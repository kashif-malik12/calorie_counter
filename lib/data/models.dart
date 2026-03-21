// lib/data/models.dart

class Food {
  final int? id;
  final String name;

  // Nutrition values are stored per baseAmount of unit
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double fiber;
  final double sugar;
  final double sodium;

  final String unit;       // g, ml, tbsp, tsp, cup, liter, piece, slice
  final double baseAmount; // 100 for g/ml, 1 for others

  final bool isSystem;
  final String? category;

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
    this.isSystem = false,
    this.category,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'unit': unit,
      'base_amount': baseAmount,
      'is_system': isSystem ? 1 : 0,
      'category': category,
    };
  }

  static Food fromMap(Map<String, Object?> m) {
    return Food(
      id: (m['id'] as num?)?.toInt(),
      name: (m['name'] as String?) ?? '',
      calories: ((m['calories'] as num?) ?? 0).toDouble(),
      protein: ((m['protein'] as num?) ?? 0).toDouble(),
      carbs: ((m['carbs'] as num?) ?? 0).toDouble(),
      fat: ((m['fat'] as num?) ?? 0).toDouble(),
      fiber: ((m['fiber'] as num?) ?? 0).toDouble(),
      sugar: ((m['sugar'] as num?) ?? 0).toDouble(),
      sodium: ((m['sodium'] as num?) ?? 0).toDouble(),
      unit: (m['unit'] as String?) ?? 'g',
      baseAmount: ((m['base_amount'] as num?) ?? 100).toDouble(),
      isSystem: ((m['is_system'] as num?) ?? 0).toInt() == 1,
      category: m['category'] as String?,
    );
  }
}

class LogEntry {
  final int? id;
  final String date;

  // For food entries:
  final int? foodId;

  // Amount in chosen unit (for manual we still keep grams=1 just as placeholder)
  final double grams;

  // Snapshot of unit/baseAmount used at log time (important for history)
  final String unit;
  final double baseAmount;

  final String? time;  // "HH:mm"
  final String? label; // Breakfast/Lunch/...

  // Snapshot nutrition (per baseAmount) for food entries
  final String? foodName;
  final double? calories100;
  final double? protein100;
  final double? carbs100;
  final double? fat100;

  // Manual one-time entry support
  final String entryType; // 'food' or 'manual'
  final String? manualName;
  final double? manualKcal;
  final double? manualProtein;
  final double? manualCarbs;
  final double? manualFat;

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

    this.entryType = 'food',
    this.manualName,
    this.manualKcal,
    this.manualProtein,
    this.manualCarbs,
    this.manualFat,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'food_id': foodId,
      'grams': grams,
      'unit': unit,
      'base_amount': baseAmount,
      'time': time,
      'label': label,

      'food_name': foodName,
      'calories_100': calories100,
      'protein_100': protein100,
      'carbs_100': carbs100,
      'fat_100': fat100,

      'entry_type': entryType,
      'manual_name': manualName,
      'manual_kcal': manualKcal,
      'manual_protein': manualProtein,
      'manual_carbs': manualCarbs,
      'manual_fat': manualFat,
    };
  }

  static LogEntry fromMap(Map<String, Object?> m) {
    return LogEntry(
      id: (m['id'] as num?)?.toInt(),
      date: (m['date'] as String?) ?? '',
      foodId: (m['food_id'] as num?)?.toInt(),
      grams: ((m['grams'] as num?) ?? 0).toDouble(),
      unit: (m['unit'] as String?) ?? 'g',
      baseAmount: ((m['base_amount'] as num?) ?? 100).toDouble(),
      time: m['time'] as String?,
      label: m['label'] as String?,

      foodName: m['food_name'] as String?,
      calories100: (m['calories_100'] as num?)?.toDouble(),
      protein100: (m['protein_100'] as num?)?.toDouble(),
      carbs100: (m['carbs_100'] as num?)?.toDouble(),
      fat100: (m['fat_100'] as num?)?.toDouble(),

      entryType: (m['entry_type'] as String?) ?? 'food',
      manualName: m['manual_name'] as String?,
      manualKcal: (m['manual_kcal'] as num?)?.toDouble(),
      manualProtein: (m['manual_protein'] as num?)?.toDouble(),
      manualCarbs: (m['manual_carbs'] as num?)?.toDouble(),
      manualFat: (m['manual_fat'] as num?)?.toDouble(),
    );
  }
}

class MealTemplate {
  final int? id;
  final String name;
  final String label;
  final String createdAt;

  final bool isSystem;
  final String? systemKey;

  const MealTemplate({
    this.id,
    required this.name,
    required this.label,
    required this.createdAt,
    this.isSystem = false,
    this.systemKey,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'label': label,
      'created_at': createdAt,
      'is_system': isSystem ? 1 : 0,
      'system_key': systemKey,
    };
  }

  static MealTemplate fromMap(Map<String, Object?> m) {
    return MealTemplate(
      id: (m['id'] as num?)?.toInt(),
      name: (m['name'] as String?) ?? '',
      label: (m['label'] as String?) ?? '',
      createdAt: (m['created_at'] as String?) ?? '',
      isSystem: ((m['is_system'] as num?) ?? 0).toInt() == 1,
      systemKey: m['system_key'] as String?,
    );
  }
}

class MealTemplateItem {
  final int? id;
  final int templateId;
  final int foodId;
  final double amount;
  final String unit;
  final double baseAmount;
  final int sortOrder;

  const MealTemplateItem({
    this.id,
    required this.templateId,
    required this.foodId,
    required this.amount,
    required this.unit,
    required this.baseAmount,
    required this.sortOrder,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'template_id': templateId,
      'food_id': foodId,
      'amount': amount,
      'unit': unit,
      'base_amount': baseAmount,
      'sort_order': sortOrder,
    };
  }

  static MealTemplateItem fromMap(Map<String, Object?> m) {
    return MealTemplateItem(
      id: (m['id'] as num?)?.toInt(),
      templateId: (m['template_id'] as num).toInt(),
      foodId: (m['food_id'] as num).toInt(),
      amount: ((m['amount'] as num?) ?? 0).toDouble(),
      unit: (m['unit'] as String?) ?? 'g',
      baseAmount: ((m['base_amount'] as num?) ?? 100).toDouble(),
      sortOrder: ((m['sort_order'] as num?) ?? 0).toInt(),
    );
  }
}

class FoodServing {
  final int? id;
  final int foodId;
  final String name;   // e.g. "1 tbsp", "1 egg", "½ cup"
  final double grams;  // equivalent amount in food's base unit

  const FoodServing({
    this.id,
    required this.foodId,
    required this.name,
    required this.grams,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'food_id': foodId,
    'name': name,
    'grams': grams,
  };

  static FoodServing fromMap(Map<String, Object?> m) => FoodServing(
    id: (m['id'] as num?)?.toInt(),
    foodId: (m['food_id'] as num).toInt(),
    name: m['name'] as String,
    grams: ((m['grams'] as num?) ?? 0).toDouble(),
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

  DayTotals addScaledFood(Food f, double amount) {
    final base = f.baseAmount <= 0 ? 1.0 : f.baseAmount;
    final factor = amount / base;

    return DayTotals(
      calories: calories + (f.calories * factor),
      protein: protein + (f.protein * factor),
      carbs: carbs + (f.carbs * factor),
      fat: fat + (f.fat * factor),
      fiber: fiber + (f.fiber * factor),
      sugar: sugar + (f.sugar * factor),
      sodium: sodium + (f.sodium * factor),
    );
  }

  DayTotals addManual({
    required double caloriesAdd,
    required double proteinAdd,
    required double carbsAdd,
    required double fatAdd,
  }) {
    return DayTotals(
      calories: calories + caloriesAdd,
      protein: protein + proteinAdd,
      carbs: carbs + carbsAdd,
      fat: fat + fatAdd,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
    );
  }
}