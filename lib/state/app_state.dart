import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../profile_models.dart';
import '../services/nutrition_calc.dart';

/// App-wide state, saved on the phone with shared_preferences.
class AppState extends ChangeNotifier {
  SharedPreferences? _p;

  // Profile and onboarding
  UserProfile? profile;
  bool onboardingSkipped = false;
  final List<WeightEntry> weights = [];

  // Allergies
  final Set<String> allergies = {};
  final Map<String, String> severity = {}; // allergen id -> mild|medium|severe
  bool traceWarning = true;

  // Targets
  int kcalTarget = 1850;
  int proteinTarget = 110;
  int carbsTarget = 220;
  int fatTarget = 60;
  int waterTarget = 8;

  // Logs
  final List<DiaryEntry> entries = [];
  final Map<String, int> water = {}; // yyyy-mm-dd -> glasses
  final List<WorkoutLog> workouts = [];

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get needsOnboarding => profile == null && !onboardingSkipped;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;

    final prof = p.getString('profile');
    profile = prof == null
        ? null
        : UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(prof) as Map));
    onboardingSkipped = p.getBool('onboardingSkipped') ?? false;

    weights.clear();
    final w = p.getString('weights');
    if (w != null) {
      for (final x in jsonDecode(w) as List) {
        weights.add(WeightEntry.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }

    allergies
      ..clear()
      ..addAll(p.getStringList('allergies') ?? const []);

    final sev = p.getString('severity');
    severity.clear();
    if (sev != null) {
      severity.addAll(Map<String, String>.from(jsonDecode(sev) as Map));
    }

    traceWarning = p.getBool('traceWarning') ?? true;
    kcalTarget = p.getInt('kcalTarget') ?? kcalTarget;
    proteinTarget = p.getInt('proteinTarget') ?? proteinTarget;
    carbsTarget = p.getInt('carbsTarget') ?? carbsTarget;
    fatTarget = p.getInt('fatTarget') ?? fatTarget;

    entries.clear();
    final e = p.getString('entries');
    if (e != null) {
      for (final x in jsonDecode(e) as List) {
        entries.add(DiaryEntry.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }

    water.clear();
    final wt = p.getString('water');
    if (wt != null) {
      water.addAll(Map<String, int>.from(jsonDecode(wt) as Map));
    }

    workouts.clear();
    final wk = p.getString('workouts');
    if (wk != null) {
      for (final x in jsonDecode(wk) as List) {
        workouts.add(WorkoutLog.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    if (profile != null) {
      await p.setString('profile', jsonEncode(profile!.toJson()));
    } else {
      await p.remove('profile');
    }
    await p.setBool('onboardingSkipped', onboardingSkipped);
    await p.setString('weights', jsonEncode(weights.map((e) => e.toJson()).toList()));
    await p.setStringList('allergies', allergies.toList());
    await p.setString('severity', jsonEncode(severity));
    await p.setBool('traceWarning', traceWarning);
    await p.setInt('kcalTarget', kcalTarget);
    await p.setInt('proteinTarget', proteinTarget);
    await p.setInt('carbsTarget', carbsTarget);
    await p.setInt('fatTarget', fatTarget);
    await p.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setString('water', jsonEncode(water));
    await p.setString('workouts', jsonEncode(workouts.map((e) => e.toJson()).toList()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---- Profile and targets ----
  void saveProfile(UserProfile next) {
    final first = profile == null;
    profile = next;
    onboardingSkipped = false;
    if (first || weights.isEmpty || weights.last.kg != next.weightKg) {
      weights.add(WeightEntry(DateTime.now(), next.weightKg));
    }
    _applyTargets(targetsFor(next));
    _changed();
  }

  void skipOnboarding() {
    onboardingSkipped = true;
    _changed();
  }

  void _applyTargets(Targets t) {
    kcalTarget = t.kcal;
    proteinTarget = t.protein;
    carbsTarget = t.carbs;
    fatTarget = t.fat;
  }

  void recalculateTargets() {
    final pr = profile;
    if (pr == null) return;
    _applyTargets(targetsFor(pr));
    _changed();
  }

  void setTargets({int? kcal, int? protein, int? carbs, int? fat}) {
    kcalTarget = kcal ?? kcalTarget;
    proteinTarget = protein ?? proteinTarget;
    carbsTarget = carbs ?? carbsTarget;
    fatTarget = fat ?? fatTarget;
    _changed();
  }

  // ---- Weight ----
  void logWeight(double kg) {
    weights.add(WeightEntry(DateTime.now(), kg));
    final pr = profile;
    if (pr != null) profile = pr.copyWith(weightKg: kg);
    _changed();
  }

  // ---- Allergies ----
  void toggleAllergy(String id) {
    if (!allergies.remove(id)) {
      allergies.add(id);
      severity.putIfAbsent(id, () => 'medium');
    } else {
      severity.remove(id);
    }
    _changed();
  }

  void setSeverity(String id, String level) {
    severity[id] = level;
    _changed();
  }

  void setTraceWarning(bool v) {
    traceWarning = v;
    _changed();
  }

  bool get hasSevereAllergy => severity.values.any((s) => s == 'severe');

  // ---- Diary ----
  List<DiaryEntry> get today {
    final now = DateTime.now();
    return entries.where((e) => sameDay(e.at, now)).toList();
  }

  double get kcalToday => today.fold(0.0, (s, e) => s + e.kcal);
  double get proteinToday => today.fold(0.0, (s, e) => s + e.protein);
  double get carbsToday => today.fold(0.0, (s, e) => s + e.carbs);
  double get fatToday => today.fold(0.0, (s, e) => s + e.fat);

  List<DiaryEntry> mealEntries(String meal) =>
      today.where((e) => e.meal == meal).toList();

  void addEntry(DiaryEntry e) {
    entries.add(e);
    _changed();
  }

  void removeEntry(String id) {
    entries.removeWhere((e) => e.id == id);
    _changed();
  }

  /// Days in a row with at least one food logged. Today not logged yet
  /// does not break the streak.
  int get foodStreak {
    final days = <String>{for (final e in entries) dayKey(e.at)};
    var d = DateTime.now();
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---- Water ----
  int get waterToday => water[dayKey(DateTime.now())] ?? 0;

  void addWater(int delta) {
    final k = dayKey(DateTime.now());
    water[k] = (waterToday + delta).clamp(0, 30);
    _changed();
  }

  // ---- Workouts ----
  void addWorkout(WorkoutLog w) {
    workouts.add(w);
    _changed();
  }

  int get workoutsThisWeek {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return workouts.where((w) => !w.at.isBefore(start)).length;
  }

  Future<void> clearAll() async {
    profile = null;
    onboardingSkipped = false;
    weights.clear();
    allergies.clear();
    severity.clear();
    entries.clear();
    water.clear();
    workouts.clear();
    notifyListeners();
    await _p?.clear();
  }
}
