import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/muscle_stats.dart';
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/bar_chart.dart';
import '../widgets/muscle_activity.dart';
import '../widgets/sparkline.dart';
import '../services/units.dart';

/// The Analytics tab: calories, macros, protein, weight, workouts, steps,
/// water and muscle volume, for the last 7 or 30 days.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 7;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _blue = Color(0xFF2563EB);
  static const _sky = Color(0xFF0EA5E9);
  static const _amber = Color(0xFFF59E0B);
  static const _violet = Color(0xFF7C3AED);

  String _fmt(num n) => n
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  double _avg(List<double> v) {
    final used = v.where((x) => x > 0).toList();
    if (used.isEmpty) return 0;
    return used.fold<double>(0, (a, b) => a + b) / used.length;
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final now = DateTime.now();
    final days = [
      for (var i = _days - 1; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];
    final labels = [
      for (final d in days) _days <= 7 ? _weekdays[d.weekday - 1] : '${d.day}',
    ];

    // Food per day: kcal, protein, carbs, fat.
    final food = <String, List<double>>{};
    for (final e in a.entries) {
      if (e.at.isBefore(days.first)) continue;
      final l = food.putIfAbsent(AppState.dayKey(e.at), () => <double>[0, 0, 0, 0]);
      l[0] += e.kcal;
      l[1] += e.protein;
      l[2] += e.carbs;
      l[3] += e.fat;
    }
    List<double> series(int i) =>
        [for (final d in days) (food[AppState.dayKey(d)]?[i] ?? 0).toDouble()];
    final kcal = series(0);
    final protein = series(1);
    final carbs = series(2);
    final fat = series(3);

    final water = [for (final d in days) (a.water[AppState.dayKey(d)] ?? 0).toDouble()];
    final steps = [
      for (final e in StepService.instance.lastDays(_days)) e.value.toDouble(),
    ];
    final sessions = [
      for (final d in days)
        a.workouts.where((w) => AppState.sameDay(w.at, d)).length.toDouble(),
    ];

    final ms = MuscleStats.compute(a, _days);

    final loggedDays = kcal.where((x) => x > 0).length;
    final onTarget = kcal
        .where((x) => x >= a.kcalTarget * 0.8 && x <= a.kcalTarget * 1.1)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('Your progress at a glance',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _tile(Icons.local_fire_department_outlined, _fmt(_avg(kcal)), 'Avg kcal a day'),
            const SizedBox(width: 8),
            _tile(Icons.check_circle_outline, '$onTarget / $_days', 'Days on target'),
            const SizedBox(width: 8),
            _tile(Icons.fitness_center, '${ms.workouts}', 'Workouts'),
          ],
        ),
        const SizedBox(height: 12),
        BarChartCard(
          title: 'Calories',
          icon: Icons.local_fire_department_outlined,
          summary: loggedDays == 0 ? 'No data' : 'Avg ${_fmt(_avg(kcal))} kcal',
          values: kcal,
          labels: labels,
          target: a.kcalTarget.toDouble(),
          color: AppColors.primary,
          note: loggedDays == 0
              ? 'Log your meals in the Diary to see this chart.'
              : 'Dashed line is your goal of ${_fmt(a.kcalTarget)} kcal. Logged on $loggedDays of $_days days.',
        ),
        const SizedBox(height: 12),
        _macroCard(carbs, protein, fat),
        const SizedBox(height: 12),
        BarChartCard(
          title: 'Protein',
          icon: Icons.egg_alt_outlined,
          summary: _avg(protein) == 0 ? 'No data' : 'Avg ${_fmt(_avg(protein))} g',
          values: protein,
          labels: labels,
          target: a.proteinTarget.toDouble(),
          color: _blue,
          note: 'Goal: ${a.proteinTarget} g a day.',
        ),
        const SizedBox(height: 12),
        _weightCard(a, days.first),
        const SizedBox(height: 12),
        BarChartCard(
          title: 'Workouts',
          icon: Icons.fitness_center,
          summary: '${ms.workouts} in $_days days',
          values: sessions,
          labels: labels,
          color: _violet,
          showValues: false,
          note: ms.volume > 0 ? 'Total lifted: ${_fmt(ms.volume)} kg.' : 'Finish a workout to see it here.',
        ),
        const SizedBox(height: 12),
        BarChartCard(
          title: 'Steps',
          icon: Icons.directions_walk,
          summary: _avg(steps) == 0 ? 'No data' : 'Avg ${_fmt(_avg(steps))}',
          values: steps,
          labels: labels,
          target: 10000,
          color: _amber,
          showValues: false,
          note: 'Dashed line is 10,000 steps.',
        ),
        const SizedBox(height: 12),
        BarChartCard(
          title: 'Water',
          icon: Icons.water_drop_outlined,
          summary: _avg(water) == 0 ? 'No data' : 'Avg ${_avg(water).toStringAsFixed(1)} glasses',
          values: water,
          labels: labels,
          target: a.waterTarget.toDouble(),
          color: _sky,
          note: 'Goal: ${a.waterTarget} glasses a day.',
        ),
        const SizedBox(height: 20),
        const Text('Muscle volume',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        MuscleStatTiles(stats: ms),
        const SizedBox(height: 12),
        MuscleActivitySection(sets: ms.sets),
        const SizedBox(height: 14),
        Text(
          'Charts show what you logged. They are general guidance, not medical advice.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String value, String label) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _macroCard(List<double> carbs, List<double> protein, List<double> fat) {
    final c = carbs.fold<double>(0, (x, y) => x + y) * 4;
    final p = protein.fold<double>(0, (x, y) => x + y) * 4;
    final f = fat.fold<double>(0, (x, y) => x + y) * 9;
    final total = c + p + f;
    final parts = <(String, double, Color)>[
      ('Carbs', c, _amber),
      ('Protein', p, _blue),
      ('Fat', f, const Color(0xFFEC4899)),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.pie_chart_outline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Where your calories come from',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (total == 0)
            Text('Log your meals to see your carbs, protein and fat split.',
                style: TextStyle(fontSize: 13, color: AppColors.muted))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    for (final x in parts)
                      if (x.$2 > 0)
                        Expanded(
                          flex: (x.$2 * 100 / total).round().clamp(1, 100).toInt(),
                          child: Container(color: x.$3),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final x in parts)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: x.$3, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${x.$1} ${(x.$2 * 100 / total).round()}%',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightCard(AppState a, DateTime from) {
    final all = [...a.weights]..sort((x, y) => x.at.compareTo(y.at));
    var shown = all.where((w) => !w.at.isBefore(from)).toList();
    if (shown.length < 2 && all.length >= 2) {
      shown = all.sublist(all.length - (all.length < 10 ? all.length : 10));
    }
    final change = shown.length >= 2 ? shown.last.kg - shown.first.kg : 0.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.monitor_weight_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Weight',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (shown.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shown.length >= 2
                        ? Units.instance.weightChange(change)
                        : Units.instance.weight(shown.last.kg),
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.chipInk),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.length < 2)
            Text(
              'Add your weight from the Home screen on two different days to see the trend.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else
            Sparkline(values: [for (final w in shown) w.kg], color: AppColors.primary),
        ],
      ),
    );
  }
}
