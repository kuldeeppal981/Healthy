import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// One goal with progress: weekly missions and custom challenges share this.
class Mission {
  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final int progress;
  final int target;

  const Mission(this.id, this.title, this.detail, this.icon, this.progress, this.target);

  bool get done => progress >= target;
  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}

/// What a custom challenge counts. Values are stored in the challenge map.
const challengeKinds = <String, String>{
  'workouts': 'Workout days',
  'protein': 'Days with protein target met',
  'water': 'Days with water goal met',
  'food': 'Days with food logged',
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Number of days in [from, to) where the thing for [kind] happened.
int countDays(AppState s, String kind, DateTime from, DateTime to) {
  final days = <String>{};
  switch (kind) {
    case 'workouts':
      for (final w in s.workouts) {
        if (!w.at.isBefore(from) && w.at.isBefore(to)) days.add(AppState.dayKey(w.at));
      }
    case 'food':
      for (final e in s.entries) {
        if (!e.at.isBefore(from) && e.at.isBefore(to)) days.add(AppState.dayKey(e.at));
      }
    case 'protein':
      final byDay = <String, double>{};
      for (final e in s.entries) {
        if (!e.at.isBefore(from) && e.at.isBefore(to)) {
          final k = AppState.dayKey(e.at);
          byDay[k] = (byDay[k] ?? 0) + e.protein;
        }
      }
      byDay.forEach((k, v) {
        if (v >= s.proteinTarget * 0.9) days.add(k);
      });
    case 'water':
      var d = from;
      while (d.isBefore(to)) {
        final k = AppState.dayKey(d);
        if ((s.water[k] ?? 0) >= s.waterTarget) days.add(k);
        d = d.add(const Duration(days: 1));
      }
  }
  return days.length;
}

class Missions {
  static DateTime mondayOf(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));

  /// This week's missions (Monday to Sunday), worked out from the logs.
  static List<Mission> forWeek(AppState s, DateTime monday) {
    final end = monday.add(const Duration(days: 7));
    final planned = [for (var wd = 1; wd <= 7; wd++) if (!s.planFor(wd).rest) wd].length;
    final workoutTarget = planned == 0 ? 3 : (planned > 5 ? 5 : planned);
    return [
      Mission('workouts', 'Train $workoutTarget days', 'Finish a workout on $workoutTarget days',
          Icons.fitness_center, countDays(s, 'workouts', monday, end), workoutTarget),
      Mission('protein', 'Protein on 4 days', 'Reach about ${s.proteinTarget} g protein',
          Icons.egg_alt_outlined, countDays(s, 'protein', monday, end), 4),
      Mission('water', 'Water goal on 5 days', 'Drink ${s.waterTarget} glasses',
          Icons.water_drop_outlined, countDays(s, 'water', monday, end), 5),
      Mission('food', 'Log food on 6 days', 'Even a small log counts',
          Icons.restaurant_outlined, countDays(s, 'food', monday, end), 6),
    ];
  }

  /// Missions finished in earlier weeks plus this one (last 26 weeks). Each is
  /// worth XP in [Progress]. Nothing is stored, it is worked out from the logs.
  static int completedCount(AppState s) {
    final first = <DateTime>[
      for (final e in s.entries) e.at,
      for (final w in s.workouts) w.at,
    ];
    if (first.isEmpty) return 0;
    first.sort();
    var m = mondayOf(first.first);
    final thisWeek = mondayOf(DateTime.now());
    final limit = thisWeek.subtract(const Duration(days: 7 * 25));
    if (m.isBefore(limit)) m = limit;
    var n = 0;
    while (!m.isAfter(thisWeek)) {
      n += forWeek(s, m).where((x) => x.done).length;
      m = m.add(const Duration(days: 7));
    }
    return n;
  }

  /// Longest run of days that count (active or covered by a freeze).
  static int bestStreak(AppState s) {
    final days = <DateTime>[
      for (final k in {...s.activeDays, ...s.frozen})
        if (DateTime.tryParse(k) != null) DateTime.parse(k),
    ]..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev != null && d.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// Number of comebacks: an active day after a break of 3 or more days.
  static int comebacks(AppState s) {
    final days = <DateTime>[
      for (final k in s.activeDays)
        if (DateTime.tryParse(k) != null) DateTime.parse(k),
    ]..sort();
    var n = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays >= 4) n++;
    }
    return n;
  }

  /// A custom challenge as a [Mission]: progress counts days since it started.
  static Mission challenge(AppState s, Map<String, dynamic> c) {
    final start = DateTime.tryParse(c['start'] as String? ?? '') ?? DateTime.now();
    final days = (c['days'] as num?)?.toInt() ?? 7;
    final kind = c['kind'] as String? ?? 'food';
    final end = _day(start).add(Duration(days: days));
    final target = (c['target'] as num?)?.toInt() ?? 1;
    final progress = countDays(s, kind, _day(start), end);
    return Mission(
      c['id'] as String? ?? '',
      c['name'] as String? ?? 'Challenge',
      '${challengeKinds[kind] ?? kind}, $days days',
      Icons.flag_outlined,
      progress,
      target,
    );
  }

  static int daysLeft(Map<String, dynamic> c) {
    final start = DateTime.tryParse(c['start'] as String? ?? '') ?? DateTime.now();
    final days = (c['days'] as num?)?.toInt() ?? 7;
    final end = _day(start).add(Duration(days: days));
    return end.difference(_day(DateTime.now())).inDays;
  }
}
