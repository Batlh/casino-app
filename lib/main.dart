import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/scope.dart';
import 'core/settings.dart';
import 'core/sfx.dart';
import 'core/theme.dart';
import 'core/wallet.dart';
import 'ui/lobby_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    GluckspfennigApp(
      wallet: Wallet(prefs),
      sfx: Sfx(prefs),
      settings: Settings(prefs),
    ),
  );
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
