import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/net/lan.dart';
import '../../core/net/lan_table.dart';
import '../../core/saves.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_panels.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'skat_bot.dart';
import 'skat_engine.dart';
import 'skat_net.dart';

const skatPlaceCoins = [200, 60, 0];

int skatWinCoins(int value) => math.min(150, value);

const skatGuide = GameGuide(
  'Skat',
  [
    GuideSection(
      'Ziel',
      'Drei Spieler, 32 Karten, jeder bekommt zehn, zwei liegen im Skat. Wer am höchsten reizt, spielt allein gegen die beiden '
          'anderen und braucht mindestens 61 der 120 Augen. Ass 11, Zehn 10, König 4, Dame 3, Bube 2. Gespielt werden zwölf Spiele.',
    ),
    GuideSection(
      'Reizen',
      'Mittelhand sagt Vorhand Zahlen: 18, 20, 22, 23, 24, 27 … Vorhand antwortet mit „Ja“ oder passt. Danach reizt Hinterhand '
          'gegen den Gewinner. Reize nur so hoch, wie dein Spiel wert ist: Grundwert mal (Spitzen + 1). Grundwerte: Karo 9, Herz 10, '
          'Pik 11, Kreuz 12, Grand 24, Null 23 (Hand 35).',
    ),
    GuideSection(
      'Spitzen',
      'Spitzen sind die Buben von oben (Kreuz, Pik, Herz, Karo, dann Ass, Zehn … der Trumpffarbe). Hast du den Kreuz-Buben, '
          'spielst du „mit“ so vielen, wie du ohne Lücke hast, sonst „ohne“ so vielen, wie dir fehlen.',
    ),
    GuideSection(
      'Skat und Spiel',
      'Der Alleinspieler nimmt den Skat auf und drückt zwei Karten, oder er spielt Hand (eine Stufe mehr, bei Hand auch Schneider '
          'oder Schwarz ansagbar). Dann sagt er das Spiel an. Im Farbspiel sind die vier Buben und die Trumpffarbe Trumpf, im Grand nur '
          'die Buben. Beim Null gibt es keinen Trumpf, und der Alleinspieler darf keinen Stich bekommen.',
    ),
    GuideSection(
      'Bedienen',
      'Die angespielte Farbe muss bedient werden. Buben gehören zum Trumpf, nicht zu ihrer Farbe. Wer nicht bedienen kann, darf '
          'beliebig abwerfen oder stechen.',
    ),
    GuideSection(
      'Wertung und Münzen',
      'Gewonnen: + Spielwert, verloren: − doppelter Spielwert. Schneider (90 Augen) und Schwarz (alle Stiche) bringen je eine Stufe '
          'mehr. Ist das Spiel weniger wert als gereizt, ist es überreizt und verloren. Ein gewonnenes Spiel bringt so viele Münzen '
          'wie sein Wert (höchstens 150), am Ende 200 oder 60 Münzen für Platz 1 oder 2. Ouvert-Spiele gibt es hier nicht.',
    ),
  ],
);

class SkatScreen extends StatefulWidget {
  const SkatScreen({super.key, this.seed});
  final int? seed;

  @override
  State<SkatScreen> createState() => _SkatScreenState();
}

class _SkatScreenState extends State<SkatScreen> {
  late math.Random _rng;
  late SkatGame _g;
  final Set<PlayingCard> _sel = {};
  bool _running = false;
  bool _paid = false;
  bool _paidMatch = false;
  int _earned = 0;
  SkatType _choice = SkatType.clubs;
  bool _schneider = false;
  bool _schwarz = false;

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  /// Dein Platz (im Netz je Gerät verschieden) und die Plätze, an denen Menschen sitzen.
  int _me = 0;
  Set<int> _humans = {0};
  bool _isBot(int p) => !_humans.contains(p);

  // Netzwerk
  bool _netPanel = false;
  String _name = '';
  String _netMessage = '';
  NetTableHost? _host;
  NetTableGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manual = TextEditingController();
  bool _netPlaying = false;
  List<String> _netNames = const [];

  /// Gastgeber: so viele Protokolleinträge sind schon verteilt.
  int _sent = 0;
  bool get _net => _host != null || _guest != null;
  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
    _seed = widget.seed ?? math.Random.secure().nextInt(1 << 31);
    _g = _restore() ?? _make();
    final st = _store;
    _name = '${st.loadGame('netz')?['name'] ?? st.loadGame('poker')?['name'] ?? st.loadGame('bingo')?['name'] ?? ''}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  late int _seed;
  static const _saveId = 'skat';
  bool get _saving => widget.seed == null && !_net;

  SkatGame _make() => SkatGame(rng: math.Random(_seed))..start();

  /// Gespeicherte Partie nachspielen.
  SkatGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      final g = _make();
      for (final a in d['log'] as List) {
        skatApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _paid = g.phase == SkatPhase.dealOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (e, st) {
      debugLog.error('skat.spielstand', e, st);
      _app.settings.clearGame(_saveId);
      _seed = math.Random.secure().nextInt(1 << 31);
      return null;
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
    _broadcast();
  }

  @override
  void dispose() {
    _persist();
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manual.dispose();
    super.dispose();
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_g.phase == SkatPhase.matchOver || _g.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'seed': _seed, 'log': _g.actionLog, 'earned': _earned, 'paid': _paid ? _g.actionLog.length : -1});
  }

  bool get _humanBid => _g.phase == SkatPhase.bidding && _g.bidTurn == _me;
  bool get _humanDeclarer => _g.declarer == _me;
  bool get _myCard => _g.phase == SkatPhase.playing && _g.current == _me && !_running;

  Future<void> _pump() async {
    if (_running) return;
    // Als Mitspieler zieht nur der Gastgeber die Computer
    if (_guest != null) {
      if (_g.phase == SkatPhase.dealOver || _g.phase == SkatPhase.matchOver) _pay();
      return;
    }
    _running = true;
    while (mounted) {
      final ph = _g.phase;
      if (ph == SkatPhase.dealOver || ph == SkatPhase.matchOver) {
        _pay();
        break;
      }
      if (ph == SkatPhase.bidding) {
        if (!_isBot(_g.bidTurn)) break;
        await Future<void>.delayed(_app.settings.botDelay(600));
        if (!mounted) return;
        final p = _g.bidTurn;
        if (skatMaxBid(_g.players[p].hand) >= _g.askedValue) {
          _g.bidYes(p);
        } else {
          _g.bidPass(p);
        }
        setState(() {});
        continue;
      }
      if (ph == SkatPhase.skatChoice || ph == SkatPhase.discard || ph == SkatPhase.declare) {
        if (!_isBot(_g.declarer)) {
          if (_humanDeclarer && ph == SkatPhase.declare) _choice = skatChooseGame(_g, [..._g.players[_me].hand, ..._g.skat]);
          break;
        }
        await Future<void>.delayed(_app.settings.botDelay(700));
        if (!mounted) return;
        final d = _g.declarer;
        if (ph == SkatPhase.skatChoice) _g.takeSkat();
        if (_g.phase == SkatPhase.discard) {
          final cards = _g.players[d].hand;
          _g.discard(skatDiscard(cards, skatChooseGame(_g, cards)));
        }
        if (_g.phase == SkatPhase.declare) _g.declare(skatChooseGame(_g, [..._g.players[d].hand, ..._g.skat]));
        _app.sfx.play(Sound.chip);
        setState(() {});
        continue;
      }
      if (ph == SkatPhase.playing) {
        if (!_isBot(_g.current)) break;
        await Future<void>.delayed(_app.settings.botDelay(_g.trick.isEmpty && _g.lastTrick.isNotEmpty ? 900 : 600));
        if (!mounted) return;
        _g.play(_g.current, skatBotCard(_g, _g.current, _rng));
        _app.sfx.play(Sound.card);
        setState(() {});
        continue;
      }
      break;
    }
    _running = false;
    if (mounted) setState(() {});
  }

  void _pay() {
    final r = _g.result;
    if (!_paid && r != null) {
      _paid = true;
      if (r.declarer == _me && r.won) {
        final coins = skatWinCoins(r.value);
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.win);
      } else if (r.declarer >= 0 && r.declarer != _me && !r.won) {
        _app.sfx.play(Sound.coin);
      }
    }
    if (_g.phase == SkatPhase.matchOver && !_paidMatch) {
      _paidMatch = true;
      final coins = skatPlaceCoins[_g.ranking().indexOf(_me)];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.bigWin);
      }
    }
  }

  /// Als Mitspieler geht der Zug an den Gastgeber und kommt mit dem Protokoll zurück.
  bool _sendIfGuest(List<Object?> a) {
    final guest = _guest;
    if (guest == null) return false;
    guest.send({'t': 'act', 'a': a});
    return true;
  }

  void _bidYes() {
    if (_sendIfGuest(['y', _me])) return;
    _g.bidYes(_me);
    _app.sfx.play(Sound.tick);
    setState(() {});
    _pump();
  }

  void _bidPass() {
    if (_sendIfGuest(['b', _me])) return;
    _g.bidPass(_me);
    _app.sfx.play(Sound.tick);
    setState(() {});
    _pump();
  }

  void _takeSkat() {
    if (_sendIfGuest(['s'])) return;
    _g.takeSkat();
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
  }

  void _playHand() {
    if (_sendIfGuest(['h'])) return;
    _g.playHand();
    _choice = skatChooseGame(_g, _g.players[_me].hand);
    setState(() {});
  }

  void _discard() {
    if (_sendIfGuest(['d', for (final c in _sel) cardCode(c)])) {
      setState(_sel.clear);
      return;
    }
    _g.discard(_sel.toList());
    _app.sfx.play(Sound.card);
    _choice = skatChooseGame(_g, [..._g.players[_me].hand, ..._g.skat]);
    setState(_sel.clear);
  }

  void _declare() {
    if (_sendIfGuest(['a', _choice.index, _schneider || _schwarz, _schwarz])) return;
    _g.declare(_choice, schneider: _schneider, schwarz: _schwarz);
    _app.sfx.play(Sound.chip);
    setState(() {
      _schneider = false;
      _schwarz = false;
    });
    _pump();
  }

  void _tapCard(PlayingCard c) {
    if (_g.phase == SkatPhase.discard && _humanDeclarer) {
      setState(() {
        if (!_sel.remove(c) && _sel.length < 2) _sel.add(c);
      });
      return;
    }
    if (!_myCard || !_g.legalCards(_me).contains(c)) return;
    if (_sendIfGuest(['p', _me, cardCode(c)])) return;
    _g.play(_me, c);
    _app.sfx.play(Sound.card);
    setState(() {});
    _pump();
  }

  void _next() {
    if (_guest != null) return;
    _g.nextDeal();
    setState(() {
      _paid = false;
      _sel.clear();
    });
    _pump();
  }

  void _newMatch() {
    if (_guest != null) return;
    if (_host != null) {
      _hostStart();
      return;
    }
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _paid = false;
      _paidMatch = false;
      _earned = 0;
    });
    _pump();
  }

  String _role(int p) {
    final pos = p == _g.forehand ? 'Vorhand' : (p == _g.middlehand ? 'Mittelhand' : 'Hinterhand');
    if (_g.declarer < 0) return pos;
    return p == _g.declarer ? 'Alleinspieler' : 'Gegenspieler';
  }

  String get _status {
    final g = _g;
    switch (g.phase) {
      case SkatPhase.bidding:
        if (_humanBid) {
          final listening = g.listening;
          return listening ? '${g.players[g.sayer].name} sagt ${g.bid}. Hältst du mit?' : 'Du reizt: ${g.askedValue} sagen oder passen?';
        }
        return g.lastEvent.isEmpty ? 'Gereizt wird' : g.lastEvent;
      case SkatPhase.skatChoice:
        return _humanDeclarer ? 'Du spielst für ${g.bid}. Skat aufnehmen oder Hand spielen?' : g.lastEvent;
      case SkatPhase.discard:
        return _humanDeclarer ? 'Wähle zwei Karten zum Drücken' : g.lastEvent;
      case SkatPhase.declare:
        if (!_humanDeclarer) return g.lastEvent;
        final all = [...g.players[_me].hand, ...g.skat];
        final v = g.baseGameValue(_choice, all, hand: g.hand);
        return 'Spiel ansagen: ${skatTypeNames[_choice]} ist mindestens $v wert${v < g.bid ? ' – überreizt!' : ''}';
      case SkatPhase.playing:
        if (_myCard) return '${g.lastEvent.isNotEmpty && g.trick.isEmpty && g.lastTrick.isEmpty ? '${g.lastEvent}. ' : ''}Du bist dran';
        return '${g.players[g.current].name} ist dran';
      case SkatPhase.dealOver:
      case SkatPhase.matchOver:
        return g.result?.text ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = _netScreen();
    return GameFrame(
      title: 'Skat',
      guide: skatGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF15553A), Color(0xFF082116)])),
      actions: [
        // Auf schmalen Handys ist die Leiste voll, dort gibt es den Knopf am Ende der Liste
        if (!_net && !_netPanel && MediaQuery.sizeOf(context).width >= 420)
          IconButton(
            tooltip: 'Im Netzwerk spielen',
            icon: const Icon(Icons.wifi),
            onPressed: () => setState(() => _netPanel = true),
          ),
      ],
      child: net ?? LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  // ---------------------------------------------------------------- Netzwerk: Gastgeber

  /// Neue Protokolleinträge an alle Mitspieler.
  void _broadcast() {
    final host = _host;
    if (host == null || !_netPlaying) return;
    final log = _g.actionLog;
    if (log.length <= _sent) return;
    host.lan.broadcast({'t': 'acts', 'from': _sent, 'acts': log.sublist(_sent)});
    _sent = log.length;
  }

  LanMessage _gameMessage(int me) => {'t': 'game', 'seed': _seed, 'names': _netNames, 'humans': _humans.toList(), 'me': me, 'log': _g.actionLog};

  Future<void> _openTable() async {
    final host = NetTableHost(game: skatNetGame, hostName: _displayName, info: 'Skat · 12 Spiele');
    host.onMove = _remoteMove;
    host.onLeave = _remoteLeft;
    try {
      await host.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _netMessage = 'Tisch konnte nicht eröffnet werden');
      await host.close();
      return;
    }
    _addresses = await localAddresses();
    _sub = host.changed.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _host = host;
      _netMessage = '';
    });
  }

  /// Neue Liste am eigenen Tisch: du auf Platz 0, bis zu zwei Mitspieler, den Rest spielen Computer.
  void _hostStart() {
    final host = _host!;
    final names = [_displayName];
    final humans = {0};
    for (final s in host.seats.values) {
      s.index = -1;
      if (names.length >= 3) continue;
      s.index = names.length;
      humans.add(s.index);
      names.add(s.name);
    }
    for (final bot in const ['Horst', 'Inge', 'Klaus']) {
      if (names.length >= 3) break;
      names.add(bot);
    }
    debugLog.info('netz', 'Skat startet mit ${humans.length - 1} Mitspielern');
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _netNames = names;
      _humans = humans;
      _me = 0;
      _g = SkatGame(rng: math.Random(_seed), names: names)..start();
      _netPlaying = true;
      _sent = _g.actionLog.length;
      _paid = false;
      _paidMatch = false;
      _earned = 0;
      _sel.clear();
    });
    for (final s in host.seats.values) {
      host.send(s, _gameMessage(s.index));
    }
    _pump();
  }

  void _remoteMove(NetSeat seat, LanMessage m) {
    if (!_netPlaying) return;
    if (m['t'] == 'sync') {
      _host?.send(seat, _gameMessage(seat.index));
      return;
    }
    if (m['t'] != 'act' || seat.index < 0 || !_humans.contains(seat.index)) return;
    final a = m['a'] as List;
    if (!skatAllowed(_g, seat.index, a)) {
      _host?.send(seat, _gameMessage(seat.index));
      return;
    }
    try {
      skatApply(_g, a);
    } catch (err) {
      debugLog.warn('netz', 'Ungültiger Zug von ${seat.name}: $err');
      return;
    }
    _app.sfx.play(a.first == 'p' || a.first == 'd' || a.first == 's' ? Sound.card : (a.first == 'a' ? Sound.chip : Sound.tick));
    if (!mounted) return;
    setState(() {});
    _pump();
  }

  void _remoteLeft(NetSeat seat) {
    if (!_netPlaying || seat.index < 0) return;
    // Für den Gegangenen spielt ab jetzt der Computer
    _humans.remove(seat.index);
    _pump();
    if (mounted) setState(() {});
  }

  Future<void> _closeNet() async {
    await _sub?.cancel();
    _sub = null;
    await _host?.close();
    await _guest?.close();
    await _browser?.close();
    if (!mounted) return;
    _host = null;
    _guest = null;
    _browser = null;
    _netPlaying = false;
    _netPanel = false;
    _netMessage = '';
    _me = 0;
    _humans = {0};
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _restore() ?? _make();
      _paid = false;
      _paidMatch = false;
      _sel.clear();
    });
    _pump();
  }

  // ---------------------------------------------------------------- Netzwerk: Mitspieler

  Future<void> _browse() async {
    final b = LanBrowser(skatNetGame);
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _netMessage = '';
    });
  }

  Future<void> _join(String address, int port) async {
    final guest = NetTableGuest(_displayName);
    guest.onMessage = _guestMessage;
    try {
      await guest.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _netMessage = 'Tisch nicht erreichbar');
      await guest.close();
      return;
    }
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    _sub = guest.changed.listen((_) {
      if (!mounted) return;
      if (!guest.lan.connected) _netMessage = 'Der Gastgeber hat den Tisch geschlossen';
      setState(() {});
    });
    setState(() {
      _guest = guest;
      _netPlaying = false;
      _netMessage = '';
    });
  }

  void _guestMessage(LanMessage m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'game':
        final me = (m['me'] as num).toInt();
        if (me < 0) {
          setState(() => _netMessage = 'Der Tisch ist voll, warte auf die nächste Liste');
          return;
        }
        final names = [for (final n in m['names'] as List) '$n'];
        final g = SkatGame(rng: math.Random((m['seed'] as num).toInt()), names: names)
          ..me = me
          ..start();
        try {
          for (final a in m['log'] as List) {
            skatApply(g, a as List);
          }
        } catch (err) {
          debugLog.warn('netz', 'Nachspielen fehlgeschlagen: $err');
        }
        final fresh = !_netPlaying || (m['log'] as List).isEmpty;
        setState(() {
          _seed = (m['seed'] as num).toInt();
          _netNames = names;
          _humans = {for (final h in m['humans'] as List) (h as num).toInt()};
          _me = me;
          _g = g;
          _netPlaying = true;
          if (fresh) {
            _paid = false;
            _paidMatch = false;
            _earned = 0;
          }
          _sel.clear();
        });
        _app.sfx.play(Sound.card);
        _pump();
      case 'acts':
        if (!_netPlaying) return;
        final from = (m['from'] as num).toInt();
        final acts = m['acts'] as List;
        final have = _g.actionLog.length;
        if (from > have) {
          _guest?.send({'t': 'sync'});
          return;
        }
        final phaseBefore = _g.phase;
        try {
          for (final a in acts.skip(have - from)) {
            skatApply(_g, a as List);
            final k = a.first;
            _app.sfx.play(k == 'p' || k == 'd' || k == 's' ? Sound.card : (k == 'a' ? Sound.chip : Sound.tick));
          }
        } catch (err) {
          debugLog.warn('netz', 'Zug passt nicht: $err');
          _guest?.send({'t': 'sync'});
          return;
        }
        if (phaseBefore == SkatPhase.dealOver && _g.phase == SkatPhase.bidding) _paid = false;
        if (_humanDeclarer && _g.phase == SkatPhase.declare) _choice = skatChooseGame(_g, [..._g.players[_me].hand, ..._g.skat]);
        setState(_sel.clear);
        _pump();
    }
  }

  void _saveName(String v) {
    _name = v;
    _store.saveGame('netz', {'name': v});
  }

  /// Was statt des Tischs gezeigt wird, solange das Netzwerk eingerichtet wird.
  Widget? _netScreen() {
    final guest = _guest;
    if (guest != null) {
      if (!_netPlaying || !guest.lan.connected) return NetGuestWaiting(guest: guest, onLeave: _closeNet, message: _netMessage);
      return null;
    }
    if (_browser != null) {
      return NetBrowsePanel(tables: _tables, manual: _manual, onJoin: _join, onBack: _closeNet, message: _netMessage);
    }
    final host = _host;
    if (host != null && !_netPlaying) {
      return NetHostLobby(
        host: host,
        addresses: _addresses,
        bots: 2 - math.min(2, host.seats.length),
        maxBots: 2 - math.min(2, host.seats.length),
        onBots: (_) {},
        onStart: _hostStart,
        onClose: _closeNet,
        startLabel: 'Liste starten',
      );
    }
    if (_netPanel) {
      return NetStartPanel(
        name: _name,
        onName: _saveName,
        onHost: _openTable,
        onBrowse: _browse,
        onBack: () => setState(() => _netPanel = false),
        message: _netMessage,
        hint: 'Alle Geräte im selben WLAN, drei Plätze. Freie Plätze spielen Computer.',
      );
    }
    return null;
  }

  Widget _layout(BoxConstraints box) {
    final g = _g;
    final w = box.maxWidth;
    final cw = math.min(78.0, w / 7.5);
    final pal = Palette.of(context);
    final over = g.phase == SkatPhase.dealOver || g.phase == SkatPhase.matchOver;
    final showTrick = g.trick.isNotEmpty ? g.trick : g.lastTrick;
    final starter = g.trick.isNotEmpty ? g.trickStarter : (g.lastTrickWinner < 0 ? 0 : _lastStarter);
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final p in [(_me + 1) % 3, (_me + 2) % 3])
                    OpponentBadge(
                      name: g.players[p].name,
                      cardCount: g.players[p].hand.length,
                      active: (g.phase == SkatPhase.playing && g.current == p) || (g.phase == SkatPhase.bidding && g.bidTurn == p),
                      detail: '${_role(p)} · ${g.players[p].score}',
                      width: math.min(150, w / 2.6),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                // Im Querformat ist hier wenig Platz: lieber verkleinern als abschneiden
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (g.phase == SkatPhase.playing)
                      Text(
                        '${skatTypeNames[g.type]}${g.hand ? ' Hand' : ''} · ${g.declarer == _me ? 'du spielst' : '${g.players[g.declarer].name} spielt'}',
                        style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700),
                      ),
                    if (g.phase == SkatPhase.bidding) Text('Gereizt: ${g.bid == 0 ? '–' : g.bid}', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < showTrick.length; i++)
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Column(
                              children: [
                                Opacity(opacity: g.trick.isEmpty ? 0.6 : 1, child: PlayingCardView(width: cw, card: showTrick[i])),
                                Text(g.players[(starter + i) % 3].name, style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (g.phase == SkatPhase.declare && _humanDeclarer) ConstrainedBox(constraints: BoxConstraints(maxWidth: w), child: _declarePanel(pal)),
                  ],
                ),
                ),
              ),
            ),
            Text('Du · ${_role(_me)} · ${g.players[_me].score} Punkte · Spiel ${math.min(g.dealsPlayed + 1, g.deals)} von ${g.deals}',
                style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
            SizedBox(height: 46, child: Center(child: Wrap(spacing: 8, children: _buttons()))),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: HandFan(
                cards: g.players[_me].hand,
                // Auch nach der Höhe richten, sonst ragt die Hand im Querformat über den Rand
                maxCardWidth: math.min(math.min(80.0, w / 7), math.max(40.0, (box.maxHeight - 240) / 1.5)),
                isRaised: _sel.contains,
                isEnabled: (c) => !_myCard || g.legalCards(_me).contains(c),
                onTap: _tapCard,
              ),
            ),
          ],
        ),
        if (over) Positioned.fill(child: _resultPanel(pal)),
      ],
    );
  }

  int get _lastStarter {
    // Wer den letzten Stich anfing: der Gewinner davor; aus der Anzeige reicht eine Schätzung
    final w = _g.lastTrickWinner;
    final idx = trickWinner(_g.lastTrick, _g.type);
    return (w - idx + 3) % 3;
  }

  List<Widget> _buttons() {
    final g = _g;
    if (_humanBid) {
      final listening = g.listening;
      return [
        ActionButton(primary: true, label: listening ? 'Ja (${g.bid})' : 'Sage ${g.askedValue}', onPressed: _bidYes),
        ActionButton(label: 'Passe', onPressed: _bidPass),
      ];
    }
    if (g.phase == SkatPhase.skatChoice && _humanDeclarer) {
      return [
        ActionButton(primary: true, label: 'Skat aufnehmen', onPressed: _takeSkat),
        ActionButton(label: 'Hand spielen', onPressed: _playHand),
      ];
    }
    if (g.phase == SkatPhase.discard && _humanDeclarer) {
      return [ActionButton(primary: true, label: 'Drücken', onPressed: _sel.length == 2 ? _discard : null)];
    }
    if (g.phase == SkatPhase.declare && _humanDeclarer) {
      return [ActionButton(primary: true, label: 'Spielen', onPressed: _declare)];
    }
    return [];
  }

  Widget _declarePanel(Palette pal) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: pal.panel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final t in SkatType.values)
                ChoiceChip(label: Text(skatTypeNames[t]!), selected: _choice == t, onSelected: (_) => setState(() => _choice = t)),
            ],
          ),
          if (_g.hand && _choice != SkatType.nullGame)
            Wrap(
              spacing: 6,
              children: [
                FilterChip(label: const Text('Schneider ansagen'), selected: _schneider || _schwarz, onSelected: (v) => setState(() => _schneider = v)),
                FilterChip(label: const Text('Schwarz ansagen'), selected: _schwarz, onSelected: (v) => setState(() => _schwarz = v)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resultPanel(Palette pal) {
    final g = _g;
    final r = g.result;
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: pal.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.panelEdge, width: 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r?.text ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final l in r?.lines ?? const <String>[]) Text(l, style: TextStyle(color: pal.ink)),
                if (r != null && r.declarer >= 0)
                  Text('${r.points >= 0 ? '+' : '−'}${r.points.abs()} für ${g.players[r.declarer].name}',
                      style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)),
                if (r != null && r.declarer == _me && r.won)
                  Text('+${skatWinCoins(r.value)} Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                if (r != null && r.declarer >= 0 && g.skat.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Im Skat:', style: TextStyle(color: pal.inkSoft)),
                  Row(mainAxisSize: MainAxisSize.min, children: [for (final c in g.skat) Padding(padding: const EdgeInsets.all(2), child: PlayingCardView(width: 40, card: c))]),
                ],
                const SizedBox(height: 8),
                Text([for (final p in g.players) '${p.name} ${p.score}'].join(' · '), style: TextStyle(color: pal.inkSoft)),
                if (g.phase == SkatPhase.matchOver) ...[
                  const SizedBox(height: 6),
                  Text(g.ranking().first == _me ? 'Du gewinnst die Liste!' : '${g.players[g.ranking().first].name} gewinnt die Liste',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_earned > 0) Text('Verdient: $_earned Münzen', style: const TextStyle(color: Color(0xFFFFC95C))),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  if (_guest != null)
                    const ActionButton(label: 'Warte auf den Gastgeber', onPressed: null)
                  else
                    ActionButton(
                      primary: true,
                      label: g.phase == SkatPhase.matchOver ? 'Neue Liste' : 'Nächstes Spiel',
                      onPressed: g.phase == SkatPhase.matchOver ? _newMatch : _next,
                    ),
                  if (_net)
                    ActionButton(label: 'Tisch verlassen', onPressed: _closeNet)
                  else if (g.phase == SkatPhase.matchOver)
                    ActionButton(label: 'Im Netzwerk', onPressed: () => setState(() => _netPanel = true)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
