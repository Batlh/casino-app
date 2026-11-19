import '../../core/debug_log.dart';
import 'slot_engine.dart';
import 'slot_games.dart';

/// Kurzform eines Symbols fürs Protokoll, z. B. „Muschel“ oder „Qualle*“ für den Joker.
String _sym(SlotGame g, int s) => s == symWild ? '${g.symbolNames[s]}*' : g.symbolNames[s];

String _gridText(SlotGame game, List<List<int>> grid) {
  final rows = grid.fold(0, (a, c) => c.length > a ? c.length : a);
  final b = StringBuffer();
  for (var row = 0; row < rows; row++) {
    b.write('\n  R${row + 1}: ${[for (final c in grid) row < c.length ? _sym(game, c[row]) : '–'].join(' | ')}');
  }
  return b.toString();
}

String _winText(SlotGame game, SlotRules rules, List<List<int>> grid, LineWin w) {
  if (w.kind == WinKind.cluster) {
    return '\n  Gruppe ${w.count} × ${game.symbolNames[w.symbol]} = ${w.payout}';
  }
  if (w.kind == WinKind.expand) {
    return '\n  Sondersymbol ${game.symbolNames[w.symbol]} auf ${w.count} Walzen, alle ${rules.lineCount} Linien = ${w.payout}';
  }
  final wilds = [for (final (r, row) in w.cells) if (grid[r][row] == symWild) 1].length;
  final head = w.line >= 0
      ? 'Linie ${w.line + 1} (${rules.lines[w.line].map((row) => row + 1).join('-')})'
      : 'Wege ab Walze ${w.start + 1}';
  final b = StringBuffer('\n  $head: ${w.count} × ${game.symbolNames[w.symbol]}');
  if (w.line < 0) b.write(', ${w.ways} ${w.ways == 1 ? 'Weg' : 'Wege'}');
  if (wilds > 0 && w.symbol != symWild) b.write(' mit $wilds Joker');
  b.write(' = ${w.payout}');
  return b.toString();
}

/// Eine vollständige Drehung (mit Kaskaden, Hold & Spin, Glücksrad) als Text.
String describeSlotOutcome(SlotGame game, SpinOutcome o, {required int stake, required bool free, int? balance}) {
  final rules = game.rules;
  final b = StringBuffer('${game.name} ${free ? 'Freispiel' : 'Einsatz $stake'}');
  if (rules.mode == PayMode.lines) {
    b.write(' · ${rules.lineCount} Linien à ${stake ~/ rules.lineCount}');
  } else if (rules.mode == PayMode.cluster) {
    b.write(' · Gruppen ab ${rules.clusterMin}');
  } else {
    b.write(' · Wege${rules.waysAnywhere ? ' überall' : ''}');
  }
  if (rules.heights != null) b.write(' · Höhen ${o.heights.join('/')}');
  if (o.stops.isNotEmpty) b.write(' · Stopps ${o.stops.join('/')}');
  b.write(' · Gewinn ${o.total}');
  if (balance != null) b.write(' · Stand $balance');
  for (var i = 0; i < o.steps.length; i++) {
    final s = o.steps[i];
    if (s.respin) {
      b.write('\n  Nachdrehung (wandernde Joker):');
    } else if (s.expanded) {
      b.write('\n  Ausgebreitet:');
    } else if (i > 0) {
      b.write('\n  Kaskade ${i + 1} ×${s.multiplier}:');
    }
    b.write(_gridText(game, s.grid));
    if (s.giant != null) b.write('\n  Riesensymbol ${s.giant!.$3} × ${s.giant!.$3} ab Walze ${s.giant!.$1 + 1}');
    if (i == 0 && o.coins.isNotEmpty) {
      b.write('\n  Münzen: ${[for (final v in o.coins.values) coinText(rules, v, stake)].join(', ')}');
    }
    for (final w in s.wins) {
      b.write(_winText(game, rules, s.grid, w));
    }
  }
  if (o.scatterCount >= 3) {
    b.write('\n  ${o.scatterCount} × ${game.symbolNames[symScatter]} = ${o.scatterWin}');
  }
  final wheel = o.wheel;
  if (wheel != null) b.write('\n  Glücksrad: ${wheel.segment.label}${wheel.win > 0 ? ' = ${wheel.win}' : ''}');
  if (o.freeSpinsWon > 0) b.write('\n  ${o.freeSpinsWon} Freispiele');
  if (o.expandSymbol != null) b.write('\n  Sondersymbol ${game.symbolNames[o.expandSymbol!]}');
  final h = o.holdSpin;
  if (h != null) {
    b.write('\n  Hold & Spin: ${h.boards.first.length} Startmünzen, ${h.boards.length - 1} Respins, '
        '${h.boards.last.length} Münzen${h.full ? ', GRAND' : ''} = ${h.total}');
  }
  return b.toString();
}

/// Münzwert als Text: Jackpot-Name oder Betrag.
String coinText(SlotRules rules, int tenths, int stake) {
  final j = rules.holdSpin?.jackpots[tenths];
  final v = tenths * stake ~/ 10;
  return j == null ? '$v' : '$j $v';
}

void logSlotOutcome(SlotGame game, SpinOutcome o, {required int stake, required bool free, int? balance}) =>
    debugLog.info('slots', describeSlotOutcome(game, o, stake: stake, free: free, balance: balance));
