import 'klondike_engine.dart';
import 'spider_engine.dart';
import 'table_card.dart';

/// Ein Tipp: entweder ein Zug von einem Stapel auf einen anderen oder
/// Karten vom Stapel ziehen beziehungsweise neu austeilen.
class SolitaireHint {
  const SolitaireHint.move(PileRef this.from, this.index, PileRef this.to) : draw = false;
  const SolitaireHint.draw()
      : from = null,
        index = 0,
        to = null,
        draw = true;

  final PileRef? from;
  final int index;
  final PileRef? to;
  final bool draw;
}

/// Ein Sieg kostet je Tipp ein Zehntel der Prämie.
int hintCost(int reward) => reward ~/ 10;

bool _fitsFoundation(KlondikeEngine e, TableCard c) {
  for (final f in e.foundations) {
    if (f.isEmpty ? c.rank == 1 : f.last.suit == c.suit && f.last.rank + 1 == c.rank) return true;
  }
  return false;
}

/// Sucht den nützlichsten Zug in der Patience. Ohne sinnvollen Zug kommt das
/// Ziehen vom Stapel, sonst null.
SolitaireHint? klondikeHint(KlondikeEngine e, {bool allowDraw = true}) {
  SolitaireHint? best;
  var bestScore = 0;
  void consider(PileRef from, int index, PileRef to, int score) {
    if (score > bestScore && e.canDrop(from, index, to)) {
      best = SolitaireHint.move(from, index, to);
      bestScore = score;
    }
  }

  final sources = <(PileRef, int)>[
    if (e.waste.isNotEmpty) (const PileRef(PileKind.waste), e.waste.length - 1),
    for (var t = 0; t < 7; t++)
      for (var i = 0; i < e.tableau[t].length; i++)
        if (e.tableau[t][i].up) (PileRef(PileKind.tableau, t), i),
  ];
  for (final (from, i) in sources) {
    final src = e.pile(from);
    final onTableau = from.kind == PileKind.tableau;
    final reveals = onTableau && i > 0 && !src[i - 1].up;
    if (i == src.length - 1) {
      for (var f = 0; f < 4; f++) {
        consider(from, i, PileRef(PileKind.foundation, f), 100 + (reveals ? 20 : 0));
      }
    }
    for (var t = 0; t < 7; t++) {
      final to = PileRef(PileKind.tableau, t);
      if (to == from) continue;
      final targetEmpty = e.tableau[t].isEmpty;
      int score;
      if (!onTableau) {
        score = 40;
      } else if (reveals) {
        score = 80;
      } else if (i == 0) {
        // Macht eine Spalte frei, aber nur auf eine belegte Spalte
        score = targetEmpty ? 0 : 30;
      } else {
        // Teilreihe umziehen lohnt nur, wenn die Karte darunter dann auf die Ablage kann
        score = !targetEmpty && _fitsFoundation(e, src[i - 1]) ? 70 : 0;
      }
      consider(from, i, to, score);
    }
  }
  if (best == null && allowDraw && e.canDraw) return const SolitaireHint.draw();
  return best;
}

/// Karten aus Stapel und Ablage, die durch Ziehen irgendwann oben liegen.
List<TableCard> klondikeReachable(KlondikeEngine e) {
  final order = [...e.waste, ...e.stock.reversed];
  if (e.drawCount == 1) return order;
  final out = <TableCard>{};
  if (e.waste.isNotEmpty) out.add(e.waste.last);
  // Rest der laufenden Runde
  for (var i = e.waste.length + 2; i < order.length; i += 3) {
    out.add(order[i]);
  }
  if (order.isNotEmpty) out.add(order.last);
  // Alle folgenden Runden beginnen von vorn
  for (var i = 2; i < order.length; i += 3) {
    out.add(order[i]);
  }
  return out.toList();
}

bool _fitsOn(TableCard c, List<TableCard> col) =>
    col.isEmpty ? c.rank == 13 : col.last.up && col.last.red != c.red && col.last.rank == c.rank + 1;

/// Kein Zug bringt die Patience noch weiter: verloren.
bool klondikeStuck(KlondikeEngine e) {
  if (e.isWon) return false;
  final reach = klondikeReachable(e);
  for (final c in reach) {
    if (_fitsFoundation(e, c)) return false;
    if (e.tableau.any((col) => _fitsOn(c, col))) return false;
  }
  for (var t = 0; t < 7; t++) {
    final col = e.tableau[t];
    if (col.isNotEmpty && col.last.up && _fitsFoundation(e, col.last)) return false;
    for (var i = 0; i < col.length; i++) {
      if (!col[i].up) continue;
      for (var u = 0; u < 7; u++) {
        if (u == t || !e.canDrop(PileRef(PileKind.tableau, t), i, PileRef(PileKind.tableau, u))) continue;
        // Ein König ganz unten wechselt nur die leere Spalte
        if (i == 0 && col[i].rank == 13) continue;
        if (i == 0 || !col[i - 1].up) return false;
        // Teilreihe umziehen hilft nur, wenn die freigelegte Karte etwas aufnehmen kann
        final exposed = col[i - 1];
        if (_fitsFoundation(e, exposed)) return false;
        if (reach.any((c) => c.red != exposed.red && c.rank + 1 == exposed.rank)) return false;
      }
    }
  }
  return true;
}

/// Kein sinnvoller Zug und kein Austeilen mehr: verloren.
bool spiderStuck(SpiderEngine e) {
  if (e.isWon || e.canDeal) return false;
  for (var from = 0; from < 10; from++) {
    final col = e.tableau[from];
    for (var i = 0; i < col.length; i++) {
      if (!e.canPick(from, i)) continue;
      final first = col[i];
      final sitsOnFit = i > 0 && col[i - 1].up && col[i - 1].rank == first.rank + 1;
      for (var to = 0; to < 10; to++) {
        if (!e.canDrop(from, i, to)) continue;
        final target = e.tableau[to];
        if (target.isEmpty) {
          if (i > 0) return false;
          continue;
        }
        final same = target.last.suit == first.suit;
        if (sitsOnFit && (!same || col[i - 1].suit == first.suit)) continue;
        return false;
      }
    }
  }
  return true;
}

/// Sucht den nützlichsten Zug in Spider. Ohne sinnvollen Zug kommt das
/// Austeilen, sonst null.
SolitaireHint? spiderHint(SpiderEngine e) {
  SolitaireHint? best;
  var bestScore = 0;
  for (var from = 0; from < 10; from++) {
    final col = e.tableau[from];
    for (var i = 0; i < col.length; i++) {
      if (!e.canPick(from, i)) continue;
      final first = col[i];
      final reveals = i > 0 && !col[i - 1].up;
      final sitsOnFit = i > 0 && col[i - 1].up && col[i - 1].rank == first.rank + 1;
      final sameSuitBelow = sitsOnFit && col[i - 1].suit == first.suit;
      for (var to = 0; to < 10; to++) {
        if (!e.canDrop(from, i, to)) continue;
        final target = e.tableau[to];
        int score;
        if (target.isEmpty) {
          score = reveals ? 35 : 0;
        } else {
          final same = target.last.suit == first.suit;
          if (sameSuitBelow || (sitsOnFit && !same)) {
            score = 0;
          } else {
            // Eine ganze Spalte nur auf die gleiche Farbe, sonst läuft es im Kreis
            score = i == 0 && !same ? 0 : (same ? 50 : 10) + (reveals ? 40 : 0) + (i == 0 ? 20 : 0) + (col.length - i);
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = SolitaireHint.move(PileRef(PileKind.tableau, from), i, PileRef(PileKind.tableau, to));
        }
      }
    }
  }
  if (best != null) return best;
  if (e.canDeal) return const SolitaireHint.draw();
  // Vor dem Austeilen muss jede Spalte belegt sein
  if (e.stock.isNotEmpty) {
    for (var to = 0; to < 10; to++) {
      if (e.tableau[to].isNotEmpty) continue;
      for (var from = 0; from < 10; from++) {
        final col = e.tableau[from];
        for (var i = 1; i < col.length; i++) {
          final below = col[i - 1];
          final perfect = below.up && below.suit == col[i].suit && below.rank == col[i].rank + 1;
          if (!perfect && e.canDrop(from, i, to)) {
            return SolitaireHint.move(PileRef(PileKind.tableau, from), i, PileRef(PileKind.tableau, to));
          }
        }
      }
    }
  }
  return null;
}

/// Beschreibung eines Zugs, z. B. „Herz 7 auf Pik 8“.
String describeHint(SolitaireHint h, List<TableCard> Function(PileRef) pile) {
  final src = pile(h.from!);
  final card = src[h.index];
  final run = src.length - h.index > 1 ? ' samt Reihe' : '';
  final target = pile(h.to!);
  final where = switch (h.to!.kind) {
    PileKind.foundation => 'nach oben auf die Ablage',
    _ when target.isEmpty => 'in die leere Spalte',
    _ => 'auf ${target.last.card.spokenName}',
  };
  return '${card.card.spokenName}$run $where';
}
