import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile_models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/reminder_service.dart';
import '../services/social_service.dart';
import '../services/voice_parser.dart';
import '../widgets/muscle_art.dart';
import '../widgets/ui_kit.dart';
import '../widgets/voice_capture.dart';
import '../data/exercise_library.dart';
import 'exercise_library_screen.dart';
import 'plan_editor.dart';
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
  bool _logging = false; // false: plan overview, true: logging sets

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

  List<List<_SetLog>> _logsFor(int weekday, DayPlan plan) {
    return _logs.putIfAbsent(weekday, () {
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

  /// "bench press 40 kilo 8 reps" fills the next open set of that exercise.
  Future<void> _voiceSet(AppState state) async {
    final plan = state.planFor(_weekday);
    if (plan.rest || plan.exercises.isEmpty) return;
    final text = await showVoiceCapture(context, hint: 'Say your set');
    if (text == null || !mounted) return;
    final v = parseWorkoutVoice(text, [for (final e in plan.exercises) e.name]);
    final msg = ScaffoldMessenger.of(context);
    if (v == null) {
      msg.showSnackBar(const SnackBar(
          content: Text('Could not find that exercise in today\'s plan.')));
      return;
    }
    final sets = _logsFor(_weekday, plan)[v.exerciseIndex];
    final open = sets.where((l) => !l.done).toList();
    if (open.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('All sets of that exercise are done.')));
      return;
    }
    final l = open.first;
    setState(() {
      _logging = true;
      if (v.kg != null) l.kg.text = v.kg! == v.kg!.roundToDouble() ? '${v.kg!.round()}' : '${v.kg}';
      if (v.reps != null) l.reps.text = '${v.reps}';
      l.done = true;
    });
    _startRest();
    msg.showSnackBar(SnackBar(
      content: Text('${plan.exercises[v.exerciseIndex].name}: ${v.kg ?? 0} kg x ${v.reps ?? l.reps.text} logged'),
    ));
  }

  Future<void> _toggleAlarm(AppState state, bool on) async {
    final svc = ReminderService.instance;
    if (on) {
      final ok = await svc.askPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Allow notifications for Healthy in your phone settings.'),
        ));
        return;
      }
      final exact = await svc.askExactAlarm();
      if (!exact && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Allow "Alarms and reminders" for Healthy so the alarm rings on time.'),
        ));
      }
    }
    svc.workout.enabled = on;
    await svc.apply(state);
    if (mounted) setState(() {});
  }

  Future<void> _pickAlarmTime(AppState state) async {
    final svc = ReminderService.instance;
    final t = await showTimePicker(context: context, initialTime: svc.workout.time);
    if (t == null) return;
    svc.workout.time = t;
    if (!svc.workout.enabled) {
      await _toggleAlarm(state, true);
    } else {
      await svc.apply(state);
      if (mounted) setState(() {});
    }
  }

  Widget _alarmCard(AppState state) {
    final w = ReminderService.instance.workout;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.alarm, color: AppColors.primary),
          ),
          const SizedBox(width: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily gym alarm',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  w.enabled
                      ? 'Rings at ${w.time.format(context)} on workout days'
                      : 'Off',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickAlarmTime(state),
            child: Text(w.enabled ? 'Change' : 'Set time'),
          ),
          Switch(
            value: w.enabled,
            activeColor: AppColors.primary,
            onChanged: (v) => _toggleAlarm(state, v),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(AppState state) async {
    final day = _weekday;
    final result = await showModalBottomSheet<DayPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlanEditor(
        dayName: _dayNames[day - 1],
        plan: state.planFor(day),
        isCustom: state.isCustomPlan(day),
        onReset: () {
          _skipRest();
          _resetDay(day);
          state.resetPlan(day);
          ReminderService.instance.reschedule(state);
        },
      ),
    );
    if (result == null || !mounted) return;
    _skipRest();
    _resetDay(day);
    state.saveCustomPlan(day, result);
    ReminderService.instance.reschedule(state);
  }

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

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
    final bests = <Map<String, dynamic>>[];
    final muscleSets = <String, int>{};
    for (var i = 0; i < plan.exercises.length; i++) {
      final ex = plan.exercises[i];
      double bestKg = 0;
      int bestReps = 0;
      for (final l in logs[i]) {
        if (!l.done) continue;
        sets++;
        final m = muscleOf(ex.name);
        if (m != null) muscleSets[m] = (muscleSets[m] ?? 0) + 1;
        if (ex.unit == 'reps') {
          final kg = double.tryParse(l.kg.text.trim()) ?? 0;
          final reps = double.tryParse(l.reps.text.trim()) ?? 0;
          volume += kg * reps;
          if (kg > bestKg || (kg == bestKg && reps > bestReps)) {
            bestKg = kg;
            bestReps = reps.round();
          }
        }
      }
      if (bestKg > 0) {
        bests.add({'name': ex.name, 'kg': bestKg, 'reps': bestReps});
      }
    }

    final state = context.read<AppState>();
    final prs = findNewPrs(state.workouts, bests);
    final now = DateTime.now();
    final stamp = SocialService.dayText(now);
    for (final pr in prs) {
      SocialService.instance.postAchievement(
        kind: 'pr',
        title: 'New PR: ${pr.exercise} ${pr.text}',
        body: pr.previousKg == null
            ? null
            : 'Previous best was ${pr.previousKg == pr.previousKg!.roundToDouble() ? pr.previousKg!.round() : pr.previousKg} kg',
        dedupe: 'pr-${pr.exercise.toLowerCase()}-$stamp',
      );
    }
    if (sets > 0) {
      SocialService.instance.postAchievement(
        kind: 'workout',
        title: 'Finished ${plan.title}',
        body: '$sets sets, ${volume.round()} kg lifted',
        dedupe: 'workout-${now.microsecondsSinceEpoch}',
      );
    }
    state.addWorkout(
          WorkoutLog(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            at: DateTime.now(),
            title: plan.title,
            sets: sets,
            volumeKg: volume,
            bests: bests,
            muscleSets: muscleSets,
          ),
        );
    _skipRest();
    _resetDay(_weekday);
    setState(() => _logging = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prs.isEmpty
            ? 'Workout saved: $sets sets, ${volume.round()} kg lifted'
            : 'New PR! ${prs.map((e) => '${e.exercise} ${e.text}').join(', ')}'),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.planFor(_weekday);
    final logs = _logsFor(_weekday, plan);
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
              _header(state, plan, today),
              const SizedBox(height: 16),
              _dayChips(),
              const SizedBox(height: 14),
              _alarmCard(state),
              const SizedBox(height: 14),
              if (plan.rest)
                const AppCard(
                  child: Text(
                    'Rest day. Take a 20 minute walk, stretch lightly and drink plenty of water. Tap Edit to plan a workout for this day instead.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                )
              else ...[
                _banner(plan, done, total),
                const SizedBox(height: 14),
                if (_logging)
                  for (var i = 0; i < plan.exercises.length; i++)
                    _exerciseCard(plan.exercises[i], logs[i])
                else
                  _planCard(plan, logs),
                const SizedBox(height: 14),
                _tipCard(),
                const SizedBox(height: 14),
                _progressCard(state),
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
                          Text(w.sets == 0 ? 'Synced' : '${w.sets} sets  |  ${w.volumeKg.round()} kg',
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
                Text('Rest timer',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.chipInk)),
                const Spacer(),
                Text(_mmss(_rest),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.chipInk)),
                TextButton(onPressed: _skipRest, child: const Text('Skip')),
              ],
            ),
          ),
        if (!plan.rest && _logging)
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

  Widget _header(AppState state, DayPlan plan, int today) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primaryDeep],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_weekday == today ? "Today's workout" : 'Workout plan',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              Text(plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(
                state.isCustomPlan(_weekday)
                    ? 'Your own plan'
                    : (plan.rest ? 'Recover well' : 'Build stronger today'),
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
        if (_logging)
          IconButton(
            tooltip: 'Log a set by voice',
            onPressed: () => _voiceSet(state),
            icon: Icon(Icons.mic, color: AppColors.primary),
          ),
        FilledButton.tonalIcon(
          onPressed: () => _edit(state),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        ),
      ],
    );
  }

  Widget _dayChips() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final wd = i + 1;
          final sel = wd == _weekday;
          final d = monday.add(Duration(days: i));
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              _skipRest();
              setState(() {
                _weekday = wd;
                _logging = false;
              });
            },
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryLight, AppColors.primaryDeep],
                      )
                    : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel ? Colors.transparent : AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekdayShort[i],
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('${_months[d.month - 1]} ${d.day}',
                      style: TextStyle(
                          fontSize: 12, color: sel ? Colors.white70 : AppColors.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _banner(DayPlan plan, int done, int total) {
    final mins = estimateMinutes(plan);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: 96,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.55,
                child: AppImage('assets/images/hero.png', fit: BoxFit.fitHeight),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${plan.exercises.length} exercises \u2022 $mins min',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  _logging
                      ? '$done of $total sets done'
                      : 'Complete your workout today',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => setState(() => _logging = !_logging),
            icon: Icon(_logging ? Icons.list_alt : Icons.play_arrow, size: 20),
            label: Text(_logging ? 'Plan' : (done > 0 ? 'Continue' : 'Start')),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDeep,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

  IconData _groupIcon(String name) {
    final g = findExercise(name)?.group;
    return switch (g) {
      'Legs' => Icons.directions_run,
      'Core' => Icons.self_improvement,
      'Cardio' => Icons.favorite_outline,
      'Back' => Icons.accessibility_new,
      'Arms' => Icons.sports_martial_arts,
      'Shoulders' => Icons.sports_gymnastics,
      _ => Icons.fitness_center,
    };
  }

  /// Photos exist only for a few exercises; others get a muscle-group icon.
  static const _photos = {
    'bench press': 'ex1',
    'dumbbell bench press': 'ex1',
    'incline dumbbell press': 'ex2',
    'incline dumbbell bench press': 'ex2',
    'triceps pushdown': 'ex3',
    'triceps rope pushdown': 'ex3',
    'overhead triceps extension': 'ex4',
  };

  Widget _thumb(String name) {
    final photo = _photos[name.trim().toLowerCase()];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: photo != null
          ? AppImage('assets/images/$photo.jpg', width: 72, height: 52, fit: BoxFit.cover)
          : MuscleTile(muscle: muscleOf(name), icon: _groupIcon(name)),
    );
  }

  Widget _planCard(DayPlan plan, List<List<_SetLog>> logs) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.format_list_bulleted, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Workout Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => setState(() => _logging = true),
                style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                child: const Text('Log sets  \u2192',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          for (var i = 0; i < plan.exercises.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final info = findExercise(plan.exercises[i].name);
                if (info != null) {
                  openExercise(context, info);
                } else {
                  setState(() => _logging = true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _thumb(plan.exercises[i].name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.exercises[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(plan.exercises[i].target,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Icon(
                      logs[i].every((l) => l.done)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: logs[i].every((l) => l.done)
                          ? AppColors.safe
                          : AppColors.muted,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _tips = [
    'Focus on good form and controlled reps for better muscle growth.',
    'Warm up for 5 minutes before your first set.',
    'Drink water between sets and rest 60 to 90 seconds.',
    'Add a little weight or one more rep each week.',
    'Sleep 7 to 8 hours. Muscles grow while you rest.',
    'Eat protein within a couple of hours after training.',
    'Stop a set if your form breaks down or something hurts.',
  ];

  Widget _tipCard() {
    return AppCard(
      color: AppColors.chipBg,
      borderColor: AppColors.chipBg,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pro Tip',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep)),
                const SizedBox(height: 2),
                Text(_tips[(_weekday - 1) % _tips.length],
                    style: TextStyle(
                        fontSize: 14, color: AppColors.chipInk, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppImage('assets/images/shaker.png', height: 74, fit: BoxFit.contain),
        ],
      ),
    );
  }

  Widget _progressCard(AppState state) {
    final goal = [
      for (var d = 1; d <= 7; d++)
        if (!state.planFor(d).rest) d,
    ].length;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final kg = state.workouts
        .where((w) => !w.at.isBefore(start))
        .fold<double>(0, (n, w) => n + w.volumeKg);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Your Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('This week',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${state.workoutsThisWeek} / $goal',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const Text('Workouts completed',
                        style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  ],
                ),
              ),
              Container(width: 1, height: 52, color: AppColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${kg.round()} kg',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const Text('Total lifted',
                        style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  ],
                ),
              ),
              AppImage('assets/images/trophy.png', width: 54, fit: BoxFit.contain),
            ],
          ),
        ],
      ),
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
                if (findExercise(ex.name) != null)
                  IconButton(
                    tooltip: 'How to do it',
                    icon: Icon(Icons.help_outline, color: AppColors.primary),
                    onPressed: () => openExercise(context, findExercise(ex.name)!),
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
                          if (v == true) {
                            Haptic.done();
                            _startRest();
                          }
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
