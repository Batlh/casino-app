import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../cards/card_widgets.dart';

/// Wahl vor einer Brettpartie: Computer mit Stufe oder zu zweit, dazu die Farbe.
class BoardSetup {
  const BoardSetup({this.level, this.humanFirst = true});

  /// Index der Computerstufe, null bei zwei Spielern an einem Gerät.
  final int? level;

  /// Der Mensch hat den ersten Zug (Weiß bzw. Sente).
  final bool humanFirst;

  bool get vsComputer => level != null;
}

Future<BoardSetup?> showBoardSetup(
  BuildContext context, {
  required List<String> levels,
  required List<int> rewards,
  required String firstSide,
  required String secondSide,
}) async {
  final i = await showChoiceSheet(
    context,
    title: 'Gegen wen spielst du?',
    options: [
      for (var k = 0; k < levels.length; k++) 'Computer: ${levels[k]}, Sieg bringt ${formatCoins(rewards[k])} Münzen',
      'Zu zweit an diesem Gerät',
    ],
  );
  if (i == null || !context.mounted) return null;
  if (i == levels.length) return const BoardSetup();
  final c = await showChoiceSheet(
    context,
    title: 'Welche Seite nimmst du?',
    options: ['$firstSide, du beginnst', secondSide, 'Zufällig'],
  );
  if (c == null) return null;
  final first = c == 0 || (c == 2 && Random().nextBool());
  return BoardSetup(level: i, humanFirst: first);
}
