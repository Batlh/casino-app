import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import 'slot_engine.dart';
import 'slot_games.dart';

/// Erklärtexte und Bilder zu den Slot-Regeln. Gemeinsam genutzt von Spielerklärung, Gewinnplan und
/// der Gewinnaufschlüsselung, damit überall dasselbe steht.

String _x(List<int> m) => m.map((v) => '×$v').join(', ');

/// „2-, 5- oder 20-Fache“
String _fold(List<int> v) => v.length == 1 ? '${v.first}-Fache' : '${v.take(v.length - 1).map((x) => '$x-').join(', ')} oder ${v.last}-Fache';

/// Symbolname in Anführungszeichen, damit „6 oder mehr ‚Glücksmünze‘“ grammatisch passt.
String _sym(SlotGame g, int s) => 'Symbole „${g.symbolNames[s]}“';

/// Betrag als Text, auch mit Nachkommastelle (0,5).
String _amount(num v) => v == v.roundToDouble() ? formatCoins(v.round()) : v.toStringAsFixed(2).replaceAll('.', ',').replaceAll(RegExp(r',?0+$'), '');

/// Wie Wege gezählt werden.
String waysText(SlotRules r) {
  final start = r.waysAnywhere
      ? 'Die Folge darf auf jeder Walze beginnen, sie muss nur ohne Lücke weiterlaufen. '
      : 'Die Folge beginnt immer auf der ersten Walze links und läuft ohne Lücke weiter. ';
  return 'Es gibt keine festen Linien. Ein Symbol gewinnt, wenn es auf mindestens drei nebeneinanderliegenden Walzen '
      'vorkommt, egal in welcher Reihe. $start'
      'Wie oft es auf jeder dieser Walzen liegt, wird miteinander malgenommen: Das ergibt die Zahl der Wege. '
      'Der Betrag aus dem Gewinnplan zählt für jeden Weg einmal.';
}

/// Rechenbeispiel zum Bild.
String waysExampleText(SlotRules r) =>
    'Beispiel im Bild: Das Symbol liegt auf Walze 1 zweimal, auf Walze 2 einmal plus ein Joker, auf Walze 3 einmal und '
    'auf den Walzen 4 und 5 je zweimal. Das sind 2 × 2 × 1 × 2 × 2 = 16 Wege. Zahlt das Symbol für fünf gleiche 25, '
    'gibt es 16 × 25 = 400 (bei Einsatz ${formatCoins(r.waysDivisor)}). Ein Joker zählt für jedes Symbol mit, auch für '
    'mehrere Symbole gleichzeitig, und kann so mehrere Gewinne auf einmal auslösen.';

String linesText(SlotRules r) =>
    'Es zählen nur die ${r.lineCount} Gewinnlinien. Gleiche Symbole müssen auf der ersten Walze links beginnen und ohne '
    'Lücke auf der Linie weiterlaufen. Jede Linie bekommt den gleichen Teil des Einsatzes, der Betrag aus dem Gewinnplan '
    'gilt pro Linie.';

String heightsText(SlotRules r) {
  final hs = r.heights!;
  final maxWays = math.pow(hs.reduce(math.max), r.reels).round();
  return 'Jede Walze zeigt bei jeder Drehung zufällig ${hs.first} bis ${hs.last} Symbole. Je höher die Walzen, desto mehr '
      'Wege: alle Walzen ${hs.last} hoch ergeben ${formatCoins(maxWays)} Wege, alle ${hs.first} hoch nur '
      '${formatCoins(math.pow(hs.first, r.reels).round())}.';
}

String cascadeText(SlotRules r) {
  final free = r.freeCascade.isNotEmpty ? ' In Freispielen beginnt die Leiter höher: ${_x(r.freeCascade)}.' : '';
  return 'Nach einem Gewinn verschwinden alle Symbole, die gewonnen haben. Die übrigen rutschen nach unten, von oben fallen '
      'neue nach. Gibt es wieder einen Gewinn, geht es weiter, bis nichts mehr gewinnt. Alles gehört zur selben Drehung, '
      'der Einsatz wird nur einmal bezahlt. ${r.scatterDrops ? 'Streusymbole können nachfallen und zählen mit: Was am Ende liegt, entscheidet über die Freispiele.' : 'Streusymbole bleiben liegen und fallen nie nach: Was am Anfang liegt, zählt für die Freispiele.'} '
      'Jede Stufe zählt mehr: der erste Gewinn ${r.cascade.first == 1 ? 'normal' : '×${r.cascade.first}'}, '
      'danach ${_x(r.cascade.skip(1).toList())}, ab dann bleibt es bei ×${r.cascade.last}.$free';
}

String holdText(SlotGame g, {int? stake}) {
  final h = g.rules.holdSpin!;
  final cells = g.rules.reels * g.rules.rows;
  String val(int tenths) => stake == null ? '${_amount(tenths / 10)}-facher Einsatz' : formatCoins(tenths * stake ~/ 10);
  final jackpots = [for (final e in h.jackpots.entries) '${e.value} ${val(e.key)}'].join(', ');
  return '${h.trigger} oder mehr ${_sym(g, symCoin)} auf einmal starten Hold & Spin. Jede Münze trägt einen Wert, '
      'manche einen Jackpot. Alle Münzen bleiben liegen, die übrigen Felder ($cells insgesamt) drehen neu. Du hast '
      '${h.respins} Respins. Landet in einem Respin mindestens eine neue Münze, bleibt sie liegen und die Respins stehen '
      'wieder auf ${h.respins}. Landet keine, ist einer verbraucht. Die Runde endet, wenn kein Respin mehr übrig ist oder alle '
      'Felder voll sind. Dann zählen alle Münzwerte zusammen. Jackpots: $jackpots. Sind alle $cells Felder voll, kommt der '
      'Grand dazu: ${val(h.grand)}.';
}

String wheelText(SlotGame g, {int? stake}) {
  final w = g.rules.wheel!;
  final fields = [
    for (final s in w.segments)
      switch (s.kind) {
        WheelKind.coins => stake == null ? '${s.amount}-facher Einsatz' : formatCoins(s.amount * stake),
        WheelKind.freeSpins => '${s.amount} Freispiele',
        WheelKind.holdSpin => 'Hold & Spin mit ${s.amount} Startmünzen',
      },
  ].toSet().join(', ');
  return '${w.trigger} oder mehr ${_sym(g, symBonus)} drehen das Glücksrad auf eigenem Bildschirm. Wo der Zeiger '
      'stehen bleibt, gibt es den Gewinn. Felder: $fields.';
}

String freeSpinsText(SlotGame g) {
  final r = g.rules;
  final extra = [
    if (r.freeMultiplier > 1) 'Jeder Gewinn in Freispielen zählt ×${r.freeMultiplier}.',
    if (r.expandWildInFree) 'Ein Joker auf den inneren Walzen füllt dort die ganze Walze.',
    if (r.stickyWildsInFree) 'Jeder Joker, der landet, bleibt bis zum Ende der Freispiele an seinem Platz liegen.',
    if (r.freeCascade.isNotEmpty) 'Die Kaskaden zählen mehr (siehe Kaskaden).',
  ].join(' ');
  return 'Drei oder mehr ${_sym(g, symScatter)} irgendwo auf den Walzen zahlen das ${_fold(r.scatterPays)} des '
      'Einsatzes und starten ${r.freeSpins} Freispiele. Freispiele kosten nichts, neue Symbole „${g.symbolNames[symScatter]}“ '
      'darin bringen weitere. $extra';
}

/// Spielerklärung (?-Knopf), passend zu den Regeln des Automaten.
GameGuide slotGuide(SlotGame g) {
  final r = g.rules;
  final ways = r.mode == PayMode.ways;
  return GameGuide(g.name, [
    GuideSection('So wird gewonnen', ways ? waysText(r) : linesText(r)),
    if (ways) GuideSection('Wege zählen', waysExampleText(r), picture: (_) => WaysExample(game: g)),
    if (r.heights != null) GuideSection('Wechselnde Walzen', heightsText(r)),
    GuideSection('Joker', g.wildText),
    if (r.hasScatter) GuideSection('Freispiele', freeSpinsText(g)),
    if (r.cascades) GuideSection('Kaskaden', cascadeText(r)),
    if (r.holdSpin != null) GuideSection('Hold & Spin', holdText(g)),
    if (r.wheel != null) GuideSection('Glücksrad', wheelText(g)),
    const GuideSection(
      'Einsatz und Gewinnplan',
      'Wähl unten den Einsatz pro Drehung. Der Gewinnplan zeigt die Beträge für den gewählten Einsatz. Tippst du nach einem '
          'Gewinn auf die Zeile unter den Walzen, siehst du genau, wie der Betrag zustande kommt.',
    ),
    const GuideSection(
      'Tipp',
      'Automaten sind reines Glück. Gespielt wird nur mit Spielmünzen, die keinen Geldwert haben. Geht dir das Geld aus, '
          'gibt es neue Münzen, dazu einmal am Tag den Tagesbonus in der Lobby.',
    ),
  ]);
}

/// Beispielbild: Raster mit markierten Treffern je Walze und der Rechnung darunter.
class WaysExample extends StatelessWidget {
  const WaysExample({super.key, required this.game});
  final SlotGame game;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 208,
          child: CustomPaint(painter: _WaysExamplePainter(game, p.ink)),
        ),
        const SizedBox(height: 4),
        Text('2 × 2 × 1 × 2 × 2 = 16 Wege', style: TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

class _WaysExamplePainter extends CustomPainter {
  _WaysExamplePainter(this.game, this.ink);
  final SlotGame game;
  final Color ink;

  // Treffer je Walze: Reihe → Symbol (0 = das Beispielsymbol, 6 = Joker)
  static const _hits = [
    {1: 0, 3: 0},
    {0: 6, 2: 0},
    {2: 0},
    {0: 0, 3: 0},
    {1: 0, 2: 0},
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const reels = 5;
    const rows = 4;
    final labelH = size.height * 0.16;
    final cw = size.width / reels;
    final ch = (size.height - labelH) / rows;
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFFC95C);
    for (var r = 0; r < reels; r++) {
      for (var row = 0; row < rows; row++) {
        final cell = Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(2);
        final hit = _hits[r][row];
        canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(6)), Paint()..color = hit == null ? const Color(0x22808080) : const Color(0x33FFC95C));
        if (hit != null) {
          final s = math.min(cell.width, cell.height);
          game.paintSymbol(canvas, Rect.fromCenter(center: cell.center, width: s, height: s).deflate(s * 0.06), hit == 6 ? symWild : 0);
          canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(6)), frame);
        }
      }
      final tp = TextPainter(
        text: TextSpan(text: '${_hits[r].length}', style: TextStyle(fontFamily: bodyFont, color: ink, fontWeight: FontWeight.w800, fontSize: labelH * 0.7)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r * cw + cw / 2 - tp.width / 2, size.height - labelH + (labelH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_WaysExamplePainter old) => old.game != game || old.ink != ink;
}

/// Aufschlüsselung eines Gewinns: welche Felder, wie viele Wege, welcher Betrag, welcher Multiplikator.
List<String> winBreakdown(SlotGame game, List<List<int>> grid, LineWin w, {required int stake, required int multiplier}) {
  final r = game.rules;
  final name = game.symbolNames[w.symbol];
  final lines = <String>[];
  if (w.line >= 0) {
    final lineBet = stake ~/ r.lineCount;
    final factor = w.payout ~/ (lineBet * multiplier);
    final base = r.linePays[w.symbol]?[w.count - 3] ?? factor;
    lines.add('Linie ${w.line + 1}: ${w.count} × $name ab Walze 1.');
    lines.add('Laut Gewinnplan: $base × Linieneinsatz.');
    if (factor != base) lines.add('Jeder Joker in der Linie verdoppelt: $base → $factor.');
    lines.add('Linieneinsatz: ${formatCoins(stake)} ÷ ${r.lineCount} Linien = ${formatCoins(lineBet)}.');
    lines.add('$factor × ${formatCoins(lineBet)}${multiplier > 1 ? ' × $multiplier' : ''} = ${formatCoins(w.payout)}');
    return lines;
  }
  final counts = <int>[];
  final wildsPer = <int>[];
  for (var i = w.start; i < w.start + w.count; i++) {
    counts.add(grid[i].where((s) => s == w.symbol || s == symWild).length);
    wildsPer.add(grid[i].where((s) => s == symWild).length);
  }
  lines.add('${w.count} × $name nebeneinander, Walze ${w.start + 1} bis ${w.start + w.count}.');
  for (var k = 0; k < counts.length; k++) {
    final j = wildsPer[k];
    lines.add('Walze ${w.start + k + 1}: ${counts[k]}-mal${j > 0 ? ' (davon $j Joker)' : ''}');
  }
  lines.add('Wege: ${counts.join(' × ')} = ${w.ways}');
  final pay = r.linePays[w.symbol]![w.count - 3];
  final perWay = pay * stake / r.waysDivisor;
  lines.add('Laut Gewinnplan je Weg: ${_amount(perWay)} (bei Einsatz ${formatCoins(stake)})');
  final exact = perWay * w.ways * multiplier;
  lines.add('${w.ways} × ${_amount(perWay)}${multiplier > 1 ? ' × $multiplier' : ''} = ${_amount(exact)}'
      '${exact != w.payout ? ', abgerundet ${formatCoins(w.payout)}' : ''}');
  if (multiplier > 1) lines.add('×$multiplier kommt von der Kaskade oder den Freispielen.');
  return lines;
}

/// Blatt mit der Aufschlüsselung, geöffnet durch Tippen auf die Gewinnzeile.
Future<void> showWinBreakdown(BuildContext context, SlotGame game, List<List<int>> grid, LineWin w,
    {required int stake, required int multiplier}) {
  final p = Palette.of(context);
  final text = winBreakdown(game, grid, w, stake: stake, multiplier: multiplier);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: p.panel,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('So kommt der Gewinn zustande', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 280,
                height: 280 * game.rules.rows / game.rules.reels,
                child: CustomPaint(painter: _WinGridPainter(game, grid, w)),
              ),
            ),
            const SizedBox(height: 10),
            for (final (i, line) in text.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  line,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 16,
                    fontWeight: i == text.length - 1 || line.startsWith('Wege:') ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _WinGridPainter extends CustomPainter {
  _WinGridPainter(this.game, this.grid, this.win);
  final SlotGame game;
  final List<List<int>> grid;
  final LineWin win;

  @override
  void paint(Canvas canvas, Size size) {
    final reels = grid.length;
    final cw = size.width / reels;
    game.paintBackdrop(canvas, Offset.zero & size, 0);
    final hit = win.cells.toSet();
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFC95C);
    for (var r = 0; r < reels; r++) {
      final ch = size.height / grid[r].length;
      for (var row = 0; row < grid[r].length; row++) {
        final cell = Rect.fromLTWH(r * cw, row * ch, cw, ch);
        final on = hit.contains((r, row));
        final s = math.min(cw, ch);
        canvas.saveLayer(cell, Paint()..color = Color.fromRGBO(0, 0, 0, on ? 1 : 0.35));
        game.paintSymbol(canvas, Rect.fromCenter(center: cell.center, width: s, height: s).deflate(s * 0.08), grid[r][row]);
        canvas.restore();
        if (on) canvas.drawRRect(RRect.fromRectAndRadius(cell.deflate(2), const Radius.circular(8)), frame);
      }
    }
  }

  @override
  bool shouldRepaint(_WinGridPainter old) => old.win != win || old.grid != grid;
}
