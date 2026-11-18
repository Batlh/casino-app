import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'skat_bot.dart';
import 'skat_engine.dart';

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

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
    _seed = widget.seed ?? math.Random.secure().nextInt(1 << 31);
    _g = _restore() ?? _make();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  late int _seed;
  static const _saveId = 'skat';
  bool get _saving => widget.seed == null;

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
  }

  @override
  void dispose() {
    _persist();
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

  bool get _humanBid => _g.phase == SkatPhase.bidding && _g.bidTurn == 0;
  bool get _humanDeclarer => _g.declarer == 0;
  bool get _myCard => _g.phase == SkatPhase.playing && _g.current == 0 && !_running;

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      final ph = _g.phase;
      if (ph == SkatPhase.dealOver || ph == SkatPhase.matchOver) {
        _pay();
        break;
      }
      if (ph == SkatPhase.bidding) {
        if (_g.bidTurn == 0) break;
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
        if (_humanDeclarer) {
          if (ph == SkatPhase.declare) _choice = skatChooseGame(_g, [..._g.players[0].hand, ..._g.skat]);
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
        if (_g.current == 0) break;
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
      if (r.declarer == 0 && r.won) {
        final coins = skatWinCoins(r.value);
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.win);
      } else if (r.declarer > 0 && !r.won) {
        _app.sfx.play(Sound.coin);
      }
    }
    if (_g.phase == SkatPhase.matchOver && !_paidMatch) {
      _paidMatch = true;
      final coins = skatPlaceCoins[_g.ranking().indexOf(0)];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.bigWin);
      }
    }
  }

  void _bidYes() {
    _g.bidYes(0);
    _app.sfx.play(Sound.tick);
    setState(() {});
    _pump();
  }

  void _bidPass() {
    _g.bidPass(0);
    _app.sfx.play(Sound.tick);
    setState(() {});
    _pump();
  }

  void _takeSkat() {
    _g.takeSkat();
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
  }

  void _playHand() {
    _g.playHand();
    _choice = skatChooseGame(_g, _g.players[0].hand);
    setState(() {});
  }

  void _discard() {
    _g.discard(_sel.toList());
    _app.sfx.play(Sound.card);
    _choice = skatChooseGame(_g, [..._g.players[0].hand, ..._g.skat]);
    setState(_sel.clear);
  }

  void _declare() {
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
    if (!_myCard || !_g.legalCards(0).contains(c)) return;
    _g.play(0, c);
    _app.sfx.play(Sound.card);
    setState(() {});
    _pump();
  }

  void _next() {
    _g.nextDeal();
    setState(() {
      _paid = false;
      _sel.clear();
    });
    _pump();
  }

  void _newMatch() {
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
        final all = [...g.players[0].hand, ...g.skat];
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
    return GameFrame(
      title: 'Skat',
      guide: skatGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF15553A), Color(0xFF082116)])),
      child: LayoutBuilder(builder: (context, box) => _layout(box)),
    );
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
                  for (final p in [1, 2])
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
                        '${skatTypeNames[g.type]}${g.hand ? ' Hand' : ''} · ${g.declarer == 0 ? 'du spielst' : '${g.players[g.declarer].name} spielt'}',
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
            Text('Du · ${_role(0)} · ${g.players[0].score} Punkte · Spiel ${math.min(g.dealsPlayed + 1, g.deals)} von ${g.deals}',
                style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
            SizedBox(height: 46, child: Center(child: Wrap(spacing: 8, children: _buttons()))),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: HandFan(
                cards: g.players[0].hand,
                // Auch nach der Höhe richten, sonst ragt die Hand im Querformat über den Rand
                maxCardWidth: math.min(math.min(80.0, w / 7), math.max(40.0, (box.maxHeight - 240) / 1.5)),
                isRaised: _sel.contains,
                isEnabled: (c) => !_myCard || g.legalCards(0).contains(c),
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
                if (r != null && r.declarer == 0 && r.won)
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
                  Text(g.ranking().first == 0 ? 'Du gewinnst die Liste!' : '${g.players[g.ranking().first].name} gewinnt die Liste',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_earned > 0) Text('Verdient: $_earned Münzen', style: const TextStyle(color: Color(0xFFFFC95C))),
                ],
                const SizedBox(height: 10),
                ActionButton(
                  primary: true,
                  label: g.phase == SkatPhase.matchOver ? 'Neue Liste' : 'Nächstes Spiel',
                  onPressed: g.phase == SkatPhase.matchOver ? _newMatch : _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
