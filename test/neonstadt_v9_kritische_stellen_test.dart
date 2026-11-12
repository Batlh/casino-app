import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:forge2d/forge2d.dart' as f;

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

void main() {
  test('240 gezielte Kugeln: Zungen, Trichter, Sockelgassen, Stößel und Ecken', () {
    final faults = <String>[], records = <Map<String, Object?>>[];
    final entrances = cityTable.ramps.where((r) => r.skillBand < 0).toList();
    expect(entrances.length, 6);
    for (var trial = 0; trial < 240; trial++) {
      final rng = Random(8000 + trial),
          t = PinballTable(rng: Random(8000 + trial), spec: cityTable),
          family = trial % 12;
      var name = '';
      if (family < 6) {
        final r = entrances[family];
        name = 'Einfahrt ${r.id}';
        t.debugPlaceBall(
          (r.a.x + r.b.x) / 2 + (rng.nextDouble() - .5) * .12,
          r.a.y + .35,
          (rng.nextDouble() - .5) * .4,
          (trial ~/ 12).isEven ? -12 : -r.minSpeed * .6,
        );
      } else if (family == 6) {
        name = 'Kerntrichter';
        t.debugPlaceBall(
          5.2735 + (rng.nextDouble() - .5) * .4,
          5.65,
          0,
          -(3 + rng.nextDouble() * 7),
        );
      } else if (family == 7) {
        name = 'Sockelgasse links';
        t.debugPlaceBall(3.45 + (rng.nextDouble() - .5) * .18, 5.6, 0, -5);
      } else if (family == 8) {
        name = 'Sockelgasse rechts';
        t.debugPlaceBall(7.10 + (rng.nextDouble() - .5) * .18, 5.6, 0, -5);
      } else if (family == 9) {
        name = 'Kickback';
        t.city!.kickbackLit = (trial ~/ 12).isEven;
        t.debugPlaceBall(.53, 15.64, 0, 3);
      } else if (family == 10) {
        name = 'Linke obere Ecke';
        t.debugPlaceBall(.40, .70, (rng.nextDouble() - .5), 2);
      } else {
        name = 'Abschuss und Übergänge';
        t.charge = .2 + rng.nextDouble() * .8;
        t.launch();
      }
      final slow = <Ball, double>{};
      var armed = true, hold = 0.0, holdLeft = true;
      var nudges = 0, escaped = false, stuck = false, frames = 0;
      for (; frames < 1920 && !t.gameOver; frames++) {
        final p = t.ball;
        if (p != null && p.y < 14) armed = true;
        if (armed && p != null && p.y > 14.4 && p.x > 1.8 && p.x < 7.4) {
          hold = .20;
          holdLeft = p.x < 4.6;
          armed = false;
        }
        hold -= 1 / 120;
        t.leftPressed = hold > 0 && holdLeft;
        t.rightPressed = hold > 0 && !holdLeft;
        t.step(1 / 120);
        nudges += t.events
            .where((e) => e.kind == PinballEventKind.nudge)
            .length;
        t.events.clear();
        if (t.ballInLane) break;
        for (final b in t.balls) {
          final q = b.pos;
          if (!q.x.isFinite ||
              !q.y.isFinite ||
              q.x < -.1 ||
              q.x > 10.05 ||
              q.y < -.1)
            escaped = true;
          final body = b.body;
          if (body != null &&
              body.position.x < PinballTable.fieldRight &&
              body.linearVelocity.length < .25)
            slow[b] = (slow[b] ?? 0) + 1 / 120;
          else
            slow[b] = 0;
          if ((slow[b] ?? 0) > 1.5) stuck = true;
        }
        if (escaped || stuck) break;
      }
      if (trial == 0 && stuck) {
        final body = t.balls.first.body!;
        for (final contact in body.contacts.where((c) => c.isTouching())) {
          final fixture = identical(contact.fixtureA.body, body)
              ? contact.fixtureB
              : contact.fixtureA;
          final shape = fixture.shape;
          print(
            'KONTAKT ${shape.runtimeType} Körper ${fixture.body.position} Winkel ${fixture.body.angle}',
          );
          if (shape is f.EdgeShape)
            print('KANTE ${shape.vertex1} → ${shape.vertex2}');
          if (shape is f.PolygonShape) print('POLYGON ${shape.vertices}');
        }
      }
      if (escaped || stuck || nudges > 0)
        faults.add(
          '$trial $name: hängen=$stuck außerhalb=$escaped Schubs=$nudges bei ${t.ball?.x},${t.ball?.y}',
        );
      records.add({
        'versuch': trial,
        'stelle': name,
        'schritte': frames,
        'haengt': stuck,
        'ausserhalb': escaped,
        'schubser': nudges,
      });
    }
    final out = Platform.environment['NEONSTADT_EVIDENCE'];
    if (out != null)
      File('$out/Haengetest_kritische_Stellen.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'kugeln': 240, 'fehler': faults, 'versuche': records}),
      );
    print('Neonstadt V9: 240 gezielte Starts, Fehler ${faults.length}');
    for (final f in faults.take(20)) print(f);
    expect(faults, isEmpty);
  });
}
