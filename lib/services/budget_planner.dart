import 'dart:math';

import '../data/budget_foods.dart';

/// One food in a planned meal, with how many servings.
class PlanItem {
  final PlanFood food;
  final double qty;

  const PlanItem(this.food, this.qty);

  double get kcal => food.kcal * qty;
  double get protein => food.protein * qty;
  double get carbs => food.carbs * qty;
  double get fat => food.fat * qty;
  double cost(double factor) => food.price * qty * factor;

  String get servingText {
    final q = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
    return qty == 1 ? food.serving : '$q x ${food.serving}';
  }
}

class PlanMeal {
  final String slot; // breakfast | lunch | snacks | dinner
  final List<PlanItem> items;
  final double factor;

  const PlanMeal(this.slot, this.items, this.factor);

  double get kcal => items.fold(0.0, (s, i) => s + i.kcal);
  double get protein => items.fold(0.0, (s, i) => s + i.protein);
  double get cost => items.fold(0.0, (s, i) => s + i.cost(factor));
}

class PlanDay {
  final List<PlanMeal> meals;
  final double budget;
  final int kcalTarget;
  final int proteinTarget;

  const PlanDay(this.meals, this.budget, this.kcalTarget, this.proteinTarget);

  double get kcal => meals.fold(0.0, (s, m) => s + m.kcal);
  double get protein => meals.fold(0.0, (s, m) => s + m.protein);
  double get cost => meals.fold(0.0, (s, m) => s + m.cost);
  bool get overBudget => cost > budget * 1.02;
  bool get lowCalories => kcal < kcalTarget * 0.85;
  bool get lowProtein => protein < proteinTarget * 0.8;
  bool get hasEmptyMeal => meals.any((m) => m.items.isEmpty);
}

/// Builds a one-day or one-week eating plan that fits a rupee budget, the
/// user's calorie and protein targets (which already follow their goal), their
/// food type and their allergies. It is plain rule-based code: no AI, no
/// internet. Prices are approximate and the result is general guidance.
class BudgetPlanner {
  static const _slots = ['breakfast', 'lunch', 'snacks', 'dinner'];
  static const _kcalShare = {'breakfast': 0.25, 'lunch': 0.33, 'snacks': 0.10, 'dinner': 0.32};
  static const _budgetShare = {'breakfast': 0.22, 'lunch': 0.34, 'snacks': 0.09, 'dinner': 0.35};

  static bool _dietOk(String diet, String foodDiet) {
    if (diet == 'nonveg') return true;
    if (diet == 'egg') return foodDiet != 'nonveg';
    return foodDiet == 'veg';
  }

  static List<PlanFood> _pool(String slot, String diet, Set<String> allergies) {
    return [
      for (final f in planFoods)
        if (f.slots.contains(slot) &&
            _dietOk(diet, f.diet) &&
            !f.allergens.any(allergies.contains))
          f,
    ];
  }

  static List<double> _qtyOptions(PlanFood f) {
    const all = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0];
    return [for (final q in all) if (q <= f.maxServ) q];
  }

  static PlanItem _randomItem(PlanFood f, Random r) {
    final o = _qtyOptions(f);
    return PlanItem(f, o[r.nextInt(o.length)]);
  }

  static PlanFood? _pick(List<PlanFood> pool, String role, Random r, Set<String> taken) {
    final c = [for (final f in pool) if (f.role == role && !taken.contains(f.name)) f];
    if (c.isEmpty) return null;
    return c[r.nextInt(c.length)];
  }

  static List<PlanItem> _candidate(String slot, List<PlanFood> pool, Random r) {
    final taken = <String>{};
    final items = <PlanItem>[];
    void add(PlanFood? f) {
      if (f == null) return;
      taken.add(f.name);
      items.add(_randomItem(f, r));
    }

    if (slot == 'snacks') {
      add(pool[r.nextInt(pool.length)]);
      if (r.nextBool()) {
        final rest = [for (final f in pool) if (!taken.contains(f.name)) f];
        if (rest.isNotEmpty) add(rest[r.nextInt(rest.length)]);
      }
      return items;
    }
    if (slot == 'breakfast') {
      add(_pick(pool, 'main', r, taken));
    } else {
      add(_pick(pool, 'staple', r, taken));
      add(_pick(pool, 'main', r, taken));
    }
    final extras = r.nextInt(3); // 0, 1 or 2 sides
    for (var i = 0; i < extras; i++) {
      add(_pick(pool, 'side', r, taken));
    }
    if (items.isEmpty) add(pool[r.nextInt(pool.length)]);
    return items;
  }

  static PlanMeal _bestMeal(String slot, List<PlanFood> pool, double kcalT, double protT,
      double budgetT, double factor, Random r, Set<String> avoid) {
    if (pool.isEmpty) return PlanMeal(slot, const [], factor);
    List<PlanItem>? best;
    var bestScore = double.infinity;
    for (var i = 0; i < 500; i++) {
      final c = _candidate(slot, pool, r);
      var kcal = 0.0, prot = 0.0, cost = 0.0;
      var repeats = 0;
      for (final it in c) {
        kcal += it.kcal;
        prot += it.protein;
        cost += it.cost(factor);
        if (avoid.contains(it.food.name)) repeats++;
      }
      final kcalErr = (kcal - kcalT).abs() / kcalT;
      final protShort = protT > 0 ? max(0.0, protT - prot) / protT : 0.0;
      final over = budgetT > 0 ? max(0.0, cost - budgetT) / budgetT : 0.0;
      final cheap = budgetT > 0 ? cost / budgetT : 0.0;
      final score = kcalErr * 10 + protShort * 6 + over * 14 + cheap * 1.2 + repeats * 1.5;
      if (score < bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return PlanMeal(slot, best ?? const [], factor);
  }

  /// One day. [avoid] holds food names used recently, so days look different.
  static PlanDay day({
    required int kcalTarget,
    required int proteinTarget,
    required double budget,
    required String diet,
    required Set<String> allergies,
    required double priceFactor,
    required int seed,
    Set<String> avoid = const {},
  }) {
    PlanDay? cheapest;
    for (final tighten in const [1.0, 0.9, 0.8, 0.7, 0.6]) {
      final r = Random(seed);
      final used = <String>{...avoid};
      final meals = <PlanMeal>[];
      for (final slot in _slots) {
        final m = _bestMeal(
          slot,
          _pool(slot, diet, allergies),
          kcalTarget * _kcalShare[slot]!,
          proteinTarget * _kcalShare[slot]!,
          budget * _budgetShare[slot]! * tighten,
          priceFactor,
          r,
          used,
        );
        for (final it in m.items) {
          used.add(it.food.name);
        }
        meals.add(m);
      }
      final d = PlanDay(meals, budget, kcalTarget, proteinTarget);
      if (cheapest == null || d.cost < cheapest.cost) cheapest = d;
      if (!d.overBudget && !d.lowCalories) return d;
    }
    return cheapest!;
  }

  /// Seven days, each avoiding what the day before used.
  static List<PlanDay> week({
    required int kcalTarget,
    required int proteinTarget,
    required double budget,
    required String diet,
    required Set<String> allergies,
    required double priceFactor,
    required int seed,
  }) {
    final days = <PlanDay>[];
    var prev = <String>{};
    for (var i = 0; i < 7; i++) {
      final d = day(
        kcalTarget: kcalTarget,
        proteinTarget: proteinTarget,
        budget: budget,
        diet: diet,
        allergies: allergies,
        priceFactor: priceFactor,
        seed: seed * 977 + i * 131 + 7,
        avoid: prev,
      );
      days.add(d);
      prev = {for (final m in d.meals) for (final it in m.items) it.food.name};
    }
    return days;
  }
}
