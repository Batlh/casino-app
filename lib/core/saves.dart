import '../games/cards/playing_card.dart';
import '../games/solitaire/table_card.dart';

/// Kurzschrift für Karten im Spielstand: Rang und Farbe, z. B. „12s“ für die Pik Dame.
String cardCode(PlayingCard c) => '${c.rank}${c.suit.name[0]}';

PlayingCard cardFromCode(String s) {
  final suit = Suit.values.firstWhere((x) => x.name[0] == s[s.length - 1]);
  return PlayingCard(int.parse(s.substring(0, s.length - 1)), suit);
}

List<String> cardCodes(Iterable<PlayingCard> cards) => [for (final c in cards) cardCode(c)];
List<PlayingCard> cardsFromCodes(List<dynamic> codes) => [for (final c in codes) cardFromCode(c as String)];

/// Tischkarte mit offen (+) oder verdeckt (-).
List<String> tableCodes(List<TableCard> pile) => [for (final c in pile) '${cardCode(c.card)}${c.up ? '+' : '-'}'];

List<TableCard> tableFromCodes(List<dynamic> codes) => [
      for (final raw in codes)
        TableCard(cardFromCode((raw as String).substring(0, raw.length - 1)), up: raw.endsWith('+')),
    ];

List<int> intList(dynamic l) => [for (final x in l as List<dynamic>) x as int];
