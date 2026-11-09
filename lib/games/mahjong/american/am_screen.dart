import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/scope.dart';
import '../../../core/settings.dart';
import '../../../core/sfx.dart';
import '../../../core/theme.dart';
import '../../../ui/guide.dart';
import '../../../ui/widgets.dart';
import '../tiles.dart';
import 'am_card.dart';
import 'am_engine.dart';

const amPlaceRewards = [300, 120, 40, 0];

int amHandReward(AmResult r) => math.min(200, 20 + (r.hand?.hand.value ?? 0) * (r.jokerless ? 2 : 1) * 2);

const _suitColors = {'A': Color(0xFF1F4E9A), 'B': Color(0xFFC62828), 'C': Color(0xFF1B7A3E)};

/// Kartenhand als farbiger Text: gleiche Farbe heißt gleiche Mahjong-Farbe.
Widget amHandLabel(AmHand h, {double size = 15, Color? ink}) {
  return Text.rich(
    TextSpan(
      children: [
        for (final s in h.specs) ...[
          TextSpan(
            text: _specText(s),
            style: TextStyle(
              color: s.suit.isEmpty ? (s.code == 'F' ? const Color(0xFF8E24AA) : ink) : _suitColors[s.suit],
              fontWeight: FontWeight.w800,
              fontSize: size,
            ),
          ),
          const TextSpan(text: '  '),
        ],
      ],
    ),
  );
}

String _specText(AmSpec s) {
  final c = switch (s.code) { 'Wh' => '0', 'R' || 'G' => 'D', _ => s.code };
  if (c.startsWith('n')) {
    final off = c.length > 1 ? c.substring(1) : '';
    return List.filled(s.count, 'n$off').join(' ');
  }
  return List.filled(s.count, c).join();
}

Future<void> showAmCard(BuildContext context, {List<(AmConcrete, int)> near = const []}) {
  final p = Palette.of(context);
  final nearIdx = {for (final n in near) n.$1.index: n.$2};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.panel,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Glückskarte', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Gleiche Farbe der Schrift heißt gleiche Mahjong-Farbe, verschiedene Farben heißen verschiedene. n ist eine Zahl, die du wählst. '
            'D ist der Drache der Farbe (Zeichen rot, Kreise weiß, Bambus grün), 0 ist der Weiße Drache, F eine Blume. '
            'X: aufdecken erlaubt, C: nur verdeckt.',
            style: TextStyle(color: p.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < amCard.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: nearIdx.containsKey(i) ? p.accent.withValues(alpha: 0.18) : null,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.panelEdge),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(amCard[i].category, style: TextStyle(color: p.inkSoft, fontSize: 12)),
                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: amHandLabel(amCard[i], ink: p.ink)),
                        if (nearIdx.containsKey(i))
                          Text('Dir fehlen ${nearIdx[i]} Steine', style: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Text(
                    '${amCard[i].concealed ? 'C' : 'X'} ${amCard[i].value}',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class AmScreen extends StatefulWidget {
  const AmScreen({super.key, this.guide, this.seed});
  final GameGuide? guide;
  final int? seed;

  @override
  State<AmScreen> createState() => _AmScreenState();
}

class _AmScreenState extends State<AmScreen> {
  late AmGame _g;
  late math.Random _rng;
  int? _selected;
  final Set<int> _pick = {};
  bool _running = false;
  bool _rewarded = false;
  bool _handPaid = false;
  int _earned = 0;
  Map<int, AmClaim> _pending = {};
  String _nearKey = '';
  List<(AmConcrete, int)> _near = [];

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  AmPlayer get _me => _g.players[0];

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
  static const _saveId = 'american';
  bool get _saving => widget.seed == null;

  AmGame _make() => AmGame(rng: math.Random(_seed))..start();

  /// Gespeicherte Partie nachspielen.
  AmGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      final g = _make();
      for (final a in d['log'] as List) {
        amApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _handPaid = g.phase == AmPhase.handOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (_) {
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
    if (_g.phase == AmPhase.gameOver || _g.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'seed': _seed, 'log': _g.actionLog, 'earned': _earned, 'paid': _handPaid ? _g.actionLog.length : -1});
  }

  void _newGame() {
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _selected = null;
      _pick.clear();
      _rewarded = false;
      _handPaid = false;
      _earned = 0;
      _pending = {};
    });
    _app.sfx.play(Sound.card);
  }

  bool get _humanClaim => _g.phase == AmPhase.claim && _g.claims.containsKey(0);
  bool get _myTurn => !_running && _g.phase == AmPhase.discard && _g.current == 0;

  List<(AmConcrete, int)> get _nearHands {
    final key = '${_me.hand.join(',')}|${_me.exposed.length}';
    if (key != _nearKey) {
      _nearKey = key;
      _near = amTargets(_me.hand, _me.exposed, limit: 3);
    }
    return _near;
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      if (_g.phase == AmPhase.handOver) {
        _payHand();
        break;
      }
      if (_g.phase == AmPhase.gameOver) {
        _payGame();
        break;
      }
      if (_g.phase == AmPhase.charleston) break;
      if (_g.phase == AmPhase.discard) {
        if (_g.current == 0) break;
        await Future<void>.delayed(_app.settings.botDelay(650));
        if (!mounted) return;
        final p = _g.current;
        switch (amBotTurn(_g, p, _rng)) {
          case AmBotMahjong():
            _g.mahjong(p);
            _app.sfx.play(Sound.lose);
          case AmBotSwap(:final owner, :final index):
            _g.swapJoker(p, owner, index);
            _app.sfx.play(Sound.chip);
          case AmBotDiscard(:final tile):
            _g.discard(p, tile);
            _app.sfx.play(Sound.tick);
        }
        setState(() {});
        continue;
      }
      if (_g.phase == AmPhase.claim) {
        final choices = <int, AmClaim>{};
        for (final e in _g.claims.entries) {
          if (e.key != 0) choices[e.key] = amBotClaim(_g, e.key, e.value);
        }
        if (_g.claims.containsKey(0)) {
          _pending = choices;
          setState(() {});
          break;
        }
        if (choices.values.any((c) => !c.isPass)) {
          await Future<void>.delayed(_app.settings.botDelay(300));
          if (!mounted) return;
        }
        _g.resolveClaims(choices);
        setState(() {});
        continue;
      }
    }
    _running = false;
    if (mounted) setState(() {});
  }

  void _payHand() {
    if (_handPaid) return;
    _handPaid = true;
    final r = _g.result;
    if (r != null && r.winner == 0) {
      final coins = amHandReward(r);
      _earned += coins;
      _app.wallet.credit(coins);
      _app.sfx.play(Sound.win);
    }
  }

  void _payGame() {
    if (_rewarded) return;
    _rewarded = true;
    final place = _g.ranking().indexOf(0);
    final coins = amPlaceRewards[place];
    if (coins > 0) {
      _earned += coins;
      _app.wallet.credit(coins);
      _app.sfx.play(place == 0 ? Sound.bigWin : Sound.coin);
    }
  }

  void _nextHand() {
    _g.nextHand();
    setState(() {
      _handPaid = false;
      _selected = null;
      _pick.clear();
    });
    _pump();
  }

  void _tapTile(int t, int index) {
    if (_g.phase == AmPhase.charleston) {
      if (t == jokerKind) return;
      setState(() {
        if (!_pick.remove(index) && _pick.length < 3) _pick.add(index);
      });
      return;
    }
    if (!_myTurn || !_g.canDiscard(0, t)) return;
    if (_selected == t) {
      _g.discard(0, t);
      _app.sfx.play(Sound.tick);
      setState(() => _selected = null);
      _pump();
    } else {
      setState(() => _selected = t);
    }
  }

  List<int> get _picked {
    final hand = [..._me.hand]..sort();
    return [for (final i in _pick) if (i < hand.length) hand[i]];
  }

  void _pass() {
    final tiles = _picked;
    if (!_g.validPass(0, tiles)) return;
    _g.submitPass(0, tiles);
    _app.sfx.play(Sound.card);
    setState(() => _pick.clear());
    _pump();
  }

  void _suggest() {
    final hand = [..._me.hand]..sort();
    final used = <int>{};
    for (final t in _g.botPass(0, _rng)) {
      for (var i = 0; i < hand.length; i++) {
        if (hand[i] == t && !used.contains(i)) {
          used.add(i);
          break;
        }
      }
    }
    setState(() {
      _pick
        ..clear()
        ..addAll(used);
    });
  }

  void _mahjong() {
    if (!_g.canMahjong(0)) return;
    _g.mahjong(0);
    setState(() {});
    _pump();
  }

  void _swap() {
    final s = _g.jokerSwaps(0);
    if (s.isEmpty) return;
    _g.swapJoker(0, s.first.$1, s.first.$2);
    _app.sfx.play(Sound.chip);
    setState(() {});
  }

  void _claim(AmClaim c) {
    if (!_humanClaim) return;
    final choices = {..._pending, 0: c};
    _pending = {};
    _g.resolveClaims(choices);
    _app.sfx.play(c.isPass ? Sound.tick : Sound.chip);
    setState(() => _selected = null);
    _pump();
  }

  String get _status {
    if (_g.phase == AmPhase.gameOver) return 'Das Spiel ist vorbei';
    if (_g.phase == AmPhase.handOver) return _g.result?.text ?? '';
    if (_g.phase == AmPhase.charleston) {
      return 'Charleston ${_g.charlestonStep + 1} von 3: Gib drei Steine ${charlestonNames[_g.charlestonStep]} weiter';
    }
    if (_humanClaim) return '${_g.players[_g.lastDiscarder].name} wirft ${tileName(_g.lastDiscard!)} ab. Willst du ihn?';
    final near = _nearHands;
    final hint = near.isEmpty ? '' : ' · Am nächsten: ${near.first.$1.hand.category} (es fehlen ${near.first.$2})';
    if (_myTurn) {
      if (_g.canMahjong(0)) return 'Deine Hand passt zur Karte! Mahjong?';
      return '${_g.lastEvent.isNotEmpty ? '${_g.lastEvent}. ' : ''}Du bist dran$hint';
    }
    return '${_g.lastEvent.isNotEmpty ? _g.lastEvent : '${_g.players[_g.current].name} ist dran'}$hint';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'American Mahjong',
      guide: widget.guide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1F3F6B), Color(0xFF0C1A2B)]),
      ),
      child: LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _exposures(int p, double tw) => Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final e in _g.players[p].exposed)
            Row(mainAxisSize: MainAxisSize.min, children: [for (final t in e.tiles) TileView(tile: t, width: tw)]),
        ],
      );

  Widget _seat(int p, double tw, int perRow) {
    final pl = _g.players[p];
    final pal = Palette.of(context);
    final active = _g.current == p && _g.phase == AmPhase.discard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: active ? pal.accent : const Color(0x88000000), borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${pl.name} · ${formatCoins(pl.points)}${p == _g.dealer ? ' · Geber' : ''}',
            style: TextStyle(color: active ? pal.onAccent : const Color(0xFFF6E7C8), fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 3),
        if (p != 0) _exposures(p, tw * 0.9),
        SizedBox(
          width: perRow * (tw + 1),
          child: Wrap(spacing: 1, runSpacing: 1, children: [for (final t in pl.discards) TileView(tile: t, width: tw)]),
        ),
      ],
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.2;
    final handW = landscape ? math.min(math.min((w - 40) / 17, h * 0.085), 52.0) : math.min((w - 16) / 16.2, 44.0);
    final pondW = landscape ? math.min(handW * 0.6, h * 0.045) : math.min(handW * 0.62, (w - 140) / 13);
    final perRow = landscape ? 8 : 6;
    Widget seat(int p) => FittedBox(fit: BoxFit.scaleDown, child: _seat(p, pondW, perRow));
    final table = Column(
      children: [
        Expanded(flex: 2, child: seat(2)),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(child: Center(child: seat(3))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Hand ${_g.handsPlayed + 1} von ${AmGame.hands}',
                        style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${_g.wall.length} Steine', style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(child: Center(child: seat(1))),
            ],
          ),
        ),
        Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: _seat(0, pondW, landscape ? 12 : 9))),
      ],
    );
    final overlay = _g.phase == AmPhase.handOver || _g.phase == AmPhase.gameOver;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.all(4), child: table)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
            _actions(),
            Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 8), child: _hand(handW)),
          ],
        ),
        if (overlay) Positioned.fill(child: _resultPanel()),
      ],
    );
  }

  Widget _actions() {
    final b = <Widget>[ActionButton(label: 'Karte', onPressed: () => showAmCard(context, near: _nearHands))];
    if (_g.phase == AmPhase.charleston) {
      b.add(ActionButton(label: 'Vorschlag', onPressed: _suggest));
      b.add(ActionButton(primary: true, label: 'Weitergeben', onPressed: _g.validPass(0, _picked) ? _pass : null));
    } else if (_humanClaim) {
      for (final o in _g.claims[0]!) {
        final label = o.mahjong ? 'Mahjong!' : const {3: 'Pung', 4: 'Kong', 5: 'Fünfling'}[o.count]!;
        b.add(ActionButton(primary: o.mahjong, label: label, onPressed: () => _claim(o)));
      }
      b.add(ActionButton(label: 'Weiter', onPressed: () => _claim(const AmClaim.pass())));
    } else if (_myTurn) {
      if (_g.canMahjong(0)) b.add(ActionButton(primary: true, label: 'Mahjong!', onPressed: _mahjong));
      if (_g.jokerSwaps(0).isNotEmpty) b.add(ActionButton(label: 'Joker holen', onPressed: _swap));
    }
    return SizedBox(
      height: 46,
      child: Center(child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: b)),
    );
  }

  Widget _hand(double tw) {
    final sorted = [..._me.hand]..sort();
    final drawn = _g.current == 0 && _g.phase == AmPhase.discard ? _g.drawn : null;
    final charleston = _g.phase == AmPhase.charleston;
    Widget tile(int t, int index) {
      final sel = charleston ? _pick.contains(index) : _selected == t;
      return GestureDetector(
        onTap: () => _tapTile(t, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.only(bottom: sel ? 10 : 0, top: sel ? 0 : 10),
          child: TileView(tile: t, width: tw, depth: tw * 0.08, selected: sel, dim: charleston && t == jokerKind),
        ),
      );
    }

    final children = <Widget>[];
    if (charleston || drawn == null) {
      for (var i = 0; i < sorted.length; i++) {
        children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: tile(sorted[i], i)));
      }
    } else {
      final rest = [...sorted]..remove(drawn);
      for (final t in rest) {
        children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: tile(t, -1)));
      }
      children.addAll([SizedBox(width: tw * 0.4), tile(drawn, -1)]);
    }
    if (_me.exposed.isNotEmpty) children.addAll([SizedBox(width: tw * 0.5), _exposures(0, tw * 0.8)]);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children),
    );
  }

  Widget _resultPanel() {
    final pal = Palette.of(context);
    final over = _g.phase == AmPhase.gameOver;
    final r = _g.result;
    final c = <Widget>[];
    if (over) {
      final order = _g.ranking();
      c.add(Text('Endstand', style: Theme.of(context).textTheme.titleLarge));
      for (var i = 0; i < 4; i++) {
        final p = order[i];
        c.add(Text(
          '${i + 1}. ${_g.players[p].name}: ${formatCoins(_g.players[p].points)}${p == 0 && amPlaceRewards[i] > 0 ? ' · +${amPlaceRewards[i]} Münzen' : ''}',
          style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: p == 0 ? FontWeight.w700 : FontWeight.w500),
        ));
      }
      if (_earned > 0) c.add(Text('Verdient: ${formatCoins(_earned)} Münzen', style: TextStyle(color: pal.inkSoft)));
      c.add(const SizedBox(height: 10));
      c.add(ActionButton(primary: true, label: 'Neues Spiel', onPressed: _newGame));
    } else if (r != null) {
      c.add(Text(r.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium));
      if (r.hand != null) {
        c.add(const SizedBox(height: 6));
        c.add(FittedBox(child: Row(mainAxisSize: MainAxisSize.min, children: [for (final t in r.tiles) TileView(tile: t, width: 26)])));
        c.add(const SizedBox(height: 6));
        c.add(Text('${r.hand!.hand.category}: ${r.hand!.hand.value} Punkte${r.jokerless ? ', ohne Joker doppelt' : ''}',
            style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)));
        c.add(FittedBox(child: amHandLabel(r.hand!.hand, ink: pal.ink)));
        if (r.winner == 0) {
          c.add(Text('+${amHandReward(r)} Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)));
        }
      }
      c.add(const SizedBox(height: 6));
      for (var p = 0; p < 4; p++) {
        final ch = r.changes[p];
        c.add(Text(
          '${_g.players[p].name}: ${formatCoins(_g.players[p].points)}${ch == 0 ? '' : ' (${ch > 0 ? '+' : '−'}${formatCoins(ch.abs())})'}',
          style: TextStyle(color: pal.ink, fontSize: 14),
        ));
      }
      c.add(const SizedBox(height: 10));
      c.add(ActionButton(primary: true, label: _g.gameWillEnd ? 'Zum Endstand' : 'Nächste Hand', onPressed: _nextHand));
    }
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.panelEdge, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: c),
          ),
        ),
      ),
    );
  }
}
