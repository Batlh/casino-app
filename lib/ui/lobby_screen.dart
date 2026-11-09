import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/sfx.dart';
import '../core/theme.dart';
import '../core/wallet.dart';
import '../games/arschloch/ah_screen.dart';
import '../games/blackjack/blackjack_screen.dart';
import '../games/cards/playing_card.dart';
import '../games/chess/chess_engine.dart';
import '../games/chess/chess_pieces.dart';
import '../games/chess/chess_screen.dart';
import '../games/mahjong/american/am_guide.dart';
import '../games/mahjong/classic/mj_rules.dart';
import '../games/mahjong/classic/mj_variants_screen.dart';
import '../games/mahjong/riichi_screen.dart';
import '../games/mahjong/shisen_screen.dart';
import '../games/mahjong/solitaire_screen.dart';
import '../games/mahjong/tiles.dart' show paintTile;
import '../games/shogi/shogi_board.dart';
import '../games/shogi/shogi_engine.dart';
import '../games/shogi/shogi_screen.dart';
import '../games/eins/eins_card.dart';
import '../games/eins/eins_engine.dart';
import '../games/eins/eins_screen.dart';
import '../games/hearts/hearts_screen.dart';
import '../games/holdem/holdem_screen.dart';
import '../games/maumau/maumau_screen.dart';
import '../games/pachinko/pachinko_screen.dart';
import '../games/pikdame/pd_screen.dart';
import '../games/pinball/pinball_screen.dart';
import '../games/quatro/quatro_screen.dart';
import '../games/roulette/roulette_painters.dart';
import '../games/roulette/roulette_screen.dart';
import '../games/skat/skat_screen.dart';
import '../games/slots/kosmos_art.dart';
import '../games/slots/slot_games.dart';
import '../games/slots/slot_screen.dart';
import '../games/slots/tiefsee_art.dart';
import '../games/solitaire/klondike_screen.dart';
import '../games/solitaire/spider_screen.dart';
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
        'Neon Flipper',
        'Flipper mit Tastatur oder Bildschirmtasten',
        const Color(0xFF1A0B33),
        _FlipperArt.new,
        () => _open(const PinballScreen()),
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
    final cardGames = <_Game>[
      _Game(
        'Solitaire',
        'Ohne Einsatz, ein Sieg bringt bis zu 400 Münzen',
        const Color(0xFF0F5B4A),
        _SolitaireArt.new,
        () => _open(const KlondikeScreen()),
      ),
      _Game(
        'Spider Solitaire',
        'Eine, zwei oder vier Farben, bis zu 1.000 Münzen',
        const Color(0xFF2B0B45),
        _SpiderArt.new,
        () => _open(const SpiderScreen()),
      ),
      _Game(
        'Mau Mau',
        'Gegen bis zu drei Gegner, Sieben auf Sieben zählt',
        const Color(0xFF7A1F12),
        _MauMauArt.new,
        () => _open(const MauMauScreen()),
      ),
      _Game(
        'Eins!',
        'Klassisch oder in sechs wilden Spielweisen',
        const Color(0xFF2A160E),
        _EinsArt.new,
        () => _open(const EinsScreen()),
      ),
      _Game(
        'Schwarze Dame',
        'Stiche ohne Herz und ohne die Pik Dame',
        const Color(0xFF14506E),
        _HeartsArt.new,
        () => _open(const HeartsScreen()),
      ),
      _Game(
        'Pik Dame',
        'Omas Rommé mit Jokern, die Pik Dame zählt 100',
        const Color(0xFF1E5631),
        _PikDameArt.new,
        () => _open(const PikDameScreen()),
      ),
      _Game(
        'Arschloch',
        'Karten loswerden: König oder Arschloch?',
        const Color(0xFF6B3A1F),
        _ArschlochArt.new,
        () => _open(const ArschlochScreen()),
      ),
      _Game(
        'Skat',
        'Reizen, drücken, ansagen: zu dritt gegen zwei Computer',
        const Color(0xFF15553A),
        _SkatArt.new,
        () => _open(const SkatScreen()),
      ),
      _Game(
        'Viererkette',
        'Farbige Steine legen, vier in einer Reihe gewinnen',
        const Color(0xFF3A1467),
        _QuatroArt.new,
        () => _open(const QuatroScreen()),
      ),
    ];
    final boardGames = <_Game>[
      _Game(
        'Schach',
        'Gegen den Computer in vier Stufen oder zu zweit',
        const Color(0xFF3A2116),
        _ChessArt.new,
        () => _open(const ChessScreen()),
      ),
      _Game(
        'Shogi',
        'Japanisches Schach: geschlagene Steine kommen zurück',
        const Color(0xFF5A3420),
        _ShogiArt.new,
        () => _open(const ShogiScreen()),
      ),
    ];

    final mahjongGames = <_Game>[
      _Game(
        'Mahjong Solitär',
        'Paare vom Turm abräumen, ein leeres Brett bringt 300',
        const Color(0xFF0F5B4A),
        () => _MahjongArt(const [4, 31, 4]),
        () => _open(const MahjongSolitaireScreen()),
      ),
      _Game(
        'Riichi Mahjong',
        'Gegen drei Computer: Pon, Chi, Riichi und Ron',
        const Color(0xFF7A1F12),
        () => _MahjongArt(const [33, 27, 32]),
        () => _open(const RiichiScreen()),
      ),
      _Game(
        'Sichuan Mahjong',
        'Blutkampf und Blutfluss wie Mahjong Inferno',
        const Color(0xFF8E1B2C),
        () => _MahjongArt(const [4, 13, 22]),
        () => _open(const MjVariantsScreen(only: [MjVariant.sichuanRiver, MjVariant.sichuanBattle])),
      ),
      _Game(
        'Mahjong-Varianten',
        'Hongkong, Taiwan, MCR, Singapur, Korea und mehr',
        const Color(0xFF5B1530),
        () => _MahjongArt(const [34, 42, 46]),
        () => _open(const MjVariantsScreen()),
      ),
      _Game(
        'American Mahjong',
        'Mit Jokern, Charleston und eigener Glückskarte',
        const Color(0xFF1F3F6B),
        () => _MahjongArt(const [46, 10, 46]),
        () => _open(amScreen()),
      ),
      _Game(
        'Shisen-Sho',
        'Gleiche Steine mit höchstens zwei Knicken verbinden',
        const Color(0xFF3B2A6B),
        () => _MahjongArt(const [31, 34, 31]),
        () => _open(const ShisenScreen()),
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
            ..._section(context, 'Casino', games),
            ..._section(context, 'Kartenspiele', cardGames),
            ..._section(context, 'Brettspiele', boardGames),
            ..._section(context, 'Mahjong', mahjongGames),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _section(BuildContext context, String title, List<_Game> games) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        sliver: SliverToBoxAdapter(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
    ];

/// Kleine Spielkarte für die Lobbybilder.
void _miniCard(
  Canvas canvas,
  Offset center,
  double w,
  double angle,
  String label,
  Suit suit,
) {
  final h = w / cardAspect;
  final ink = suit == Suit.hearts || suit == Suit.diamonds
      ? const Color(0xFFC8321F)
      : const Color(0xFF241410);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  canvas.drawRRect(
    RRect.fromRectAndRadius(r.shift(const Offset(2, 4)), Radius.circular(w * 0.09)),
    Paint()..color = const Color(0x66000000),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(w * 0.09)),
    Paint()..color = const Color(0xFFFFF8E7),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(fontFamily: displayFont, fontSize: w * 0.32, color: ink),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, r.topLeft + Offset(w * 0.08, w * 0.02));
  paintSuit(
    canvas,
    Rect.fromCenter(center: Offset(0, h * 0.1), width: w * 0.5, height: w * 0.5),
    suit,
    ink,
  );
  canvas.restore();
}

class _SolitaireArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.24, size.height * 0.5 * cardAspect);
    const cards = [
      ('K', Suit.spades),
      ('Q', Suit.hearts),
      ('J', Suit.clubs),
      ('10', Suit.diamonds),
    ];
    for (var i = 0; i < cards.length; i++) {
      _miniCard(
        canvas,
        Offset(
          size.width / 2 + (i - 1.5) * w * 0.34,
          size.height * 0.36 + i * w * 0.22,
        ),
        w,
        0,
        cards[i].$1,
        cards[i].$2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Spinnennetz mit kleiner Spinne, gezeichnet aus Linien.
class _SpiderArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = math.min(size.width, size.height) * 0.62;
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x99E9D8FF);
    const spokes = 12;
    for (var i = 0; i < spokes; i++) {
      final a = i * 2 * math.pi / spokes;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, thread);
    }
    for (var ring = 1; ring <= 6; ring++) {
      final rr = r * ring / 6.5;
      final path = Path();
      for (var i = 0; i <= spokes; i++) {
        final a = i * 2 * math.pi / spokes;
        final p = c + Offset(math.cos(a), math.sin(a)) * rr;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          final mid = (i - 0.5) * 2 * math.pi / spokes;
          final q = c + Offset(math.cos(mid), math.sin(mid)) * rr * 0.9;
          path.quadraticBezierTo(q.dx, q.dy, p.dx, p.dy);
        }
      }
      canvas.drawPath(path, thread);
    }
    final spider = c + Offset(r * 0.18, r * 0.28);
    canvas.drawLine(c + Offset(r * 0.18, -r), spider, thread);
    final leg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF120A1E);
    final s = r * 0.1;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final y = (i - 1.5) * s * 0.5;
        canvas.drawPath(
          Path()
            ..moveTo(spider.dx, spider.dy + y)
            ..lineTo(spider.dx + side * s * 1.2, spider.dy + y - s * 0.6)
            ..lineTo(spider.dx + side * s * 1.9, spider.dy + y + s * 0.5),
          leg,
        );
      }
    }
    canvas.drawCircle(spider, s * 0.75, Paint()..color = const Color(0xFF120A1E));
    canvas.drawCircle(spider + Offset(0, -s * 0.85), s * 0.45, Paint()..color = const Color(0xFF120A1E));
    canvas.drawCircle(spider + Offset(0, s * 0.1), s * 0.25, Paint()..color = const Color(0xFFC4391F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MauMauArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.3, size.height * 0.6 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.52);
    _miniCard(canvas, c + Offset(-w * 0.42, 0), w, -0.22, '7', Suit.hearts);
    _miniCard(canvas, c + Offset(w * 0.42, 0), w, 0.18, 'J', Suit.clubs);
    final tp = TextPainter(
      text: TextSpan(
        text: 'Mau!',
        style: TextStyle(
          fontFamily: displayFont,
          fontSize: w * 0.42,
          color: const Color(0xFFFFC95C),
          shadows: const [Shadow(offset: Offset(2, 2), color: Color(0xFF3A1206))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 16, 26));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EinsArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.28, size.height * 0.62 * cardAspect);
    final h = w / cardAspect;
    final c = Offset(size.width / 2, size.height * 0.55);
    const cards = [
      (EinsFace(EinsKind.number, color: EinsColor.blue, number: 7), false),
      (EinsFace(EinsKind.flip, color: EinsColor.purple), true),
      (EinsFace(EinsKind.wildDrawFour), false),
    ];
    for (var i = 0; i < cards.length; i++) {
      canvas.save();
      canvas.translate(c.dx + (i - 1) * w * 0.62, c.dy);
      canvas.rotate((i - 1) * 0.2);
      paintEinsCard(
        canvas,
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        cards[i].$1,
        dark: cards[i].$2,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuatroArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cols = 5;
    const rows = 3;
    final cell = math.min(size.width * 0.7 / cols, size.height * 0.75 / rows);
    final origin = Offset(size.width / 2 - cols * cell / 2, size.height * 0.56 - rows * cell / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx - cell * 0.1, origin.dy - cell * 0.1, cols * cell + cell * 0.2, rows * cell + cell * 0.2),
        Radius.circular(cell * 0.25),
      ),
      Paint()..color = const Color(0xFF2A160E),
    );
    // Farbe je Feld, -1 leer. Die Diagonale in Gelb ist die Gewinnreihe.
    const grid = [
      [-1, -1, 1, -1, -1],
      [-1, 1, 0, 3, -1],
      [1, 2, 3, 0, 2],
    ];
    const colors = [EinsColor.red, EinsColor.yellow, EinsColor.green, EinsColor.blue];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell).deflate(cell * 0.08);
        final v = grid[r][c];
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.15)),
          Paint()..color = v < 0 ? const Color(0xFF140A06) : einsColors[colors[v]]!,
        );
        if (v >= 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.15)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.05
              ..color = const Color(0xFFFFF8E7),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartsArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.32, size.height * 0.62 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.54);
    final heart = Paint()..color = const Color(0x66FF8FB0);
    final rng = math.Random(12);
    for (var i = 0; i < 9; i++) {
      final hs = 14.0 + rng.nextDouble() * 16;
      final o = Offset(rng.nextDouble() * size.width, 30 + rng.nextDouble() * (size.height - 50));
      paintSuit(canvas, Rect.fromCenter(center: o, width: hs, height: hs), Suit.hearts, heart.color);
    }
    _miniCard(canvas, c, w, -0.08, 'Q', Suit.spades);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArschlochArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.24, size.height * 0.56 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.56);
    for (var i = 0; i < 4; i++) {
      _miniCard(canvas, c + Offset((i - 1.5) * w * 0.42, (i - 1.5).abs() * 4), w, (i - 1.5) * 0.12, 'A', Suit.values[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkatArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.24, size.height * 0.56 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.56);
    const suits = [Suit.diamonds, Suit.hearts, Suit.spades, Suit.clubs];
    for (var i = 0; i < 4; i++) {
      _miniCard(canvas, c + Offset((i - 1.5) * w * 0.42, (i - 1.5).abs() * 4), w, (i - 1.5) * 0.12, 'J', suits[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PikDameArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.26, size.height * 0.58 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.56);
    _miniCard(canvas, c + Offset(-w * 0.7, 6), w, -0.28, '7', Suit.hearts);
    _miniCard(canvas, c + const Offset(0, -2), w, 0, '8', Suit.hearts);
    _miniCard(canvas, c + Offset(w * 0.7, 6), w, 0.28, 'Q', Suit.spades);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChessArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / 9, size.height / 5.2);
    final ox = size.width / 2 - cell * 4;
    final oy = size.height * 0.62;
    // Schräg gekipptes Brettstück
    for (var r = 0; r < 3; r++) {
      for (var f = 0; f < 8; f++) {
        canvas.drawRect(
          Rect.fromLTWH(ox + f * cell, oy + r * cell * 0.55, cell, cell * 0.55),
          Paint()..color = (f + r).isEven ? const Color(0xFFF0DDB8) : const Color(0xFFB27C52),
        );
      }
    }
    void piece(int p, double x, double s) {
      canvas.save();
      canvas.translate(x - s / 2, oy - s * 0.82);
      ChessPiecePainter(p).paint(canvas, Size.square(s));
      canvas.restore();
    }

    piece(-knight, size.width * 0.28, cell * 2.2);
    piece(king, size.width * 0.5, cell * 2.8);
    piece(-queen, size.width * 0.72, cell * 2.4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShogiArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 4.2, size.height / 2.3);
    final cy = size.height * 0.56;
    final pieces = [sRook, -sKing, sBishop];
    for (var i = 0; i < 3; i++) {
      final cx = size.width / 2 + (i - 1) * s * 1.15;
      final big = i == 1 ? 1.2 : 1.0;
      paintShogiPiece(canvas, Rect.fromCenter(center: Offset(cx, cy), width: s * big, height: s * 1.1 * big), pieces[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MahjongArt extends CustomPainter {
  _MahjongArt(this.tiles);
  final List<int> tiles;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width / 4.6, size.height / 2.2 * 0.76);
    final h = w / 0.76;
    final cy = size.height * 0.56;
    for (var i = 0; i < tiles.length; i++) {
      final cx = size.width / 2 + (i - 1) * w * 1.15;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate((i - 1) * 0.12);
      paintTile(canvas, Rect.fromCenter(center: Offset.zero, width: w, height: h), tiles[i], depth: w * 0.12);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _FlipperArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height * 1.4);
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF63E6FF);
    // Zwei Flipper und eine Kugel
    void flipper(double x, double dir, double angle) {
      canvas.save();
      canvas.translate(x, cy + s * 0.18);
      canvas.rotate(angle);
      final l = s * 0.24 * dir;
      final p = Path()
        ..moveTo(0, -s * 0.03)
        ..lineTo(l, -s * 0.012)
        ..lineTo(l, s * 0.012)
        ..lineTo(0, s * 0.03)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFFC95C));
      canvas.restore();
    }

    canvas.drawLine(Offset(cx - s * 0.42, cy - s * 0.1), Offset(cx - s * 0.3, cy + s * 0.16), neon);
    canvas.drawLine(Offset(cx + s * 0.42, cy - s * 0.1), Offset(cx + s * 0.3, cy + s * 0.16), neon);
    flipper(cx - s * 0.3, 1, -0.3);
    flipper(cx + s * 0.3, -1, 0.45);
    for (final b in [Offset(cx - s * 0.18, cy - s * 0.2), Offset(cx + s * 0.18, cy - s * 0.2)]) {
      canvas.drawCircle(b, s * 0.07, Paint()..color = const Color(0xCCFF5EA8));
      canvas.drawCircle(b, s * 0.03, Paint()..color = Colors.white);
    }
    final ball = Offset(cx + s * 0.05, cy - s * 0.02);
    canvas.drawCircle(
      ball,
      s * 0.045,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Colors.white, Color(0xFF8A94AA)],
        ).createShader(Rect.fromCircle(center: ball, radius: s * 0.045)),
    );
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
