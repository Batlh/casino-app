import 'package:flutter/material.dart';

import '../core/progress.dart';
import '../core/scope.dart';
import '../core/sfx.dart';
import '../core/theme.dart';

/// Tagesaufgaben, Erfolge und Statistik.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    progress.addListener(_changed);
  }

  @override
  void dispose() {
    progress.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.bg,
          foregroundColor: p.ink,
          title: const Text('Erfolge und Aufgaben'),
          bottom: TabBar(
            labelColor: p.ink,
            unselectedLabelColor: p.inkSoft,
            indicatorColor: p.accent,
            tabs: const [Tab(text: 'Aufgaben'), Tab(text: 'Erfolge'), Tab(text: 'Statistik')],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: const TabBarView(children: [_Daily(), _Achievements(), _Stats()]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Daily extends StatelessWidget {
  const _Daily();

  @override
  // Eigene Aktualisierung: Die Tabs stehen als const in der TabBarView und würden
  // beim Neuzeichnen des Bildschirms sonst übersprungen (Abholen-Knopf blieb stehen).
  Widget build(BuildContext context) => ListenableBuilder(listenable: progress, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final p = Palette.of(context);
    final d = progress.daily;
    final done = d.tasks.where((t) => d.claimed.contains(t.key)).length;
    final w = progress.weekly;
    final weekDone = w.tasks.where((t) => w.claimed.contains(t.key)).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Drei Aufgaben für heute. Jede bringt Münzen, alle drei zusammen noch ${formatCoins(dailyAllBonus)} extra. '
            'Morgen gibt es neue.', style: TextStyle(color: p.inkSoft, fontSize: 15)),
        const SizedBox(height: 12),
        for (final t in d.tasks) _TaskCard(task: t),
        const SizedBox(height: 8),
        Text(
          d.allBonus ? 'Alle Aufgaben erledigt, Extra abgeholt.' : '$done von ${d.tasks.length} abgeholt',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 28),
        Text('Diese Woche', style: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Drei Aufgaben bis Sonntag. Alle drei zusammen bringen noch ${formatCoins(weeklyAllBonus)} extra. '
            'Ab Montag gibt es neue.', style: TextStyle(color: p.inkSoft, fontSize: 15)),
        const SizedBox(height: 12),
        for (final t in w.tasks) _TaskCard(task: t),
        const SizedBox(height: 8),
        Text(
          w.allBonus ? 'Alle Wochenaufgaben erledigt, Extra abgeholt.' : '$weekDone von ${w.tasks.length} abgeholt',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final DailyTask task;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final have = progress.dailyProgress(task);
    final done = progress.dailyDone(task);
    final claimed = progress.claimed(task);
    return Card(
      color: p.panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: done ? p.accent : p.panelEdge, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(claimed ? Icons.check_circle : Icons.flag_outlined, color: done ? p.accent : p.inkSoft),
              const SizedBox(width: 10),
              Expanded(child: Text(task.text, style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700))),
              Text('+${formatCoins(task.reward)}', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: have / task.goal, minHeight: 8, color: p.accent, backgroundColor: p.bg),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text(task.goal >= 100 ? '${formatCoins(have)} / ${formatCoins(task.goal)}' : '$have / ${task.goal}',
                  style: TextStyle(color: p.inkSoft)),
              const Spacer(),
              if (claimed)
                Text('Abgeholt', style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w700))
              else
                FilledButton(
                  onPressed: done
                      ? () {
                          final weekly = progress.weekly.tasks.contains(task);
                          final coins = progress.claimDaily(task);
                          if (coins > 0) {
                            final bonus = progress.lastClaimBonus;
                            AppScope.of(context).sfx.play(Sound.coin);
                            final text = bonus > 0
                                ? '+${formatCoins(coins - bonus)} Münzen · +${formatCoins(bonus)} für alle ${weekly ? 'Wochenaufgaben' : 'Tagesaufgaben'}'
                                : '+${formatCoins(coins)} Münzen';
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
                          }
                        }
                      : null,
                  child: const Text('Abholen'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements();

  @override
  // Eigene Aktualisierung: Die Tabs stehen als const in der TabBarView und würden
  // beim Neuzeichnen des Bildschirms sonst übersprungen (Abholen-Knopf blieb stehen).
  Widget build(BuildContext context) => ListenableBuilder(listenable: progress, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final p = Palette.of(context);
    final got = achievements.where((a) => progress.unlocked.containsKey(a.id)).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('$got von ${achievements.length} Erfolgen', style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 10),
        for (final a in achievements) _AchievementTile(a: a),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.a});
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final date = progress.unlocked[a.id];
    final have = progress.progressOf(a);
    return Card(
      color: p.panel,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: date != null ? p.accent : p.panelEdge, width: 2)),
      child: ListTile(
        leading: Icon(date != null ? Icons.emoji_events : Icons.lock_outline, color: date != null ? const Color(0xFFFFC95C) : p.inkSoft, size: 32),
        title: Text(a.title, style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
        subtitle: Text(
          date != null ? '${a.text} · geschafft am ${_german(date)}' : (a.goal > 1 ? '${a.text} · ${_amount(have)} / ${_amount(a.goal)}' : a.text),
          style: TextStyle(color: p.inkSoft),
        ),
      ),
    );
  }

  static String _amount(int v) => v >= 1000 ? formatCoins(v) : '$v';
  static String _german(String iso) {
    final x = iso.split('-');
    return x.length == 3 ? '${x[2]}.${x[1]}.${x[0]}' : iso;
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  // Eigene Aktualisierung: Die Tabs stehen als const in der TabBarView und würden
  // beim Neuzeichnen des Bildschirms sonst übersprungen (Abholen-Knopf blieb stehen).
  Widget build(BuildContext context) => ListenableBuilder(listenable: progress, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final p = Palette.of(context);
    final list = progress.stats.entries.toList()..sort((a, b) => b.value.rounds.compareTo(a.value.rounds));
    if (list.isEmpty) {
      return Center(child: Text('Noch nichts gespielt', style: TextStyle(color: p.inkSoft, fontSize: 17)));
    }
    final staked = list.fold(0, (a, e) => a + e.value.staked);
    final paid = list.fold(0, (a, e) => a + e.value.paid);
    TextStyle head = TextStyle(color: p.inkSoft, fontWeight: FontWeight.w700, fontSize: 13);
    TextStyle cell = TextStyle(color: p.ink, fontSize: 15);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 18, runSpacing: 6, children: [
          _Fact('Spiele', '${progress.gamesPlayed}'),
          _Fact('Einsätze', formatCoins(progress.counters['runden'] ?? 0)),
          _Fact('Gesetzt', formatCoins(staked)),
          _Fact('Ausgezahlt', formatCoins(paid)),
          _Fact('Größter Gewinn', formatCoins(progress.counters['bester'] ?? 0)),
        ]),
        const SizedBox(height: 14),
        Table(
          columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(), 2: FlexColumnWidth(1.3), 3: FlexColumnWidth(1.3)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              Text('Spiel', style: head),
              Text('Einsätze', style: head, textAlign: TextAlign.right),
              Text('Bilanz', style: head, textAlign: TextAlign.right),
              Text('Bester', style: head, textAlign: TextAlign.right),
            ]),
            for (final e in list)
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(e.key, style: cell)),
                Text('${e.value.rounds}', style: cell, textAlign: TextAlign.right),
                Text(
                  '${e.value.paid - e.value.staked >= 0 ? '+' : ''}${formatCoins(e.value.paid - e.value.staked)}',
                  style: cell.copyWith(color: e.value.paid >= e.value.staked ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
                  textAlign: TextAlign.right,
                ),
                Text(formatCoins(e.value.best), style: cell, textAlign: TextAlign.right),
              ]),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: p.inkSoft, fontSize: 13)),
      Text(value, style: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w800)),
    ]);
  }
}
