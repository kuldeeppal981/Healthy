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

class _AddFoodForm extends StatefulWidget {
  final String initialMeal;
  final bool startCustom;

  const _AddFoodForm({required this.initialMeal, required this.startCustom});

  @override
  State<_AddFoodForm> createState() => _AddFoodFormState();
}

class _AddFoodFormState extends State<_AddFoodForm> {
  late bool _custom = widget.startCustom;
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
    var servings = 1.0;
    final count = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(f.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1 serving = ${f.serving}',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Fewer servings',
                      onPressed: servings > 0.5 ? () => setLocal(() => servings -= 0.5) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(_fmt(servings),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    IconButton.outlined(
                      tooltip: 'More servings',
                      onPressed: () => setLocal(() => servings += 0.5),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${(f.kcal * servings).round()} kcal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                onPressed: () => Navigator.pop(ctx, servings),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
    if (count == null || !mounted) return;
    final label = count == 1 ? '${f.name} (${f.serving})' : '${_fmt(count)} x ${f.name} (${f.serving})';
    _addEntry(label, f.kcal * count, f.protein * count, f.carbs * count, f.fat * count);
    Navigator.of(context).pop();
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
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Indian foods')),
                ButtonSegment(value: true, label: Text('Custom')),
              ],
              selected: {_custom},
              onSelectionChanged: (v) => setState(() => _custom = v.first),
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
