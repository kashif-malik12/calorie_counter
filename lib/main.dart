// lib/main.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sqflite/sqflite.dart' as sqflite; // ✅ Android/iOS factory
import 'package:sqflite_common/sqflite.dart' as common; // ✅ global databaseFactory used by db.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // ✅ desktop
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // ✅ web

import 'data/db.dart';
import 'data/models.dart';
import 'settings/target_settings.dart';
import 'settings/retention_settings.dart';

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

      // Ensure DB open
      await AppDb.instance.db;

      // ✅ Auto cleanup based on retention setting
      final days = await RetentionSettings.getRetentionDays();
      await AppDb.instance.purgeDataOlderThanDays(days);
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

// ---------------- Retention dialog ----------------

Future<void> editRetentionDaysDialog(BuildContext context) async {
  final current = await RetentionSettings.getRetentionDays();
  final ctrl = TextEditingController(text: current.toString());

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Data retention'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How many days should the app keep your history?'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Days to keep',
              helperText: 'Min 7, max 3650',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );

  if (ok != true) return;

  final days = int.tryParse(ctrl.text.trim()) ?? current;
  await RetentionSettings.setRetentionDays(days);

  final deleted = await AppDb.instance.purgeDataOlderThanDays(days);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved. Deleted $deleted old entries.')),
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

String _baseLabel(Food f) {
  final u = f.unit;
  final b = f.baseAmount;
  return 'per ${b.toStringAsFixed(b == b.roundToDouble() ? 0 : 1)} $u';
}

// ---------------- GOAL CALCULATOR ----------------

class GoalCalculatorScreen extends StatefulWidget {
  final String date; // apply for this date
  const GoalCalculatorScreen({super.key, required this.date});

  @override
  State<GoalCalculatorScreen> createState() => _GoalCalculatorScreenState();
}

class _GoalCalculatorScreenState extends State<GoalCalculatorScreen> {
  String sex = 'male'; // male/female
  final ageCtrl = TextEditingController(text: '30');
  final heightCtrl = TextEditingController(text: '175');
  final weightCtrl = TextEditingController(text: '75');

  String activity = 'moderate'; // sedentary/light/moderate/very/athlete
  String goal = 'maintain'; // lose/maintain/gain
  String pace = 'medium'; // slow/medium/aggressive

  double _activityFactor(String a) {
    switch (a) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'very':
        return 1.725;
      case 'athlete':
        return 1.9;
      default:
        return 1.55;
    }
  }

  int _deltaForPace(String p, String g) {
    // kcal/day
    final base = switch (p) {
      'slow' => 250,
      'medium' => 500,
      'aggressive' => 750,
      _ => 500,
    };
    if (g == 'lose') return -base;
    if (g == 'gain') return base;
    return 0;
  }

  double _bmr({required String sex, required int age, required double cm, required double kg}) {
    // Mifflin–St Jeor
    final s = (sex == 'male') ? 5.0 : -161.0;
    return (10.0 * kg) + (6.25 * cm) - (5.0 * age) + s;
    // kcal/day
  }

  MacroTargets _macroTargetsFromCalories(int calories) {
    // Simple default split:
    // Protein: 25% kcal, Carbs: 45% kcal, Fat: 30% kcal
    // Protein/Carbs = 4 kcal/g, Fat = 9 kcal/g
    final p = (calories * 0.25 / 4).round();
    final c = (calories * 0.45 / 4).round();
    final f = (calories * 0.30 / 9).round();
    return MacroTargets(calories: calories, protein: p, carbs: c, fat: f);
  }

  @override
  Widget build(BuildContext context) {
    int parseInt(TextEditingController c, int fallback) => int.tryParse(c.text.trim()) ?? fallback;
    double parseDouble(TextEditingController c, double fallback) =>
        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

    final age = parseInt(ageCtrl, 30);
    final h = parseDouble(heightCtrl, 175);
    final w = parseDouble(weightCtrl, 75);

    final bmr = _bmr(sex: sex, age: age, cm: h, kg: w);
    final tdee = bmr * _activityFactor(activity);
    final delta = _deltaForPace(pace, goal);
    final targetCalories = (tdee + delta).round().clamp(800, 6000);

    final targets = _macroTargetsFromCalories(targetCalories);

    final calcJson = jsonEncode({
      'sex': sex,
      'age': age,
      'height_cm': h,
      'weight_kg': w,
      'activity': activity,
      'goal': goal,
      'pace': pace,
      'bmr': bmr,
      'tdee': tdee,
      'target_calories': targetCalories,
    });

    String fmt(double x) => x.toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Goal Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Enter your details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: sex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => sex = v ?? 'male'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (cm)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: activity,
              decoration: const InputDecoration(labelText: 'Activity level'),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'very', child: Text('Very active')),
                DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
              ],
              onChanged: (v) => setState(() => activity = v ?? 'moderate'),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: goal,
              decoration: const InputDecoration(labelText: 'Goal'),
              items: const [
                DropdownMenuItem(value: 'lose', child: Text('Lose weight')),
                DropdownMenuItem(value: 'maintain', child: Text('Maintain')),
                DropdownMenuItem(value: 'gain', child: Text('Gain weight')),
              ],
              onChanged: (v) => setState(() => goal = v ?? 'maintain'),
            ),
            const SizedBox(height: 10),

            if (goal != 'maintain')
              DropdownButtonFormField<String>(
                value: pace,
                decoration: const InputDecoration(labelText: 'Pace'),
                items: const [
                  DropdownMenuItem(value: 'slow', child: Text('Slow (±250 kcal/day)')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium (±500 kcal/day)')),
                  DropdownMenuItem(value: 'aggressive', child: Text('Aggressive (±750 kcal/day)')),
                ],
                onChanged: (v) => setState(() => pace = v ?? 'medium'),
              ),

            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text('BMR: ${fmt(bmr)} kcal/day'),
                    Text('TDEE: ${fmt(tdee)} kcal/day'),
                    const Divider(height: 24),
                    Text('Suggested calories: $targetCalories kcal/day',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Suggested macros: P ${targets.protein}g • C ${targets.carbs}g • F ${targets.fat}g'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Apply to ${widget.date}'),
              onPressed: () async {
                await AppDb.instance.setTargetsForDate(
                  widget.date,
                  targets,
                  source: 'calculator',
                  calculatorJson: calcJson,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Targets applied for ${widget.date}')),
                );
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }
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

  Future<void> _showAddMenu() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Add from foods'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addLogEntryFromFoods();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on),
              title: const Text('Quick entry (one-time)'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addQuickManualEntry();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('Add from templates'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addFromTemplates();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Goal calculator (auto targets)'),
              onTap: () async {
                Navigator.pop(ctx);
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => GoalCalculatorScreen(date: _date)),
                );
                if (changed == true && mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addLogEntryFromFoods() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        Food? selected;
        final amountCtrl = TextEditingController(text: '1');
        final searchCtrl = TextEditingController();

        String selectedLabel = 'Breakfast';
        TimeOfDay selectedTime = TimeOfDay.now();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setInner) {
                final unitSuffix = selected?.unit ?? 'g';

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add what you ate',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
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
                            height: 240,
                            child: ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final f = list[i];
                                final isSel = selected?.id == f.id;
                                final tag = f.isSystem ? ' • System' : '';
                                return ListTile(
                                  title: Text('${f.name}$tag'),
                                  subtitle: Text('${f.calories.toStringAsFixed(0)} kcal (${_baseLabel(f)})'),
                                  trailing: isSel ? const Icon(Icons.check_circle) : null,
                                  onTap: () => setInner(() => selected = f),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
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
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount eaten',
                          suffixText: unitSuffix,
                          helperText: selected == null ? null : 'Nutrition is ${_baseLabel(selected!)}',
                        ),
                      ),

                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          final f = selected;
                          if (f == null) return;

                          final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
                          if (amount <= 0) return;

                          await AppDb.instance.insertLog(
                            LogEntry(
                              date: _date,
                              foodId: f.id,
                              grams: amount,
                              unit: f.unit,
                              baseAmount: f.baseAmount,
                              label: selectedLabel,
                              time: _fmtTime(selectedTime),

                              // snapshot nutrition per baseAmount (legacy names)
                              foodName: f.name,
                              calories100: f.calories,
                              protein100: f.protein,
                              carbs100: f.carbs,
                              fat100: f.fat,

                              entryType: 'food',
                            ),
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) setState(() {});
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _addQuickManualEntry() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final kcalCtrl = TextEditingController();
        final pCtrl = TextEditingController(text: '0');
        final cCtrl = TextEditingController(text: '0');
        final fCtrl = TextEditingController(text: '0');

        String selectedLabel = 'Breakfast';
        TimeOfDay selectedTime = TimeOfDay.now();

        double d(TextEditingController t) => double.tryParse(t.text.trim().replaceAll(',', '.')) ?? 0;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setInner) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Quick entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name (e.g., Restaurant pasta)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedLabel,
                      decoration: const InputDecoration(labelText: 'Label', prefixIcon: Icon(Icons.sell_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                        DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                        DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                        DropdownMenuItem(value: 'Snack', child: Text('Snack')),
                      ],
                      onChanged: (v) => setInner(() => selectedLabel = v ?? 'Breakfast'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('Time: ${_fmtTime(selectedTime)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: const Text('Pick'),
                          onPressed: () async {
                            final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                            if (picked != null) setInner(() => selectedTime = picked);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: kcalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Protein (g)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: cCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Carbs (g)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: fCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Fat (g)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final kcal = d(kcalCtrl);
                        if (name.isEmpty || kcal <= 0) return;

                        await AppDb.instance.insertManualLog(
                          date: _date,
                          name: name,
                          calories: kcal,
                          protein: d(pCtrl),
                          carbs: d(cCtrl),
                          fat: d(fCtrl),
                          time: _fmtTime(selectedTime),
                          label: selectedLabel,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) setState(() {});
                      },
                      child: const Text('Add'),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addFromTemplates() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        TimeOfDay selectedTime = TimeOfDay.now();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setInner) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Add from templates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Time: ${_fmtTime(selectedTime)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: const Text('Pick'),
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                          if (picked != null) setInner(() => selectedTime = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  FutureBuilder<List<MealTemplate>>(
                    future: AppDb.instance.getMealTemplates(),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final templates = snap.data ?? const <MealTemplate>[];
                      if (templates.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('No templates yet. Create one in Templates screen.'),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Create template'),
                                onPressed: () async {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TemplatesPage()),
                                  );
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      return SizedBox(
                        height: 320,
                        child: ListView.builder(
                          itemCount: templates.length,
                          itemBuilder: (_, i) {
                            final t = templates[i];
                            return Card(
                              child: ListTile(
                                title: Text(t.name),
                                subtitle: Text('Label: ${t.label}'),
                                trailing: const Icon(Icons.add_circle_outline),
                                onTap: () async {
                                  await AppDb.instance.addTemplateToDate(
                                    templateId: t.id!,
                                    date: _date,
                                    time: _fmtTime(selectedTime),
                                    labelOverride: t.label,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Manage templates'),
                    onPressed: () async {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage()));
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
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
            tooltip: 'Data retention',
            icon: const Icon(Icons.storage),
            onPressed: () async {
              await editRetentionDaysDialog(context);
              if (mounted) setState(() {});
            },
          ),
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
            tooltip: 'Goal calculator',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => GoalCalculatorScreen(date: _date)),
              );
              if (changed == true && mounted) setState(() {});
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
      floatingActionButton: FloatingActionButton(onPressed: _showAddMenu, child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: Future.wait([
            AppDb.instance.getTotalsForDate(_date),
            AppDb.instance.getTargetsForDate(_date),
            AppDb.instance.getLogRowsForDate(_date),
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
            final rows = (data?[2] as List<Map<String, Object?>>?) ?? const [];

            return ListView(
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

                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No entries yet. Tap + to add what you ate.')),
                  )
                else
                  ...rows.map((r) {
                    final logId = r['log_id'] as int;

                    final entryType = (r['entry_type'] as String?) ?? 'food';
                    final name = (r['name'] as String?) ?? 'Unknown';

                    final time = (r['time'] as String?)?.trim();
                    final label = (r['label'] as String?)?.trim();
                    final metaParts = <String>[
                      if (time != null && time.isNotEmpty) time,
                      if (label != null && label.isNotEmpty) label,
                    ];
                    final meta = metaParts.join(' • ');

                    String subtitle;

                    if (entryType == 'manual') {
                      final kcal = ((r['calories'] as num?) ?? 0).toDouble();
                      subtitle = meta.isEmpty ? '${kcal.toStringAsFixed(0)} kcal' : '$meta • ${kcal.toStringAsFixed(0)} kcal';
                    } else {
                      final amount = (r['grams'] as num).toDouble();
                      final unit = (r['unit'] as String?)?.trim().isNotEmpty == true ? (r['unit'] as String) : 'g';
                      final baseAmount = ((r['base_amount'] as num?) ?? 100).toDouble();
                      final safeBase = baseAmount <= 0 ? 1.0 : baseAmount;

                      final kcalPerBase = ((r['calories'] as num?) ?? 0).toDouble();
                      final kcal = kcalPerBase * amount / safeBase;

                      final amountStr = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 1);

                      subtitle = meta.isEmpty
                          ? '$amountStr $unit • ${kcal.toStringAsFixed(0)} kcal'
                          : '$meta • $amountStr $unit • ${kcal.toStringAsFixed(0)} kcal';
                    }

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
                  }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- TEMPLATES ----------------

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  Future<void> _createTemplate() async {
    final nameCtrl = TextEditingController();
    String label = 'Breakfast';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: label,
              decoration: const InputDecoration(labelText: 'Label'),
              items: const [
                DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                DropdownMenuItem(value: 'Snack', child: Text('Snack')),
              ],
              onChanged: (v) => label = v ?? 'Breakfast',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final id = await AppDb.instance.createMealTemplate(name: name, label: label);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TemplateEditPage(templateId: id, templateName: name, templateLabel: label)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      floatingActionButton: FloatingActionButton(onPressed: _createTemplate, child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<MealTemplate>>(
          future: AppDb.instance.getMealTemplates(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final list = snap.data ?? const <MealTemplate>[];
            if (list.isEmpty) return const Center(child: Text('No templates yet. Tap + to create one.'));
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text('Label: ${t.label}'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplateEditPage(templateId: t.id!, templateName: t.name, templateLabel: t.label),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await AppDb.instance.deleteMealTemplate(t.id!);
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
    );
  }
}

class TemplateEditPage extends StatefulWidget {
  final int templateId;
  final String templateName;
  final String templateLabel;

  const TemplateEditPage({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.templateLabel,
  });

  @override
  State<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends State<TemplateEditPage> {
  String _q = '';

  Future<void> _addFoodToTemplate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        Food? selected;
        final amountCtrl = TextEditingController(text: '1');
        final searchCtrl = TextEditingController();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setInner) {
                final unitSuffix = selected?.unit ?? 'g';

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Add food to template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                        builder: (_, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final foods = snap.data ?? const <Food>[];
                          if (foods.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No foods found.'));
                          return SizedBox(
                            height: 240,
                            child: ListView.builder(
                              itemCount: foods.length,
                              itemBuilder: (_, i) {
                                final f = foods[i];
                                final isSel = selected?.id == f.id;
                                return ListTile(
                                  title: Text(f.name),
                                  subtitle: Text('${f.calories.toStringAsFixed(0)} kcal (${_baseLabel(f)})'),
                                  trailing: isSel ? const Icon(Icons.check_circle) : null,
                                  onTap: () => setInner(() => selected = f),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          suffixText: unitSuffix,
                          helperText: selected == null ? null : 'Nutrition is ${_baseLabel(selected!)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          final f = selected;
                          if (f == null) return;

                          final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
                          if (amount <= 0) return;

                          await AppDb.instance.addMealTemplateItem(
                            templateId: widget.templateId,
                            foodId: f.id!,
                            amount: amount,
                            unit: f.unit,
                            baseAmount: f.baseAmount,
                            sortOrder: 0,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) setState(() {});
                        },
                        child: const Text('Add to template'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateName),
        actions: [
          IconButton(
            tooltip: 'Add to template',
            icon: const Icon(Icons.add),
            onPressed: _addFoodToTemplate,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<MealTemplateItem>>(
          future: AppDb.instance.getMealTemplateItems(widget.templateId),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final items = snap.data ?? const <MealTemplateItem>[];

            return Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Search items', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No items yet. Tap + to add foods.'))
                      : ListView(
                          children: items.where((it) {
                            if (_q.isEmpty) return true;
                            return it.foodId.toString().contains(_q);
                          }).map((it) {
                            return Card(
                              child: ListTile(
                                title: Text('Food ID: ${it.foodId}'),
                                subtitle: Text('${it.amount} ${it.unit}'),
                                // Simple MVP: we don’t edit/remove single items yet (can add later easily)
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: In this MVP, template items show Food ID. Next step: join foods to show names + remove/reorder.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFoodToTemplate,
        child: const Icon(Icons.add),
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

  static const kUnits = <String>[
    'g',
    'ml',
    'tbsp',
    'tsp',
    'cup',
    'liter',
    'piece',
    'slice',
  ];

  double _computeBaseAmount(String unit) {
    if (unit == 'g' || unit == 'ml') return 100;
    return 1;
    }

  Future<void> _openFoodForm({Food? existing}) async {
    if (existing?.isSystem == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System foods cannot be edited.')),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final calsCtrl = TextEditingController(text: (existing?.calories ?? 0).toString());
    final protCtrl = TextEditingController(text: (existing?.protein ?? 0).toString());
    final carbCtrl = TextEditingController(text: (existing?.carbs ?? 0).toString());
    final fatCtrl = TextEditingController(text: (existing?.fat ?? 0).toString());
    final fiberCtrl = TextEditingController(text: (existing?.fiber ?? 0).toString());
    final sugarCtrl = TextEditingController(text: (existing?.sugar ?? 0).toString());
    final sodiumCtrl = TextEditingController(text: (existing?.sodium ?? 0).toString());

    String selectedUnit = existing?.unit ?? 'g';

    double parseNum(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final baseAmount = _computeBaseAmount(selectedUnit);
          final baseLabel = 'per ${baseAmount.toStringAsFixed(baseAmount == baseAmount.roundToDouble() ? 0 : 1)} $selectedUnit';

          return AlertDialog(
            title: Text(existing == null ? 'Add food ($baseLabel)' : 'Edit food ($baseLabel)'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      helperText: 'For g/ml values are per 100. For others values are per 1.',
                      helperMaxLines: 2,
                    ),
                    items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setInner(() => selectedUnit = v ?? 'g'),
                  ),
                  const SizedBox(height: 10),
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
                      unit: selectedUnit,
                      baseAmount: _computeBaseAmount(selectedUnit),
                      isSystem: false,
                      category: existing?.category,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foods'),
        actions: [
          IconButton(
            tooltip: 'Templates',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage()));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
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
                      final baseStr = _baseLabel(f);

                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(f.name)),
                              if (f.isSystem)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.lock_outline, size: 18),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${f.calories.toStringAsFixed(0)} kcal • P ${f.protein}g • C ${f.carbs}g • F ${f.fat}g ($baseStr)',
                          ),
                          onTap: () => _openFoodForm(existing: f),
                          trailing: f.isSystem
                              ? null
                              : IconButton(
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
            tooltip: 'Data retention',
            icon: const Icon(Icons.storage),
            onPressed: () async {
              await editRetentionDaysDialog(context);
              if (mounted) setState(() {});
            },
          ),
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
            tooltip: 'Goal calculator',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => GoalCalculatorScreen(date: _date)),
              );
              if (changed == true && mounted) setState(() {});
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
            AppDb.instance.getLogRowsForDate(_date),
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
            final rows = (data?[2] as List<Map<String, Object?>>?) ?? const [];

            return ListView(
              children: [
                _progressBarCalories(taken: totals.calories.round(), target: targets.calories),
                const SizedBox(height: 12),
                _targetsTable(totals: totals, targets: targets),
                const SizedBox(height: 12),

                const Text('Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No entries for this date.')),
                  )
                else
                  ...rows.map((r) {
                    final logId = r['log_id'] as int;

                    final entryType = (r['entry_type'] as String?) ?? 'food';
                    final name = (r['name'] as String?) ?? 'Unknown';

                    final time = (r['time'] as String?)?.trim();
                    final label = (r['label'] as String?)?.trim();
                    final metaParts = <String>[
                      if (time != null && time.isNotEmpty) time,
                      if (label != null && label.isNotEmpty) label,
                    ];
                    final meta = metaParts.join(' • ');

                    String subtitle;

                    if (entryType == 'manual') {
                      final kcal = ((r['calories'] as num?) ?? 0).toDouble();
                      subtitle = meta.isEmpty ? '${kcal.toStringAsFixed(0)} kcal' : '$meta • ${kcal.toStringAsFixed(0)} kcal';
                    } else {
                      final amount = (r['grams'] as num).toDouble();
                      final unit = (r['unit'] as String?)?.trim().isNotEmpty == true ? (r['unit'] as String) : 'g';
                      final baseAmount = ((r['base_amount'] as num?) ?? 100).toDouble();
                      final safeBase = baseAmount <= 0 ? 1.0 : baseAmount;

                      final kcalPerBase = ((r['calories'] as num?) ?? 0).toDouble();
                      final kcal = kcalPerBase * amount / safeBase;

                      final amountStr = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 1);

                      subtitle = meta.isEmpty
                          ? '$amountStr $unit • ${kcal.toStringAsFixed(0)} kcal'
                          : '$meta • $amountStr $unit • ${kcal.toStringAsFixed(0)} kcal';
                    }

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
                  }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}