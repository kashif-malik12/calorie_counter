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
        // ✅ bump version so migration runs for existing installs
        version: 5,
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

          // ✅ NEW: add time + label columns for log_entries (safe)
          if (!await _hasColumn(db, 'log_entries', 'time')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN time TEXT;");
          }
          if (!await _hasColumn(db, 'log_entries', 'label')) {
            await db.execute("ALTER TABLE log_entries ADD COLUMN label TEXT;");
          }

          await db.execute('CREATE INDEX IF NOT EXISTS idx_log_date_time ON log_entries(date, time);');
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
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL DEFAULT 0,
        sugar REAL NOT NULL DEFAULT 0,
        sodium REAL NOT NULL DEFAULT 0
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
          food_id INTEGER NOT NULL,
          grams REAL NOT NULL,
          time TEXT,
          label TEXT
        );
      ''');
      return;
    }

    // ✅ Non-web: FK + cascade
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        food_id INTEGER NOT NULL,
        grams REAL NOT NULL,
        time TEXT,
        label TEXT,
        FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
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

    // ✅ Web: emulate ON DELETE CASCADE
    if (kIsWeb) {
      await d.delete('log_entries', where: 'food_id = ?', whereArgs: [id]);
    }

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
    return d.insert('log_entries', entry.toMap());
  }

  Future<int> deleteLog(int id) async {
    final d = await db;
    return d.delete('log_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns rows joined with food data, plus:
  /// - le.time (HH:mm)
  /// - le.label (Breakfast/Lunch/Dinner/Snack)
  Future<List<Map<String, Object?>>> getLogRowsForDate(String date) async {
    final d = await db;

    return d.rawQuery('''
      SELECT le.id as log_id,
             le.grams,
             le.date,
             le.time,
             le.label,
             f.id as food_id,
             f.name,
             f.calories,
             f.protein,
             f.carbs,
             f.fat,
             f.fiber,
             f.sugar,
             f.sodium
      FROM log_entries le
      JOIN foods f ON f.id = le.food_id
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
      final food = Food(
        id: r['food_id'] as int,
        name: r['name'] as String,
        calories: (r['calories'] as num).toDouble(),
        protein: (r['protein'] as num).toDouble(),
        carbs: (r['carbs'] as num).toDouble(),
        fat: (r['fat'] as num).toDouble(),
        fiber: (r['fiber'] as num).toDouble(),
        sugar: (r['sugar'] as num).toDouble(),
        sodium: (r['sodium'] as num).toDouble(),
      );

      final grams = (r['grams'] as num).toDouble();
      totals = totals.addScaledFood(food, grams);
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

  // ---------------- RESET / CLOSE ----------------

  Future<void> resetDb() async {
    final d = _db;
    _db = null;
    _opening = null;
    await d?.close();

    // ✅ Web: deleteDatabase can be flaky depending on backend; rebuild schema
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