// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sqflite/sqflite.dart' as sqflite;              // ✅ Android/iOS factory
import 'package:sqflite_common/sqflite.dart' as common;       // ✅ global databaseFactory used by your db.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';         // ✅ desktop
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // ✅ web

import 'data/db.dart';
import 'data/models.dart';
import 'settings/target_settings.dart';

const bool kResetOnStartup = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    common.databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    common.databaseFactory = databaseFactoryFfi;
  } else {
    // ✅ Android/iOS: use sqflite plugin factory
    common.databaseFactory = sqflite.databaseFactory;
  }

  runApp(const CalorieCounterApp());
}

class CalorieCounterApp extends StatelessWidget {
  const CalorieCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calorie Counter (Local)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const InitGate(),
    );
  }
}

/// ✅ Runs startup work AFTER UI exists.
/// If something fails, you'll SEE the error instead of a blank screen.
class InitGate extends StatefulWidget {
  const InitGate({super.key});

  @override
  State<InitGate> createState() => _InitGateState();
}

class _InitGateState extends State<InitGate> {
  late final Future<void> _initFuture = _init();

  Future<void> _init() async {
    try {
      if (kResetOnStartup) {
        await AppDb.instance.resetDb();
        await TargetSettings.resetAllTargets();
      }

      await AppDb.instance.db;
    } catch (e, st) {
      throw Exception('$e\n\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          final err = snap.error;
          return Scaffold(
            appBar: AppBar(title: const Text('Startup Error')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                'App failed to start:\n\n$err\n\n'
                'Fix: open Chrome DevTools Console to see full stacktrace.\n'
                'Common causes:\n'
                '- shared_preferences not added to pubspec.yaml\n'
                '- missing flutter clean / rebuild\n'
                '- old cached web data (Clear site data)\n',
              ),
            ),
          );
        }

        return const HomeShell();
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayPage(),
      const FoodsPage(),
      const HistoryPage(),
    ];

    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Foods'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'History'),
        ],
      ),
    );
  }
}

// ---------------- Targets dialogs (single dialog) ----------------

Future<void> editDefaultTargetsOneDialog(BuildContext context) async {
  final c = await TargetSettings.getCalories();
  final p = await TargetSettings.getProtein();
  final cb = await TargetSettings.getCarbs();
  final f = await TargetSettings.getFat();

  final cCtrl = TextEditingController(text: c.toString());
  final pCtrl = TextEditingController(text: p.toString());
  final cbCtrl = TextEditingController(text: cb.toString());
  final fCtrl = TextEditingController(text: f.toString());

  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Default targets'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
            TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
            TextField(controller: cbCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
            TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );

  if (res != true) return;

  int parse(TextEditingController t) => int.tryParse(t.text.trim()) ?? 0;

  await TargetSettings.setCalories(parse(cCtrl));
  await TargetSettings.setProtein(parse(pCtrl));
  await TargetSettings.setCarbs(parse(cbCtrl));
  await TargetSettings.setFat(parse(fCtrl));

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default targets saved')),
    );
  }
}

Future<void> editTargetsForDateOneDialog(BuildContext context, String date) async {
  final cur = await AppDb.instance.getTargetsForDate(date);

  final cCtrl = TextEditingController(text: cur.calories.toString());
  final pCtrl = TextEditingController(text: cur.protein.toString());
  final cbCtrl = TextEditingController(text: cur.carbs.toString());
  final fCtrl = TextEditingController(text: cur.fat.toString());

  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Targets for $date'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
            TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
            TextField(controller: cbCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
            TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );

  if (res != true) return;

  int parse(TextEditingController t) => int.tryParse(t.text.trim()) ?? 0;

  await AppDb.instance.setTargetsForDate(
    date,
    MacroTargets(
      calories: parse(cCtrl),
      protein: parse(pCtrl),
      carbs: parse(cbCtrl),
      fat: parse(fCtrl),
    ),
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Targets saved for $date')),
    );
  }
}

// ---------------- Shared widgets ----------------

DataRow _macroRow(String name, double taken, int target, String unit) {
  final bal = target - taken;
  String fmt(double x) => x.toStringAsFixed(1);

  final takenStr = (name == 'Calories') ? taken.round().toString() : fmt(taken);
  final balStr = (name == 'Calories')
      ? (bal >= 0 ? '+${bal.round()}' : '-${(-bal).round()}')
      : (bal >= 0 ? '+${fmt(bal)}' : '-${fmt(-bal)}');

  return DataRow(
    cells: [
      DataCell(Text(name)),
      DataCell(Text(takenStr)),
      DataCell(Text('$target')),
      DataCell(Text(balStr)),
      DataCell(Text(unit)),
    ],
  );
}

Widget _progressBarCalories({required int taken, required int target}) {
  final safeTarget = target <= 0 ? 1 : target;
  final progress = (taken / safeTarget).clamp(0.0, 1.0);
  final over = taken - safeTarget;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Calories progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$taken / $safeTarget kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                over <= 0 ? '${safeTarget - taken} left' : '$over over',
                style: TextStyle(
                  color: over <= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 12),
          ),
        ],
      ),
    ),
  );
}

Widget _targetsTable({required DayTotals totals, required MacroTargets targets}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Taken vs Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Taken')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('Balance')),
                DataColumn(label: Text('Unit')),
              ],
              rows: [
                _macroRow('Calories', totals.calories, targets.calories, 'kcal'),
                _macroRow('Protein', totals.protein, targets.protein, 'g'),
                _macroRow('Carbs', totals.carbs, targets.carbs, 'g'),
                _macroRow('Fat', totals.fat, targets.fat, 'g'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------- TODAY ----------------

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_date) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: initial,
    );
    if (picked != null) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _addLogEntry() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Food? selected;
        final gramsCtrl = TextEditingController(text: '100');
        final searchCtrl = TextEditingController();

        // ✅ NEW fields
        String selectedLabel = 'Breakfast';
        TimeOfDay selectedTime = TimeOfDay.now();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setInner) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Add what you ate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(labelText: 'Search food', prefixIcon: Icon(Icons.search)),
                    onChanged: (_) => setInner(() {}),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Food>>(
                    future: AppDb.instance.getFoods(query: searchCtrl.text.trim()),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final list = snap.data ?? const <Food>[];
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No foods found. Add foods in the Foods tab first.'),
                        );
                      }
                      return SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final f = list[i];
                            final isSel = selected?.id == f.id;
                            return ListTile(
                              title: Text(f.name),
                              subtitle: Text('${f.calories.toStringAsFixed(0)} kcal /100g'),
                              trailing: isSel ? const Icon(Icons.check_circle) : null,
                              onTap: () => setInner(() => selected = f),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // ✅ NEW: label dropdown
                  DropdownButtonFormField<String>(
                    value: selectedLabel,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                      DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'Snack', child: Text('Snack')),
                    ],
                    onChanged: (v) => setInner(() => selectedLabel = v ?? 'Breakfast'),
                  ),

                  const SizedBox(height: 10),

                  // ✅ NEW: time picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Time: ${_fmtTime(selectedTime)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: const Text('Pick'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) setInner(() => selectedTime = picked);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  TextField(
                    controller: gramsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Grams eaten', suffixText: 'g'),
                  ),

                  const SizedBox(height: 12),

                  FilledButton(
                    onPressed: () async {
                      final f = selected;
                      if (f == null) return;

                      final grams = double.tryParse(gramsCtrl.text.trim().replaceAll(',', '.')) ?? 0;
                      if (grams <= 0) return;

                      await AppDb.instance.insertLog(
                        LogEntry(
                          date: _date,
                          foodId: f.id!,
                          grams: grams,
                          // ✅ save new fields
                          label: selectedLabel,
                          time: _fmtTime(selectedTime),
                        ),
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() {});
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _totRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today ($_date)'),
        actions: [
          IconButton(
            tooltip: 'Default targets',
            icon: const Icon(Icons.flag),
            onPressed: () async {
              await editDefaultTargetsOneDialog(context);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Targets for this date',
            icon: const Icon(Icons.edit_calendar),
            onPressed: () async {
              await editTargetsForDateOneDialog(context, _date);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Reset to defaults for this date',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await AppDb.instance.clearTargetsForDate(_date);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Using default targets for this date')),
              );
            },
          ),
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.date_range)),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addLogEntry, child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder(
                future: Future.wait([
                  AppDb.instance.getTotalsForDate(_date),
                  AppDb.instance.getTargetsForDate(_date),
                ]),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final data = snap.data as List<Object?>?;
                  final totals = (data?[0] as DayTotals?) ?? const DayTotals();
                  final targets = (data?[1] as MacroTargets?) ??
                      const MacroTargets(calories: 2000, protein: 150, carbs: 200, fat: 70);

                  return Column(
                    children: [
                      _progressBarCalories(taken: totals.calories.round(), target: targets.calories),
                      const SizedBox(height: 12),
                      _targetsTable(totals: totals, targets: targets),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Other totals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              _totRow('Fiber', '${totals.fiber.toStringAsFixed(1)} g'),
                              _totRow('Sugar', '${totals.sugar.toStringAsFixed(1)} g'),
                              _totRow('Sodium', '${totals.sodium.toStringAsFixed(0)} mg'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: AppDb.instance.getLogRowsForDate(_date),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snap.data ?? const [];
                  if (rows.isEmpty) return const Center(child: Text('No entries yet. Tap + to add what you ate.'));

                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final logId = r['log_id'] as int;
                      final grams = (r['grams'] as num).toDouble();
                      final name = r['name'] as String;
                      final kcal100 = (r['calories'] as num).toDouble();
                      final kcal = kcal100 * grams / 100.0;

                      // ✅ NEW: show time + label (if present)
                      final time = (r['time'] as String?)?.trim();
                      final label = (r['label'] as String?)?.trim();
                      final metaParts = <String>[
                        if (time != null && time.isNotEmpty) time,
                        if (label != null && label.isNotEmpty) label,
                      ];
                      final meta = metaParts.join(' • ');

                      final subtitle = meta.isEmpty
                          ? '${grams.toStringAsFixed(0)} g • ${kcal.toStringAsFixed(0)} kcal'
                          : '$meta • ${grams.toStringAsFixed(0)} g • ${kcal.toStringAsFixed(0)} kcal';

                      return Card(
                        child: ListTile(
                          title: Text(name),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await AppDb.instance.deleteLog(logId);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- FOODS ----------------

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  String _q = '';

  Future<void> _openFoodForm({Food? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final calsCtrl = TextEditingController(text: (existing?.calories ?? 0).toString());
    final protCtrl = TextEditingController(text: (existing?.protein ?? 0).toString());
    final carbCtrl = TextEditingController(text: (existing?.carbs ?? 0).toString());
    final fatCtrl = TextEditingController(text: (existing?.fat ?? 0).toString());
    final fiberCtrl = TextEditingController(text: (existing?.fiber ?? 0).toString());
    final sugarCtrl = TextEditingController(text: (existing?.sugar ?? 0).toString());
    final sodiumCtrl = TextEditingController(text: (existing?.sodium ?? 0).toString());

    double parseNum(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add food (per 100g)' : 'Edit food (per 100g)'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: calsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
              TextField(controller: protCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
              TextField(controller: carbCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
              TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)')),
              const SizedBox(height: 10),
              TextField(controller: fiberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fiber (g)')),
              TextField(controller: sugarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sugar (g)')),
              TextField(controller: sodiumCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sodium (mg)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                  return;
                }

                final food = Food(
                  id: existing?.id,
                  name: name,
                  calories: parseNum(calsCtrl),
                  protein: parseNum(protCtrl),
                  carbs: parseNum(carbCtrl),
                  fat: parseNum(fatCtrl),
                  fiber: parseNum(fiberCtrl),
                  sugar: parseNum(sugarCtrl),
                  sodium: parseNum(sodiumCtrl),
                );

                if (existing == null) {
                  await AppDb.instance.insertFood(food);
                } else {
                  await AppDb.instance.updateFood(food);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food saved')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foods (per 100g)')),
      floatingActionButton: FloatingActionButton(onPressed: () => _openFoodForm(), child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Search food', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Food>>(
                future: AppDb.instance.getFoods(query: _q),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final foods = snap.data ?? const <Food>[];
                  if (foods.isEmpty) return const Center(child: Text('No foods yet. Tap + to add.'));
                  return ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (_, i) {
                      final f = foods[i];
                      return Card(
                        child: ListTile(
                          title: Text(f.name),
                          subtitle: Text('${f.calories.toStringAsFixed(0)} kcal • P ${f.protein}g • C ${f.carbs}g • F ${f.fat}g (per 100g)'),
                          onTap: () => _openFoodForm(existing: f),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await AppDb.instance.deleteFood(f.id!);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- HISTORY ----------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_date) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: initial,
    );
    if (picked != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History ($_date)'),
        actions: [
          IconButton(
            tooltip: 'Default targets',
            icon: const Icon(Icons.flag),
            onPressed: () async {
              await editDefaultTargetsOneDialog(context);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Targets for this date',
            icon: const Icon(Icons.edit_calendar),
            onPressed: () async {
              await editTargetsForDateOneDialog(context, _date);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Reset to defaults for this date',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await AppDb.instance.clearTargetsForDate(_date);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Using default targets for this date')),
              );
            },
          ),
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.date_range)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: Future.wait([
            AppDb.instance.getTotalsForDate(_date),
            AppDb.instance.getTargetsForDate(_date),
          ]),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

            final data = snap.data as List<Object?>?;
            final totals = (data?[0] as DayTotals?) ?? const DayTotals();
            final targets = (data?[1] as MacroTargets?) ??
                const MacroTargets(calories: 2000, protein: 150, carbs: 200, fat: 70);

            return Column(
              children: [
                _progressBarCalories(taken: totals.calories.round(), target: targets.calories),
                const SizedBox(height: 12),
                _targetsTable(totals: totals, targets: targets),
              ],
            );
          },
        ),
      ),
    );
  }
}