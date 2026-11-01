/// The person using the app (adults only).
class UserProfile {
  final String sex; // male | female
  final int age;
  final double heightCm;
  final double weightKg;
  final String activity; // sedentary | light | moderate | active
  final String goal; // lose | maintain | gain

  const UserProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
  });

  UserProfile copyWith({double? weightKg}) => UserProfile(
        sex: sex,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg ?? this.weightKg,
        activity: activity,
        goal: goal,
      );

  Map<String, dynamic> toJson() => {
        'sex': sex,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity,
        'goal': goal,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        sex: j['sex'] as String,
        age: (j['age'] as num).toInt(),
        heightCm: (j['heightCm'] as num).toDouble(),
        weightKg: (j['weightKg'] as num).toDouble(),
        activity: j['activity'] as String,
        goal: j['goal'] as String,
      );
}

class WeightEntry {
  final DateTime at;
  final double kg;

  const WeightEntry(this.at, this.kg);

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'kg': kg};

  factory WeightEntry.fromJson(Map<String, dynamic> j) =>
      WeightEntry(DateTime.parse(j['at'] as String), (j['kg'] as num).toDouble());
}

/// One finished gym session.
class WorkoutLog {
  final String id;
  final DateTime at;
  final String title;
  final int sets;
  final double volumeKg; // sum of kg x reps over completed sets

  const WorkoutLog({
    required this.id,
    required this.at,
    required this.title,
    required this.sets,
    required this.volumeKg,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'title': title,
        'sets': sets,
        'volumeKg': volumeKg,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        title: j['title'] as String,
        sets: (j['sets'] as num).toInt(),
        volumeKg: (j['volumeKg'] as num).toDouble(),
      );
}
