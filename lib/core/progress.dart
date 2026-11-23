import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet.dart';

/// Statistik, Erfolge und Tagesaufgaben.
///
/// Gezählt wird automatisch über die Geldbörse: Jeder Einsatz und jede Auszahlung gehört zum Spiel, das gerade
/// offen ist (setzt GameFrame). Tagesbonus und Nachfüllen zählen nicht. Besondere Ereignisse (Royal Flush,
/// Solitaire gewonnen …) melden die Spiele selbst über [event].
class Progress extends ChangeNotifier {
  Progress({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _key = 'progress';
  final DateTime Function() _clock;
  SharedPreferences? _prefs;
  Wallet? _wallet;

  /// Spiel, das gerade offen ist (Titel aus GameFrame), oder null in der Lobby.
  String? current;

  final Map<String, GameStat> stats = {};
  final Map<String, String> unlocked = {}; // Erfolg → Datum
  final Map<String, int> counters = {}; // Ereignisse und Zähler
  DailyState? _daily;
  DailyState? _weekly;

  /// Extra, das beim letzten Abholen mit ausgezahlt wurde (für die Meldung).
  int lastClaimBonus = 0;

  /// Zuletzt freigeschalteter Erfolg, für die Meldung im Spiel.
  final ValueNotifier<Achievement?> justUnlocked = ValueNotifier(null);

  void attach(SharedPreferences prefs, Wallet wallet) {
    _prefs = prefs;
    _wallet = wallet;
    _load();
    wallet
      ..onSpend = _spent
      ..onCredit = _credited
      ..onBonus = _bonus;
  }

  // ---------------------------------------------------------------- Speichern

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stats
        ..clear()
        ..addAll({for (final e in ((j['stats'] as Map?) ?? {}).entries) '${e.key}': GameStat.fromJson(e.value as Map)});
      unlocked
        ..clear()
        ..addAll({for (final e in ((j['unlocked'] as Map?) ?? {}).entries) '${e.key}': '${e.value}'});
      counters
        ..clear()
        ..addAll({for (final e in ((j['counters'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toInt()});
      final d = j['daily'];
      _daily = d is Map ? DailyState.fromJson(d) : null;
      final w = j['weekly'];
      _weekly = w is Map ? DailyState.fromJson(w, weeklyTasksFor) : null;
    } catch (_) {
      // Kaputter Stand: neu anfangen
    }
  }

  void _save() {
    _prefs?.setString(
      _key,
      jsonEncode({
        'stats': {for (final e in stats.entries) e.key: e.value.toJson()},
        'unlocked': unlocked,
        'counters': counters,
        if (_daily != null) 'daily': _daily!.toJson(),
        if (_weekly != null) 'weekly': _weekly!.toJson(),
      }),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- Ereignisse

  void _spent(int amount) {
    final g = current;
    if (g == null) return;
    final s = stats.putIfAbsent(g, GameStat.new)
      ..rounds += 1
      ..staked += amount;
    s.lastPlayed = _today;
    _count('einsatz', amount);
    _count('runden', 1);
    _dailyAdd('runden', 1);
    _dailyAdd('einsatz', amount);
    _dailyGame(g);
    _check();
  }

  void _credited(int amount) {
    final g = current;
    if (g == null) return;
    final s = stats.putIfAbsent(g, GameStat.new)
      ..paid += amount
      ..lastPlayed = _today;
    if (amount > s.best) s.best = amount;
    if (amount > (counters['bester'] ?? 0)) counters['bester'] = amount;
    _dailyMax('gewinn', amount);
    _dailyGame(g);
    _check();
  }

  void _bonus() {
    _count('bonus', 1);
    _check();
  }

  /// Besonderes Ereignis aus einem Spiel, z. B. 'royal_flush'.
  void event(String id, [int n = 1]) {
    _count('e.$id', n);
    _dailyAdd('e.$id', n);
    _check();
  }

  void _count(String id, int n) => counters[id] = (counters[id] ?? 0) + n;

  // ---------------------------------------------------------------- Erfolge

  int get gamesPlayed => stats.values.where((s) => s.rounds > 0 || s.paid > 0).length;

  int _value(Achievement a) => switch (a.kind) {
        AchKind.counter => counters[a.key] ?? 0,
        AchKind.games => gamesPlayed,
        AchKind.best => counters['bester'] ?? 0,
      };

  /// Fortschritt eines Erfolgs (0..ziel).
  int progressOf(Achievement a) => min(_value(a), a.goal);

  void _check() {
    Achievement? last;
    for (final a in achievements) {
      if (unlocked.containsKey(a.id)) continue;
      if (_value(a) >= a.goal) {
        unlocked[a.id] = _today;
        last = a;
      }
    }
    _save();
    if (last != null) justUnlocked.value = last;
  }

  // ---------------------------------------------------------------- Tagesaufgaben

  String get _today {
    final d = _clock();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Die drei Aufgaben von heute (werden um Mitternacht neu ausgelost, für jeden Tag gleich).
  DailyState get daily {
    final today = _today;
    // Neuer Tag: neue Aufgaben (gespeichert wird beim nächsten Ereignis, nicht hier mitten im Zeichnen)
    if (_daily?.date != today) _daily = DailyState(today, dailyTasksFor(today), {}, {}, false);
    return _daily!;
  }

  /// Montag der laufenden Woche; Wochenaufgaben gelten von Montag bis Sonntag.
  String get _thisWeek {
    final now = _clock();
    final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Die drei Aufgaben dieser Woche (ab Montag neu, für jeden gleich).
  DailyState get weekly {
    final week = _thisWeek;
    if (_weekly?.date != week) _weekly = DailyState(week, weeklyTasksFor(week), {}, {}, false);
    return _weekly!;
  }

  void _dailyAdd(String key, int n) {
    for (final d in [daily, weekly]) {
      d.values[key] = (d.values[key] ?? 0) + n;
    }
  }

  void _dailyMax(String key, int n) {
    for (final d in [daily, weekly]) {
      if (n > (d.values[key] ?? 0)) d.values[key] = n;
    }
  }

  void _dailyGame(String game) {
    for (final d in [daily, weekly]) {
      final list = d.games;
      if (!list.contains(game)) list.add(game);
      d.values['spiel:$game'] = 1;
      d.values['verschieden'] = list.length;
    }
  }

  bool _isWeekly(DailyTask t) => weekly.tasks.contains(t) && !daily.tasks.contains(t);
  DailyState _stateOf(DailyTask t) => _isWeekly(t) ? weekly : daily;

  int dailyProgress(DailyTask t) => min(_stateOf(t).values[t.key] ?? 0, t.goal);

  /// Aufgaben (Tag und Woche), deren Belohnung bereitliegt.
  int get dailyReady => [
        for (final d in [daily, weekly]) ...d.tasks.where((t) => dailyProgress(t) >= t.goal && !d.claimed.contains(t.key)),
      ].length;
  bool dailyDone(DailyTask t) => dailyProgress(t) >= t.goal;
  bool claimed(DailyTask t) => _stateOf(t).claimed.contains(t.key);

  /// Belohnung für eine erledigte Tages- oder Wochenaufgabe abholen. Gibt alle Münzen zurück
  /// (0, wenn nicht möglich); ein Extra für alle drei steht zusätzlich in [lastClaimBonus].
  int claimDaily(DailyTask t) {
    final isWeek = _isWeekly(t);
    final d = isWeek ? weekly : daily;
    lastClaimBonus = 0;
    if (!dailyDone(t) || d.claimed.contains(t.key)) return 0;
    d.claimed.add(t.key);
    var coins = t.reward;
    _count(isWeek ? 'wochenaufgaben' : 'aufgaben', 1);
    if (!isWeek) weekly.values['tagesaufgaben'] = (weekly.values['tagesaufgaben'] ?? 0) + 1;
    // Alle drei geschafft: Extra
    if (!d.allBonus && d.tasks.every((x) => d.claimed.contains(x.key))) {
      d.allBonus = true;
      lastClaimBonus = isWeek ? weeklyAllBonus : dailyAllBonus;
      coins += lastClaimBonus;
      if (!isWeek) weekly.values['tage'] = (weekly.values['tage'] ?? 0) + 1;
    }
    _wallet?.addReward(coins);
    _check();
    return coins;
  }
}

/// Global wie das Fehlerprotokoll, damit jedes Spiel Ereignisse melden kann.
final progress = Progress();

class GameStat {
  GameStat();
  GameStat.fromJson(Map j)
      : rounds = (j['r'] as num?)?.toInt() ?? 0,
        staked = (j['s'] as num?)?.toInt() ?? 0,
        paid = (j['p'] as num?)?.toInt() ?? 0,
        best = (j['b'] as num?)?.toInt() ?? 0,
        lastPlayed = j['l'] as String?;
  int rounds = 0;
  int staked = 0;
  int paid = 0;
  int best = 0;
  String? lastPlayed;
  Map<String, Object?> toJson() => {'r': rounds, 's': staked, 'p': paid, 'b': best, if (lastPlayed != null) 'l': lastPlayed};
}

// ------------------------------------------------------------------ Erfolge

enum AchKind { counter, games, best }

class Achievement {
  const Achievement(this.id, this.title, this.text, this.kind, this.goal, [this.key = '']);
  final String id;
  final String title;
  final String text;
  final AchKind kind;
  final int goal;

  /// Zähler für [AchKind.counter].
  final String key;
}

const achievements = <Achievement>[
  Achievement('erste_runde', 'Erster Einsatz', 'Setze zum ersten Mal Münzen', AchKind.counter, 1, 'runden'),
  Achievement('runden_100', 'Stammgast', 'Setze 100 Mal', AchKind.counter, 100, 'runden'),
  Achievement('runden_1000', 'Dauergast', 'Setze 1.000 Mal', AchKind.counter, 1000, 'runden'),
  Achievement('spiele_5', 'Neugierig', 'Spiele 5 verschiedene Spiele', AchKind.games, 5),
  Achievement('spiele_15', 'Rundgang', 'Spiele 15 verschiedene Spiele', AchKind.games, 15),
  Achievement('spiele_30', 'Kenner', 'Spiele 30 verschiedene Spiele', AchKind.games, 30),
  Achievement('gewinn_1000', 'Kleiner Fisch', 'Gewinne auf einmal 1.000 Münzen', AchKind.best, 1000),
  Achievement('gewinn_10000', 'Dicker Fisch', 'Gewinne auf einmal 10.000 Münzen', AchKind.best, 10000),
  Achievement('gewinn_100000', 'Wal', 'Gewinne auf einmal 100.000 Münzen', AchKind.best, 100000),
  Achievement('einsatz_100k', 'Großer Umsatz', 'Setze insgesamt 100.000 Münzen', AchKind.counter, 100000, 'einsatz'),
  Achievement('einsatz_1mio', 'Millionenumsatz', 'Setze insgesamt 1.000.000 Münzen', AchKind.counter, 1000000, 'einsatz'),
  Achievement('bonus_7', 'Treue Seele', 'Hole an 7 Tagen den Tagesbonus ab', AchKind.counter, 7, 'bonus'),
  Achievement('bonus_30', 'Monatskarte', 'Hole an 30 Tagen den Tagesbonus ab', AchKind.counter, 30, 'bonus'),
  Achievement('aufgaben_10', 'Fleißig', 'Erledige 10 Tagesaufgaben', AchKind.counter, 10, 'aufgaben'),
  Achievement('royal_flush', 'Königlich', 'Ziehe beim Video Poker einen Royal Flush', AchKind.counter, 1, 'e.royal_flush'),
  Achievement('black_jack', 'Natürlich', 'Bekomme beim Black Jack einen Black Jack', AchKind.counter, 1, 'e.black_jack'),
  Achievement('null', 'Volltreffer Null', 'Gewinne beim Roulette auf der Null', AchKind.counter, 1, 'e.roulette_null'),
  Achievement('joker_rad', 'Jokerrad', 'Triff beim Glücksrad den Joker mit Einsatz', AchKind.counter, 1, 'e.rad_joker'),
  Achievement('flipper_million', 'Flipperkönig', 'Erreiche an einem Flipper 1.000.000 Punkte', AchKind.counter, 1, 'e.flipper_million'),
  Achievement('solitaire', 'Geduld', 'Gewinne eine Partie Solitaire oder Spider', AchKind.counter, 1, 'e.solitaire_sieg'),
  Achievement('mahjong', 'Mahjong!', 'Gewinne eine Hand Mahjong', AchKind.counter, 1, 'e.mahjong_sieg'),
  Achievement('schachmatt', 'Schachmatt', 'Gewinne eine Partie Schach', AchKind.counter, 1, 'e.schach_sieg'),
  Achievement('kniffel', 'Kniffel!', 'Wirf beim Kniffel einen Kniffel', AchKind.counter, 1, 'e.kniffel'),
  Achievement('netz', 'Gesellig', 'Spiele einmal im Netzwerk', AchKind.counter, 1, 'e.netz'),
  Achievement('pachislo_big', 'Glückslampe', 'Richte beim Pachislo einen BIG aus', AchKind.counter, 1, 'e.pachislo_big'),
];

// ------------------------------------------------------------------ Tagesaufgaben

class DailyTask {
  const DailyTask(this.key, this.text, this.goal, this.reward);
  final String key;
  final String text;
  final int goal;
  final int reward;
}

const dailyAllBonus = 500;
const weeklyAllBonus = 3000;

/// Drei Aufgaben für eine Woche (Schlüssel = Montag), für jeden gleich.
List<DailyTask> weeklyTasksFor(String monday) {
  var seed = 0x3eec;
  for (final c in monday.codeUnits) {
    seed = (seed * 31 + c) & 0x7fffffff;
  }
  final rng = Random(seed);
  final pool = <DailyTask>[
    const DailyTask('runden', 'Setze 200 Mal Münzen, egal wo', 200, 1500),
    const DailyTask('verschieden', 'Spiele 10 verschiedene Spiele', 10, 1500),
    const DailyTask('gewinn', 'Gewinne auf einmal mindestens 5.000 Münzen', 5000, 2500),
    const DailyTask('einsatz', 'Setze insgesamt 30.000 Münzen', 30000, 2000),
    const DailyTask('tagesaufgaben', 'Hole 12 Tagesaufgaben ab', 12, 2000),
    const DailyTask('tage', 'Schließe an 4 Tagen alle Tagesaufgaben ab', 4, 2500),
    const DailyTask('e.solitaire_sieg', 'Gewinne 5 Partien Solitaire oder Spider', 5, 2000),
    const DailyTask('e.mahjong_sieg', 'Gewinne 5 Hände Mahjong', 5, 2000),
  ];
  pool.shuffle(rng);
  return pool.sublist(0, 3);
}

/// Spiele für die Aufgabe „Spiele eine Runde …“ (Titel wie im Spiel).
const dailyGames = [
  'Black Jack', 'Roulette', 'Video Poker', 'Glücksrad', 'Keno', 'Craps', 'Baccarat', 'Sic Bo',
  'Entchen angeln', 'Caribbean Stud', 'Kosmos 78', 'Tiefsee', 'Fruchtlawine', 'Pharaonengold',
];

/// Drei Aufgaben für einen Tag, aus dem Datum ausgelost (für jeden gleich, ändert sich täglich).
List<DailyTask> dailyTasksFor(String date) {
  // Eigene Prüfsumme statt hashCode, damit es auf allen Geräten gleich ist
  var seed = 0x5eed;
  for (final c in date.codeUnits) {
    seed = (seed * 31 + c) & 0x7fffffff;
  }
  final rng = Random(seed);
  final pool = <DailyTask>[
    const DailyTask('runden', 'Setze 25 Mal Münzen, egal wo', 25, 300),
    const DailyTask('verschieden', 'Spiele 3 verschiedene Spiele', 3, 300),
    const DailyTask('gewinn', 'Gewinne auf einmal mindestens 500 Münzen', 500, 400),
    const DailyTask('einsatz', 'Setze insgesamt 3.000 Münzen', 3000, 400),
    const DailyTask('e.solitaire_sieg', 'Gewinne eine Partie Solitaire oder Spider', 1, 500),
    const DailyTask('e.mahjong_sieg', 'Gewinne eine Hand Mahjong', 1, 500),
  ];
  pool.shuffle(rng);
  final game = dailyGames[rng.nextInt(dailyGames.length)];
  return [pool[0], pool[1], DailyTask('spiel:$game', 'Spiele eine Runde $game', 1, 300)];
}

class DailyState {
  DailyState(this.date, this.tasks, this.values, this.claimed, this.allBonus);
  factory DailyState.fromJson(Map j, [List<DailyTask> Function(String) tasksFor = dailyTasksFor]) {
    final date = '${j['date']}';
    return DailyState(
      date,
      tasksFor(date),
      {for (final e in ((j['v'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toInt()},
      {for (final c in (j['c'] as List?) ?? const []) '$c'},
      j['all'] == true,
    )..games.addAll([for (final g in (j['g'] as List?) ?? const []) '$g']);
  }

  final String date;
  final List<DailyTask> tasks;
  final Map<String, int> values;
  final Set<String> claimed;
  final List<String> games = [];
  bool allBonus;

  Map<String, Object?> toJson() => {'date': date, 'v': values, 'c': claimed.toList(), 'g': games, 'all': allBonus};
}
