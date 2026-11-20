import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/ui/net_chat.dart';

void main() {
  test('Nur gültige Nummern ergeben Text', () {
    expect(quickMessageText(0), quickMessages.first);
    expect(quickMessageText(quickMessages.length), isNull);
    expect(quickMessageText(-1), isNull);
    expect(quickMessageText('x'), isNull);
    expect(quickMessageText(null), isNull);
  });

  testWidgets('Knopf zeigt die Sätze, Nachricht erscheint unten', (tester) async {
    int? sent;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(actions: [
            quickChatButton((i) {
              sent = i;
              showQuickMessage(context, 'Anna', i);
            }),
          ]),
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gut gespielt!'));
    await tester.pumpAndSettle();
    expect(sent, quickMessages.indexOf('Gut gespielt!'));
    expect(find.text('Anna: Gut gespielt!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
