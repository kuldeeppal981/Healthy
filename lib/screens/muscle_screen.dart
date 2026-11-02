import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_library.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _muscleColors = <String, Color>{
  'Chest': Color(0xFF7C3AED),
  'Back': Color(0xFF2563EB),
  'Shoulders': Color(0xFF0EA5E9),
  'Biceps': Color(0xFF10B981),
  'Triceps': Color(0xFFF59E0B),
  'Legs': Color(0xFFEF4444),
  'Core': Color(0xFFEC4899),
};

/// Weekly (or monthly) training sets per muscle group.
class MuscleScreen extends StatefulWidget {
  const MuscleScreen({super.key});

  @override
  State<MuscleScreen> createState() => _MuscleScreenState();
}

class _MuscleScreenState extends State<MuscleScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days - 1));
    final logs = a.workouts.where((w) => !w.at.isBefore(from)).toList();

    final sets = <String, int>{for (final m in trackedMuscles) m: 0};
    var volume = 0.0;
    var oldSets = 0;
    for (final w in logs) {
      volume += w.volumeKg;
      if (w.muscleSets.isEmpty) {
        oldSets += w.sets;
      }
      w.muscleSets.forEach((k, v) {
        if (sets.containsKey(k)) sets[k] = sets[k]! + v;
      });
    }
    final total = sets.values.fold<int>(0, (x, y) => x + y);
    final trained = sets.values.where((v) => v > 0).length;
    final maxSets = sets.values.fold<int>(0, math.max);
    final missing = [for (final m in trackedMuscles) if (sets[m] == 0) m];

    return Scaffold(
      appBar: AppBar(title: const Text('Muscle volume')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('Last 7 days')),
              ButtonSegment(value: 30, label: Text('Last 30 days')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Muscle distribution',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Completed sets per muscle group',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  width: 200,
                  child: CustomPaint(
                    painter: _DonutPainter(sets, total),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                          const Text('sets', style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stat('Workouts', '${logs.length}')),
              const SizedBox(width: 10),
              Expanded(child: _stat('Muscles hit', '$trained / ${trackedMuscles.length}')),
              const SizedBox(width: 10),
              Expanded(child: _stat('Volume', '${volume.round()} kg')),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                for (final m in trackedMuscles) _bar(m, sets[m]!, maxSets, total),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              total == 0
                  ? 'No muscle data yet. Finish a workout and your sets will show here.'
                  : missing.isEmpty
                      ? 'Nice, you trained every muscle group in this period.'
                      : 'Not trained yet: ${missing.join(', ')}. Try adding one exercise for these.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (oldSets > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$oldSets sets from older workouts are not counted, because muscle data was not saved for them. '
              'Custom exercises that are not in the library are not counted either.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'General guide: many people train each muscle about 10 sets a week. Not medical advice.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _bar(String m, int v, int maxSets, int total) {
    final pct = total == 0 ? 0 : (v * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _muscleColors[m], shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 78, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: maxSets == 0 ? 0 : v / maxSets,
                minHeight: 8,
                color: _muscleColors[m],
                backgroundColor: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('$v sets  $pct%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> sets;
  final int total;

  _DonutPainter(this.sets, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.primary.withOpacity(0.08);
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final m in trackedMuscles) {
      final v = sets[m] ?? 0;
      if (v == 0) continue;
      final sweep = math.pi * 2 * v / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _muscleColors[m] ?? AppColors.primary;
      canvas.drawArc(rect, start, math.max(sweep - 0.03, 0.01), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
