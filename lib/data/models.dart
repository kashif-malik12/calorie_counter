// lib/data/models.dart

class Food {
  final int? id;
  final String name;

  // per 100g values (your UI scales by grams)
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double fiber;
  final double sugar;
  final double sodium;

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
      );
}

class LogEntry {
  final int? id;
  final String date; // e.g. "2026-03-04"

  /// Nullable now:
  /// - foodId != null for "saved foods"
  /// - foodId == null for "one-time custom items"
  final int? foodId;

  final double grams;

  // UI fields
  final String? time; // "HH:mm"
  final String? label; // "Breakfast" / "Snack" / ...

  /// Snapshot fields (so history survives food deletion)
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
        'time': time,
        'label': label,

        // snapshot
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
        time: (m['time'] as String?),
        label: (m['label'] as String?),

        // snapshot
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

  DayTotals addScaledFood(Food food, double grams) {
    final factor = grams / 100.0;
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

  DayTotals addScaledSnapshot({
    required double grams,
    required double calories100,
    required double protein100,
    required double carbs100,
    required double fat100,
  }) {
    final factor = grams / 100.0;
    return DayTotals(
      calories: calories + calories100 * factor,
      protein: protein + protein100 * factor,
      carbs: carbs + carbs100 * factor,
      fat: fat + fat100 * factor,
      // snapshot doesn't track these right now
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
    );
  }
}