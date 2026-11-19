import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_replay_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'riichi_bot.dart';
import 'riichi_engine.dart';
import 'riichi_hand.dart';
import 'tiles.dart';
import '../../ui/tap_catcher.dart';
import 'tile_legend.dart';

/// Münzen je Platz am Ende der Ostrunde.
const riichiPlaceRewards = [300, 120, 40, 0];

int riichiHandReward(HandScore s) => s.yakuman > 0 ? 200 : math.min(200, 20 + 10 * s.han);

class RiichiScreen extends StatefulWidget {
  const RiichiScreen({super.key, this.seed});
  final int? seed;

  @override
  State<RiichiScreen> createState() => _RiichiScreenState();
}

class _RiichiScreenState extends State<RiichiScreen> with NetReplayScreen {
  late RiichiGame _g;
  late math.Random _rng;
  int? _selected;
  bool _riichiMode = false;
  bool _running = false;
  bool _rewarded = false;
  bool _handPaid = false;
  int _earned = 0;
  Map<int, ClaimOption> _pending = {};

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  RPlayer get _me => _g.players[_ms];

  /// Dein Platz: allein 0, im Netz je Gerät verschieden.
  int get _ms => replayActive ? replayMe : 0;

  /// Spielt hier der Computer diesen Platz (im Netz nur beim Gastgeber)?
  bool _botHere(int p) => replayActive ? replayIsHost && replayIsBot(p) : p != 0;

  /// Als Mitspieler: Ansage ist unterwegs zum Gastgeber.
  bool _claimSent = false;
  int _claimLog = -1;

  late int _seed;
  static const _saveId = 'riichi';
  bool get _saving => widget.seed == null && !replayActive;

  RiichiGame _make() => RiichiGame(rng: math.Random(_seed))..start();

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
  RiichiGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      final g = _make();
      for (final a in d['log'] as List) {
        riichiApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _handPaid = g.phase == RPhase.handOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (e, st) {
      debugLog.error('riichi.spielstand', e, st);
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
  String get replayGame => 'riichi';
  @override
  String get replayTitle => 'Riichi Mahjong';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const ['Helga', 'Otto', 'Bärbel'];
  @override
  List<List<Object?>> get replayLog => _g.actionLog;

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _seed = seed;
    _g = RiichiGame(rng: math.Random(seed), names: names, humans: replayHumans, me: me)..start();
    _selected = null;
    _riichiMode = false;
    _rewarded = false;
    _handPaid = false;
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
      _pending[(a[1] as num).toInt()] = ClaimOption(ClaimType.values[(a[2] as num).toInt()], [for (final t in a.sublist(3)) (t as num).toInt()]);
      _resolveIfComplete();
      return;
    }
    riichiApply(_g, a);
  }

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    int i(int k) => (a[k] as num).toInt();
    if (a.length < 2 || i(1) != seat) return false;
    switch (a[0]) {
      case 'cl':
        if (_g.phase != RPhase.claim || _pending.containsKey(seat)) return false;
        final opts = _g.claims[seat];
        if (opts == null) return false;
        final type = ClaimType.values[i(2)];
        if (type == ClaimType.pass) return true;
        final tiles = [for (final t in a.sublist(3)) (t as num).toInt()];
        return opts.any((o) => o.type == type && o.tiles.join(',') == tiles.join(','));
      case 'd':
        if (_g.phase != RPhase.discard || _g.current != seat || !_g.canDiscard(seat, i(2))) return false;
        return a[3] != true || _g.riichiDiscards(seat).contains(i(2));
      case 't':
        return _g.phase == RPhase.discard && _g.current == seat && _g.canTsumo(seat);
      case 'k':
        return _g.phase == RPhase.discard && _g.current == seat && _g.kanOptions(seat).contains(i(2));
    }
    return false;
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    if (acts.isNotEmpty) _app.sfx.play(Sound.tick);
    if (_g.phase != RPhase.handOver && _g.phase != RPhase.gameOver) _handPaid = false;
    if (_selected != null && !_me.hand.contains(_selected)) _selected = null;
    setState(() {});
    _pump();
  }

  @override
  void replayClosed() => _newGame();

  /// Zug ausführen: allein und beim Gastgeber sofort, als Mitspieler über den Gastgeber.
  void _do(List<Object?> a) {
    if (replaySend(a)) return;
    riichiApply(_g, a);
    replayBroadcast();
  }

  /// Neue Ansagerunde (erkannt am Protokoll): Computer entscheiden sofort, Menschen wählen selbst.
  void _startClaimRound() {
    if (_g.phase != RPhase.claim || _claimLog == _g.actionLog.length) return;
    _claimLog = _g.actionLog.length;
    _claimSent = false;
    _pending = {};
    if (replayIsGuest) return;
    for (final e in _g.claims.entries) {
      if (_botHere(e.key)) _pending[e.key] = botClaim(_g, e.key, e.value);
    }
  }

  /// Gastgeber: Haben alle, die etwas ansagen dürfen, gewählt, wird entschieden.
  void _resolveIfComplete() {
    if (_g.phase != RPhase.claim) return;
    if (_g.claims.keys.any((q) => !_pending.containsKey(q))) return;
    final choices = _pending;
    _pending = {};
    _g.resolveClaims(choices);
    if (_g.phase == RPhase.handOver) _app.sfx.play(Sound.lose);
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_g.phase == RPhase.gameOver || _g.actionLog.isEmpty) {
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
      _riichiMode = false;
      _rewarded = false;
      _handPaid = false;
      _earned = 0;
      _pending = {};
    });
    _app.sfx.play(Sound.card);
    _pump();
  }

  bool get _humanClaim => _g.phase == RPhase.claim && _g.claims.containsKey(_ms) && !_claimSent;
  bool get _myTurn => !_running && _g.phase == RPhase.discard && _g.current == _ms;

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      if (_g.phase == RPhase.handOver) {
        _payHand();
        break;
      }
      if (_g.phase == RPhase.gameOver) {
        _payGame();
        break;
      }
      if (_g.phase == RPhase.discard) {
        if (!_botHere(_g.current)) {
          // In Riichi wird ein nutzloser Stein von selbst abgeworfen
          if (_g.current == _ms && _me.riichi && _g.drawn != null && !_g.canTsumo(_ms)) {
            final log = _g.actionLog.length;
            await Future<void>.delayed(_app.settings.botDelay(500));
            if (!mounted) return;
            if (_g.actionLog.length != log) continue;
            _do(['d', _ms, _g.drawn!, false]);
            _app.sfx.play(Sound.tick);
            setState(() {});
            if (replayIsGuest) break;
            continue;
          }
          break;
        }
        final engine = _g;
        final log = _g.actionLog.length;
        await Future<void>.delayed(_app.settings.botDelay(650));
        if (!mounted) return;
        if (!identical(engine, _g) || _g.actionLog.length != log) continue;
        final p = _g.current;
        final act = botTurn(_g, p, _rng);
        switch (act) {
          case BotTsumo():
            _g.tsumo(p);
            _app.sfx.play(Sound.lose);
          case BotKan(:final tile):
            _g.kan(p, tile);
            _app.sfx.play(Sound.chip);
          case BotDiscard(:final tile, :final riichi):
            _g.discard(p, tile, riichi: riichi);
            _app.sfx.play(riichi ? Sound.chip : Sound.tick);
        }
        replayBroadcast();
        setState(() {});
        continue;
      }
      if (_g.phase == RPhase.claim) {
        _startClaimRound();
        if (replayIsGuest || _g.claims.keys.any((q) => !_pending.containsKey(q))) {
          setState(() {});
          break;
        }
        if (_pending.values.any((c) => c.type != ClaimType.pass)) {
          final log = _g.actionLog.length;
          await Future<void>.delayed(_app.settings.botDelay(300));
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
    if (r != null && r.winner == _ms && r.score != null) {
      final coins = riichiHandReward(r.score!);
      _earned += coins;
      _app.wallet.credit(coins);
      _app.sfx.play(Sound.win);
    }
  }

  void _payGame() {
    if (_rewarded) return;
    _rewarded = true;
    final place = _g.ranking().indexOf(_ms);
    final coins = riichiPlaceRewards[place];
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
      _riichiMode = false;
    });
    _pump();
  }

  // ---------- Eingaben ----------

  void _tapTile(int t) {
    if (!_myTurn) return;
    if (_riichiMode && !_g.riichiDiscards(_ms).contains(t)) return;
    if (!_g.canDiscard(_ms, t)) return;
    if (_selected == t) {
      _do(['d', _ms, t, _riichiMode]);
      _app.sfx.play(_riichiMode ? Sound.chip : Sound.tick);
      setState(() {
        _selected = null;
        _riichiMode = false;
      });
      _pump();
    } else {
      setState(() => _selected = t);
    }
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

  void _claim(ClaimOption o) {
    if (!_humanClaim) return;
    if (replaySend(['cl', _ms, o.type.index, ...o.tiles])) {
      _claimSent = true;
    } else {
      _startClaimRound();
      _pending[_ms] = o;
      _resolveIfComplete();
      replayBroadcast();
    }
    _app.sfx.play(o.type == ClaimType.pass ? Sound.tick : Sound.chip);
    setState(() => _selected = null);
    _pump();
  }

  // ---------- Anzeige ----------

  String get _status {
    if (_g.phase == RPhase.gameOver) return 'Die Ostrunde ist vorbei';
    if (_g.phase == RPhase.handOver) return _g.result?.text ?? '';
    if (_g.phase == RPhase.claim && _claimSent) return 'Warte auf die anderen …';
    if (_humanClaim) {
      return '${_g.players[_g.lastDiscarder].name} wirft ${tileName(_g.lastDiscard!)} ab. Willst du ihn?';
    }
    if (_myTurn) {
      if (_riichiMode) return 'Riichi: Wähle den Stein, den du abwirfst (zweimal tippen)';
      if (_g.canTsumo(_ms)) return 'Deine Hand ist fertig! Tsumo ansagen?';
      final prefix = _g.lastEvent.isNotEmpty ? '${_g.lastEvent}. ' : '';
      return '${prefix}Du bist dran: Stein antippen, nochmal tippen zum Abwerfen';
    }
    if (_g.lastEvent.isNotEmpty) return _g.lastEvent;
    return '${_g.players[_g.current].name} ist dran';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      actions: [...replayActions(context), const TileLegendButton()],
      network: replayActive ? null : replayOpenPanel,
      title: 'Riichi Mahjong',
      guide: riichiGuide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1F6B52), Color(0xFF0C2B21)]),
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
          for (final d in pl.discards)
            Opacity(
              opacity: d.called ? 0.3 : 1,
              child: d.riichi
                  ? RotatedBox(quarterTurns: 1, child: TileView(tile: d.tile, width: tw))
                  : TileView(tile: d.tile, width: tw),
            ),
        ],
      ),
    );
  }

  Widget _melds(int p, double tw) {
    final pl = _g.players[p];
    return Wrap(
      spacing: 4,
      children: [
        for (final m in pl.melds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < m.tiles.length; i++)
                TileView(tile: m.tiles[i], width: tw, back: !m.open && (i == 0 || i == 3)),
            ],
          ),
      ],
    );
  }

  Widget _seat(int p, double tw, {int perRow = 6}) {
    final pl = _g.players[p];
    final pal = Palette.of(context);
    final active = _g.current == p && _g.phase == RPhase.discard;
    final wind = windNames[_g.seatWind(p) - 27];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? pal.accent : const Color(0x88000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${pl.name} · $wind · ${formatCoins(pl.points)}${pl.riichi ? ' · Riichi' : ''}',
            style: TextStyle(
              color: active ? pal.onAccent : const Color(0xFFF6E7C8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (p != _ms) _melds(p, tw * 0.9),
        if (p != _ms) const SizedBox(height: 2),
        _pond(p, tw, perRow: perRow),
      ],
    );
  }

  Widget _centerInfo(double tw) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ost ${_g.handNumber}${_g.honba > 0 ? ' · ${_g.honba} Honba' : ''}',
            style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text(
            '${_g.wallLeft} Steine${_g.riichiSticks > 0 ? ' · ${_g.riichiSticks} Riichi' : ''}',
            style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Dora ', style: TextStyle(color: Color(0xFFF6E7C8), fontSize: 12)),
              for (final t in _g.doraIndicators) TileView(tile: t, width: tw),
            ],
          ),
        ],
      ),
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.2;
    final handW = landscape ? math.min(math.min((w - 40) / 16, h * 0.085), 52.0) : math.min((w - 16) / 15.2, 44.0);
    final pondW = landscape ? math.min(handW * 0.6, h * 0.045) : math.min(handW * 0.62, (w - 140) / 13);
    final perRow = landscape ? 8 : 6;

    final table = Column(
      children: [
        Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: _seat((_ms + 2) % 4, pondW, perRow: perRow))),
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _seat((_ms + 3) % 4, pondW, perRow: perRow)))),
              _centerInfo(pondW),
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _seat((_ms + 1) % 4, pondW, perRow: perRow)))),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: FittedBox(fit: BoxFit.scaleDown, child: _seat(_ms, pondW, perRow: landscape ? 12 : 9)),
        ),
      ],
    );

    final overlay = _g.phase == RPhase.handOver || _g.phase == RPhase.gameOver;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.all(4), child: table)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ResultBanner(text: _status, maxLines: 2),
            ),
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
    if (_humanClaim) {
      for (final o in _g.claims[_ms]!) {
        final label = switch (o.type) {
          ClaimType.ron => 'Ron!',
          ClaimType.pon => 'Pon',
          ClaimType.kan => 'Kan',
          ClaimType.chi => 'Chi ${o.tiles.map((t) => numberOf(t)).join('-')}',
          ClaimType.pass => 'Weiter',
        };
        buttons.add(ActionButton(primary: o.type == ClaimType.ron, label: label, onPressed: () => _claim(o)));
      }
      buttons.add(ActionButton(label: 'Weiter', onPressed: () => _claim(const ClaimOption(ClaimType.pass))));
    } else if (_myTurn) {
      if (_g.canTsumo(_ms)) buttons.add(ActionButton(primary: true, label: 'Tsumo!', onPressed: _tsumo));
      final riichi = _g.riichiDiscards(_ms);
      if (riichi.isNotEmpty) {
        buttons.add(
          ActionButton(
            primary: _riichiMode,
            label: _riichiMode ? 'Kein Riichi' : 'Riichi',
            onPressed: () => setState(() {
              _riichiMode = !_riichiMode;
              _selected = null;
            }),
          ),
        );
      }
      if (_g.kanOptions(_ms).isNotEmpty) buttons.add(ActionButton(label: 'Kan', onPressed: _kan));
    }
    return SizedBox(
      height: 46,
      child: Center(
        child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: buttons),
      ),
    );
  }

  Widget _hand(double tw) {
    final tiles = [..._me.hand];
    final drawn = _g.current == _ms && _g.phase == RPhase.discard ? _g.drawn : null;
    if (drawn != null) tiles.remove(drawn);
    tiles.sort();
    final riichiOk = _riichiMode ? _g.riichiDiscards(_ms).toSet() : null;
    Widget tile(int t) {
      final enabled = _myTurn && _g.canDiscard(_ms, t) && (riichiOk == null || riichiOk.contains(t));
      final sel = _selected == t;
      return TapCatcher(
        onTap: (_) => _tapTile(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.only(bottom: sel ? 10 : 0, top: sel ? 0 : 10),
          child: TileView(tile: t, width: tw, depth: tw * 0.08, selected: sel, dim: _myTurn && !enabled),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final t in tiles) Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: tile(t)),
          if (drawn != null) ...[SizedBox(width: tw * 0.4), tile(drawn)],
          if (_me.melds.isNotEmpty) ...[SizedBox(width: tw * 0.5), _melds(_ms, tw * 0.8)],
        ],
      ),
    );
  }

  Widget _resultPanel() {
    final pal = Palette.of(context);
    final over = _g.phase == RPhase.gameOver;
    final r = _g.result;
    final children = <Widget>[];
    if (over) {
      final order = _g.ranking();
      children.add(Text('Endstand', style: Theme.of(context).textTheme.titleLarge));
      for (var i = 0; i < 4; i++) {
        final p = order[i];
        children.add(
          Text(
            '${i + 1}. ${_g.players[p].name}: ${formatCoins(_g.players[p].points)} Punkte'
            '${p == _ms && riichiPlaceRewards[i] > 0 ? ' · +${riichiPlaceRewards[i]} Münzen' : ''}',
            style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: p == _ms ? FontWeight.w700 : FontWeight.w500),
          ),
        );
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
      if (r.winner != null && r.score != null) {
        final s = r.score!;
        children.add(const SizedBox(height: 6));
        children.add(
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in r.winHand) TileView(tile: t, width: 28, selected: t == r.winTile && r.winHand.indexOf(t) == r.winHand.lastIndexOf(t)),
                const SizedBox(width: 6),
                for (final m in r.winMelds)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [for (final t in m.tiles) TileView(tile: t, width: 24)]),
                  ),
              ],
            ),
          ),
        );
        children.add(const SizedBox(height: 6));
        for (final y in s.yaku) {
          children.add(Text(
            s.yakuman > 0 ? y.name : '${y.name}: ${y.han} Han',
            style: TextStyle(color: pal.ink, fontSize: 15),
          ));
        }
        final limit = s.limitName;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            s.yakuman > 0 ? limit : '${s.han} Han, ${s.fu} Fu${limit.isEmpty ? '' : ' · $limit'}',
            style: TextStyle(color: pal.ink, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ));
        if (r.winner == _ms) {
          children.add(Text('+${riichiHandReward(s)} Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)));
        }
      }
      children.add(const SizedBox(height: 6));
      for (var p = 0; p < 4; p++) {
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
        children.add(ActionButton(
          primary: true,
          label: _g.gameWillEnd ? 'Zum Endstand' : 'Nächste Hand',
          onPressed: _nextHand,
        ));
      }
    }
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
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
