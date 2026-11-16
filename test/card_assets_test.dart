import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/ui/card_face_image.dart';

void main() {
  test('Alle Kartenbilder und Eckzeichen sind vorhanden', () {
    final missing = [for (final a in allCardAssets) if (!File(a).existsSync()) a];
    expect(missing, isEmpty);
    // 52 Karten, 2 Joker, 15 Ränge, 4 Farben, JOKER
    expect(allCardAssets.length, 52 + 2 + 15 + 4 + 1);
  });

  test('Kartenbilder sind im pubspec eingetragen', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/cards/\n'));
    expect(pubspec, contains('- assets/cards/index/\n'));
  });
}
