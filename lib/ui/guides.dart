import 'package:flutter/material.dart';

import '../games/chess/chess_board.dart';
import '../games/chess/chess_engine.dart';
import '../games/chess/chess_tutorial.dart';
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
