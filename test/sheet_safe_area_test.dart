import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/ui/settings_sheet.dart';

import 'widget_test.dart' show pumpApp;

void main() {
  testWidgets('Einstellungen beginnen unter der Kamera-Aussparung', (tester) async {
    // Handy mit 40 px Statusleiste/Notch oben
    tester.view.padding = const FakeViewPadding(top: 40);
    addTearDown(tester.view.resetPadding);
    await pumpApp(tester, const Size(393, 852));
    final context = tester.element(find.byType(Navigator).first);
    showSettingsSheet(context);
    // Die Lobby ist dauerhaft animiert, deshalb feste Zeit statt pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final top = tester.getTopLeft(find.byType(BottomSheet)).dy;
    expect(top, greaterThanOrEqualTo(40));
    expect(tester.takeException(), isNull);
  });
}
