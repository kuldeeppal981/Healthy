import '../data/indian_foods.dart';

/// One spoken food, with its nutrition for the quantity given.
class VoiceItem {
  String name;
  String serving;
  double kcal; // per 1 serving
  double protein;
  double carbs;
  double fat;
  double qty;
  final bool estimated;

  VoiceItem({
    required this.name,
    required this.serving,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.qty,
    this.estimated = false,
  });
}

enum VoiceKind { none, food, water, weight }

class VoiceResult {
  final VoiceKind kind;
  final List<VoiceItem> items;
  final List<String> unmatched; // spoken foods we do not know yet
  final double? number; // glasses of water, or weight in kg

  const VoiceResult(this.kind,
      {this.items = const [], this.unmatched = const [], this.number});
}

// ---- words ----

const _numberWords = <String, double>{
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'half': 0.5, 'quarter': 0.25,
  'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5,
  'chhe': 6, 'chhah': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
  'aadha': 0.5, 'adha': 0.5, 'aadhi': 0.5, 'dedh': 1.5, 'dhai': 2.5,
  'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पांच': 5, 'पाँच': 5, 'छह': 6,
  'छः': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
  'आधा': 0.5, 'आधी': 0.5, 'डेढ़': 1.5, 'ढाई': 2.5,
};

const _unitWords = {
  'katori', 'katoris', 'bowl', 'bowls', 'plate', 'plates', 'glass', 'glasses',
  'cup', 'cups', 'piece', 'pieces', 'pc', 'pcs', 'spoon', 'spoons', 'scoop',
  'scoops', 'slice', 'slices', 'serving', 'servings', 'gilas', 'गिलास',
  'कटोरी', 'कटोरा', 'प्लेट', 'कप', 'पीस', 'चम्मच',
};

const _fillerWords = {
  'maine', 'mene', 'main', 'mai', 'mein', 'me', 'i', 'had', 'ate', 'eat',
  'khaya', 'khayi', 'khai', 'khaye', 'liya', 'li', 'piya', 'piye', 'pee',
  'drank', 'of', 'ka', 'ki', 'ke', 'ko', 'aaj', 'today', 'for', 'breakfast',
  'lunch', 'dinner', 'snack', 'snacks', 'subah', 'dopahar', 'raat', 'with',
  'some', 'the', 'my', 'मैंने', 'खाया', 'खायी', 'खाई', 'पिया', 'आज', 'का',
  'की', 'के', 'में', 'सुबह', 'दोपहर', 'रात',
};

/// Words people say for each food, in English, Hinglish and Hindi.
const _aliases = <String, List<String>>{
  'Roti / chapati': ['roti', 'chapati', 'chapatti', 'phulka', 'रोटी', 'चपाती', 'फुल्का'],
  'Paratha (plain)': ['paratha', 'parantha', 'पराठा', 'परांठा'],
  'Steamed rice': ['rice', 'chawal', 'chaval', 'चावल', 'भात'],
  'Dal (tadka)': ['dal', 'daal', 'dhal', 'दाल'],
  'Rajma curry': ['rajma', 'राजमा'],
  'Chole': ['chole', 'chhole', 'chana masala', 'छोले'],
  'Khichdi': ['khichdi', 'khichri', 'खिचड़ी'],
  'Mixed veg sabzi': ['sabzi', 'sabji', 'sabzee', 'vegetable', 'veg', 'सब्जी', 'सब्ज़ी'],
  'Aloo sabzi': ['aloo sabzi', 'aloo ki sabzi', 'aloo', 'alu', 'potato', 'आलू'],
  'Paneer bhurji': ['paneer', 'bhurji', 'पनीर', 'भुर्जी'],
  'Chicken curry': ['chicken', 'murgh', 'चिकन'],
  'Chicken biryani': ['chicken biryani', 'biryani', 'biriyani', 'बिरयानी'],
  'Curd / dahi': ['dahi', 'curd', 'yogurt', 'yoghurt', 'दही'],
  'Boiled egg': ['boiled egg', 'egg', 'eggs', 'anda', 'ande', 'अंडा', 'अंडे'],
  'Omelette': ['omelette', 'omelet', 'ऑमलेट', 'आमलेट'],
  'Idli': ['idli', 'idly', 'इडली'],
  'Dosa (plain)': ['dosa', 'dosai', 'डोसा'],
  'Sambar': ['sambar', 'sambhar', 'सांभर'],
  'Poha': ['poha', 'पोहा'],
  'Upma': ['upma', 'उपमा'],
  'Samosa': ['samosa', 'समोसा'],
  'Banana': ['banana', 'kela', 'kele', 'केला', 'केले'],
  'Apple': ['apple', 'seb', 'सेब'],
  'Milk (toned)': ['milk', 'doodh', 'dudh', 'दूध'],
  'Tea with milk and sugar': ['tea', 'chai', 'चाय'],
  'Almonds': ['almond', 'almonds', 'badam', 'बादाम'],
  'Whey protein': ['whey', 'protein shake', 'protein powder', 'प्रोटीन'],
};

bool _hasAlias(String text, String alias) {
  final devanagari = RegExp(r'[ऀ-ॿ]').hasMatch(alias);
  if (devanagari) return text.contains(alias);
  return RegExp('(^|[^a-z])${RegExp.escape(alias)}(s|es)?([^a-z]|\$)').hasMatch(text);
}

FoodPreset? _matchPreset(String text) {
  FoodPreset? best;
  var bestLen = 0;
  for (final p in indianFoods) {
    final list = _aliases[p.name];
    if (list == null) continue;
    for (final a in list) {
      if (a.length > bestLen && _hasAlias(text, a)) {
        best = p;
        bestLen = a.length;
      }
    }
  }
  return best;
}

/// First quantity found in the words, or null.
double? _quantity(List<String> tokens) {
  for (final t in tokens) {
    final m = RegExp(r'^(\d+(?:[.,]\d+)?)x?$').firstMatch(t);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (t == '½') return 0.5;
    final w = _numberWords[t];
    if (w != null) return w;
  }
  return null;
}

String _cleanName(List<String> tokens) {
  final keep = tokens.where((t) =>
      !_unitWords.contains(t) &&
      !_fillerWords.contains(t) &&
      !_numberWords.containsKey(t) &&
      !RegExp(r'^\d+(?:[.,]\d+)?x?$').hasMatch(t));
  return keep.join(' ').trim();
}

List<String> _tokens(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[.!?]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Understands one sentence: food, water or weight.
VoiceResult parseVoice(String raw) {
  final text = raw.toLowerCase().trim();
  if (text.isEmpty) return const VoiceResult(VoiceKind.none);

  final nums = RegExp(r'\d+(?:[.,]\d+)?');

  // Weight: "aaj weight 72 kilo hai"
  if (RegExp(r'weight|vajan|vazan|वजन|वज़न').hasMatch(text)) {
    final m = nums.firstMatch(text);
    final kg = m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', '.'));
    if (kg != null && kg >= 25 && kg <= 300) {
      return VoiceResult(VoiceKind.weight, number: kg);
    }
  }

  // Water: "2 glass paani piya"
  final hasWater = RegExp(r'paani|pani|water|पानी').hasMatch(text);
  if (hasWater && !RegExp(r'\b(roti|chai|tea|milk|doodh)\b').hasMatch(text)) {
    final tokens = _tokens(text);
    var n = _quantity(tokens) ?? 1;
    if (RegExp(r'litre|liter|लीटर').hasMatch(text)) n *= 4;
    if (RegExp(r'bottle|बोतल').hasMatch(text)) n *= 2;
    return VoiceResult(VoiceKind.water, number: n.clamp(0.5, 20).toDouble());
  }

  // Food: split into pieces.
  final parts = text
      .split(RegExp(r',|\+|\band\b|\baur\b|\bplus\b|\bwith\b|\bsaath\b|\bthen\b|\bphir\b|और|साथ|फिर'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  final items = <VoiceItem>[];
  final unmatched = <String>[];
  for (final part in parts) {
    final preset = _matchPreset(part);
    final tokens = _tokens(part);
    final qty = (_quantity(tokens) ?? 1).clamp(0.25, 20).toDouble();
    if (preset != null) {
      items.add(VoiceItem(
        name: preset.name,
        serving: preset.serving,
        kcal: preset.kcal,
        protein: preset.protein,
        carbs: preset.carbs,
        fat: preset.fat,
        qty: qty,
      ));
    } else {
      final name = _cleanName(tokens);
      if (name.length >= 2) {
        unmatched.add(qty == 1 ? name : '${_fmt(qty)} $name');
      }
    }
  }

  if (items.isEmpty && unmatched.isEmpty) return const VoiceResult(VoiceKind.none);
  return VoiceResult(VoiceKind.food, items: items, unmatched: unmatched);
}

String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// A set spoken during a workout: "bench press 40 kilo 8 reps".
class WorkoutVoice {
  final int exerciseIndex;
  final double? kg;
  final int? reps;

  const WorkoutVoice(this.exerciseIndex, this.kg, this.reps);
}

WorkoutVoice? parseWorkoutVoice(String raw, List<String> exerciseNames) {
  final text = raw.toLowerCase();

  var bestIndex = -1;
  var bestScore = 0;
  for (var i = 0; i < exerciseNames.length; i++) {
    final words = exerciseNames[i]
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.length > 2);
    final score = words.where(text.contains).length;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  if (bestIndex < 0) return null;

  double? kg;
  int? reps;
  final kgM = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|kgs|kilo|kilos|किलो)').firstMatch(text);
  final repM = RegExp(r'(\d+)\s*(reps?|repetitions?|times|baar|बार)').firstMatch(text);
  if (kgM != null) kg = double.tryParse(kgM.group(1)!.replaceAll(',', '.'));
  if (repM != null) reps = int.tryParse(repM.group(1)!);

  if (kg == null || reps == null) {
    final all = RegExp(r'\d+(?:[.,]\d+)?').allMatches(text).map((m) => m.group(0)!).toList();
    if (kg == null && reps == null && all.length >= 2) {
      kg = double.tryParse(all[0].replaceAll(',', '.'));
      reps = int.tryParse(all[1].split(RegExp(r'[.,]')).first);
    } else if (reps == null && kg != null && all.length >= 2) {
      reps = int.tryParse(all.last.split(RegExp(r'[.,]')).first);
    } else if (kg == null && reps != null && all.length >= 2) {
      kg = double.tryParse(all.first.replaceAll(',', '.'));
    }
  }
  return WorkoutVoice(bestIndex, kg, reps);
}
