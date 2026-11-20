import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';

/// Auszahlung (mal Einsatz) je Anzahl gewählter Zahlen und Treffer.
const kenoPays = <int, Map<int, int>>{
  1: {1: 3},
  2: {2: 12},
  3: {2: 1, 3: 42},
  4: {2: 1, 3: 4, 4: 100},
  5: {3: 2, 4: 20, 5: 450},
  6: {3: 1, 4: 7, 5: 50, 6: 1500},
  7: {3: 1, 4: 3, 5: 20, 6: 100, 7: 5000},
  8: {4: 2, 5: 10, 6: 50, 7: 1000, 8: 10000},
  9: {4: 1, 5: 5, 6: 25, 7: 200, 8: 4000, 9: 25000},
  10: {0: 2, 5: 2, 6: 20, 7: 80, 8: 500, 9: 5000, 10: 50000},
};

int kenoPayout(int picks, int hits, int bet) => (kenoPays[picks]?[hits] ?? 0) * bet;

const kenoGuide = GameGuide('Keno', [
  GuideSection(
    'Ziel',
    'Wähle 1 bis 10 Zahlen von 1 bis 80. Dann werden 20 Zahlen gezogen. Je mehr deiner Zahlen dabei sind, desto mehr gewinnst du.',
  ),
  GuideSection(
    'Gewinne',
    'Die Tabelle unter dem Feld zeigt, was deine Auswahl bei wie vielen Treffern bringt, als Vielfaches des Einsatzes. '
        'Wer zehn Zahlen wählt und gar keine trifft, bekommt den doppelten Einsatz zurück.',
  ),
]);

class KenoScreen extends StatefulWidget {
  const KenoScreen({super.key, this.seed});
  final int? seed;

  @override
  State<KenoScreen> createState() => _KenoScreenState();
}

class _KenoScreenState extends State<KenoScreen> with NetSharedTable {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  final Set<int> _picks = {};
  final List<int> _drawn = [];
  int _bet = 10;
  bool _drawing = false;
  String _message = 'Wähle bis zu zehn Zahlen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  @override
  void dispose() {
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'keno';
  @override
  String get sharedTitle => 'Keno';
  List<int>? _pending;

  /// Ziehung vom Gastgeber: Wer Zahlen gewählt hat, spielt mit.
  @override
  void sharedResult(Object? outcome) {
    if (outcome is! List || outcome.length != 20) return;
    final drawn = [for (final v in outcome) (v as num).toInt()];
    if (_drawing) {
      _pending = drawn;
      return;
    }
    _drawTo(drawn);
  }

  void _stake() => sharedStake(_picks.isEmpty ? 0 : _bet);

  void _toggle(int n) {
    if (_drawing) return;
    setState(() {
      if (_drawn.isNotEmpty) _drawn.clear();
      if (!_picks.remove(n) && _picks.length < 10) _picks.add(n);
      _message = '${_picks.length} Zahlen gewählt';
    });
    _app.sfx.play(Sound.tick);
    _stake();
  }

  void _quick() {
    if (_drawing) return;
    final all = [for (var i = 1; i <= 80; i++) i]..shuffle(_rng);
    setState(() {
      _drawn.clear();
      _picks
        ..clear()
        ..addAll(all.take(_picks.isEmpty ? 6 : _picks.length));
      _message = '${_picks.length} Zahlen gewählt';
    });
    _stake();
  }

  Future<void> _draw() async {
    if (_drawing || sharedGuest) return;
    // Am Netztisch zieht der Gastgeber auch ohne eigene Zahlen
    if (_picks.isEmpty && !sharedHost) return;
    if (_picks.isNotEmpty && !sharedWallet.canAfford(_bet)) return;
    final all = [for (var i = 1; i <= 80; i++) i]..shuffle(_rng);
    final drawn = all.take(20).toList();
    sharedSend(drawn);
    await _drawTo(drawn);
  }

  Future<void> _drawTo(List<int> drawn) async {
    final playing = _picks.isNotEmpty && sharedWallet.spend(_bet);
    setState(() {
      _drawing = true;
      _drawn.clear();
      _message = '';
    });
    for (final n in drawn) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      _app.sfx.play(_picks.contains(n) ? Sound.chip : Sound.tick);
      setState(() => _drawn.add(n));
    }
    final hits = _drawn.where(_picks.contains).length;
    final paid = playing ? kenoPayout(_picks.length, hits, _bet) : 0;
    if (paid > 0) sharedWallet.credit(paid);
    sharedWallet.refillIfBroke();
    if (playing) _app.sfx.play(paid > _bet ? Sound.win : (paid > 0 ? Sound.coin : Sound.lose));
    setState(() {
      _drawing = false;
      _big = paid >= 50 * _bet;
      _message = !playing
          ? 'Gezogen. Wähle Zahlen, um bei der nächsten Ziehung mitzuspielen'
          : '$hits von ${_picks.length} getroffen. ${paid > 0 ? 'Du bekommst ${formatCoins(paid)}' : 'Kein Gewinn'}';
    });
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _drawTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return GameFrame(
      title: 'Keno',
      guide: kenoGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1F3A6B), Color(0xFF0A142B)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                LayoutBuilder(builder: (context, box) {
                  final cell = (box.maxWidth - 9 * 4) / 10;
                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var n = 1; n <= 80; n++)
                        GestureDetector(
                          onTap: () => _toggle(n),
                          child: Container(
                            width: cell,
                            height: math.min(cell, 44),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _drawn.contains(n) && _picks.contains(n)
                                  ? const Color(0xFF2E7D32)
                                  : _picks.contains(n)
                                      ? const Color(0xFFFFC95C)
                                      : _drawn.contains(n)
                                          ? const Color(0xFFC62828)
                                          : pal.panel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: pal.panelEdge),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _drawn.contains(n) && !_picks.contains(n) ? Colors.white : (_picks.contains(n) ? const Color(0xFF241410) : pal.ink),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                ResultBanner(text: _message, highlight: _big, maxLines: 2),
                sharedStakesBar(),
                const SizedBox(height: 6),
                if (_picks.isNotEmpty)
                  Text(
                    'Bei ${_picks.length} Zahlen: ${kenoPays[_picks.length]!.entries.map((e) => '${e.key} Treffer ×${e.value}').join(' · ')}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.onFelt, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                BetPicker(
                  value: _bet,
                  onChanged: (v) {
                    setState(() => _bet = v);
                    _stake();
                  },
                  enabled: !_drawing,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionButton(label: 'Zufall', onPressed: _drawing ? null : _quick),
                    ActionButton(label: 'Löschen', onPressed: _drawing || _picks.isEmpty ? null : () {
                          setState(() {
                            _picks.clear();
                            _drawn.clear();
                          });
                          _stake();
                        }),
                    ActionButton(
                      primary: true,
                      label: sharedGuest ? 'Der Gastgeber zieht' : (_picks.isEmpty && sharedHost ? 'Ziehen' : 'Ziehen: ${formatCoins(_bet)}'),
                      onPressed: _drawing || sharedGuest || (_picks.isEmpty && !sharedHost) || (_picks.isNotEmpty && !sharedWallet.canAfford(_bet)) ? null : _draw,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
