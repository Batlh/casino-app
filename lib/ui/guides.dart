import 'package:flutter/material.dart';

import '../games/chess/chess_board.dart';
import '../games/chess/chess_engine.dart';
import '../games/chess/chess_tutorial.dart';
import '../games/mahjong/mahjong_tutorial.dart';
import '../games/mahjong/tiles.dart';
import '../games/shogi/shogi_board.dart';
import '../games/shogi/shogi_engine.dart';
import '../games/shogi/shogi_tutorial.dart';
import '../games/slots/slot_games.dart';
import 'guide.dart';

/// Kleines Brett als Bild in der Erklärung.
Widget _chessPicture(String fen, {Set<int> marks = const {}}) => SizedBox(
      width: 240,
      child: ChessBoardView(game: ChessGame.fromFen(fen), marks: marks),
    );

GameGuide slotGuide(SlotGame g) => GameGuide(g.name, [
      const GuideSection(
        'Ziel',
        'Dreh die Walzen und hoffe auf gleiche Symbole auf den Gewinnlinien. Die Linien laufen von links nach rechts; '
            'gezählt wird ab der ersten Walze ohne Lücke.',
      ),
      const GuideSection(
        'Einsatz',
        'Wähl unten den Einsatz pro Dreh. Gewinne sind ein Vielfaches davon. Die Gewinntabelle zeigt, was jedes Symbol zahlt.',
      ),
      GuideSection('Joker', g.wildText),
      GuideSection('Besonderheit', g.featureText),
      const GuideSection(
        'Tipp',
        'Automaten sind reines Glück. Gespielt wird nur mit Spielmünzen, die keinen Geldwert haben. Geht dir das Geld aus, '
            'gibt es neue Münzen, dazu einmal am Tag den Tagesbonus in der Lobby.',
      ),
    ]);

const holdemGuide = GameGuide("Texas Hold'em", [
  GuideSection(
    'Ziel',
    'Gewinne Chips von den Computergegnern. Jeder bekommt zwei verdeckte Karten, dazu kommen bis zu fünf offene '
        'Gemeinschaftskarten in der Mitte. Die beste Fünf-Karten-Hand aus allen sieben Karten gewinnt den Pot.',
  ),
  GuideSection(
    'Ablauf einer Hand',
    'Zwei Spieler zahlen Pflichteinsätze, die Blinds. Dann folgen vier Setzrunden: vor dem Flop, nach dem Flop (drei '
        'Karten), nach dem Turn (vierte Karte) und nach dem River (fünfte Karte). In jeder Runde kannst du passen '
        '(Fold), schieben (Check), mitgehen (Call) oder erhöhen (Raise). No-Limit heißt: Du darfst jederzeit alles setzen.',
  ),
  GuideSection(
    'Rangfolge der Hände',
    'Von oben nach unten: Royal Flush, Straight Flush, Vierling, Full House, Flush, Straße, Drilling, Zwei Paare, '
        'Ein Paar, höchste Karte.',
  ),
  GuideSection('Tipp', 'Spiel mit schwachen Startkarten lieber nicht mit. Ein Paar, zwei hohe Karten oder Karten gleicher Farbe sind ein guter Anfang.'),
]);

const omahaGuide = GameGuide('Omaha', [
  GuideSection(
    'Ziel',
    'Wie Texas Hold\'em, aber jeder bekommt vier verdeckte Karten. Für die Hand zählen immer genau zwei deiner vier Karten '
        'und genau drei der fünf Karten in der Mitte, nicht mehr und nicht weniger.',
  ),
  GuideSection(
    'Achtung',
    'Liegen vier Herz in der Mitte und du hast nur ein Herz, hast du keinen Flush: Du brauchst zwei Herz auf der Hand. '
        'Weil jeder vier Karten hat, sind starke Hände viel häufiger als beim Hold\'em.',
  ),
  GuideSection(
    'Setzen',
    'Blinds und vier Setzrunden wie beim Hold\'em. Hier wird No-Limit gespielt, in Casinos ist Omaha meist Pot-Limit.',
  ),
]);

const pachinkoGuide = GameGuide('Neon Pachinko', [
  GuideSection(
    'Ziel',
    'Schieß Kugeln ins Brett. Sie fallen durch die Nägel; landen sie in einer Tasche, gibt es Münzen. Jede Kugel kostet 10.',
  ),
  GuideSection(
    'Taschen',
    'Die Tulpen zahlen 25. Die Starttasche in der Mitte zahlt 30 und lässt die Ziffern im Anzeigefeld laufen. '
        'Zeigen sie drei gleiche Ziffern, beginnt das Fieber: Das Tor unten öffnet sich und zahlt 150 pro Kugel. Bei drei Siebenen dauert das Fieber länger.',
  ),
  GuideSection('Stärke', 'Mit dem Regler stellst du ein, wie kräftig geschossen wird. Zu schwache Schüsse rollen zurück, du bekommst die Kugel erstattet.'),
]);

const blackjackGuide = GameGuide('Black Jack', [
  GuideSection('Ziel', 'Komm näher an 21 als die Bank, ohne darüber zu gehen. Zahlen zählen ihren Wert, Bilder 10, das Ass 1 oder 11.'),
  GuideSection(
    'Ablauf',
    'Du setzt, dann gibt es zwei Karten für dich und zwei für die Bank, eine davon verdeckt. Du ziehst Karten („Karte“) oder '
        'bleibst stehen („Halten“). Mit zwei Karten darfst du verdoppeln: doppelter Einsatz, genau eine Karte. Zwei gleiche '
        'Karten darfst du einmal teilen. Die Bank zieht bis 16 und bleibt ab 17 stehen.',
  ),
  GuideSection('Auszahlung', 'Ein Sieg zahlt 1:1. Ein Black Jack, also Ass und Zehnerkarte als erste zwei Karten, zahlt 3:2. Gleichstand gibt den Einsatz zurück.'),
]);

const rouletteGuide = GameGuide('Roulette', [
  GuideSection('Ziel', 'Setz Jetons auf Zahlen oder Felder. Die Kugel bestimmt die Gewinnzahl von 0 bis 36.'),
  GuideSection(
    'Einsätze',
    'Eine einzelne Zahl zahlt 35:1. Rot oder Schwarz, Gerade oder Ungerade und 1 bis 18 oder 19 bis 36 zahlen 1:1. '
        'Ein Dutzend oder eine Kolonne zahlt 2:1. Fällt die Null, verlieren alle einfachen Chancen.',
  ),
  GuideSection('Bedienung', 'Jeton wählen, Feld antippen, Drehen. „Wiederholen“ setzt die letzten Einsätze noch einmal.'),
]);

const videoPokerGuide = GameGuide('Video Poker', [
  GuideSection('Ziel', 'Du bekommst fünf Karten. Halte die guten, tausche den Rest einmal aus und versuche, eine Gewinnhand zu bilden.'),
  GuideSection(
    'Gewinntabelle',
    'Royal Flush 800, Straight Flush 50, Vierling 25, Full House 9, Flush 6, Straße 4, Drilling 3, Zwei Paare 2, '
        'ein Paar ab Bube 1. Alles mal Einsatz.',
  ),
  GuideSection('Tipp', 'Halte immer ein Paar ab Bube und jede fertige Gewinnhand. Vier Karten zum Flush sind oft besser als ein kleines Paar.'),
]);

const klondikeGuide = GameGuide('Solitaire', [
  GuideSection('Ziel', 'Leg alle 52 Karten nach Farben sortiert von Ass bis König oben auf die vier Ablagen.'),
  GuideSection(
    'Spalten',
    'In den sieben Spalten legst du absteigend und abwechselnd rot und schwarz an, zum Beispiel Pik 7 auf Herz 8. '
        'Ganze Reihen lassen sich mitnehmen. In eine leere Spalte darf nur ein König. Wird eine verdeckte Karte frei, dreht sie sich um.',
  ),
  GuideSection('Stapel', 'Tipp oben links auf den Stapel, um eine oder drei Karten aufzudecken. Ist er leer, dreht ein Tipp ihn wieder um.'),
  GuideSection(
    'Münzen und Tipps',
    'Jede Karte, die zum ersten Mal auf eine Ablage kommt, bringt Münzen, ein Sieg 200 oder 400. Der Tipp-Knopf zeigt einen '
        'guten Zug; jeder Tipp zieht ein Zehntel der Siegprämie ab. Geht nichts mehr, sagt dir das Spiel Bescheid.',
  ),
]);

const spiderGuide = GameGuide('Spider Solitaire', [
  GuideSection('Ziel', 'Bilde in den zehn Spalten acht vollständige Reihen von König bis Ass in einer Farbe. Fertige Reihen verschwinden von selbst.'),
  GuideSection(
    'Anlegen',
    'Jede Karte darf auf eine um eins höhere, egal welche Farbe. Bewegen lassen sich aber nur Reihen in einer Farbe. '
        'In eine leere Spalte darf alles.',
  ),
  GuideSection('Austeilen', 'Oben rechts liegt der Stapel. Ein Tipp legt auf jede Spalte eine neue Karte, aber nur, wenn keine Spalte leer ist.'),
  GuideSection('Münzen und Tipps', 'Jede fertige Reihe bringt Münzen, der Sieg bis zu 1.000. Jeder Tipp zieht ein Zehntel der Siegprämie ab.'),
]);

const mauGuide = GameGuide('Mau Mau', [
  GuideSection('Ziel', 'Werde als Erster alle Karten los.'),
  GuideSection(
    'Legen',
    'Leg eine Karte gleicher Farbe oder gleichen Werts auf die oberste Karte. Kannst oder willst du nicht, ziehst du eine.',
  ),
  GuideSection(
    'Sonderkarten',
    'Sieben: Der Nächste zieht zwei, außer er legt selbst eine Sieben, dann zieht der Übernächste vier. Acht: Der Nächste setzt aus. '
        'Bube: Du wünschst dir eine Farbe. Was genau gilt, stellst du in den Einstellungen ein.',
  ),
  GuideSection('Münzen', 'Ein Sieg bringt 50 je Gegner, Platz zwei oder drei einen Trostpreis. Kommst du auf die letzte Karte, gibt es 5 extra.'),
]);

const einsGuide = GameGuide('Eins!', [
  GuideSection('Ziel', 'Werde als Erster alle Karten los.'),
  GuideSection('Legen', 'Leg eine Karte gleicher Farbe, gleicher Zahl oder gleichen Symbols. Farbwahlkarten passen immer. Wer nicht kann, zieht.'),
  GuideSection(
    'Aktionskarten',
    'Aussetzen, Richtungswechsel, +2 und +4. Mit Farbwahl bestimmst du die nächste Farbe. Hast du nur noch eine Karte, drück rechtzeitig „Eins! rufen“.',
  ),
  GuideSection(
    'Spielweisen',
    'Über „Spielweise“ wählst du Klassisch, Kehrseite, Gnadenlos, Kartenwerfer, Glücksrad oder Kraftkarten. '
        'Die genauen Regeln jeder Spielweise stehen im Spiel unter „Regeln“. Schwere Spielweisen zahlen mehr Münzen.',
  ),
]);

const heartsGuide = GameGuide('Schwarze Dame', [
  GuideSection('Ziel', 'Sammle möglichst wenige Strafpunkte. Jedes Herz zählt 1, die Pik Dame 13. Ab 100 Punkten endet das Spiel, der Niedrigste gewinnt.'),
  GuideSection(
    'Ablauf',
    'Vor jeder Runde gibst du drei Karten weiter. Wer die Kreuz Zwei hat, beginnt. Du musst die ausgespielte Farbe bedienen; '
        'die höchste Karte dieser Farbe gewinnt den Stich. Herz darf erst ausgespielt werden, wenn schon eins abgeworfen wurde.',
  ),
  GuideSection('Den Mond schießen', 'Holst du alle Herzen und die Pik Dame, bekommst du null Punkte und alle anderen je 26.'),
]);

const quatroGuide = GameGuide('Viererkette', [
  GuideSection('Ziel', 'Bilde eine Reihe aus vier Steinen gleicher Farbe oder gleicher Zahl, waagerecht, senkrecht oder schräg.'),
  GuideSection(
    'Legen',
    'Wirf einen Stein von oben in eine Spalte. Er muss zu einem Nachbarn passen: gleiche Farbe oder gleiche Zahl. '
        'Passt keiner, tauschst du einen Stein mit dem Beutel.',
  ),
  GuideSection('Aktionssteine', 'Tausch-Steine vertauschen zwei Spalten, Schieber drücken von oben und schieben den untersten Stein heraus, Minus zwei lässt den Nächsten zwei Steine zurücklegen.'),
]);

final chessGuide = GameGuide(
  'Schach',
  [
    GuideSection(
      'Ziel',
      'Setz den gegnerischen König matt: Er steht im Schach, also angegriffen, und kann sich durch nichts mehr retten. '
          'Weiß beginnt, danach wird abwechselnd gezogen.',
      picture: (_) => _chessPicture(ChessGame.startFen),
    ),
    GuideSection(
      'Die Figuren',
      'Bauer: ein Feld vor, beim ersten Zug auch zwei, schlägt schräg. Springer: im L-Sprung, darf über Figuren. '
          'Läufer: schräg beliebig weit. Turm: gerade beliebig weit. Dame: wie Turm und Läufer. König: ein Feld in jede Richtung.',
    ),
    GuideSection(
      'Sonderzüge',
      'Rochade: König zwei Felder Richtung Turm, der Turm springt über ihn. Schlagen im Vorbeigehen: Ein Bauer, der zwei Felder '
          'neben deinen Bauern zieht, darf sofort so geschlagen werden, als wäre er nur eins gegangen. Umwandlung: Ein Bauer auf der '
          'letzten Reihe wird zu einer Figur deiner Wahl.',
      picture: (_) => _chessPicture('4k3/8/8/3pP3/8/8/8/4K2R w K d6 0 1', marks: {35, 36}),
    ),
    GuideSection(
      'Remis',
      'Unentschieden ist es bei Patt (kein Zug möglich, aber kein Schach), bei dreifacher Wiederholung der Stellung, '
          'nach 50 Zügen ohne Schlagen oder Bauernzug und wenn niemand mehr mattsetzen kann.',
    ),
    GuideSection(
      'Bedienung und Münzen',
      'Tipp eine Figur an, die grünen Punkte zeigen ihre Züge. Gegen den Computer bringt ein Sieg je nach Stufe 50 bis 400 Münzen, '
          'ein Remis die Hälfte. Zu zweit spielt ihr abwechselnd am selben Gerät.',
    ),
  ],
  tutorial: (_) => const ChessTutorialScreen(),
  tutorialLabel: 'Schach lernen: 12 kleine Übungen',
);

Widget _shogiPicture(String sfen) => SizedBox(
      width: 260,
      child: ShogiBoardView(game: ShogiGame.fromSfen(sfen)),
    );

Widget _pieceRow(List<int> pieces) => Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [for (final p in pieces) ShogiPieceView(piece: p, size: 40)],
    );

Widget _tileRow(List<int> tiles, {double width = 34}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in tiles)
            t < 0
                ? const SizedBox(width: 12)
                : Padding(padding: const EdgeInsets.all(1), child: TileView(tile: t, width: width, depth: 3)),
        ],
      ),
    );

final shogiGuide = GameGuide(
  'Shogi',
  [
    GuideSection(
      'Ziel',
      'Shogi ist japanisches Schach auf 9 mal 9 Feldern. Wer den gegnerischen König mattsetzt, gewinnt. Sente zieht zuerst '
          'und sitzt unten, Gote oben. Die Steine haben keine Farben: Ihre Spitze zeigt zum Gegner.',
      picture: (_) => _shogiPicture(ShogiGame.startSfen),
    ),
    GuideSection(
      'Die Steine',
      'König 王: ein Feld in jede Richtung. Turm 飛: gerade beliebig weit. Läufer 角: schräg beliebig weit. '
          'Goldgeneral 金: ein Feld, nur nicht schräg zurück. Silbergeneral 銀: ein Feld nach vorn oder schräg. '
          'Springer 桂: nur nach vorn im L-Sprung. Lanze 香: geradeaus nach vorn beliebig weit. Bauer 歩: ein Feld vor.',
      picture: (_) => _pieceRow(const [sKing, sRook, sBishop, sGold, sSilver, sKnight, sLance, sPawn]),
    ),
    GuideSection(
      'Beförderung',
      'Die drei Reihen auf der Gegnerseite sind die Zone. Ein Zug hinein, heraus oder darin darf einen Stein befördern; '
          'er wird umgedreht und rot beschriftet. Bauer, Lanze, Springer und Silber ziehen dann wie Gold. Turm und Läufer '
          'werden zu Drachenkönig 龍 und Drachenpferd 馬 und dürfen zusätzlich wie der König ziehen. Kann ein Stein sonst '
          'nie wieder ziehen, muss er befördert werden.',
      picture: (_) => _pieceRow(const [sTokin, 10, 11, 12, sHorse, sDragon]),
    ),
    const GuideSection(
      'Einsetzen',
      'Geschlagene Steine wandern in deine Hand. Statt zu ziehen darfst du einen davon auf ein freies Feld setzen, '
          'immer unbefördert. Verboten sind: zwei eigene unbeförderte Bauern in einer Linie, ein Bauer, Springer oder eine '
          'Lanze dort, wo sie nie mehr ziehen könnten, und ein eingesetzter Bauer, der sofort mattsetzt.',
    ),
    const GuideSection(
      'Bedienung und Münzen',
      'Tipp einen Stein auf dem Brett oder in deiner Hand an, die grünen Punkte zeigen, wohin er kann. Gegen den Computer '
          'bringt ein Sieg 50 bis 400 Münzen. Viermal dieselbe Stellung ist ein Remis.',
    ),
  ],
  tutorial: (_) => const ShogiTutorialScreen(),
  tutorialLabel: 'Shogi lernen: 10 kleine Übungen',
);

final mahjongSolitaireGuide = GameGuide(
  'Mahjong Solitär',
  [
    GuideSection(
      'Ziel',
      'Räum alle 144 Steine vom Turm ab, immer zwei gleiche auf einmal. Jede Sorte gibt es viermal. Blumen passen zu jeder '
          'Blume, Jahreszeiten zu jeder Jahreszeit.',
      picture: (_) => _tileRow(const [4, 4, -1, 31, 31, -1, 34, 36, -1, 39, 41]),
    ),
    const GuideSection(
      'Freie Steine',
      'Ein Stein ist frei, wenn nichts auf ihm liegt und seine linke oder rechte Seite frei ist. Nur freie Steine lassen '
          'sich antippen. Steine, die gerade blockiert sind, erscheinen etwas dunkler.',
    ),
    const GuideSection(
      'Hilfe',
      'Der Tipp-Knopf zeigt ein freies Paar (30 Münzen vom Gewinn). Geht nichts mehr, mischt „Mischen“ die übrigen '
          'Steine lösbar neu (50 Münzen vom Gewinn). Rückgängig ist kostenlos. Auf kleinen Bildschirmen lässt sich das '
          'Brett mit zwei Fingern vergrößern.',
    ),
    const GuideSection(
      'Münzen',
      'Jedes abgeräumte Paar bringt 2 Münzen, ein leeres Brett 300 abzüglich Tipps und Mischen.',
    ),
    const GuideSection(
      'Formen',
      'Mit dem Knopf „Form“ wählst du den Aufbau: Schildkröte (144 Steine), Pyramide, Festung, Drache oder Kreuz. '
          'Jede Form wird so gemischt, dass sie lösbar ist.',
    ),
  ],
  tutorial: (_) => QuizTutorialScreen(title: 'Mahjong Solitär lernen', lessons: solitaireLessons),
  tutorialLabel: 'Mahjong Solitär lernen: 3 kurze Übungen',
);

final riichiGuide = GameGuide(
  'Riichi Mahjong',
  [
    GuideSection(
      'Ziel',
      'Vier Spieler, du und drei Computer. Bilde als Erster eine fertige Hand aus 14 Steinen: vier Gruppen und ein Paar. '
          'Gruppen sind Folgen wie 3-4-5 in einer Farbe oder drei gleiche Steine.',
      picture: (_) => _tileRow(const [0, 1, 2, -1, 12, 13, 14, -1, 19, 20, 21, -1, 27, 27, 27, -1, 33, 33], width: 24),
    ),
    GuideSection(
      'Die Steine',
      'Drei Farben von 1 bis 9: Zeichen, Kreise und Bambus. Dazu vier Winde und drei Drachen. Steine mit 1 und 9 heißen '
          'Endsteine, Winde und Drachen Ehrensteine.',
      picture: (_) => _tileRow(const [0, 8, -1, 9, 17, -1, 18, 26, -1, 27, 28, 29, 30, -1, 31, 32, 33], width: 24),
    ),
    const GuideSection(
      'Ein Zug',
      'Ziehen, dann einen Stein abwerfen: einmal antippen hebt ihn an, ein zweites Mal wirft ihn ab. Auf fremde Abwürfe '
          'kannst du Pon (zwei gleiche dazu), Kan (drei gleiche dazu) oder, nur vom Spieler links von dir, Chi (Folge) rufen. '
          'Damit wird deine Hand offen.',
    ),
    const GuideSection(
      'Gewinnen',
      'Mit dem letzten Stein vom Stapel sagst du Tsumo, mit einem fremden Abwurf Ron. Die Hand braucht mindestens ein Yaku, '
          'zum Beispiel Riichi, Menzen Tsumo, Tanyao (nur 2 bis 8) oder einen Drilling aus Drachen oder deinem Wind. '
          'Die Knöpfe erscheinen von selbst, sobald etwas möglich ist.',
    ),
    const GuideSection(
      'Riichi und Furiten',
      'Mit geschlossener Hand, der nur ein Stein fehlt, kannst du Riichi sagen: 1.000 Punkte Einsatz, dafür ein sicheres '
          'Yaku. Danach wirfst du jeden gezogenen Stein ab, der nicht passt. Liegt einer deiner Wartesteine in deinen eigenen '
          'Abwürfen, bist du Furiten und darfst nur mit Tsumo gewinnen.',
    ),
    const GuideSection(
      'Punkte und Münzen',
      'Han aus Yaku und Dora und Fu aus der Handform ergeben die Punkte. Jeder startet mit 25.000; gespielt wird eine '
          'Ostrunde, also mindestens vier Hände. Jede eigene Hand bringt 20 Münzen plus 10 je Han, am Ende gibt es '
          '300, 120 oder 40 Münzen für Platz 1 bis 3.',
    ),
  ],
  tutorial: (_) => QuizTutorialScreen(title: 'Mahjong lernen', lessons: riichiLessons),
  tutorialLabel: 'Mahjong lernen: 7 kurze Übungen',
);

const pinballGuide = GameGuide('Neon Flipper', [
  GuideSection(
    'Ziel',
    'Halte die Kugel mit den beiden Flippern im Spiel und sammle Punkte. Ein Spiel hat drei Kugeln und kostet 20 Münzen; '
        'am Ende gibt es eine Münze je 100 Punkte.',
  ),
  GuideSection(
    'Steuerung am PC',
    'Linker Flipper: A, Y oder linke Shift-Taste (auch Pfeil links). Rechter Flipper: L, M oder rechte Shift-Taste '
        '(auch Pfeil rechts). Abschuss: Leertaste, Enter oder Pfeil runter gedrückt halten, um die Feder zu spannen, '
        'dann loslassen. T rüttelt den Tisch, falls die Kugel festhängt.',
  ),
  GuideSection(
    'Steuerung am Handy',
    'Unten liegen drei große Tasten: Links und Rechts für die Flipper, in der Mitte der Abschuss. Beide Flipper '
        'lassen sich gleichzeitig drücken. Abschuss gedrückt halten spannt die Feder.',
  ),
  GuideSection(
    'Punkte',
    'Pilze 100, Schleudern über den Flippern 10, jede obere Gasse 50. Leuchten alle drei Gassen, gibt es 1.000 Punkte '
        'und der Multiplikator steigt, bis ×5. Er gilt für alle Punkte und fällt mit jeder verlorenen Kugel zurück auf ×1. '
        'In den ersten 6 Sekunden nach dem Abschuss rettet die Ballrettung einmal pro Kugel eine verlorene Kugel.',
  ),
]);
