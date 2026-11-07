import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/indian_foods.dart';
import '../models.dart';
import '../services/recipes.dart';
import '../state/app_state.dart';
import '../theme.dart';

String _fmtQty(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// "My recipes": saved home recipes. Tap one to log a quantity.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  void _edit(BuildContext context, [Map<String, dynamic>? r]) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => RecipeEditorScreen(existing: r)));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('My recipes')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (s.recipes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 56, color: AppColors.primary),
                    const SizedBox(height: 10),
                    const Text('Save your home recipes once',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        'Add ingredients, oil and servings. Next time, log a serving in two taps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.35)),
                  ],
                ),
              )
            else
              AppCard(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final r in s.recipes)
                      Builder(builder: (_) {
                        final ps = recipePerServing(r);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: AppColors.chipBg, borderRadius: BorderRadius.circular(14)),
                            child: Icon(Icons.soup_kitchen_outlined, color: AppColors.primary),
                          ),
                          title: Text(r['name']?.toString() ?? 'Recipe',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${ps.kcal.round()} kcal per serving',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _edit(context, r);
                              if (v == 'delete') s.deleteRecipe(r['id'].toString());
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () => showLogRecipeSheet(context, r),
                        );
                      }),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'New recipe',
              icon: Icons.add,
              onPressed: () => _edit(context),
            ),
            const SizedBox(height: 10),
            Text(
                'Calories come from average values, so they are close but not exact. Your oil and ghee are counted, because they change the calories the most.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

/// Pick how much you ate, the meal, and add it to the diary.
Future<void> showLogRecipeSheet(BuildContext context, Map<String, dynamic> r, {DateTime? at}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (_) => _LogRecipe(recipe: r, at: at),
  );
}

class _LogRecipe extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final DateTime? at;
  const _LogRecipe({required this.recipe, this.at});

  @override
  State<_LogRecipe> createState() => _LogRecipeState();
}

class _LogRecipeState extends State<_LogRecipe> {
  double _qty = 1;
  String _meal = mealForNow();

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final ps = recipePerServing(r);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r['name']?.toString() ?? 'Recipe',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('How many servings did you eat?',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _qty > 0.5 ? () => setState(() => _qty -= 0.5) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 90,
                  child: Text(_fmtQty(_qty),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                ),
                IconButton.filledTonal(
                  onPressed: _qty < 20 ? () => setState(() => _qty += 0.5) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final q in const [0.5, 1.0, 1.5, 2.0])
                  ChoiceChip(
                    label: Text(q == 0.5 ? '½' : _fmtQty(q)),
                    selected: _qty == q,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: _qty == q ? AppColors.onAccent : AppColors.ink),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _qty = q),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _n('${(ps.kcal * _qty).round()}', 'kcal'),
                _n('${(ps.protein * _qty).round()} g', 'Protein'),
                _n('${(ps.carbs * _qty).round()} g', 'Carbs'),
                _n('${(ps.fat * _qty).round()} g', 'Fat'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in mealOrder)
                  ChoiceChip(
                    label: Text(mealLabels[m] ?? m),
                    selected: _meal == m,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: _meal == m ? AppColors.onAccent : AppColors.ink),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _meal = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'Add to ${mealLabels[_meal] ?? _meal}',
              icon: Icons.check,
              onPressed: () {
                final app = context.read<AppState>();
                final now = widget.at ?? DateTime.now();
                final nav = Navigator.of(context);
                final msg = ScaffoldMessenger.of(context);
                final name = r['name']?.toString() ?? 'Recipe';
                app.addEntry(DiaryEntry(
                  id: '${DateTime.now().microsecondsSinceEpoch}',
                  name: _qty == 1 ? name : '${_fmtQty(_qty)} x $name',
                  meal: _meal,
                  kcal: ps.kcal * _qty,
                  protein: ps.protein * _qty,
                  carbs: ps.carbs * _qty,
                  fat: ps.fat * _qty,
                  at: now,
                ));
                nav.pop();
                msg.showSnackBar(SnackBar(content: Text('Added to ${mealLabels[_meal] ?? _meal}')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _n(String v, String l) => Expanded(
        child: Column(
          children: [
            Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(l, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );
}

/// Create or edit a recipe.
class RecipeEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const RecipeEditorScreen({super.key, this.existing});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _servings;
  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _servings = TextEditingController(text: e == null ? '4' : _fmtQty(recipeServings(e)));
    _items = [
      for (final x in (e?['items'] as List? ?? const []))
        if (x is Map) Map<String, dynamic>.from(x),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    super.dispose();
  }

  double get _srv {
    final v = double.tryParse(_servings.text.replaceAll(',', '.')) ?? 1;
    return v <= 0 ? 1 : v;
  }

  Map<String, dynamic> _draft() => {
        'id': widget.existing?['id'] ?? '${DateTime.now().microsecondsSinceEpoch}',
        'name': _name.text.trim(),
        'servings': _srv,
        'items': _items,
      };

  Future<void> _addIngredient() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => const _IngredientPicker(),
    );
    if (picked != null) setState(() => _items.add(picked));
  }

  void _save() {
    final msg = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Give the recipe a name.')));
      return;
    }
    if (_items.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Add at least one ingredient.')));
      return;
    }
    context.read<AppState>().saveRecipe(_draft());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ps = recipePerServing(_draft());
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(widget.existing == null ? 'New recipe' : 'Edit recipe')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Recipe name', hintText: 'Mummy ki dal'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _servings,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Servings (how many portions this makes)'),
              onChanged: (_) => setState(() {}),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 8, left: 4),
              child: Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('No ingredients yet. Do not forget oil or ghee.',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_items[i]['name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(
                                '${_fmtQty((_items[i]['qty'] as num?)?.toDouble() ?? 1)} x ${_items[i]['serving'] ?? ''}',
                                style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${((_items[i]['kcal'] as num?) ?? 0).round()} kcal',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _items.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 8, left: 4),
              child: Text('Per serving', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            AppCard(
              radius: 22,
              child: Row(
                children: [
                  _n('${ps.kcal.round()}', 'kcal'),
                  _n('${ps.protein.round()} g', 'Protein'),
                  _n('${ps.carbs.round()} g', 'Carbs'),
                  _n('${ps.fat.round()} g', 'Fat'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(label: 'Save recipe', icon: Icons.check, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _n(String v, String l) => Expanded(
        child: Column(
          children: [
            Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(l, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );
}

/// Search the ingredient lists, or type the numbers yourself.
class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker();

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _q = '';

  Future<void> _choose(FoodPreset f) async {
    final c = TextEditingController(text: '1');
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How many of: ${f.serving}?'),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'For example 2 or 0.5'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    Navigator.pop(context, {
      'name': f.name,
      'serving': f.serving,
      'qty': qty,
      'kcal': f.kcal * qty,
      'p': f.protein * qty,
      'c': f.carbs * qty,
      'f': f.fat * qty,
    });
  }

  Future<void> _manual() async {
    final name = TextEditingController();
    final k = TextEditingController();
    final p = TextEditingController();
    final c = TextEditingController();
    final f = TextEditingController();
    double n(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;
    Widget field(TextEditingController t, String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextField(
              controller: t,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: label),
            ),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add by numbers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ingredient name')),
            const SizedBox(height: 8),
            Row(children: [field(k, 'kcal')]),
            Row(children: [field(p, 'Protein g'), field(c, 'Carbs g'), field(f, 'Fat g')]),
            const SizedBox(height: 6),
            Text('Total for the amount you put in the recipe.',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    Navigator.pop(context, {
      'name': name.text.trim(),
      'serving': 'as entered',
      'qty': 1.0,
      'kcal': n(k),
      'p': n(p),
      'c': n(c),
      'f': n(f),
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = allIngredientChoices
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                    hintText: 'Search: dal, atta, tel, paneer...', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final f in list)
                    ListTile(
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${f.serving} · ${f.kcal.round()} kcal',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      onTap: () => _choose(f),
                    ),
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: AppColors.primary),
                    title: const Text('Not in the list? Enter numbers',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onTap: _manual,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
