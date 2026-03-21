// lib/services/food_search.dart
//
// Uses the USDA FoodData Central API (free, no sign-up required with DEMO_KEY).
// All nutrient values returned are per 100 g / 100 ml.

import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodSearchResult {
  final String name;
  final double calories;  // per 100 g
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;    // mg per 100 g

  const FoodSearchResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
  });

  /// Pretty label shown in the results list.
  String get macroSummary =>
      '${calories.toStringAsFixed(0)} kcal  •  '
      'P ${protein.toStringAsFixed(1)} g  •  '
      'C ${carbs.toStringAsFixed(1)} g  •  '
      'F ${fat.toStringAsFixed(1)} g'
      '  (per 100 g)';
}

/// USDA nutrient IDs we care about.
const _kNutrientIds = {
  1008: 'calories',  // Energy, kcal
  1003: 'protein',   // Protein
  1005: 'carbs',     // Carbohydrate, by difference
  1004: 'fat',       // Total lipid (fat)
  1079: 'fiber',     // Fiber, total dietary
  2000: 'sugar',     // Sugars, total
  1093: 'sodium',    // Sodium, Na
};

/// Capitalises each word (USDA names are ALL-CAPS).
String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');

Future<List<FoodSearchResult>> searchFoodsOnline(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
    'query': trimmed,
    'api_key': 'DEMO_KEY',
    'pageSize': '20',
    'dataType': 'Foundation,SR Legacy',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) {
    throw Exception('Search failed (HTTP ${response.statusCode})');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final foods = (body['foods'] as List?) ?? [];

  final results = <FoodSearchResult>[];

  for (final f in foods) {
    final nutrients = (f['foodNutrients'] as List?) ?? [];

    double get(int id) {
      for (final n in nutrients) {
        if ((n['nutrientId'] as int?) == id) {
          return ((n['value'] as num?) ?? 0).toDouble();
        }
      }
      return 0;
    }

    final calories = get(1008);
    if (calories <= 0) continue; // skip zero-calorie entries

    results.add(FoodSearchResult(
      name: _titleCase(f['description'] as String? ?? 'Unknown'),
      calories: calories,
      protein: get(1003),
      carbs: get(1005),
      fat: get(1004),
      fiber: get(1079),
      sugar: get(2000),
      sodium: get(1093),
    ));
  }

  return results;
}
