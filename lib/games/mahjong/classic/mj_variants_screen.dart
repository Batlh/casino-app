import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../ui/guide.dart';
import '../../../ui/widgets.dart';
import '../mahjong_tutorial.dart';
import '../tiles.dart';
import 'mj_guides.dart';
import 'mj_rules.dart';
import 'mj_screen.dart';

/// Kleine Auswahl an Steinen als Erkennungszeichen der Variante.
const _variantTiles = <MjVariant, List<int>>{
  MjVariant.sichuanBattle: [4, 13, 22],
  MjVariant.sichuanRiver: [0, 9, 18],
  MjVariant.hongKong: [33, 34, 38],
  MjVariant.taiwan: [27, 31, 35],
  MjVariant.mcr: [32, 0, 13],
  MjVariant.singapore: [42, 43, 44],
  MjVariant.korean: [18, 26, 29],
  MjVariant.zungJung: [31, 32, 33],
  MjVariant.western: [27, 28, 36],
  MjVariant.filipino: [9, 17, 37],
  MjVariant.vietnam: [46, 40, 33],
};

Widget mjTutorialFor(MjVariant v) => QuizTutorialScreen(title: '${mjRules[v]!.title} lernen', lessons: mjLessons(v));

GameGuide mjGuideFor(MjVariant v) => mjGuide(v, tutorial: (_) => mjTutorialFor(v));

class MjVariantsScreen extends StatelessWidget {
  const MjVariantsScreen({super.key, this.only});

  /// Nur diese Varianten zeigen (zum Beispiel beide Sichuan-Arten).
  final List<MjVariant>? only;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final list = only ?? MjVariant.values;
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    return GameFrame(
      title: only == null ? 'Mahjong-Varianten' : 'Sichuan Mahjong',
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF6B1F2A), Color(0xFF2A0C12)]),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final v in list)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  color: p.panel,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: p.panelEdge, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            for (final t in _variantTiles[v]!)
                              Padding(padding: const EdgeInsets.only(right: 2), child: TileView(tile: t, width: 26)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mjRules[v]!.title, style: Theme.of(context).textTheme.titleMedium),
                                  Text(mjRules[v]!.blurb, style: TextStyle(color: p.inkSoft, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            ActionButton(label: 'Erklärung', onPressed: () => showGuide(context, mjGuideFor(v))),
                            ActionButton(label: 'Üben', onPressed: () => open(mjTutorialFor(v))),
                            ActionButton(
                              primary: true,
                              label: 'Spielen',
                              onPressed: () => open(MjScreen(rules: mjRules[v]!, guide: mjGuideFor(v))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
