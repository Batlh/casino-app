import 'package:flutter/material.dart';

/// Farben der Spielhalle. Dunkel: Teakholz bei Nacht. Hell: Senftapete.
@immutable
class Palette {
  const Palette({
    required this.bg,
    required this.panel,
    required this.panelEdge,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.felt,
    required this.feltEdge,
    required this.onFelt,
  });

  final Color bg;
  final Color panel;
  final Color panelEdge;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color felt;
  final Color feltEdge;
  final Color onFelt;

  static const dark = Palette(
    bg: Color(0xFF1E120D),
    panel: Color(0xFF3A2116),
    panelEdge: Color(0xFF6B3E1E),
    ink: Color(0xFFF6E7C8),
    inkSoft: Color(0xFFCDB48C),
    accent: Color(0xFFF2A33A),
    onAccent: Color(0xFF2A160E),
    danger: Color(0xFFEE6A4D),
    felt: Color(0xFF0F5B4A),
    feltEdge: Color(0xFF0A3F34),
    onFelt: Color(0xFFF6E7C8),
  );

  static const light = Palette(
    bg: Color(0xFFF4C24D),
    panel: Color(0xFFFFF1C9),
    panelEdge: Color(0xFFB9772A),
    ink: Color(0xFF2A160E),
    inkSoft: Color(0xFF6A4326),
    accent: Color(0xFFC4391F),
    onAccent: Color(0xFFFFF1C9),
    danger: Color(0xFFA82A13),
    felt: Color(0xFF1B7A63),
    feltEdge: Color(0xFF115443),
    onFelt: Color(0xFFFFF7E2),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const String displayFont = 'Shrikhand';
const String bodyFont = 'Barlow';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
  ).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.panel,
    onSurface: p.ink,
    error: p.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: bodyFont,
    // Schriftzeichen für Shogi und Mahjong
    fontFamilyFallback: const ['Kanji'],
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: p.accent,
        selectedForegroundColor: p.onAccent,
        foregroundColor: p.ink,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(
        color: p.bg,
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontFamily: displayFont, color: p.ink),
      titleLarge: TextStyle(fontFamily: displayFont, color: p.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
      bodySmall: TextStyle(fontWeight: FontWeight.w500, color: p.inkSoft),
      labelLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );
}
