import '../data/indian_foods.dart';

/// Raw ingredients for home recipes (approximate values for the amount shown).
/// Cooked dishes are in `indianFoods`; both lists can be used as ingredients.
const rawIngredients = <FoodPreset>[
  FoodPreset('Oil (any cooking oil)', '1 tsp (5 ml)', 40, 0, 0, 4.5),
  FoodPreset('Ghee', '1 tsp (5 g)', 45, 0, 0, 5),
  FoodPreset('Butter', '1 tsp (5 g)', 36, 0, 0, 4),
  FoodPreset('Toor / arhar dal (raw)', '100 g', 340, 22, 62, 1.5),
  FoodPreset('Moong dal (raw)', '100 g', 345, 24, 60, 1.2),
  FoodPreset('Masoor dal (raw)', '100 g', 350, 25, 60, 1),
  FoodPreset('Chana dal (raw)', '100 g', 360, 21, 60, 5),
  FoodPreset('Rajma (raw)', '100 g', 333, 23, 60, 1),
  FoodPreset('Chole / kabuli chana (raw)', '100 g', 360, 19, 61, 6),
  FoodPreset('Rice (raw)', '100 g', 350, 7, 78, 0.6),
  FoodPreset('Atta (wheat flour)', '100 g', 340, 12, 72, 1.7),
  FoodPreset('Besan', '100 g', 390, 22, 58, 7),
  FoodPreset('Suji / rava', '100 g', 350, 10, 73, 1),
  FoodPreset('Poha (raw)', '100 g', 350, 7, 77, 1),
  FoodPreset('Potato', '100 g', 77, 2, 17, 0.1),
  FoodPreset('Onion', '100 g', 40, 1.1, 9, 0.1),
  FoodPreset('Tomato', '100 g', 20, 0.9, 4, 0.2),
  FoodPreset('Spinach / palak', '100 g', 23, 2.9, 3.6, 0.4),
  FoodPreset('Cauliflower / gobi', '100 g', 25, 1.9, 5, 0.3),
  FoodPreset('Peas (matar)', '100 g', 81, 5, 14, 0.4),
  FoodPreset('Mixed vegetables', '100 g', 50, 2, 9, 0.4),
  FoodPreset('Paneer', '100 g', 265, 18, 3, 20),
  FoodPreset('Curd / dahi', '100 g', 60, 3.5, 5, 3),
  FoodPreset('Milk (toned)', '100 ml', 60, 3.2, 5, 3),
  FoodPreset('Chicken (raw, boneless)', '100 g', 120, 23, 0, 2.5),
  FoodPreset('Egg', '1 egg', 70, 6, 0.5, 5),
  FoodPreset('Fish (raw)', '100 g', 110, 20, 0, 3),
  FoodPreset('Soya chunks (dry)', '100 g', 345, 52, 33, 0.5),
  FoodPreset('Sugar', '1 tsp (5 g)', 20, 0, 5, 0),
  FoodPreset('Jaggery / gud', '1 tsp (5 g)', 19, 0, 4.8, 0),
  FoodPreset('Coconut (grated)', '2 tbsp (20 g)', 70, 0.7, 3, 6.6),
  FoodPreset('Peanuts', '30 g', 170, 7.5, 5, 14),
  FoodPreset('Masala, namak, haldi (all spices)', '1 tsp', 8, 0.3, 1.3, 0.3),
];

/// Everything that can be picked as an ingredient: raw items first, then cooked foods.
List<FoodPreset> get allIngredientChoices => [...rawIngredients, ...indianFoods];

/// Totals of a recipe map (see AppState.recipes) for the whole pot.
class RecipeTotals {
  final double kcal, protein, carbs, fat;
  const RecipeTotals(this.kcal, this.protein, this.carbs, this.fat);
}

RecipeTotals recipeTotals(Map<String, dynamic> r) {
  var k = 0.0, p = 0.0, c = 0.0, f = 0.0;
  for (final x in (r['items'] as List? ?? const [])) {
    if (x is! Map) continue;
    k += (x['kcal'] as num?)?.toDouble() ?? 0;
    p += (x['p'] as num?)?.toDouble() ?? 0;
    c += (x['c'] as num?)?.toDouble() ?? 0;
    f += (x['f'] as num?)?.toDouble() ?? 0;
  }
  return RecipeTotals(k, p, c, f);
}

double recipeServings(Map<String, dynamic> r) {
  final v = (r['servings'] as num?)?.toDouble() ?? 1;
  return v <= 0 ? 1 : v;
}

/// One serving of the recipe.
RecipeTotals recipePerServing(Map<String, dynamic> r) {
  final t = recipeTotals(r);
  final n = recipeServings(r);
  return RecipeTotals(t.kcal / n, t.protein / n, t.carbs / n, t.fat / n);
}
