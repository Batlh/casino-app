import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'playing_card.dart';

/// Leerer Platz für einen Stapel.
class CardSlot extends StatelessWidget {
  const CardSlot({super.key, required this.width, this.label, this.icon, this.glow = false});

  final double width;
  final String? label;
  final IconData? icon;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final onFelt = Palette.of(context).onFelt;
    return Container(
      width: width,
      height: width / cardAspect,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: glow ? const Color(0x33FFC95C) : const Color(0x14000000),
        borderRadius: BorderRadius.circular(width * 0.09),
        border: Border.all(
          color: glow ? const Color(0xFFFFC95C) : onFelt.withValues(alpha: 0.35),
          width: glow ? 2.5 : 1.5,
        ),
      ),
      child: icon != null
          ? Icon(icon, size: width * 0.42, color: onFelt.withValues(alpha: 0.6))
          : label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    fontFamily: displayFont,
                    fontSize: width * 0.36,
                    color: onFelt.withValues(alpha: 0.45),
                  ),
                )
              : null,
    );
  }
}

/// Reihenfolge auf der Hand: Kreuz, Karo, Pik, Herz, jeweils aufsteigend.
List<PlayingCard> sortedHand(Iterable<PlayingCard> cards) {
  const order = [Suit.clubs, Suit.diamonds, Suit.spades, Suit.hearts];
  return cards.toList()
    ..sort((a, b) {
      final s = order.indexOf(a.suit).compareTo(order.indexOf(b.suit));
      return s != 0 ? s : a.rank.compareTo(b.rank);
    });
}

/// Handkarten nebeneinander, überlappend, wenn der Platz nicht reicht.
class HandFan extends StatelessWidget {
  const HandFan({
    super.key,
    required this.cards,
    required this.maxCardWidth,
    this.isEnabled,
    this.isRaised,
    this.onTap,
  });

  final List<PlayingCard> cards;
  final double maxCardWidth;
  final bool Function(PlayingCard card)? isEnabled;
  final bool Function(PlayingCard card)? isRaised;
  final ValueChanged<PlayingCard>? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final total = box.maxWidth;
        final n = cards.length;
        var w = math.min(maxCardWidth, total);
        var step = w * 1.04;
        if (n > 1) {
          step = math.min(step, (total - w) / (n - 1));
          if (step < w * 0.3) {
            w = total / (1 + 0.3 * (n - 1));
            step = w * 0.3;
          }
        }
        final lift = w * 0.2;
        final height = w / cardAspect + lift;
        final width = n == 0 ? 0.0 : w + step * (n - 1);
        return SizedBox(
          height: height,
          width: total,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: (total - width) / 2 + i * step,
                  top: (isRaised?.call(cards[i]) ?? false) ? 0 : lift,
                  child: GestureDetector(
                    onTap: onTap == null ? null : () => onTap!(cards[i]),
                    child: _Dim(
                      dim: !(isEnabled?.call(cards[i]) ?? true),
                      child: PlayingCardView(
                        width: w,
                        card: cards[i],
                        highlighted: isRaised?.call(cards[i]) ?? false,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Gegner mit Namen, verdeckten Karten und einer Zusatzzeile.
class OpponentBadge extends StatelessWidget {
  const OpponentBadge({
    super.key,
    required this.name,
    required this.cardCount,
    required this.active,
    this.detail = '',
    this.width = 104,
    this.backBuilder,
    this.cardBuilder,
  });

  /// Eigener Kartenrücken, sonst der Rücken der Spielkarten.
  final Widget Function(double width)? backBuilder;

  /// Eigene Karte je Platz, zum Beispiel die sichtbare Rückseite bei der Kehrseite.
  final Widget Function(double width, int index)? cardBuilder;

  final String name;
  final int cardCount;
  final bool active;
  final String detail;
  final double width;

  @override
  Widget build(BuildContext context) {
    final shown = math.min(cardCount, 6);
    final cw = width * 0.3;
    final step = shown <= 1 ? 0.0 : (width - cw) / math.max(5, shown - 1);
    final fanWidth = shown == 0 ? 0.0 : cw + step * (shown - 1);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: cw / cardAspect * 0.62,
            width: fanWidth,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var i = 0; i < shown; i++)
                    Positioned(
                      left: i * step,
                      child: cardBuilder?.call(cw, i) ?? backBuilder?.call(cw) ?? PlayingCardView(width: cw),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xE62A160E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? const Color(0xFFFFC95C) : const Color(0xFF6B3E1E),
                width: active ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF6E7C8),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.15,
                  ),
                ),
                Text(
                  detail.isEmpty ? '$cardCount Karten' : detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFC95C),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Auswahl aus wenigen Möglichkeiten als Blatt von unten.
Future<int?> showChoiceSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = Palette.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (var i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).pop(i),
                    child: Text(options[i], textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          ),
        ),
      );
    },
  );
}

/// Farbwahl für den Buben.
Future<Suit?> showSuitPicker(BuildContext context) {
  return showModalBottomSheet<Suit>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Farbe wünschen', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in const [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds])
                    Semantics(
                      button: true,
                      label: switch (s) {
                        Suit.spades => 'Pik',
                        Suit.hearts => 'Herz',
                        Suit.diamonds => 'Karo',
                        Suit.clubs => 'Kreuz',
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(s),
                        child: Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6B3E1E), width: 2),
                          ),
                          child: SuitIcon(
                            suit: s,
                            size: 44,
                            color: s == Suit.hearts || s == Suit.diamonds
                                ? const Color(0xFFC8321F)
                                : const Color(0xFF241410),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Wie [HandFan], aber für beliebige Karten mit eigenem Aussehen.
class CardFan<T> extends StatelessWidget {
  const CardFan({
    super.key,
    required this.items,
    required this.maxCardWidth,
    required this.cardBuilder,
    this.isEnabled,
    this.isRaised,
    this.onTap,
  });

  final List<T> items;
  final double maxCardWidth;
  final Widget Function(T item, double width, bool raised) cardBuilder;
  final bool Function(T item)? isEnabled;
  final bool Function(T item)? isRaised;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final total = box.maxWidth;
        final n = items.length;
        var w = math.min(maxCardWidth, total);
        var step = w * 1.04;
        if (n > 1) {
          step = math.min(step, (total - w) / (n - 1));
          if (step < w * 0.3) {
            w = total / (1 + 0.3 * (n - 1));
            step = w * 0.3;
          }
        }
        final lift = w * 0.2;
        final width = n == 0 ? 0.0 : w + step * (n - 1);
        return SizedBox(
          height: w / cardAspect + lift,
          width: total,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: (total - width) / 2 + i * step,
                  top: (isRaised?.call(items[i]) ?? false) ? 0 : lift,
                  child: GestureDetector(
                    onTap: onTap == null ? null : () => onTap!(items[i]),
                    child: _Dim(
                      dim: !(isEnabled?.call(items[i]) ?? true),
                      child: cardBuilder(items[i], w, isRaised?.call(items[i]) ?? false),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Nicht spielbare Karten werden abgedunkelt statt durchsichtig, damit
/// überlappende Karten sauber getrennt bleiben.
class _Dim extends StatelessWidget {
  const _Dim({required this.dim, required this.child});
  final bool dim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!dim) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0x73000000), BlendMode.srcATop),
      child: child,
    );
  }
}
