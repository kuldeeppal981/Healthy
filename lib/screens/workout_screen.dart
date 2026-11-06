import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile_models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/reminder_service.dart';
import '../services/social_service.dart';
import '../services/voice_parser.dart';
import '../widgets/celebrate.dart';
import '../widgets/muscle_art.dart';
import '../widgets/activity_art.dart';
import '../widgets/ui_kit.dart';
import '../widgets/voice_capture.dart';
import '../data/exercise_library.dart';
import 'exercise_library_screen.dart';
import 'form_check_screen.dart';
import 'training_status_screen.dart';
import '../services/training_stats.dart';
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

  /// Shortened plans for today only: weekday -> exercises kept.
  final Map<int, DayPlan> _short = {};

  /// Exercises swapped for today only: weekday -> (exercise index -> new name).
  final Map<int, Map<int, String>> _swaps = {};

  /// The plan for a day with today's swaps applied.
  /// The plan before swaps: the shortened one if it is on, else the saved plan.
  DayPlan _basePlan(AppState state, int weekday) => _short[weekday] ?? state.planFor(weekday);

  DayPlan _plan(AppState state, int weekday) {
    final base = _basePlan(state, weekday);
    final sw = _swaps[weekday];
    if (sw == null || sw.isEmpty) return base;
    return DayPlan(
      base.title,
      [
        for (var i = 0; i < base.exercises.length; i++)
          sw[i] == null
              ? base.exercises[i]
              : Exercise(sw[i]!, base.exercises[i].sets, base.exercises[i].reps,
                  unit: base.exercises[i].unit),
      ],
      rest: base.rest,
    );
  }

  /// Machine busy? Shows other exercises for the same muscle and swaps for today.
  Future<void> _pickAlternative(int index, Exercise ex, List<_SetLog> sets) async {
    final have = context.read<AppState>().equipmentPref;
    final alts = alternativesFor(ex.name, equipmentHave: have);
    final muscle = muscleOf(ex.name);
    final plannedName =
        _basePlan(context.read<AppState>(), _weekday).exercises[index].name;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Text('Machine busy?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                  alts.isEmpty
                      ? 'No alternatives found for ${ex.name}.'
                      : 'Other exercises for ${muscle ?? findExercise(ex.name)?.group ?? 'the same muscle'}. Only for today, your plan stays the same.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 10),
              if (ex.name != plannedName)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.undo, color: AppColors.primary),
                  title: Text('Back to planned: $plannedName'),
                  onTap: () => Navigator.pop(ctx, plannedName),
                ),
              for (final a in alts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_horiz, color: AppColors.primary),
                  title: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${a.equipment}  |  ${a.level}  |  Main: ${a.primary}${equipmentFits(a.equipment, have) ? '' : '  |  needs more equipment'}',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, a.name),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final day = _swaps.putIfAbsent(_weekday, () => {});
      if (picked == plannedName) {
        day.remove(index);
      } else {
        day[index] = picked;
      }
      // Weights differ between exercises, so clear the kg of sets not done yet.
      for (final l in sets) {
        if (!l.done) l.kg.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Using $picked for today.')));
  }

  /// "I only have 30 minutes": suggests a shorter version of today's plan.
  Future<void> _askShort(AppState state, int weekday) async {
    final plan = state.planFor(weekday);
    if (plan.rest || plan.exercises.isEmpty) return;
    final ov = TrainingOverview.compute(state);
    final full = estimateMinutes(plan);
    var minutes = full > 30 ? 30 : (full > 20 ? 20 : 15);
    final picked = await showModalBottomSheet<ShortPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final sp = shortenPlan(plan, minutes, ov);
          return SafeArea(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  Text('Short on time?',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text('Planned workout is about $full min. How much time do you have?',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [15, 20, 30, 45])
                        if (m < full)
                          ChoiceChip(
                            label: Text('$m min'),
                            selected: minutes == m,
                            onSelected: (_) => setLocal(() => minutes = m),
                          ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Short plan, about ${sp.minutes} min',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final e in sp.plan.exercises)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle_outline, color: AppColors.primary),
                      title: Text(e.name),
                      subtitle: Text(e.target),
                    ),
                  if (sp.dropped.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Skipped today: ${sp.dropped.join(', ')}',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                      'Big lifts and rested muscles come first. Your saved plan does not change.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: sp.plan.exercises.isEmpty ? null : () => Navigator.pop(ctx, sp),
                    child: const Text('Use this short plan'),
                  ),
                  if (_short.containsKey(weekday))
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetDay(weekday);
                        setState(() {});
                      },
                      child: const Text('Back to full plan'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    // New exercise list means new set rows: start the day's log fresh.
    _resetDay(weekday);
    setState(() {
      _short[weekday] = picked.plan;
      _logging = false;
    });
  }

  Widget _trainingCard(AppState state) {
    final ov = TrainingOverview.compute(state);
    final ready = [for (final m in ov.muscles) if (m.everTrained && m.ready) m.muscle];
    final rec = [for (final m in ov.muscles) if (m.everTrained && !m.ready) m];
    return AppCard(
      radius: 18,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TrainingStatusScreen())),
        child: Row(
          children: [
            Icon(Icons.monitor_heart_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Training status',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    ov.muscles.every((m) => !m.everTrained)
                        ? 'Log workouts to see last trained, weekly sets and recovery estimate'
                        : '${ready.isEmpty ? '' : 'Likely ready: ${ready.take(3).join(', ')}. '}${rec.isEmpty ? '' : 'Recovering: ${rec.take(2).map((m) => '${m.muscle} (~${m.hoursLeft} h)').join(', ')}'}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  String _kgText(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  /// Best set of this exercise from earlier workouts, or null.
  Map<String, dynamic>? _lastBest(String name) =>
      bestSetsOf(context.read<AppState>().workouts)[name.toLowerCase()];

  /// Fills the sets that are not done yet with the weight and reps of last time.
  bool _useLast(Exercise ex, List<_SetLog> sets) {
    final b = _lastBest(ex.name);
    if (b == null) return false;
    for (final l in sets) {
      if (l.done) continue;
      l.kg.text = _kgText(b['kg'] as double);
      l.reps.text = '${b['reps']}';
    }
    return true;
  }

  /// Copies the weight and reps of the first set into every set not done yet.
  void _repeatFirst(List<_SetLog> sets) {
    if (sets.length < 2) return;
    final first = sets.first;
    for (var i = 1; i < sets.length; i++) {
      if (sets[i].done) continue;
      sets[i].kg.text = first.kg.text;
      sets[i].reps.text = first.reps.text;
    }
    setState(() {});
  }

  void _copyLastWorkout(DayPlan plan, List<List<_SetLog>> logs) {
    var filled = 0;
    for (var i = 0; i < plan.exercises.length; i++) {
      if (_useLast(plan.exercises[i], logs[i])) filled++;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(filled == 0
          ? 'No earlier workout to copy yet.'
          : 'Filled $filled exercises from last time.'),
    ));
  }

  /// After a set is ticked, the next empty set gets the same weight and reps.
  void _prefillNext(List<_SetLog> sets, int i) {
    if (i + 1 >= sets.length) return;
    final next = sets[i + 1];
    if (next.done || next.kg.text.trim().isNotEmpty) return;
    next.kg.text = sets[i].kg.text;
    next.reps.text = sets[i].reps.text;
  }

  /// Weekdays whose "missed workout" suggestion was dismissed or used.
  final Set<int> _missedHandled = {};

  /// Most recent earlier day this week with a planned workout and no log.
  int? _missedWeekday(AppState state) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    for (var wd = now.weekday - 1; wd >= 1; wd--) {
      if (_missedHandled.contains(wd)) continue;
      final plan = state.planFor(wd);
      if (plan.rest) continue;
      final date = monday.add(Duration(days: wd - 1));
      final done = state.workouts.any((w) => AppState.sameDay(w.at, date));
      if (!done) return wd;
    }
    return null;
  }

  /// Flexible calendar: a missed workout can be done today instead.
  Widget _missedCard(AppState state) {
    final today = DateTime.now().weekday;
    if (_weekday != today || _logging || _short.containsKey(today)) {
      return const SizedBox.shrink();
    }
    final todayPlan = state.planFor(today);
    final wd = _missedWeekday(state);
    if (wd == null) return const SizedBox.shrink();
    final missed = state.planFor(wd);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: AppColors.warnBg,
        borderColor: AppColors.warnBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You missed ${_dayNames[wd - 1]}: ${missed.title}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              todayPlan.rest
                  ? 'Today is a rest day, so you can do it now.'
                  : 'No problem. Do it today instead of ${todayPlan.title}, or skip it.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () {
                    _skipRest();
                    _resetDay(today);
                    setState(() {
                      _short[today] = missed;
                      _missedHandled.add(wd);
                    });
                  },
                  child: const Text('Do it today'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => setState(() => _missedHandled.add(wd)),
                  child: const Text('Skip it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetDay(int weekday) {
    _swaps.remove(weekday);
    _short.remove(weekday);
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
    final plan = _plan(state, _weekday);
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
    _startRest(exercise: plan.exercises[v.exerciseIndex].name);
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
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
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

  void _startRest({String? exercise}) {
    _timer?.cancel();
    ReminderService.instance.startRestTimer(_restSeconds, exercise: exercise);
    setState(() => _rest = _restSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_rest <= 1) {
        t.cancel();
        // App is open and showing the timer, so no need to ring the notification.
        ReminderService.instance.stopRestTimer();
        setState(() => _rest = 0);
      } else {
        setState(() => _rest--);
      }
    });
  }

  void _skipRest() {
    _timer?.cancel();
    ReminderService.instance.stopRestTimer();
    setState(() => _rest = 0);
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _finish(DayPlan plan, List<List<_SetLog>> logs) {
    Haptic.win();
    Celebrate.show(context);
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
    final plan = _plan(state, _weekday);
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
              _missedCard(state),
              if (plan.rest)
                const AppCard(
                  child: Text(
                    'Rest day. Take a 20 minute walk, stretch lightly and drink plenty of water. Tap Edit to plan a workout for this day instead.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                )
              else ...[
                _banner(plan, done, total),
                if (!_logging) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
                      label: Text(_short.containsKey(_weekday)
                          ? 'Short plan on, change'
                          : 'Short on time?'),
                      onPressed: () => _askShort(state, _weekday),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _trainingCard(state),
                ],
                const SizedBox(height: 14),
                if (_logging)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: Icon(Icons.history, size: 18, color: AppColors.primary),
                        label: const Text('Copy last workout'),
                        onPressed: () => _copyLastWorkout(plan, logs),
                      ),
                    ),
                  ),
                if (_logging)
                  for (var i = 0; i < plan.exercises.length; i++)
                    _exerciseCard(i, plan.exercises[i], logs[i])
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
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text(w.sets == 0 ? 'Synced' : '${w.sets} sets  |  ${w.volumeKg.round()} kg',
                              style: TextStyle(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Workout',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(
                state.isCustomPlan(_weekday)
                    ? 'Your own plan'
                    : (plan.rest ? 'Recover well' : 'Build stronger today'),
                style: TextStyle(color: AppColors.muted, fontSize: 13),
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
          label: const Text('Edit plan'),
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
                color: sel ? null : AppColors.chipBg.withOpacity(0.6),
                borderRadius: BorderRadius.circular(22),
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
            const Positioned(
              right: 70,
              top: 0,
              bottom: 0,
              child: Center(child: DumbbellArt(width: 120, opacity: 0.22)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weekday == DateTime.now().weekday ? 'Today' : 'Plan',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                Text('${plan.exercises.length} exercises \u2022 $mins min',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
                              style: TextStyle(
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
          const ShakerArt(height: 74),
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
                    Text('Workouts completed',
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
                    Text('Total lifted',
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

  Widget _exerciseCard(int index, Exercise ex, List<_SetLog> sets) {
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
                  Padding(
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
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (findExercise(ex.name) != null)
                  IconButton(
                    tooltip: 'Check my form (photo)',
                    icon: Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => FormCheckScreen(exercise: ex.name),
                    )),
                  ),
                if (findExercise(ex.name) != null)
                  IconButton(
                    tooltip: 'Machine busy? Find an alternative',
                    icon: Icon(Icons.swap_horiz, color: AppColors.primary),
                    onPressed: () => _pickAlternative(index, ex, sets),
                  ),
                if (findExercise(ex.name) != null)
                  IconButton(
                    tooltip: 'How to do it',
                    icon: Icon(Icons.help_outline, color: AppColors.primary),
                    onPressed: () => openExercise(context, findExercise(ex.name)!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (_lastBest(ex.name) != null)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(
                        'Last time ${_kgText(_lastBest(ex.name)!['kg'] as double)} kg x ${_lastBest(ex.name)!['reps']}'),
                    onPressed: () {
                      Haptic.tap();
                      _useLast(ex, sets);
                      setState(() {});
                    },
                  ),
                if (sets.length > 1)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.content_copy, size: 15),
                    label: const Text('Same as set 1'),
                    onPressed: () {
                      Haptic.tap();
                      _repeatFirst(sets);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(width: 36, child: Text('Set', style: _head)),
                Expanded(child: Text('Kg', style: _head)),
                const SizedBox(width: 8),
                Expanded(child: Text('Reps / sec', style: _head)),
                const SizedBox(width: 56),
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
                            _prefillNext(sets, i);
                            _startRest(exercise: ex.name);
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

  static TextStyle get _head =>
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
