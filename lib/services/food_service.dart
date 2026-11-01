import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

/// Looks up packaged products on Open Food Facts (free, open database).
/// Indian coverage is partial, so always offer manual add as a fallback.
class FoodService {
  Future<FoodItem?> lookup(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode.json',
      {
        'fields': 'product_name,brands,nutriments,ingredients_text,'
            'allergens_tags,traces_tags,nutrition_grades,serving_quantity',
      },
    );

    final res = await http.get(uri, headers: {
      'User-Agent': 'HealthyApp/0.1 (change-this@example.com)',
    }).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;

    final p = (data['product'] ?? {}) as Map<String, dynamic>;
    final n = (p['nutriments'] ?? {}) as Map<String, dynamic>;

    double num0(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}') ?? 0;
    }

    List<String> tags(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    double? opt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    // Sodium is in grams per 100 g; salt in grams (sodium is about 0.4 of salt).
    final sodiumG = opt(n['sodium_100g']);
    final saltG = opt(n['salt_100g']);
    final sodiumMg = sodiumG != null ? sodiumG * 1000 : (saltG != null ? saltG * 400 : null);

    final serving = num0(p['serving_quantity']);
    final grade = (p['nutrition_grades'] ?? '').toString().trim();

    return FoodItem(
      barcode: barcode,
      name: (p['product_name'] ?? '').toString().trim().isEmpty
          ? 'Unnamed product'
          : p['product_name'].toString().trim(),
      brand: (p['brands'] ?? '').toString().split(',').first.trim(),
      kcal100: num0(n['energy-kcal_100g']),
      protein100: num0(n['proteins_100g']),
      carbs100: num0(n['carbohydrates_100g']),
      fat100: num0(n['fat_100g']),
      sugar100: num0(n['sugars_100g']),
      ingredients: (p['ingredients_text'] ?? '').toString(),
      allergenTags: tags(p['allergens_tags']),
      traceTags: tags(p['traces_tags']),
      nutriGrade: grade.length == 1 ? grade.toUpperCase() : null,
      servingGrams: serving > 0 ? serving : 100,
      satFat100: opt(n['saturated-fat_100g']),
      sodiumMg100: sodiumMg,
      fiber100: opt(n['fiber_100g']),
    );
  }
}
