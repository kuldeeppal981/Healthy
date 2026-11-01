/// A packaged food looked up by barcode. Nutrition values are per 100 g.
class FoodItem {
  final String barcode;
  final String name;
  final String brand;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double sugar100;
  final String ingredients;
  final List<String> allergenTags;
  final List<String> traceTags;
  final String? nutriGrade;
  final double servingGrams;

  /// Optional per 100 g values. Null means the product does not list them.
  final double? satFat100;
  final double? sodiumMg100;
  final double? fiber100;

  /// True when the data was read from a photo of the label, not a database.
  final bool fromLabel;

  const FoodItem({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.sugar100,
    required this.ingredients,
    required this.allergenTags,
    required this.traceTags,
    required this.nutriGrade,
    required this.servingGrams,
    this.fromLabel = false,
    this.satFat100,
    this.sodiumMg100,
    this.fiber100,
  });

  static double scale(double per100, double grams) => per100 * grams / 100;
}

/// One logged food in the daily diary.
class DiaryEntry {
  final String id;
  final String name;
  final String meal; // breakfast | lunch | snacks | dinner
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime at;

  const DiaryEntry({
    required this.id,
    required this.name,
    required this.meal,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'meal': meal,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'at': at.toIso8601String(),
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        meal: j['meal'] as String,
        kcal: (j['kcal'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carbs: (j['carbs'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        at: DateTime.parse(j['at'] as String),
      );
}

const mealOrder = ['breakfast', 'lunch', 'snacks', 'dinner'];

const mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'snacks': 'Snacks',
  'dinner': 'Dinner',
};

String mealForNow([DateTime? time]) {
  final h = (time ?? DateTime.now()).hour;
  if (h < 11) return 'breakfast';
  if (h < 16) return 'lunch';
  if (h < 19) return 'snacks';
  return 'dinner';
}
