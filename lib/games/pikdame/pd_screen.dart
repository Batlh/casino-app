import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import 'pd_engine.dart';

const pdRoundWinReward = 30;

List<int> pdPlaceRewards(int players) => switch (players) {
      2 => const [200, 0],
      3 => const [250, 80, 0],
      _ => const [300, 120, 40, 0],
    };

/// Karte oder Joker.
class PdCardView extends StatelessWidget {
  const PdCardView({super.key, required this.card, required this.width, this.highlighted = false});
  final PdCard? card;
  final double width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = card;
    if (c == null || !c.joker) return PlayingCardView(width: width, card: c?.card, highlighted: highlighted);
    final h = width / cardAspect;
    return Semantics(
      label: 'Joker',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(width * 0.09),
          border: Border.all(color: highlighted ? const Color(0xFFFFC95C) : const Color(0x33000000), width: highlighted ? 3 : 1),
          boxShadow: const [BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x66000000))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, size: width * 0.5, color: const Color(0xFFC8321F)),
            Text('JOKER', style: TextStyle(fontSize: width * 0.17, fontWeight: FontWeight.w900, color: const Color(0xFF241410))),
          ],
        ),
      ),
    );
  }
}

final pikDameGuide = GameGuide(
  'Pik Dame',
  [
    const GuideSection(
      'Ziel',
      'Ein Rommé mit zwei Kartenspielen und sechs Jokern. Lege Sätze (mindestens drei gleiche Werte, Farben dürfen doppelt sein) '
          'und Folgen (mindestens drei aufeinanderfolgende Karten einer Farbe) aus. Wer zuerst 1.000 Punkte hat, gewinnt.',
    ),
    const GuideSection(
      'Ein Zug',
      'Ziehe eine Karte vom Stapel. Die oberste Karte der Ablage darfst du nur nehmen, wenn du sie sofort auslegst – dann bekommst '
          'du den ganzen Ablagestapel auf die Hand. Nur im allerersten Zug darf die offene Karte einfach so genommen werden. '
          'Danach legst du aus, legst an deine eigenen Auslagen an und wirfst zum Schluss eine Karte ab.',
    ),
    const GuideSection(
      'Joker',
      'Üblich ist ein Joker je Auslage, wenn nötig auch zwei (einstellbar). Liegt in deiner Auslage ein Joker und du hast die passende Karte, darfst du tauschen und '
          'den Joker wieder auf die Hand nehmen.',
    ),
    const GuideSection(
      'Erste Auslage',
      'Die erste Auslage einer Runde muss zusammen mindestens 50 Punkte bringen (abschaltbar). Reicht es nicht, nimmst du alles '
          'mit „Zurücknehmen“ wieder auf.',
    ),
    const GuideSection(
      'Kartenwerte',
      '2 bis 9 zählen 5, 10, Bube, Dame und König 10, das Ass 25, der Joker 25 (oder 20 bzw. 15, einstellbar). Die Pik Dame zählt 100 – '
          'auf der Hand ist sie eine teure Last.',
    ),
    const GuideSection(
      'Abheben und Stapel',
      'Deckt der Abhebende eine Pik Dame oder einen Joker auf, darf er sie zusätzlich zu seinen 15 Karten behalten. '
          'Ist der Stapel leer, wird die Ablage bis auf die oberste Karte gemischt und zum neuen Stapel. Nach dem dritten Mischen '
          'endet die Runde, damit sie nicht endlos läuft.',
    ),
    const GuideSection(
      'Ausmachen und Hand',
      'Zum Ausmachen brauchst du eine letzte Karte zum Ablegen. Dann zählt jeder: Ausgelegtes plus, Karten auf der Hand minus. '
          'Legst du alles auf einmal aus, ohne vorher ausgelegt zu haben, ist das eine „Hand“: deine Punkte zählen doppelt und die '
          'Handkarten der anderen doppelt minus.',
    ),
    const GuideSection(
      'Münzen',
      'Ausmachen bringt $pdRoundWinReward Münzen, eine Hand das Doppelte. Am Ende gibt es Münzen für die Platzierung.',
    ),
  ],
);

class PikDameScreen extends StatefulWidget {
  const PikDameScreen({super.key, this.seed, this.options});
  final int? seed;

  /// Für Tests: direkt mit diesen Einstellungen starten.
  final PdOptions? options;

  @override
  State<PikDameScreen> createState() => _PikDameScreenState();
}

class _PikDameScreenState extends State<PikDameScreen> {
  PdGame? _g;
  late math.Random _rng;
  final Set<PdCard> _sel = {};
  bool _running = false;
  bool _paidRound = false;
  bool _paidGame = false;
  int _earned = 0;
  String _msg = '';

  // Einstellungen für das nächste Spiel
  List<Seat> _seats = const [Seat('Du', human: true), Seat('Oma Erna'), Seat('Opa Karl')];

  /// Wessen Hand gezeigt wird, und ob sie beim Weitergeben verdeckt ist.
  int _viewer = 0;
  bool _covered = false;
  int _target = 1000;
  int _jokerValue = 25;
  int _maxJokers = 1;
  bool _first50 = true;

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);

  late int _seed;
  static const _saveId = 'pikdame';
  bool get _saving => widget.seed == null;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final saved = _store.loadGame('seats.pikdame');
    if (saved != null) {
      try {
        final list = [for (final j in saved['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
        if (list.length >= 2 && list.length <= 4 && list.any((x) => x.human)) _seats = list;
      } catch (_) {
        // Standard behalten
      }
    }
    _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
    _seed = widget.seed ?? math.Random.secure().nextInt(1 << 31);
    if (widget.options != null) {
      _start(widget.options!);
    } else {
      _restore();
    }
  }

  /// Gespeicherte Partie nachspielen.
  void _restore() {
    if (!_saving) return;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return;
    try {
      final seats = d['seats'] == null ? null : [for (final j in d['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
      final o = PdOptions(
        players: d['players'] as int,
        target: d['target'] as int,
        jokerValue: d['jokerValue'] as int? ?? (d['joker15'] == true ? 15 : 20),
        maxJokers: d['maxJokers'] as int,
        firstMeld50: d['first50'] as bool,
      );
      _seed = d['seed'] as int;
      final game = _makeGame(o, seats)..start();
      for (final a in d['log'] as List) {
        pdApply(game, a as List);
      }
      _g = game;
      _viewer = game.players.indexWhere((x) => x.human);
      _covered = false;
      _syncViewer();
      _earned = d['earned'] as int;
      _paidRound = game.phase == PdPhase.roundOver && d['paid'] == game.actionLog.length;
      _msg = 'Spielstand geladen';
      WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
    } catch (e, st) {
      debugLog.error('pikdame.spielstand', e, st);
      _app.settings.clearGame(_saveId);
      _g = null;
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  @override
  void dispose() {
    _persist();
    super.dispose();
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    final game = _g;
    if (game == null) return;
    if (game.phase == PdPhase.gameOver || game.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    final o = game.options;
    s.saveGame(_saveId, {
      'seed': _seed,
      'players': o.players,
      'target': o.target,
      'jokerValue': o.jokerValue,
      'maxJokers': o.maxJokers,
      'first50': o.firstMeld50,
      'log': game.actionLog,
      'seats': [for (var i = 0; i < game.n; i++) Seat(game.players[i].name, human: game.players[i].human).toJson()],
      'earned': _earned,
      'paid': _paidRound ? game.actionLog.length : -1,
    });
  }

  /// Spiel mit den gewählten Plätzen; Computer behalten ihre bekannten Namen.
  PdGame _makeGame(PdOptions o, List<Seat>? seats) {
    if (seats == null || seats.length != o.players) return PdGame(o, rng: math.Random(_seed));
    const bots = ['Oma Erna', 'Opa Karl', 'Tante Gisela'];
    var b = 0;
    return PdGame(
      o,
      rng: math.Random(_seed),
      names: [for (final s in seats) s.human ? s.name : bots[b++ % bots.length]],
      humans: [for (final s in seats) s.human],
    );
  }

  int get _humans => g.players.where((x) => x.human).length;

  /// Ist ein anderer Mensch dran, wird die Hand verdeckt, bis er das Gerät hat.
  void _syncViewer() {
    final game = _g;
    if (game == null) return;
    if (game.phase != PdPhase.draw && game.phase != PdPhase.play) return;
    if (!game.players[game.current].human || game.current == _viewer) return;
    _viewer = game.current;
    _covered = _humans > 1;
    _sel.clear();
  }

  void _start(PdOptions o) {
    if (_saving) _seed = math.Random.secure().nextInt(1 << 31);
    _g = _makeGame(o, widget.options != null ? null : _seats)..start();
    _viewer = _g!.players.indexWhere((x) => x.human);
    _covered = false;
    _syncViewer();
    _sel.clear();
    _paidRound = false;
    _paidGame = false;
    _earned = 0;
    _msg = '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  PdGame get g => _g!;
  bool get _myTurn =>
      !_running && !_covered && g.current == _viewer && g.players[g.current].human && (g.phase == PdPhase.draw || g.phase == PdPhase.play);

  Future<void> _pump() async {
    if (_running || _g == null) return;
    _running = true;
    while (mounted) {
      if (g.phase == PdPhase.roundOver || g.phase == PdPhase.gameOver) {
        _pay();
        break;
      }
      if (g.players[g.current].human) break;
      await Future<void>.delayed(_app.settings.botDelay(900));
      if (!mounted) return;
      pdBotTurn(g, g.current, _rng);
      _app.sfx.play(Sound.card);
      setState(() {});
    }
    _running = false;
    if (mounted) setState(_syncViewer);
  }

  void _pay() {
    final r = g.result;
    if (!_paidRound && r != null) {
      _paidRound = true;
      if (g.players[r.winner].human && g.players.any((x) => !x.human)) {
        final coins = pdRoundWinReward * (r.hand ? 2 : 1);
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.win);
      }
    }
    if (g.phase == PdPhase.gameOver && !_paidGame) {
      _paidGame = true;
      // Allein: Münzen nach Platz; mehrere Menschen: nur für einen menschlichen Sieger gegen Computer
      final order = g.ranking();
      final human = g.players.indexWhere((x) => x.human);
      final place = _humans == 1 ? order.indexOf(human) : (g.players[order.first].human && g.players.any((x) => !x.human) ? 0 : -1);
      final coins = place < 0 ? 0 : pdPlaceRewards(g.n)[place];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(place == 0 ? Sound.bigWin : Sound.coin);
      }
    }
  }

  // ---------- Eingaben ----------

  void _toggle(PdCard c) {
    if (!_myTurn) return;
    setState(() {
      if (!_sel.remove(c)) _sel.add(c);
      _msg = '';
    });
  }

  void _drawStack() {
    g.drawStack(_viewer);
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
    if (g.phase == PdPhase.roundOver || g.phase == PdPhase.gameOver) _pump();
  }

  void _takeOpen() {
    g.takeOpen(_viewer);
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
  }

  void _takePile() {
    final cards = _sel.toList();
    if (!g.canTakePile(_viewer, cards)) {
      setState(() => _msg = 'Wähle Karten, die mit der obersten Ablagekarte eine Auslage bilden');
      return;
    }
    g.takePile(_viewer, cards);
    _app.sfx.play(Sound.chip);
    setState(_sel.clear);
  }

  void _meld() {
    final cards = _sel.toList();
    if (!g.canMeld(_viewer, cards)) {
      setState(() => _msg = cards.length < 3
          ? 'Eine Auslage braucht mindestens drei Karten'
          : 'Das ist weder ein Satz noch eine Folge (oder es bliebe keine Karte zum Abwerfen)');
      return;
    }
    g.meld(_viewer, cards);
    _app.sfx.play(Sound.chip);
    setState(_sel.clear);
  }

  void _tapMeld(int index) {
    if (!_myTurn || g.phase != PdPhase.play || _sel.length != 1) {
      if (_myTurn && g.phase == PdPhase.play) setState(() => _msg = 'Wähle genau eine Karte und tippe dann auf deine Auslage');
      return;
    }
    final c = _sel.first;
    if (g.canSwapJoker(_viewer, index, c)) {
      g.swapJoker(_viewer, index, c);
      _msg = 'Joker zurück auf die Hand';
    } else if (g.canExtend(_viewer, index, c)) {
      g.extend(_viewer, index, c);
      _msg = '';
    } else {
      setState(() => _msg = 'Diese Karte passt nicht an die Auslage');
      return;
    }
    _app.sfx.play(Sound.chip);
    setState(_sel.clear);
  }

  void _undo() {
    g.undoTurn();
    _app.sfx.play(Sound.tick);
    setState(() {
      _sel.clear();
      _msg = 'Zurückgenommen';
    });
  }

  void _discard() {
    if (_sel.length != 1) {
      setState(() => _msg = 'Wähle genau eine Karte zum Abwerfen');
      return;
    }
    final block = g.discardBlocker(_viewer);
    if (block != null) {
      setState(() => _msg = block);
      return;
    }
    g.discard(_viewer, _sel.first);
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
    _pump();
  }

  void _nextRound() {
    g.nextRound();
    setState(() {
      _paidRound = false;
      _sel.clear();
      _msg = '';
    });
    _pump();
  }

  // ---------- Anzeige ----------

  String get _status {
    if (_msg.isNotEmpty) return _msg;
    if (g.phase == PdPhase.roundOver || g.phase == PdPhase.gameOver) return g.result?.text ?? '';
    if (_covered) return 'Gib das Gerät an ${g.players[g.current].name}';
    if (!_myTurn) return g.lastEvent.isNotEmpty ? g.lastEvent : '${g.players[g.current].name} ist dran';
    if (g.phase == PdPhase.draw) {
      return g.firstTurn ? 'Ziehe vom Stapel oder nimm die offene Karte' : 'Ziehe vom Stapel oder nimm die Ablage mit passenden Karten';
    }
    final first = !g.players[_viewer].hasMelded && g.options.firstMeld50 ? ' · Erste Auslage ${g.turnMeldPoints}/50' : '';
    if (g.mustUse != null) return 'Lege die ${g.mustUse!.name} aus$first';
    return 'Auslegen, anlegen, dann eine Karte abwerfen$first';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Pik Dame',
      guide: pikDameGuide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1E5631), Color(0xFF0B2414)]),
      ),
      child: _g == null ? _setup() : LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _setup() {
    final p = Palette.of(context);
    Widget row(String label, List<(String, bool, VoidCallback)> opts) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: p.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [for (final o in opts) ChoiceChip(label: Text(o.$1), selected: o.$2, onSelected: (_) => setState(o.$3))],
              ),
            ],
          ),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.panelEdge, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Neues Spiel', style: Theme.of(context).textTheme.titleLarge),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'Mitspieler: ${_seats.map((x) => x.human ? x.name : 'Computer').join(', ')}',
                      style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final seats = await showSeatSetup(context, gameId: 'pikdame', title: 'Pik Dame', minSeats: 2, maxSeats: 4);
                      if (seats != null && mounted) setState(() => _seats = seats);
                    },
                    child: const Text('Ändern'),
                  ),
                ]),
              ),
              row('Ziel', [for (final t in [500, 1000]) ('$t Punkte', _target == t, () => _target = t)]),
              row('Joker zählt', [for (final v in [25, 20, 15]) ('$v Punkte', _jokerValue == v, () => _jokerValue = v)]),
              row('Joker je Auslage', [
                ('Einer', _maxJokers == 1, () => _maxJokers = 1),
                ('Bis zu zwei', _maxJokers == 2, () => _maxJokers = 2),
              ]),
              row('Erste Auslage', [
                ('Mindestens 50', _first50, () => _first50 = true),
                ('Ohne Minimum', !_first50, () => _first50 = false),
              ]),
              const SizedBox(height: 10),
              ActionButton(
                primary: true,
                label: 'Los geht’s',
                onPressed: () => setState(() => _start(PdOptions(players: _seats.length, target: _target, jokerValue: _jokerValue, maxJokers: _maxJokers, firstMeld50: _first50))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meldRow(PdMeld m, double w, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < m.cards.length; i++)
                Align(widthFactor: i == m.cards.length - 1 ? 1 : 0.45, child: PdCardView(card: m.cards[i], width: w)),
            ],
          ),
        ),
      );

  Widget _opponent(int p, double w) {
    final pl = g.players[p];
    final pal = Palette.of(context);
    final active = g.current == p && g.phase != PdPhase.roundOver && g.phase != PdPhase.gameOver;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: active ? pal.accent : const Color(0x88000000), borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${pl.name} · ${pl.hand.length} Karten · ${pl.score} Punkte',
            style: TextStyle(color: active ? pal.onAccent : const Color(0xFFF6E7C8), fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [for (final m in g.meldsOf(p)) _meldRow(m, w)]),
      ],
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final small = math.min(34.0, w / 22);
    final overlay = g.phase == PdPhase.roundOver || g.phase == PdPhase.gameOver;
    final pal = Palette.of(context);
    final myMelds = [for (var i = 0; i < g.melds.length; i++) if (g.melds[i].owner == _viewer) i];
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [for (var k = 1; k < g.n; k++) _opponent((_viewer + k) % g.n, small)],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(children: [
                            PdCardView(card: null, width: small * 1.6),
                            Text('${g.stack.length}', style: const TextStyle(color: Color(0xFFF6E7C8))),
                          ]),
                          const SizedBox(width: 16),
                          Column(children: [
                            if (g.pile.isEmpty) SizedBox(width: small * 1.6, height: small * 1.6 / cardAspect) else PdCardView(card: g.pile.last, width: small * 1.6),
                            Text('Ablage ${g.pile.length}', style: const TextStyle(color: Color(0xFFF6E7C8))),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_humans > 1 ? g.players[_viewer].name : 'Du'} · ${g.players[_viewer].score} Punkte', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [for (final i in myMelds) _meldRow(g.melds[i], small * 1.2, onTap: () => _tapMeld(i))],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
            _actions(),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
              child: _covered
                  ? HandCover(name: g.players[g.current].name, onReveal: () => setState(() => _covered = false))
                  : CardFan<PdCard>(
                items: [...g.players[_viewer].hand]..sort(_order),
                maxCardWidth: math.min(70, w / 9),
                cardBuilder: (c, cw, raised) => PdCardView(card: c, width: cw, highlighted: raised),
                isRaised: _sel.contains,
                onTap: _toggle,
              ),
            ),
          ],
        ),
        if (overlay) Positioned.fill(child: _resultPanel(pal)),
      ],
    );
  }

  int _order(PdCard a, PdCard b) {
    if (a.joker != b.joker) return a.joker ? 1 : -1;
    if (a.joker) return 0;
    final s = a.suit!.index - b.suit!.index;
    return s != 0 ? s : a.rank - b.rank;
  }

  Widget _actions() {
    final b = <Widget>[];
    if (_myTurn && g.phase == PdPhase.draw) {
      b.add(ActionButton(primary: true, label: 'Vom Stapel', onPressed: _drawStack));
      if (g.canTakeOpen(_viewer)) b.add(ActionButton(label: 'Offene Karte', onPressed: _takeOpen));
      if (g.pile.isNotEmpty && !g.firstTurn) {
        b.add(ActionButton(label: 'Ablage nehmen', onPressed: g.canTakePile(_viewer, _sel.toList()) ? _takePile : null));
      }
    } else if (_myTurn && g.phase == PdPhase.play) {
      b.add(ActionButton(label: 'Auslegen', onPressed: _sel.length >= 3 ? _meld : null));
      if (g.canUndoTurn) b.add(ActionButton(label: 'Zurücknehmen', onPressed: _undo));
      b.add(ActionButton(primary: true, label: 'Abwerfen', onPressed: _sel.length == 1 ? _discard : null));
    }
    return SizedBox(
      height: 46,
      child: Center(child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: b)),
    );
  }

  Widget _resultPanel(Palette pal) {
    final r = g.result;
    final over = g.phase == PdPhase.gameOver;
    final c = <Widget>[
      Text(r?.text ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (var p = 0; p < g.n; p++)
        Text(
          '${g.players[p].name}: ${r == null ? '' : '${r.changes[p] >= 0 ? '+' : '−'}${r.changes[p].abs()} → '}${g.players[p].score}',
          style: TextStyle(color: pal.ink, fontSize: 15, fontWeight: g.players[p].human ? FontWeight.w700 : FontWeight.w500),
        ),
      if (r != null && g.players[r.winner].human && g.players.any((x) => !x.human)) Text('+${pdRoundWinReward * (r!.hand ? 2 : 1)} Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
    ];
    if (over) {
      final order = g.ranking();
      final place = _humans == 1 ? order.indexOf(g.players.indexWhere((x) => x.human)) : -1;
      c.addAll([
        const SizedBox(height: 8),
        Text(place == 0 ? 'Du hast gewonnen!' : 'Gewonnen hat ${g.players[order.first].name}', style: Theme.of(context).textTheme.titleLarge),
        if (_earned > 0) Text('Verdient: $_earned Münzen', style: TextStyle(color: pal.inkSoft)),
        const SizedBox(height: 10),
        ActionButton(primary: true, label: 'Neues Spiel', onPressed: () => setState(() => _g = null)),
      ]);
    } else {
      c.addAll([const SizedBox(height: 10), ActionButton(primary: true, label: 'Nächste Runde', onPressed: _nextRound)]);
    }
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: pal.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.panelEdge, width: 2)),
          child: Column(mainAxisSize: MainAxisSize.min, children: c),
        ),
      ),
    );
  }
}
