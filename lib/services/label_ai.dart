import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'allergy_checker.dart';

class LabelAiException implements Exception {
  final String message;
  final bool unreadable;
  LabelAiException(this.message, {this.unreadable = false});
  @override
  String toString() => message;
}

/// Sends a photo of a food label to the `coach` edge function (mode "label")
/// and turns the answer into a [FoodItem]. The AI key stays on the server.
class LabelAi {
  /// Hybrid reading: phone OCR (free) -> our saved products -> AI.
  /// [path] is the photo file, [jpegBytes] its bytes (used when OCR is not enough).
  static Future<FoodItem> read(String path, List<int> jpegBytes) async {
    final client = Supabase.instance.client;
    final text = await _ocr(path);
    final key = text.length >= 60 ? ingredientKey(text) : null;

    // 1. Saved before? Then no AI is needed.
    if (key != null) {
      try {
        final hit = await client.rpc('find_label_product', params: {'p_hash': key});
        if (hit is Map) {
          return _fromLabel(Map<String, dynamic>.from(hit), brand: 'From saved scans');
        }
      } catch (_) {}
    }

    // 2. Ask the AI. Text only when OCR worked (cheaper), else the photo.
    Map<String, dynamic> label;
    if (text.length >= 60) {
      try {
        label = await _askAi({'mode': 'label', 'text': text});
      } on LabelAiException catch (e) {
        if (!e.unreadable) rethrow;
        label = await _askAi(_imageBody(jpegBytes));
      }
    } else {
      label = await _askAi(_imageBody(jpegBytes));
    }

    // 3. Save for everyone (best effort).
    final ing = (label['ingredients'] ?? '').toString();
    if (key != null && ing.length >= 10) {
      try {
        await client.rpc('save_label_product', params: {
          'p_hash': key,
          'p_name': (label['name'] ?? '').toString(),
          'p_ingredients': ing,
          'p_contains': List<String>.from((label['contains'] as List?) ?? const []),
          'p_may': List<String>.from((label['may_contain'] as List?) ?? const []),
          'p_serving': label['serving_grams'],
          'p_per100': label['per100'] ?? <String, dynamic>{},
        });
      } catch (_) {}
    }
    return _fromLabel(label);
  }

  static Map<String, dynamic> _imageBody(List<int> bytes) =>
      {'mode': 'label', 'image': base64Encode(bytes), 'mime': 'image/jpeg'};

  static Future<String> _ocr(String path) async {
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await rec.processImage(InputImage.fromFilePath(path));
      return res.text;
    } catch (_) {
      return '';
    } finally {
      await rec.close();
    }
  }

  /// A fingerprint of the ingredient list: the words after "ingredients",
  /// lower case, unique and sorted, so line breaks and word order do not
  /// matter. Null when no ingredient list is found.
  static String? ingredientKey(String text) {
    final low = text.toLowerCase().replaceAll('\n', ' ');
    final i = low.indexOf('ingredient');
    if (i < 0) return null;
    var seg = low.substring(i + 10);
    for (final stop in const [
      'nutrition', 'nutritional', 'allergen', 'fssai', 'net wt', 'net qty',
      'mfd', 'best before', 'manufactured', 'storage', 'energy',
    ]) {
      final j = seg.indexOf(stop);
      if (j > 20) seg = seg.substring(0, j);
    }
    final words = RegExp(r'[a-z]{3,}').allMatches(seg).map((m) => m.group(0)!).toSet().toList()..sort();
    if (words.length < 5) return null;
    return sha256.convert(utf8.encode(words.join(' '))).toString();
  }

  static Future<Map<String, dynamic>> _askAi(Map<String, dynamic> body) async {
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions.invoke('coach', body: body);
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['message'] != null
          ? d['message'].toString()
          : 'Could not read the photo. Try again.';
      throw LabelAiException(msg);
    } catch (_) {
      throw LabelAiException('No internet or sign-in problem. Try again.');
    }
    final l = data['label'];
    if (l is! Map || l['readable'] == false) {
      throw LabelAiException(
        'I could not find a label in that photo. Take a closer, clearer photo of the ingredients and nutrition table.',
        unreadable: true,
      );
    }
    return Map<String, dynamic>.from(l);
  }

  static FoodItem _fromLabel(Map<String, dynamic> l, {String brand = ''}) {
    final per = (l['per100'] is Map) ? Map<String, dynamic>.from(l['per100'] as Map) : <String, dynamic>{};
    double? d(String k) => (per[k] is num) ? (per[k] as num).toDouble() : null;

    final contains = _tags(l['contains']);
    final may = _tags(l['may_contain']);
    final name = (l['name'] ?? '').toString().trim();
    final serving = (l['serving_grams'] is num && (l['serving_grams'] as num) > 0)
        ? (l['serving_grams'] as num).toDouble()
        : 100.0;
    return FoodItem(
      barcode: '',
      name: name.isEmpty ? 'Scanned product' : name,
      brand: brand,
      kcal100: d('kcal') ?? 0,
      protein100: d('protein') ?? 0,
      carbs100: d('carbs') ?? 0,
      fat100: d('fat') ?? 0,
      sugar100: d('sugar') ?? 0,
      ingredients: (l['ingredients'] ?? '').toString(),
      allergenTags: contains,
      traceTags: may,
      nutriGrade: null,
      servingGrams: serving,
      fromLabel: true,
      satFat100: d('sat_fat'),
      sodiumMg100: d('sodium_mg'),
      fiber100: d('fiber'),
    );
  }

  /// Maps words like "milk" or "peanut" to the Open Food Facts style tags
  /// that the allergy checker understands.
  static List<String> _tags(dynamic raw) {
    final out = <String>{};
    if (raw is! List) return const [];
    for (final w0 in raw) {
      final w = w0.toString().toLowerCase().trim();
      if (w.isEmpty) continue;
      for (final def in allergenDefs) {
        final hit = w == def.id ||
            w.contains(def.id) ||
            def.label.toLowerCase().contains(w) ||
            def.keywords.any((k) => w.contains(k));
        if (hit) out.addAll(def.offTags);
      }
    }
    return out.toList();
  }
}
