import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/debug_log.dart';
import '../../../core/scope.dart';
import '../../../core/settings.dart';
import '../../../core/sfx.dart';
import '../../../core/theme.dart';
import '../../../ui/guide.dart';
import '../../../ui/net_replay_mixin.dart';
import '../../../ui/widgets.dart';
import '../../cards/card_widgets.dart';
import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_bot.dart';
import 'mj_engine.dart';
import 'mj_rules.dart';
import 'mj_scoring.dart' show vietBonusPhan;
import 'mj_shape.dart';
import '../../../ui/tap_catcher.dart';
import '../tile_legend.dart';

const suitNames = ['Zeichen', 'Kreise', 'Bambus'];

/// Münzen für eigene Siege: ungefähr wie beim Riichi, umgerechnet auf die Einheit der Variante.
int mjHandReward(MjRules r, MjScore s) {
  final units = switch (r.variant) {
    MjVariant.mcr => s.core ~/ 4,
    MjVariant.zungJung => s.points ~/ 15,
    MjVariant.western => s.points ~/ 40,
    MjVariant.filipino => s.points ~/ 2,
    MjVariant.korean => s.core,
    MjVariant.taiwan => s.points,
    MjVariant.vietnam => s.points >= 32 ? 6 * (s.points ~/ 32) : s.points ~/ 2,
    _ => s.points * 2,
  };
  return math.min(200, 20 + 10 * units);
}

List<int> mjPlaceRewards(int players) => players == 3 ? const [250, 80, 0] : const [300, 120, 40, 0];

class MjScreen extends StatefulWidget {
  const MjScreen({super.key, required this.rules, this.guide, this.seed});
  final MjRules rules;
  final GameGuide? guide;
  final int? seed;

  @override
  State<MjScreen> createState() => _MjScreenState();
}

class _MjScreenState extends State<MjScreen> with NetReplayScreen {
  late MjGame _g;
  late math.Random _rng;
  int? _selected;
  final Set<int> _exchangePick = {};
  bool _running = false;
  bool _rewarded = false;
  bool _handPaid = false;
  bool _fast = false;
  int _earned = 0;
  Map<int, MjOption> _pending = {};
  String _waitKey = '';
  List<int> _waitCache = [];

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  MjPlayer get _me => _g.players[_ms];

  /// Dein Platz: allein 0, im Netz je Gerät verschieden.
  int get _ms => replayActive ? replayMe : 0;

  /// Platz [k] Schritte rechts von dir (für die Sitzordnung am Bildschirm).
  int _rel(int k) => (_ms + k) % _g.n;

  /// Spielt hier der Computer diesen Platz (im Netz nur beim Gastgeber)?
  bool _botHere(int p) => replayActive ? replayIsHost && replayIsBot(p) : p != 0;
  MjRules get _r => widget.rules;

  /// Startwert für die Mauer; die Computer würfeln getrennt davon.
  late int _seed;
  String get _saveId => 'mj.${_r.variant.name}';
  bool get _saving => widget.seed == null && !replayActive;

  MjGame _make() => MjGame(_r, rng: math.Random(_seed))..start();

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
    _seed = widget.seed ?? math.Random.secure().nextInt(1 << 31);
    _g = _restore() ?? _make();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  /// Gespeicherte Partie nachspielen.
  MjGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      final g = _make();
      for (final a in d['log'] as List) {
        mjApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _handPaid = g.phase == MjPhase.handOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (e, st) {
      debugLog.error('mahjong.spielstand', e, st);
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
    replayDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get replayGame => _saveId;
  @override
  String get replayTitle => _r.title;
  @override
  int get replaySeats => _r.players;
  @override
  List<String> get replayBotNames => const ['Mei', 'Jun', 'Lan'];
  @override
  List<List<Object?>> get replayLog => _g.actionLog;

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _seed = seed;
    _g = MjGame(_r, rng: math.Random(seed), names: names, humans: replayHumans, me: me)..start();
    _selected = null;
    _exchangePick.clear();
    _rewarded = false;
    _handPaid = false;
    _fast = false;
    _earned = 0;
    _pending = {};
    _running = false;
    _claimLog = -1;
    _claimSent = false;
  }

  @override
  void replayApply(List<dynamic> a) {
    if (a[0] == 'cl') {
      _startClaimRound();
      _pending[(a[1] as num).toInt()] = MjOption(MjClaimType.values[(a[2] as num).toInt()], [for (final t in a.sublist(3)) (t as num).toInt()]);
      _resolveIfComplete();
      return;
    }
    mjApply(_g, a);
  }

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    int i(int k) => (a[k] as num).toInt();
    if (a.length < 2 || i(1) != seat) return false;
    switch (a[0]) {
      case 'cl':
        if (_g.phase != MjPhase.claim || _pending.containsKey(seat)) return false;
        final opts = _g.claims[seat];
        if (opts == null) return false;
        final type = MjClaimType.values[i(2)];
        if (type == MjClaimType.pass) return true;
        final tiles = [for (final t in a.sublist(3)) (t as num).toInt()];
        return opts.any((o) => o.type == type && o.tiles.join(',') == tiles.join(','));
      case 'd':
        return _g.phase == MjPhase.discard && _g.current == seat && _g.canDiscard(seat, i(2));
      case 't':
        return _g.phase == MjPhase.discard && _g.current == seat && _g.canTsumo(seat);
      case 'k':
        return _g.phase == MjPhase.discard && _g.current == seat && _g.kanOptions(seat).contains(i(2));
      case 'j':
        return _g.phase == MjPhase.discard && _g.current == seat && _g.declarableJokers(seat).contains(i(2));
      case 'x':
        return _g.phase == MjPhase.exchange && _g.players[seat].exchange.length != 3 &&
            _g.validExchange([for (final t in a[2] as List) (t as num).toInt()]);
      case 'v':
        return _g.phase == MjPhase.voidChoice && _g.players[seat].voidSuit == null;
    }
    return false;
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    if (acts.isNotEmpty) _app.sfx.play(Sound.tick);
    if (_g.phase != MjPhase.handOver && _g.phase != MjPhase.gameOver) _handPaid = false;
    if (_selected != null && !_me.hand.contains(_selected)) _selected = null;
    setState(() {});
    _pump();
  }

  @override
  void replayClosed() => _newGame();

  /// Zug ausführen: allein und beim Gastgeber sofort, als Mitspieler über den Gastgeber.
  void _do(List<Object?> a) {
    if (replaySend(a)) return;
    mjApply(_g, a);
    replayBroadcast();
  }

  /// Neue Ansagerunde (erkannt am Protokoll): Computer entscheiden sofort, Menschen wählen selbst.
  void _startClaimRound() {
    if (_g.phase != MjPhase.claim || _claimLog == _g.actionLog.length) return;
    _claimLog = _g.actionLog.length;
    _claimSent = false;
    _pending = {};
    if (replayIsGuest) return;
    for (final e in _g.claims.entries) {
      if (_botHere(e.key)) _pending[e.key] = mjBotClaim(_g, e.key, e.value);
    }
  }

  /// Gastgeber: Haben alle, die etwas ansagen dürfen, gewählt, wird entschieden.
  void _resolveIfComplete() {
    if (_g.phase != MjPhase.claim) return;
    if (_g.claims.keys.any((q) => !_pending.containsKey(q))) return;
    final choices = _pending;
    _pending = {};
    _g.resolveClaims(choices);
    if (_g.handWins.isNotEmpty) _app.sfx.play(Sound.lose);
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_g.phase == MjPhase.gameOver || _g.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'seed': _seed, 'log': _g.actionLog, 'earned': _earned, 'paid': _handPaid ? _g.actionLog.length : -1});
  }

  void _newGame() {
    if (replayActive) {
      if (replayIsHost) replayHostStart();
      _pump();
      return;
    }
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _selected = null;
      _exchangePick.clear();
      _rewarded = false;
      _handPaid = false;
      _fast = false;
      _earned = 0;
      _pending = {};
    });
    _app.sfx.play(Sound.card);
    _pump();
  }

  Duration _delay(int ms) => _fast ? const Duration(milliseconds: 60) : _app.settings.botDelay(ms);

  bool get _humanClaim => _g.phase == MjPhase.claim && _g.claims.containsKey(_ms) && !_claimSent;
  bool get _myTurn => !_running && _g.phase == MjPhase.discard && _g.current == _ms;

  /// Als Mitspieler: Ansage ist unterwegs zum Gastgeber.
  bool _claimSent = false;
  int _claimLog = -1;

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      if (_g.phase == MjPhase.handOver) {
        _payHand();
        break;
      }
      if (_g.phase == MjPhase.gameOver) {
        _payGame();
        break;
      }
      if (_g.phase == MjPhase.exchange || _g.phase == MjPhase.voidChoice) break;
      if (_g.phase == MjPhase.discard) {
        if (!_botHere(_g.current)) {
          // Feste Hand nach einem Sieg (Blutfluss): unpassende Steine gehen von selbst weg
          if (_g.current == _ms && _me.locked && _g.drawn != null && !_g.canTsumo(_ms)) {
            final log = _g.actionLog.length;
            await Future<void>.delayed(_delay(450));
            if (!mounted) return;
            if (_g.actionLog.length != log) continue;
            _do(['d', _ms, _g.drawn!]);
            _app.sfx.play(Sound.tick);
            setState(() {});
            if (replayIsGuest) break;
            continue;
          }
          break;
        }
        final engine = _g;
        final log = _g.actionLog.length;
        await Future<void>.delayed(_delay(650));
        if (!mounted) return;
        if (!identical(engine, _g) || _g.actionLog.length != log) continue;
        final p = _g.current;
        switch (mjBotTurn(_g, p, _rng)) {
          case MjBotWin():
            _g.tsumo(p);
            _app.sfx.play(Sound.lose);
          case MjBotKan(:final tile):
            _g.kan(p, tile);
            _app.sfx.play(Sound.chip);
          case MjBotJoker(:final tile):
            _g.declareJoker(p, tile);
            _app.sfx.play(Sound.chip);
          case MjBotDiscard(:final tile):
            _g.discard(p, tile);
            _app.sfx.play(Sound.tick);
        }
        replayBroadcast();
        setState(() {});
        continue;
      }
      if (_g.phase == MjPhase.claim) {
        _startClaimRound();
        if (replayIsGuest || _g.claims.keys.any((q) => !_pending.containsKey(q))) {
          setState(() {});
          break;
        }
        if (_pending.values.any((c) => c.type != MjClaimType.pass)) {
          final log = _g.actionLog.length;
          await Future<void>.delayed(_delay(300));
          if (!mounted) return;
          if (_g.actionLog.length != log) continue;
        }
        _resolveIfComplete();
        replayBroadcast();
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
    if (r == null) return;
    var coins = 0;
    for (final w in r.wins) {
      if (w.winner == _ms) coins += mjHandReward(_r, w.score);
    }
    if (coins > 0) {
      _earned += coins;
      _app.wallet.credit(coins);
      _app.sfx.play(Sound.win);
    }
  }

  void _payGame() {
    if (_rewarded) return;
    _rewarded = true;
    final place = _g.ranking().indexOf(_ms);
    final coins = mjPlaceRewards(_g.n)[place];
    if (coins > 0) {
      _earned += coins;
      _app.wallet.credit(coins);
      _app.sfx.play(place == 0 ? Sound.bigWin : Sound.coin);
    }
  }

  void _nextHand() {
    if (replayIsGuest) return;
    _g.nextHand();
    replayBroadcast();
    setState(() {
      _handPaid = false;
      _selected = null;
      _exchangePick.clear();
      _fast = false;
    });
    _pump();
  }

  // ---------- Eingaben ----------

  void _tapTile(int t, int index) {
    if (_g.phase == MjPhase.exchange) {
      setState(() {
        if (!_exchangePick.remove(index)) {
          if (_exchangePick.length < 3) _exchangePick.add(index);
        }
      });
      return;
    }
    if (!_myTurn || !_g.canDiscard(_ms, t)) return;
    if (_selected == t) {
      _do(['d', _ms, t]);
      _app.sfx.play(Sound.tick);
      setState(() => _selected = null);
      _pump();
    } else {
      setState(() => _selected = t);
    }
  }

  List<int> get _pickedTiles {
    final hand = [..._me.hand]..sort();
    return [for (final i in _exchangePick) if (i < hand.length) hand[i]];
  }

  void _submitExchange() {
    final tiles = _pickedTiles;
    if (!_g.validExchange(tiles) || _me.exchange.length == 3) return;
    _do(['x', _ms, tiles]);
    _app.sfx.play(Sound.card);
    setState(() => _exchangePick.clear());
    _pump();
  }

  void _suggestExchange() {
    final hand = [..._me.hand]..sort();
    final pick = _g.botExchange(_ms);
    final used = <int>{};
    for (final t in pick) {
      for (var i = 0; i < hand.length; i++) {
        if (hand[i] == t && !used.contains(i)) {
          used.add(i);
          break;
        }
      }
    }
    setState(() {
      _exchangePick
        ..clear()
        ..addAll(used);
    });
  }

  void _chooseVoid(int suit) {
    if (_me.voidSuit != null) return;
    _do(['v', _ms, suit]);
    _app.sfx.play(Sound.chip);
    setState(() {});
    _pump();
  }

  void _tsumo() {
    if (!_myTurn || !_g.canTsumo(_ms)) return;
    _do(['t', _ms]);
    setState(() {});
    _pump();
  }

  Future<void> _kan() async {
    if (!_myTurn) return;
    final opts = _g.kanOptions(_ms);
    if (opts.isEmpty) return;
    var t = opts.first;
    if (opts.length > 1) {
      final i = await showChoiceSheet(context, title: 'Welcher Kan?', options: [for (final o in opts) tileName(o)]);
      if (i == null || !mounted) return;
      t = opts[i];
    }
    if (!_myTurn || !_g.kanOptions(_ms).contains(t)) return;
    _do(['k', _ms, t]);
    _app.sfx.play(Sound.chip);
    setState(() => _selected = null);
    _pump();
  }

  /// Vietnam: einen Joker für Punkte beiseitelegen, dafür kommt ein Ersatzstein.
  Future<void> _declareJoker() async {
    if (!_myTurn) return;
    final opts = _g.declarableJokers(_ms);
    if (opts.isEmpty) return;
    final seat = _g.seatOf(_ms);
    final i = await showChoiceSheet(
      context,
      title: 'Welchen Joker beiseitelegen? Er bringt Punkte, ersetzt aber keinen Stein mehr.',
      options: [for (final o in opts) '${tileName(o)}: ${vietBonusPhan(o, seat)} Phán'],
    );
    if (i == null || !mounted) return;
    if (!_myTurn) return;
    _do(['j', _ms, opts[i]]);
    _app.sfx.play(Sound.chip);
    setState(() => _selected = null);
    _pump();
  }

  void _claim(MjOption o) {
    if (!_humanClaim) return;
    final msg = ['cl', _ms, o.type.index, ...o.tiles];
    if (replaySend(msg)) {
      _claimSent = true;
    } else {
      _startClaimRound();
      _pending[_ms] = o;
      _resolveIfComplete();
      replayBroadcast();
    }
    _app.sfx.play(o.type == MjClaimType.pass ? Sound.tick : Sound.chip);
    setState(() => _selected = null);
    _pump();
  }

  // ---------- Anzeige ----------

  List<int> _myWaits() {
    if (_g.phase != MjPhase.discard && _g.phase != MjPhase.claim) return const [];
    final handTiles = _me.hand.length;
    if (handTiles % 3 != 1) return const [];
    final key = '${_me.hand.join(',')}|${_me.melds.length}|${_me.bonus.length}';
    if (key != _waitKey) {
      _waitKey = key;
      _waitCache = _g.waits(_ms);
    }
    return _waitCache;
  }

  String get _status {
    if (_g.phase == MjPhase.gameOver) return 'Die Runde ist vorbei';
    if (_g.phase == MjPhase.handOver) return _g.result?.text ?? '';
    if (_g.phase == MjPhase.exchange) {
      final dir = switch (_g.exchangeDir) { 1 => 'nach rechts', -1 => 'nach links', _ => 'über den Tisch' };
      return 'Wähle drei Steine einer Farbe zum Tauschen. Sie gehen $dir.';
    }
    if (_g.phase == MjPhase.voidChoice) {
      return 'Welche Farbe streichst du? Diese Steine musst du zuerst loswerden.';
    }
    if (_me.out) return 'Du hast gewonnen und schaust zu, bis die Hand fertig ist';
    if (_g.phase == MjPhase.claim && _claimSent) return 'Warte auf die anderen …';
    if (_g.phase == MjPhase.exchange && _me.exchange.length == 3) return 'Warte, bis alle getauscht haben …';
    if (_g.phase == MjPhase.voidChoice && _me.voidSuit != null) return 'Warte auf die Wahl der anderen …';
    if (_humanClaim) {
      final from = _g.lastDiscarder;
      if (_g.robbingTile != null) return '${_g.players[from].name} erweitert zum Kan. Du kannst den Stein rauben!';
      return '${_g.players[from].name} wirft ${tileName(_g.lastDiscard!)} ab. Willst du ihn?';
    }
    if (_myTurn) {
      if (_g.canTsumo(_ms)) return 'Deine Hand ist fertig! Gewinnen?';
      final prefix = _g.lastEvent.isNotEmpty ? '${_g.lastEvent}. ' : '';
      if (_me.hasVoid()) return '${prefix}Wirf zuerst die ${suitNames[_me.voidSuit!]} ab';
      return '${prefix}Du bist dran: Stein antippen, nochmal tippen zum Abwerfen';
    }
    final w = _myWaits();
    final wait = w.isEmpty ? '' : ' · Du wartest auf ${w.take(4).map(tileName).join(', ')}${w.length > 4 ? ' …' : ''}';
    if (_g.lastEvent.isNotEmpty) return '${_g.lastEvent}$wait';
    return '${_g.players[_g.current].name} ist dran$wait';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      actions: [...replayActions(context), const TileLegendButton()],
      network: replayActive ? null : replayOpenPanel,
      title: _r.title,
      guide: widget.guide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF6B1F2A), Color(0xFF2A0C12)]),
      ),
      child: replayScreen() ?? LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _pond(int p, double tw, {int perRow = 6}) {
    final pl = _g.players[p];
    return SizedBox(
      width: perRow * (tw + 1),
      child: Wrap(
        spacing: 1,
        runSpacing: 1,
        children: [
          for (final d in pl.discards) Opacity(opacity: d.called ? 0.3 : 1, child: TileView(tile: d.tile, width: tw)),
        ],
      ),
    );
  }

  Widget _melds(int p, double tw) {
    final pl = _g.players[p];
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final m in pl.melds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < m.tiles.length; i++)
                TileView(tile: m.tiles[i], width: tw, back: !m.open && (i == 0 || i == 3)),
            ],
          ),
        if (pl.bonus.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [for (final b in pl.bonus) TileView(tile: b, width: tw * 0.8)]),
        if (pl.wonTiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFC95C)), borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [for (final t in pl.wonTiles) TileView(tile: t, width: tw * 0.8)]),
          ),
      ],
    );
  }

  Widget _seat(int p, double tw, {int perRow = 6}) {
    final pl = _g.players[p];
    final pal = Palette.of(context);
    final active = _g.current == p && _g.phase == MjPhase.discard;
    final wind = windNames[_g.seatWind(p) - 27];
    final tags = [
      wind,
      formatCoins(pl.points),
      // Die Wahl der anderen bleibt verdeckt, bis alle gewählt haben
      if (pl.voidSuit != null && (p == _ms || _g.phase != MjPhase.voidChoice)) 'ohne ${suitNames[pl.voidSuit!]}',
      if (pl.out) 'fertig',
      if (pl.locked) '${pl.wonTiles.length}× gewonnen',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? pal.accent : (pl.out ? const Color(0xAA1B5E20) : const Color(0x88000000)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${pl.name} · ${tags.join(' · ')}',
            style: TextStyle(color: active ? pal.onAccent : const Color(0xFFF6E7C8), fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 3),
        if (p != _ms) _melds(p, tw * 0.9),
        if (p != _ms) const SizedBox(height: 2),
        _pond(p, tw, perRow: perRow),
      ],
    );
  }

  Widget _centerInfo() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hand ${_g.handsPlayed + 1}',
            style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text('${_g.wallLeft} Steine', style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12)),
          Text('Geber: ${_g.players[_g.dealer].name}', style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.2;
    final slots = _r.handSize + 3.2;
    final handW = landscape ? math.min(math.min((w - 40) / (slots + 1), h * 0.085), 52.0) : math.min((w - 16) / slots, 44.0);
    final pondW = landscape ? math.min(handW * 0.6, h * 0.045) : math.min(handW * 0.62, (w - 140) / 13);
    final perRow = landscape ? 8 : 6;
    Widget seat(int p) => FittedBox(fit: BoxFit.scaleDown, child: _seat(p, pondW, perRow: perRow));

    final four = _g.n == 4;
    final table = Column(
      children: [
        if (four) Expanded(flex: 2, child: seat(_rel(2))),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(child: Center(child: seat(_rel(four ? 3 : 2)))),
              _centerInfo(),
              Expanded(child: Center(child: seat(_rel(1)))),
            ],
          ),
        ),
        Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: _seat(_ms, pondW, perRow: landscape ? 12 : 9))),
      ],
    );

    final overlay = _g.phase == MjPhase.handOver || _g.phase == MjPhase.gameOver;
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
    final buttons = <Widget>[];
    if (_g.phase == MjPhase.exchange && _me.exchange.length == 3) {
      // schon getauscht, warten
    } else if (_g.phase == MjPhase.voidChoice && _me.voidSuit != null) {
      // schon gewählt, warten
    } else if (_g.phase == MjPhase.exchange) {
      buttons.add(ActionButton(label: 'Vorschlag', onPressed: _suggestExchange));
      buttons.add(ActionButton(
        primary: true,
        label: 'Tauschen',
        onPressed: _g.validExchange(_pickedTiles) ? _submitExchange : null,
      ));
    } else if (_g.phase == MjPhase.voidChoice) {
      final hint = _g.botVoid(_ms);
      for (var s = 0; s < 3; s++) {
        buttons.add(ActionButton(primary: s == hint, label: suitNames[s], onPressed: () => _chooseVoid(s)));
      }
    } else if (_humanClaim) {
      for (final o in _g.claims[_ms]!) {
        final label = switch (o.type) {
          MjClaimType.win => 'Gewinnen!',
          MjClaimType.pon => 'Pung',
          MjClaimType.kan => 'Kan',
          MjClaimType.chi => 'Chi ${o.tiles.map(numberOf).join('-')}',
          MjClaimType.pass => 'Weiter',
        };
        buttons.add(ActionButton(primary: o.type == MjClaimType.win, label: label, onPressed: () => _claim(o)));
      }
      buttons.add(ActionButton(label: 'Weiter', onPressed: () => _claim(const MjOption(MjClaimType.pass))));
    } else if (_myTurn) {
      if (_g.canTsumo(_ms)) buttons.add(ActionButton(primary: true, label: 'Gewinnen!', onPressed: _tsumo));
      if (_g.kanOptions(_ms).isNotEmpty) buttons.add(ActionButton(label: 'Kan', onPressed: _kan));
      if (_g.declarableJokers(_ms).isNotEmpty) buttons.add(ActionButton(label: 'Joker ablegen', onPressed: _declareJoker));
    } else if (_me.out && !_fast && _g.phase != MjPhase.handOver) {
      buttons.add(ActionButton(label: 'Vorspulen', onPressed: () => setState(() => _fast = true)));
    }
    return SizedBox(
      height: 46,
      child: Center(child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: buttons)),
    );
  }

  Widget _hand(double tw) {
    final tiles = [..._me.hand]..sort();
    final drawn = _g.current == _ms && _g.phase == MjPhase.discard ? _g.drawn : null;
    if (drawn != null) tiles.remove(drawn);
    final exchanging = _g.phase == MjPhase.exchange;
    final sortedAll = [..._me.hand]..sort();
    Widget tile(int t, int index) {
      final enabled = exchanging || (_myTurn && _g.canDiscard(_ms, t));
      final sel = exchanging ? _exchangePick.contains(index) : _selected == t;
      final voidTile = _me.voidSuit != null && t < 27 && suitOf(t) == _me.voidSuit;
      return TapCatcher(
        onTap: (_) => _tapTile(t, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.only(bottom: sel ? 10 : 0, top: sel ? 0 : 10),
          child: Stack(
            children: [
              TileView(tile: t, width: tw, depth: tw * 0.08, selected: sel, dim: (_myTurn && !enabled)),
              if (voidTile)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(width: tw * 0.25, height: tw * 0.25, decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      );
    }

    // Beim Tauschen zählt die Position in der sortierten Hand
    final children = <Widget>[];
    if (exchanging) {
      for (var i = 0; i < sortedAll.length; i++) {
        children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: tile(sortedAll[i], i)));
      }
    } else {
      for (final t in tiles) {
        children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: tile(t, -1)));
      }
      if (drawn != null) children.addAll([SizedBox(width: tw * 0.4), tile(drawn, -1)]);
    }
    if (_me.melds.isNotEmpty || _me.bonus.isNotEmpty || _me.wonTiles.isNotEmpty) {
      children.addAll([SizedBox(width: tw * 0.5), _melds(_ms, tw * 0.8)]);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children),
    );
  }

  Widget _winBlock(MjWin w) {
    final pal = Palette.of(context);
    final s = w.score;
    final who = w.winner == _ms ? 'Du' : _g.players[w.winner].name;
    final how = w.loser == null ? 'selbst gezogen' : 'von ${w.loser == _ms ? 'dir' : _g.players[w.loser!].name}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$who · $how', style: TextStyle(color: pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in w.hand) TileView(tile: t, width: 26, selected: t == w.tile && w.hand.indexOf(t) == w.hand.lastIndexOf(t)),
                for (final m in w.melds)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [for (final t in m.tiles) TileView(tile: t, width: 22)]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final f in s.fans)
            Text(
              f.value == 0 ? f.name : '${f.name}: ${f.value} ${f.unit ?? _r.unitName}',
              style: TextStyle(color: pal.ink, fontSize: 14),
            ),
          Text(
            'Zusammen ${s.points} ${_r.unitName}${s.limit ? ' (Grenze)' : ''}',
            style: TextStyle(color: pal.ink, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (w.winner == _ms)
            Text('+${mjHandReward(_r, s)} Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _resultPanel() {
    final pal = Palette.of(context);
    final over = _g.phase == MjPhase.gameOver;
    final r = _g.result;
    final children = <Widget>[];
    final rewards = mjPlaceRewards(_g.n);
    if (over) {
      final order = _g.ranking();
      children.add(Text('Endstand', style: Theme.of(context).textTheme.titleLarge));
      for (var i = 0; i < order.length; i++) {
        final p = order[i];
        children.add(Text(
          '${i + 1}. ${_g.players[p].name}: ${formatCoins(_g.players[p].points)} Punkte'
          '${p == _ms && rewards[i] > 0 ? ' · +${rewards[i]} Münzen' : ''}',
          style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: p == _ms ? FontWeight.w700 : FontWeight.w500),
        ));
      }
      if (_earned > 0) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('In dieser Runde verdient: ${formatCoins(_earned)} Münzen', style: TextStyle(color: pal.inkSoft)),
        ));
      }
      children.add(const SizedBox(height: 10));
      if (replayActive) {
        children.add(Wrap(spacing: 8, children: replayButtons(label: 'Neues Spiel', next: replayHostStart)));
      } else {
        children.add(ActionButton(primary: true, label: 'Neues Spiel', onPressed: _newGame));
      }
    } else if (r != null) {
      children.add(Text(r.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium));
      children.add(const SizedBox(height: 8));
      for (final w in r.wins) {
        children.add(_winBlock(w));
      }
      for (final note in r.notes) {
        children.add(Text(note, textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoft, fontSize: 14)));
      }
      children.add(const SizedBox(height: 6));
      for (var p = 0; p < _g.n; p++) {
        final c = r.changes[p];
        children.add(Text(
          '${_g.players[p].name}: ${formatCoins(_g.players[p].points)}${c == 0 ? '' : ' (${c > 0 ? '+' : '−'}${formatCoins(c.abs())})'}',
          style: TextStyle(color: pal.ink, fontSize: 14),
        ));
      }
      children.add(const SizedBox(height: 10));
      if (replayActive) {
        children.add(Wrap(spacing: 8, children: replayButtons(label: _g.gameWillEnd ? 'Zum Endstand' : 'Nächste Hand', next: _nextHand)));
      } else {
        children.add(ActionButton(primary: true, label: _g.gameWillEnd ? 'Zum Endstand' : 'Nächste Hand', onPressed: _nextHand));
      }
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
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Für Tests und Anzeige: ist der Stein ein Joker?
bool isJoker(int t) => isJokerTile(t);

/// Für Tests: Meld als Text.
String meldText(Meld m) => m.tiles.map(tileName).join(', ');
