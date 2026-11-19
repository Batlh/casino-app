import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/main.dart';
import 'package:gluckspfennig/ui/lobby_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Suche: Umlaute, Groß/klein, mehrere Wörter', () {
    expect(lobbyMatches('Glücksrad', 'Geldrad wie im Casino', 'gluecksrad'), isTrue);
    expect(lobbyMatches('Glücksrad', 'Geldrad wie im Casino', 'GLÜCK'), isTrue);
    expect(lobbyMatches('Mau Mau', 'Gegen bis zu drei Gegner', 'mau gegner'), isTrue);
    expect(lobbyMatches('Mau Mau', 'Gegen bis zu drei Gegner', 'mau poker'), isFalse);
    expect(lobbyMatches('Black Jack', 'Sechs Decks', '  '), isFalse);
  });

  testWidgets('Favorit setzen, Bereich erscheint, Suche filtert', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'save.lobby': '{"recent":["Roulette"]}'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Favoriten'), findsNothing);
    await tester.tap(find.byTooltip('Zu den Favoriten').first);
    await tester.pump();
    expect(find.text('Favoriten'), findsWidgets);
    expect(find.byTooltip('Aus den Favoriten nehmen'), findsWidgets);
    // Zuletzt gespielt bleibt erhalten
    expect(prefs.getString('save.lobby'), contains('Roulette'));
    expect(prefs.getString('save.lobby'), contains('fav'));

    await tester.enterText(find.byType(TextField), 'roulette');
    await tester.pump();
    expect(find.text('Gefunden'), findsOneWidget);
    expect(find.text('Casino'), findsOneWidget); // nur noch der Knopf oben, kein Bereich
    await tester.enterText(find.byType(TextField), 'gibtesnicht');
    await tester.pump();
    expect(find.text('Kein Spiel gefunden'), findsOneWidget);
  });
}
