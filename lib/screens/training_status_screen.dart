import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/training_stats.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

/// Per muscle: last trained, sets this week, how often, and a recovery
/// ESTIMATE based only on the user's own training history.
class TrainingStatusScreen extends StatelessWidget {
  const TrainingStatusScreen({super.key});

  static String ago(DateTime? t) {
    if (t == null) return 'Not trained yet';
    final d = DateTime.now().difference(t);
    if (d.inHours < 1) return 'Just now';
    if (d.inHours < 24) return '${d.inHours} h ago';
    final days = d.inDays;
    return days == 1 ? 'Yesterday' : '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final ov = TrainingOverview.compute(a);
    final diff = ov.volumeLastWeek <= 0
        ? null
        : ((ov.volumeThisWeek - ov.volumeLastWeek) / ov.volumeLastWeek * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Training status')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${ov.workoutsThisWeek}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      Text('workouts in 7 days',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${ov.volumeThisWeek.round()} kg',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      Text(
                        diff == null
                            ? 'volume this week'
                            : 'volume, ${diff >= 0 ? '+' : ''}$diff% vs last week',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.warnBg,
            borderColor: AppColors.warnBg,
            radius: 14,
            child: Text(
              'Recovery is an estimate from your logged workouts (about 48 to 72 hours per muscle). It is not a measurement of your body. Sleep, food, stress and age change real recovery. Not medical advice.',
              style: TextStyle(color: AppColors.warnInk, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final m in ov.muscles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.muscle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (!m.everTrained
                                    ? AppColors.muted
                                    : (m.ready ? AppColors.safe : const Color(0xFFF59E0B)))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            !m.everTrained
                                ? 'No data'
                                : (m.ready ? 'Likely ready' : 'Recovering ~${m.hoursLeft} h'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !m.everTrained
                                  ? AppColors.muted
                                  : (m.ready ? AppColors.safe : const Color(0xFFF59E0B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.everTrained
                          ? 'Last trained: ${ago(m.lastTrained)} (${m.setsLastSession} sets)'
                          : 'Last trained: not in your logs yet',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.weeklySets} sets this week  |  ${m.perWeek.toStringAsFixed(1)} times a week (last 4 weeks)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            'Sets count completed sets of library exercises. Custom exercises are not counted.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
