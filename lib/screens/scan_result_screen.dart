import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/allergy_checker.dart';
import '../services/food_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';

/// Shows a scanned product, warns about the user's allergies, and lets the
/// user add it to today's diary.
class ScanResultScreen extends StatefulWidget {
  final String barcode;

  const ScanResultScreen({super.key, required this.barcode});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late Future<FoodItem?> _future = _load();
  double _grams = 100;

  Future<FoodItem?> _load() async {
    final item = await FoodService().lookup(widget.barcode);
    if (item != null) _grams = item.servingGrams;
    return item;
  }

  void _retry() => setState(() => _future = _load());

  Color _gradeColor(String? g) {
    switch (g) {
      case 'A':
        return const Color(0xFF2E9E5B);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C':
        return const Color(0xFFFFC107);
      case 'D':
        return const Color(0xFFFF9800);
      case 'E':
        return const Color(0xFFE53935);
      default:
        return AppColors.track;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan result')),
      body: FutureBuilder<FoodItem?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _message(
              'Network or server problem. Please try again.',
              actionLabel: 'Try again',
              onAction: _retry,
            );
          }
          final item = snap.data;
          if (item == null) {
            return _message(
              'This product was not found in the database (${widget.barcode}). You can add the calories yourself.',
              actionLabel: 'Add manually',
              onAction: () async {
                await showAddFoodSheet(context, customMode: true);
                if (context.mounted) Navigator.of(context).pop();
              },
            );
          }
          return _content(context, item);
        },
      ),
    );
  }

  Widget _message(String text, {required String actionLabel, required VoidCallback onAction}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, FoodItem item) {
    final s = context.watch<AppState>();
    final hits = checkProduct(item, s.allergies, traceWarning: s.traceWarning);
    final contains = hits.where((h) => !h.traceOnly).toList();
    final traces = hits.where((h) => h.traceOnly).toList();
    final incomplete = dataIsIncomplete(item);

    final kcal = FoodItem.scale(item.kcal100, _grams);
    final protein = FoodItem.scale(item.protein100, _grams);
    final carbs = FoodItem.scale(item.carbs100, _grams);
    final fat = FoodItem.scale(item.fat100, _grams);
    final sugar = FoodItem.scale(item.sugar100, _grams);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _banner(contains, traces, incomplete, s.allergies.isEmpty),
        const SizedBox(height: 12),
        AppCard(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.brand.isNotEmpty)
                          Text(item.brand,
                              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        Text(item.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (item.nutriGrade != null)
                    Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _gradeColor(item.nutriGrade),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(item.nutriGrade!,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87)),
                        ),
                        const SizedBox(height: 2),
                        const Text('Nutri-Score',
                            style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('${kcal.round()}', 'kcal'),
                  _stat('${protein.toStringAsFixed(1)} g', 'protein'),
                  _stat('${sugar.toStringAsFixed(1)} g', 'sugar',
                      warn: item.sugar100 > 15),
                  _stat('${fat.toStringAsFixed(1)} g', 'fat'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: 'Less 25 g',
                    onPressed: _grams > 25 ? () => setState(() => _grams -= 25) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text('${_grams.round()} g',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton.outlined(
                    tooltip: 'More 25 g',
                    onPressed: () => setState(() => _grams += 25),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingredients',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (item.ingredients.trim().isEmpty)
                const Text('Ingredient list is not available in the database.',
                    style: TextStyle(color: AppColors.muted))
              else
                Text.rich(
                  TextSpan(children: _spans(item.ingredients, s.allergies)),
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (contains.isNotEmpty)
          OutlinedButton(
            onPressed: () => _add(context, item, kcal, protein, carbs, fat),
            child: const Text('Add to diary anyway'),
          )
        else
          FilledButton(
            onPressed: () => _add(context, item, kcal, protein, carbs, fat),
            child: const Text('Add to diary'),
          ),
      ],
    );
  }

  Widget _banner(
    List<AllergyHit> contains,
    List<AllergyHit> traces,
    bool incomplete,
    bool noAllergiesSet,
  ) {
    Widget box(Color bg, Color fg, IconData icon, String title, String body) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(fontSize: 13, height: 1.4, color: fg)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (contains.isNotEmpty) {
      final names = contains.map((h) => h.allergen.label).join(', ');
      return box(
        AppColors.danger,
        Colors.white,
        Icons.warning_amber_rounded,
        'Allergy alert: $names',
        contains.map((h) => '${h.allergen.label}: ${h.reason}').join('\n'),
      );
    }
    if (traces.isNotEmpty) {
      final names = traces.map((h) => h.allergen.label).join(', ');
      return box(
        AppColors.warnBg,
        AppColors.warnInk,
        Icons.info_outline,
        'May contain: $names',
        'This product may contain traces. Avoid it if your allergy is severe.',
      );
    }
    if (noAllergiesSet) {
      return box(
        AppColors.chipBg,
        AppColors.chipInk,
        Icons.shield_outlined,
        'Your allergy profile is empty',
        'Select your allergies in the Allergy tab to get an alert on every scan.',
      );
    }
    if (incomplete) {
      return box(
        AppColors.warnBg,
        AppColors.warnInk,
        Icons.help_outline,
        'No allergen data found',
        'Ingredient data for this product is incomplete, so we cannot call it safe. Please read the label yourself.',
      );
    }
    return box(
      AppColors.safeBg,
      AppColors.safe,
      Icons.check_circle_outline,
      'No match with your allergies',
      'Data is from Open Food Facts. Please also check the label before eating.',
    );
  }

  Widget _stat(String value, String label, {bool warn = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: warn ? AppColors.dangerBg : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: warn ? AppColors.danger : AppColors.ink,
                )),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: warn ? AppColors.danger : AppColors.muted,
                )),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _spans(String text, Set<String> allergies) {
    final re = highlightRegex(allergies);
    if (re == null) return [TextSpan(text: text)];

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: const TextStyle(
          backgroundColor: AppColors.dangerBg,
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  void _add(BuildContext context, FoodItem item, double kcal, double protein,
      double carbs, double fat) {
    context.read<AppState>().addEntry(
          DiaryEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: '${item.name} (${_grams.round()} g)',
            meal: mealForNow(),
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            at: DateTime.now(),
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to your diary')),
    );
    Navigator.of(context).pop();
  }
}
