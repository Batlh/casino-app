import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_art.dart';
import 'package:gluckspfennig/games/pinball/neonstadt_assets.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('V9: tatsächlicher CustomPainter, Stromausfall, Hologramm und neun Punktmatrix-Bildfolgen', () async {
    await NeonstadtAssets.instance.load();
    expect(NeonstadtAssets.instance.isReady, isTrue);
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
    final font = File(
      '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (font.existsSync())
      await (FontLoader('Barlow')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    final out = Directory(
      Platform.environment['NEONSTADT_EVIDENCE'] ?? 'build/neonstadt_nachweise',
    )..createSync(recursive: true);
    final notifier = ValueNotifier(0);
    Future<List<int>> capture(
      String name,
      CustomPainter painter,
      int w,
      int h,
    ) async {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), Size(w.toDouble(), h.toDouble()));
      final pic = rec.endRecording();
      final img = await pic.toImage(w, h);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      File('${out.path}/$name.png').writeAsBytesSync(bytes);
      img.dispose();
      pic.dispose();
      return bytes;
    }

    TablePainter field(PinballTable table) => TablePainter(
      () => table,
      () => cityTable,
      () => table.city!.clock,
      () => [],
      notifier,
    );
    final normal = PinballTable(spec: cityTable);
    await capture('Neonstadt_V9_Modell', field(normal), 995, 1985);
    final dark = PinballTable(spec: cityTable);
    dark.city!.nextMode = 5;
    dark.city!.hit('shot', 'kern');
    await capture('Stromausfall', field(dark), 995, 1985);
    final holo = PinballTable(spec: cityTable);
    holo.city!.hit('shot', 'kern');
    holo.city!.clock = .2;
    final h1 = await capture('Hologramm_01', field(holo), 995, 1985);
    holo.city!.clock = .4;
    final h2 = await capture('Hologramm_02', field(holo), 995, 1985);
    expect(h1, isNot(equals(h2)));

    Directory('${out.path}/interaktion').createSync();
    final kick = PinballTable(spec: cityTable);
    await capture('interaktion/Kickback_bereit', field(kick), 995, 1985);
    kick.debugPlaceBall(.53, 15.65, 0, 3);
    kick.step(1 / 120);
    await capture('interaktion/Kickback_Schlag', field(kick), 995, 1985);
    final lamps = PinballTable(spec: cityTable);
    for (final l in cityTable.lanes.where((l) => l.group != 'top').take(3)) {
      lamps.debugPlaceBall(l.x, l.y, 0, 1);
      lamps.step(1 / 120);
    }
    await capture('interaktion/Gassen_3_von_4', field(lamps), 995, 1985);
    final chase = PinballTable(spec: cityTable);
    chase.city!.nextMode = 3;
    chase.city!.hit('shot', 'kern');
    chase.city!.clock = .01;
    final arrow1 = await capture(
      'interaktion/Pfeile_Blinken_an',
      field(chase),
      995,
      1985,
    );
    chase.city!.clock = .20;
    final arrow2 = await capture(
      'interaktion/Pfeile_Blinken_aus',
      field(chase),
      995,
      1985,
    );
    expect(arrow1, isNot(equals(arrow2)));
    final upload = PinballTable(spec: cityTable);
    upload.city!.hit('shot', 'kern');
    upload.city!.hit('shot', 'kern');
    await capture('interaktion/Lock_2_von_3', field(upload), 995, 1985);
    final upper = PinballTable(spec: cityTable);
    upper.debugPlacePlateauBall(3.7, 2.8, 0, 1);
    await capture('interaktion/Kugel_auf_Plateau', field(upper), 995, 1985);
    for (var i = 0; i < 300 && upper.balls.first.onPlateau; i++)
      upper.step(1 / 120);
    expect(upper.balls.first.onPlateau, isFalse);
    await capture('interaktion/Kugel_auf_Abfahrt', field(upper), 995, 1985);
    final bonus = PinballTable(spec: cityTable);
    for (final l in cityTable.lanes.where((l) => l.group != 'top')) {
      bonus.debugPlaceBall(l.x, l.y, 0, 1);
      bonus.step(1 / 120);
    }
    bonus.debugPlaceBall(4.625, 18.25, 0, 3);
    for (var i = 0; i < 10; i++) bonus.step(1 / 120);
    expect(bonus.cityBonusVisible, isTrue);
    await capture(
      'interaktion/Bonus_Anzeige',
      DmdPainter(
        () => DmdState(
          'BONUS',
          bonus.cityBonusText,
          cityTable.theme.dmd,
          time: bonus.city!.clock,
        ),
        notifier,
        industrial: true,
      ),
      512,
      96,
    );
    Directory('${out.path}/dmd').createSync();
    for (var mode = 0; mode < 9; mode++) {
      final t = PinballTable(spec: cityTable), rules = t.city!;
      if (mode == 8) {
        rules.completed.addAll(List.generate(8, (i) => i));
      } else {
        rules.nextMode = mode;
      }
      rules.hit('shot', 'kern');
      final frames = <List<int>>[];
      for (var f = 0; f < 4; f++) {
        rules.clock = f / 6 + .01;
        frames.add(
          await capture(
            'dmd/Modus_${mode + 1}_Bild_${f + 1}',
            DmdPainter(
              () => DmdState(
                rules.title,
                rules.subtitle,
                cityTable.theme.dmd,
                time: rules.clock,
                animation: mode,
              ),
              notifier,
              industrial: true,
            ),
            512,
            96,
          ),
        );
      }
      expect(frames[0], isNot(equals(frames[1])));
    }
    final geometry = {
      'height': cityTable.playfieldHeight,
      'walls': [
        for (final w in cityTable.walls)
          {
            'visible': w.visible,
            'points': [
              for (final p in w.points) [p.x, p.y],
            ],
          },
      ],
      'bumpers': [
        for (final b in cityTable.bumpers) [b.x, b.y, b.radius],
      ],
      'supports': [
        for (final p in cityTable.supports) [p.x, p.y, p.height],
      ],
      'slings': [
        for (final p in cityTable.slings)
          [
            [p.a.x, p.a.y],
            [p.b.x, p.b.y],
            [p.c.x, p.c.y],
          ],
      ],
      'lanes': [
        for (final p in cityTable.lanes)
          {
            'group': p.group,
            'position': [p.x, p.y],
          },
      ],
      'flippers': [
        for (final f in cityTable.flippers)
          {
            'pivot': [f.pivot.x, f.pivot.y],
            'length': f.length,
            'rest': f.rest,
            'up': f.up,
            'heel': f.heelHalfWidth,
            'tip': f.tipHalfWidth,
          },
      ],
      'targets': [
        for (final b in cityTable.targets)
          {
            'id': b.id,
            'points': [
              for (final p in b.targets) [p.x, p.y],
            ],
            'angle': b.angle,
          },
      ],
      'saucers': [
        for (final s in cityTable.saucers) [s.x, s.y],
      ],
      'ramps': [
        for (final p in cityTable.ramps)
          {
            'id': p.id,
            'entry': [
              [p.a.x, p.a.y],
              [p.b.x, p.b.y],
            ],
            'path': [
              for (final x in p.path) [x.x, x.y],
            ],
            'heights': p.heights,
            'wireStart': p.wireStart,
          },
      ],
    };
    File(
      '${out.path}/neonstadt_v9_geometry.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(geometry));
    notifier.dispose();
  });
}
