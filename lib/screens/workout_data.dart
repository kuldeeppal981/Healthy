/// Starter day-wise gym plan (6 days + rest). Beginner-friendly split.
class Exercise {
  final String name;
  final int sets;
  final int reps; // reps, or seconds when [unit] is 'sec'
  final String unit; // 'reps' | 'sec'

  const Exercise(this.name, this.sets, this.reps, {this.unit = 'reps'});

  String get target => '$sets sets x $reps $unit';

  Map<String, dynamic> toJson() =>
      {'name': name, 'sets': sets, 'reps': reps, 'unit': unit};

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        j['name'] as String,
        (j['sets'] as num).toInt(),
        (j['reps'] as num).toInt(),
        unit: j['unit'] as String? ?? 'reps',
      );
}

class DayPlan {
  final String title;
  final bool rest;
  final List<Exercise> exercises;

  const DayPlan(this.title, this.exercises, {this.rest = false});

  Map<String, dynamic> toJson() => {
        'title': title,
        'rest': rest,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        j['title'] as String,
        ((j['exercises'] as List?) ?? const [])
            .map((x) => Exercise.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList(),
        rest: j['rest'] as bool? ?? false,
      );
}

/// [weekday] follows DateTime: Monday = 1 ... Sunday = 7.
DayPlan planForWeekday(int weekday) => weeklyPlan[weekday]!;

const weeklyPlan = <int, DayPlan>{
  1: DayPlan('Chest + Triceps', [
    Exercise('Bench press', 4, 8),
    Exercise('Incline dumbbell press', 3, 10),
    Exercise('Cable fly', 3, 12),
    Exercise('Triceps pushdown', 3, 12),
    Exercise('Overhead triceps extension', 3, 12),
  ]),
  2: DayPlan('Back + Biceps', [
    Exercise('Lat pulldown', 4, 10),
    Exercise('Seated cable row', 3, 10),
    Exercise('Deadlift', 3, 6),
    Exercise('Dumbbell curl', 3, 12),
    Exercise('Hammer curl', 3, 12),
  ]),
  3: DayPlan('Legs', [
    Exercise('Squat', 4, 8),
    Exercise('Leg press', 3, 10),
    Exercise('Lunges', 3, 12),
    Exercise('Leg curl', 3, 12),
    Exercise('Calf raise', 4, 15),
  ]),
  4: DayPlan('Shoulders + Abs', [
    Exercise('Overhead press', 4, 8),
    Exercise('Lateral raise', 3, 12),
    Exercise('Rear delt fly', 3, 12),
    Exercise('Plank', 3, 45, unit: 'sec'),
    Exercise('Crunches', 3, 15),
    Exercise('Leg raise', 3, 12),
  ]),
  5: DayPlan('Full body', [
    Exercise('Squat', 3, 8),
    Exercise('Bench press', 3, 8),
    Exercise('Barbell row', 3, 8),
    Exercise('Overhead press', 3, 10),
    Exercise('Plank', 3, 40, unit: 'sec'),
  ]),
  6: DayPlan('Cardio + Core', [
    Exercise('Treadmill or cycling (steady)', 1, 1800, unit: 'sec'),
    Exercise('Skipping', 3, 120, unit: 'sec'),
    Exercise('Russian twist', 3, 20),
    Exercise('Mountain climbers', 3, 30, unit: 'sec'),
  ]),
  7: DayPlan('Rest day', [], rest: true),
};

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Rough length of a workout: about 2.25 minutes per set, to the nearest 5.
int estimateMinutes(DayPlan plan) {
  if (plan.rest) return 0;
  final sets = plan.exercises.fold<int>(0, (n, e) => n + e.sets);
  final m = (sets * 2.25 / 5).round() * 5;
  return m < 10 ? 10 : m;
}
