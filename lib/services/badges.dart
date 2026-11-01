import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'step_service.dart';

class AppBadge {
  final String id;
  final String title;
  final String hint;
  final IconData icon;
  final bool earned;

  const AppBadge(this.id, this.title, this.hint, this.icon, this.earned);
}

/// Streaks and badges worked out from what the user has already logged,
/// so nothing extra is stored and badges stay earned.
class Achievements {
  final int currentStreak;
  final int bestStreak;
  final List<AppBadge> badges;

  const Achievements(this.currentStreak, this.bestStreak, this.badges);

  int get earnedCount => badges.where((b) => b.earned).length;

  static Achievements of(AppState s) {
    // Longest run of days with food logged.
    final days = <DateTime>{
      for (final e in s.entries) DateTime(e.at.year, e.at.month, e.at.day),
    }.toList()
      ..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    final current = s.foodStreak;
    if (current > best) best = current;

    // Per-day totals.
    final kcal = <String, double>{};
    final protein = <String, double>{};
    final count = <String, int>{};
    for (final e in s.entries) {
      final k = AppState.dayKey(e.at);
      kcal[k] = (kcal[k] ?? 0) + e.kcal;
      protein[k] = (protein[k] ?? 0) + e.protein;
      count[k] = (count[k] ?? 0) + 1;
    }
    final onTarget = kcal.entries.any((e) =>
        (count[e.key] ?? 0) >= 2 &&
        e.value >= s.kcalTarget * 0.9 &&
        e.value <= s.kcalTarget * 1.05);
    final proteinDay = protein.values.any((v) => s.proteinTarget > 0 && v >= s.proteinTarget);
    final waterDay = s.water.values.any((v) => v >= s.waterTarget);
    final steps = StepService.instance;
    final stepDay = steps.history.values.any((v) => v >= steps.goal);

    return Achievements(current, best, [
      AppBadge('first_log', 'First bite', 'Log your first food', Icons.restaurant, s.entries.isNotEmpty),
      AppBadge('streak3', '3 day streak', 'Log food 3 days in a row', Icons.local_fire_department, best >= 3),
      AppBadge('streak7', 'One week', 'Log food 7 days in a row', Icons.whatshot, best >= 7),
      AppBadge('streak14', 'Two weeks', 'Log food 14 days in a row', Icons.workspace_premium, best >= 14),
      AppBadge('streak30', 'Habit built', 'Log food 30 days in a row', Icons.emoji_events, best >= 30),
      AppBadge('on_target', 'Right on target', 'Finish a day within your calorie target', Icons.track_changes, onTarget),
      AppBadge('protein', 'Protein pro', 'Reach your protein target in a day', Icons.egg_alt, proteinDay),
      AppBadge('water', 'Well hydrated', 'Drink your water goal in a day', Icons.water_drop, waterDay),
      AppBadge('first_workout', 'First rep', 'Finish your first workout', Icons.fitness_center, s.workouts.isNotEmpty),
      AppBadge('workouts5', 'Getting strong', 'Finish 5 workouts', Icons.sports_gymnastics, s.workouts.length >= 5),
      AppBadge('workouts20', 'Gym regular', 'Finish 20 workouts', Icons.military_tech, s.workouts.length >= 20),
      AppBadge('steps', 'Step goal', 'Reach your daily step goal', Icons.directions_walk, stepDay),
      AppBadge('weigh', 'On the scale', 'Log your weight 3 times', Icons.monitor_weight, s.weights.length >= 3),
      AppBadge('allergy', 'Allergy aware', 'Set up your allergies', Icons.health_and_safety, s.allergies.isNotEmpty),
      AppBadge('profile', 'All set', 'Complete your profile', Icons.person, s.profile != null),
    ]);
  }
}
