import '../state/app_state.dart';

class PersonalRecord {
  final String exercise;
  final double kg;
  final int reps;
  final bool isNew; // beat everything before this month

  const PersonalRecord(this.exercise, this.kg, this.reps, this.isNew);
}

class MonthReport {
  final DateTime month;
  final int daysInMonth;
  final int workouts;
  final int totalSets;
  final double volumeKg;
  final int loggedDays;
  final double avgKcal;
  final double avgProtein;
  final double proteinConsistency; // 0..1 of logged days that hit the target
  final int proteinDays;
  final double? weightStart;
  final double? weightEnd;
  final List<PersonalRecord> prs;
  final int kcalTarget;
  final int proteinTarget;

  const MonthReport({
    required this.month,
    required this.daysInMonth,
    required this.workouts,
    required this.totalSets,
    required this.volumeKg,
    required this.loggedDays,
    required this.avgKcal,
    required this.avgProtein,
    required this.proteinConsistency,
    required this.proteinDays,
    required this.weightStart,
    required this.weightEnd,
    required this.prs,
    required this.kcalTarget,
    required this.proteinTarget,
  });

  double? get weightChange =>
      (weightStart != null && weightEnd != null) ? weightEnd! - weightStart! : null;

  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get title => '${monthNames[month.month - 1]} ${month.year}';

  static MonthReport build(AppState s, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    bool inMonth(DateTime d) => !d.isBefore(start) && d.isBefore(end);

    // Food
    final kcal = <String, double>{};
    final protein = <String, double>{};
    for (final e in s.entries.where((e) => inMonth(e.at))) {
      final k = AppState.dayKey(e.at);
      kcal[k] = (kcal[k] ?? 0) + e.kcal;
      protein[k] = (protein[k] ?? 0) + e.protein;
    }
    final logged = kcal.length;
    final avgKcal = logged == 0 ? 0.0 : kcal.values.reduce((a, b) => a + b) / logged;
    final avgProtein = logged == 0 ? 0.0 : protein.values.reduce((a, b) => a + b) / logged;
    final hit = protein.values.where((p) => p >= s.proteinTarget * 0.9).length;

    // Workouts
    final ws = s.workouts.where((w) => inMonth(w.at)).toList();
    final sets = ws.fold<int>(0, (n, w) => n + w.sets);
    final vol = ws.fold<double>(0, (n, w) => n + w.volumeKg);

    // Personal records: best weight per exercise this month vs before it.
    final before = <String, double>{};
    final inMon = <String, Map<String, dynamic>>{};
    for (final w in s.workouts) {
      for (final b in w.bests) {
        final name = '${b['name']}';
        final kg = (b['kg'] as num).toDouble();
        final reps = (b['reps'] as num?)?.toInt() ?? 0;
        if (w.at.isBefore(start)) {
          if (kg > (before[name] ?? 0)) before[name] = kg;
        } else if (inMonth(w.at)) {
          final cur = inMon[name];
          if (cur == null || kg > (cur['kg'] as double)) {
            inMon[name] = {'kg': kg, 'reps': reps};
          }
        }
      }
    }
    final prs = [
      for (final e in inMon.entries)
        PersonalRecord(e.key, e.value['kg'] as double, e.value['reps'] as int,
            (e.value['kg'] as double) > (before[e.key] ?? 0)),
    ]..sort((a, b) {
        if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
        return b.kg.compareTo(a.kg);
      });

    // Weight
    final inW = s.weights.where((w) => inMonth(w.at)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    double? wStart, wEnd;
    if (inW.isNotEmpty) {
      wEnd = inW.last.kg;
      final prior = s.weights.where((w) => w.at.isBefore(start)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      wStart = prior.isNotEmpty ? prior.last.kg : inW.first.kg;
    }

    return MonthReport(
      month: start,
      daysInMonth: DateTime(month.year, month.month + 1, 0).day,
      workouts: ws.length,
      totalSets: sets,
      volumeKg: vol,
      loggedDays: logged,
      avgKcal: avgKcal,
      avgProtein: avgProtein,
      proteinConsistency: logged == 0 ? 0 : hit / logged,
      proteinDays: hit,
      weightStart: wStart,
      weightEnd: wEnd,
      prs: prs,
      kcalTarget: s.kcalTarget,
      proteinTarget: s.proteinTarget,
    );
  }
}
