import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
import '../profile_models.dart';
import '../services/cloud_sync.dart';
import '../screens/workout_data.dart';
import '../services/nutrition_calc.dart';

/// App-wide state, saved on the phone with shared_preferences.
class AppState extends ChangeNotifier {
  SharedPreferences? _p;

  // Profile and onboarding
  UserProfile? profile;
  bool onboardingSkipped = false;
  String? profileName; // name the user typed in Profile
  final List<WeightEntry> weights = [];

  // Allergies
  final Set<String> allergies = {};
  final Set<String> conditions = {};
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

  /// Days the user tapped Check in, and days a streak freeze covered.
  final Set<String> checkIns = {};
  final Set<String> frozen = {};

  /// The user's own plan per weekday (Monday = 1). Days not in here use the
  /// suggested plan.
  final Map<int, DayPlan> customPlans = {};

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get needsOnboarding => profile == null && !onboardingSkipped;

  // ---- Cloud (Supabase) ----
  CloudSync? cloud; // set in main() when Supabase is configured
  bool guestMode = false;
  DateTime? lastModified;
  bool syncing = false;
  String? syncError;
  Timer? _pushTimer;

  bool get signedIn => cloud?.userId != null;
  String? get accountEmail => cloud?.email;
  String? get accountName => cloud?.displayName;

  /// Name shown in the app: the one typed in Profile, else the account name.
  String? get displayName {
    final n = profileName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final a = accountName?.trim();
    return (a != null && a.isNotEmpty) ? a : null;
  }

  void setProfileName(String name) {
    profileName = name.trim().isEmpty ? null : name.trim();
    _changed();
    final n = profileName;
    if (n != null && signedIn) {
      cloud?.updateName(n).catchError((_) {});
    }
  }
  bool get needsAuth => cloudEnabled && !signedIn && !guestMode;

  Map<String, dynamic> toSnapshot() => {
        'profile': profile?.toJson(),
        'onboardingSkipped': onboardingSkipped,
        'profileName': profileName,
        'weights': weights.map((e) => e.toJson()).toList(),
        'allergies': allergies.toList(),
        'conditions': conditions.toList(),
        'severity': severity,
        'traceWarning': traceWarning,
        'kcalTarget': kcalTarget,
        'proteinTarget': proteinTarget,
        'carbsTarget': carbsTarget,
        'fatTarget': fatTarget,
        'entries': entries.map((e) => e.toJson()).toList(),
        'water': water,
        'workouts': workouts.map((e) => e.toJson()).toList(),
        'customPlans': customPlans.map((k, v) => MapEntry('$k', v.toJson())),
        'checkIns': checkIns.toList(),
        'frozen': frozen.toList(),
      };

  void applySnapshot(Map<String, dynamic> j, DateTime at) {
    final prof = j['profile'];
    profile = prof == null
        ? null
        : UserProfile.fromJson(Map<String, dynamic>.from(prof as Map));
    onboardingSkipped = j['onboardingSkipped'] as bool? ?? false;
    profileName = j['profileName'] as String?;

    weights
      ..clear()
      ..addAll(((j['weights'] as List?) ?? const []).map(
          (x) => WeightEntry.fromJson(Map<String, dynamic>.from(x as Map))));
    allergies
      ..clear()
      ..addAll(((j['allergies'] as List?) ?? const []).map((x) => x.toString()));
    conditions
      ..clear()
      ..addAll(((j['conditions'] as List?) ?? const []).map((x) => x.toString()));
    severity
      ..clear()
      ..addAll(Map<String, String>.from((j['severity'] as Map?) ?? const {}));
    traceWarning = j['traceWarning'] as bool? ?? true;

    kcalTarget = (j['kcalTarget'] as num?)?.toInt() ?? kcalTarget;
    proteinTarget = (j['proteinTarget'] as num?)?.toInt() ?? proteinTarget;
    carbsTarget = (j['carbsTarget'] as num?)?.toInt() ?? carbsTarget;
    fatTarget = (j['fatTarget'] as num?)?.toInt() ?? fatTarget;

    entries
      ..clear()
      ..addAll(((j['entries'] as List?) ?? const []).map(
          (x) => DiaryEntry.fromJson(Map<String, dynamic>.from(x as Map))));
    water
      ..clear()
      ..addAll(Map<String, int>.from((j['water'] as Map?) ?? const {}));
    workouts
      ..clear()
      ..addAll(((j['workouts'] as List?) ?? const []).map(
          (x) => WorkoutLog.fromJson(Map<String, dynamic>.from(x as Map))));
    _readCustomPlans(j['customPlans']);
    checkIns
      ..clear()
      ..addAll(((j['checkIns'] as List?) ?? const []).map((x) => x.toString()));
    frozen
      ..clear()
      ..addAll(((j['frozen'] as List?) ?? const []).map((x) => x.toString()));

    lastModified = at;
    notifyListeners();
    _save();
  }

  void _schedulePush() {
    if (!signedIn) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), _push);
  }

  Future<void> _push() async {
    final c = cloud;
    if (c == null || !signedIn) return;
    try {
      await c.push(toSnapshot(), lastModified ?? DateTime.now());
      syncError = null;
    } catch (_) {
      syncError = 'Could not back up. It will retry on your next change.';
    }
    notifyListeners();
  }

  /// Pulls the account's data and merges it with what is on the phone.
  /// [preferRemote] is true right after a fresh sign-in (the account's data
  /// wins); at app start the newer side wins so offline edits are not lost.
  Future<void> syncAfterLogin({bool preferRemote = false}) async {
    final c = cloud;
    if (c == null || !signedIn || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      final remote = await c.pull();
      final local = lastModified;
      if (remote == null) {
        await c.push(toSnapshot(), local ?? DateTime.now());
      } else if (preferRemote || local == null || remote.updatedAt.isAfter(local)) {
        applySnapshot(remote.data, remote.updatedAt);
      } else {
        await c.push(toSnapshot(), local);
      }
      syncError = null;
    } catch (_) {
      syncError = 'Sync failed. Check your internet connection.';
    }
    syncing = false;
    notifyListeners();
  }

  Future<AuthOutcome> signIn(String email, String password) async {
    final c = cloud;
    if (c == null) return const AuthOutcome(error: 'Cloud sync is not set up.');
    final r = await c.signIn(email, password);
    if (r.error == null) {
      guestMode = false;
      await syncAfterLogin(preferRemote: true);
      notifyListeners();
    }
    return r;
  }

  Future<AuthOutcome> signUp(String email, String password, {String? name}) async {
    final c = cloud;
    if (c == null) return const AuthOutcome(error: 'Cloud sync is not set up.');
    final r = await c.signUp(email, password, name: name);
    if (r.error == null && !r.needsEmailConfirm) {
      guestMode = false;
      await syncAfterLogin(preferRemote: true);
      notifyListeners();
    }
    return r;
  }

  /// Checks the code the user got by email. Success signs the user in.
  Future<AuthOutcome> verifyCode(String email, String code) async {
    final c = cloud;
    if (c == null) return const AuthOutcome(error: 'Cloud sync is not set up.');
    final r = await c.verifyEmailCode(email, code);
    if (r.error == null) {
      guestMode = false;
      await syncAfterLogin(preferRemote: true);
      notifyListeners();
    }
    return r;
  }

  Future<AuthOutcome> resendCode(String email) async {
    final c = cloud;
    if (c == null) return const AuthOutcome(error: 'Cloud sync is not set up.');
    return c.resendCode(email);
  }

  Future<AuthOutcome> signInWithGoogle() async {
    final c = cloud;
    if (c == null) return const AuthOutcome(error: 'Cloud sync is not set up.');
    return c.signInWithGoogle();
  }

  StreamSubscription<void>? _signedInSub;
  StreamSubscription<void>? _anyAuthSub;

  /// Reacts to logins that finish outside the app screen, like Google
  /// sign-in coming back through the deep link, and to sign-outs.
  void listenAuth() {
    final c = cloud;
    if (c == null) return;
    _signedInSub?.cancel();
    _anyAuthSub?.cancel();
    _signedInSub = c.signedInEvents.listen((_) {
      guestMode = false;
      syncAfterLogin(preferRemote: true);
    });
    _anyAuthSub = c.anyAuthEvents.listen((_) => notifyListeners());
  }

  Future<void> signOut() async {
    await cloud?.signOut();
    await clearAll();
  }

  void continueAsGuest() {
    guestMode = true;
    _save();
    notifyListeners();
  }

  void leaveGuest() {
    guestMode = false;
    _save();
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;

    final prof = p.getString('profile');
    profile = prof == null
        ? null
        : UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(prof) as Map));
    onboardingSkipped = p.getBool('onboardingSkipped') ?? false;
    profileName = p.getString('profileName');
    guestMode = p.getBool('guestMode') ?? false;
    final lm = p.getString('lastModified');
    lastModified = lm == null ? null : DateTime.tryParse(lm);

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
    conditions
      ..clear()
      ..addAll(p.getStringList('conditions') ?? const []);

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

    final cp = p.getString('customPlans');
    _readCustomPlans(cp == null ? null : jsonDecode(cp));

    checkIns
      ..clear()
      ..addAll(p.getStringList('checkIns') ?? const []);
    frozen
      ..clear()
      ..addAll(p.getStringList('frozen') ?? const []);

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
    if (profileName != null) {
      await p.setString('profileName', profileName!);
    } else {
      await p.remove('profileName');
    }
    await p.setBool('guestMode', guestMode);
    final lm = lastModified;
    if (lm != null) {
      await p.setString('lastModified', lm.toUtc().toIso8601String());
    }
    await p.setString('weights', jsonEncode(weights.map((e) => e.toJson()).toList()));
    await p.setStringList('allergies', allergies.toList());
    await p.setStringList('conditions', conditions.toList());
    await p.setString('severity', jsonEncode(severity));
    await p.setBool('traceWarning', traceWarning);
    await p.setInt('kcalTarget', kcalTarget);
    await p.setInt('proteinTarget', proteinTarget);
    await p.setInt('carbsTarget', carbsTarget);
    await p.setInt('fatTarget', fatTarget);
    await p.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setString('water', jsonEncode(water));
    await p.setString('workouts', jsonEncode(workouts.map((e) => e.toJson()).toList()));
    await p.setStringList('checkIns', checkIns.toList());
    await p.setStringList('frozen', frozen.toList());
    await p.setString(
        'customPlans', jsonEncode(customPlans.map((k, v) => MapEntry('$k', v.toJson()))));
  }

  void _changed() {
    lastModified = DateTime.now();
    notifyListeners();
    _save();
    _schedulePush();
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

  // ---- Health conditions ----
  void toggleCondition(String id) {
    if (!conditions.remove(id)) conditions.add(id);
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


  // ---- Daily streak, check-in and freezes ----
  static const freezesPerMonth = 2;

  bool get checkedInToday => checkIns.contains(dayKey(DateTime.now()));

  /// A day counts when the user checked in, logged food or finished a workout.
  Set<String> get activeDays => {
        ...checkIns,
        for (final e in entries) dayKey(e.at),
        for (final w in workouts) dayKey(w.at),
      };

  void checkIn() {
    if (checkedInToday) return;
    checkIns.add(dayKey(DateTime.now()));
    _changed();
  }

  int get freezesLeft {
    final prefix = dayKey(DateTime.now()).substring(0, 7);
    final used = frozen.where((d) => d.startsWith(prefix)).length;
    return (freezesPerMonth - used).clamp(0, freezesPerMonth);
  }

  /// Days in a row that count. A frozen day keeps the streak alive but adds
  /// nothing. Today not done yet does not break it.
  int get dailyStreak {
    final active = activeDays;
    var d = DateTime.now();
    final today = dayKey(d);
    if (!active.contains(today) && !frozen.contains(today)) {
      d = d.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (true) {
      final k = dayKey(d);
      if (active.contains(k)) {
        n++;
      } else if (!frozen.contains(k)) {
        break;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// If exactly yesterday was missed after a running streak, spend a freeze
  /// on it (2 per month). Safe to call again and again.
  bool settleFreezes() {
    final now = DateTime.now();
    final y = dayKey(now.subtract(const Duration(days: 1)));
    final yy = dayKey(now.subtract(const Duration(days: 2)));
    final active = activeDays;
    bool covered(String k) => active.contains(k) || frozen.contains(k);
    if (covered(y) || !covered(yy) || freezesLeft <= 0) return false;
    frozen.add(y);
    _changed();
    return true;
  }

  // ---- Water ----
  int get waterToday => water[dayKey(DateTime.now())] ?? 0;

  void addWater(int delta) {
    final k = dayKey(DateTime.now());
    water[k] = (waterToday + delta).clamp(0, 30);
    _changed();
  }

  // ---- Workouts ----
  void _readCustomPlans(Object? raw) {
    customPlans.clear();
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final day = int.tryParse(k.toString());
      if (day == null || day < 1 || day > 7) return;
      try {
        customPlans[day] = DayPlan.fromJson(Map<String, dynamic>.from(v as Map));
      } catch (_) {}
    });
  }

  /// The plan shown for a weekday: the user's own, else the suggested one.
  DayPlan planFor(int weekday) => customPlans[weekday] ?? planForWeekday(weekday);

  bool isCustomPlan(int weekday) => customPlans.containsKey(weekday);

  void saveCustomPlan(int weekday, DayPlan plan) {
    customPlans[weekday] = plan;
    _changed();
  }

  void resetPlan(int weekday) {
    customPlans.remove(weekday);
    _changed();
  }

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

  Future<void> clearAll({bool deleteCloud = false}) async {
    _pushTimer?.cancel();
    if (deleteCloud && signedIn) {
      try {
        await cloud!.deleteRemote();
      } catch (_) {}
    }
    guestMode = false;
    lastModified = null;
    syncError = null;
    profile = null;
    onboardingSkipped = false;
    profileName = null;
    weights.clear();
    allergies.clear();
    conditions.clear();
    severity.clear();
    entries.clear();
    water.clear();
    workouts.clear();
    checkIns.clear();
    frozen.clear();
    customPlans.clear();
    notifyListeners();
    await _p?.clear();
  }
}
