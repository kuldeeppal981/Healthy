import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../state/app_state.dart';

class WeeklyReviewData {
  final String headline;
  final List<String> wentWell;
  final List<String> improve;
  final List<String> steps;
  const WeeklyReviewData(this.headline, this.wentWell, this.improve, this.steps);

  Map<String, dynamic> toJson() =>
      {'headline': headline, 'well': wentWell, 'improve': improve, 'steps': steps};

  static WeeklyReviewData? fromJson(Object? j) {
    if (j is! Map) return null;
    List<String> l(Object? x) => x is List ? x.map((e) => '$e').toList() : <String>[];
    final steps = l(j['steps']);
    if (steps.isEmpty) return null;
    return WeeklyReviewData('${j['headline'] ?? ''}', l(j['well']), l(j['improve']), steps);
  }
}

class WeeklyException implements Exception {
  final String message;
  WeeklyException(this.message);
  @override
  String toString() => message;
}

/// Numbers for the last 7 days, taken from the diary.
class WeekStats {
  final DateTime from;
  final DateTime to;
  final int daysLogged;
  final double avgKcal;
  final double avgProtein;
  final int goalDays;
  final int proteinDays;
  final List<double> perDay; // oldest first, 7 values
  const WeekStats(this.from, this.to, this.daysLogged, this.avgKcal, this.avgProtein,
      this.goalDays, this.proteinDays, this.perDay);

  static WeekStats of(AppState s) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final per = <double>[];
    var logged = 0, goal = 0, prot = 0;
    var kSum = 0.0, pSum = 0.0;
    for (var i = 6; i >= 0; i--) {
      final d = end.subtract(Duration(days: i));
      final es = s.entriesOn(d);
      final k = es.fold(0.0, (a, e) => a + e.kcal);
      final p = es.fold(0.0, (a, e) => a + e.protein);
      per.add(k);
      if (es.isNotEmpty) {
        logged++;
        kSum += k;
        pSum += p;
        if (k <= s.kcalTarget * 1.05) goal++;
        if (p >= s.proteinTarget * 0.9) prot++;
      }
    }
    return WeekStats(end.subtract(const Duration(days: 6)), end, logged,
        logged == 0 ? 0 : kSum / logged, logged == 0 ? 0 : pSum / logged, goal, prot, per);
  }

  /// Plain text sent to the AI. No name, email or photos, only numbers and food names.
  String toPrompt(AppState s) {
    final b = StringBuffer()
      ..writeln('Last 7 days (oldest first). Calorie goal: ${s.kcalTarget} kcal. Protein goal: ${s.proteinTarget} g.')
      ..writeln('Days with food logged: $daysLogged of 7.')
      ..writeln('Average calories on logged days: ${avgKcal.round()}. Average protein: ${avgProtein.round()} g.')
      ..writeln('Days within calorie goal: $goalDays. Days protein goal met: $proteinDays.')
      ..writeln('Calories per day: ${perDay.map((v) => v.round()).join(', ')}.');
    final goal = s.profile?.goal;
    if (goal != null) b.writeln('Goal: $goal weight.');
    if (s.allergies.isNotEmpty) b.writeln('Allergies: ${s.allergies.join(', ')}.');
    // most logged foods
    final count = <String, int>{};
    for (var i = 0; i < 7; i++) {
      for (final e in s.entriesOn(to.subtract(Duration(days: i)))) {
        final n = e.name.replaceFirst(RegExp(r'^[0-9.]+ x '), '');
        count[n] = (count[n] ?? 0) + 1;
      }
    }
    final top = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      b.writeln('Most logged foods: ${top.take(8).map((e) => '${e.key} (${e.value}x)').join(', ')}.');
    }
    // meals by slot
    for (final m in mealOrder) {
      var n = 0;
      for (var i = 0; i < 7; i++) {
        if (s.entriesOn(to.subtract(Duration(days: i))).any((e) => e.meal == m)) n++;
      }
      b.writeln('Days with ${mealLabels[m]}: $n.');
    }
    return b.toString();
  }
}

class WeeklyReviewService {
  static Future<WeeklyReviewData> make(AppState s) async {
    final stats = WeekStats.of(s);
    if (stats.daysLogged == 0) {
      throw WeeklyException('Log some food this week first, then come back for your review.');
    }
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions
          .invoke('coach', body: {'mode': 'weekly', 'summary': stats.toPrompt(s)});
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      throw WeeklyException(
          d is Map && d['message'] != null ? d['message'].toString() : 'Could not make the review. Try again.');
    } catch (_) {
      throw WeeklyException('No internet or sign-in problem. Try again.');
    }
    final w = WeeklyReviewData.fromJson({
      'headline': data['weekly']?['headline'],
      'well': data['weekly']?['went_well'],
      'improve': data['weekly']?['improve'],
      'steps': data['weekly']?['steps'],
    });
    if (w == null) throw WeeklyException('Could not make the review. Try again.');
    return w;
  }
}
