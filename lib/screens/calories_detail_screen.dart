import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Opens when you tap the calorie card on Home: today in detail plus a trend.
class CaloriesDetailScreen extends StatefulWidget {
  const CaloriesDetailScreen({super.key});

  @override
  State<CaloriesDetailScreen> createState() => _CaloriesDetailScreenState();
}

class _CaloriesDetailScreenState extends State<CaloriesDetailScreen> {
  int _days = 7;

  String _n(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Calories')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _ring(s),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _macro('Protein', s.proteinToday, s.proteinTarget, const Color(0xFF16A34A))),
                const SizedBox(width: 10),
                Expanded(child: _macro('Carbs', s.carbsToday, s.carbsTarget, const Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Expanded(child: _macro('Fat', s.fatToday, s.fatTarget, const Color(0xFF3B82F6))),
              ],
            ),
            _title('By meal'),
            _byMeal(s),
            _title('Other nutrients today'),
            _others(s),
            _title('Trend'),
            _trend(s),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8, left: 4),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _ring(AppState s) {
    final target = s.kcalTarget.toDouble();
    final eaten = s.kcalToday;
    final p = target <= 0 ? 0.0 : (eaten / target).clamp(0.0, 1.0);
    final left = target - eaten;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: p,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.track,
                    color: eaten > target ? AppColors.warnInk : AppColors.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_n(eaten),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    Text('of ${_n(target)} kcal',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _eq('Goal', _n(target), AppColors.ink),
              _eq('Eaten', _n(eaten), AppColors.ink),
              _eq(left < 0 ? 'Over' : 'Left', _n(left.abs()),
                  left < 0 ? AppColors.warnInk : AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eq(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );

  Widget _macro(String label, double v, int target, Color color) {
    final p = target <= 0 ? 0.0 : (v / target).clamp(0.0, 1.0);
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                      value: p, strokeWidth: 6, backgroundColor: AppColors.track, color: color),
                ),
                Text('${(p * 100).round()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('${v.round()} g', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('$label / $target g', style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _byMeal(AppState s) {
    const icons = {
      'breakfast': Icons.free_breakfast_outlined,
      'lunch': Icons.lunch_dining_outlined,
      'snacks': Icons.cookie_outlined,
      'dinner': Icons.dinner_dining_outlined,
    };
    final today = s.today;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final m in mealOrder)
            Builder(builder: (_) {
              final items = today.where((e) => e.meal == m).toList();
              final kcal = items.fold(0.0, (a, e) => a + e.kcal);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icons[m], color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mealLabels[m] ?? m, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(items.isEmpty ? 'Not logged yet' : items.map((e) => e.name).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text(items.isEmpty ? '-' : '${_n(kcal)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _others(AppState s) {
    final today = s.today;
    final withData = today.where((e) => e.more.isNotEmpty).toList();
    if (withData.isEmpty) {
      return AppCard(
        radius: 22,
        child: Text(
            'Fibre, sugar, sodium, iron and vitamins show up here for food you add with Meal photo. Other foods only have calories and macros.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
      );
    }
    return AppCard(
      radius: 22,
      child: Column(
        children: [
          for (final n in nutrientRows)
            Builder(builder: (_) {
              final key = n[1] as String;
              final v = withData.fold(0.0, (a, e) => a + (e.more[key] ?? 0));
              final ref = n[3] as double;
              final limit = n[4] as bool;
              final p = ref == 0 ? 0.0 : v / ref;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(n[0] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Text('${v >= 10 ? v.round() : v.toStringAsFixed(1)} ${n[2]}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: AppColors.track,
                        color: limit && p > 0.8 ? AppColors.warnInk : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 4),
          Text('Counted only from foods that have these details. Percent of a typical adult\'s daily need.',
              style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _trend(AppState s) {
    final now = DateTime.now();
    final vals = <double>[];
    for (var i = _days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      vals.add(s.entriesOn(d).fold(0.0, (a, e) => a + e.kcal));
    }
    final target = s.kcalTarget.toDouble();
    final top = [target * 1.25, ...vals].reduce((a, b) => a > b ? a : b);
    final logged = vals.where((v) => v > 0).toList();
    final avg = logged.isEmpty ? 0.0 : logged.reduce((a, b) => a + b) / logged.length;
    final within = logged.where((v) => v <= target).length;
    const h = 120.0;
    return Column(
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
          ],
          selected: {_days},
          onSelectionChanged: (v) => setState(() => _days = v.first),
        ),
        const SizedBox(height: 12),
        AppCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Calories per day', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(
                height: h,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < vals.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: _days > 30 ? 0.4 : (_days > 7 ? 1 : 5)),
                              child: Container(
                                height: top <= 0 ? 0 : (vals[i] / top * h).clamp(0.0, h),
                                decoration: BoxDecoration(
                                  color: i == vals.length - 1 ? AppColors.primary : AppColors.primaryLight,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: top <= 0 ? 0 : (target / top * h).clamp(0.0, h),
                      child: Container(height: 1.5, color: AppColors.muted.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  logged.isEmpty
                      ? 'Nothing logged in this time yet.'
                      : 'Average ${_n(avg)} kcal on days you logged. Line is your goal (${_n(target)}).',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          radius: 22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                logged.isEmpty
                    ? 'Log food to see how many days you stay inside your goal.'
                    : '$within of ${logged.length} logged days were inside your goal.',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
