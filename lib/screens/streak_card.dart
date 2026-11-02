import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/levels.dart';
import '../services/social_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'badges_screen.dart';

/// Compact home card: daily streak, level and XP, streak freezes, check-in.
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
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your consistency',
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Level ${p.level}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Image.asset('assets/images/trophy.png', width: 54, fit: BoxFit.contain),
              ],
            ),
            const SizedBox(height: 10),
            Text('🔥 ${streak == 1 ? '1 day' : '$streak days'} streak',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.fraction,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.track,
              ),
            ),
            const SizedBox(height: 4),
            Text('${p.xp} XP  |  ❄️ ${s.freezesLeft} freezes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: done ? null : () => _checkIn(s),
                child: Text(done ? 'Checked in' : 'Check in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
