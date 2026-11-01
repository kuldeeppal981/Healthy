import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/label_parser.dart';
import '../theme.dart';
import 'scan_result_screen.dart';

/// For products without a barcode result: photograph the ingredients label,
/// read it on the phone, let the user fix mistakes, then run the usual
/// allergy check.
class LabelScanScreen extends StatefulWidget {
  const LabelScanScreen({super.key});

  @override
  State<LabelScanScreen> createState() => _LabelScanScreenState();
}

class _LabelScanScreenState extends State<LabelScanScreen> {
  final _name = TextEditingController();
  final _ingredients = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _sugar = TextEditingController();
  final _satFat = TextEditingController();
  final _sodium = TextEditingController();

  bool _busy = false;
  bool _read = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _ingredients, _kcal, _protein, _carbs, _fat, _sugar, _satFat, _sodium]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1));

  Future<void> _capture(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final data = parseLabel(result.text);
      if (!mounted) return;
      setState(() {
        _ingredients.text = data.ingredients;
        _kcal.text = _fmt(data.kcal);
        _protein.text = _fmt(data.protein);
        _carbs.text = _fmt(data.carbs);
        _fat.text = _fmt(data.fat);
        _sugar.text = _fmt(data.sugar);
        _satFat.text = _fmt(data.satFat);
        _sodium.text = _fmt(data.sodiumMg);
        _read = true;
        _busy = false;
        if (result.text.trim().isEmpty) {
          _error = 'No text found. Try again in good light, closer to the label.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not read the photo. Try again, or type the ingredients below.';
        _read = true;
      });
    } finally {
      await recognizer.close();
    }
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  double? _opt(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _check() {
    if (_ingredients.text.trim().isEmpty) {
      setState(() => _error = 'Add the ingredients so we can check them.');
      return;
    }
    final item = FoodItem(
      barcode: '',
      name: _name.text.trim().isEmpty ? 'Scanned label' : _name.text.trim(),
      brand: '',
      kcal100: _d(_kcal),
      protein100: _d(_protein),
      carbs100: _d(_carbs),
      fat100: _d(_fat),
      sugar100: _d(_sugar),
      ingredients: _ingredients.text.trim(),
      allergenTags: const [],
      traceTags: const [],
      nutriGrade: null,
      servingGrams: 100,
      fromLabel: true,
      satFat100: _opt(_satFat),
      sodiumMg100: _opt(_sodium),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ScanResultScreen(barcode: '', item: item)),
    );
  }

  Widget _num(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a label')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Take a clear photo of the ingredients list. We read it on your phone and check it against your allergies.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _capture(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_read ? 'Retake photo' : 'Take photo'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                child: const Text('Gallery'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (_read) ...[
            const SizedBox(height: 20),
            const Text('Check what we read',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Photo reading can miss or mix up words. Fix anything that looks wrong.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Product name (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ingredients,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Nutrition per 100 g (optional)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [_num(_kcal, 'kcal'), const SizedBox(width: 8), _num(_protein, 'Protein g')]),
            const SizedBox(height: 8),
            Row(children: [_num(_carbs, 'Carbs g'), const SizedBox(width: 8), _num(_fat, 'Fat g')]),
            const SizedBox(height: 8),
            Row(children: [_num(_sugar, 'Sugar g'), const SizedBox(width: 8), _num(_satFat, 'Sat. fat g')]),
            const SizedBox(height: 8),
            Row(children: [_num(_sodium, 'Sodium mg'), const Spacer()]),
            const SizedBox(height: 20),
            FilledButton(onPressed: _check, child: const Text('Check allergies')),
          ],
        ],
      ),
    );
  }
}
