import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'debug_log.dart';

/// Zeichnet bei eingeschalteter Fehlersuche app-weit jedes Tippen, jede Taste, jeden
/// Seitenwechsel und das Ein- und Ausblenden der App auf. So lässt sich auch in Spielen,
/// die selbst nichts protokollieren, nachvollziehen, was vor einem Fehler passiert ist.
class DebugTrace {
  DebugTrace._();

  static bool _installed = false;
  static final Map<int, (DateTime, Offset)> _down = {};
  static AppLifecycleListener? _life;

  /// Beobachter für den Navigator der App.
  static final NavigatorObserver navigatorObserver = _NavLog();

  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
    _life = AppLifecycleListener(
      onStateChange: (s) => debugLog.info('app', 'Zustand: ${s.name}'),
    );
  }

  static void _onPointer(PointerEvent e) {
    if (!debugLog.verbose) return;
    if (e is PointerDownEvent) {
      _down[e.pointer] = (DateTime.now(), e.position);
      debugLog.detail(
        'tippen',
        '${debugLog.screen}: runter #${e.pointer} ${_kind(e)} ${_pos(e.position)}${_buttons(e)} auf ${_describe(e)}',
      );
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      final d = _down.remove(e.pointer);
      final held = d == null ? '' : ' nach ${DateTime.now().difference(d.$1).inMilliseconds} ms';
      final moved = d == null ? '' : ', ${(e.position - d.$2).distance.round()} px bewegt';
      debugLog.detail(
        'tippen',
        '${debugLog.screen}: ${e is PointerCancelEvent ? 'abgebrochen' : 'hoch'} #${e.pointer} ${_pos(e.position)}$held$moved',
      );
    } else if (e is PointerScrollEvent) {
      debugLog.detail('tippen', '${debugLog.screen}: Mausrad ${_pos(e.position)} ${e.scrollDelta.dy.round()}');
    }
  }

  static String _kind(PointerEvent e) => switch (e.kind) {
        PointerDeviceKind.touch => 'Finger',
        PointerDeviceKind.mouse => 'Maus',
        PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => 'Stift',
        PointerDeviceKind.trackpad => 'Touchpad',
        _ => e.kind.name,
      };

  static String _buttons(PointerEvent e) =>
      e.kind == PointerDeviceKind.mouse && e.buttons == kSecondaryMouseButton ? ' rechts' : '';

  static String _pos(Offset p) => '(${p.dx.round()},${p.dy.round()})';

  /// Was unter dem Finger liegt: Beschriftung eines Knopfes, sonst Spielfeld oder Fläche.
  static String _describe(PointerDownEvent e) {
    try {
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, e.position, e.viewId);
      final view = WidgetsBinding.instance.platformDispatcher.views.where((v) => v.viewId == e.viewId).firstOrNull;
      final screenArea = view == null ? double.infinity : (view.physicalSize.width * view.physicalSize.height) / (view.devicePixelRatio * view.devicePixelRatio);
      var canvas = false;
      var n = 0;
      for (final entry in result.path) {
        final t = entry.target;
        if (t is! RenderBox || !t.hasSize) continue;
        if (++n > 12) break;
        if (t is RenderCustomPaint && (t.painter != null || t.foregroundPainter != null)) canvas = true;
        // Nur kleine Flächen nach Text durchsuchen, sonst landet man beim Text der ganzen Seite
        if (t.size.width * t.size.height > screenArea * 0.12) continue;
        final text = _textIn(t, 0);
        if (text != null) return '„$text“';
      }
      return canvas ? 'Spielfeld' : 'Fläche';
    } catch (_) {
      return '?';
    }
  }

  static String? _textIn(RenderObject r, int depth) {
    if (r is RenderParagraph) {
      final s = r.text.toPlainText().trim();
      if (s.isNotEmpty) {
        // Symbole aus der Icon-Schrift
        if (s.runes.length == 1 && s.runes.first >= 0xE000 && s.runes.first <= 0xF8FF) return 'Symbol';
        return s.length > 40 ? '${s.substring(0, 40)}…' : s.replaceAll('\n', ' ');
      }
    }
    if (depth >= 7) return null;
    String? found;
    r.visitChildren((c) => found ??= _textIn(c, depth + 1));
    return found;
  }

  static bool _onKey(KeyEvent e) {
    if (!debugLog.verbose || e is KeyRepeatEvent) return false;
    final k = e.logicalKey;
    final name = k.keyLabel.isNotEmpty ? k.keyLabel : (k.debugName ?? 'Taste ${k.keyId}');
    debugLog.detail('taste', '${debugLog.screen}: ${e is KeyDownEvent ? 'runter' : 'hoch'} $name');
    return false;
  }

  /// Nur für Tests: alles wieder abmelden.
  static void uninstall() {
    if (!_installed) return;
    _installed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _life?.dispose();
    _life = null;
  }
}

class _NavLog extends NavigatorObserver {
  String _name(Route<dynamic>? r) {
    if (r == null) return '–';
    final n = r.settings.name;
    if (n != null) return n;
    if (r is PopupRoute) return 'Dialog/Menü';
    if (r is PageRoute) return 'Seite';
    return r.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      debugLog.detail('seite', 'öffnet ${_name(route)} über ${_name(previousRoute)}');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      debugLog.detail('seite', 'schließt ${_name(route)}, zurück zu ${_name(previousRoute)}');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      debugLog.detail('seite', 'ersetzt ${_name(oldRoute)} durch ${_name(newRoute)}');
}
