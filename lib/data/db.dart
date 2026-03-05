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
        version: 9,
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

          await db.execute('''
            CREATE TABLE IF NOT EXISTS day_targets (
              date TEXT PRIMARY KEY,
              calories_target INTEGER NOT NULL,
              protein_target INTEGER NOT NULL,
              carbs_target INTEGER NOT NULL,
              fat_target INTEGER NOT NULL
            );
          ''');

          // ---------- log_entries columns ----------
          if (!await _hasColumn(db, 'log_entries', 'time')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN time TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'label')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN label TEXT;");
          }

          // ✅ Snapshot columns (so history survives food deletion)
          if (!await _hasColumn(db, 'log_entries', 'food_name')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN food_name TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'calories_100')) {
            // keep legacy name; meaning now "calories per base_amount"
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

          // ✅ unit + base_amount snapshot for logs
          if (!await _hasColumn(db, 'log_entries', 'unit')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN unit TEXT DEFAULT 'g';");
          }
          if (!await _hasColumn(db, 'log_entries', 'base_amount')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN base_amount REAL DEFAULT 100;");
          }

          await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');

          // ---------- foods columns ----------
          // ✅ foods.unit (g/ml/tbsp/piece/...)
          if (!await _hasColumn(db, 'foods', 'unit')) {
            await db.execute("ALTER TABLE foods ADD COLUMN unit TEXT NOT NULL DEFAULT 'g';");
          }

          // ✅ foods.base_amount (100 for g/ml, 1 for tbsp/piece/etc)
          if (!await _hasColumn(db, 'foods', 'base_amount')) {
            await db.execute("ALTER TABLE foods ADD COLUMN base_amount REAL NOT NULL DEFAULT 100;");
          }

          // ✅ Fill base_amount more realistically for existing foods:
          // - if unit is NOT g/ml => base_amount should be 1 (if it was left default 100)
          // This is safe and makes old foods usable if you later change unit.
          await db.execute('''
            UPDATE foods
            SET base_amount = 1
            WHERE unit NOT IN ('g','ml') AND (base_amount IS NULL OR base_amount = 100);
          ''');

          // ---------- v6 legacy rebuild (kept from your old code) ----------
          // IMPORTANT: old non-web schema used ON DELETE CASCADE + food_id NOT NULL.
          // We rebuild the table once (when upgrading to v6) so:
          // - food_id becomes nullable
          // - FK becomes ON DELETE SET NULL (no history deletion)
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

                FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE SET NULL
              );
            ''');

            await db.execute('''
              INSERT INTO log_entries_new (
                id, date, food_id, grams, unit, base_amount, time, label,
                food_name, calories_100, protein_100, carbs_100, fat_100
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
                COALESCE(le.fat_100, f.fat) AS fat_100
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
        fat_target INTEGER NOT NULL
      );
    ''');
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
        base_amount REAL NOT NULL DEFAULT 100
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
          fat_100 REAL
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

          // ✅ snapshot unit and base amount (IMPORTANT)
          unit: f.unit,
          baseAmount: f.baseAmount,

          time: entry.time,
          label: entry.label,
          foodName: f.name,

          // NOTE: names are legacy "calories_100" etc but meaning is "per base_amount"
          calories100: f.calories,
          protein100: f.protein,
          carbs100: f.carbs,
          fat100: f.fat,
        );

        return d.insert('log_entries', withSnap.toMap());
      }
    }

    // Custom item (foodId null) or missing food row
    return d.insert('log_entries', entry.toMap());
  }

  Future<int> deleteLog(int id) async {
    final d = await db;
    return d.delete('log_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Joined rows:
  /// - uses snapshot when food deleted
  Future<List<Map<String, Object?>>> getLogRowsForDate(String date) async {
    final d = await db;

    return d.rawQuery('''
      SELECT le.id as log_id,
             le.grams,
             COALESCE(le.unit, f.unit, 'g') as unit,
             COALESCE(le.base_amount, f.base_amount, 100) as base_amount,
             le.date,
             le.time,
             le.label,

             le.food_id as food_id,

             COALESCE(le.food_name, f.name) as name,

             -- per base_amount values
             COALESCE(le.calories_100, f.calories) as calories,
             COALESCE(le.protein_100, f.protein) as protein,
             COALESCE(le.carbs_100, f.carbs) as carbs,
             COALESCE(le.fat_100, f.fat) as fat,

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
      );

      // ✅ IMPORTANT: scale by amount/baseAmount (not /100 always)
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

  Future<void> setTargetsForDate(String date, MacroTargets t) async {
    final d = await db;
    await d.insert(
      'day_targets',
      {
        'date': date,
        'calories_target': t.calories,
        'protein_target': t.protein,
        'carbs_target': t.carbs,
        'fat_target': t.fat,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearTargetsForDate(String date) async {
    final d = await db;
    await d.delete('day_targets', where: 'date = ?', whereArgs: [date]);
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