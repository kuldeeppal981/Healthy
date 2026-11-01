import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// App-wide state, saved on the phone with shared_preferences.
class AppState extends ChangeNotifier {
  SharedPreferences? _p;

  final Set<String> allergies = {};
  final Map<String, String> severity = {}; // allergen id -> mild|medium|severe
  bool traceWarning = true;

  int kcalTarget = 1850;
  int proteinTarget = 110;
  int carbsTarget = 220;
  int fatTarget = 60;
  int waterTarget = 8;

  final List<DiaryEntry> entries = [];
  final Map<String, int> water = {}; // yyyy-mm-dd -> glasses

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;

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
    final w = p.getString('water');
    if (w != null) {
      water.addAll(Map<String, int>.from(jsonDecode(w) as Map));
    }
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    await p.setStringList('allergies', allergies.toList());
    await p.setString('severity', jsonEncode(severity));
    await p.setBool('traceWarning', traceWarning);
    await p.setInt('kcalTarget', kcalTarget);
    await p.setInt('proteinTarget', proteinTarget);
    await p.setInt('carbsTarget', carbsTarget);
    await p.setInt('fatTarget', fatTarget);
    await p.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setString('water', jsonEncode(water));
  }

  void _changed() {
    notifyListeners();
    _save();
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
    return entries
        .where((e) =>
            e.at.year == now.year && e.at.month == now.month && e.at.day == now.day)
        .toList();
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

  // ---- Water ----
  int get waterToday => water[dayKey(DateTime.now())] ?? 0;

  void addWater(int delta) {
    final k = dayKey(DateTime.now());
    final next = (waterToday + delta).clamp(0, 30);
    water[k] = next;
    _changed();
  }

  // ---- Targets ----
  void setTargets({int? kcal, int? protein, int? carbs, int? fat}) {
    kcalTarget = kcal ?? kcalTarget;
    proteinTarget = protein ?? proteinTarget;
    carbsTarget = carbs ?? carbsTarget;
    fatTarget = fat ?? fatTarget;
    _changed();
  }

  Future<void> clearAll() async {
    allergies.clear();
    severity.clear();
    entries.clear();
    water.clear();
    notifyListeners();
    await _p?.clear();
  }
}
