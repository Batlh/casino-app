// Die Hintergrund-Animationen der Slots laufen in einer Schleife: Zeit 0 und Zeit 1 müssen gleich aussehen,
// sonst ruckelt es bei jedem Durchlauf.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';

Future<Uint8List> _render(SlotGame g, double time) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.paintBackdrop(canvas, const Rect.fromLTWH(0, 0, 200, 160), time);
  final image = await recorder.endRecording().toImage(200, 160);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

void main() {
  for (final g in allSlots) {
    testWidgets('${g.name}: Hintergrund ist eine nahtlose Schleife', (tester) async {
      await tester.runAsync(() async {
        final start = await _render(g, 0);
        final end = await _render(g, 1);
        var diff = 0;
        for (var i = 0; i < start.length; i++) {
          final d = (start[i] - end[i]).abs();
          if (d > 2) diff++;
        }
        // Rundungen erlaubt, sichtbare Sprünge nicht
        expect(diff, lessThan(start.length ~/ 500), reason: '$diff abweichende Werte');
      });
    });
  }
}
