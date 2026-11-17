import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Bildschirm anlassen ist aus und wird gespeichert', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    expect(settings.keepScreenOn, isFalse);
    var notified = 0;
    settings.addListener(() => notified++);
    settings.keepScreenOn = true;
    expect(notified, 1);
    expect(Settings(prefs).keepScreenOn, isTrue);
  });
}
