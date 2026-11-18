import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_art.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  testWidgets('Neue Flippertische', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: Row(
            children: [
              for (final t in [lakeTable, jungleTable, circusTable])
                SizedBox(width: 497, height: 900, child: CustomPaint(painter: TablePainter.preview(t))),
            ],
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/flipper_neu.png'));
  });
}
