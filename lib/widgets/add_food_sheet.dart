import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/indian_foods.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Bottom sheet to add food: search common Indian foods, or enter your own.
Future<void> showAddFoodSheet(
  BuildContext context, {
  String? meal,
  bool customMode = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddFoodForm(
      initialMeal: meal ?? mealForNow(),
      startCustom: customMode,
    ),
  );
}

class _Portion {
  final String label;
  final double kcal, protein, carbs, fat;
  const _Portion(this.label, this.kcal, this.protein, this.carbs, this.fat);
}

class _AddFoodForm extends StatefulWidget {
  final String initialMeal;
  final bool startCustom;

  const _AddFoodForm({required this.initialMeal, required this.startCustom});

  @override
  State<_AddFoodForm> createState() => _AddFoodFormState();
}

class _AddFoodFormState extends State<_AddFoodForm> {
  late bool _custom = widget.startCustom;
  bool _quick = false;
  late String _meal = widget.initialMeal;
  String _query = '';

  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _addEntry(String name, double kcal, double p, double c, double f) {
    final hit = context.read<AppState>().reportAvoidHit(name);
    if (hit != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Your report says to limit "$hit". Keep the portion small.'),
        duration: const Duration(seconds: 4),
      ));
    }
    context.read<AppState>().addEntry(
          DiaryEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            meal: _meal,
            kcal: kcal,
            protein: p,
            carbs: c,
            fat: f,
            at: DateTime.now(),
          ),
        );
  }

  void _saveCustom() {
    final name = _name.text.trim();
    if (name.isEmpty || _n(_kcal) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and calories')),
      );
      return;
    }
    _addEntry(name, _n(_kcal), _n(_protein), _n(_carbs), _n(_fat));
    Navigator.of(context).pop();
  }

  Future<void> _pickPreset(FoodPreset f) async {
    final gm = RegExp(r'\((\d+)\s*g\)').firstMatch(f.serving);
    final baseGrams = gm == null ? null : double.tryParse(gm.group(1)!);
    var servings = 1.0;
    var size = 1; // 0 small, 1 medium, 2 large
    var useGrams = false;
    var ghee = 0.0; // teaspoons of extra ghee or oil
    final gramsCtl = TextEditingController(text: baseGrams == null ? '' : _fmt(baseGrams));
    const sizeFactor = [0.75, 1.0, 1.3];
    const sizeName = ['Small', 'Medium', 'Large'];

    final res = await showDialog<_Portion>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final grams = double.tryParse(gramsCtl.text.trim()) ?? 0;
            final factor = (useGrams && baseGrams != null)
                ? grams / baseGrams
                : servings * sizeFactor[size];
            final kcal = f.kcal * factor + ghee * 45;
            final protein = f.protein * factor;
            final carbs = f.carbs * factor;
            final fat = f.fat * factor + ghee * 5;
            return AlertDialog(
              title: Text(f.name),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1 serving = ${f.serving}',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 10),
                    if (baseGrams != null)
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('Pieces')),
                            ButtonSegment(value: true, label: Text('Grams')),
                          ],
                          selected: {useGrams},
                          onSelectionChanged: (v) => setLocal(() => useGrams = v.first),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (useGrams && baseGrams != null)
                      TextField(
                        controller: gramsCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight in grams'),
                        onChanged: (_) => setLocal(() {}),
                      )
                    else ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 0; i < 3; i++)
                            ChoiceChip(
                              label: Text(sizeName[i]),
                              selected: size == i,
                              onSelected: (_) => setLocal(() => size = i),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.outlined(
                            tooltip: 'Fewer',
                            onPressed:
                                servings > 0.5 ? () => setLocal(() => servings -= 0.5) : null,
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(_fmt(servings),
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          ),
                          IconButton.outlined(
                            tooltip: 'More',
                            onPressed: () => setLocal(() => servings += 0.5),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: Text('Extra ghee / oil (tsp)')),
                        IconButton(
                          onPressed: ghee > 0 ? () => setLocal(() => ghee -= 0.5) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(_fmt(ghee), style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: () => setLocal(() => ghee += 0.5),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${kcal.round()} kcal',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('P ${protein.round()} g  |  C ${carbs.round()} g  |  F ${fat.round()} g',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                        'Size and ghee change the calories a lot. Homemade often has more oil than shown.',
                        style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                  onPressed: factor <= 0
                      ? null
                      : () {
                          final extra = ghee > 0 ? ', +${_fmt(ghee)} tsp ghee' : '';
                          final String label;
                          if (useGrams && baseGrams != null) {
                            label = '${f.name} (${_fmt(grams)} g$extra)';
                          } else {
                            final sz = size == 1 ? '' : '${sizeName[size]}, ';
                            label = servings == 1 && size == 1 && ghee == 0
                                ? '${f.name} (${f.serving})'
                                : '${_fmt(servings)} x ${f.name} ($sz${f.serving}$extra)';
                          }
                          Navigator.pop(ctx, _Portion(label, kcal, protein, carbs, fat));
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    gramsCtl.dispose();
    if (res == null || !mounted) return;
    _addEntry(res.label, res.kcal, res.protein, res.carbs, res.fat);
    Navigator.of(context).pop();
  }

  Future<void> _askTemplateName(List<DiaryEntry> items) async {
    final c = TextEditingController(text: 'My ${mealLabels[_meal]?.toLowerCase() ?? 'meal'}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    context.read<AppState>().saveTemplate(name, items, _meal);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved "$name". Tap it any day to add it.')));
  }

  void _addMap(Map<String, dynamic> x) {
    _addEntry(x['name'] as String, (x['kcal'] as num).toDouble(),
        (x['protein'] as num).toDouble(), (x['carbs'] as num).toDouble(),
        (x['fat'] as num).toDouble());
    Navigator.of(context).pop();
  }

  Widget _quickView() {
    final s = context.watch<AppState>();
    final mealToday = s.today.where((e) => e.meal == _meal).toList();
    final recent = s.recentFoods();
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
    return SizedBox(
      height: 340,
      child: ListView(
        children: [
          if (mealToday.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text('Save today\'s ${mealLabels[_meal]?.toLowerCase()} as template'),
                onPressed: () => _askTemplateName(mealToday),
              ),
            ),
          if (s.mealTemplates.isNotEmpty) head('My meals'),
          for (var i = 0; i < s.mealTemplates.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_menu, color: AppColors.primary),
              title: Text(s.mealTemplates[i]['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${((s.mealTemplates[i]['items'] as List?) ?? const []).length} items, one tap adds all'),
              trailing: IconButton(
                tooltip: 'Delete template',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => s.deleteTemplate(i),
              ),
              onTap: () {
                final t = s.mealTemplates[i];
                final hit = [
                  for (final x in (t['items'] as List? ?? const []))
                    if (x is Map) s.reportAvoidHit(x['name'] as String),
                ].whereType<String>().toList();
                s.addTemplate(t, _meal);
                if (hit.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Your report says to limit "${hit.first}". Keep the portion small.')));
                }
                Navigator.of(context).pop();
              },
            ),
          if (s.favFoods.isNotEmpty) head('Favourites'),
          for (final f in s.favFoods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${(f['kcal'] as num).round()} kcal'),
              trailing: const Icon(Icons.star, color: Color(0xFFF59E0B)),
              onTap: () => _addMap(f),
            ),
          if (recent.isNotEmpty) head('Recent'),
          for (final e in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${e.kcal.round()} kcal'),
              trailing: IconButton(
                tooltip: 'Favourite',
                icon: Icon(s.isFavorite(e.name) ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B)),
                onPressed: () => s.toggleFavorite(e),
              ),
              onTap: () => _addMap({
                'name': e.name,
                'kcal': e.kcal,
                'protein': e.protein,
                'carbs': e.carbs,
                'fat': e.fat,
              }),
            ),
          if (recent.isEmpty && s.favFoods.isEmpty && s.mealTemplates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                    'Foods you log will show up here for one-tap adding. Star your favourites and save meals as templates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.4)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool number = true}) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foods = indianFoods
        .where((f) => f.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add food',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in mealOrder)
                ChoiceChip(
                  label: Text(mealLabels[m]!),
                  selected: _meal == m,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Foods')),
                ButtonSegment(value: 1, label: Text('Quick')),
                ButtonSegment(value: 2, label: Text('Custom')),
              ],
              selected: {_custom ? 2 : (_quick ? 1 : 0)},
              onSelectionChanged: (v) => setState(() {
                _custom = v.first == 2;
                _quick = v.first == 1;
              }),
            ),
          ),
          const SizedBox(height: 12),
          if (_custom)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _field('Name (for example 2 roti + dal)', _name, number: false),
                    const SizedBox(height: 10),
                    _field('Calories (kcal)', _kcal),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field('Protein g', _protein)),
                        const SizedBox(width: 8),
                        Expanded(child: _field('Carbs g', _carbs)),
                        const SizedBox(width: 8),
                        Expanded(child: _field('Fat g', _fat)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _saveCustom, child: const Text('Add')),
                  ],
                ),
              ),
            )
          else if (_quick)
            Flexible(child: _quickView())
          else ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search roti, dal, rice, idli...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: foods.isEmpty
                  ? Center(
                      child: Text('No match. Use the Custom tab to add it yourself.',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView.builder(
                      itemCount: foods.length,
                      itemBuilder: (_, i) {
                        final f = foods[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(f.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(f.serving),
                          trailing: Text('${f.kcal.round()} kcal',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () => _pickPreset(f),
                        );
                      },
                    ),
            ),
            Text(
              'Values are approximate for a typical home portion.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
