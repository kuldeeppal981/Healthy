import '../models.dart';

/// A health condition the user can switch on. Food labels are then checked
/// against general, widely used limits. This is guidance, not medical advice.
class HealthCondition {
  final String id;
  final String label;
  final String summary;
  final List<String> prefer;
  final List<String> limit;

  const HealthCondition(this.id, this.label, this.summary, this.prefer, this.limit);
}

const healthConditions = <HealthCondition>[
  HealthCondition(
    'diabetes',
    'Diabetes / high sugar',
    'Keeps an eye on sugar and carbohydrates.',
    [
      'Dal, sprouts, chana and rajma',
      'Sabzi and salad with every meal',
      'Roti from whole wheat, jowar, bajra or ragi',
      'Curd, paneer, eggs, nuts in small amounts',
      'Whole fruit instead of juice',
    ],
    [
      'Mithai, sweets, cold drinks and packaged juice',
      'Maida items like white bread, naan and biscuits',
      'Large portions of white rice and potato',
      'Sugar in chai, and sweet snacks',
    ],
  ),
  HealthCondition(
    'bp',
    'High blood pressure',
    'Keeps an eye on salt (sodium).',
    [
      'Fresh fruits, vegetables and sprouts',
      'Curd, unsalted nuts, oats',
      'Cooking with less salt and more spices, lemon, herbs',
      'Banana, coconut water and leafy greens (if your doctor agrees)',
    ],
    [
      'Packaged snacks, namkeen, chips and instant noodles',
      'Papad, achar and chutney in large amounts',
      'Processed meat, ready sauces and soup cubes',
      'Extra salt on the plate',
    ],
  ),
  HealthCondition(
    'cholesterol',
    'High cholesterol / heart',
    'Keeps an eye on saturated fat and hydrogenated oils.',
    [
      'Oats, dalia, whole grains and lots of fibre',
      'Dal, chana, rajma and soy',
      'Nuts like almonds and walnuts, in small amounts',
      'Fish, and cooking in small amounts of vegetable oil',
    ],
    [
      'Fried food, samosa, pakora and bhature',
      'Vanaspati, margarine and shortening',
      'Ghee, butter and cream in large amounts',
      'Red meat and bakery items made with palm oil',
    ],
  ),
  HealthCondition(
    'pcos',
    'PCOS / insulin resistance',
    'Keeps an eye on sugar and refined carbohydrates.',
    [
      'Protein with every meal: dal, eggs, paneer, curd, chicken',
      'High fibre: vegetables, salad, whole grains, millets',
      'Nuts and seeds like flax and pumpkin seeds',
      'Regular meal times and daily walking',
    ],
    [
      'Sugary drinks, sweets and bakery items',
      'Maida and other refined flour',
      'Long gaps between meals followed by heavy meals',
      'Packaged foods high in sugar',
    ],
  ),
];

HealthCondition? conditionById(String id) {
  for (final c in healthConditions) {
    if (c.id == id) return c;
  }
  return null;
}

enum HealthLevel { avoid, caution, good, info }

class HealthFlag {
  final String conditions; // names joined, like "Diabetes, PCOS"
  final HealthLevel level;
  final String message;

  const HealthFlag(this.conditions, this.level, this.message);
}

bool _has(String text, List<String> words) {
  for (final w in words) {
    if (RegExp('\\b${RegExp.escape(w)}', caseSensitive: false).hasMatch(text)) {
      return true;
    }
  }
  return false;
}

String? _found(String text, List<String> words) {
  for (final w in words) {
    if (RegExp('\\b${RegExp.escape(w)}', caseSensitive: false).hasMatch(text)) {
      return w;
    }
  }
  return null;
}

String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// Checks a product against the user's conditions. Limits per 100 g follow
/// the common traffic-light food label thresholds.
List<HealthFlag> checkHealth(FoodItem item, Set<String> conditions, {double grams = 100}) {
  final raw = <String, List<(HealthLevel, String)>>{};
  final text = item.ingredients.toLowerCase();
  final hasMacros = item.kcal100 > 0 || item.carbs100 > 0 || item.fat100 > 0;

  void add(String cond, HealthLevel l, String m) =>
      (raw[cond] ??= []).add((l, m));

  for (final id in conditions) {
    if (id == 'diabetes' || id == 'pcos') {
      if (hasMacros) {
        if (item.sugar100 > 22.5) {
          add(id, HealthLevel.avoid, 'Very high sugar: ${_n(item.sugar100)} g per 100 g');
        } else if (item.sugar100 > 10) {
          add(id, HealthLevel.caution, 'Fairly high sugar: ${_n(item.sugar100)} g per 100 g');
        }
        final carbs = item.carbs100 * grams / 100;
        if (carbs > 45) {
          add(id, HealthLevel.caution,
              'A lot of carbs in this portion: ${_n(carbs)} g');
        }
      }
      final sweet = _found(text, [
        'glucose', 'fructose', 'corn syrup', 'dextrose', 'maltodextrin',
        'jaggery', 'honey', 'syrup', 'sugar',
      ]);
      if (sweet != null && item.sugar100 <= 10) {
        add(id, HealthLevel.caution, 'Contains sugar in the ingredients ($sweet)');
      }
      if (_has(text, ['maida', 'refined wheat flour', 'refined flour'])) {
        add(id, HealthLevel.caution, 'Made with refined flour (maida)');
      }
      if ((item.fiber100 ?? 0) >= 6) {
        add(id, HealthLevel.good, 'High in fibre: ${_n(item.fiber100!)} g per 100 g');
      }
    }

    if (id == 'bp') {
      final na = item.sodiumMg100;
      if (na == null) {
        add(id, HealthLevel.info, 'No salt (sodium) information found for this product');
      } else if (na > 600) {
        add(id, HealthLevel.avoid, 'High salt: ${na.round()} mg sodium per 100 g');
      } else if (na > 120) {
        add(id, HealthLevel.caution, 'Medium salt: ${na.round()} mg sodium per 100 g');
      } else {
        add(id, HealthLevel.good, 'Low salt: ${na.round()} mg sodium per 100 g');
      }
    }

    if (id == 'cholesterol') {
      final sat = item.satFat100;
      if (sat != null) {
        if (sat > 5) {
          add(id, HealthLevel.avoid, 'High saturated fat: ${_n(sat)} g per 100 g');
        } else if (sat > 1.5) {
          add(id, HealthLevel.caution, 'Medium saturated fat: ${_n(sat)} g per 100 g');
        }
      } else if (item.fat100 > 17.5) {
        add(id, HealthLevel.caution,
            'High total fat (${_n(item.fat100)} g per 100 g), saturated fat not listed');
      }
      final bad = _found(text, ['hydrogenated', 'vanaspati', 'margarine', 'shortening', 'palm']);
      if (bad != null) {
        add(id, HealthLevel.caution, 'Contains $bad, an unhealthy fat');
      }
      final rich = _found(text, ['ghee', 'butter', 'cream']);
      if (rich != null) {
        add(id, HealthLevel.caution, 'Contains $rich, high in saturated fat');
      }
      if ((item.fiber100 ?? 0) >= 6) {
        add(id, HealthLevel.good, 'High in fibre: ${_n(item.fiber100!)} g per 100 g');
      }
    }
  }

  // Merge the same message across conditions.
  final merged = <String, List<String>>{};
  final order = <String, (HealthLevel, String)>{};
  for (final e in raw.entries) {
    final name = conditionById(e.key)?.label.split(' /').first ?? e.key;
    for (final (l, m) in e.value) {
      final key = '${l.name}|$m';
      (merged[key] ??= []).add(name);
      order[key] = (l, m);
    }
  }
  final flags = [
    for (final e in order.entries)
      HealthFlag(merged[e.key]!.join(', '), e.value.$1, e.value.$2),
  ];
  const rank = {
    HealthLevel.avoid: 0,
    HealthLevel.caution: 1,
    HealthLevel.info: 2,
    HealthLevel.good: 3,
  };
  flags.sort((a, b) => rank[a.level]!.compareTo(rank[b.level]!));
  return flags;
}
