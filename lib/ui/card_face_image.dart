import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../games/cards/playing_card.dart';

/// Druckfarben der gezeichneten Karten (aus den Bildern gemessen).
const cardRed = Color(0xFFDA060A);
const cardBlack = Color(0xFF090908);

/// Breite, ab der die Eckzeichen in normaler Größe erscheinen. Kleinere Karten bekommen größere Zeichen.
const _comfortWidth = 72.0;

String cardAsset(PlayingCard card) => 'assets/cards/${card.suit.name}_${card.rank}.webp';

String jokerAsset({required bool red}) => 'assets/cards/joker_${red ? 'red' : 'black'}.webp';

/// Alle Bilder des Blatts, zum Vorladen.
List<String> get allCardAssets => [
      for (final s in Suit.values)
        for (var r = 2; r <= 14; r++) cardAsset(PlayingCard(r, s)),
      jokerAsset(red: true),
      jokerAsset(red: false),
      for (final r in ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A', 'J', 'Q', 'K', 'B', 'D'])
        'assets/cards/index/rank_$r.png',
      for (final s in Suit.values) 'assets/cards/index/suit_${s.name}.png',
      'assets/cards/index/joker.png',
    ];

/// Vorderseite aus den gezeichneten Bildern: Bild ohne Ecken, die Eckzeichen setzt die App in alle vier Ecken.
///
/// [label] ist das Eckzeichen (J/Q oder B/D je nach Einstellung). Fehlt das Bild oder lädt es noch, erscheint
/// [fallback].
class CardFaceImage extends StatelessWidget {
  const CardFaceImage({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.ink,
    required this.fallback,
    this.label,
    this.suit,
    this.strip = false,
  });

  /// Eine Spielkarte.
  factory CardFaceImage.card(
    PlayingCard card, {
    Key? key,
    required String label,
    required double width,
    required double height,
    required Widget fallback,
    bool strip = false,
  }) =>
      CardFaceImage(
        key: key,
        asset: cardAsset(card),
        width: width,
        height: height,
        ink: card.isRed ? cardRed : cardBlack,
        label: label,
        suit: card.suit,
        strip: strip,
        fallback: fallback,
      );

  /// Joker, rot oder schwarz. Eckzeichen „JOKER“ senkrecht mit Stern.
  factory CardFaceImage.joker({
    Key? key,
    required bool red,
    required double width,
    required double height,
    required Widget fallback,
  }) =>
      CardFaceImage(
        key: key,
        asset: jokerAsset(red: red),
        width: width,
        height: height,
        ink: red ? cardRed : cardBlack,
        fallback: fallback,
      );

  final String asset;
  final double width;
  final double height;
  final Color ink;
  final Widget fallback;

  /// Rang im Eck, null beim Joker.
  final String? label;
  final Suit? suit;

  /// Rang und Farbe groß oben, für überlappende Patiencen-Spalten.
  final bool strip;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final w = width;
    final h = height;
    // Kleine Karten: Eckzeichen bis zu 1,7-mal größer, damit sie lesbar bleiben.
    final k = (_comfortWidth / w).clamp(1.0, 1.7);
    final children = <Widget>[
      Image.asset(
        asset,
        width: w,
        height: h,
        fit: BoxFit.fill,
        // In Stufen von 64 px, damit gleich große Karten sich ein dekodiertes Bild teilen.
        cacheWidth: math.min(530, ((w * dpr) / 64).ceil() * 64),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) => sync || frame != null ? child : fallback,
        errorBuilder: (context, error, stack) => fallback,
      ),
    ];

    Widget glyph(String name, double gh, double boxW) => SizedBox(
          width: boxW,
          height: gh,
          child: Image.asset(
            'assets/cards/index/$name.png',
            fit: BoxFit.contain,
            color: ink,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        );

    // Ein Zeichen in allen vier Ecken: Mitte bei cx (und w - cx), Oberkante bei top, unten um 180° gedreht.
    void corner(String name, double cx, double top, double gh, double boxW) {
      for (final x in [cx, w - cx]) {
        children.add(Positioned(left: x - boxW / 2, top: top, child: glyph(name, gh, boxW)));
        children.add(Positioned(
          left: w - x - boxW / 2,
          top: h - top - gh,
          child: RotatedBox(quarterTurns: 2, child: glyph(name, gh, boxW)),
        ));
      }
    }

    final s = suit;
    final l = label;
    if (l == null) {
      final gh = h * 0.2;
      corner('joker', w * 0.03 + gh * 0.09, h * 0.032, gh, gh * 0.2);
    } else if (s != null) {
      final rankH = h * 0.0755 * k;
      final suitH = h * 0.063 * k;
      final cx = w * 0.03 + rankH * 0.6;
      final rankTop = h * 0.032;
      final suitTop = rankTop + rankH + h * 0.0095 * k;
      if (strip) {
        // Groß oben: Rang links, Farbe rechts. Unten die normalen Zeichen.
        final bigRank = h * 0.13;
        final bigSuit = h * 0.11;
        children.add(Positioned(left: w * 0.035, top: h * 0.03, child: glyph('rank_$l', bigRank, bigRank * 1.3)));
        children.add(Positioned(
          left: w - w * 0.035 - bigSuit,
          top: h * 0.035,
          child: glyph('suit_${s.name}', bigSuit, bigSuit),
        ));
        for (final x in [cx, w - cx]) {
          children.add(Positioned(
            left: w - x - rankH * 0.8,
            top: h - rankTop - rankH,
            child: RotatedBox(quarterTurns: 2, child: glyph('rank_$l', rankH, rankH * 1.6)),
          ));
          children.add(Positioned(
            left: w - x - suitH * 0.8,
            top: h - suitTop - suitH,
            child: RotatedBox(quarterTurns: 2, child: glyph('suit_${s.name}', suitH, suitH * 1.6)),
          ));
        }
      } else {
        corner('rank_$l', cx, rankTop, rankH, rankH * 1.6);
        corner('suit_${s.name}', cx, suitTop, suitH, suitH * 1.6);
      }
    }
    return SizedBox(width: w, height: h, child: Stack(clipBehavior: Clip.hardEdge, children: children));
  }
}
