import 'dart:async';

import 'package:flutter/material.dart';

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

/// Day-wise workout: pick a day, log sets (kg x reps), rest timer runs
/// after every completed set. (Logs live in memory for now.)
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

  @override
  Widget build(BuildContext context) {
    final plan = planForWeekday(_weekday);
    final logs = _logsFor(_weekday);
    final total = logs.fold<int>(0, (n, e) => n + e.length);
    final done = logs.fold<int>(0, (n, e) => n + e.where((l) => l.done).length);
    final today = DateTime.now().weekday;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Text(_weekday == today ? 'Aaj ka workout' : 'Workout plan',
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
                    'Aaj rest day hai. 20 min walk aur halki stretching karo, paani zyada piyo.',
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
              onPressed: done == 0
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Shabash! $done sets complete hue.')),
                      );
                    },
              child: const Text('Workout finish karo'),
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
            Row(
              children: const [
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
