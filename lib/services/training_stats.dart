import '../data/exercise_library.dart';
import '../screens/workout_data.dart';
import '../state/app_state.dart';

/// Training facts for one muscle, worked out only from the user's own logged
/// workouts. The recovery number is an ESTIMATE from training history, not a
/// biological measurement.
class MuscleTraining {
  final String muscle;
  final DateTime? lastTrained;
  final int setsLastSession;
  final int weeklySets; // completed sets in the last 7 days
  final int sessions28; // workouts that hit this muscle in the last 28 days
  final double hoursSince;
  final double hoursNeeded;

  const MuscleTraining({
    required this.muscle,
    required this.lastTrained,
    required this.setsLastSession,
    required this.weeklySets,
    required this.sessions28,
    required this.hoursSince,
    required this.hoursNeeded,
  });

  bool get everTrained => lastTrained != null;
  bool get ready => !everTrained || hoursSince >= hoursNeeded;

  /// Hours until the estimate says it is ready again (0 when ready).
  int get hoursLeft => ready ? 0 : (hoursNeeded - hoursSince).ceil();

  double get perWeek => sessions28 / 4;
}

class TrainingOverview {
  final List<MuscleTraining> muscles;
  final double volumeThisWeek; // kg, last 7 days
  final double volumeLastWeek; // kg, the 7 days before
  final int workoutsThisWeek;

  const TrainingOverview(this.muscles, this.volumeThisWeek, this.volumeLastWeek, this.workoutsThisWeek);

  static TrainingOverview compute(AppState a) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final week = startToday.subtract(const Duration(days: 6));
    final prevWeek = startToday.subtract(const Duration(days: 13));
    final month = startToday.subtract(const Duration(days: 27));

    var volThis = 0.0;
    var volPrev = 0.0;
    var wk = 0;
    for (final w in a.workouts) {
      if (!w.at.isBefore(week)) {
        volThis += w.volumeKg;
        wk++;
      } else if (!w.at.isBefore(prevWeek)) {
        volPrev += w.volumeKg;
      }
    }

    final out = <MuscleTraining>[];
    for (final m in trackedMuscles) {
      DateTime? last;
      var lastSets = 0;
      var weekly = 0;
      var sessions = 0;
      for (final w in a.workouts) {
        final s = w.muscleSets[m] ?? 0;
        if (s <= 0) continue;
        if (!w.at.isBefore(week)) weekly += s;
        if (!w.at.isBefore(month)) sessions++;
        if (last == null || w.at.isAfter(last)) {
          last = w.at;
          lastSets = s;
        }
      }
      // Rule of thumb: 48 h after a light session, up to 72 h after a long one.
      final needed = (36 + 4.0 * lastSets).clamp(48.0, 72.0).toDouble();
      out.add(MuscleTraining(
        muscle: m,
        lastTrained: last,
        setsLastSession: lastSets,
        weeklySets: weekly,
        sessions28: sessions,
        hoursSince: last == null ? 9999 : now.difference(last).inMinutes / 60.0,
        hoursNeeded: needed,
      ));
    }
    return TrainingOverview(out, volThis, volPrev, wk);
  }
}

/// A shorter version of a planned workout for when time is short.
class ShortPlan {
  final DayPlan plan;
  final int minutes;
  final List<String> dropped;
  final bool trimmed; // some exercises lost sets
  const ShortPlan(this.plan, this.minutes, this.dropped, this.trimmed);
}

const _compound = [
  'squat', 'deadlift', 'bench', 'row', 'press', 'pull-up', 'pullup', 'lunge',
  'hip thrust', 'dip', 'pulldown', 'push-up',
];

/// Keeps the most useful exercises when only [available] minutes are free.
/// Big compound lifts and muscles that are rested come first; if needed an
/// exercise keeps just 2 sets. Same 2.25 minutes per set as the plan estimate.
ShortPlan shortenPlan(DayPlan plan, int available, TrainingOverview ov) {
  final readyMuscles = {
    for (final m in ov.muscles)
      if (m.ready) m.muscle,
  };

  double priority(Exercise e) {
    final n = e.name.toLowerCase();
    var p = 1.0;
    if (_compound.any(n.contains)) p += 2;
    final info = findExercise(e.name);
    if (info != null) p += 0.5;
    final m = muscleOf(e.name);
    if (m != null && readyMuscles.contains(m)) p += 0.5;
    if (info != null && (info.group == 'Core' || info.group == 'Cardio')) p -= 0.7;
    return p;
  }

  final idx = List<int>.generate(plan.exercises.length, (i) => i)
    ..sort((a, b) {
      final c = priority(plan.exercises[b]).compareTo(priority(plan.exercises[a]));
      return c != 0 ? c : a.compareTo(b);
    });

  const perSet = 2.25;
  var budget = available.toDouble();
  final keepSets = <int, int>{};
  for (final i in idx) {
    final e = plan.exercises[i];
    final full = e.sets * perSet;
    if (full <= budget) {
      keepSets[i] = e.sets;
      budget -= full;
    } else {
      final fit = (budget / perSet).floor();
      if (fit >= 2) {
        keepSets[i] = fit < e.sets ? fit : e.sets;
        budget -= keepSets[i]! * perSet;
      }
    }
  }

  final kept = <Exercise>[];
  final dropped = <String>[];
  var trimmed = false;
  for (var i = 0; i < plan.exercises.length; i++) {
    final e = plan.exercises[i];
    final k = keepSets[i];
    if (k == null) {
      dropped.add(e.name);
    } else {
      if (k < e.sets) trimmed = true;
      kept.add(Exercise(e.name, k, e.reps, unit: e.unit));
    }
  }
  final sets = kept.fold<int>(0, (n, e) => n + e.sets);
  final mins = (sets * perSet / 5).round() * 5;
  return ShortPlan(
    DayPlan('${plan.title} (short)', kept, rest: plan.rest),
    mins < 10 ? 10 : mins,
    dropped,
    trimmed,
  );
}
