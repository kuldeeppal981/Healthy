import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Bottom sheet to add a food by hand (when a scan finds nothing, or for
/// home food like roti and dal).
Future<void> showAddFoodSheet(
  BuildContext context, {
  String? meal,
  String? name,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddFoodForm(initialMeal: meal ?? mealForNow(), initialName: name),
  );
}

class _AddFoodForm extends StatefulWidget {
  final String initialMeal;
  final String? initialName;

  const _AddFoodForm({required this.initialMeal, this.initialName});

  @override
  State<_AddFoodForm> createState() => _AddFoodFormState();
}

class _AddFoodFormState extends State<_AddFoodForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  late String _meal = widget.initialMeal;

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

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || _n(_kcal) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naam aur calories daalo')),
      );
      return;
    }
    context.read<AppState>().addEntry(
          DiaryEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            meal: _meal,
            kcal: _n(_kcal),
            protein: _n(_protein),
            carbs: _n(_carbs),
            fat: _n(_fat),
            at: DateTime.now(),
          ),
        );
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khana add karo',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _field('Naam (jaise 2 roti + dal)', _name, number: false),
            const SizedBox(height: 10),
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
            FilledButton(onPressed: _save, child: const Text('Add karo')),
          ],
        ),
      ),
    );
  }
}
