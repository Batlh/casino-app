// Gewinnplan von Tiefsee mit den Linienbildern, zur Sichtprüfung. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  testWidgets('Gewinnplan Tiefsee', (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump();
    showSlotPayTable(tester.element(find.byType(Navigator).first), tiefsee, 100);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/gewinnplan_tiefsee.png'));
  });
}
