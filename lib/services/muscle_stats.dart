import '../data/exercise_library.dart';
import '../state/app_state.dart';

/// Training totals for the last [days] days (today included).
class MuscleStats {
  final Map<String, int> sets;
  final int total;
  final int workouts;
  final double volume;
  final int oldSets; // sets from workouts saved before muscle data existed

  const MuscleStats(this.sets, this.total, this.workouts, this.volume, this.oldSets);

  int get musclesHit => sets.values.where((v) => v > 0).length;

  static MuscleStats compute(AppState a, int days) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final logs = a.workouts.where((w) => !w.at.isBefore(from)).toList();
    final sets = <String, int>{for (final m in trackedMuscles) m: 0};
    var volume = 0.0;
    var oldSets = 0;
    for (final w in logs) {
      volume += w.volumeKg;
      if (w.muscleSets.isEmpty) oldSets += w.sets;
      w.muscleSets.forEach((k, v) {
        if (sets.containsKey(k)) sets[k] = sets[k]! + v;
      });
    }
    final total = sets.values.fold<int>(0, (x, y) => x + y);
    return MuscleStats(sets, total, logs.length, volume, oldSets);
  }
}
