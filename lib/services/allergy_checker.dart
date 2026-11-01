import '../models.dart';

/// One allergen the user can pick. [offTags] are Open Food Facts tags,
/// [keywords] are words searched in the ingredient list (catches hidden
/// names like casein or whey).
class AllergenDef {
  final String id;
  final String label;
  final List<String> offTags;
  final List<String> keywords;

  const AllergenDef(this.id, this.label, this.offTags, this.keywords);
}

const allergenDefs = <AllergenDef>[
  AllergenDef('peanut', 'Peanut', ['en:peanuts'], ['peanut', 'groundnut', 'arachis']),
  AllergenDef('treenuts', 'Tree nuts', ['en:nuts'],
      ['almond', 'cashew', 'walnut', 'hazelnut', 'pistachio', 'pecan', 'badam', 'kaju']),
  AllergenDef('milk', 'Milk / lactose', ['en:milk'], [
    'milk', 'casein', 'whey', 'lactose', 'butter', 'ghee', 'cream', 'curd',
    'paneer', 'cheese', 'dairy',
  ]),
  AllergenDef('gluten', 'Gluten', ['en:gluten'],
      ['wheat', 'gluten', 'barley', 'rye', 'malt', 'maida', 'semolina', 'suji']),
  AllergenDef('egg', 'Egg', ['en:eggs'], ['egg', 'albumin', 'albumen', 'lysozyme']),
  AllergenDef('soy', 'Soy', ['en:soybeans'], ['soy', 'soya', 'soybean']),
  AllergenDef('fish', 'Fish', ['en:fish'], ['fish', 'anchovy', 'tuna', 'salmon']),
  AllergenDef('shellfish', 'Shellfish', ['en:crustaceans', 'en:molluscs'],
      ['shrimp', 'prawn', 'crab', 'lobster', 'oyster', 'squid']),
  AllergenDef('sesame', 'Sesame', ['en:sesame-seeds'], ['sesame', 'tahini']),
  AllergenDef('mustard', 'Mustard', ['en:mustard'], ['mustard', 'sarson']),
];

AllergenDef? allergenById(String id) {
  for (final a in allergenDefs) {
    if (a.id == id) return a;
  }
  return null;
}

class AllergyHit {
  final AllergenDef allergen;
  final bool traceOnly;
  final String reason;

  const AllergyHit(this.allergen, this.traceOnly, this.reason);
}

RegExp _keywordRegex(String k) =>
    RegExp('\\b${RegExp.escape(k)}\\w*', caseSensitive: false);

/// Returns the allergies of the user that match this product.
List<AllergyHit> checkProduct(
  FoodItem item,
  Set<String> userAllergies, {
  bool traceWarning = true,
}) {
  final hits = <AllergyHit>[];
  final text = item.ingredients.toLowerCase();

  for (final id in userAllergies) {
    final def = allergenById(id);
    if (def == null) continue;

    String? reason;

    for (final tag in def.offTags) {
      if (item.allergenTags.contains(tag)) {
        reason = 'Declared as an allergen';
        break;
      }
    }

    if (reason == null) {
      for (final k in def.keywords) {
        if (_keywordRegex(k).hasMatch(text)) {
          reason = 'Found "$k" in ingredients';
          break;
        }
      }
    }

    if (reason != null) {
      hits.add(AllergyHit(def, false, reason));
      continue;
    }

    if (traceWarning) {
      for (final tag in def.offTags) {
        if (item.traceTags.contains(tag)) {
          hits.add(AllergyHit(def, true, 'Listed under "may contain" traces'));
          break;
        }
      }
    }
  }

  return hits;
}

/// True when the product has no ingredient/allergen data at all, so we
/// must not tell the user it is safe.
bool dataIsIncomplete(FoodItem item) =>
    item.ingredients.trim().isEmpty && item.allergenTags.isEmpty;

/// Words to highlight inside the ingredient text for the user's allergies.
RegExp? highlightRegex(Set<String> userAllergies) {
  final words = <String>[];
  for (final id in userAllergies) {
    final def = allergenById(id);
    if (def != null) words.addAll(def.keywords);
  }
  if (words.isEmpty) return null;
  return RegExp(
    '\\b(${words.map(RegExp.escape).join('|')})\\w*',
    caseSensitive: false,
  );
}
