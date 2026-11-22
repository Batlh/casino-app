import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/backup.dart';
import 'core/debug_log.dart';
import 'core/debug_trace.dart';
import 'core/licenses.dart';
import 'core/progress.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'core/sfx.dart';
import 'core/theme.dart';
import 'core/umzug.dart';
import 'core/version.dart';
import 'core/wallet.dart';
import 'ui/lobby_screen.dart';

Future<void> main() async {
  // Alle Fehler landen im Protokoll (Einstellungen → Fehlersuche), die App läuft weiter
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    registerFontLicenses();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugLog.error('flutter', details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugLog.error('plattform', error, stack);
      return true;
    };
    // Umzug auf den neuen Paketnamen: am PC alte Daten übernehmen, bevor sie geladen werden
    final moved = await moveDesktopData();
    final prefs = await SharedPreferences.getInstance();
    // Ganz neu installiert (nichts außer dem Fehlerprotokoll gespeichert)? Dann bietet die Lobby an, eine Sicherung zu laden.
    freshInstall = prefs.getKeys().every((k) => k.startsWith('debug.'));
    debugLog.attach(prefs);
    if (!kIsWeb) {
      try {
        final dir = await getApplicationSupportDirectory();
        debugLog.attachFile(Directory('${dir.path}${Platform.pathSeparator}fehlersuche'));
      } catch (e, st) {
        debugLog.error('protokoll.datei', e, st);
      }
    }
    DebugTrace.install();
    if (moved != null) debugLog.info('umzug', 'Alte Daten übernommen aus $moved');
    final view = PlatformDispatcher.instance.implicitView;
    final size = view == null ? '?' : '${(view.physicalSize.width / view.devicePixelRatio).round()}×${(view.physicalSize.height / view.devicePixelRatio).round()}';
    debugLog.info('app', 'Start $appVersion auf ${defaultTargetPlatform.name}, Fenster $size');
    runApp(_Root(prefs));
  }, (error, stack) => debugLog.error('zone', error, stack));
}

class _Root extends StatefulWidget {
  const _Root(this.prefs);
  final SharedPreferences prefs;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late Wallet _wallet;
  late Sfx _sfx;
  late Settings _settings;
  Key _key = UniqueKey();

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    // Beim Zurückkehren in die App die Einstellung erneut anwenden, beim Verlassen freigeben.
    _lifecycle = AppLifecycleListener(
      onResume: _applyScreen,
      onHide: () => _setScreen(false),
    );
    restartApp = () => setState(() {
          _settings.removeListener(_applyScreen);
          _load();
          _key = UniqueKey();
          debugLog.info('app', 'Neu geladen nach Spielstand-Import');
        });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _settings.removeListener(_applyScreen);
    super.dispose();
  }

  void _load() {
    _wallet = Wallet(widget.prefs);
    progress.attach(widget.prefs, _wallet);
    _sfx = Sfx(widget.prefs);
    _settings = Settings(widget.prefs);
    _settings.addListener(_applyScreen);
    _applyScreen();
  }

  bool? _screenOn;

  void _applyScreen() => _setScreen(_settings.keepScreenOn);

  /// Hält den Bildschirm an oder gibt ihn frei. Fehler (z. B. ohne Unterstützung auf dem System) nur protokollieren.
  Future<void> _setScreen(bool on) async {
    if (_screenOn == on) return;
    _screenOn = on;
    try {
      await WakelockPlus.toggle(enable: on);
      debugLog.info('app', on ? 'Bildschirm bleibt an' : 'Bildschirm darf aus');
    } catch (e, st) {
      debugLog.error('bildschirm', e, st);
    }
  }

  @override
  Widget build(BuildContext context) => GluckspfennigApp(key: _key, wallet: _wallet, sfx: _sfx, settings: _settings);
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
        navigatorObservers: [DebugTrace.navigatorObserver],
        home: const LobbyScreen(),
      ),
    );
  }
}
