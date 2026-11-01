/// Pulls the ingredient list and nutrition numbers out of text read from a
/// photo of a food label. Results are only a first guess: the user checks
/// and corrects them before anything is used.
class LabelData {
  final String ingredients;
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? sugar;
  final double? satFat;
  final double? sodiumMg;

  const LabelData({
    required this.ingredients,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.sugar,
    this.satFat,
    this.sodiumMg,
  });
}

double? _num(RegExp r, String text) {
  final m = r.firstMatch(text);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

LabelData parseLabel(String raw) {
  final text = raw.replaceAll('\r', '');
  final flat = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

  // Ingredients: from the word "ingredients" up to the next section.
  var ingredients = '';
  final start = RegExp(r'ingredients?\s*[:\-]?', caseSensitive: false).firstMatch(flat);
  if (start != null) {
    var rest = flat.substring(start.end);
    final stop = RegExp(
      r'(nutrition(al)?\s+(information|facts|value)|storage|best before|use by|manufactured|marketed|mfd|fssai|net (wt|weight|qty)|directions|average (composition|values))',
      caseSensitive: false,
    ).firstMatch(rest);
    if (stop != null) rest = rest.substring(0, stop.start);
    ingredients = rest.trim();
  } else {
    ingredients = flat.trim();
  }

  const n = r'(\d+(?:[.,]\d+)?)';
  final kcal = _num(RegExp('$n\\s*kcal', caseSensitive: false), flat) ??
      _num(RegExp('(?:energy|calories)[^\\d]{0,15}$n', caseSensitive: false), flat);
  final protein = _num(RegExp('protein[^\\d]{0,14}$n', caseSensitive: false), flat);
  final carbs = _num(RegExp('carbohydrates?[^\\d]{0,14}$n', caseSensitive: false), flat);
  final fat = _num(RegExp('total\\s*fat[^\\d]{0,14}$n', caseSensitive: false), flat) ??
      _num(RegExp('(?<!saturated\\s)(?<!trans\\s)fat[^\\d]{0,14}$n', caseSensitive: false), flat);
  final sugar = _num(RegExp('sugars?[^\\d]{0,14}$n', caseSensitive: false), flat);

  final satFat = _num(RegExp('saturated\\s*fat[^\\d]{0,14}$n', caseSensitive: false), flat);
  double? sodiumMg;
  final na = RegExp('sodium[^\\d]{0,12}$n\\s*(mg|g)?', caseSensitive: false).firstMatch(flat);
  if (na != null) {
    final v = double.tryParse(na.group(1)!.replaceAll(',', '.'));
    if (v != null) sodiumMg = (na.group(2)?.toLowerCase() == 'g') ? v * 1000 : v;
  }

  return LabelData(
    ingredients: ingredients,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    sugar: sugar,
    satFat: satFat,
    sodiumMg: sodiumMg,
  );
}
