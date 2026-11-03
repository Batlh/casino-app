import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/scope.dart';
import 'core/sfx.dart';
import 'core/theme.dart';
import 'core/wallet.dart';
import 'ui/lobby_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs)));
}

class GluckspfennigApp extends StatelessWidget {
  const GluckspfennigApp({super.key, required this.wallet, required this.sfx});

  final Wallet wallet;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      wallet: wallet,
      sfx: sfx,
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
