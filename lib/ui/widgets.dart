import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/sfx.dart';
import '../core/theme.dart';
import '../core/wallet.dart';
import '../games/cards/playing_card.dart';

/// Geprägter Pfennig, die Münze der App.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _CoinPainter(),
      );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFD98A), Color(0xFFD6923A), Color(0xFF8D5420)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = const Color(0xAA6B3E1E),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'Pf',
        style: TextStyle(
          fontFamily: displayFont,
          fontSize: r * 0.82,
          color: const Color(0xFF4A2A14),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Münzstand mit hochzählender Anzeige.
class BalanceBadge extends StatelessWidget {
  const BalanceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = AppScope.of(context).wallet;
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) => Semantics(
        label: '${formatCoins(wallet.balance)} Münzen',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: p.panelEdge, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 24),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(end: wallet.balance.toDouble()),
                duration: const Duration(milliseconds: 500),
                builder: (context, v, _) => Text(
                  formatCoins(v.round()),
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rahmen jedes Spiels: Kopfzeile, Münzstand, Ton und Filz oder Hintergrund.
class GameFrame extends StatefulWidget {
  const GameFrame({
    super.key,
    required this.title,
    required this.child,
    this.background,
  });

  final String title;
  final Widget child;
  final Decoration? background;

  @override
  State<GameFrame> createState() => _GameFrameState();
}

class _GameFrameState extends State<GameFrame> {
  late final Wallet _wallet = AppScope.of(context).wallet;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      _listening = true;
      _wallet.refills.addListener(_onRefill);
    }
  }

  void _onRefill() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Münzen aufgebraucht. ${formatCoins(Wallet.refillAmount)} neue Münzen sind da.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wallet.refills.removeListener(_onRefill);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sfx = AppScope.of(context).sfx;
    return Scaffold(
      backgroundColor: p.bg,
      body: DecoratedBox(
        decoration: widget.background ??
            BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [p.felt, p.feltEdge],
              ),
            ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: p.bg,
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Zurück zur Lobby',
                      icon: Icon(Icons.arrow_back, color: p.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: sfx,
                      builder: (context, _) => IconButton(
                        tooltip: sfx.enabled ? 'Ton ausschalten' : 'Ton einschalten',
                        icon: Icon(
                          sfx.enabled ? Icons.volume_up : Icons.volume_off,
                          color: p.ink,
                        ),
                        onPressed: sfx.toggle,
                      ),
                    ),
                    const BalanceBadge(),
                  ],
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

const List<int> betSteps = [10, 50, 100, 500, 1000];

Color chipColor(int value) => switch (value) {
      10 => const Color(0xFFEFE3C6),
      50 => const Color(0xFFD8402B),
      100 => const Color(0xFF1F7FA3),
      500 => const Color(0xFF3A2116),
      _ => const Color(0xFFD99A2B),
    };

/// Runder Jeton mit gestreiftem Rand.
class BetChip extends StatelessWidget {
  const BetChip({super.key, required this.value, this.size = 52});
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ChipPainter(value)),
      );
}

class _ChipPainter extends CustomPainter {
  _ChipPainter(this.value);
  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final base = chipColor(value);
    final onBase =
        base.computeLuminance() > 0.45 ? const Color(0xFF2A160E) : Colors.white;
    canvas.drawCircle(c, r, Paint()..color = base);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.2
      ..color = onBase.withValues(alpha: 0.85);
    final rect = Rect.fromCircle(center: c, radius: r * 0.9);
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(rect, i * math.pi / 3, math.pi / 7, false, dash);
    }
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = onBase.withValues(alpha: 0.7),
    );
    final label = value >= 1000 ? '${value ~/ 1000}k' : '$value';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          fontSize: r * 0.62,
          color: onBase,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.value != value;
}

/// Reihe von Jetons zum Wählen des Einsatzes.
class BetPicker extends StatelessWidget {
  const BetPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 50,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final onFelt = Palette.of(context).onFelt;
    return ListenableBuilder(
      listenable: app.wallet,
      builder: (context, _) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final step in betSteps)
            Semantics(
              button: true,
              selected: step == value,
              label: 'Einsatz ${formatCoins(step)}',
              child: Opacity(
                opacity: enabled && app.wallet.canAfford(step) ? 1 : 0.35,
                child: GestureDetector(
                  onTap: enabled && app.wallet.canAfford(step)
                      ? () {
                          app.sfx.play(Sound.chip);
                          onChanged(step);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 3,
                        color: step == value ? onFelt : Colors.transparent,
                      ),
                    ),
                    child: BetChip(value: step, size: size),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Großer Aktionsknopf für den Spieltisch.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor: primary ? p.accent : p.panel,
        foregroundColor: primary ? p.onAccent : p.ink,
        disabledBackgroundColor: p.panel.withValues(alpha: 0.45),
        disabledForegroundColor: p.ink.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: primary ? Colors.transparent : p.panelEdge,
            width: 2,
          ),
        ),
      ),
      child: Text(label, maxLines: 1),
    );
  }
}

/// Ergebniszeile. Reserviert ihre Höhe, damit der Tisch nicht springt.
class ResultBanner extends StatelessWidget {
  const ResultBanner({super.key, required this.text, this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 38,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            text,
            key: ValueKey(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: highlight ? displayFont : bodyFont,
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 24 : 18,
              color: highlight ? const Color(0xFFFFC95C) : p.onFelt,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeichnet ein Kartensymbol als Fläche. Unabhängig von Systemschriften.
void paintSuit(Canvas canvas, Rect r, Suit suit, Color color) {
  final paint = Paint()..color = color;
  final w = r.width;
  final h = r.height;
  double x(double v) => r.left + v * w;
  double y(double v) => r.top + v * h;

  Path heart() => Path()
    ..moveTo(x(0.5), y(0.95))
    ..cubicTo(x(0.05), y(0.6), x(-0.05), y(0.3), x(0.1), y(0.14))
    ..cubicTo(x(0.25), y(0), x(0.43), y(0.08), x(0.5), y(0.26))
    ..cubicTo(x(0.57), y(0.08), x(0.75), y(0), x(0.9), y(0.14))
    ..cubicTo(x(1.05), y(0.3), x(0.95), y(0.6), x(0.5), y(0.95))
    ..close();

  switch (suit) {
    case Suit.hearts:
      canvas.drawPath(heart(), paint);
    case Suit.diamonds:
      canvas.drawPath(
        Path()
          ..moveTo(x(0.5), y(0.02))
          ..quadraticBezierTo(x(0.68), y(0.3), x(0.9), y(0.5))
          ..quadraticBezierTo(x(0.68), y(0.7), x(0.5), y(0.98))
          ..quadraticBezierTo(x(0.32), y(0.7), x(0.1), y(0.5))
          ..quadraticBezierTo(x(0.32), y(0.3), x(0.5), y(0.02))
          ..close(),
        paint,
      );
    case Suit.spades:
      canvas.drawPath(
        Path()
          ..moveTo(x(0.5), y(0.02))
          ..cubicTo(x(0.95), y(0.38), x(1.08), y(0.6), x(0.9), y(0.74))
          ..cubicTo(x(0.75), y(0.84), x(0.6), y(0.76), x(0.54), y(0.68))
          ..quadraticBezierTo(x(0.56), y(0.86), x(0.68), y(0.98))
          ..lineTo(x(0.32), y(0.98))
          ..quadraticBezierTo(x(0.44), y(0.86), x(0.46), y(0.68))
          ..cubicTo(x(0.4), y(0.76), x(0.25), y(0.84), x(0.1), y(0.74))
          ..cubicTo(x(-0.08), y(0.6), x(0.05), y(0.38), x(0.5), y(0.02))
          ..close(),
        paint,
      );
    case Suit.clubs:
      canvas.drawCircle(Offset(x(0.5), y(0.27)), w * 0.23, paint);
      canvas.drawCircle(Offset(x(0.24), y(0.58)), w * 0.23, paint);
      canvas.drawCircle(Offset(x(0.76), y(0.58)), w * 0.23, paint);
      canvas.drawPath(
        Path()
          ..moveTo(x(0.46), y(0.45))
          ..quadraticBezierTo(x(0.46), y(0.84), x(0.32), y(0.98))
          ..lineTo(x(0.68), y(0.98))
          ..quadraticBezierTo(x(0.54), y(0.84), x(0.54), y(0.45))
          ..close(),
        paint,
      );
  }
}

class SuitIcon extends StatelessWidget {
  const SuitIcon({super.key, required this.suit, required this.size, required this.color});
  final Suit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _SuitPainter(suit, color),
      );
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);
  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSuit(canvas, Offset.zero & size, suit, color);

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}

const double cardAspect = 2.5 / 3.5;

/// Spielkarte oder Kartenrücken in beliebiger Breite.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.width,
    this.card,
    this.highlighted = false,
  });

  final double width;

  /// null zeigt den Rücken.
  final PlayingCard? card;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final height = width / cardAspect;
    final radius = BorderRadius.circular(width * 0.09);
    final c = card;
    return Semantics(
      label: c?.spokenName ?? 'Verdeckte Karte',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: radius,
          border: Border.all(
            color: highlighted ? const Color(0xFFFFC95C) : const Color(0x33000000),
            width: highlighted ? 3 : 1,
          ),
          boxShadow: const [
            BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x66000000)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: c == null
              ? CustomPaint(painter: _CardBackPainter())
              : _CardFace(card: c, width: width, height: height),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width, required this.height});
  final PlayingCard card;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? const Color(0xFFC8321F) : const Color(0xFF241410);
    final corner = Padding(
      padding: EdgeInsets.all(width * 0.06),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.rankLabel,
            style: TextStyle(
              fontFamily: bodyFont,
              fontWeight: FontWeight.w700,
              fontSize: width * 0.25,
              height: 1,
              color: color,
            ),
          ),
          SuitIcon(suit: card.suit, size: width * 0.17, color: color),
        ],
      ),
    );
    final isFace = card.rank >= 11 && card.rank <= 13;
    return Stack(
      children: [
        Center(
          child: isFace
              ? Text(
                  card.rankLabel,
                  style: TextStyle(
                    fontFamily: displayFont,
                    fontSize: width * 0.62,
                    color: color,
                  ),
                )
              : SuitIcon(suit: card.suit, size: width * 0.5, color: color),
        ),
        Align(alignment: Alignment.topLeft, child: corner),
        Align(
          alignment: Alignment.bottomRight,
          child: RotatedBox(quarterTurns: 2, child: corner),
        ),
      ],
    );
  }
}

/// Kartenrücken im Tapetenmuster der Siebziger.
class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFC4391F));
    final step = size.width / 2.6;
    final rings = [
      const Color(0xFFF2A33A),
      const Color(0xFF6B3E1E),
      const Color(0xFFFFF1C9),
    ];
    for (var ix = 0; ix < 4; ix++) {
      for (var iy = 0; iy < 6; iy++) {
        final c = Offset(
          step * 0.2 + ix * step + (iy.isOdd ? step / 2 : 0),
          iy * step * 0.8,
        );
        for (var i = 0; i < rings.length; i++) {
          canvas.drawCircle(c, step * (0.5 - i * 0.14), Paint()..color = rings[i]);
        }
      }
    }
    canvas.drawRect(
      (Offset.zero & size).deflate(size.width * 0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = const Color(0xFFFFF1C9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lässt eine Karte von oben einfliegen.
class DealIn extends StatelessWidget {
  const DealIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + const Duration(milliseconds: 240);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -40 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
