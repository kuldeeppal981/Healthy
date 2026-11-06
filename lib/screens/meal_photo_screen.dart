import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../services/meal_ai.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ai_wait.dart';
import '../widgets/pro_sheet.dart';

/// Take a photo of a meal, AI estimates calories, you fix portions and save.
class MealPhotoScreen extends StatefulWidget {
  const MealPhotoScreen({super.key});

  @override
  State<MealPhotoScreen> createState() => _MealPhotoScreenState();
}

class _MealPhotoScreenState extends State<MealPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  int? _size;
  String? _error;
  MealResult? _result;
  String _meal = mealForNow();

  Future<void> _go(ImageSource source) async {
    final s = context.read<AppState>();
    if (!cloudEnabled || !s.signedIn) {
      setState(() => _error = 'Sign in to use photo logging.');
      return;
    }
    setState(() => _error = null);
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 1400, imageQuality: 80);
      if (f == null) return;
      setState(() {
        _busy = true;
        _result = null;
      });
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _size = bytes.length);
      final r = await MealAi.read(bytes);
      if (!mounted) return;
      setState(() => _result = r);
    } on MealAiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.limit) showProLimitSheet(context, e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera or photo. Allow permission and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _q(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  double get _total => _result == null
      ? 0
      : _result!.items.fold(0.0, (a, i) => a + i.kcal * i.qty);

  void _save() {
    final r = _result;
    if (r == null) return;
    final s = context.read<AppState>();
    final now = DateTime.now();
    var n = 0;
    for (final i in r.items) {
      if (i.qty <= 0) continue;
      s.addEntry(DiaryEntry(
        id: '${now.microsecondsSinceEpoch}${n++}',
        name: i.qty == 1 ? i.name : '${_q(i.qty)} x ${i.name}',
        meal: _meal,
        kcal: i.kcal * i.qty,
        protein: i.protein * i.qty,
        carbs: i.carbs * i.qty,
        fat: i.fat * i.qty,
        at: now,
      ));
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $n item${n == 1 ? '' : 's'} to ${mealLabels[_meal] ?? _meal}')),
    );
  }

  // label, key, unit, daily reference, isLimit (true = try to stay under)
  static const _nutri = <List<Object>>[
    ['Fiber', 'fiber', 'g', 30.0, false],
    ['Iron', 'iron_mg', 'mg', 18.0, false],
    ['Calcium', 'calcium_mg', 'mg', 1000.0, false],
    ['Potassium', 'potassium_mg', 'mg', 3500.0, false],
    ['Vitamin A', 'vit_a_mcg', 'mcg', 900.0, false],
    ['Vitamin C', 'vit_c_mg', 'mg', 80.0, false],
    ['Vitamin B12', 'vit_b12_mcg', 'mcg', 2.4, false],
    ['Vitamin D', 'vit_d_mcg', 'mcg', 15.0, false],
    ['Sugar', 'sugar', 'g', 50.0, true],
    ['Saturated fat', 'sat_fat', 'g', 22.0, true],
    ['Sodium', 'sodium_mg', 'mg', 2000.0, true],
  ];

  double _sum(String key) => _result == null
      ? 0
      : _result!.items.fold(0.0, (a, i) => a + (i.more[key] ?? 0) * i.qty);

  Widget _nutrients() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All nutrients in this meal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Percent is of a typical adult\'s daily need (or daily limit for sugar, saturated fat and sodium).',
              style: TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 10),
          for (final n in _nutri) _nutriRow(n),
        ],
      ),
    );
  }

  Widget _nutriRow(List<Object> n) {
    final v = _sum(n[1] as String);
    final ref = n[3] as double;
    final limit = n[4] as bool;
    final pct = ref == 0 ? 0.0 : v / ref;
    final over = limit && pct > 0.4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(n[0] as String, style: const TextStyle(fontSize: 13))),
              Text('${v >= 10 ? v.round() : v.toStringAsFixed(1)} ${n[2]}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              SizedBox(
                width: 52,
                child: Text('${(pct * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: over ? AppColors.danger : AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              color: over ? AppColors.danger : AppColors.primary,
              backgroundColor: AppColors.track,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(MealItem i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${i.serving}  |  ${(i.kcal * i.qty).round()} kcal',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(
                        'P ${(i.protein * i.qty).round()} g  C ${(i.carbs * i.qty).round()} g  F ${(i.fat * i.qty).round()} g',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Less',
                onPressed: i.qty > 0 ? () => setState(() => i.qty = (i.qty - 0.5).clamp(0, 10).toDouble()) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('x${_q(i.qty)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                tooltip: 'More',
                onPressed: () => setState(() => i.qty = (i.qty + 0.5).clamp(0, 10).toDouble()),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Meal photo')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('Take a photo of your plate from above. AI estimates the calories, you fix the portions.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _busy ? null : () => _go(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _busy ? null : () => _go(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Uses 1 daily AI request. The photo is not saved.',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
            if (_busy) ...[
              const SizedBox(height: 16),
              AiWaitCard(doing: 'Looking at your meal', sizeBytes: _size),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(color: AppColors.danger)),
            ],
            if (r != null) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text('What I see',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  Text('${_total.round()} kcal', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              for (final i in r.items) _row(i),
              const SizedBox(height: 4),
              _nutrients(),
              const SizedBox(height: 10),
              AppCard(
                color: AppColors.warnBg,
                borderColor: AppColors.warnBg,
                radius: 14,
                child: Text(
                  'This is an estimate from a photo. Portions are a guess and hidden oil, sugar or allergens cannot be seen. Fix the amounts with + and -. Vitamins and minerals are typical values for the dish, so treat them as a rough guide.${r.notes.isEmpty ? '' : ' ${r.notes}'}',
                  style: TextStyle(color: AppColors.warnInk, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in mealOrder)
                    ChoiceChip(
                      label: Text(mealLabels[m] ?? m),
                      selected: _meal == m,
                      onSelected: (_) => setState(() => _meal = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              GradientButton(label: 'Add to diary', icon: Icons.check, onPressed: _save),
            ],
          ],
        ),
      ),
    );
  }
}
