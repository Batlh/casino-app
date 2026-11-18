import '../../core/debug_log.dart';
import 'slot_engine.dart';
import 'slot_games.dart';

/// Kurzform eines Symbols fürs Protokoll, z. B. „Muschel“ oder „Qualle*“ für den Joker.
String _sym(SlotGame g, int s) => s == symWild ? '${g.symbolNames[s]}*' : g.symbolNames[s];

/// Eine Drehung als Text: Kopfzeile, Raster Reihe für Reihe, dann jede Gewinnlinie.
String describeSlotSpin(SlotGame game, SpinResult r, {required int stake, required bool free, int? balance}) {
  final rules = game.rules;
  final b = StringBuffer()
    ..write('${game.name} ${free ? 'Freispiel' : 'Einsatz $stake'}')
    ..write(' · ${rules.lineCount} Linien à ${stake ~/ rules.lineCount}');
  if (r.stops.isNotEmpty) b.write(' · Stopps ${r.stops.join('/')}');
  b.write(' · Gewinn ${r.total}');
  if (balance != null) b.write(' · Stand $balance');
  for (var row = 0; row < rules.rows; row++) {
    b.write('\n  R${row + 1}: ${[for (var reel = 0; reel < rules.reels; reel++) _sym(game, r.grid[reel][row])].join(' | ')}');
  }
  for (final w in r.lineWins) {
    final path = rules.lines[w.line].map((row) => row + 1).join('-');
    final wilds = [
      for (var reel = 0; reel < w.count; reel++)
        if (r.grid[reel][rules.lines[w.line][reel]] == symWild) reel,
    ].length;
    b.write('\n  Linie ${w.line + 1} ($path): ${w.count} × ${game.symbolNames[w.symbol]}');
    if (wilds > 0 && w.symbol != symWild) b.write(' mit $wilds Joker');
    b.write(' = ${w.payout}');
  }
  if (r.scatterCount >= 3) {
    b.write('\n  ${r.scatterCount} × ${game.symbolNames[symScatter]} = ${r.scatterWin}');
    if (r.freeSpinsWon > 0) b.write(', ${r.freeSpinsWon} Freispiele');
  }
  return b.toString();
}

/// Schreibt die Drehung ins Fehlerprotokoll (Bereich „slots“).
void logSlotSpin(SlotGame game, SpinResult r, {required int stake, required bool free, int? balance}) =>
    debugLog.info('slots', describeSlotSpin(game, r, stake: stake, free: free, balance: balance));
