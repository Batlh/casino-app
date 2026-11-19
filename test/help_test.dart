import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/ui/help_screen.dart';

void main() {
  test('Hilfe: Suche findet die passenden Kapitel', () {
    List<String> find(String q) => [for (final t in helpTopics) if (t.matches(q)) t.title];
    expect(find(''), hasLength(helpTopics.length));
    expect(find('Firewall'), ['Probleme lösen']);
    expect(find('tagesbonus'), contains('Erste Schritte'));
    expect(find('mahjong netz'), contains('Im Netzwerk spielen'));
    expect(find('gibtesnicht'), isEmpty);
  });

  test('Hilfe nennt alle Netzspiele', () {
    final net = helpTopics.firstWhere((t) => t.title == 'Im Netzwerk spielen');
    for (final g in ['Mau-Mau', 'Skat', 'Poker', 'Viererkette', 'Memory', 'Schach', 'Mahjong', 'Roulette', 'Keno', 'Black Jack', 'Caribbean Stud']) {
      expect(net.matches(g), isTrue, reason: g);
    }
  });
}
