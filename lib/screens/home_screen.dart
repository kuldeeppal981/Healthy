import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/ring.dart';
import '../widgets/voice_review.dart';
import 'badges_screen.dart';
import 'exercise_library_screen.dart';
import 'health_connect_screen.dart';
import 'report_screen.dart';
import 'social_screen.dart';
import 'coach_screen.dart';
import 'steps_screen.dart';
import 'streak_card.dart';
import 'workout_data.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onGoto;

  const HomeScreen({super.key, required this.onGoto});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _tip(AppState s) {
    final h = DateTime.now().hour;
    if (s.today.isEmpty) return 'Log your first meal of the day. Scanning a barcode is the fastest way.';
    if (s.kcalToday > s.kcalTarget) {
      return 'You are over your calorie target today. Keep the next meal light and take a short walk.';
    }
    if (h >= 15 && s.proteinToday < s.proteinTarget * 0.5) {
      return 'Protein is a bit low. Add dal, chana, eggs or paneer to your next meal.';
    }
    if (s.waterToday < s.waterTarget ~/ 2 && h >= 14) {
      return 'You are behind on water. Have a glass now.';
    }
    return 'You are doing well. Keep logging.';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final remaining = (s.kcalTarget - s.kcalToday).round();
    final plan = s.planFor(now.weekday);
    final streak = s.foodStreak;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  Text(_greeting(now.hour),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            InkWell(
              onTap: () => onGoto(1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 16, color: AppColors.chipInk),
                    const SizedBox(width: 6),
                    Text(
                      s.allergies.isEmpty
                          ? 'Add allergies'
                          : '${s.allergies.length} allergy alert${s.allergies.length == 1 ? '' : 's'} on',
                      style: const TextStyle(
                        color: AppColors.chipInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          radius: 24,
          child: Column(
            children: [
              Row(
                children: [
                  Ring(
                    progress: s.kcalToday / s.kcalTarget,
                    color: AppColors.ring,
                    track: AppColors.track,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${s.kcalToday.round()}',
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                        ),
                        Text('of ${s.kcalTarget} kcal',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily goal',
                            style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(
                          remaining >= 0
                              ? '$remaining kcal left'
                              : '${-remaining} kcal over',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                        if (streak > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$streak day logging streak',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.link),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _macro('Protein', s.proteinToday, s.proteinTarget, AppColors.primary),
                  const SizedBox(width: 12),
                  _macro('Carbs', s.carbsToday, s.carbsTarget, AppColors.ring),
                  const SizedBox(width: 12),
                  _macro('Fat', s.fatToday, s.fatTarget, AppColors.blue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Water',
                              style: TextStyle(fontSize: 13, color: AppColors.muted)),
                          Text('${s.waterToday} / ${s.waterTarget}',
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w700)),
                          const Text('glasses',
                              style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Add a glass of water',
                      onPressed: () => s.addWater(1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => onGoto(2),
                borderRadius: BorderRadius.circular(18),
                child: AppCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today's workout",
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      Text(plan.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${s.workoutsThisWeek} done this week',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const StreakCard(),
        const SizedBox(height: 16),
        const StepsCard(),
        const SizedBox(height: 16),
        const BadgesCard(),
        const SizedBox(height: 16),
        AppCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            leading: const Icon(Icons.insights_outlined, color: AppColors.primary),
            title: const Text('Monthly report', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Workouts, calories, protein, records, PDF'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ExerciseLibraryCard(),
        const SizedBox(height: 16),
        const HealthConnectCard(),
        if (cloudEnabled) ...[
          const SizedBox(height: 16),
          const SocialCard(),
        ],
        if (cloudEnabled) ...[
          const SizedBox(height: 16),
          AppCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
              title: const Text('Ask the coach',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Food, protein and workout questions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CoachScreen()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text("Today's meals",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            FilledButton.tonalIcon(
              onPressed: () => logByVoice(context),
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Speak'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final meal in mealOrder) _mealCard(context, s, meal),
        const SizedBox(height: 4),
        AppCard(
          color: AppColors.chipBg,
          borderColor: AppColors.chipBg,
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(
                text: 'Tip: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: _tip(s)),
            ]),
            style: const TextStyle(color: AppColors.chipInk, fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _macro(String label, double value, int target, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${value.round()}/$target',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (value / target).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.track,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealCard(BuildContext context, AppState s, String meal) {
    final items = s.mealEntries(meal);
    final kcal = items.fold(0.0, (sum, e) => sum + e.kcal).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mealLabels[meal]!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (items.isEmpty)
                        const Text('Nothing added yet',
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Text('$kcal kcal',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: 'Add to ${mealLabels[meal]}',
                  onPressed: () => showAddFoodSheet(context, meal: meal),
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                ),
              ],
            ),
            for (final e in items)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.dangerBg,
                  child: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
                onDismissed: (_) => s.removeEntry(e.id),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      Text('${e.kcal.round()} kcal',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
