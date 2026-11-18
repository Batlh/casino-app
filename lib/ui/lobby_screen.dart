import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/sfx.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../core/wallet.dart';
import '../games/arschloch/ah_screen.dart';
import '../games/baccarat/baccarat_screen.dart';
import '../games/bingo/bingo_screen.dart';
import '../games/blackjack/blackjack_screen.dart';
import '../games/cards/playing_card.dart';
import '../games/caribbean/caribbean_screen.dart';
import '../games/chess/chess_engine.dart';
import '../games/chess/chess_pieces.dart';
import '../games/chess/chess_screen.dart';
import '../games/keno/keno_screen.dart';
import '../games/lose/lose_art.dart';
import '../games/lose/lose_screens.dart';
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
import '../games/craps/craps_screen.dart';
import '../games/eins/eins_card.dart';
import '../games/ente/ente_screen.dart';
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
import '../games/sicbo/sicbo_screen.dart';
import '../games/skat/skat_screen.dart';
import '../games/slots/kosmos_art.dart';
import '../games/slots/slot_engine.dart';
import '../games/slots/slot_games.dart';
import '../games/slots/slot_screen.dart';
import '../games/slots/tiefsee_art.dart';
import '../games/backgammon/bg_screen.dart';
import '../games/dame/dame_screen.dart';
import '../games/go/go_screen.dart';
import '../games/halma/halma_screen.dart';
import '../games/kniffel/kniffel_screen.dart';
import '../games/ladder/ladder_screen.dart';
import '../games/madn/madn_screen.dart';
import '../games/memory/memory_screen.dart';
import '../games/muehle/muehle_screen.dart';
import '../games/reversi/reversi_screen.dart';
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
  @override
  void initState() {
    super.initState();
    // Nach dem ersten Bild nach Updates schauen (nur wenn eingeschaltet, höchstens alle sechs Stunden)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) autoCheckForUpdate(context);
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  final _sectionKeys = {for (final s in const ['Zuletzt gespielt', 'Casino', 'Kartenspiele', 'Brettspiele', 'Mahjong']) s: GlobalKey()};

  /// Zuletzt geöffnete Spiele, neuestes zuerst.
  List<String> _recent() {
    final r = AppScope.of(context).settings.loadGame('lobby')?['recent'];
    return r is List ? [for (final x in r) '$x'] : const [];
  }

  void _remember(String name) {
    final list = [name, ..._recent().where((x) => x != name)].take(4).toList();
    AppScope.of(context).settings.saveGame('lobby', {'recent': list});
  }

  _Game _tracked(_Game g) => _Game(g.name, g.blurb, g.color, g.art, () {
        _remember(g.name);
        g.onTap();
        setState(() {});
      });

  void _jump(String section) {
    final ctx = _sectionKeys[section]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
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
        edelsteinmine.name,
        edelsteinmine.blurb,
        edelsteinmine.lobbyColor,
        () => _SlotArt(edelsteinmine, 5, 6),
        () => _open(SlotScreen(game: AppScope.of(context).settings.mineScatterDrops ? edelsteinmineB : edelsteinmine)),
      ),
      _Game(
        drachenhort.name,
        drachenhort.blurb,
        drachenhort.lobbyColor,
        () => _SlotArt(drachenhort, 5, symCoin),
        () => _open(const SlotScreen(game: drachenhort)),
      ),
      _Game(
        jahrmarkt.name,
        jahrmarkt.blurb,
        jahrmarkt.lobbyColor,
        () => _SlotArt(jahrmarkt, 5, symBonus),
        () => _open(const SlotScreen(game: jahrmarkt)),
      ),
      _Game(
        vulkaninsel.name,
        vulkaninsel.blurb,
        vulkaninsel.lobbyColor,
        () => _SlotArt(vulkaninsel, 5, symScatter),
        () => _open(const SlotScreen(game: vulkaninsel)),
      ),
      _Game(
        sakura.name,
        sakura.blurb,
        sakura.lobbyColor,
        () => _SlotArt(sakura, 6, 7),
        () => _open(const SlotScreen(game: sakura)),
      ),
      _Game(
        jadetempel.name,
        jadetempel.blurb,
        jadetempel.lobbyColor,
        () => _SlotArt(jadetempel, 5, symCoin),
        () => _open(const SlotScreen(game: jadetempel)),
      ),
      _Game(
        fruechtekorb.name,
        fruechtekorb.blurb,
        fruechtekorb.lobbyColor,
        () => _SlotArt(fruechtekorb, 6, 0),
        () => _open(const SlotScreen(game: fruechtekorb)),
      ),
      _Game(
        "Texas Hold'em",
        'No-Limit gegen bis zu fünf Gegner',
        const Color(0xFF7A1F12),
        () => _PokerArt('holdem'),
        () => _open(const HoldemScreen()),
      ),
      _Game(
        'Omaha',
        'Vier Karten auf der Hand, genau zwei davon zählen',
        const Color(0xFF5A1A3A),
        () => _PokerArt('omaha'),
        () => _open(const HoldemScreen(omaha: true)),
      ),
      _Game(
        'Five Card Draw',
        'Fünf Karten, einmal tauschen, dann wird gesetzt',
        const Color(0xFF233A6B),
        () => _PokerArt('draw'),
        () => _open(const HoldemScreen(draw: true)),
      ),
      _Game(
        'Baccarat',
        'Spieler oder Bank: wer kommt näher an die 9?',
        const Color(0xFF14504A),
        _BaccaratArt.new,
        () => _open(const BaccaratScreen()),
      ),
      _Game(
        'Caribbean Stud',
        'Fünf-Karten-Poker gegen die Bank',
        const Color(0xFF0E5E6B),
        () => _PokerArt('caribbean'),
        () => _open(const CaribbeanScreen()),
      ),
      _Game(
        'Sic Bo',
        'Drei Würfel, Klein oder Groß, Drillinge zahlen 150',
        const Color(0xFF6B1F1F),
        _SicBoArt.new,
        () => _open(const SicBoScreen()),
      ),
      _Game(
        'Craps',
        'Pass Line, Punkt und Field mit zwei Würfeln',
        const Color(0xFF1B5E20),
        _SicBoArt.new,
        () => _open(const CrapsScreen()),
      ),
      _Game(
        'Keno',
        'Bis zu zehn Zahlen wählen, 20 werden gezogen',
        const Color(0xFF1F3A6B),
        _KenoArt.new,
        () => _open(const KenoScreen()),
      ),
      _Game(
        'Bingo',
        '75 Kugeln (USA) oder 90 Kugeln (UK) gegen Mitspieler',
        const Color(0xFF8E2A5A),
        _BingoArt.new,
        () => _open(const BingoScreen()),
      ),
      _Game(
        'Entchen angeln',
        'Jahrmarkt: Entchen aus dem Becken angeln',
        const Color(0xFF0277BD),
        _EntenArt.new,
        () => _open(const EntenScreen()),
      ),
      _Game(
        'Rubbellose',
        'Drei Sorten zum Freirubbeln, Hauptgewinn bis 1 Mio.',
        const Color(0xFF2E5E2E),
        () => _LosArt(false),
        () => _open(const RubbelScreen()),
      ),
      _Game(
        'Pull-Tabs',
        'Aufreißlose aus den USA: drei Gleiche gewinnen',
        const Color(0xFF7A1F3A),
        () => _LosArt(true),
        () => _open(const PullTabScreen()),
      ),
      _Game(
        'Pachinko',
        'Fünf Maschinen mit Tulpen und Fieber-Tor',
        const Color(0xFF2B0B45),
        _PachinkoArt.new,
        () => _open(const PachinkoScreen()),
      ),
      _Game(
        'Flipper',
        'Sechs Tische mit Rampen, Multiball und Missionen',
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
      _Game(
        'Dame',
        'Deutsch 8×8 oder international 10×10, Schlagen ist Pflicht',
        const Color(0xFF3A2116),
        _DameArt.new,
        () => _open(const DameScreen()),
      ),
      _Game(
        'Mühle',
        'Neun Steine, Mühlen schließen, springen mit dreien',
        const Color(0xFF5A3420),
        _MuehleArt.new,
        () => _open(const MuehleScreen()),
      ),
      _Game(
        'Backgammon',
        'Würfeln, schlagen, abtragen: der Klassiker für zwei',
        const Color(0xFF5A3420),
        _BackgammonArt.new,
        () => _open(const BgScreen()),
      ),
      _Game(
        'Go',
        'Gebiet umschließen, mit Go-Schule und Aufgaben',
        const Color(0xFF6B4A1F),
        _GoArt.new,
        () => _open(const GoScreen()),
      ),
      _Game(
        'Reversi',
        'Steine einklemmen und umdrehen, Ecken sind Gold',
        const Color(0xFF1E5631),
        _ReversiArt.new,
        () => _open(const ReversiScreen()),
      ),
      _Game(
        'Memory',
        'Paare finden: allein, zu mehreren oder gegen den Computer',
        const Color(0xFF6B2A4A),
        _MemoryArt.new,
        () => _open(const MemoryScreen()),
      ),
      _Game(
        'Halma',
        'Stern-Halma für zwei bis sechs: springen, Leitern bauen',
        const Color(0xFF2F4F7F),
        _HalmaArt.new,
        () => _open(const HalmaScreen()),
      ),
      _Game(
        'Mensch ärgere dich nicht',
        'Rauswerfen, heimbringen, Hausregeln einstellbar',
        const Color(0xFF8E1B2C),
        _MadnArt.new,
        () => _open(const MadnScreen()),
      ),
      _Game(
        'Kniffel',
        'Fünf Würfel, drei Würfe, 13 Zeilen zum Füllen',
        const Color(0xFF14506E),
        _KniffelArt.new,
        () => _open(const KniffelScreen()),
      ),
      _Game(
        'Leiterspiel',
        'Würfeln, Leitern hoch, Schlangen runter, bis zu vier',
        const Color(0xFF7A5A1F),
        _LadderArt.new,
        () => _open(const LadderScreen()),
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

    final all = {for (final g in [...games, ...cardGames, ...boardGames, ...mahjongGames]) g.name: g};
    final recent = [for (final n in _recent()) if (all[n] != null) _tracked(all[n]!)];

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
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in const ['Casino', 'Kartenspiele', 'Brettspiele', 'Mahjong'])
                              ActionChip(
                                label: Text(s, style: TextStyle(color: p.ink, fontWeight: FontWeight.w700)),
                                backgroundColor: p.panel,
                                side: BorderSide(color: p.panelEdge, width: 2),
                                onPressed: () => _jump(s),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (recent.isNotEmpty) ..._section(context, 'Zuletzt gespielt', recent, key: _sectionKeys['Zuletzt gespielt']),
            ..._section(context, 'Casino', [for (final g in games) _tracked(g)], key: _sectionKeys['Casino']),
            ..._section(context, 'Kartenspiele', [for (final g in cardGames) _tracked(g)], key: _sectionKeys['Kartenspiele']),
            ..._section(context, 'Brettspiele', [for (final g in boardGames) _tracked(g)], key: _sectionKeys['Brettspiele']),
            ..._section(context, 'Mahjong', [for (final g in mahjongGames) _tracked(g)], key: _sectionKeys['Mahjong']),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _section(BuildContext context, String title, List<_Game> games, {Key? key}) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        sliver: SliverToBoxAdapter(
          key: key,
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

class _BaccaratArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.26, size.height * 0.58 * cardAspect);
    final c = Offset(size.width / 2, size.height * 0.56);
    _miniCard(canvas, c + Offset(-w * 0.45, 4), w, -0.15, '9', Suit.diamonds);
    _miniCard(canvas, c + Offset(w * 0.45, 4), w, 0.15, '8', Suit.clubs);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SicBoArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width * 0.22, size.height * 0.4);
    final c = Offset(size.width / 2, size.height * 0.58);
    for (var i = 0; i < 3; i++) {
      final o = c + Offset((i - 1) * d * 1.15, i == 1 ? -d * 0.25 : 0);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: d, height: d), Radius.circular(d * 0.18));
      canvas.drawRRect(r, Paint()..color = const Color(0xFFFFFBF2));
      for (var k = 0; k <= i; k++) {
        final p = o + Offset((k - i / 2) * d * 0.26, (k - i / 2) * d * 0.26);
        canvas.drawCircle(p, d * 0.09, Paint()..color = i == 0 ? const Color(0xFFC62828) : const Color(0xFF241410));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BingoArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width * 0.5, size.height * 0.72) / 5;
    final origin = Offset(size.width * 0.12, (size.height - cell * 5) / 2 + 4);
    final rng = math.Random(9);
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        final rect = Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell).deflate(1);
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFF8E7));
        if (r == c || (r == 2 && c == 2) || rng.nextDouble() < 0.25) {
          canvas.drawCircle(rect.center, cell * 0.36, Paint()..color = r == c ? const Color(0xCCFFB300) : const Color(0x99E53935));
        }
      }
    }
    // Kugel daneben
    final b = Offset(size.width * 0.8, size.height * 0.5);
    final br = math.min(size.width, size.height) * 0.2;
    canvas.drawCircle(b, br, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF90CAF9), Color(0xFF1565C0)]).createShader(Rect.fromCircle(center: b, radius: br)));
    canvas.drawCircle(b, br * 0.6, Paint()..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(text: '42', style: TextStyle(fontFamily: bodyFont, color: const Color(0xFF241410), fontWeight: FontWeight.w900, fontSize: br * 0.7)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, b - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EntenArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pond = Rect.fromCenter(center: size.center(Offset.zero).translate(0, 8), width: size.width * 0.8, height: size.height * 0.5);
    canvas.drawOval(pond, Paint()..color = const Color(0xFF4FC3F7));
    final w = size.shortestSide * 0.26;
    for (final (dx, dy) in [(-0.22, 0.02), (0.0, -0.05), (0.22, 0.03)]) {
      final c = pond.center.translate(size.width * dx, size.height * dy);
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: w * 0.6), Paint()..color = const Color(0xFFFBC02D));
      canvas.drawCircle(c.translate(w * 0.28, -w * 0.3), w * 0.22, Paint()..color = const Color(0xFFFFEE58));
      canvas.drawCircle(c.translate(w * 0.34, -w * 0.33), w * 0.04, Paint()..color = const Color(0xFF241410));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LosArt extends CustomPainter {
  _LosArt(this.pull);
  final bool pull;

  @override
  void paint(Canvas canvas, Size size) {
    final card = Rect.fromCenter(center: size.center(Offset.zero).translate(0, 6), width: size.width * 0.62, height: size.height * 0.7);
    canvas.save();
    canvas.translate(card.center.dx, card.center.dy);
    canvas.rotate(-0.08);
    canvas.translate(-card.center.dx, -card.center.dy);
    canvas.drawRRect(RRect.fromRectAndRadius(card, const Radius.circular(8)), Paint()..color = pull ? const Color(0xFFC62828) : const Color(0xFF2E7D32));
    final inner = card.deflate(card.width * 0.08);
    if (pull) {
      for (var i = 0; i < 3; i++) {
        final row = Rect.fromLTWH(inner.left, inner.top + i * inner.height / 3, inner.width, inner.height / 3).deflate(2);
        canvas.drawRect(row, Paint()..color = const Color(0xFFFFF8E7));
        if (i == 1) {
          for (var k = 0; k < 3; k++) {
            paintLosSymbol(canvas, Rect.fromLTWH(row.left + k * row.width / 3, row.top, row.width / 3, row.height), 'Sieben');
          }
        } else {
          canvas.drawRect(row, Paint()..color = const Color(0xFFFF8A80));
        }
      }
    } else {
      canvas.drawRect(inner, Paint()..color = const Color(0xFFFFF8E7));
      for (var i = 0; i < 3; i++) {
        paintLosSymbol(canvas, Rect.fromLTWH(inner.left + i * inner.width / 3, inner.top, inner.width / 3, inner.height / 2), 'Diamant');
      }
      // halb freigerubbelt
      final cover = Path()
        ..moveTo(inner.left, inner.top + inner.height * 0.45)
        ..quadraticBezierTo(inner.center.dx, inner.top + inner.height * 0.6, inner.right, inner.top + inner.height * 0.4)
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(inner.left, inner.bottom)
        ..close();
      canvas.drawPath(cover, Paint()..color = const Color(0xFFBDBDBD));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KenoArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 14, size.height / 7);
    final rng = math.Random(7);
    const colors = [Color(0xFFFFC95C), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF1F4E9A)];
    for (var i = 0; i < 9; i++) {
      final o = Offset(size.width * (0.18 + 0.32 * (i % 3)), size.height * (0.34 + 0.2 * (i ~/ 3)));
      canvas.drawCircle(o, r, Paint()..color = colors[rng.nextInt(4)]);
      final tp = TextPainter(
        text: TextSpan(text: '${1 + rng.nextInt(80)}', style: TextStyle(color: Colors.white, fontSize: r * 0.9, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
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

class _ReversiArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 5;
    final o = Offset(size.width / 2 - u * 2, size.height / 2 - u * 2);
    canvas.drawRect(o & Size.square(u * 4), Paint()..color = const Color(0xFF1E7A4A));
    const stones = [0, 1, 2, 1, 1, 2, 2, 0, 2, 1, 2, 1, 0, 2, 1, 0];
    for (var i = 0; i < 16; i++) {
      final c = o + Offset((i % 4 + 0.5) * u, (i ~/ 4 + 0.5) * u);
      canvas.drawRect(Rect.fromCenter(center: c, width: u, height: u), Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF0E4A2C));
      if (stones[i] == 0) continue;
      canvas.drawCircle(c, u * 0.4, Paint()..color = stones[i] == 1 ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MemoryArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width / 4.2, size.height / 2.2);
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromCenter(center: Offset(size.width * (0.27 + i * 0.23), size.height * 0.52), width: w, height: w * 1.25);
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate((i - 1) * 0.12);
      canvas.translate(-r.center.dx, -r.center.dy);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(w * 0.1));
      if (i == 1) {
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFB8452A));
      } else {
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFF8E8));
        canvas.save();
        canvas.translate(r.left + r.width * 0.1, r.top + r.height * 0.18);
        CatFacePainter(7).paint(canvas, Size(w * 0.8, w * 0.8));
        canvas.restore();
      }
      canvas.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFF6E7C8));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackgammonArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(size.width * 0.8, size.height * 1.2);
    final h = w * 0.7;
    final o = Offset((size.width - w) / 2, (size.height - h) / 2);
    canvas.drawRect(o & Size(w, h), Paint()..color = const Color(0xFF1E6B45));
    final cw = w / 6;
    for (var i = 0; i < 6; i++) {
      final x = o.dx + i * cw;
      final c = i.isEven ? const Color(0xFFC9A57A) : const Color(0xFF9C3B2A);
      canvas.drawPath(
        Path()
          ..moveTo(x, o.dy)
          ..lineTo(x + cw, o.dy)
          ..lineTo(x + cw / 2, o.dy + h * 0.42)
          ..close(),
        Paint()..color = c,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, o.dy + h)
          ..lineTo(x + cw, o.dy + h)
          ..lineTo(x + cw / 2, o.dy + h * 0.58)
          ..close(),
        Paint()..color = i.isEven ? const Color(0xFF9C3B2A) : const Color(0xFFC9A57A),
      );
    }
    final r = cw * 0.42;
    for (var k = 0; k < 3; k++) {
      canvas.drawCircle(o + Offset(cw * 0.5, h - r - k * r * 2), r, Paint()..color = const Color(0xFFF2EEE6));
      canvas.drawCircle(o + Offset(cw * 4.5, r + k * r * 2), r, Paint()..color = const Color(0xFF2A2A30));
    }
    canvas.drawCircle(o + Offset(cw * 2.5, h - r), r, Paint()..color = const Color(0xFF2A2A30));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 6;
    final o = Offset(size.width / 2 - u * 2.5, size.height / 2 - u * 2.5);
    canvas.drawRect((o & Size.square(u * 5)).inflate(u * 0.4), Paint()..color = const Color(0xFFDDB46B));
    final line = Paint()
      ..color = const Color(0xFF3A2410)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(o + Offset(0, i * u), o + Offset(u * 5, i * u), line);
      canvas.drawLine(o + Offset(i * u, 0), o + Offset(i * u, u * 5), line);
    }
    const stones = [(1, 1, 1), (2, 1, 2), (2, 2, 1), (3, 2, 2), (1, 3, 1), (3, 3, 2), (2, 4, 2), (4, 1, 1)];
    for (final (x, y, v) in stones) {
      canvas.drawCircle(o + Offset(x * u, y * u), u * 0.46, Paint()..color = v == 1 ? const Color(0xFF1A1A1A) : const Color(0xFFF4F1EA));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DameArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 5;
    final o = Offset(size.width / 2 - u * 2, size.height / 2 - u * 2);
    for (var i = 0; i < 16; i++) {
      final r = i ~/ 4;
      final c = i % 4;
      canvas.drawRect(
        Rect.fromLTWH(o.dx + c * u, o.dy + r * u, u, u),
        Paint()..color = (r + c).isOdd ? const Color(0xFF7A4A2A) : const Color(0xFFF0DDB8),
      );
    }
    void stone(int r, int c, bool white, {bool king = false}) {
      final center = o + Offset((c + 0.5) * u, (r + 0.5) * u);
      canvas.drawCircle(center, u * 0.4, Paint()..color = white ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22));
      if (king) canvas.drawCircle(center, u * 0.16, Paint()..color = const Color(0xFFE8B923));
    }

    stone(0, 1, false);
    stone(0, 3, false);
    stone(1, 2, false);
    stone(2, 1, true, king: true);
    stone(3, 0, true);
    stone(3, 2, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MuehleArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 7.5;
    final o = Offset(size.width / 2 - u * 3, size.height / 2 - u * 3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.12
      ..color = const Color(0xFFD9B67A);
    for (var r = 0; r < 3; r++) {
      canvas.drawRect(Rect.fromLTWH(o.dx + r * u, o.dy + r * u, (6 - 2 * r) * u, (6 - 2 * r) * u), line);
    }
    canvas.drawLine(o + Offset(u * 3, 0), o + Offset(u * 3, u * 2), line);
    canvas.drawLine(o + Offset(u * 3, u * 4), o + Offset(u * 3, u * 6), line);
    canvas.drawLine(o + Offset(0, u * 3), o + Offset(u * 2, u * 3), line);
    canvas.drawLine(o + Offset(u * 4, u * 3), o + Offset(u * 6, u * 3), line);
    void stone(double x, double y, bool white) {
      canvas.drawCircle(o + Offset(x * u, y * u), u * 0.42, Paint()..color = white ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22));
    }

    stone(0, 0, true);
    stone(3, 0, true);
    stone(6, 0, true);
    stone(1, 5, false);
    stone(3, 4, false);
    stone(5, 5, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HalmaArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.42;
    final star = Path();
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      final rr = i.isEven ? r : r * 0.58;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFE9D7B0));
    const colors = [Color(0xFFD8402B), Color(0xFF2E9E57), Color(0xFFE8B923), Color(0xFF2F7FD0), Color(0xFF8E4FC9), Color(0xFFEE7F2D)];
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      for (var k = 0; k < 3; k++) {
        final pt = c + Offset(math.cos(a), math.sin(a)) * (r * (0.82 - k * 0.14)) + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * ((k - 1) * r * 0.08);
        canvas.drawCircle(pt, r * 0.07, Paint()..color = colors[i]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MadnArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 5.5;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, u * 2.4, Paint()..color = const Color(0xFFF3E3B8));
    const colors = [Color(0xFFD8402B), Color(0xFF2F7FD0), Color(0xFF2E9E57), Color(0xFFE8B923)];
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      final o = c + Offset(math.cos(a), math.sin(a)) * (u * 1.5);
      // Spielfigur: Kopf und Körper
      canvas.drawCircle(o + Offset(u * 0.05, u * 0.1), u * 0.45, Paint()..color = Colors.black26);
      final body = Path()
        ..moveTo(o.dx - u * 0.38, o.dy + u * 0.45)
        ..quadraticBezierTo(o.dx, o.dy - u * 0.5, o.dx + u * 0.38, o.dy + u * 0.45)
        ..close();
      canvas.drawPath(body, Paint()..color = colors[i]);
      canvas.drawCircle(o - Offset(0, u * 0.25), u * 0.22, Paint()..color = colors[i]);
      canvas.drawCircle(o - Offset(u * 0.07, u * 0.32), u * 0.07, Paint()..color = Colors.white54);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KniffelArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width / 4.4, size.height / 2.6);
    void die(Offset c, double angle, int v) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final r = Rect.fromCenter(center: Offset.zero, width: u, height: u);
      canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(2, 3)), Radius.circular(u * 0.18)), Paint()..color = Colors.black38);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u * 0.18)), Paint()..color = const Color(0xFFFFF8E8));
      const spots = {
        5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
        6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
      };
      for (final (x, y) in spots[v]!) {
        canvas.drawCircle(Offset(x * u * 0.27, y * u * 0.27), u * 0.09, Paint()..color = const Color(0xFF2A160E));
      }
      canvas.restore();
    }

    die(Offset(size.width * 0.3, size.height * 0.55), -0.2, 6);
    die(Offset(size.width * 0.52, size.height * 0.45), 0.1, 6);
    die(Offset(size.width * 0.73, size.height * 0.58), 0.3, 5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LadderArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height) / 5;
    final o = Offset(size.width / 2 - u * 2, size.height / 2 - u * 2);
    for (var i = 0; i < 16; i++) {
      canvas.drawRect(
        Rect.fromLTWH(o.dx + (i % 4) * u, o.dy + (i ~/ 4) * u, u, u),
        Paint()..color = (i % 4 + i ~/ 4).isEven ? const Color(0xFFF3E3B8) : const Color(0xFFE2C98E),
      );
    }
    final rail = Paint()
      ..strokeWidth = u * 0.12
      ..color = const Color(0xFF8A5A2B);
    canvas.drawLine(o + Offset(u * 0.6, u * 3.7), o + Offset(u * 1.6, u * 0.4), rail);
    canvas.drawLine(o + Offset(u * 1.0, u * 3.8), o + Offset(u * 2.0, u * 0.5), rail);
    for (var k = 1; k < 6; k++) {
      final t = k / 6;
      canvas.drawLine(
        Offset.lerp(o + Offset(u * 0.6, u * 3.7), o + Offset(u * 1.6, u * 0.4), t)!,
        Offset.lerp(o + Offset(u * 1.0, u * 3.8), o + Offset(u * 2.0, u * 0.5), t)!,
        rail..strokeWidth = u * 0.08,
      );
    }
    final snake = Path()
      ..moveTo(o.dx + u * 3.4, o.dy + u * 0.5)
      ..quadraticBezierTo(o.dx + u * 2.4, o.dy + u * 1.4, o.dx + u * 3.2, o.dy + u * 2.2)
      ..quadraticBezierTo(o.dx + u * 3.9, o.dy + u * 3.0, o.dx + u * 2.8, o.dy + u * 3.6);
    canvas.drawPath(snake, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E7D3A));
    canvas.drawCircle(o + Offset(u * 3.4, u * 0.5), u * 0.24, Paint()..color = const Color(0xFF2E7D3A));
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
/// Unter der Maus wächst es ein wenig, beim Drücken gibt es nach.
class _Cabinet extends StatefulWidget {
  const _Cabinet({required this.game});
  final _Game game;

  @override
  State<_Cabinet> createState() => _CabinetState();
}

class _CabinetState extends State<_Cabinet> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.97 : (_hover ? 1.025 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: _cabinet(context),
        ),
      ),
    );
  }

  Widget _cabinet(BuildContext context) {
    final game = widget.game;
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
                      foregroundPainter: _GlassPainter(),
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

/// Lobbybild eines Slots: Hintergrund und zwei Symbole.
class _SlotArt extends CustomPainter {
  _SlotArt(this.game, this.big, this.small);
  final SlotGame game;
  final int big;
  final int small;

  @override
  void paint(Canvas canvas, Size size) {
    game.paintBackdrop(canvas, Offset.zero & size, 0.3);
    final s = math.min(size.width, size.height) * 0.7;
    final c = size.center(Offset.zero);
    game.paintSymbol(canvas, Rect.fromCenter(center: c.translate(s * 0.34, s * 0.08), width: s, height: s), big);
    game.paintSymbol(canvas, Rect.fromCenter(center: c.translate(-s * 0.38, -s * 0.08), width: s * 0.8, height: s * 0.8), small);
  }

  @override
  bool shouldRepaint(_SlotArt old) => false;
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

/// Pokertisch mit Karten und Chips: holdem zwei Karten, omaha vier, caribbean fünf und die Bank.
class _PokerArt extends CustomPainter {
  _PokerArt(this.kind);
  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final felt = Rect.fromCenter(center: c.translate(0, 14), width: size.width * 0.9, height: size.height * 0.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(felt, Radius.circular(felt.height / 2)),
      Paint()..color = const Color(0xFF6B3E1E),
    );
    final inner = felt.deflate(size.width * 0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)),
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF239A7C), Color(0xFF145C4A)])
            .createShader(inner),
    );
    final w = size.width * 0.16;
    switch (kind) {
      case 'omaha':
        const cards = [('A', Suit.spades), ('K', Suit.hearts), ('Q', Suit.clubs), ('J', Suit.diamonds)];
        for (var i = 0; i < 4; i++) {
          _miniCard(canvas, c + Offset((i - 1.5) * w * 0.62, 10 + (i - 1.5).abs() * 4), w, (i - 1.5) * 0.22, cards[i].$1, cards[i].$2);
        }
        _chips(canvas, Offset(inner.right - w * 0.9, inner.bottom - w * 0.55), w * 0.42, 5, const Color(0xFF2B5BD7));
      case 'draw':
        // Fächer aus fünf Karten, zwei davon hochgeschoben zum Tauschen
        const cards = [('7', Suit.clubs), ('K', Suit.spades), ('K', Suit.hearts), ('2', Suit.diamonds), ('9', Suit.hearts)];
        for (var i = 0; i < 5; i++) {
          final up = i == 0 || i == 3 ? -12.0 : 0.0;
          _miniCard(canvas, c + Offset((i - 2) * w * 0.66, 14 + up + (i - 2).abs() * 5.0), w * 0.92, (i - 2) * 0.16, cards[i].$1, cards[i].$2);
        }
        _chips(canvas, Offset(inner.right - w * 0.8, inner.bottom - w * 0.5), w * 0.4, 4, const Color(0xFFD7392B));
      case 'caribbean':
        const cards = [('10', Suit.hearts), ('J', Suit.hearts), ('Q', Suit.hearts), ('K', Suit.hearts), ('A', Suit.hearts)];
        for (var i = 0; i < 5; i++) {
          _miniCard(canvas, c + Offset((i - 2) * w * 0.66, 14 + (i - 2).abs() * 5.0), w * 0.92, (i - 2) * 0.16, cards[i].$1, cards[i].$2);
        }
        // Spielmarke der Bank
        final d = Offset(inner.left + w * 0.8, inner.top + w * 0.6);
        canvas.drawCircle(d, w * 0.32, Paint()..color = const Color(0xFFFFF8E7));
        final tp = TextPainter(
          text: TextSpan(text: 'Bank', style: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w800, fontSize: w * 0.2, color: const Color(0xFF241410))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, d - Offset(tp.width / 2, tp.height / 2));
      default:
        _miniCard(canvas, c + Offset(-w * 0.35, 6), w * 1.1, -0.18, 'A', Suit.spades);
        _miniCard(canvas, c + Offset(w * 0.35, 6), w * 1.1, 0.18, 'A', Suit.hearts);
        _chips(canvas, Offset(inner.left + w * 0.9, inner.bottom - w * 0.55), w * 0.42, 6, const Color(0xFFC8321F));
        _chips(canvas, Offset(inner.right - w * 0.9, inner.bottom - w * 0.5), w * 0.42, 4, const Color(0xFF241410));
    }
  }

  void _chips(Canvas canvas, Offset base, double r, int n, Color color) {
    for (var i = 0; i < n; i++) {
      final c = base - Offset(0, i * r * 0.32);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(0, r * 0.12), width: r * 2, height: r * 0.8), Paint()..color = const Color(0x55000000));
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 0.8), Paint()..color = color);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 1.4, height: r * 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = const Color(0xFFFFF8E7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PokerArt oldDelegate) => oldDelegate.kind != kind;
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

/// Glanz auf dem gewölbten Glas über dem Motiv.
class _GlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shine = Path()
      ..moveTo(size.width * 0.08, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.12, size.height * 0.08, size.width * 0.5, size.height * 0.04)
      ..lineTo(size.width * 0.5, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.16, size.width * 0.14, size.height * 0.55)
      ..close();
    canvas.drawPath(shine, Paint()..color = Colors.white.withValues(alpha: 0.07));
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent, Colors.black.withValues(alpha: 0.12)],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) => false;
}
