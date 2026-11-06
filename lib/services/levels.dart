import '../state/app_state.dart';
import 'badges.dart';
import 'missions.dart';

/// XP and level, worked out from what the user has logged. Nothing extra is
/// stored, so it syncs with the account and never goes down.
class Progress {
  final int xp;
  final int level;
  final int xpAtLevel; // XP needed to reach this level
  final int xpAtNext; // XP needed for the next level

  const Progress(this.xp, this.level, this.xpAtLevel, this.xpAtNext);

  static int xpFor(int level) => 50 * level * (level - 1);

  static const _titles = <(int, String)>[
    (1, 'Beginner'),
    (3, 'Mover'),
    (5, 'Fit'),
    (8, 'Athlete'),
    (12, 'Beast'),
    (18, 'Legend'),
  ];

  String get title {
    var t = _titles.first.$2;
    for (final e in _titles) {
      if (level >= e.$1) t = e.$2;
    }
    return t;
  }

  double get fraction =>
      xpAtNext == xpAtLevel ? 0 : ((xp - xpAtLevel) / (xpAtNext - xpAtLevel)).clamp(0.0, 1.0);

  static Progress of(AppState s) {
    var xp = 0;

    // Food: 5 XP per entry, up to 4 entries a day.
    final perDay = <String, int>{};
    for (final e in s.entries) {
      final k = AppState.dayKey(e.at);
      perDay[k] = (perDay[k] ?? 0) + 1;
    }
    for (final n in perDay.values) {
      xp += (n > 4 ? 4 : n) * 5;
    }

    // Workouts: 50 XP each, up to 2 a day.
    final wk = <String, int>{};
    for (final w in s.workouts) {
      final k = AppState.dayKey(w.at);
      wk[k] = (wk[k] ?? 0) + 1;
    }
    for (final n in wk.values) {
      xp += (n > 2 ? 2 : n) * 50;
    }

    // Water goal days, check-ins, weigh-ins, badges.
    xp += s.water.values.where((v) => v >= s.waterTarget).length * 10;
    xp += s.checkIns.length * 10;
    // Weekly missions (30 XP each) and comebacks after a break (25 XP each).
    xp += Missions.completedCount(s) * 30;
    xp += Missions.comebacks(s) * 25;
    xp += (s.weights.length > 30 ? 30 : s.weights.length) * 10;
    // The step badge is left out: step history is only kept for 14 days.
    xp += Achievements.of(s).badges.where((b) => b.earned && b.id != 'steps').length * 25;

    var level = 1;
    while (xp >= xpFor(level + 1)) {
      level++;
    }
    return Progress(xp, level, xpFor(level), xpFor(level + 1));
  }
}
