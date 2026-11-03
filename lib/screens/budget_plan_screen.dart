import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/allergy_checker.dart';
import '../services/budget_planner.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/food_art.dart';
import '../widgets/ui_kit.dart';

/// Budget diet planner: a week of meals that fits a daily rupee budget and the
/// user's goal (calories and protein targets), food type and allergies.
class BudgetPlanScreen extends StatefulWidget {
  const BudgetPlanScreen({super.key});

  @override
  State<BudgetPlanScreen> createState() => _BudgetPlanScreenState();
}

class _BudgetPlanScreenState extends State<BudgetPlanScreen> {
  double _budget = 150;
  String _diet = 'veg';
  int _level = 1; // 0 cheaper, 1 normal, 2 costly
  int _day = 0;
  int _seed = 1;
  List<PlanDay>? _plan;

  static const _factors = [0.8, 1.0, 1.25];
  static const _levelNames = ['Small town', 'Normal', 'Big city'];
  static const _goalText = {
    'lose': 'Lose weight',
    'maintain': 'Stay at your weight',
    'gain': 'Gain weight',
  };
  static const _slotNames = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'snacks': 'Snacks',
    'dinner': 'Dinner',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _budget = (p.getDouble('bp_budget') ?? _budget).clamp(80.0, 500.0).toDouble();
      _diet = p.getString('bp_diet') ?? _diet;
      _level = (p.getInt('bp_level') ?? _level).clamp(0, 2).toInt();
    } catch (_) {}
    if (!mounted) return;
    _regen();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('bp_budget', _budget);
      await p.setString('bp_diet', _diet);
      await p.setInt('bp_level', _level);
    } catch (_) {}
  }

  void _regen() {
    final s = context.read<AppState>();
    setState(() {
      _plan = BudgetPlanner.week(
        kcalTarget: s.kcalTarget,
        proteinTarget: s.proteinTarget,
        budget: _budget,
        diet: _diet,
        allergies: Set<String>.from(s.allergies),
        priceFactor: _factors[_level],
        seed: _seed,
      );
    });
  }

  String _dayLabel(int i) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = DateTime.now().add(Duration(days: i));
    return i == 0 ? 'Today' : names[d.weekday - 1];
  }

  void _addMealToDiary(PlanMeal m) {
    final s = context.read<AppState>();
    final now = DateTime.now();
    var n = 0;
    for (final it in m.items) {
      s.addEntry(DiaryEntry(
        id: '${now.microsecondsSinceEpoch}_${n++}',
        name: '${it.food.name} (${it.servingText})',
        meal: m.slot,
        kcal: it.kcal,
        protein: it.protein,
        carbs: it.carbs,
        fat: it.fat,
        at: now,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_slotNames[m.slot]} added to today\'s diary')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final plan = _plan;
    final goal = _goalText[s.profile?.goal ?? 'maintain'] ?? 'Stay at your weight';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Budget diet plan'),
        actions: [
          IconButton(
            tooltip: 'New ideas',
            icon: const Icon(Icons.shuffle),
            onPressed: () {
              _seed++;
              _regen();
            },
          ),
        ],
      ),
      body: AppBackground(
        child: plan == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _goalCard(s, goal),
                  const SizedBox(height: 12),
                  _controls(),
                  const SizedBox(height: 14),
                  _dayChips(),
                  const SizedBox(height: 12),
                  _totals(plan[_day]),
                  for (final m in plan[_day].meals) ...[
                    const SizedBox(height: 12),
                    _mealCard(m),
                  ],
                  const SizedBox(height: 12),
                  _weekCard(plan),
                  const SizedBox(height: 12),
                  _notes(s),
                ],
              ),
      ),
    );
  }

  Widget _goalCard(AppState s, String goal) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan for your goal',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(goal,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${s.kcalTarget} kcal and ${s.proteinTarget} g protein a day',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Daily food budget',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Rs ${_budget.round()}',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _budget,
            min: 80,
            max: 500,
            divisions: 42,
            label: 'Rs ${_budget.round()}',
            onChanged: (v) => setState(() => _budget = v),
            onChangeEnd: (_) {
              _save();
              _regen();
            },
          ),
          const Text('Food type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final d in const [
                ('veg', 'Veg'),
                ('egg', 'Veg + egg'),
                ('nonveg', 'Non-veg'),
              ])
                ChoiceChip(
                  label: Text(d.$2),
                  selected: _diet == d.$1,
                  onSelected: (_) {
                    _diet = d.$1;
                    _save();
                    _regen();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Prices where you live',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(_levelNames[i]),
                  selected: _level == i,
                  onSelected: (_) {
                    _level = i;
                    _save();
                    _regen();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(_dayLabel(i)),
          selected: _day == i,
          onSelected: (_) => setState(() => _day = i),
        ),
      ),
    );
  }

  Widget _totals(PlanDay d) {
    final kcalFrac = d.kcalTarget == 0 ? 0.0 : (d.kcal / d.kcalTarget).clamp(0.0, 1.0).toDouble();
    final costFrac = d.budget == 0 ? 0.0 : (d.cost / d.budget).clamp(0.0, 1.0).toDouble();
    final warn = <String>[];
    if (d.hasEmptyMeal) {
      warn.add('Some meals have no safe food for your food type and allergies.');
    }
    if (d.overBudget) {
      warn.add('This budget is too low for your goal. Raise it a little, or pick Veg and a cheaper price level.');
    }
    if (d.lowCalories && !d.overBudget && !d.hasEmptyMeal) {
      warn.add('Calories are a bit under your target for this budget.');
    }
    if (d.lowProtein) {
      warn.add('Protein is under target. Dal, soya, eggs or sprouts are cheap ways to add more.');
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stat('${d.kcal.round()}', 'of ${d.kcalTarget} kcal'),
              _stat('${d.protein.round()} g', 'of ${d.proteinTarget} g protein'),
              _stat('Rs ${d.cost.round()}', 'of Rs ${d.budget.round()}'),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Calories', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          GradientBar(value: kcalFrac),
          const SizedBox(height: 10),
          const Text('Budget used', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          GradientBar(
            value: costFrac,
            colors: d.overBudget
                ? const [Color(0xFFF59E0B), Color(0xFFDC2626)]
                : null,
          ),
          for (final w in warn) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warnBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(w,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.warnInk, height: 1.35)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String big, String small) {
    return Expanded(
      child: Column(
        children: [
          Text(big, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(small,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _mealCard(PlanMeal m) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_slotNames[m.slot] ?? m.slot,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${m.kcal.round()} kcal  |  Rs ${m.cost.round()}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (m.items.isEmpty)
            const Text('No safe food found for this meal. Try another food type.',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          for (final it in m.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (FoodArt.kindFor(it.food.name) != null) ...[
                    FoodArt(FoodArt.kindFor(it.food.name)!, size: 28),
                    const SizedBox(width: 10),
                  ] else
                    const SizedBox(width: 38),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.food.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(it.servingText,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Text('${it.kcal.round()} kcal',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
          if (m.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _addMealToDiary(m),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add to today\'s diary'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekCard(List<PlanDay> plan) {
    final total = plan.fold(0.0, (s, d) => s + d.cost);
    return AppCard(
      color: AppColors.chipBg,
      child: Row(
        children: [
          Icon(Icons.shopping_basket_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week: about Rs ${total.round()}',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.chipInk)),
                Text('Average Rs ${(total / 7).round()} a day',
                    style: TextStyle(fontSize: 12.5, color: AppColors.chipInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notes(AppState s) {
    final names = [
      for (final id in s.allergies)
        if (allergenById(id) != null) allergenById(id)!.label,
    ];
    final allergyLine = names.isEmpty
        ? 'You have not added allergies. Add them in the Allergy tab and this plan will skip those foods.'
        : 'Skipping foods that usually contain: ${names.join(', ')}. Recipes differ, so always check ingredients.';
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(allergyLine,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 8),
          const Text(
            'Prices are rough home-cooking costs and change by city and season. '
            'This is general guidance, not medical advice. If you have a health '
            'condition, check your diet with a doctor or dietitian.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
