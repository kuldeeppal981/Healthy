import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'allergy_checker.dart';

class LabelAiException implements Exception {
  final String message;
  LabelAiException(this.message);
  @override
  String toString() => message;
}

/// Sends a photo of a food label to the `coach` edge function (mode "label")
/// and turns the answer into a [FoodItem]. The AI key stays on the server.
class LabelAi {
  static Future<FoodItem> read(List<int> jpegBytes) async {
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'coach',
        body: {
          'mode': 'label',
          'image': base64Encode(jpegBytes),
          'mime': 'image/jpeg',
        },
      );
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
      throw LabelAiException('I could not find a label in that photo. Take a closer, clearer photo of the ingredients and nutrition table.');
    }
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
      brand: '',
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
