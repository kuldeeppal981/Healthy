/// Starter day-wise gym plan (6 days + rest). Beginner-friendly split.
class Exercise {
  final String name;
  final int sets;
  final int reps; // reps, or seconds when [unit] is 'sec'
  final String unit; // 'reps' | 'sec'

  const Exercise(this.name, this.sets, this.reps, {this.unit = 'reps'});

  String get target => '$sets sets x $reps $unit';
}

class DayPlan {
  final String title;
  final bool rest;
  final List<Exercise> exercises;

  const DayPlan(this.title, this.exercises, {this.rest = false});
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
