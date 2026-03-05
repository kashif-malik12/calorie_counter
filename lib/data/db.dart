// lib/data/db.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/sqflite.dart';

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
    // ✅ Web: IndexedDB, use a simple name
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

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        // ✅ bump version so migrations run
        version: 10,
        onConfigure: (db) async {
          if (!kIsWeb) {
            await db.execute('PRAGMA foreign_keys = ON;');
          }
        },
        onCreate: (db, version) async => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          // Ensure base tables exist
          await _createFoodsTable(db);
          await _createLogEntriesTable(db);

          await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON log_entries(date);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');

          // Ensure targets table exists (old versions)
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

          // ---------- log_entries columns ----------
          if (!await _hasColumn(db, 'log_entries', 'time')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN time TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'label')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN label TEXT;");
          }

          // snapshot columns
          if (!await _hasColumn(db, 'log_entries', 'food_name')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN food_name TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'calories_100')) {
            // legacy name; meaning "per base_amount"
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

          // unit + base_amount snapshot
          if (!await _hasColumn(db, 'log_entries', 'unit')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN unit TEXT DEFAULT 'g';");
          }
          if (!await _hasColumn(db, 'log_entries', 'base_amount')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN base_amount REAL DEFAULT 100;");
          }

          // ✅ manual one-time entries
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

          // ---------- day_targets metadata columns ----------
          if (!await _hasColumn(db, 'day_targets', 'source')) {
            await db.execute("ALTER TABLE day_targets ADD COLUMN source TEXT DEFAULT 'manual';");
          }
          if (!await _hasColumn(db, 'day_targets', 'calculator_json')) {
            await db.execute("ALTER TABLE day_targets ADD COLUMN calculator_json TEXT;");
          }

          // ---------- foods columns ----------
          if (!await _hasColumn(db, 'foods', 'unit')) {
            await db.execute("ALTER TABLE foods ADD COLUMN unit TEXT NOT NULL DEFAULT 'g';");
          }
          if (!await _hasColumn(db, 'foods', 'base_amount')) {
            await db.execute("ALTER TABLE foods ADD COLUMN base_amount REAL NOT NULL DEFAULT 100;");
          }

          // global foods seed support
          if (!await _hasColumn(db, 'foods', 'is_system')) {
            await db.execute("ALTER TABLE foods ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0;");
          }
          if (!await _hasColumn(db, 'foods', 'category')) {
            await db.execute("ALTER TABLE foods ADD COLUMN category TEXT;");
          }

          // Fill base_amount more realistically for existing foods:
          await db.execute('''
            UPDATE foods
            SET base_amount = 1
            WHERE unit NOT IN ('g','ml') AND (base_amount IS NULL OR base_amount = 100);
          ''');

          // ---------- meal templates tables ----------
          await db.execute('''
            CREATE TABLE IF NOT EXISTS meal_templates (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              label TEXT NOT NULL,
              created_at TEXT NOT NULL
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
          await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_items_template ON meal_template_items(template_id, sort_order);');

          // ---------- v6 legacy rebuild (kept from your old code) ----------
          if (!kIsWeb && oldVersion < 6) {
            await db.execute('PRAGMA foreign_keys = OFF;');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS log_entries_new (
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
                manual_fat REAL,

                FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE SET NULL
              );
            ''');

            await db.execute('''
              INSERT INTO log_entries_new (
                id, date, food_id, grams, unit, base_amount, time, label,
                food_name, calories_100, protein_100, carbs_100, fat_100,
                entry_type, manual_name, manual_kcal, manual_protein, manual_carbs, manual_fat
              )
              SELECT
                le.id, le.date, le.food_id, le.grams,
                COALESCE(le.unit, 'g') as unit,
                COALESCE(le.base_amount, 100) as base_amount,
                le.time, le.label,
                COALESCE(le.food_name, f.name) AS food_name,
                COALESCE(le.calories_100, f.calories) AS calories_100,
                COALESCE(le.protein_100, f.protein) AS protein_100,
                COALESCE(le.carbs_100, f.carbs) AS carbs_100,
                COALESCE(le.fat_100, f.fat) AS fat_100,
                COALESCE(le.entry_type, 'food') as entry_type,
                le.manual_name, le.manual_kcal, le.manual_protein, le.manual_carbs, le.manual_fat
              FROM log_entries le
              LEFT JOIN foods f ON f.id = le.food_id;
            ''');

            await db.execute('DROP TABLE log_entries;');
            await db.execute('ALTER TABLE log_entries_new RENAME TO log_entries;');

            await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON log_entries(date);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');

            await db.execute('PRAGMA foreign_keys = ON;');
          }
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await _createFoodsTable(db);
    await _createLogEntriesTable(db);

    await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON log_entries(date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');

    await db.execute('''
      CREATE TABLE day_targets (
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
      CREATE TABLE meal_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        label TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE meal_template_items (
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meal_items_template ON meal_template_items(template_id, sort_order);');
  }

  Future<void> _createFoodsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,

        -- values stored "per base_amount of unit"
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
        category TEXT
      );
    ''');
  }

  Future<void> _createLogEntriesTable(Database db) async {
    // ✅ Web-safe: no FK constraints
    if (kIsWeb) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS log_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          food_id INTEGER,

          -- amount in the chosen unit
          grams REAL NOT NULL,

          -- snapshot of unit and its base amount
          unit TEXT DEFAULT 'g',
          base_amount REAL DEFAULT 100,

          time TEXT,
          label TEXT,

          -- snapshot nutrition (per base_amount)
          food_name TEXT,
          calories_100 REAL,
          protein_100 REAL,
          carbs_100 REAL,
          fat_100 REAL,

          -- one-time manual item
          entry_type TEXT NOT NULL DEFAULT 'food',
          manual_name TEXT,
          manual_kcal REAL,
          manual_protein REAL,
          manual_carbs REAL,
          manual_fat REAL
        );
      ''');
      return;
    }

    // ✅ Non-web: FK with SET NULL (NOT CASCADE) + allow nullable food_id
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
        manual_fat REAL,

        FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE SET NULL
      );
    ''');
  }

  // ---------------- FOODS ----------------

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

  Future<List<Food>> getFoods({String? query}) async {
    final d = await db;
    final q = query?.trim();

    final rows = await d.query(
      'foods',
      where: (q == null || q.isEmpty) ? null : 'name LIKE ?',
      whereArgs: (q == null || q.isEmpty) ? null : ['%$q%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Food.fromMap).toList();
  }

  // ---------------- LOG ENTRIES ----------------

  Future<int> insertLog(LogEntry entry) async {
    final d = await db;

    // ✅ Manual one-time entry: store as-is (no food lookup)
    if (entry.entryType == 'manual') {
      // Ensure sane defaults
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
        // snapshots not needed
        foodName: null,
        calories100: null,
        protein100: null,
        carbs100: null,
        fat100: null,
      );

      return d.insert('log_entries', e.toMap());
    }

    // Food-based entry:
    final hasSnap = entry.foodName != null &&
        entry.calories100 != null &&
        entry.protein100 != null &&
        entry.carbs100 != null &&
        entry.fat100 != null;

    // If snapshot already provided, store it as-is.
    if (hasSnap) {
      return d.insert('log_entries', entry.toMap());
    }

    // If foodId exists, fetch food and store snapshot at insert time.
    if (entry.foodId != null) {
      final rows = await d.query(
        'foods',
        where: 'id = ?',
        whereArgs: [entry.foodId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final f = Food.fromMap(rows.first);

        final withSnap = LogEntry(
          id: entry.id,
          date: entry.date,
          foodId: entry.foodId,
          grams: entry.grams,

          // snapshot unit and base amount
          unit: f.unit,
          baseAmount: f.baseAmount,

          time: entry.time,
          label: entry.label,
          foodName: f.name,

          // legacy columns (per base_amount)
          calories100: f.calories,
          protein100: f.protein,
          carbs100: f.carbs,
          fat100: f.fat,

          entryType: 'food',
        );

        return d.insert('log_entries', withSnap.toMap());
      }
    }

    // Custom item (foodId null) or missing food row
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

  /// Joined rows:
  /// - uses snapshot when food deleted
  /// - supports manual one-time items
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

        f.fiber,
        f.sugar,
        f.sodium

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

        // per base amount values
        calories: ((r['calories'] as num?) ?? 0).toDouble(),
        protein: ((r['protein'] as num?) ?? 0).toDouble(),
        carbs: ((r['carbs'] as num?) ?? 0).toDouble(),
        fat: ((r['fat'] as num?) ?? 0).toDouble(),

        fiber: ((r['fiber'] as num?) ?? 0).toDouble(),
        sugar: ((r['sugar'] as num?) ?? 0).toDouble(),
        sodium: ((r['sodium'] as num?) ?? 0).toDouble(),

        unit: (r['unit'] as String?) ?? 'g',
        baseAmount: baseAmount,

        // these may be null in join; defaults are fine
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
    final rows = await d.query(
      'day_targets',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final r = rows.first;
      return MacroTargets(
        calories: (r['calories_target'] as num).toInt(),
        protein: (r['protein_target'] as num).toInt(),
        carbs: (r['carbs_target'] as num).toInt(),
        fat: (r['fat_target'] as num).toInt(),
      );
    }

    // fallback to global targets in shared prefs
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
    String source = 'manual', // 'manual' | 'calculator'
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

  // ---------------- MEAL TEMPLATES (basic helpers) ----------------

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
    });
  }

  Future<void> deleteMealTemplate(int templateId) async {
    final d = await db;
    await d.delete('meal_template_items', where: 'template_id = ?', whereArgs: [templateId]);
    await d.delete('meal_templates', where: 'id = ?', whereArgs: [templateId]);
  }

  Future<List<MealTemplate>> getMealTemplates({String? label}) async {
    final d = await db;
    final rows = await d.query(
      'meal_templates',
      where: (label == null || label.trim().isEmpty) ? null : 'label = ?',
      whereArgs: (label == null || label.trim().isEmpty) ? null : [label.trim()],
      orderBy: 'label COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(MealTemplate.fromMap).toList();
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
      'base_amount': baseAmount,
      'sort_order': sortOrder,
    });
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

  /// Adds all template items as log entries for the given date.
  /// Uses current food snapshot at insert time (same as normal insertLog()).
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

  // ---------------- RETENTION ----------------

  /// Deletes log_entries and day_targets older than N days.
  /// Dates are stored "yyyy-MM-dd", string comparison works safely.
  Future<int> purgeDataOlderThanDays(int days) async {
    final d = await db;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr =
        '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final deletedLogs = await d.delete(
      'log_entries',
      where: 'date < ?',
      whereArgs: [cutoffStr],
    );

    await d.delete(
      'day_targets',
      where: 'date < ?',
      whereArgs: [cutoffStr],
    );

    return deletedLogs;
  }

  // ---------------- RESET / CLOSE ----------------

  Future<void> resetDb() async {
    final d = _db;
    _db = null;
    _opening = null;
    await d?.close();

    // ✅ Web: deleteDatabase can be flaky; rebuild schema
    if (kIsWeb) {
      final dbi = await db;
      await dbi.execute('DROP TABLE IF EXISTS log_entries;');
      await dbi.execute('DROP TABLE IF EXISTS foods;');
      await dbi.execute('DROP TABLE IF EXISTS day_targets;');
      await dbi.execute('DROP TABLE IF EXISTS meal_template_items;');
      await dbi.execute('DROP TABLE IF EXISTS meal_templates;');
      await _createSchema(dbi);
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