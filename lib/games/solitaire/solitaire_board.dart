import 'package:flutter/material.dart';

import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'table_card.dart';

/// Gegriffene Karte samt allem, was darauf liegt.
class Grab {
  const Grab(this.from, this.index);
  final PileRef from;
  final int index;
}

/// Abstände in einer Spalte. Wird es zu eng, rücken die Karten zusammen.
List<double> columnOffsets(
  List<TableCard> cards,
  double cardH,
  double availH, {
  double upFactor = 0.3,
  double downFactor = 0.13,
}) {
  if (cards.isEmpty) return [];
  var du = cardH * upFactor;
  var dd = cardH * downFactor;
  var need = 0.0;
  for (var i = 0; i < cards.length - 1; i++) {
    need += cards[i].up ? du : dd;
  }
  final room = availH - cardH;
  if (need > room && need > 0) {
    final k = (room / need).clamp(0.0, 1.0);
    du *= k;
    dd *= k;
  }
  final out = <double>[];
  var y = 0.0;
  for (var i = 0; i < cards.length; i++) {
    out.add(y);
    y += cards[i].up ? du : dd;
  }
  return out;
}

/// Ziehbare Karte. Mitgezogen werden alle Karten, die darauf liegen.
class CardRunDraggable extends StatelessWidget {
  const CardRunDraggable({
    super.key,
    required this.grab,
    required this.run,
    required this.width,
    required this.step,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.child,
    this.onTap,
  });

  final Grab grab;
  final List<TableCard> run;
  final double width;
  final double step;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ch = width / cardAspect;
    return Draggable<Grab>(
      data: grab,
      maxSimultaneousDrags: 1,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          height: ch + step * (run.length - 1),
          child: Stack(
            children: [
              for (var i = 0; i < run.length; i++)
                Positioned(
                  top: i * step,
                  child: PlayingCardView(width: width, card: run[i].card, strip: true),
                ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0, child: child),
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

/// Eine Spalte der Auslage: Ablageziel und Quelle zugleich.
class TableauColumn extends StatelessWidget {
  const TableauColumn({
    super.key,
    required this.ref,
    required this.cards,
    required this.width,
    required this.height,
    required this.canPick,
    required this.onTap,
    required this.canAccept,
    required this.onAccept,
    required this.onDragStart,
    required this.onDragEnd,
    this.hideFrom,
    this.emptyLabel,
  });

  final PileRef ref;
  final List<TableCard> cards;
  final double width;
  final double height;
  final bool Function(int index) canPick;
  final void Function(int index) onTap;
  final bool Function(Grab grab) canAccept;
  final void Function(Grab grab) onAccept;
  final void Function(Grab grab) onDragStart;
  final VoidCallback onDragEnd;
  final int? hideFrom;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ch = width / cardAspect;
    final offs = columnOffsets(cards, ch, height);
    return DragTarget<Grab>(
      onWillAcceptWithDetails: (d) => canAccept(d.data),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) => Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (cards.isEmpty)
              CardSlot(width: width, label: emptyLabel, glow: candidates.isNotEmpty),
            for (var i = 0; i < cards.length; i++)
              Positioned(
                top: offs[i],
                child: Opacity(
                  opacity: hideFrom != null && i >= hideFrom! ? 0 : 1,
                  child: _card(i, offs, ch),
                ),
              ),
            if (candidates.isNotEmpty && cards.isNotEmpty)
              Positioned(
                top: offs.last,
                child: IgnorePointer(
                  child: Container(
                    width: width,
                    height: ch,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width * 0.09),
                      border: Border.all(color: const Color(0xFFFFC95C), width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(int i, List<double> offs, double ch) {
    final c = cards[i];
    final view = PlayingCardView(width: width, card: c.up ? c.card : null, strip: true);
    if (!c.up) return view;
    if (!canPick(i)) return GestureDetector(onTap: () => onTap(i), child: view);
    final step = i + 1 < cards.length ? offs[i + 1] - offs[i] : ch * 0.3;
    final grab = Grab(ref, i);
    return CardRunDraggable(
      grab: grab,
      run: cards.sublist(i),
      width: width,
      step: step,
      onTap: () => onTap(i),
      onDragStarted: () => onDragStart(grab),
      onDragEnd: onDragEnd,
      child: view,
    );
  }
}

/// Fußleiste der Patiencen: Meldung, Rückgängig, neues Spiel.
class SolitaireBar extends StatelessWidget {
  const SolitaireBar({
    super.key,
    required this.message,
    required this.highlight,
    required this.onUndo,
    required this.onNew,
    this.vertical = false,
  });

  final String message;
  final bool highlight;
  final VoidCallback? onUndo;
  final VoidCallback onNew;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ActionButton(label: 'Rückgängig', onPressed: onUndo),
      ActionButton(primary: highlight, label: 'Neues Spiel', onPressed: onNew),
    ];
    if (vertical) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlight ? const Color(0xFFFFC95C) : const Color(0xFFF6E7C8),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBanner(text: message, highlight: highlight),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: buttons),
      ],
    );
  }
}
