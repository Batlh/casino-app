import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/painted_assets.dart';
import 'package:gluckspfennig/games/pinball/painted_tables.dart';
import 'package:gluckspfennig/games/pinball/pinball_art.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';

/// Jeder gemalte Tisch lädt sein Spielfeldbild und lässt sich mitten im Spiel
/// (mit und ohne Physik-Linien) ohne Fehler zeichnen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final spec in paintedTables) {
    testWidgets('${spec.name}: Spielfeldbild lädt und Tisch wird gezeichnet', (
      tester,
    ) async {
      final id = PaintedAssets.idOf(spec.theme.art)!;
      await tester.runAsync(() => PaintedAssets.instance.load(id));
      expect(PaintedAssets.instance.isReady(id), isTrue);
      final image = PaintedAssets.instance.image(id)!;
      expect(image.width, 848);
      expect(image.height, 1536);
      final table = PinballTable(rng: Random(3), spec: spec);
      table.charge = 0.8;
      table.launch();
      for (var i = 0; i < 240; i++) {
        table.leftPressed = i % 50 < 10;
        table.step(1 / 120);
      }
      for (final physics in [false, true]) {
        PaintedAssets.showPhysics = physics;
        final painter = TablePainter(
          () => table,
          () => spec,
          () => 2.0,
          () => const [],
          ValueNotifier(0),
        );
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(400, 800));
        recorder.endRecording().dispose();
      }
      PaintedAssets.showPhysics = false;
    });
  }
}
