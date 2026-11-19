// Vorschaubilder Hilfe und Lobby-Kopf. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/main.dart';
import 'package:gluckspfennig/ui/help_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> start(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  testWidgets('Lobby mit Hilfe-Knopf', (tester) async {
    await tester.runAsync(loadFonts);
    await start(tester, const Size(393, 852));
    await snap('hilfe_lobby');
  });

  testWidgets('Hilfe: Übersicht und Netzwerk aufgeklappt', (tester) async {
    await tester.runAsync(loadFonts);
    await start(tester, const Size(393, 852));
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
    await tester.pumpAndSettle();
    await snap('hilfe_uebersicht');
    await tester.tap(find.text('Im Netzwerk spielen'));
    await tester.pumpAndSettle();
    await snap('hilfe_netzwerk');
    await tester.enterText(find.byType(TextField), 'firewall');
    await tester.pumpAndSettle();
    await snap('hilfe_suche');
  });
}
