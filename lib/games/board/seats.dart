import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';

/// Ein Platz am Tisch: Mensch an diesem Gerät oder Computer.
class Seat {
  const Seat(this.name, {this.human = false});
  final String name;
  final bool human;

  Map<String, Object> toJson() => {'n': name, 'h': human};
  static Seat fromJson(Map<String, dynamic> j) => Seat(j['n'] as String, human: j['h'] as bool);
}

const seatColorNames = ['Rot', 'Blau', 'Grün', 'Gelb', 'Lila', 'Orange'];
const seatColors = [
  Color(0xFFD8402B),
  Color(0xFF2F7FD0),
  Color(0xFF2E9E57),
  Color(0xFFE8B923),
  Color(0xFF8E4FC9),
  Color(0xFFEE7F2D),
];
const _botNames = ['Mia', 'Ben', 'Lea', 'Tom', 'Ida', 'Max'];

/// Fragt vor dem Spiel, wer mitspielt: Anzahl der Plätze, wer davon Mensch ist und wie er heißt.
/// Freie Plätze übernimmt der Computer. Die Wahl wird pro Spiel gemerkt.
Future<List<Seat>?> showSeatSetup(
  BuildContext context, {
  required String gameId,
  required String title,
  int minSeats = 2,
  int maxSeats = 4,
  List<String> colorNames = seatColorNames,
  List<Color> colors = seatColors,
}) {
  final store = AppScope.of(context).settings;
  final saved = store.loadGame('seats.$gameId');
  var count = minSeats == maxSeats ? minSeats : 2.clamp(minSeats, maxSeats);
  final humans = List<bool>.generate(maxSeats, (i) => i == 0);
  final names = List<String>.generate(maxSeats, (i) => i == 0 ? 'Du' : 'Spieler ${i + 1}');
  if (saved != null) {
    try {
      final list = [for (final j in saved['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
      if (list.length >= minSeats && list.length <= maxSeats) {
        count = list.length;
        for (var i = 0; i < list.length; i++) {
          humans[i] = list[i].human;
          if (list[i].human) names[i] = list[i].name;
        }
      }
    } catch (_) {
      // alte oder kaputte Wahl: Standard
    }
  }
  final controllers = [for (final n in names) TextEditingController(text: n)];
  return showModalBottomSheet<List<Seat>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = Palette.of(context);
      return StatefulBuilder(
        builder: (context, setState) {
          final anyHuman = humans.take(count).any((h) => h);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9, maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Wer spielt an diesem Gerät mit? Alle anderen Plätze übernimmt der Computer.',
                        style: TextStyle(color: p.inkSoft, fontSize: 14),
                      ),
                      if (minSeats != maxSeats) ...[
                        const SizedBox(height: 10),
                        Text('Plätze am Tisch', style: TextStyle(color: p.ink, fontSize: 16)),
                        const SizedBox(height: 6),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            for (var n = minSeats; n <= maxSeats; n++) ButtonSegment(value: n, label: Text('$n')),
                          ],
                          selected: {count},
                          onSelectionChanged: (s) => setState(() => count = s.first),
                        ),
                      ],
                      const SizedBox(height: 10),
                      for (var i = 0; i < count; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Tooltip(
                                message: colorNames[i],
                                child: CircleAvatar(radius: 12, backgroundColor: colors[i]),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: humans[i]
                                    ? TextField(
                                        controller: controllers[i],
                                        maxLength: 14,
                                        decoration: const InputDecoration(isDense: true, counterText: '', hintText: 'Name'),
                                        style: TextStyle(color: p.ink, fontSize: 16),
                                      )
                                    : Text('Computer (${_botNames[i]})', style: TextStyle(color: p.inkSoft, fontSize: 16)),
                              ),
                              const SizedBox(width: 8),
                              SegmentedButton<bool>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                segments: const [
                                  ButtonSegment(value: true, icon: Icon(Icons.person), tooltip: 'Mensch'),
                                  ButtonSegment(value: false, icon: Icon(Icons.smart_toy), tooltip: 'Computer'),
                                ],
                                selected: {humans[i]},
                                onSelectionChanged: (s) => setState(() => humans[i] = s.first),
                              ),
                            ],
                          ),
                        ),
                      if (!anyHuman)
                        Text('Mindestens ein Mensch muss mitspielen.', style: TextStyle(color: p.danger, fontSize: 14)),
                      const SizedBox(height: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: p.onAccent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: !anyHuman
                            ? null
                            : () {
                                final seats = [
                                  for (var i = 0; i < count; i++)
                                    humans[i]
                                        ? Seat(
                                            controllers[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : controllers[i].text.trim(),
                                            human: true,
                                          )
                                        : Seat(_botNames[i]),
                                ];
                                store.saveGame('seats.$gameId', {
                                  'seats': [for (final s in seats) s.toJson()],
                                });
                                Navigator.of(context).pop(seats);
                              },
                        child: const Text('Los geht’s', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Nur Menschen am Tisch: dann gibt es keine Münzen, es ist ein Spiel unter Freunden.
bool vsComputer(List<Seat> seats) => seats.any((s) => !s.human);

/// Münzen nur, wenn ein Mensch gegen mindestens einen Computer gewinnt.
int seatReward(List<Seat> seats, int winner, int amount) =>
    seats[winner].human && vsComputer(seats) ? amount : 0;
