import 'package:flutter/widgets.dart';

import 'sfx.dart';
import 'wallet.dart';

/// Stellt Münzkonto und Ton im ganzen Widget-Baum bereit.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.wallet,
    required this.sfx,
    required super.child,
  });

  final Wallet wallet;
  final Sfx sfx;

  static AppScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

String formatCoins(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}
