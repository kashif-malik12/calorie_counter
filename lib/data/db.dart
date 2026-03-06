// lib/data/db.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite/utils/utils.dart';

import '../settings/target_settings.dart';
import 'models.dart';

class MacroTargets {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MacroTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class SystemTemplatePreviewItem {
  final String name;
  final double amount;
  final String unit;
  final double baseAmount;

  final double caloriesPerBase;
  final double proteinPerBase;
  final double carbsPerBase;
  final double fatPerBase;

  const SystemTemplatePreviewItem({
    required this.name,
    required this.amount,
    required this.unit,
    required this.baseAmount,
    required this.caloriesPerBase,
    required this.proteinPerBase,
    required this.carbsPerBase,
    required this.fatPerBase,
  });

  double get calories => caloriesPerBase * amount / (baseAmount <= 0 ? 1 : baseAmount);
  double get protein => proteinPerBase * amount / (baseAmount <= 0 ? 1 : baseAmount);
  double get carbs => carbsPerBase * amount / (baseAmount <= 0 ? 1 : baseAmount);
  double get fat => fatPerBase * amount / (baseAmount <= 0 ? 1 : baseAmount);
}

class SystemTemplatePreview {
  final MealTemplate template;
  final List<SystemTemplatePreviewItem> items;

  const SystemTemplatePreview({
    required this.template,
    required this.items,
  });

  DayTotals get totals {
    double c = 0, p = 0, cb = 0, f = 0;
    for (final it in items) {
      c += it.calories;
      p += it.protein;
      cb += it.carbs;
      f += it.fat;
    }
    return DayTotals(calories: c, protein: p, carbs: cb, fat: f);
  }
}

class TemplateWithTotals {
  final MealTemplate template;
  final DayTotals totals;

  const TemplateWithTotals({
    required this.template,
    required this.totals,
  });
}

class TemplateWithTotalsPreview {
  final MealTemplate template;
  final DayTotals totals;
  final String ingredientsPreview;
  final int itemCount;

  const TemplateWithTotalsPreview({
    required this.template,
    required this.totals,
    required this.ingredientsPreview,
    required this.itemCount,
  });
}

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const _dbFileName = 'calorie_counter_local.db';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final opening = _opening;
    if (opening != null) return opening;

    _opening = _open();
    final opened = await _opening!;
    _db = opened;
    _opening = null;
    return opened;
  }

  Future<String> _resolveDbPath() async {
    if (kIsWeb) return _dbFileName;

    final basePath = await databaseFactory.getDatabasesPath();
    if (basePath == null || basePath.isEmpty) return _dbFileName;
    return p.join(basePath, _dbFileName);
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table);');
    return info.any((r) => (r['name'] as String) == column);
  }

  Future<Database> _open() async {
    final path = await _resolveDbPath();

    final d = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 12,
        onConfigure: (db) async {
          if (!kIsWeb) {
            await db.execute('PRAGMA foreign_keys = ON;');
          }
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createSchema(db);

          if (!await _hasColumn(db, 'foods', 'unit')) {
            await db.execute("ALTER TABLE foods ADD COLUMN unit TEXT NOT NULL DEFAULT 'g';");
          }
          if (!await _hasColumn(db, 'foods', 'base_amount')) {
            await db.execute("ALTER TABLE foods ADD COLUMN base_amount REAL NOT NULL DEFAULT 100;");
          }
          if (!await _hasColumn(db, 'foods', 'is_system')) {
            await db.execute("ALTER TABLE foods ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0;");
          }
          if (!await _hasColumn(db, 'foods', 'category')) {
            await db.execute("ALTER TABLE foods ADD COLUMN category TEXT;");
          }
          if (!await _hasColumn(db, 'foods', 'system_key')) {
            await db.execute("ALTER TABLE foods ADD COLUMN system_key TEXT;");
          }

          if (!await _hasColumn(db, 'log_entries', 'time')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN time TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'label')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN label TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'unit')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN unit TEXT DEFAULT 'g';");
          }
          if (!await _hasColumn(db, 'log_entries', 'base_amount')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN base_amount REAL DEFAULT 100;");
          }
          if (!await _hasColumn(db, 'log_entries', 'food_name')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN food_name TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'calories_100')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN calories_100 REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'protein_100')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN protein_100 REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'carbs_100')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN carbs_100 REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'fat_100')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN fat_100 REAL;");
          }

          if (!await _hasColumn(db, 'log_entries', 'entry_type')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'food';");
          }
          if (!await _hasColumn(db, 'log_entries', 'manual_name')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN manual_name TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'manual_kcal')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN manual_kcal REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'manual_protein')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN manual_protein REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'manual_carbs')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN manual_carbs REAL;");
          }
          if (!await _hasColumn(db, 'log_entries', 'manual_fat')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN manual_fat REAL;");
          }

          if (!await _hasColumn(db, 'day_targets', 'source')) {
            await db.execute("ALTER TABLE day_targets ADD COLUMN source TEXT DEFAULT 'manual';");
          }
          if (!await _hasColumn(db, 'day_targets', 'calculator_json')) {
            await db.execute("ALTER TABLE day_targets ADD COLUMN calculator_json TEXT;");
          }

          if (!await _hasColumn(db, 'meal_templates', 'is_system')) {
            await db.execute("ALTER TABLE meal_templates ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0;");
          }
          if (!await _hasColumn(db, 'meal_templates', 'system_key')) {
            await db.execute("ALTER TABLE meal_templates ADD COLUMN system_key TEXT;");
          }
        },
      ),
    );

    await ensureSystemSeeded(d);

    return d;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,

        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,

        fiber REAL NOT NULL DEFAULT 0,
        sugar REAL NOT NULL DEFAULT 0,
        sodium REAL NOT NULL DEFAULT 0,

        unit TEXT NOT NULL DEFAULT 'g',
        base_amount REAL NOT NULL DEFAULT 100,

        is_system INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        system_key TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        food_id INTEGER,
        grams REAL NOT NULL,

        unit TEXT DEFAULT 'g',
        base_amount REAL DEFAULT 100,

        time TEXT,
        label TEXT,

        food_name TEXT,
        calories_100 REAL,
        protein_100 REAL,
        carbs_100 REAL,
        fat_100 REAL,

        entry_type TEXT NOT NULL DEFAULT 'food',
        manual_name TEXT,
        manual_kcal REAL,
        manual_protein REAL,
        manual_carbs REAL,
        manual_fat REAL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON log_entries(date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS day_targets (
        date TEXT PRIMARY KEY,
        calories_target INTEGER NOT NULL,
        protein_target INTEGER NOT NULL,
        carbs_target INTEGER NOT NULL,
        fat_target INTEGER NOT NULL,
        source TEXT DEFAULT 'manual',
        calculator_json TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        label TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0,
        system_key TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        food_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        base_amount REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_templates_label ON meal_templates(label);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_templates_system ON meal_templates(is_system, name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_items_template ON meal_template_items(template_id, sort_order);');
  }

  // ---------------- SYSTEM SEEDING ----------------

  Future<void> ensureSystemSeeded(Database db) async {
    final foodsCountRows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM foods WHERE is_system = 1;');
    final existingFoods = (foodsCountRows.first['c'] as num?)?.toInt() ?? 0;

    final templatesCountRows = await db
        .rawQuery('SELECT COUNT(*) AS c FROM meal_templates WHERE is_system = 1;');
    final existingTemplates =
        (templatesCountRows.first['c'] as num?)?.toInt() ?? 0;

    if (existingFoods > 0 && existingTemplates > 0) return;

    String norm(String s) =>
        s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

    if (existingFoods == 0) {
      final rawFoods = await rootBundle.loadString('assets/system_foods.json');
      final list = (jsonDecode(rawFoods) as List).cast<Map<String, dynamic>>();

      final batch = db.batch();
      for (final m in list) {
        batch.insert('foods', {
          'name': (m['name'] ?? '').toString(),
          'calories': (m['calories'] as num?)?.toDouble() ?? 0,
          'protein': (m['protein'] as num?)?.toDouble() ?? 0,
          'carbs': (m['carbs'] as num?)?.toDouble() ?? 0,
          'fat': (m['fat'] as num?)?.toDouble() ?? 0,
          'fiber': (m['fiber'] as num?)?.toDouble() ?? 0,
          'sugar': (m['sugar'] as num?)?.toDouble() ?? 0,
          'sodium': (m['sodium'] as num?)?.toDouble() ?? 0,
          'unit': (m['unit'] ?? 'g').toString(),
          'base_amount': (m['baseAmount'] as num?)?.toDouble() ?? 100,
          'is_system': 1,
          'category': m['category']?.toString(),
          'system_key': m['system_key']?.toString(),
        });
      }
      await batch.commit(noResult: true);
    }

    if (existingTemplates == 0) {
      final rawT = await rootBundle.loadString('assets/system_templates.json');
      final list = (jsonDecode(rawT) as List).cast<Map<String, dynamic>>();

      final foodRows = await db.rawQuery(
        'SELECT id, name, system_key FROM foods WHERE is_system = 1;',
      );

      final Map<String, int> foodIdByName = {
        for (final r in foodRows)
          norm((r['name'] as String?) ?? ''): (r['id'] as int),
      };
      final Map<String, int> foodIdBySystemKey = {
        for (final r in foodRows)
          if ((r['system_key'] as String?)?.trim().isNotEmpty == true)
            (r['system_key'] as String).trim(): (r['id'] as int),
      };

      await db.transaction((txn) async {
        for (final t in list) {
          final templateName = (t['name'] ?? '').toString().trim();
          final label =
              (t['default_label'] ?? t['label'] ?? 'Custom').toString().trim();
          final systemKey = t['system_key']?.toString().trim();
          final createdAt = DateTime.now().toIso8601String();

          if (templateName.isEmpty) continue;

          final templateId = await txn.insert('meal_templates', {
            'name': templateName,
            'label': label.isEmpty ? 'Custom' : label,
            'created_at': createdAt,
            'is_system': 1,
            'system_key': systemKey,
          });

          final rawItems = (t['items'] as List? ?? const []);
          var sort = 0;

          for (final rawItem in rawItems) {
            final it = Map<String, dynamic>.from(rawItem as Map);

            final rawFoodName = (
              it['food'] ??
              it['name'] ??
              it['foodName'] ??
              it['item'] ??
              it['food_name'] ??
              ''
            ).toString().trim();

            final foodSystemKey = it['food_system_key']?.toString().trim();

            int? foodId;
            if (foodSystemKey != null && foodSystemKey.isNotEmpty) {
              foodId = foodIdBySystemKey[foodSystemKey];
            }
            if (foodId == null && rawFoodName.isNotEmpty) {
              foodId = foodIdByName[norm(rawFoodName)];
            }
            if (foodId == null) {
              continue;
            }

            final amount = (it['amount'] as num?)?.toDouble() ?? 1;
            final unit = (it['unit'] ?? 'g').toString().trim();
            final baseAmount = (it['baseAmount'] as num?)?.toDouble() ??
                ((unit == 'g' || unit == 'ml') ? 100 : 1);

            await txn.insert('meal_template_items', {
              'template_id': templateId,
              'food_id': foodId,
              'amount': amount,
              'unit': unit.isEmpty ? 'g' : unit,
              'base_amount': baseAmount <= 0 ? 1 : baseAmount,
              'sort_order': sort++,
            });
          }
        }
      });
    }
  }

  // ---------------- FOODS: USER vs SYSTEM ----------------

  Future<List<Food>> getUserFoods({String? query}) async {
    final d = await db;
    final q = query?.trim();
    final rows = await d.query(
      'foods',
      where: (q == null || q.isEmpty) ? 'is_system = 0' : 'is_system = 0 AND name LIKE ?',
      whereArgs: (q == null || q.isEmpty) ? null : ['%$q%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> getSystemFoods({String? query}) async {
    final d = await db;
    final q = query?.trim();
    final rows = await d.query(
      'foods',
      where: (q == null || q.isEmpty) ? 'is_system = 1' : 'is_system = 1 AND name LIKE ?',
      whereArgs: (q == null || q.isEmpty) ? null : ['%$q%'],
      orderBy: 'category COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<Food?> getFoodById(int id) async {
    final d = await db;
    final rows = await d.query('foods', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Food.fromMap(rows.first);
  }

  Future<int> insertFood(Food food) async {
    final d = await db;
    return d.insert('foods', food.toMap());
  }

  Future<int> updateFood(Food food) async {
    final d = await db;
    return d.update('foods', food.toMap(), where: 'id = ?', whereArgs: [food.id]);
  }

  Future<int> deleteFood(int id) async {
    final d = await db;
    return d.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> importSystemFoodToUser(int systemFoodId) async {
    final d = await db;

    final sys = await d.query('foods', where: 'id = ? AND is_system = 1', whereArgs: [systemFoodId], limit: 1);
    if (sys.isEmpty) throw Exception('System food not found');

    final name = (sys.first['name'] as String);

    final existingUser = await d.query(
      'foods',
      where: 'is_system = 0 AND name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (existingUser.isNotEmpty) return (existingUser.first['id'] as int);

    final newId = await d.insert('foods', {
      'name': name,
      'calories': sys.first['calories'],
      'protein': sys.first['protein'],
      'carbs': sys.first['carbs'],
      'fat': sys.first['fat'],
      'fiber': sys.first['fiber'],
      'sugar': sys.first['sugar'],
      'sodium': sys.first['sodium'],
      'unit': sys.first['unit'],
      'base_amount': sys.first['base_amount'],
      'is_system': 0,
      'category': sys.first['category'],
      'system_key': null,
    });

    return newId;
  }

  // ---------------- LOG ENTRIES ----------------

  Future<int> insertLog(LogEntry entry) async {
    final d = await db;

    if (entry.entryType == 'manual') {
      final e = LogEntry(
        id: entry.id,
        date: entry.date,
        foodId: null,
        grams: entry.grams <= 0 ? 1 : entry.grams,
        unit: entry.unit.trim().isEmpty ? 'g' : entry.unit.trim(),
        baseAmount: entry.baseAmount <= 0 ? 1 : entry.baseAmount,
        time: entry.time,
        label: entry.label,
        entryType: 'manual',
        manualName: entry.manualName?.trim().isEmpty == true ? 'Manual item' : entry.manualName?.trim(),
        manualKcal: entry.manualKcal ?? 0,
        manualProtein: entry.manualProtein ?? 0,
        manualCarbs: entry.manualCarbs ?? 0,
        manualFat: entry.manualFat ?? 0,
      );
      return d.insert('log_entries', e.toMap());
    }

    final hasSnap = entry.foodName != null &&
        entry.calories100 != null &&
        entry.protein100 != null &&
        entry.carbs100 != null &&
        entry.fat100 != null;

    if (hasSnap) {
      return d.insert('log_entries', entry.toMap());
    }

    if (entry.foodId != null) {
      final f = await getFoodById(entry.foodId!);
      if (f != null) {
        final withSnap = LogEntry(
          id: entry.id,
          date: entry.date,
          foodId: entry.foodId,
          grams: entry.grams,
          unit: f.unit,
          baseAmount: f.baseAmount,
          time: entry.time,
          label: entry.label,
          foodName: f.name,
          calories100: f.calories,
          protein100: f.protein,
          carbs100: f.carbs,
          fat100: f.fat,
          entryType: 'food',
        );
        return d.insert('log_entries', withSnap.toMap());
      }
    }

    return d.insert('log_entries', entry.toMap());
  }

  Future<int> insertManualLog({
    required String date,
    required String name,
    required double calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    String? time,
    String? label,
  }) async {
    final entry = LogEntry(
      date: date,
      foodId: null,
      grams: 1,
      unit: 'g',
      baseAmount: 1,
      time: time,
      label: label,
      entryType: 'manual',
      manualName: name,
      manualKcal: calories,
      manualProtein: protein,
      manualCarbs: carbs,
      manualFat: fat,
    );
    return insertLog(entry);
  }

  Future<int> deleteLog(int id) async {
    final d = await db;
    return d.delete('log_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> getLogRowsForDate(String date) async {
    final d = await db;
    return d.rawQuery('''
      SELECT
        le.id as log_id,
        le.grams,
        COALESCE(le.unit, f.unit, 'g') as unit,
        COALESCE(le.base_amount, f.base_amount, 100) as base_amount,
        le.date,
        le.time,
        le.label,
        le.food_id as food_id,

        le.entry_type as entry_type,
        le.manual_name as manual_name,
        le.manual_kcal as manual_kcal,
        le.manual_protein as manual_protein,
        le.manual_carbs as manual_carbs,
        le.manual_fat as manual_fat,

        CASE
          WHEN le.entry_type = 'manual' THEN COALESCE(le.manual_name, 'Manual item')
          ELSE COALESCE(le.food_name, f.name)
        END as name,

        CASE
          WHEN le.entry_type = 'manual' THEN COALESCE(le.manual_kcal, 0)
          ELSE COALESCE(le.calories_100, f.calories)
        END as calories,

        CASE
          WHEN le.entry_type = 'manual' THEN COALESCE(le.manual_protein, 0)
          ELSE COALESCE(le.protein_100, f.protein)
        END as protein,

        CASE
          WHEN le.entry_type = 'manual' THEN COALESCE(le.manual_carbs, 0)
          ELSE COALESCE(le.carbs_100, f.carbs)
        END as carbs,

        CASE
          WHEN le.entry_type = 'manual' THEN COALESCE(le.manual_fat, 0)
          ELSE COALESCE(le.fat_100, f.fat)
        END as fat,

        COALESCE(f.fiber, 0) as fiber,
        COALESCE(f.sugar, 0) as sugar,
        COALESCE(f.sodium, 0) as sodium

      FROM log_entries le
      LEFT JOIN foods f ON f.id = le.food_id
      WHERE le.date = ?
      ORDER BY
        CASE WHEN le.time IS NULL OR le.time = '' THEN 1 ELSE 0 END,
        le.time ASC,
        le.id ASC
    ''', [date]);
  }

  Future<DayTotals> getTotalsForDate(String date) async {
    final rows = await getLogRowsForDate(date);
    var totals = const DayTotals();

    for (final r in rows) {
      final entryType = (r['entry_type'] as String?) ?? 'food';

      if (entryType == 'manual') {
        totals = totals.addManual(
          caloriesAdd: ((r['calories'] as num?) ?? 0).toDouble(),
          proteinAdd: ((r['protein'] as num?) ?? 0).toDouble(),
          carbsAdd: ((r['carbs'] as num?) ?? 0).toDouble(),
          fatAdd: ((r['fat'] as num?) ?? 0).toDouble(),
        );
        continue;
      }

      final amount = (r['grams'] as num).toDouble();
      final baseAmount = ((r['base_amount'] as num?) ?? 100).toDouble();

      final food = Food(
        id: r['food_id'] as int?,
        name: (r['name'] as String?) ?? 'Unknown',
        calories: ((r['calories'] as num?) ?? 0).toDouble(),
        protein: ((r['protein'] as num?) ?? 0).toDouble(),
        carbs: ((r['carbs'] as num?) ?? 0).toDouble(),
        fat: ((r['fat'] as num?) ?? 0).toDouble(),
        fiber: ((r['fiber'] as num?) ?? 0).toDouble(),
        sugar: ((r['sugar'] as num?) ?? 0).toDouble(),
        sodium: ((r['sodium'] as num?) ?? 0).toDouble(),
        unit: (r['unit'] as String?) ?? 'g',
        baseAmount: baseAmount,
        isSystem: false,
        category: null,
      );

      totals = totals.addScaledFood(food, amount);
    }

    return totals;
  }

  // ---------------- TARGETS ----------------

  Future<MacroTargets> getTargetsForDate(String date) async {
    final d = await db;
    final rows = await d.query('day_targets', where: 'date = ?', whereArgs: [date], limit: 1);

    if (rows.isNotEmpty) {
      final r = rows.first;
      return MacroTargets(
        calories: (r['calories_target'] as num).toInt(),
        protein: (r['protein_target'] as num).toInt(),
        carbs: (r['carbs_target'] as num).toInt(),
        fat: (r['fat_target'] as num).toInt(),
      );
    }

    return MacroTargets(
      calories: await TargetSettings.getCalories(),
      protein: await TargetSettings.getProtein(),
      carbs: await TargetSettings.getCarbs(),
      fat: await TargetSettings.getFat(),
    );
  }

  Future<void> setTargetsForDate(
    String date,
    MacroTargets t, {
    String source = 'manual',
    String? calculatorJson,
  }) async {
    final d = await db;
    await d.insert(
      'day_targets',
      {
        'date': date,
        'calories_target': t.calories,
        'protein_target': t.protein,
        'carbs_target': t.carbs,
        'fat_target': t.fat,
        'source': source,
        'calculator_json': calculatorJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearTargetsForDate(String date) async {
    final d = await db;
    await d.delete('day_targets', where: 'date = ?', whereArgs: [date]);
  }

  // ---------------- TEMPLATES (USER + SYSTEM) ----------------

  Future<int> createMealTemplate({
    required String name,
    required String label,
    String? createdAt,
  }) async {
    final d = await db;
    return d.insert('meal_templates', {
      'name': name.trim(),
      'label': label.trim(),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'is_system': 0,
      'system_key': null,
    });
  }

  Future<void> deleteMealTemplate(int templateId) async {
    final d = await db;
    await d.delete('meal_template_items', where: 'template_id = ?', whereArgs: [templateId]);
    await d.delete('meal_templates', where: 'id = ?', whereArgs: [templateId]);
  }

  Future<List<MealTemplate>> getUserMealTemplates({String? label}) async {
    final d = await db;
    final l = label?.trim();
    final rows = await d.query(
      'meal_templates',
      where: (l == null || l.isEmpty) ? 'is_system = 0' : 'is_system = 0 AND label = ?',
      whereArgs: (l == null || l.isEmpty) ? null : [l],
      orderBy: 'label COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(MealTemplate.fromMap).toList();
  }

  Future<List<MealTemplate>> getSystemMealTemplates({String? query}) async {
    final d = await db;
    final q = query?.trim();
    final rows = await d.query(
      'meal_templates',
      where: (q == null || q.isEmpty) ? 'is_system = 1' : 'is_system = 1 AND name LIKE ?',
      whereArgs: (q == null || q.isEmpty) ? null : ['%$q%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(MealTemplate.fromMap).toList();
  }

  Future<List<TemplateWithTotals>> getUserMealTemplatesWithTotals({String? label}) async {
  final d = await db;
  final l = label?.trim();

  final rows = await d.rawQuery('''
    SELECT
      t.id,
      t.name,
      t.label,
      t.created_at,
      t.is_system,
      t.system_key,

      COALESCE(SUM(COALESCE(f.calories, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_calories,
      COALESCE(SUM(COALESCE(f.protein, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_protein,
      COALESCE(SUM(COALESCE(f.carbs, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_carbs,
      COALESCE(SUM(COALESCE(f.fat, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_fat,
      COALESCE(SUM(COALESCE(f.fiber, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_fiber,
      COALESCE(SUM(COALESCE(f.sugar, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_sugar,
      COALESCE(SUM(COALESCE(f.sodium, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_sodium
    FROM meal_templates t
    LEFT JOIN meal_template_items i ON i.template_id = t.id
    LEFT JOIN foods f ON f.id = i.food_id
    WHERE t.is_system = 0
      ${l == null || l.isEmpty ? '' : 'AND t.label = ?'}
    GROUP BY t.id, t.name, t.label, t.created_at, t.is_system, t.system_key
    ORDER BY t.label COLLATE NOCASE ASC, t.name COLLATE NOCASE ASC
  ''', l == null || l.isEmpty ? [] : [l]);

  return rows.map((r) {
    final template = MealTemplate.fromMap({
      'id': r['id'],
      'name': r['name'],
      'label': r['label'],
      'created_at': r['created_at'],
      'is_system': r['is_system'],
      'system_key': r['system_key'],
    });

    final totals = DayTotals(
      calories: ((r['total_calories'] as num?) ?? 0).toDouble(),
      protein: ((r['total_protein'] as num?) ?? 0).toDouble(),
      carbs: ((r['total_carbs'] as num?) ?? 0).toDouble(),
      fat: ((r['total_fat'] as num?) ?? 0).toDouble(),
      fiber: ((r['total_fiber'] as num?) ?? 0).toDouble(),
      sugar: ((r['total_sugar'] as num?) ?? 0).toDouble(),
      sodium: ((r['total_sodium'] as num?) ?? 0).toDouble(),
    );

    return TemplateWithTotals(template: template, totals: totals);
  }).toList();
}

  Future<List<TemplateWithTotals>> getSystemMealTemplatesWithTotals({String? query}) async {
  final d = await db;
  final q = query?.trim();

  final rows = await d.rawQuery('''
    SELECT
      t.id,
      t.name,
      t.label,
      t.created_at,
      t.is_system,
      t.system_key,

      COALESCE(SUM(COALESCE(f.calories, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_calories,
      COALESCE(SUM(COALESCE(f.protein, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_protein,
      COALESCE(SUM(COALESCE(f.carbs, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_carbs,
      COALESCE(SUM(COALESCE(f.fat, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_fat,
      COALESCE(SUM(COALESCE(f.fiber, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_fiber,
      COALESCE(SUM(COALESCE(f.sugar, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_sugar,
      COALESCE(SUM(COALESCE(f.sodium, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_sodium
    FROM meal_templates t
    LEFT JOIN meal_template_items i ON i.template_id = t.id
    LEFT JOIN foods f ON f.id = i.food_id
    WHERE t.is_system = 1
      ${q == null || q.isEmpty ? '' : 'AND t.name LIKE ?'}
    GROUP BY t.id, t.name, t.label, t.created_at, t.is_system, t.system_key
    ORDER BY t.name COLLATE NOCASE ASC
  ''', q == null || q.isEmpty ? [] : ['%$q%']);

  return rows.map((r) {
    final template = MealTemplate.fromMap({
      'id': r['id'],
      'name': r['name'],
      'label': r['label'],
      'created_at': r['created_at'],
      'is_system': r['is_system'],
      'system_key': r['system_key'],
    });

    final totals = DayTotals(
      calories: ((r['total_calories'] as num?) ?? 0).toDouble(),
      protein: ((r['total_protein'] as num?) ?? 0).toDouble(),
      carbs: ((r['total_carbs'] as num?) ?? 0).toDouble(),
      fat: ((r['total_fat'] as num?) ?? 0).toDouble(),
      fiber: ((r['total_fiber'] as num?) ?? 0).toDouble(),
      sugar: ((r['total_sugar'] as num?) ?? 0).toDouble(),
      sodium: ((r['total_sodium'] as num?) ?? 0).toDouble(),
    );

    return TemplateWithTotals(template: template, totals: totals);
  }).toList();
}

  Future<int> addMealTemplateItem({
    required int templateId,
    required int foodId,
    required double amount,
    required String unit,
    required double baseAmount,
    int sortOrder = 0,
  }) async {
    final d = await db;
    return d.insert('meal_template_items', {
      'template_id': templateId,
      'food_id': foodId,
      'amount': amount,
      'unit': unit.trim().isEmpty ? 'g' : unit.trim(),
      'base_amount': baseAmount <= 0 ? 1 : baseAmount,
      'sort_order': sortOrder,
    });
  }

  Future<void> deleteMealTemplateItem(int itemId) async {
    final d = await db;
    await d.delete('meal_template_items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<List<MealTemplateItem>> getMealTemplateItems(int templateId) async {
    final d = await db;
    final rows = await d.query(
      'meal_template_items',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(MealTemplateItem.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> getMealTemplateItemsJoined(int templateId) async {
    final d = await db;
    return d.rawQuery('''
      SELECT
        i.id,
        i.template_id,
        i.food_id,
        i.amount,
        i.unit,
        i.base_amount,
        i.sort_order,
        f.name as food_name,
        f.calories,
        f.protein,
        f.carbs,
        f.fat,
        f.base_amount as food_base_amount,
        f.unit as food_unit
      FROM meal_template_items i
      LEFT JOIN foods f ON f.id = i.food_id
      WHERE i.template_id = ?
      ORDER BY i.sort_order ASC, i.id ASC
    ''', [templateId]);
  }

  Future<List<TemplateWithTotalsPreview>> getSystemMealTemplatesWithTotalsPreview({String? query}) async {
    final d = await db;
    final q = query?.trim();

    final rows = await d.rawQuery('''
      SELECT
        t.id,
        t.name,
        t.label,
        t.created_at,
        t.is_system,
        t.system_key,

        COALESCE(SUM(COALESCE(f.calories, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_calories,
        COALESCE(SUM(COALESCE(f.protein, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_protein,
        COALESCE(SUM(COALESCE(f.carbs, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_carbs,
        COALESCE(SUM(COALESCE(f.fat, 0) * i.amount / CASE WHEN i.base_amount <= 0 THEN 1 ELSE i.base_amount END), 0) as total_fat,
        COUNT(i.id) as item_count,
        COALESCE(GROUP_CONCAT(
          CASE
            WHEN i.id IN (
              SELECT ii.id
              FROM meal_template_items ii
              WHERE ii.template_id = t.id
              ORDER BY ii.sort_order ASC, ii.id ASC
              LIMIT 3
            )
            THEN
              printf('%s %s %s',
                CASE
                  WHEN CAST(i.amount AS INTEGER) = i.amount THEN CAST(i.amount AS INTEGER)
                  ELSE ROUND(i.amount, 1)
                END,
                COALESCE(NULLIF(i.unit, ''), COALESCE(f.unit, 'g')),
                COALESCE(f.name, 'Unknown')
              )
          END,
          ' • '
        ), 'No items') as ingredients_preview
      FROM meal_templates t
      LEFT JOIN meal_template_items i ON i.template_id = t.id
      LEFT JOIN foods f ON f.id = i.food_id
      WHERE t.is_system = 1
        ${q == null || q.isEmpty ? '' : 'AND t.name LIKE ?'}
      GROUP BY t.id, t.name, t.label, t.created_at, t.is_system, t.system_key
      ORDER BY t.name COLLATE NOCASE ASC
    ''', q == null || q.isEmpty ? [] : ['%$q%']);

    return rows.map((r) {
      final template = MealTemplate.fromMap({
        'id': r['id'],
        'name': r['name'],
        'label': r['label'],
        'created_at': r['created_at'],
        'is_system': r['is_system'],
        'system_key': r['system_key'],
      });

      final totals = DayTotals(
        calories: ((r['total_calories'] as num?) ?? 0).toDouble(),
        protein: ((r['total_protein'] as num?) ?? 0).toDouble(),
        carbs: ((r['total_carbs'] as num?) ?? 0).toDouble(),
        fat: ((r['total_fat'] as num?) ?? 0).toDouble(),
      );

      return TemplateWithTotalsPreview(
        template: template,
        totals: totals,
        ingredientsPreview: ((r['ingredients_preview'] as String?) ?? 'No items').trim(),
        itemCount: ((r['item_count'] as num?) ?? 0).toInt(),
      );
    }).toList();
  }

  Future<SystemTemplatePreview> getSystemTemplatePreview(int systemTemplateId) async {
    final d = await db;

    final tRows = await d.query(
      'meal_templates',
      where: 'id = ? AND is_system = 1',
      whereArgs: [systemTemplateId],
      limit: 1,
    );
    if (tRows.isEmpty) throw Exception('System template not found');

    final template = MealTemplate.fromMap(tRows.first);

    final iRows = await d.rawQuery('''
      SELECT
        i.id as id,
        i.template_id,
        i.food_id,
        i.amount,
        i.unit,
        i.base_amount,
        i.sort_order,
        f.name as food_name,
        f.calories as calories,
        f.protein as protein,
        f.carbs as carbs,
        f.fat as fat,
        f.base_amount as food_base_amount,
        f.unit as food_unit
      FROM meal_template_items i
      JOIN foods f ON f.id = i.food_id
      WHERE i.template_id = ?
      ORDER BY i.sort_order ASC, i.id ASC
    ''', [systemTemplateId]);

    final items = <SystemTemplatePreviewItem>[];
    for (final r in iRows) {
      final name = (r['food_name'] as String?) ?? 'Unknown';
      final amount = ((r['amount'] as num?) ?? 0).toDouble();

      final unit = (r['unit'] as String?) ?? ((r['food_unit'] as String?) ?? 'g');
      final baseAmount = ((r['base_amount'] as num?) ?? (r['food_base_amount'] as num?) ?? 100).toDouble();

      items.add(SystemTemplatePreviewItem(
        name: name,
        amount: amount,
        unit: unit,
        baseAmount: baseAmount,
        caloriesPerBase: ((r['calories'] as num?) ?? 0).toDouble(),
        proteinPerBase: ((r['protein'] as num?) ?? 0).toDouble(),
        carbsPerBase: ((r['carbs'] as num?) ?? 0).toDouble(),
        fatPerBase: ((r['fat'] as num?) ?? 0).toDouble(),
      ));
    }

    return SystemTemplatePreview(template: template, items: items);
  }

  Future<int> importSystemTemplateToUser({
    required int systemTemplateId,
    required String newLabel,
    String? newName,
  }) async {
    final d = await db;

    final tRows = await d.query(
      'meal_templates',
      where: 'id = ? AND is_system = 1',
      whereArgs: [systemTemplateId],
      limit: 1,
    );
    if (tRows.isEmpty) throw Exception('System template not found');
    final sysT = MealTemplate.fromMap(tRows.first);

    final userTemplateId = await d.insert('meal_templates', {
      'name': (newName?.trim().isNotEmpty == true) ? newName!.trim() : sysT.name,
      'label': newLabel.trim().isEmpty ? sysT.label : newLabel.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'is_system': 0,
      'system_key': null,
    });

    final items = await d.query(
      'meal_template_items',
      where: 'template_id = ?',
      whereArgs: [systemTemplateId],
      orderBy: 'sort_order ASC, id ASC',
    );

    var sort = 0;
    for (final r in items) {
      final systemFoodId = (r['food_id'] as num).toInt();
      final userFoodId = await importSystemFoodToUser(systemFoodId);

      await d.insert('meal_template_items', {
        'template_id': userTemplateId,
        'food_id': userFoodId,
        'amount': (r['amount'] as num).toDouble(),
        'unit': r['unit'],
        'base_amount': (r['base_amount'] as num).toDouble(),
        'sort_order': sort++,
      });
    }

    return userTemplateId;
  }

  Future<void> addTemplateToDate({
    required int templateId,
    required String date,
    String? time,
    String? labelOverride,
  }) async {
    final items = await getMealTemplateItems(templateId);
    for (final it in items) {
      await insertLog(LogEntry(
        date: date,
        foodId: it.foodId,
        grams: it.amount,
        time: time,
        label: labelOverride,
        entryType: 'food',
      ));
    }
  }
  Future<void> reseedSystemTemplates() async {
  final d = await db;

  await d.transaction((txn) async {
    await txn.delete(
      'meal_template_items',
      where: 'template_id IN (SELECT id FROM meal_templates WHERE is_system = 1)',
    );

    await txn.delete('meal_templates', where: 'is_system = 1');

    await txn.delete('foods', where: 'is_system = 1');
  });

  await ensureSystemSeeded(d);
}
Future<void> reseedSystemLibrary() async {
  final d = await db;

  await d.transaction((txn) async {
    // delete template items
    await txn.delete(
      'meal_template_items',
      where: 'template_id IN (SELECT id FROM meal_templates WHERE is_system = 1)',
    );

    // delete system templates
    await txn.delete(
      'meal_templates',
      where: 'is_system = 1',
    );

    // delete system foods
    await txn.delete(
      'foods',
      where: 'is_system = 1',
    );
  });

  // seed again
  await ensureSystemSeeded(d);
}
  // ---------------- RETENTION ----------------

  Future<int> purgeDataOlderThanDays(int days) async {
    final d = await db;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr =
        '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final deletedLogs = await d.delete('log_entries', where: 'date < ?', whereArgs: [cutoffStr]);
    await d.delete('day_targets', where: 'date < ?', whereArgs: [cutoffStr]);
    return deletedLogs;
  }

  // ---------------- RESET / CLOSE ----------------

  Future<void> resetDb() async {
    final d = _db;
    _db = null;
    _opening = null;
    await d?.close();

    if (kIsWeb) {
      final dbi = await db;
      await dbi.execute('DROP TABLE IF EXISTS log_entries;');
      await dbi.execute('DROP TABLE IF EXISTS foods;');
      await dbi.execute('DROP TABLE IF EXISTS day_targets;');
      await dbi.execute('DROP TABLE IF EXISTS meal_template_items;');
      await dbi.execute('DROP TABLE IF EXISTS meal_templates;');
      await _createSchema(dbi);
      await ensureSystemSeeded(dbi);
      return;
    }

    final path = await _resolveDbPath();
    await databaseFactory.deleteDatabase(path);
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    _opening = null;
    await d?.close();
  }
}