import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/missions.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

Widget missionRow(Mission m, {String? trailing}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: m.done ? AppColors.safeBg : AppColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(m.done ? Icons.check : m.icon,
              size: 20, color: m.done ? AppColors.safe : AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: m.fraction,
                  minHeight: 6,
                  color: m.done ? AppColors.safe : AppColors.primary,
                  backgroundColor: AppColors.track,
                ),
              ),
              const SizedBox(height: 3),
              Text(trailing ?? m.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('${m.progress > m.target ? m.target : m.progress}/${m.target}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// Home card: this week's missions.
class WeeklyMissionsCard extends StatelessWidget {
  const WeeklyMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ms = Missions.forWeek(s, Missions.mondayOf(DateTime.now()));
    final done = ms.where((m) => m.done).length;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const MissionsScreen())),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('This week',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Text('$done of ${ms.length} done  +30 XP each',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            for (final m in ms.take(3)) missionRow(m),
          ],
        ),
      ),
    );
  }
}

/// Weekly missions plus the user's own challenges.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final target = TextEditingController(text: '5');
    var kind = 'workouts';
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New challenge'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name (for example Gym week)'),
                ),
                const SizedBox(height: 12),
                const Text('What to count', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final e in challengeKinds.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(e.value),
                    value: e.key,
                    groupValue: kind,
                    onChanged: (v) => setD(() => kind = v ?? kind),
                  ),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target days'),
                ),
                const SizedBox(height: 12),
                const Text('Length', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in const [7, 14, 30])
                      ChoiceChip(
                        label: Text('$d days'),
                        selected: days == d,
                        onSelected: (_) => setD(() => days = d),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
          ],
        ),
      ),
    );
    final nm = name.text.trim();
    final tg = int.tryParse(target.text.trim()) ?? 0;
    name.dispose();
    target.dispose();
    if (ok != true || !context.mounted) return;
    if (nm.isEmpty || tg < 1 || tg > days) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a name and a target between 1 and $days.')),
      );
      return;
    }
    final now = DateTime.now();
    context.read<AppState>().addChallenge({
      'id': now.microsecondsSinceEpoch.toString(),
      'name': nm,
      'kind': kind,
      'target': tg,
      'days': days,
      'start': AppState.dayKey(now),
    });
    Haptic.done();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final week = Missions.forWeek(s, Missions.mondayOf(DateTime.now()));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Missions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New challenge'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          children: [
            const Text('Weekly missions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Monday to Sunday. Each finished mission gives 30 XP.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(children: [for (final m in week) missionRow(m)]),
            ),
            const SizedBox(height: 22),
            const Text('My challenges',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (s.customChallenges.isEmpty)
              AppCard(
                child: Text(
                  'Make your own goal, for example "Protein on 5 days in 7". Tap New challenge.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              for (final c in s.customChallenges.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey(c['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.delete_outline, color: AppColors.danger),
                    ),
                    onDismissed: (_) => s.deleteChallenge(c['id'] as String),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: () {
                        final m = Missions.challenge(s, c);
                        final left = Missions.daysLeft(c);
                        final status = m.done
                            ? 'Completed'
                            : left > 0
                                ? '$left days left'
                                : 'Ended';
                        return missionRow(m, trailing: '${m.detail}  |  $status');
                      }(),
                    ),
                  ),
                ),
            if (s.customChallenges.isNotEmpty)
              Text('Swipe a challenge left to delete it.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
