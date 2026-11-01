import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/badges.dart' as b;
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Home row that opens the badges screen.
class BadgesCard extends StatelessWidget {
  const BadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListenableBuilder(
      listenable: StepService.instance,
      builder: (context, _) {
        final a = b.Achievements.of(s);
        return AppCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
            title: const Text('Streaks and badges',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${a.currentStreak} day food streak  |  ${a.earnedCount} of ${a.badges.length} badges'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
            ),
          ),
        );
      },
    );
  }
}

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = b.Achievements.of(s);
    return Scaffold(
      appBar: AppBar(title: const Text('Streaks and badges')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _stat('${a.currentStreak}', 'Current streak (days)')),
              const SizedBox(width: 12),
              Expanded(child: _stat('${a.bestStreak}', 'Best streak (days)')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('A streak counts every day you log at least one food.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 20),
          Text('Badges  ${a.earnedCount} / ${a.badges.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [for (final x in a.badges) _badge(x)],
          ),
        ],
      ),
    );
  }

  Widget _stat(String big, String label) => AppCard(
        radius: 16,
        child: Column(
          children: [
            Text(big,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _badge(b.AppBadge x) {
    return AppCard(
      radius: 16,
      color: x.earned ? AppColors.chipBg : Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(x.icon, size: 30, color: x.earned ? AppColors.primary : AppColors.muted),
          const SizedBox(height: 6),
          Text(x.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: x.earned ? AppColors.ink : AppColors.muted)),
          const SizedBox(height: 2),
          Text(x.earned ? 'Earned' : x.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: x.earned ? AppColors.safe : AppColors.muted)),
        ],
      ),
    );
  }
}
