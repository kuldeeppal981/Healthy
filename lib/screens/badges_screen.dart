import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/badges.dart' as b;
import '../services/missions.dart';
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/illustrations.dart';
import '../widgets/ui_kit.dart';

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
            leading: Icon(Icons.emoji_events_outlined, color: AppColors.primary),
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
      body: AppBackground(
       child: ListView(
        padding: Space.pagePadding,
        children: [
          HeroHeader(
            kind: ArtKind.flame,
            title: '${a.currentStreak} day streak',
            subtitle: a.currentStreak == 0 ? 'Log a food today to start your streak.' : 'Keep going, you are doing great!',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _stat('${a.currentStreak}', 'Current streak (days)')),
              const SizedBox(width: 12),
              Expanded(child: _stat('${a.bestStreak}', 'Best streak (days)')),
            ],
          ),
          const SizedBox(height: 8),
          Text('A streak counts every day you log at least one food.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 20),
          _milestones(s),
          const SizedBox(height: 14),
          _freezes(s),
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
      ),
    );
  }

  /// 7, 30, 90 and 180 day marks of the daily streak (check-in, food or workout).
  Widget _milestones(AppState s) {
    final best = Missions.bestStreak(s);
    const marks = [7, 30, 90, 180];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Milestones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Best daily streak so far: $best days',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          for (final m in marks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(best >= m ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: best >= m ? AppColors.safe : AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('$m day streak',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: best >= m ? AppColors.ink : AppColors.muted)),
                  ),
                  Text(best >= m ? 'Reached' : '${m - best} to go',
                      style: TextStyle(
                          fontSize: 12,
                          color: best >= m ? AppColors.safe : AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Streak freezes: how many are left and on which days one was used.
  Widget _freezes(AppState s) {
    final prefix = AppState.dayKey(DateTime.now()).substring(0, 7);
    final used = s.frozen.where((d) => d.startsWith(prefix)).toList()..sort();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Streak freezes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '${s.freezesLeft} of ${AppState.freezesPerMonth} left this month. If you miss one day after a streak, a freeze covers it by itself.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Text(
            used.isEmpty ? 'No freeze used this month.' : 'Used on: ${used.join(', ')}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _stat(String big, String label) => AppCard(
        radius: 16,
        child: Column(
          children: [
            CountUp(
                value: int.tryParse(big) ?? 0,
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _badge(b.AppBadge x) {
    final card = _badgeCard(x);
    if (!x.earned) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: card,
    );
  }

  Widget _badgeCard(b.AppBadge x) {
    return AppCard(
      radius: 16,
      color: x.earned ? AppColors.chipBg : AppColors.card,
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
