import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class MealAiException implements Exception {
  final String message;
  final bool limit;
  MealAiException(this.message, {this.limit = false});
  @override
  String toString() => message;
}

class MealItem {
  String name;
  String serving;
  double kcal;
  double protein;
  double carbs;
  double fat;
  double qty = 1;

  MealItem(this.name, this.serving, this.kcal, this.protein, this.carbs, this.fat);
}

class MealResult {
  final List<MealItem> items;
  final String notes;
  const MealResult(this.items, this.notes);
}

/// Sends one meal photo to the `coach` edge function (mode "meal").
/// Counts as one daily AI request. The photo is not stored.
class MealAi {
  static Future<MealResult> read(List<int> jpegBytes) async {
    Map<String, dynamic> data;
    try {
      final res = await Supabase.instance.client.functions.invoke('coach', body: {
        'mode': 'meal',
        'image': base64Encode(jpegBytes),
        'mime': 'image/jpeg',
      });
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      throw MealAiException(
        d is Map && d['message'] != null ? d['message'].toString() : 'Could not read the photo. Try again.',
        limit: d is Map && d['error'] == 'limit',
      );
    } catch (_) {
      throw MealAiException('No internet or sign-in problem. Try again.');
    }
    final m = data['meal'];
    if (m is! Map || m['readable'] == false) {
      throw MealAiException('I could not see food in that photo. Take it from above, in good light.');
    }
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    final items = [
      for (final x in (m['items'] as List? ?? const []))
        MealItem('${x['name']}', '${x['serving'] ?? '1 serving'}', n(x['kcal']), n(x['protein']),
            n(x['carbs']), n(x['fat'])),
    ];
    if (items.isEmpty) throw MealAiException('I could not see food in that photo.');
    return MealResult(items, '${m['notes'] ?? ''}');
  }
}
