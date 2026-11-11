import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/debug_log.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'core/sfx.dart';
import 'core/theme.dart';
import 'core/version.dart';
import 'core/wallet.dart';
import 'ui/lobby_screen.dart';

Future<void> main() async {
  // Alle Fehler landen im Protokoll (Einstellungen → Fehlersuche), die App läuft weiter
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugLog.error('flutter', details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugLog.error('plattform', error, stack);
      return true;
    };
    final prefs = await SharedPreferences.getInstance();
    debugLog.attach(prefs);
    final view = PlatformDispatcher.instance.implicitView;
    final size = view == null ? '?' : '${(view.physicalSize.width / view.devicePixelRatio).round()}×${(view.physicalSize.height / view.devicePixelRatio).round()}';
    debugLog.info('app', 'Start $appVersion auf ${defaultTargetPlatform.name}, Fenster $size');
    runApp(
      GluckspfennigApp(
        wallet: Wallet(prefs),
        sfx: Sfx(prefs),
        settings: Settings(prefs),
      ),
    );
  }, (error, stack) => debugLog.error('zone', error, stack));
}

class GluckspfennigApp extends StatelessWidget {
  const GluckspfennigApp({
    super.key,
    required this.wallet,
    required this.sfx,
    required this.settings,
  });

  final Wallet wallet;
  final Sfx sfx;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      wallet: wallet,
      sfx: sfx,
      settings: settings,
      child: MaterialApp(
        title: 'Glückspfennig',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const LobbyScreen(),
      ),
    );
  }
}
