import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/levels.dart';
import '../services/social_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Home card: daily streak, check-in button, streak freezes, level and XP.
class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  // Posted once per app run; the feed also ignores repeats.
  static final _sent = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<AppState>();
      final saved = s.settleFreezes();
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You missed a day. A streak freeze saved your streak.'),
        ));
      }
      _announce(s);
    });
  }

  void _announce(AppState s) {
    final p = Progress.of(s);
    if (p.level >= 2 && _sent.add('level-${p.level}')) {
      SocialService.instance.postAchievement(
        kind: 'badge',
        title: 'Reached level ${p.level}: ${p.title}',
        body: '${p.xp} XP',
        dedupe: 'level-${p.level}',
      );
    }
    final n = s.dailyStreak;
    const marks = [7, 14, 30, 50, 100, 200, 365];
    if (marks.contains(n) && _sent.add('streak-$n-${AppState.dayKey(DateTime.now())}')) {
      SocialService.instance.postAchievement(
        kind: 'streak',
        title: '$n day streak',
        body: 'Showing up every single day.',
        dedupe: 'streak-$n-${AppState.dayKey(DateTime.now())}',
      );
    }
  }

  void _checkIn(AppState s) {
    final before = Progress.of(s);
    s.checkIn();
    final after = Progress.of(s);
    final up = after.level > before.level;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(up
          ? 'Checked in! Level ${after.level}: ${after.title}'
          : 'Checked in! +10 XP  |  ${s.dailyStreak} day streak'),
    ));
    _announce(s);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Progress.of(s);
    final streak = s.dailyStreak;
    final done = s.checkedInToday;
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(streak == 1 ? '1 day streak' : '$streak day streak',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(
                      done ? 'Checked in today' : 'Check in, log food or workout to keep it',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Lv ${p.level}  ${p.title}',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: p.fraction, minHeight: 8),
          ),
          const SizedBox(height: 6),
          Text('${p.xp} / ${p.xpAtNext} XP to level ${p.level + 1}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '❄️ ${s.freezesLeft} of ${AppState.freezesPerMonth} streak freezes left this month',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: done ? null : () => _checkIn(s),
                child: Text(done ? 'Done' : 'Check in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
