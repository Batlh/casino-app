import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Ein Abschnitt der Spielerklärung, wahlweise mit Bild.
class GuideSection {
  const GuideSection(this.heading, this.text, {this.picture});
  final String heading;
  final String text;
  final WidgetBuilder? picture;
}

/// Erklärung eines Spiels, auf Wunsch mit geführtem Tutorial.
class GameGuide {
  const GameGuide(this.title, this.sections, {this.tutorial, this.tutorialLabel = 'Geführtes Tutorial starten'});
  final String title;
  final List<GuideSection> sections;
  final WidgetBuilder? tutorial;
  final String tutorialLabel;
}

Future<void> showGuide(BuildContext context, GameGuide guide) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GuideScreen(guide: guide)),
    );

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guide});
  final GameGuide guide;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        title: Text('So geht ${guide.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (guide.tutorial != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.school),
                      label: Text(guide.tutorialLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: guide.tutorial!),
                      ),
                    ),
                  ),
                for (final s in guide.sections)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.panelEdge, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.heading,
                          style: TextStyle(color: p.ink, fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                        if (s.picture != null) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 380),
                              child: s.picture!(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(s.text, style: TextStyle(color: p.ink, fontSize: 16, height: 1.35)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
