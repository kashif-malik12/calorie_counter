// lib/data/models.dart

class Food {
  final int? id;
  final String name;

  // Nutrition values stored "per baseAmount of unit"
  // Example:
  // - unit=g, baseAmount=100 => per 100g
  // - unit=tbsp, baseAmount=1 => per 1 tbsp
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double fiber;
  final double sugar;
  final double sodium;

  // ✅ NEW
  final String unit; // g, ml, tbsp, piece, ...
  final double baseAmount; // 100 for g/ml, 1 for tbsp/piece/etc

  const Food({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.unit = 'g',
    this.baseAmount = 100,
  });

  Food copyWith({
    int? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? sodium,
    String? unit,
    double? baseAmount,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      unit: unit ?? this.unit,
      baseAmount: baseAmount ?? this.baseAmount,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'unit': unit.trim().isEmpty ? 'g' : unit,
        'base_amount': baseAmount,
      };

  static Food fromMap(Map<String, Object?> m) => Food(
        id: (m['id'] as int?),
        name: (m['name'] as String),
        calories: (m['calories'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: ((m['fiber'] as num?) ?? 0).toDouble(),
        sugar: ((m['sugar'] as num?) ?? 0).toDouble(),
        sodium: ((m['sodium'] as num?) ?? 0).toDouble(),
        unit: (m['unit'] as String?)?.trim().isNotEmpty == true ? (m['unit'] as String) : 'g',
        baseAmount: ((m['base_amount'] as num?) ?? 100).toDouble(),
      );
}

class LogEntry {
  final int? id;
  final String date; // "yyyy-MM-dd"
  final int? foodId;

  // amount in the food's unit
  final double grams;

  // ✅ snapshot (so history survives edits/deletes)
  final String unit;
  final double baseAmount;

  // UI fields
  final String? time; // "HH:mm"
  final String? label; // "Breakfast" etc.

  // snapshot nutrition per baseAmount (legacy column names in DB)
  final String? foodName;
  final double? calories100;
  final double? protein100;
  final double? carbs100;
  final double? fat100;

  const LogEntry({
    this.id,
    required this.date,
    required this.foodId,
    required this.grams,
    this.unit = 'g',
    this.baseAmount = 100,
    this.time,
    this.label,
    this.foodName,
    this.calories100,
    this.protein100,
    this.carbs100,
    this.fat100,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'food_id': foodId,
        'grams': grams,
        'unit': unit.trim().isEmpty ? 'g' : unit,
        'base_amount': baseAmount,
        'time': time,
        'label': label,

        // snapshot nutrition
        'food_name': foodName,
        'calories_100': calories100,
        'protein_100': protein100,
        'carbs_100': carbs100,
        'fat_100': fat100,
      };

  static LogEntry fromMap(Map<String, Object?> m) => LogEntry(
        id: (m['id'] as int?),
        date: (m['date'] as String),
        foodId: (m['food_id'] as int?),
        grams: (m['grams'] as num).toDouble(),
        unit: (m['unit'] as String?)?.trim().isNotEmpty == true ? (m['unit'] as String) : 'g',
        baseAmount: ((m['base_amount'] as num?) ?? 100).toDouble(),
        time: (m['time'] as String?),
        label: (m['label'] as String?),

        // snapshot nutrition
        foodName: (m['food_name'] as String?),
        calories100: (m['calories_100'] as num?)?.toDouble(),
        protein100: (m['protein_100'] as num?)?.toDouble(),
        carbs100: (m['carbs_100'] as num?)?.toDouble(),
        fat100: (m['fat_100'] as num?)?.toDouble(),
      );
}

class DayTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double fiber;
  final double sugar;
  final double sodium;

  const DayTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
  });

  DayTotals addScaledFood(Food food, double amount) {
    final safeBase = food.baseAmount <= 0 ? 1 : food.baseAmount;
    final factor = amount / safeBase;

    return DayTotals(
      calories: calories + food.calories * factor,
      protein: protein + food.protein * factor,
      carbs: carbs + food.carbs * factor,
      fat: fat + food.fat * factor,
      fiber: fiber + food.fiber * factor,
      sugar: sugar + food.sugar * factor,
      sodium: sodium + food.sodium * factor,
    );
  }
}