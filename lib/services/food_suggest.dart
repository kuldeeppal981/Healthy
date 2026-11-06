import '../data/indian_foods.dart';
import '../models.dart';
import '../state/app_state.dart';

/// Words in a food name that point to an allergen (names alone do not list
/// hidden ingredients, so this is a safety net for suggestions, not a promise).
const _allergenHints = <String, List<String>>{
  'milk': ['milk', 'paneer', 'curd', 'dahi', 'lassi', 'chaas', 'whey', 'ghee', 'tea', 'oats (with milk)', 'gulab'],
  'gluten': ['roti', 'chapati', 'paratha', 'thepla', 'pav', 'upma', 'samosa', 'dalia', 'daliya', 'oats', 'vada pav', 'chilla (besan)'],
  'egg': ['egg', 'omelette'],
  'peanut': ['peanut'],
  'treenuts': ['almond', 'cashew', 'walnut', 'pista'],
  'fish': ['fish'],
  'shellfish': ['prawn', 'shrimp', 'crab'],
  'soy': ['soya', 'soy'],
  'sesame': ['sesame', 'til'],
};

bool foodHasAllergen(String foodName, Set<String> allergies) {
  final n = foodName.toLowerCase();
  for (final a in allergies) {
    final hints = _allergenHints[a] ?? const <String>[];
    for (final h in hints) {
      if (n.contains(h)) return true;
    }
  }
  return false;
}

/// Foods that fit what is left of today: they fit the calories of the next
/// meal and help close the protein gap. General ideas, not a medical plan.
List<FoodPreset> suggestFoods(AppState s, DateTime now, {int count = 4}) {
  final remainingKcal = s.kcalTarget - s.kcalToday;
  final proteinGap = s.proteinTarget - s.proteinToday;
  final mealsLeft = now.hour < 11 ? 3.0 : (now.hour < 16 ? 2.0 : 1.0);
  final budget = (remainingKcal / mealsLeft).clamp(120.0, 700.0).toDouble();
  final eaten = s.today.map((e) => e.name.toLowerCase()).join(' | ');
  final diabetes = s.conditions.contains('diabetes');
  final heart = s.conditions.contains('cholesterol');

  final scored = <MapEntry<FoodPreset, double>>[];
  for (final f in indianFoods) {
    if (f.kcal > budget * 1.1) continue;
    if (foodHasAllergen(f.name, s.allergies)) continue;
    if (s.reportAvoidHit(f.name) != null) continue;
    if (eaten.contains(f.name.toLowerCase())) continue;
    var score = 0.0;
    if (proteinGap > 5) {
      score += f.protein / (f.kcal + 20) * 100; // protein per 100 kcal
    } else {
      score += 3;
    }
    if (diabetes && f.carbs > 35) score -= 4;
    if (heart && f.fat > 12) score -= 4;
    if (f.kcal < 40) score -= 2; // skip tiny items
    // Variety: a little randomness by day so the list is not always the same.
    score += ((f.name.hashCode + now.day) % 7) * 0.15;
    scored.add(MapEntry(f, score));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in scored.take(count)) e.key];
}

class CoachAlert {
  final String icon; // protein | water | kcal | fibre
  final String title;
  final String body;
  const CoachAlert(this.icon, this.title, this.body);
}

/// Friendly notes about today. Informative, never guilt-inducing.
List<CoachAlert> coachAlerts(AppState s, DateTime now) {
  final out = <CoachAlert>[];

  if (s.proteinTarget > 0 && now.hour >= 14) {
    final short = s.proteinTarget - s.proteinToday;
    if (short >= 15 && s.proteinToday < s.proteinTarget * 0.7) {
      out.add(CoachAlert(
        'protein',
        'Protein is ${short.round()} g away',
        'Dal, paneer, curd, eggs or sprouts in your next meal can close the gap.',
      ));
    }
  }

  if (s.kcalToday > s.kcalTarget + 250) {
    final over = (s.kcalToday - s.kcalTarget).round();
    out.add(CoachAlert(
      'kcal',
      'About $over kcal above target',
      'No stress. One day does not change much. A short walk or a lighter next meal balances it.',
    ));
  }

  if (s.waterTarget > 0 && now.hour >= 11) {
    final expected = s.waterTarget * ((now.hour - 7) / 14).clamp(0.0, 1.0);
    if (s.waterToday + 2 <= expected) {
      out.add(const CoachAlert(
        'water',
        'Water is a little behind',
        'A glass of water now keeps you on track.',
      ));
    }
  }

  // Fibre is not tracked yet, so this checks for vegetables, fruit and whole grains.
  if (now.hour >= 15) {
    const fibreWords = [
      'sabzi', 'salad', 'sprouts', 'dal', 'rajma', 'chole', 'banana', 'apple', 'orange',
      'papaya', 'oats', 'dalia', 'bhindi', 'gobi', 'palak', 'bajra', 'jowar', 'brown rice',
    ];
    final names = s.today.map((e) => e.name.toLowerCase()).join(' | ');
    final has = fibreWords.any(names.contains);
    if (s.today.isNotEmpty && !has) {
      out.add(const CoachAlert(
        'fibre',
        'Add some fibre',
        'A salad, fruit, sabzi or dal with dinner adds fibre.',
      ));
    }
  }
  return out;
}

/// Little helper to build a diary entry from a preset.
DiaryEntry entryFromPreset(FoodPreset f, String meal, {double count = 1, String? label}) {
  return DiaryEntry(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: label ?? '${f.name} (${f.serving})',
    meal: meal,
    kcal: f.kcal * count,
    protein: f.protein * count,
    carbs: f.carbs * count,
    fat: f.fat * count,
    at: DateTime.now(),
  );
}
