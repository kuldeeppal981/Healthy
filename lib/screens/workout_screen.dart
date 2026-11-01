import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile_models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'workout_data.dart';

class _SetLog {
  final TextEditingController kg;
  final TextEditingController reps;
  bool done = false;

  _SetLog(String repsText)
      : kg = TextEditingController(),
        reps = TextEditingController(text: repsText);

  void dispose() {
    kg.dispose();
    reps.dispose();
  }
}

/// Day-wise workout: pick a day, log sets (kg x reps), rest timer runs after
/// every completed set, and finished sessions are saved to history.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _weekday = DateTime.now().weekday;
  final Map<int, List<List<_SetLog>>> _logs = {};
  Timer? _timer;
  int _rest = 0;

  static const _restSeconds = 90;

  @override
  void dispose() {
    _timer?.cancel();
    for (final day in _logs.values) {
      for (final sets in day) {
        for (final l in sets) {
          l.dispose();
        }
      }
    }
    super.dispose();
  }

  List<List<_SetLog>> _logsFor(int weekday) {
    return _logs.putIfAbsent(weekday, () {
      final plan = planForWeekday(weekday);
      return [
        for (final ex in plan.exercises)
          [for (var i = 0; i < ex.sets; i++) _SetLog('${ex.reps}')],
      ];
    });
  }

  void _resetDay(int weekday) {
    final day = _logs.remove(weekday);
    if (day == null) return;
    // Dispose after the frame so text fields are no longer using them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final sets in day) {
        for (final l in sets) {
          l.dispose();
        }
      }
    });
  }

  void _startRest() {
    _timer?.cancel();
    setState(() => _rest = _restSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_rest <= 1) {
        t.cancel();
        setState(() => _rest = 0);
      } else {
        setState(() => _rest--);
      }
    });
  }

  void _skipRest() {
    _timer?.cancel();
    setState(() => _rest = 0);
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _finish(DayPlan plan, List<List<_SetLog>> logs) {
    var sets = 0;
    var volume = 0.0;
    for (var i = 0; i < plan.exercises.length; i++) {
      final ex = plan.exercises[i];
      for (final l in logs[i]) {
        if (!l.done) continue;
        sets++;
        if (ex.unit == 'reps') {
          final kg = double.tryParse(l.kg.text.trim()) ?? 0;
          final reps = double.tryParse(l.reps.text.trim()) ?? 0;
          volume += kg * reps;
        }
      }
    }

    context.read<AppState>().addWorkout(
          WorkoutLog(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            at: DateTime.now(),
            title: plan.title,
            sets: sets,
            volumeKg: volume,
          ),
        );
    _skipRest();
    _resetDay(_weekday);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workout saved: $sets sets, ${volume.round()} kg lifted')),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = planForWeekday(_weekday);
    final logs = _logsFor(_weekday);
    final total = logs.fold<int>(0, (n, e) => n + e.length);
    final done = logs.fold<int>(0, (n, e) => n + e.where((l) => l.done).length);
    final today = DateTime.now().weekday;
    final history = state.workouts.reversed.take(5).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Text(_weekday == today ? "Today's workout" : 'Workout plan',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              Text(plan.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final wd = i + 1;
                    final sel = wd == _weekday;
                    return ChoiceChip(
                      label: Text(weekdayShort[i]),
                      selected: sel,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        _skipRest();
                        setState(() => _weekday = wd);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (plan.rest)
                const AppCard(
                  child: Text(
                    'Rest day. Take a 20 minute walk, stretch lightly and drink plenty of water.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                )
              else ...[
                AppCard(
                  color: AppColors.ink,
                  borderColor: AppColors.ink,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${plan.exercises.length} exercises',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$done / $total sets',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < plan.exercises.length; i++)
                  _exerciseCard(plan.exercises[i], logs[i]),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Recent workouts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final w in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${w.at.day} ${_months[w.at.month - 1]}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text('${w.sets} sets  |  ${w.volumeKg.round()} kg',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (_rest > 0)
          Container(
            color: AppColors.chipBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text('Rest timer',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.chipInk)),
                const Spacer(),
                Text(_mmss(_rest),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.chipInk)),
                TextButton(onPressed: _skipRest, child: const Text('Skip')),
              ],
            ),
          ),
        if (!plan.rest)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: done == 0 ? null : () => _finish(plan, logs),
              child: const Text('Finish workout'),
            ),
          ),
      ],
    );
  }

  Widget _exerciseCard(Exercise ex, List<_SetLog> sets) {
    final allDone = sets.every((l) => l.done);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 18,
        borderColor: allDone ? AppColors.safe : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (allDone)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle, color: AppColors.safe),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(ex.target,
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(width: 36, child: Text('Set', style: _head)),
                Expanded(child: Text('Kg', style: _head)),
                SizedBox(width: 8),
                Expanded(child: Text('Reps / sec', style: _head)),
                SizedBox(width: 56),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < sets.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(child: _numField(sets[i].kg, hint: '0')),
                    const SizedBox(width: 8),
                    Expanded(child: _numField(sets[i].reps)),
                    SizedBox(
                      width: 56,
                      child: Checkbox(
                        value: sets[i].done,
                        activeColor: AppColors.primary,
                        onChanged: (v) {
                          setState(() => sets[i].done = v ?? false);
                          if (v == true) _startRest();
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _head =
      TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700);

  Widget _numField(TextEditingController c, {String? hint}) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
