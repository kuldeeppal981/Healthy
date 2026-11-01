import '../profile_models.dart';

/// Daily targets worked out from the user's body and goal.
/// Uses the Mifflin-St Jeor equation. These are estimates, not medical advice.
class Targets {
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;

  const Targets(this.kcal, this.protein, this.carbs, this.fat);
}

const activityFactors = <String, double>{
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
};

const activityLabels = <String, String>{
  'sedentary': 'Mostly sitting (desk job, little exercise)',
  'light': 'Light (exercise 1-3 days a week)',
  'moderate': 'Moderate (exercise 3-5 days a week)',
  'active': 'Very active (exercise 6-7 days a week)',
};

const goalLabels = <String, String>{
  'lose': 'Lose weight',
  'maintain': 'Stay at my weight',
  'gain': 'Build muscle / gain weight',
};

double bmr(UserProfile p) {
  final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
  return p.sex == 'male' ? base + 5 : base - 161;
}

double tdee(UserProfile p) => bmr(p) * (activityFactors[p.activity] ?? 1.2);

Targets targetsFor(UserProfile p) {
  var kcal = tdee(p);
  double proteinPerKg;

  switch (p.goal) {
    case 'lose':
      kcal -= 500; // about 0.5 kg per week
      proteinPerKg = 1.8;
      break;
    case 'gain':
      kcal += 300;
      proteinPerKg = 1.8;
      break;
    default:
      proteinPerKg = 1.4;
  }

  // Never suggest very low calorie targets.
  final floor = p.sex == 'male' ? 1500.0 : 1200.0;
  if (kcal < floor) kcal = floor;

  final protein = (p.weightKg * proteinPerKg).round();
  final fat = (kcal * 0.25 / 9).round();
  var carbs = ((kcal - protein * 4 - fat * 9) / 4).round();
  if (carbs < 50) carbs = 50;

  // Round calories to the nearest 10 for a cleaner number.
  final k = (kcal / 10).round() * 10;
  return Targets(k, protein, carbs, fat);
}

double bmiOf(UserProfile p) {
  final m = p.heightCm / 100;
  return p.weightKg / (m * m);
}

String bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Healthy range';
  if (bmi < 30) return 'Overweight';
  return 'Obese range';
}
