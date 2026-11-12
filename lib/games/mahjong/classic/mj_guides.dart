import 'package:flutter/material.dart';

import '../../../ui/guide.dart';
import '../mahjong_tutorial.dart';
import '../tiles.dart';
import 'mj_rules.dart';

Widget _row(List<int> tiles, {double width = 24}) => Wrap(
      spacing: 2,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [for (final t in tiles) t < 0 ? SizedBox(width: width * 0.5) : TileView(tile: t, width: width)],
    );

const _basics = [
  QuizLesson(
    title: 'Die Steine',
    text: 'Drei Farben mit den Zahlen 1 bis 9: Zeichen (rotes 萬), Kreise und Bambus. Dazu kommen je nach Regel vier Winde '
        'und drei Drachen. Jeden Stein gibt es viermal.',
    tiles: [0, 4, 8, -1, 9, 13, 17, -1, 18, 22, 26, -1, 27, 28, 29, 30, -1, 31, 32, 33],
    question: 'Welcher Stein ist die 7 Bambus?',
    tileOptions: [6, 15, 24, 25],
    correct: 2,
    explain: 'Richtig. Bambus hat grüne Stäbchen, Kreise runde Münzen und Zeichen das rote 萬.',
  ),
  QuizLesson(
    title: 'Gruppen und Paar',
    text: 'Gewonnen hat, wer alle Steine in Gruppen und ein Paar ordnet. Eine Gruppe ist eine Folge wie 3-4-5 einer Farbe '
        'oder ein Pung aus drei gleichen Steinen. Vier gleiche heißen Kan und zählen wie ein Pung, dafür gibt es einen Ersatzstein.',
    tiles: [11, 12, 13, -1, 20, 20, 20, -1, 33, 33],
    question: 'Welcher Stein macht aus 6 und 8 Zeichen eine Folge?',
    tileOptions: [6, 16, 25, 8],
    correct: 0,
    explain: 'Genau, die 7 Zeichen. Folgen gibt es nur innerhalb einer Farbe, nie mit Winden oder Drachen.',
  ),
];

final _sichuanLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Nur drei Farben',
    text: 'Beim Sichuan-Mahjong gibt es keine Winde, keine Drachen und keine Blumen: 108 Steine in Zeichen, Kreisen und Bambus. '
        'Chi gibt es nicht, du darfst nur Pung und Kan rufen. Folgen in der Hand zählen trotzdem.',
    tiles: [0, 1, 2, -1, 12, 12, 12, -1, 24, 24],
    question: 'Was darfst du auf einen fremden Abwurf rufen?',
    textOptions: ['Chi und Pung', 'Nur Pung und Kan', 'Gar nichts'],
    correct: 1,
    explain: 'Richtig. Ohne Chi ist es schwerer, eine Folge zu vervollständigen, deshalb sind Pungs beliebt.',
  ),
  const QuizLesson(
    title: 'Drei Steine tauschen',
    text: 'Vor dem Spiel gibt jeder drei Steine derselben Farbe ab. Ob sie nach rechts, links oder über den Tisch gehen, '
        'entscheidet der Zufall. Gib Steine ab, die nicht zusammenpassen.',
    tiles: [0, 3, 8, -1, 10, 11, 12, 15, 15, -1, 20, 21, 22, 25],
    question: 'Welche drei Steine gibst du am besten ab?',
    textOptions: ['1, 4 und 9 Zeichen', '2, 3 und 4 Kreise', '3, 4 und 5 Bambus'],
    correct: 0,
    explain: 'Genau. Die Zeichen sind einzeln und gehören zu keiner Gruppe. Die anderen Farben sind schon fast fertig.',
  ),
  const QuizLesson(
    title: 'Eine Farbe streichen',
    text: 'Danach streicht jeder eine Farbe. Steine dieser Farbe musst du zuerst abwerfen, und solange du welche hast, '
        'darfst du nicht gewinnen. Wähle die Farbe, von der du am wenigsten hast.',
    tiles: [1, 6, -1, 9, 10, 11, 14, 16, 16, -1, 18, 19, 23, 23, 24],
    question: 'Welche Farbe streichst du hier?',
    textOptions: ['Zeichen', 'Kreise', 'Bambus'],
    correct: 0,
    explain: 'Richtig, nur zwei Zeichen. Die roten Punkte auf deinen Steinen zeigen dir später die gestrichene Farbe.',
  ),
  const QuizLesson(
    title: 'Blumenschwein',
    text: 'Ist die Mauer leer und hält jemand noch Steine der gestrichenen Farbe, ist er das Blumenschwein und zahlt allen '
        'anderen den Höchstwert. Wer gar nicht fertig ist, zahlt denen, die fertig sind.',
    question: 'Was passiert, wenn du am Ende noch einen Stein der gestrichenen Farbe hast?',
    textOptions: ['Nichts', 'Du zahlst allen den Höchstwert', 'Du bekommst einen Bonus'],
    correct: 1,
    explain: 'Genau. Deshalb gehören Steine der gestrichenen Farbe immer zuerst weg.',
  ),
  const QuizLesson(
    title: 'Fan und Wurzeln',
    text: 'Eine einfache Hand ist 100 Punkte wert, jedes Fan verdoppelt. Reine Farbe und Sieben Paare geben 2 Fan, nur Pungs 1. '
        'Vier gleiche Steine in der Hand (Wurzel) geben je 1 Fan. Selbst gezogen gibt 1 Fan. Mehr als 6 Fan zählen nicht.',
    tiles: [9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15],
    question: 'Wie viele Fan hat diese Hand mit Sieben Paaren in einer Farbe?',
    textOptions: ['2', '4', '6'],
    correct: 1,
    explain: 'Richtig: 2 für Sieben Paare und 2 für die reine Farbe, also 1.600 Punkte.',
  ),
  const QuizLesson(
    title: 'Blutkampf und Blutfluss',
    text: 'Im Blutkampf ist für den Sieger die Hand vorbei, die anderen spielen weiter, bis nur einer übrig ist. Im Blutfluss '
        'bleibt der Sieger mit fester Hand im Spiel und kann immer wieder gewinnen, bis die Mauer leer ist. So spielt man auch '
        'Mahjong Inferno.',
    question: 'Wer darf im Blutfluss nach einem Sieg weiter gewinnen?',
    textOptions: ['Nur wer noch nicht gewonnen hat', 'Jeder, auch der Sieger', 'Niemand'],
    correct: 1,
    explain: 'Genau. Mit fester Hand wirfst du jeden gezogenen Stein ab, bis wieder einer passt.',
  ),
];

final _hkLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Blumen',
    text: 'Zu den 136 Steinen kommen vier Blumen und vier Jahreszeiten. Ziehst du eine, legst du sie offen hin und nimmst '
        'einen Ersatzstein. Passt die Zahl zu deinem Sitz (Ost 1, Süd 2, West 3, Nord 4), bringt sie 1 Fan.',
    tiles: [34, 35, 36, 37, -1, 38, 39, 40, 41],
    question: 'Du sitzt im Süden. Welche Blume gehört dir?',
    tileOptions: [34, 35, 36, 37],
    correct: 1,
    explain: 'Richtig, die Blume 2. Ohne eine einzige Blume gibt es übrigens auch 1 Fan.',
  ),
  const QuizLesson(
    title: 'Fan zählen',
    text: 'Nur Pungs gibt 3 Fan, halbe Farbe (eine Farbe plus Ehrensteine) 3, reine Farbe 7. Drachen-Pungs und Pungs aus '
        'deinem Wind geben je 1 Fan. Ab 13 Fan ist die Grenze erreicht.',
    tiles: [9, 9, 9, 13, 13, 13, 16, 16, 16, 31, 31, 31, 28, 28],
    question: 'Wie viele Fan bringen gerufene Pungs in Kreisen mit Weißem Drachen und Süd-Paar, ohne Blumen?',
    textOptions: ['4', '7', '8'],
    correct: 2,
    explain: 'Nur Pungs 3, halbe Farbe 3, Weißer Drache 1 und ohne Blumen 1 ergibt 8 Fan.',
  ),
  const QuizLesson(
    title: 'Mindestwert',
    text: 'Hier braucht eine Hand mindestens 1 Fan. Eine Hühnerhand ganz ohne Muster zählt nicht. Viele Runden in Hongkong '
        'spielen mit 3 Fan Minimum.',
    question: 'Darfst du mit einer Hand ohne jedes Fan gewinnen?',
    textOptions: ['Ja', 'Nein'],
    correct: 1,
    explain: 'Richtig. Oft reicht schon Selbst gezogen, eine verdeckte Hand oder ein Drachen-Pung.',
  ),
  const QuizLesson(
    title: 'Selbst gezogen',
    text: 'Ziehst du den letzten Stein selbst von der Mauer, bringt das 1 Fan. Gewinnst du mit einer Hand ohne gerufene Steine '
        '(verdeckt) durch einen Abwurf, bringt das ebenfalls 1 Fan. Beides zusammen zählt nur einmal.',
    question: 'Du gewinnst selbst gezogen mit verdeckter Hand. Wie viele Fan bringt das?',
    textOptions: ['1', '2', '3'],
    correct: 0,
    explain: 'Richtig, 1 Fan für Selbst gezogen. Das Fan für die verdeckte Hand gibt es nur beim Sieg durch einen Abwurf.',
  ),
];

final _taiwanLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: '16 Steine',
    text: 'Jeder hat 16 Steine. Zum Gewinnen brauchst du fünf Gruppen und ein Paar, also 17 Steine mit dem letzten. '
        'Sieben Paare gibt es nicht, aber sieben Paare und ein Pung (17 Steine) zählen 8 Tai.',
    tiles: [0, 1, 2, -1, 3, 4, 5, -1, 15, 16, 17, -1, 27, 27, 27, -1, 31, 31, 31, -1, 22, 22],
    question: 'Wie viele Gruppen hat eine fertige Hand?',
    textOptions: ['Vier', 'Fünf', 'Sechs'],
    correct: 1,
    explain: 'Genau, fünf Gruppen und ein Paar.',
  ),
  const QuizLesson(
    title: 'Tai',
    text: 'Grundwert plus Tai: Geber 1, verdeckt und selbst gezogen 3, Drachen und eigener Wind je 1, eigene Blume 1, '
        'nur Pungs 4, halbe Farbe 4, reine Farbe 8. Jedes Tai bringt 50 Punkte zusätzlich zum Grundwert von 100.',
    question: 'Was bringt mehr: halbe Farbe oder nur Pungs?',
    textOptions: ['Halbe Farbe', 'Nur Pungs', 'Beides gleich viel'],
    correct: 2,
    explain: 'Beide zählen 4 Tai.',
  ),
  const QuizLesson(
    title: 'Verdeckt und selbst gezogen',
    text: 'Hast du nichts gerufen und ziehst den Gewinnstein selbst, gibt es 3 Tai. Der Geber bekommt immer 1 Tai dazu.',
    question: 'Du bist Geber und gewinnst verdeckt und selbst gezogen. Wie viele Tai sind das mindestens?',
    textOptions: ['1', '3', '4'],
    correct: 2,
    explain: 'Genau: 3 Tai für verdeckt und selbst gezogen plus 1 Tai als Geber.',
  ),
  const QuizLesson(
    title: 'Punkte ausrechnen',
    text: 'Grundwert 100, jedes Tai 50 dazu.',
    question: 'Was ist eine Hand mit 4 Tai wert?',
    textOptions: ['200', '300', '400'],
    correct: 1,
    explain: 'Richtig: 100 plus 4 mal 50 sind 300.',
  ),
];

final _mcrLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: '8 Punkte Minimum',
    text: 'Die offizielle chinesische Turnierregel kennt 81 Muster. Gewinnen darfst du erst ab 8 Punkten, Blumen zählen dabei '
        'nicht mit. Eine Hand ganz ohne Muster heißt Hühnerhand und zählt genau 8.',
    question: 'Zählen Blumen für die 8 Punkte?',
    textOptions: ['Ja', 'Nein'],
    correct: 1,
    explain: 'Richtig. Blumen gibt es obendrauf, aber nicht für das Minimum.',
  ),
  const QuizLesson(
    title: 'Beliebte Muster',
    text: 'Gemischte Straße (1-2-3, 4-5-6, 7-8-9 in drei Farben) 8, gleiche Folge in drei Farben 8, nur Pungs 6, '
        'halbe Farbe 6, alle Sorten (alle drei Farben, ein Wind, ein Drache) 6, reine Straße 16, reine Farbe 24.',
    tiles: [0, 1, 2, -1, 12, 13, 14, -1, 24, 25, 26],
    question: 'Wie heißt dieses Muster über drei Farben?',
    textOptions: ['Reine Straße', 'Gemischte Straße', 'Kurze Straße'],
    correct: 1,
    explain: 'Genau, die gemischte Straße bringt 8 Punkte und reicht allein zum Gewinnen.',
  ),
  const QuizLesson(
    title: 'Bezahlen',
    text: 'Bei Selbst gezogen zahlen alle drei den Wert plus 8. Bei einem Abwurf zahlt der Werfende den Wert plus 8, '
        'die beiden anderen je 8.',
    question: 'Du gewinnst mit 10 Punkten durch einen Abwurf. Wie viel zahlt der Werfende?',
    textOptions: ['10', '18', '30'],
    correct: 1,
    explain: '10 plus 8, die anderen zahlen je 8. Zusammen bekommst du 34.',
  ),
];

final _sgLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Tiersteine',
    text: 'In Singapur gibt es zusätzlich vier Tiere: Katze, Maus, Hahn und Tausendfüßer. Jedes bringt 1 Tai. '
        'Wie Blumen legst du sie offen hin und ziehst Ersatz.',
    tiles: [42, 43, 44, 45],
    question: 'Wie viele Tai bringen Katze und Maus zusammen?',
    textOptions: ['1', '2', '4'],
    correct: 1,
    explain: 'Richtig, je Tier 1 Tai.',
  ),
  const QuizLesson(
    title: 'Ping Hu',
    text: 'Nur Folgen mit einem einfachen Paar und beidseitiger Wartung heißt Ping Hu: 4 Tai ohne Blumen und Tiere, sonst 1. '
        'Mehr als 5 Tai zählen nicht.',
    question: 'Wann bringt Ping Hu die vollen 4 Tai?',
    textOptions: ['Immer', 'Nur ohne Blumen und Tiere', 'Nur selbst gezogen'],
    correct: 1,
    explain: 'Genau. Jeder Bonusstein macht Ping Hu billiger.',
  ),
  const QuizLesson(
    title: 'Obergrenze',
    text: 'In Singapur zählen höchstens 5 Tai. Alles darüber bringt nicht mehr.',
    question: 'Deine Hand hätte 7 Tai. Wie viele zählen?',
    textOptions: ['5', '7', '10'],
    correct: 0,
    explain: 'Genau, bei 5 Tai ist Schluss.',
  ),
];

final _koreanLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Zu dritt',
    text: 'Drei Spieler. Es fehlen Nordwind, die Bambus 2 bis 8 und die Jahreszeiten, nur Bambus 1 und 9 bleiben. Chi gibt es nicht.',
    tiles: [18, 26, -1, 27, 28, 29, -1, 34, 35, 36, 37],
    question: 'Welcher Bambus ist im Spiel?',
    tileOptions: [19, 22, 26, 24],
    correct: 2,
    explain: 'Richtig, nur 1 und 9 Bambus.',
  ),
  const QuizLesson(
    title: 'Punkte',
    text: 'Gewonnen wird ab 3 Handpunkten. Blumen bringen Bonuspunkte, die nicht zum Minimum zählen. Bei einem Abwurf zahlt '
        'der Werfende die Handpunkte doppelt, die Bonuspunkte zahlen beide.',
    question: 'Zählen Blumen für das Minimum?',
    textOptions: ['Ja', 'Nein'],
    correct: 1,
    explain: 'Genau, nur echte Muster zählen.',
  ),
  const QuizLesson(
    title: 'Kein Chi',
    text: 'In der koreanischen Variante gibt es kein Chi: Folgen musst du selbst ziehen. Pung und Kan auf Abwürfe gehen.',
    question: 'Darfst du eine Folge aus dem Abwurf deines linken Nachbarn rufen?',
    textOptions: ['Ja', 'Nein'],
    correct: 1,
    explain: 'Richtig, Chi gibt es hier nicht.',
  ),
  const QuizLesson(
    title: 'Bambus 1 und 9',
    text: 'Ein Pung aus Bambus 1 oder Bambus 9 bringt 1 Handpunkt. Hast du beide, gibt es 4 Punkte extra, zusammen also 6.',
    tiles: [18, 18, 18, -1, 26, 26, 26],
    question: 'Wie viele Handpunkte bringen diese beiden Pungs zusammen?',
    textOptions: ['2', '4', '6'],
    correct: 2,
    explain: 'Genau: 1 + 1 + 4 = 6.',
  ),
];

final _zjLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Klare Punkte',
    text: 'Zung Jung ist eine moderne Wertung mit festen Punkten: nur Folgen 5, verdeckte Hand 5, Drachen-Pung 10, '
        'nur Pungs 30, halbe Farbe 40, reine Farbe 80. Höchstens 320 zählen. Eine Hand ganz ohne Muster ist 1 Punkt wert.',
    question: 'Wie viel bringt die reine Farbe?',
    textOptions: ['40', '80', '320'],
    correct: 1,
    explain: 'Richtig, 80 Punkte. Die halbe Farbe bringt 40.',
  ),
  const QuizLesson(
    title: 'Bezahlen',
    text: 'Bei Selbst gezogen zahlt jeder den Wert. Bei einem Abwurf zahlt der Werfende allein, und zwar dreifach.',
    question: 'Wer zahlt bei einem Abwurf?',
    textOptions: ['Alle', 'Nur der Werfende', 'Niemand'],
    correct: 1,
    explain: 'Genau. Gefährliche Steine solltest du deshalb festhalten.',
  ),
  const QuizLesson(
    title: 'Höchstwert',
    text: 'Mehr als 320 Punkte zählen in Zung Jung nicht.',
    question: 'Deine Muster ergeben zusammen 400 Punkte. Wie viel zählt die Hand?',
    textOptions: ['320', '400', '80'],
    correct: 0,
    explain: 'Genau, bei 320 ist die Grenze.',
  ),
];

final _westernLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Grundpunkte',
    text: 'Mahjong bringt 20. Ein offener Pung aus 2 bis 8 zählt 2, aus Enden oder Ehren 4; verdeckt doppelt, als Kan '
        'viermal so viel. Jede Blume 4, ein Paar aus Drachen oder eigenem Wind 2.',
    tiles: [31, 31, 31],
    question: 'Wie viel zählt ein verdeckter Pung aus Weißen Drachen?',
    textOptions: ['4', '8', '16'],
    correct: 1,
    explain: 'Ehrenstein 4, verdeckt doppelt: 8 Punkte, dazu eine Verdopplung für den Drachen.',
  ),
  const QuizLesson(
    title: 'Verdoppeln',
    text: 'Danach wird verdoppelt: für jeden Drachen-Pung, Pungs aus deinem Wind, nur Pungs, verdeckte Hand und halbe Farbe '
        'einmal, für reine Farbe dreimal. Mehr als 1.000 zählen nicht. Alle zahlen dem Sieger, der Geber doppelt.',
    question: 'Wie oft verdoppelt die reine Farbe?',
    textOptions: ['Einmal', 'Zweimal', 'Dreimal'],
    correct: 2,
    explain: 'Richtig, das ist das Achtfache.',
  ),
  const QuizLesson(
    title: 'Wer zahlt?',
    text: 'In der westlichen Wertung zahlen alle dem Sieger, der Geber doppelt.',
    question: 'Du gewinnst mit 40 Punkten, ein Mitspieler ist Geber. Wie viel zahlt er dir?',
    textOptions: ['40', '80', '120'],
    correct: 1,
    explain: 'Richtig, der Geber zahlt doppelt.',
  ),
];

final _filipinoLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Nur Farben in der Hand',
    text: 'Auf den Philippinen spielt man nur mit Kreisen, Bambus und Zeichen. Winde, Drachen, Blumen und Jahreszeiten '
        'sind alle „Blumen“: Sie werden sofort beiseitegelegt und durch einen neuen Stein ersetzt. Jeder hat 16 Steine '
        'und braucht fünf Gruppen und ein Paar.',
    tiles: [27, 31, 34, 38],
    question: 'Du ziehst den Ostwind. Was passiert?',
    textOptions: ['Er kommt in die Hand', 'Er wird beiseitegelegt und ersetzt', 'Du musst ihn abwerfen'],
    correct: 1,
    explain: 'Genau, Winde und Drachen zählen hier wie Blumen.',
  ),
  const QuizLesson(
    title: 'Viertel',
    text: 'Gezahlt wird in Vierteln einer Auszahlung. Der Sieg (Todas) ist eine ganze Auszahlung, also 4 Viertel. '
        'Escalera (1 bis 9 in einer Farbe), Siete Pares (sieben Paare und ein Pung) und alles in einer Farbe bringen je 2 dazu, '
        'nur Folgen, nur Pungs, ganz verdeckt und manche Wartungen je 1.',
    tiles: [9, 10, 11, 12, 13, 14, 15, 16, 17],
    question: 'Was bringt die Escalera zusätzlich?',
    textOptions: ['1 Viertel', '2 Viertel (eine halbe Auszahlung)', '4 Viertel'],
    correct: 1,
    explain: 'Richtig, eine halbe Auszahlung.',
  ),
  const QuizLesson(
    title: 'Bunot und Abwurf',
    text: 'Ziehst du den Gewinnstein selbst (Bunot), zahlen alle doppelt. Gewinnst du auf einen Abwurf, zahlt der Werfende '
        'doppelt und der Rest einfach.',
    question: 'Deine Hand ist 6 Viertel wert, du gewinnst auf Bens Abwurf. Was zahlt Ben?',
    textOptions: ['6 Viertel', '12 Viertel', 'Nichts'],
    correct: 1,
    explain: 'Genau, der Werfende zahlt doppelt.',
  ),
  const QuizLesson(
    title: 'Sofort bezahlt',
    text: 'Manches zahlt der Tisch sofort, egal wer die Hand gewinnt: ein Kan 1 Viertel, ein geheimer Kan und Sagasa '
        '(Pung zum Kan erweitert) je 2, keine einzige Blume beim Austeilen 1, 13 Blumen gesammelt 1.',
    question: 'Du erweiterst deinen Pung zum Kan. Wie heißt das?',
    textOptions: ['Bunot', 'Sagasa', 'Escalera'],
    correct: 1,
    explain: 'Richtig, Sagasa bringt sofort 2 Viertel von jedem.',
  ),
];

final _vietLessons = <QuizLesson>[
  ..._basics,
  const QuizLesson(
    title: 'Acht Joker-Arten',
    text: 'Vietnam spielt mit 24 Jokern, je drei von acht Arten. Grün: Allgemein (jeder Stein), Kreise, Bambus, Zeichen. '
        'Rot: Blume, Wind, Drache und Farbe (jeder Zahlenstein). Ein Joker ersetzt nur Steine seiner Art.',
    tiles: [47, 48, 49, 50, -1, 51, 52, 53, 54],
    question: 'Welcher Joker darf den Ostwind ersetzen?',
    textOptions: ['Der Kreise-Joker', 'Der Wind-Joker', 'Der Farb-Joker'],
    correct: 1,
    explain: 'Richtig. Der allgemeine Joker ginge auch, der Farb-Joker nur für Zahlensteine.',
  ),
  const QuizLesson(
    title: 'Joker in der Gruppe',
    text: 'Der Bambus-Joker füllt eine Lücke in einer Bambus-Folge, aber nicht in einer Kreise-Folge.',
    tiles: [18, 49, 20, -1, 9, 49, 11],
    question: 'Welche der beiden Gruppen ist mit dem Bambus-Joker gültig?',
    textOptions: ['Die Bambus-Folge links', 'Die Kreise-Folge rechts', 'Beide'],
    correct: 0,
    explain: 'Genau, er spielt nur Bambus.',
  ),
  const QuizLesson(
    title: 'Phán und Mủn',
    text: 'Gezählt wird in Phán. Jeder Phán verdoppelt die Auszahlung (1, 2, 4, 8, 16), sechs Phán sind 1 Mủn. '
        'Große Hände zählen gleich in Mủn: eine Farbe 2, Straße 1 bis 9 3, keine Blumen, keine Blätter 3. '
        '1 Mủn zahlt 32, jeder weitere Mủn 32 mehr. Sieben Paare gibt es nicht, ein Minimum auch nicht.',
    question: 'Wie viel zahlt eine Hand mit 3 Phán?',
    textOptions: ['3', '4', '8'],
    correct: 1,
    explain: 'Richtig: 1, 2, 4 – drei Phán zahlen 4.',
  ),
  const QuizLesson(
    title: 'Blumen und Joker ablegen',
    text: 'Blumen kommen sofort zur Seite. Eine Blume mit der Zahl deines Platzes (Ost 1, Süd 2, West 3, Nord 4) bringt 1 Phán, '
        'Kaiser und Kaiserin nichts. Joker darfst du am Zug beiseitelegen („Joker ablegen“): Dann zählen sie Phán, '
        'zum Beispiel der allgemeine 2, als Ost 3, ersetzen aber keinen Stein mehr.',
    tiles: [34, 35, 55, 56, 47],
    question: 'Du sitzt Ost. Was bringt die Blume 1?',
    textOptions: ['Nichts', '1 Phán', '1 Mủn'],
    correct: 1,
    explain: 'Genau, sie passt zu deinem Platz.',
  ),
  const QuizLesson(
    title: 'Bezahlen',
    text: 'Gewinnst du auf einen Abwurf, zahlen alle, der Werfende doppelt. Ziehst du selbst, zahlen alle doppelt. '
        'Auf einen Stein darf nur einer gewinnen, der nächste in Spielrichtung.',
    question: 'Wer zahlt bei einem Sieg auf Bens Abwurf doppelt?',
    textOptions: ['Alle', 'Ben', 'Niemand'],
    correct: 1,
    explain: 'Richtig, der Werfende zahlt doppelt, die anderen einfach.',
  ),
];

List<QuizLesson> mjLessons(MjVariant v) => [..._variantLessons(v), ...mahjongPractice];

List<QuizLesson> _variantLessons(MjVariant v) => switch (v) {
      MjVariant.sichuanBattle || MjVariant.sichuanRiver => _sichuanLessons,
      MjVariant.hongKong => _hkLessons,
      MjVariant.taiwan => _taiwanLessons,
      MjVariant.mcr => _mcrLessons,
      MjVariant.singapore => _sgLessons,
      MjVariant.korean => _koreanLessons,
      MjVariant.zungJung => _zjLessons,
      MjVariant.western => _westernLessons,
      MjVariant.filipino => _filipinoLessons,
      MjVariant.vietnam => _vietLessons,
    };

const _turn = GuideSection(
  'Ein Zug',
  'Ziehen, dann einen Stein abwerfen: einmal antippen hebt ihn an, ein zweites Mal wirft ihn ab. Auf fremde Abwürfe '
      'kannst du Pung (zwei gleiche dazu) oder Kan (drei gleiche dazu) rufen, Chi (eine Folge) nur vom Spieler vor dir. '
      'Die Knöpfe erscheinen von selbst, auch „Gewinnen!“, sobald deine Hand fertig ist.',
);

GuideSection _coins(int players) => GuideSection(
      'Münzen',
      'Jeder eigene Sieg bringt 20 Münzen plus einen Zuschlag nach Wert, höchstens 200. Am Ende gibt es '
          '${players == 3 ? '250 oder 80 Münzen für Platz 1 oder 2' : '300, 120 oder 40 Münzen für Platz 1 bis 3'}.',
    );

GameGuide mjGuide(MjVariant v, {WidgetBuilder? tutorial}) {
  final r = mjRules[v]!;
  final sections = switch (v) {
    MjVariant.sichuanBattle || MjVariant.sichuanRiver => [
        GuideSection(
          'Ziel',
          'Sichuan-Mahjong aus Westchina, bekannt als Mahjong Inferno. Nur Zeichen, Kreise und Bambus, 108 Steine. '
              'Bilde vier Gruppen und ein Paar oder sieben Paare. Chi gibt es nicht.',
          picture: (_) => _row(const [0, 1, 2, -1, 12, 12, 12, -1, 22, 23, 24, -1, 25, 25, 25, -1, 8, 8]),
        ),
        const GuideSection(
          'Tauschen und Streichen',
          'Zuerst gibst du drei Steine einer Farbe ab und bekommst drei von einem Mitspieler. Dann streichst du eine Farbe: '
              'Diese Steine musst du zuerst abwerfen, mit ihnen kannst du nicht gewinnen. Wer am Ende noch welche hat, ist das '
              'Blumenschwein und zahlt allen den Höchstwert.',
        ),
        _turn,
        GuideSection(
          v == MjVariant.sichuanRiver ? 'Blutfluss' : 'Blutkampf',
          v == MjVariant.sichuanRiver
              ? 'Wer gewinnt, behält seine Hand fest und spielt weiter: Jeder gezogene Stein, der nicht passt, geht von selbst weg, '
                  'und jeder passende bringt einen neuen Sieg. Die Hand endet erst, wenn die Mauer leer ist.'
              : 'Wer gewinnt, scheidet aus der Hand aus, die anderen spielen weiter. Die Hand endet, wenn nur noch einer übrig ist '
                  'oder die Mauer leer ist. Mehrere dürfen auf denselben Abwurf gewinnen.',
        ),
        const GuideSection(
          'Punkte',
          'Jeder startet mit 10.000. Eine einfache Hand bringt 100, jedes Fan verdoppelt, höchstens 6 Fan: nur Pungs 1, '
              'Sieben Paare 2, reine Farbe 2, überall Eins oder Neun 2, jede Wurzel (vier Gleiche) 1, selbst gezogen 1. '
              'Kans zahlen sofort: verdeckt 200 von jedem, offen 200 vom Werfenden, erweitert 100 von jedem. '
              'Wer am Ende nicht fertig ist, zahlt den Fertigen ihren Wert. Gespielt werden vier Hände.',
        ),
        _coins(4),
      ],
    MjVariant.hongKong => [
        GuideSection(
          'Ziel',
          'Kantonesisches Mahjong, wie es in Hongkong gespielt wird. 136 Steine plus vier Blumen und vier Jahreszeiten. '
              'Vier Gruppen und ein Paar, dazu Sieben Paare und Dreizehn Waisen.',
          picture: (_) => _row(const [34, 35, 36, 37, -1, 38, 39, 40, 41]),
        ),
        _turn,
        const GuideSection(
          'Fan',
          'Mindestens 1 Fan. Selbst gezogen 1, verdeckte Hand 1, Drachen- oder eigener Wind-Pung je 1, eigene Blume 1, '
              'ohne Blumen 1, nur Folgen 1, nur Pungs 3, halbe Farbe 3, Sieben Paare 4, Drei kleine Drachen 5, reine Farbe 7. '
              'Ab 13 Fan ist die Grenze erreicht.',
        ),
        const GuideSection(
          'Bezahlen',
          'Der Wert verdoppelt sich mit dem Fan (bis 4 Fan, danach in halben Schritten). Bei einem Abwurf zahlt der Werfende '
              'doppelt, bei Selbst gezogen zahlen alle einfach. Der Geber bleibt, solange er gewinnt.',
        ),
        _coins(4),
      ],
    MjVariant.taiwan => [
        GuideSection(
          'Ziel',
          'Taiwanisches Mahjong mit 16 Steinen auf der Hand. Fertig ist die Hand mit fünf Gruppen und einem Paar. '
              'Blumen und Jahreszeiten sind dabei.',
          picture: (_) => _row(const [0, 1, 2, -1, 12, 13, 14, -1, 20, 21, 22, -1, 27, 27, 27, -1, 31, 31, 31, -1, 8, 8], width: 22),
        ),
        _turn,
        const GuideSection(
          'Tai',
          'Geber 1, verdeckte Hand 1, selbst gezogen 1 (beides zusammen 3), Drachen und eigene Winde je 1, eigene Blume 1, '
              'Warten auf einen Stein 1, Ping Hu 2, drei verdeckte Pungs 2, nur Pungs 4, halbe Farbe 4, reine Farbe 8, '
              'Sieben Paare und ein Pung 8. Jedes Tai bringt 50 Punkte zum Grundwert von 100.',
        ),
        _coins(4),
      ],
    MjVariant.mcr => [
        GuideSection(
          'Ziel',
          'Die offizielle chinesische Turnierregel (Mahjong Competition Rules). 81 Muster, gewonnen wird erst ab 8 Punkten. '
              'Neben normalen Händen gibt es Sieben Paare, Dreizehn Waisen, die Verbundenen Steine (147, 258, 369 plus einzelne '
              'Ehren) und die Verbundene Straße (147, 258, 369 in drei Farben plus eine Gruppe und ein Paar).',
          picture: (_) => _row(const [0, 3, 6, -1, 10, 13, 16, -1, 20, 23, 26, -1, 27, 28, 29, 30, 31, 32, 33], width: 22),
        ),
        _turn,
        const GuideSection(
          'Punkte',
          'Kleine Muster: Selbst gezogen 1, Einzelwartung 1, ohne Ehren 1, Drachen-Pung 2, verdeckte Hand 2, nur Folgen 2. '
              'Größer: gemischte Straße 8, gleiche Folge in drei Farben 8, nur Pungs 6, halbe Farbe 6, alle Sorten 6, '
              'Verbundene Straße 12, reine Straße 16, Sieben Paare 24, reine Farbe 24, bis zu 88 für die ganz seltenen Hände. '
              'Blumen zählen je 1, aber nicht für das Minimum. Ein großes Muster schließt die kleinen aus, die schon darin stecken. '
              'Rand-, Mittel- und Einzelwartung zählen nur, wenn genau ein Stein die Hand fertig machen konnte. '
              'Noch nicht dabei: „Letzter seiner Art“ (4 Punkte).',
        ),
        const GuideSection(
          'Bezahlen',
          'Selbst gezogen: alle zahlen Wert plus 8. Abwurf: der Werfende zahlt Wert plus 8, die anderen 8. Jeder ist einmal Geber.',
        ),
        _coins(4),
      ],
    MjVariant.singapore => [
        GuideSection(
          'Ziel',
          'Mahjong aus Singapur und Malaysia mit 148 Steinen: dazu kommen Blumen, Jahreszeiten und vier Tiere. Mindestens 1 Tai.',
          picture: (_) => _row(const [42, 43, 44, 45, -1, 34, 38]),
        ),
        _turn,
        const GuideSection(
          'Tai',
          'Jedes Tier 1, eigene Blume oder Jahreszeit 1, Drachen- und eigener Wind-Pung je 1, Ping Hu 4 (mit Bonussteinen 1), '
              'nur Pungs 2, halbe Farbe 2, Sieben Paare 3, reine Farbe 4. Höchstens 5 Tai, jedes verdoppelt den Wert.',
        ),
        const GuideSection(
          'Bezahlen',
          'Bei einem Abwurf zahlt der Werfende doppelt, die anderen einfach. Selbst gezogen zahlen alle doppelt.',
        ),
        _coins(4),
      ],
    MjVariant.korean => [
        GuideSection(
          'Ziel',
          'Koreanisches Mahjong zu dritt. Es fehlen Nordwind, Bambus 2 bis 8 und die Jahreszeiten; vier Blumen sind dabei. '
              'Chi ist verboten, Folgen gibt es nur aus eigenen Steinen. Gewonnen wird ab 3 Handpunkten, der Geber wechselt jede Hand.',
          picture: (_) => _row(const [18, 26, -1, 27, 28, 29, -1, 31, 32, 33, -1, 34, 35, 36, 37]),
        ),
        _turn,
        const GuideSection(
          'Punkte',
          'Handpunkte: Drachen-Pung 1 (zwei Drachen 1 extra), Wind-Pung 1 (+1 eigener Wind, +1 Rundenwind), Kan 1 (drei Kans 3 extra), '
              'Pung Bambus 1 oder 9 je 1 (beide 4 extra), zwei gleiche Folgen 2, drei verdeckte Pungs 3, nur Pungs 3 (nur End- und '
              'Ehrensteine 6 extra), halbe Farbe 3, reine Farbe 6, Sieben Paare 3, Straße 1 bis 9 3, ohne Ehrensteine 1 (nur Folgen 2 '
              'extra), verdeckte Hand 2 (aus der Mauer 2 extra). Grenze 40, kleine Drachen und kleine Winde 20. '
              'Bonuspunkte zählen nicht fürs Minimum: aus der Mauer 1, letzter Stein 1, Ersatzstein 1, Kan geraubt 1, '
              'jede Blume 1 (alle vier 4 extra).',
        ),
        const GuideSection(
          'Bezahlen',
          'Jeder Punkt sind 10. Aus der Mauer: beide zahlen Hand- und Bonuspunkte. Auf einen Abwurf: der Werfende zahlt die '
              'Handpunkte doppelt, der andere nichts davon; die Bonuspunkte zahlen beide. Bei einer Grenzhand zahlen beide die '
              'Grenze, der Werfende doppelt. Quelle: englische Wikipedia „Three-player mahjong“.',
        ),
        _coins(3),
      ],
    MjVariant.zungJung => [
        GuideSection(
          'Ziel',
          'Zung Jung ist ein modernes Wertungssystem mit klaren, festen Punkten und ohne Blumen. Jede fertige Hand zählt, '
              'die einfachste 1 Punkt.',
          picture: (_) => _row(const [31, 31, 31, -1, 32, 32, 32, -1, 33, 33, 33]),
        ),
        _turn,
        const GuideSection(
          'Punkte',
          'Nur Folgen 5, verdeckte Hand 5, ohne Endsteine 5, Drachen-Pung und eigene Winde je 10, Sieben Paare 30, nur Pungs 30, '
              'halbe Farbe 40, Neun-Stein-Straße 40, reine Farbe 80, Drei große Drachen 130. Grenze 320.',
        ),
        const GuideSection('Bezahlen', 'Selbst gezogen zahlen alle den Wert. Bei einem Abwurf zahlt der Werfende dreifach.'),
        _coins(4),
      ],
    MjVariant.western => [
        GuideSection(
          'Ziel',
          'So spielte man Mahjong in Europa und Amerika in den 1920er Jahren. Punkte gibt es für Pungs, Kans, Blumen und '
              'wertvolle Paare, danach wird verdoppelt. Sieben Paare gibt es nicht.',
          picture: (_) => _row(const [27, 27, 27, -1, 32, 32, 32, -1, 34, 38]),
        ),
        _turn,
        const GuideSection(
          'Punkte',
          'Mahjong 20. Pung 2 (Enden und Ehren 4), verdeckt doppelt, Kan vierfach. Blume 4, Paar aus Drachen oder eigenem Wind 2, '
              'selbst gezogen 2, Einzelwartung 2. Verdopplungen: Drachen-Pung, eigener Wind-Pung, nur Pungs, verdeckte Hand, '
              'halbe Farbe je einmal, reine Farbe dreimal. Grenze 1.000.',
        ),
        const GuideSection(
          'Bezahlen',
          'Alle zahlen dem Sieger den Wert, der Geber zahlt und bekommt doppelt. In der echten alten Regel rechnen auch die '
              'Verlierer untereinander ab, das lassen wir weg.',
        ),
        _coins(4),
      ],
    MjVariant.filipino => [
        GuideSection(
          'Ziel',
          'Mahjong von den Philippinen: 16 Steine nur aus Kreisen, Bambus und Zeichen, fünf Gruppen und ein Paar. Winde, '
              'Drachen, Blumen und Jahreszeiten sind alle Blumen und werden sofort ersetzt. Siete Pares heißt sieben Paare und ein Pung.',
          picture: (_) => _row(const [9, 10, 11, 12, 13, 14, 15, 16, 17]),
        ),
        _turn,
        const GuideSection(
          'Punkte',
          'Gezählt wird in Vierteln einer Auszahlung (1 Viertel = 10 Punkte). Todas (Sieg) 4, Escalera 1 bis 9 in einer Farbe 2, '
              'Siete Pares 2, alles eine Farbe 2, nur Folgen 1, nur Pungs 1, All up (nichts aufgedeckt) 1, All down (alles aufgedeckt) 1, '
              'Single, Back to back und Paningit (Wartungen) je 1, vor dem fünften Abwurf 4, Bisaklat 4.',
        ),
        const GuideSection(
          'Bezahlen',
          'Bunot (selbst gezogen): alle zahlen doppelt. Auf einen Abwurf: der Werfende doppelt, die anderen einfach. Sofort zahlen '
              'alle: Kan 1 Viertel, geheimer Kan 2, Sagasa 2, keine Blume beim Austeilen 1, 13 Blumen 1. '
              'Quellen: „Mahjong, as we play it“ (mahjongero.com) und filipinomj.com; jeder Tisch spielt etwas anders.',
        ),
        _coins(4),
      ],
    MjVariant.vietnam => [
        GuideSection(
          'Ziel',
          'Vietnamesisches Mahjong mit 176 Steinen: die üblichen 136, acht Blumen und Jahreszeiten, je vier Kaiser und Kaiserin '
              'und 24 Joker. Vier Gruppen und ein Paar oder die Dreizehn Waisen; Sieben Paare zählen nicht.',
          picture: (_) => _row(const [47, 48, 49, 50, -1, 51, 52, 53, 54, -1, 55, 56]),
        ),
        _turn,
        const GuideSection(
          'Joker',
          'Grüne Joker: Allgemein (jeder Stein), Kreise, Bambus, Zeichen. Rote Joker: Blume, Wind, Drache, Farbe (jeder '
              'Zahlenstein). Jeder ersetzt nur seine Art. Der Blumen-Joker kommt wie eine Blume sofort zur Seite. Mit „Joker '
              'ablegen“ legst du einen Joker am Zug für Punkte beiseite und ziehst Ersatz. Auf einen abgeworfenen Joker darf '
              'jeder gewinnen, der fertig ist; Pung oder Chi mit Jokern gibt es hier nicht.',
        ),
        const GuideSection(
          'Phán',
          'Blume mit deiner Platzzahl 1, Kaiser und Kaiserin 0. Joker beiseite: Allgemein 2 (+1 als Ost), Kreise 1 (+1 Süd), '
              'Bambus 1 (+1 West), Zeichen 1 (+1 Nord), Blume 2, Wind 1 (+1 Süd), Drache 1 (+1 West), Farbe 2 (+1 Nord). '
              'Nur Folgen 1 (mit Ehren-Paar 3), nur Pungs 3.',
        ),
        const GuideSection(
          'Mủn',
          'Sechs Phán sind 1 Mủn. Nur Pungs mit Ehren oder aus Endsteinen 1, nur gerufene Pungs 1 (mit Ehren 2), ohne Blumen '
              'und Ehren 1 (dazu nur Folgen 2), eine Farbe 2, Straße 1 bis 9 3, nur Ehren 4, Dreizehn Waisen 2, keine Blumen, '
              'keine Blätter 3 bis 8, kleine drei Drachen 1, große 2, vier verdeckte Pungs 3, vier Kans 4, kleine vier Winde 5, '
              'große 8 (je +1 ohne Joker und +1 ohne Blumen), Segen des Himmels, der Erde oder des Menschen 2, Sieg auf einen '
              'abgeworfenen Joker 1.',
        ),
        const GuideSection(
          'Bezahlen',
          '0 oder 1 Phán zahlen 1 Einsatz, 2 Phán 2, 3 Phán 4, 4 Phán 8, 5 Phán 16, jeder Mủn 32. Auf einen Abwurf zahlen '
              'alle, der Werfende doppelt; selbst gezogen zahlen alle doppelt. Ein Einsatz sind 5 Punkte. '
              'Quelle: riichi_advanced (Dokumentation „vietnamese“). Weggelassen: der Sieg durch drei abgeworfene grüne Joker, '
              'die Rahmenformen der Joker und die Boni fürs Ablegen vor Spielbeginn.',
        ),
        _coins(4),
      ],
  };
  return GameGuide(r.title, sections, tutorial: tutorial, tutorialLabel: 'Übungen starten');
}
