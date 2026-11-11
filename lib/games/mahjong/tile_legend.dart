import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'tiles.dart';

/// Knopf für die Kopfzeile aller Mahjong-Spiele: öffnet die Steinkunde.
class TileLegendButton extends StatelessWidget {
  const TileLegendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Welcher Stein ist welcher?',
      icon: Icon(Icons.view_module_outlined, color: p.ink),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TileLegendScreen())),
    );
  }
}

/// Übersicht aller Steine mit Namen, für alle, die die Zeichen nicht lesen können.
class TileLegendScreen extends StatelessWidget {
  const TileLegendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final settings = AppScope.of(context).settings;
    final text = TextStyle(color: p.onFelt, fontSize: 15);
    final head = TextStyle(color: p.onFelt, fontSize: 19, fontWeight: FontWeight.w800);

    Widget tiles(List<(int, String)> items, {double w = 46}) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (t, label) in items)
              SizedBox(
                width: w + 30,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TileView(tile: t, width: w),
                    const SizedBox(height: 3),
                    Text(label, textAlign: TextAlign.center, style: text.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        );

    Widget section(String title, String explain, Widget body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: head),
              const SizedBox(height: 4),
              Text(explain, style: text),
              const SizedBox(height: 8),
              body,
            ],
          ),
        );

    const numerals = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return GameFrame(
      title: 'Welcher Stein ist welcher?',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Hilfszahlen auf allen Steinen zeigen', style: text.copyWith(fontWeight: FontWeight.w800)),
              subtitle: Text('Kleine Zahl bzw. Richtung unten rechts auf jedem Stein, in allen Mahjong-Spielen.', style: text.copyWith(fontSize: 13)),
              value: settings.mahjongHints,
              onChanged: (v) => settings.mahjongHints = v,
            ),
          ),
          const SizedBox(height: 8),
          section(
            'Die drei Farben',
            'Es gibt drei Farben mit den Zahlen 1 bis 9. Nur innerhalb einer Farbe bilden Steine Folgen wie 3-4-5.',
            const SizedBox.shrink(),
          ),
          section(
            'Zeichen (Wan)',
            'Oben steht die Zahl als chinesisches Schriftzeichen, unten das rote 萬 (heißt „zehntausend“ und zeigt nur die Farbe). '
                'Die Zahlzeichen: ${[for (var i = 0; i < 9; i++) '${numerals[i]} = ${i + 1}'].join(', ')}. '
                'Merkhilfe: 一 二 三 sind einfach 1, 2 und 3 Striche.',
            tiles([for (var i = 0; i < 9; i++) (i, '${i + 1} · ${numerals[i]}')]),
          ),
          section(
            'Kreise (Pin)',
            'So viele Kreise, wie die Zahl sagt. Die 1 ist ein großer Kreis.',
            tiles([for (var i = 0; i < 9; i++) (9 + i, '${i + 1} Kreise')]),
          ),
          section(
            'Bambus (Sou)',
            'So viele grüne Stäbchen, wie die Zahl sagt. Achtung: Die 1 Bambus zeigt einen Vogel statt eines Stäbchens.',
            tiles([for (var i = 0; i < 9; i++) (18 + i, '${i + 1} Bambus')]),
          ),
          section(
            'Winde',
            'Vier Himmelsrichtungen. Jeder Spieler hat einen Sitzwind; Pungs aus dem eigenen Wind sind meist etwas wert.',
            tiles([(27, 'Ost · 東'), (28, 'Süd · 南'), (29, 'West · 西'), (30, 'Nord · 北')]),
          ),
          section(
            'Drachen',
            'Drei Drachen: Weiß ist ein leerer Rahmen, Grün das grüne 發, Rot das rote 中.',
            tiles([(31, 'Weiß'), (32, 'Grün · 發'), (33, 'Rot · 中')]),
          ),
          section(
            'Blumen und Jahreszeiten',
            'Bonussteine: Sie kommen nicht in die Hand, sondern werden offen hingelegt; dafür ziehst du Ersatz. '
                'Die kleine Zahl 1 bis 4 gehört zu Ost, Süd, West und Nord.',
            tiles([for (var i = 0; i < 4; i++) (34 + i, 'Blume ${i + 1}'), for (var i = 0; i < 4; i++) (38 + i, 'Jahreszeit ${i + 1}')]),
          ),
          section(
            'Tiere und Joker',
            'Nur in manchen Varianten: Tiere (Singapur) sind Bonussteine wie Blumen. Joker (Vietnam, American) ersetzen beliebige Steine.',
            tiles([for (var i = 0; i < 4; i++) (42 + i, animalNames[i]), (jokerKind, 'Joker')]),
          ),
          section(
            'Begriffe',
            'Folge (Chi): drei aufeinanderfolgende Zahlen einer Farbe, z. B. 4-5-6 Kreise. '
                'Pung: drei gleiche Steine. Kan: vier gleiche. Paar: zwei gleiche. '
                'Enden: die 1 und die 9 jeder Farbe. Ehrensteine: Winde und Drachen.',
            const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
