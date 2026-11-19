// Vorschaubilder: Entchen in Schwimmrichtung, Glücksrad beim schnellen Drehen. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/ente/ente_screen.dart';
import 'package:gluckspfennig/games/gluecksrad/gluecksrad_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  testWidgets('Entchen schauen in Schwimmrichtung', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const EntenScreen(seed: 1));
    await snap('bewegung_enten_1');
    await tester.pump(const Duration(seconds: 5));
    await snap('bewegung_enten_2');
  });

  testWidgets('Glücksrad verschwimmt beim schnellen Drehen', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const GluecksradScreen(seed: 3));
    await tester.tap(find.text('Joker').first);
    await tester.pump();
    await tester.tap(find.text('Drehen'));
    await tester.pump(const Duration(milliseconds: 400));
    await snap('bewegung_rad_schnell');
    await tester.pump(const Duration(milliseconds: 2400));
    await snap('bewegung_rad_mittel');
    await tester.pump(const Duration(seconds: 3));
    await snap('bewegung_rad_steht');
  });
}
