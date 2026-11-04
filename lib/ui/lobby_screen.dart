import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/sfx.dart';
import '../core/theme.dart';
import '../core/wallet.dart';
import '../games/blackjack/blackjack_screen.dart';
import '../games/cards/playing_card.dart';
import '../games/holdem/holdem_screen.dart';
import '../games/pachinko/pachinko_screen.dart';
import '../games/roulette/roulette_painters.dart';
import '../games/roulette/roulette_screen.dart';
import '../games/slots/kosmos_art.dart';
import '../games/slots/slot_games.dart';
import '../games/slots/slot_screen.dart';
import '../games/slots/tiefsee_art.dart';
import '../games/videopoker/video_poker_screen.dart';
import 'settings_sheet.dart';
import 'widgets.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);
    final games = <_Game>[
      _Game(
        kosmos78.name,
        kosmos78.blurb,
        kosmos78.lobbyColor,
        _KosmosArt.new,
        () => _open(const SlotScreen(game: kosmos78)),
      ),
      _Game(
        tiefsee.name,
        tiefsee.blurb,
        tiefsee.lobbyColor,
        _TiefseeArt.new,
        () => _open(const SlotScreen(game: tiefsee)),
      ),
      _Game(
        schrebergarten.name,
        schrebergarten.blurb,
        schrebergarten.lobbyColor,
        _GartenArt.new,
        () => _open(const SlotScreen(game: schrebergarten)),
      ),
      _Game(
        "Texas Hold'em",
        'No-Limit gegen bis zu fünf Gegner',
        const Color(0xFF7A1F12),
        _HoldemArt.new,
        () => _open(const HoldemScreen()),
      ),
      _Game(
        'Neon Pachinko',
        'Kugeln, Tulpen und das Fieber-Tor',
        const Color(0xFF2B0B45),
        _PachinkoArt.new,
        () => _open(const PachinkoScreen()),
      ),
      _Game(
        'Black Jack',
        'Sechs Decks, Black Jack zahlt 3:2',
        const Color(0xFF0F5B4A),
        _BlackJackArt.new,
        () => _open(const BlackjackScreen()),
      ),
      _Game(
        'Roulette',
        'Europäischer Kessel mit einer Null',
        const Color(0xFF7A1F12),
        _RouletteArt.new,
        () => _open(const RouletteScreen()),
      ),
      _Game(
        'Video Poker',
        'Jacks or Better mit voller 9/6-Tabelle',
        const Color(0xFF14506E),
        _VideoPokerArt.new,
        () => _open(const VideoPokerScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Einstellungen',
                              icon: Icon(Icons.settings, color: p.ink),
                              onPressed: () => showSettingsSheet(context),
                            ),
                            const Spacer(),
                            const BalanceBadge(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Marquee(),
                        const SizedBox(height: 14),
                        _BonusBar(wallet: app.wallet, sfx: app.sfx),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = (width / 280).floor().clamp(1, 4);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: columns == 1 ? 250 : 300,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _Cabinet(game: games[i]),
                      childCount: games.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Game {
  const _Game(this.name, this.blurb, this.color, this.art, this.onTap);
  final String name;
  final String blurb;
  final Color color;
  final CustomPainter Function() art;
  final VoidCallback onTap;
}

/// Spielgerät in der Lobby: oben das Motiv hinter gewölbtem Glas, unten das Schild.
class _Cabinet extends StatelessWidget {
  const _Cabinet({required this.game});
  final _Game game;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: '${game.name}. ${game.blurb}',
      excludeSemantics: true,
      child: Material(
        color: p.panel,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(70),
            bottom: Radius.circular(10),
          ),
          side: BorderSide(color: p.panelEdge, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: game.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  decoration: BoxDecoration(
                    color: game.color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(60),
                      bottom: Radius.circular(6),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(60),
                      bottom: Radius.circular(6),
                    ),
                    child: CustomPaint(
                      painter: game.art(),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.inkSoft, fontSize: 15, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BonusBar extends StatelessWidget {
  const _BonusBar({required this.wallet, required this.sfx});
  final Wallet wallet;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) {
        if (!wallet.bonusAvailable) {
          return Text(
            'Tagesbonus abgeholt. Morgen gibt es den nächsten.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSoft, fontSize: 15),
          );
        }
        return Center(
          child: ActionButton(
            primary: true,
            label: 'Tagesbonus abholen: ${formatCoins(Wallet.dailyBonus)} Münzen',
            onPressed: () {
              wallet.claimBonus();
              sfx.play(Sound.coin);
            },
          ),
        );
      },
    );
  }
}

/// Leuchtschild mit laufendem Glühbirnenband, das eine bewegte Element der Lobby.
class Marquee extends StatefulWidget {
  const Marquee({super.key});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 0.26).clamp(104.0, 150.0);
        return SizedBox(
          height: height,
          child: CustomPaint(
            painter: _BulbPainter(_c, p),
            child: Padding(
              padding: EdgeInsets.all(height * 0.2),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Glückspfennig',
                    style: TextStyle(
                      fontFamily: displayFont,
                      fontSize: height * 0.42,
                      color: const Color(0xFFFFF1C9),
                      shadows: const [
                        Shadow(offset: Offset(3, 3), color: Color(0xFF7A1F12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BulbPainter extends CustomPainter {
  _BulbPainter(this.animation, this.p) : super(repaint: animation);
  final Animation<double> animation;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFC4391F));
    canvas.drawRRect(
      outer.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF7A1F12),
    );

    final inset = RRect.fromRectAndRadius(
      rect.deflate(size.height * 0.1),
      const Radius.circular(12),
    );
    final metric = (Path()..addRRect(inset)).computeMetrics().first;
    final count = (metric.length / 24).floor();
    final phase = animation.value * 3;
    for (var i = 0; i < count; i++) {
      final pos = metric.getTangentForOffset(metric.length * i / count)!.position;
      final lit = (i + phase.floor()) % 3 == 0;
      if (lit) {
        canvas.drawCircle(
          pos,
          8,
          Paint()
            ..color = const Color(0x88FFD98A)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(
        pos,
        4,
        Paint()..color = lit ? const Color(0xFFFFF1C9) : const Color(0xFF8A3A1C),
      );
    }
  }

  @override
  bool shouldRepaint(_BulbPainter old) => old.p != p;
}

class _KosmosArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintKosmosSky(canvas, Offset.zero & size, 0);
    final s = math.min(size.width, size.height) * 0.62;
    final c = size.center(Offset.zero);
    paintKosmosSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(-s * 0.32, s * 0.08), width: s, height: s),
      3,
    );
    paintKosmosSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(s * 0.44, -s * 0.12), width: s * 0.8, height: s * 0.8),
      5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TiefseeArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintTiefseeBackdrop(canvas, Offset.zero & size, 0.2);
    final s = math.min(size.width, size.height) * 0.7;
    final c = size.center(Offset.zero);
    paintTiefseeSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(s * 0.34, s * 0.12), width: s, height: s),
      5,
    );
    paintTiefseeSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(-s * 0.38, -s * 0.1), width: s * 0.8, height: s * 0.8),
      6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GartenArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    schrebergarten.paintBackdrop(canvas, Offset.zero & size, 0);
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.72, size.width, size.height),
      Paint()..color = const Color(0xFF5E9A3E),
    );
    final s = math.min(size.width, size.height) * 0.72;
    final c = size.center(Offset.zero);
    schrebergarten.paintSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(s * 0.42, s * 0.08), width: s * 0.72, height: s * 0.72),
      2,
    );
    schrebergarten.paintSymbol(
      canvas,
      Rect.fromCenter(center: c.translate(-s * 0.26, s * 0.08), width: s * 1.1, height: s * 1.1),
      6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HoldemArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final felt = Rect.fromCenter(
      center: c.translate(0, 8),
      width: size.width * 0.86,
      height: size.height * 0.62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(felt, Radius.circular(felt.height / 2)),
      Paint()..color = const Color(0xFF1B7A63),
    );
    const suits = [Suit.diamonds, Suit.spades, Suit.hearts];
    final w = size.width * 0.17;
    final h = w / cardAspect;
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(
        c.dx + (i - 1.5) * (w + 5),
        felt.center.dy - h / 2,
        w,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(5)),
        Paint()..color = const Color(0xFFFFF8E7),
      );
      paintSuit(
        canvas,
        Rect.fromCenter(center: r.center, width: w * 0.62, height: w * 0.62),
        suits[i],
        i == 1 ? const Color(0xFF241410) : const Color(0xFFC8321F),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PachinkoArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1140), Color(0xFF4A1466), Color(0xFFB02A7E)],
        ).createShader(Offset.zero & size),
    );
    final peg = Paint()..color = const Color(0xFFE9C271);
    final step = size.width / 8;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 9; col++) {
        canvas.drawCircle(
          Offset(col * step + (row.isOdd ? step / 2 : 0), 30 + row * step * 0.8),
          2.4,
          peg,
        );
      }
    }
    final rng = math.Random(9);
    for (var i = 0; i < 7; i++) {
      final o = Offset(
        size.width * (0.2 + 0.6 * rng.nextDouble()),
        size.height * (0.25 + 0.6 * rng.nextDouble()),
      );
      canvas.drawCircle(
        o,
        9,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Colors.white, Color(0xFF8D93B8)],
          ).createShader(Rect.fromCircle(center: o, radius: 9)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlackJackArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * 0.7;
    final w = h * cardAspect;
    final c = size.center(Offset.zero);
    void card(double angle, double dx, String label, Suit suit, Color ink) {
      canvas.save();
      canvas.translate(c.dx + dx, c.dy + 6);
      canvas.rotate(angle);
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.shift(const Offset(2, 4)), const Radius.circular(8)),
        Paint()..color = const Color(0x66000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFFF8E7),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontFamily: displayFont, fontSize: w * 0.34, color: ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, r.topLeft + Offset(w * 0.08, w * 0.02));
      paintSuit(
        canvas,
        Rect.fromCenter(center: Offset(0, h * 0.1), width: w * 0.56, height: w * 0.56),
        suit,
        ink,
      );
      canvas.restore();
    }

    card(-0.2, -w * 0.32, 'K', Suit.hearts, const Color(0xFFC8321F));
    card(0.16, w * 0.32, 'A', Suit.spades, const Color(0xFF241410));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouletteArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * 0.46;
    paintWheel(
      canvas,
      size.center(Offset.zero).translate(0, 8),
      r,
      0.3,
      labels: false,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VideoPokerArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs, Suit.hearts];
    final w = size.width * 0.17;
    final h = w / cardAspect;
    final y = size.height / 2 - h / 2 + 8;
    for (var i = 0; i < 5; i++) {
      final x = size.width / 2 + (i - 2.5) * (w + 4);
      final r = Rect.fromLTWH(x, y, w, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(5)),
        Paint()..color = const Color(0xFFFFF8E7),
      );
      paintSuit(
        canvas,
        Rect.fromCenter(center: r.center, width: w * 0.62, height: w * 0.62),
        suits[i],
        i == 1 || i == 2 || i == 4
            ? const Color(0xFFC8321F)
            : const Color(0xFF241410),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
