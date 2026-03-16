// lib/main.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqflite.dart' as common;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'data/db.dart';
import 'data/models.dart';
import 'settings/target_settings.dart';
import 'settings/retention_settings.dart';

const bool kResetOnStartup = false;
const String kBrandMarkAsset = 'assets/branding/caloriefit_mark.png';
const String kBrandLogoAsset = 'assets/branding/caloriefit_logo.png';
const Color kBrandPrimary = Color(0xFF0B3C49);
const Color kBrandAccent = Color(0xFF3AC47D);
const Color kBrandSurface = Color(0xFFF4FBF7);

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
    common.databaseFactory = sqflite.databaseFactory;
  }

  await AppDb.instance.db;
//  await AppDb.instance.reseedSystemLibrary();

  runApp(const CalorieFitApp());
}

class CalorieFitApp extends StatelessWidget {
  const CalorieFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrandPrimary,
        scaffoldBackgroundColor: kBrandSurface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kBrandPrimary,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const InitGate(),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        kBrandMarkAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class BrandedAppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const BrandedAppBarTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle ?? 'CalorieFit',
              style: textTheme.labelMedium?.copyWith(
                color: kBrandPrimary.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(kBrandLogoAsset, width: 220),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Startup Error')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('App failed to start:\n\n${snap.error}'),
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
      const GlobalPage(),
      const HistoryPage(),
    ];

    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'My Foods'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Global'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'History'),
        ],
      ),
    );
  }
}

// ---------------- Shared helpers ----------------

String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _baseLabel(Food f) {
  final u = f.unit;
  final b = f.baseAmount;
  return 'per ${b.toStringAsFixed(b == b.roundToDouble() ? 0 : 1)} $u';
}

String _numStr(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

String _macroLine({
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
}) {
  return '${calories.toStringAsFixed(0)} kcal • '
      'P ${_numStr(protein)}g • '
      'C ${_numStr(carbs)}g • '
      'F ${_numStr(fat)}g';
}

String _foodListSubtitle(Food f, {String? extra}) {
  final lines = <String>[
    '${_baseLabel(f)}${extra != null && extra.isNotEmpty ? ' • $extra' : ''}',
    _macroLine(
      calories: f.calories,
      protein: f.protein,
      carbs: f.carbs,
      fat: f.fat,
    ),
  ];
  return lines.join('\n');
}

String _templateListSubtitle({
  required String label,
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
  bool isDefaultLabel = false,
  String? ingredientsPreview,
}) {
  final labelText = isDefaultLabel ? 'Default label: $label' : 'Label: $label';

  final lines = <String>[
    labelText,
    _macroLine(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    ),
    if (ingredientsPreview != null && ingredientsPreview.trim().isNotEmpty)
      ingredientsPreview.trim(),
  ];

  return lines.join('\n');
}

String _logSubtitleFromRow(Map<String, Object?> r) {
  final entryType = (r['entry_type'] as String?) ?? 'food';

  final time = (r['time'] as String?)?.trim();
  final label = (r['label'] as String?)?.trim();

  final metaParts = <String>[
    if (time != null && time.isNotEmpty) time,
    if (label != null && label.isNotEmpty) label,
  ];
  final meta = metaParts.join(' • ');

  if (entryType == 'manual') {
    final kcal = ((r['calories'] as num?) ?? 0).toDouble();
    final protein = ((r['protein'] as num?) ?? 0).toDouble();
    final carbs = ((r['carbs'] as num?) ?? 0).toDouble();
    final fat = ((r['fat'] as num?) ?? 0).toDouble();

    final lines = <String>[
      if (meta.isNotEmpty) meta,
      _macroLine(
        calories: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    ];
    return lines.join('\n');
  } else {
    final amount = ((r['grams'] as num?) ?? 0).toDouble();
    final unit = (r['unit'] as String?)?.trim().isNotEmpty == true ? (r['unit'] as String) : 'g';
    final baseAmount = ((r['base_amount'] as num?) ?? 100).toDouble();
    final safeBase = baseAmount <= 0 ? 1.0 : baseAmount;
    final factor = amount / safeBase;

    final kcalPerBase = ((r['calories'] as num?) ?? 0).toDouble();
    final proteinPerBase = ((r['protein'] as num?) ?? 0).toDouble();
    final carbsPerBase = ((r['carbs'] as num?) ?? 0).toDouble();
    final fatPerBase = ((r['fat'] as num?) ?? 0).toDouble();

    final kcal = kcalPerBase * factor;
    final protein = proteinPerBase * factor;
    final carbs = carbsPerBase * factor;
    final fat = fatPerBase * factor;

    final amountStr = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 1);

    final lines = <String>[
      if (meta.isNotEmpty) meta,
      '$amountStr $unit',
      _macroLine(
        calories: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    ];
    return lines.join('\n');
  }
}

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

// ---------------- Targets dialogs ----------------

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default targets saved')));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Targets saved for $date')));
  }
}

double _activityFactor(String value) {
  switch (value) {
    case 'Light':
      return 1.375;
    case 'Moderate':
      return 1.55;
    case 'Active':
      return 1.725;
    case 'Very active':
      return 1.9;
    case 'Sedentary':
    default:
      return 1.2;
  }
}

int _goalAdjustment(String value) {
  switch (value) {
    case 'Lose':
      return -400;
    case 'Gain':
      return 300;
    case 'Maintain':
    default:
      return 0;
  }
}

Future<void> showBmiAndCalorieToolsDialog(BuildContext context, String date) async {
  final heightCtrl = TextEditingController(text: '170');
  final weightCtrl = TextEditingController(text: '70');
  final ageCtrl = TextEditingController(text: '30');

  String sex = 'Male';
  String activity = 'Moderate';
  String goal = 'Maintain';

  double parseNum(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  int parseInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final heightCm = parseNum(heightCtrl);
        final weightKg = parseNum(weightCtrl);
        final age = parseInt(ageCtrl);

        final heightM = heightCm > 0 ? heightCm / 100 : 0;
        final bmi = (heightM > 0) ? (weightKg / (heightM * heightM)) : 0.0;

        String bmiText;
        if (bmi <= 0) {
          bmiText = '-';
        } else if (bmi < 18.5) {
          bmiText = 'Underweight';
        } else if (bmi < 25) {
          bmiText = 'Normal';
        } else if (bmi < 30) {
          bmiText = 'Overweight';
        } else {
          bmiText = 'Obesity';
        }

        double bmr = 0;
        if (heightCm > 0 && weightKg > 0 && age > 0) {
          if (sex == 'Male') {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
          } else {
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
          }
        }

        final tdee = bmr * _activityFactor(activity);
        final targetCalories = (tdee + _goalAdjustment(goal)).round();

        final protein =
            goal == 'Lose' ? (weightKg * 2.0).round() : (weightKg * 1.8).round();
        final fat = ((targetCalories * 0.25) / 9).round();
        final carbs = (((targetCalories - (protein * 4) - (fat * 9)) / 4))
            .clamp(0, 100000)
            .round();

        return AlertDialog(
          title: const Text('BMI & calorie target'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  onChanged: (_) => setInner(() {}),
                ),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  onChanged: (_) => setInner(() {}),
                ),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                  onChanged: (_) => setInner(() {}),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (v) => setInner(() => sex = v ?? 'Male'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: activity,
                  decoration: const InputDecoration(labelText: 'Activity'),
                  items: const [
                    DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                    DropdownMenuItem(value: 'Light', child: Text('Light')),
                    DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Very active', child: Text('Very active')),
                  ],
                  onChanged: (v) => setInner(() => activity = v ?? 'Moderate'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: goal,
                  decoration: const InputDecoration(labelText: 'Goal'),
                  items: const [
                    DropdownMenuItem(value: 'Lose', child: Text('Lose')),
                    DropdownMenuItem(value: 'Maintain', child: Text('Maintain')),
                    DropdownMenuItem(value: 'Gain', child: Text('Gain')),
                  ],
                  onChanged: (v) => setInner(() => goal = v ?? 'Maintain'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('BMI: ${bmi > 0 ? bmi.toStringAsFixed(1) : '-'}'),
                        Text('BMI status: $bmiText'),
                        const SizedBox(height: 8),
                        Text('BMR: ${bmr > 0 ? bmr.toStringAsFixed(0) : '-'} kcal'),
                        Text('Estimated daily calories: ${targetCalories > 0 ? targetCalories : '-'} kcal'),
                        const SizedBox(height: 8),
                        Text('Protein target: ${protein > 0 ? protein : '-'} g'),
                        Text('Carbs target: ${carbs >= 0 ? carbs : '-'} g'),
                        Text('Fat target: ${fat > 0 ? fat : '-'} g'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                if (targetCalories <= 0) return;

                await TargetSettings.setCalories(targetCalories);
                await TargetSettings.setProtein(protein);
                await TargetSettings.setCarbs(carbs);
                await TargetSettings.setFat(fat);

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved as default targets')),
                  );
                }
              },
              child: const Text('Save default'),
            ),
            FilledButton(
              onPressed: () async {
                if (targetCalories <= 0) return;

                await AppDb.instance.setTargetsForDate(
                  date,
                  MacroTargets(
                    calories: targetCalories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                  ),
                  source: 'calculator',
                  calculatorJson: jsonEncode({
                    'height_cm': heightCm,
                    'weight_kg': weightKg,
                    'age': age,
                    'sex': sex,
                    'activity': activity,
                    'goal': goal,
                    'bmi': bmi,
                    'bmr': bmr,
                    'tdee': tdee,
                  }),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved targets for $date')),
                  );
                }
              },
              child: const Text('Save for this date'),
            ),
          ],
        );
      },
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
  String _date = _fmtDate(DateTime.now());

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
    if (picked != null) setState(() => _date = _fmtDate(picked));
  }

  Future<void> _showAddMenu() async {
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
              title: const Text('Add from My Foods'),
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
              title: const Text('Add from My Templates'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addFromTemplates();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addLogEntryFromFoods() async {
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
                        decoration: const InputDecoration(labelText: 'Search My Foods', prefixIcon: Icon(Icons.search)),
                        onChanged: (_) => setInner(() {}),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Food>>(
                        future: AppDb.instance.getUserFoods(query: searchCtrl.text.trim()),
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
                              child: Text('No foods found. Add foods in My Foods or import from Global.'),
                            );
                          }
                          return SizedBox(
                            height: 240,
                            child: ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final f = list[i];
                                final isSel = selected?.id == f.id;
                                return ListTile(
                                  isThreeLine: true,
                                  title: Text(f.name),
                                  subtitle: Text(_foodListSubtitle(f)),
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
  final nameCtrl = TextEditingController();
  final kcalCtrl = TextEditingController();
  final pCtrl = TextEditingController(text: '0');
  final cCtrl = TextEditingController(text: '0');
  final fCtrl = TextEditingController(text: '0');

  String selectedLabel = 'Breakfast';
  TimeOfDay selectedTime = TimeOfDay.now();

  double d(TextEditingController t) =>
      double.tryParse(t.text.trim().replaceAll(',', '.')) ?? 0;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
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
                        child: Text(
                          'Quick entry',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name (e.g., Restaurant pasta)',
                    ),
                  ),
                  const SizedBox(height: 10),
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
                          if (picked != null) {
                            setInner(() => selectedTime = picked);
                          }
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
                  ),
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
                      const Expanded(child: Text('Add from My Templates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
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
                  FutureBuilder<List<TemplateWithTotals>>(
                    future: AppDb.instance.getUserMealTemplatesWithTotals(),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final templates = snap.data ?? const <TemplateWithTotals>[];
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
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage()));
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
                            final row = templates[i];
                            final t = row.template;
                            final totals = row.totals;

                            return Card(
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(t.name),
                                subtitle: Text(
                                  _templateListSubtitle(
                                    label: t.label,
                                    calories: totals.calories,
                                    protein: totals.protein,
                                    carbs: totals.carbs,
                                    fat: totals.fat,
                                  ),
                                ),
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
        title: BrandedAppBarTitle(title: 'Today', subtitle: _date),
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
            tooltip: 'Reset targets for this date',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await AppDb.instance.clearTargetsForDate(_date);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Using default targets for this date')));
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
            final targets = (data?[1] as MacroTargets?) ?? const MacroTargets(calories: 2000, protein: 150, carbs: 200, fat: 70);
            final rows = (data?[2] as List<Map<String, Object?>>?) ?? const [];

            return ListView(
              children: [
               Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Health tools',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.monitor_weight_outlined),
              label: const Text('BMI & calories'),
              onPressed: () async {
                await showBmiAndCalorieToolsDialog(context, _date);
                if (mounted) setState(() {});
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Edit targets'),
              onPressed: () async {
                await editTargetsForDateOneDialog(context, _date);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ],
    ),
  ),
),
const SizedBox(height: 12),
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
                    final name = (r['name'] as String?) ?? 'Unknown';
                    final subtitle = _logSubtitleFromRow(r);

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
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

// ---------------- MY FOODS ----------------

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  String _q = '';

  static const kUnits = <String>['g', 'ml', 'tbsp', 'tsp', 'cup', 'liter', 'piece', 'slice'];

  double _computeBaseAmount(String unit) => (unit == 'g' || unit == 'ml') ? 100 : 1;

  Future<void> _openFoodForm({Food? existing}) async {
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

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
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openTemplates() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesPage()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle(title: 'My Foods'),
        actions: [
          IconButton(
            tooltip: 'My Templates',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _openTemplates,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openFoodForm(), child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Search My Foods', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Food>>(
                future: AppDb.instance.getUserFoods(query: _q),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final foods = snap.data ?? const <Food>[];
                  if (foods.isEmpty) return const Center(child: Text('No foods yet. Add or import from Global.'));

                  return ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (_, i) {
                      final f = foods[i];
                      return Card(
                        child: ListTile(
                          isThreeLine: true,
                          title: Text(f.name),
                          subtitle: Text(_foodListSubtitle(f)),
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

// ---------------- GLOBAL PAGE ----------------

class GlobalPage extends StatefulWidget {
  const GlobalPage({super.key});

  @override
  State<GlobalPage> createState() => _GlobalPageState();
}

class _GlobalPageState extends State<GlobalPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle(title: 'Global'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Foods'),
            Tab(icon: Icon(Icons.bookmarks), text: 'Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          GlobalFoodsTab(),
          GlobalTemplatesTab(),
        ],
      ),
    );
  }
}

class GlobalFoodsTab extends StatefulWidget {
  const GlobalFoodsTab({super.key});

  @override
  State<GlobalFoodsTab> createState() => _GlobalFoodsTabState();
}

class _GlobalFoodsTabState extends State<GlobalFoodsTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Search global foods', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Food>>(
              future: AppDb.instance.getSystemFoods(query: _q),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final foods = snap.data ?? const <Food>[];
                if (foods.isEmpty) return const Center(child: Text('No system foods found.'));

                return ListView.builder(
                  itemCount: foods.length,
                  itemBuilder: (_, i) {
                    final f = foods[i];
                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        title: Text(f.name),
                        subtitle: Text(_foodListSubtitle(f, extra: f.category ?? 'Uncategorized')),
                        trailing: FilledButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Add'),
                          onPressed: () async {
                            await AppDb.instance.importSystemFoodToUser(f.id!);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to My Foods')));
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
    );
  }
}


class GlobalTemplatesTab extends StatefulWidget {
  const GlobalTemplatesTab({super.key});

  @override
  State<GlobalTemplatesTab> createState() => _GlobalTemplatesTabState();
}

class _GlobalTemplatesTabState extends State<GlobalTemplatesTab> {
  String _q = '';
  String _labelFilter = 'All';
  late Future<List<TemplateWithTotalsPreview>> _future;

  static const _labels = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _future = _loadTemplates();
  }

  Future<List<TemplateWithTotalsPreview>> _loadTemplates() {
    return AppDb.instance.getSystemMealTemplatesWithTotalsPreview(
      query: _q,
      label: _labelFilter == 'All' ? null : _labelFilter,
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search global templates',
              prefixIcon: Icon(Icons.search),
              helperText: 'Search by template name or label like Breakfast',
            ),
            onChanged: (v) {
              _q = v;
              _refresh();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _labels.map((label) {
                final selected = _labelFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      _labelFilter = label;
                      _refresh();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<TemplateWithTotalsPreview>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? const <TemplateWithTotalsPreview>[];
                if (list.isEmpty) {
                  return const Center(child: Text('No global templates found.'));
                }

                final widgets = <Widget>[];
                String? currentLabel;

                for (final row in list) {
                  final t = row.template;
                  final totals = row.totals;
                  final previewText = row.itemCount > 0
                      ? row.ingredientsPreview
                      : 'No ingredients found. Reseed system templates once.';

                  if (currentLabel != t.label) {
                    currentLabel = t.label;
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          currentLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }

                  widgets.add(
                    Card(
                      child: ListTile(
                        isThreeLine: true,
                        title: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _templateListSubtitle(
                            label: t.label,
                            calories: totals.calories,
                            protein: totals.protein,
                            carbs: totals.carbs,
                            fat: totals.fat,
                            isDefaultLabel: true,
                            ingredientsPreview: previewText,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SystemTemplatePreviewPage(
                                systemTemplateId: t.id!,
                              ),
                            ),
                          );
                          if (mounted) _refresh();
                        },
                      ),
                    ),
                  );
                }

                return ListView(children: widgets);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SystemTemplatePreviewPage extends StatefulWidget {
  final int systemTemplateId;
  const SystemTemplatePreviewPage({super.key, required this.systemTemplateId});

  @override
  State<SystemTemplatePreviewPage> createState() => _SystemTemplatePreviewPageState();
}

class _SystemTemplatePreviewPageState extends State<SystemTemplatePreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template preview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<SystemTemplatePreview>(
          future: AppDb.instance.getSystemTemplatePreview(widget.systemTemplateId),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final preview = snap.data!;
            final totals = preview.totals;

            return ListView(
              children: [
                Text(preview.template.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Default label: ${preview.template.label}'),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Totals', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Calories: ${totals.calories.toStringAsFixed(0)} kcal'),
                        Text('Protein: ${totals.protein.toStringAsFixed(1)} g'),
                        Text('Carbs: ${totals.carbs.toStringAsFixed(1)} g'),
                        Text('Fat: ${totals.fat.toStringAsFixed(1)} g'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                ...preview.items.map((it) {
                  final amt = it.amount.toStringAsFixed(it.amount == it.amount.roundToDouble() ? 0 : 1);
                  return Card(
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(it.name),
                      subtitle: Text(
                        '$amt ${it.unit}\n'
                        '${_macroLine(
                          calories: it.calories,
                          protein: it.protein,
                          carbs: it.carbs,
                          fat: it.fat,
                        )}',
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Import to My Templates'),
                  onPressed: () async {
                    final labelCtrl = TextEditingController(text: preview.template.label);
                    final nameCtrl = TextEditingController(text: preview.template.name);

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Import template'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Template name')),
                            const SizedBox(height: 10),
                            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (custom allowed)')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
                        ],
                      ),
                    );

                    if (ok != true) return;

                    await AppDb.instance.importSystemTemplateToUser(
                      systemTemplateId: widget.systemTemplateId,
                      newLabel: labelCtrl.text.trim().isEmpty ? preview.template.label : labelCtrl.text.trim(),
                      newName: nameCtrl.text.trim().isEmpty ? preview.template.name : nameCtrl.text.trim(),
                    );

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported to My Templates')));
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- USER TEMPLATES ----------------

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  Future<void> _createTemplate() async {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Breakfast');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (custom allowed)')),
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
    final label = labelCtrl.text.trim();
    if (name.isEmpty) return;

    final id = await AppDb.instance.createMealTemplate(name: name, label: label.isEmpty ? 'Breakfast' : label);

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(templateId: id, title: name)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Templates')),
      floatingActionButton: FloatingActionButton(onPressed: _createTemplate, child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<TemplateWithTotals>>(
          future: AppDb.instance.getUserMealTemplatesWithTotals(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final list = snap.data ?? const <TemplateWithTotals>[];
            if (list.isEmpty) return const Center(child: Text('No templates yet. Tap + to create one.'));

            return ListView.builder(
  itemCount: list.length,
  itemExtent: 92,
  itemBuilder: (_, i) {
    final row = list[i];
    final t = row.template;
    final totals = row.totals;

    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(
          t.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _templateListSubtitle(
            label: t.label,
            calories: totals.calories,
            protein: totals.protein,
            carbs: totals.carbs,
            fat: totals.fat,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await AppDb.instance.deleteMealTemplate(t.id!);
            if (mounted) setState(() {});
          },
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TemplateEditPage(templateId: t.id!, title: t.name),
            ),
          );
          if (mounted) setState(() {});
        },
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
  final String title;

  const TemplateEditPage({
    super.key,
    required this.templateId,
    required this.title,
  });

  @override
  State<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends State<TemplateEditPage> {
  Future<void> _addFoodToTemplate() async {
    Food? selected;
    final amountCtrl = TextEditingController(text: '1');
    final searchCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
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
                            child: Text(
                              'Add food',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search My Foods',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setInner(() {}),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Food>>(
                        future: AppDb.instance.getUserFoods(
                          query: searchCtrl.text.trim(),
                        ),
                        builder: (_, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final foods = snap.data ?? const <Food>[];
                          if (foods.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No My Foods found. Import from Global first.',
                              ),
                            );
                          }

                          return SizedBox(
                            height: 240,
                            child: ListView.builder(
                              itemCount: foods.length,
                              itemBuilder: (_, i) {
                                final f = foods[i];
                                final isSel = selected?.id == f.id;

                                return ListTile(
                                  isThreeLine: true,
                                  title: Text(f.name),
                                  subtitle: Text(_foodListSubtitle(f)),
                                  trailing: isSel
                                      ? const Icon(Icons.check_circle)
                                      : null,
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          final f = selected;
                          if (f == null) return;

                          final amount = double.tryParse(
                                amountCtrl.text.trim().replaceAll(',', '.'),
                              ) ??
                              0;
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

  Future<List<Map<String, Object?>>> _loadJoinedItems() async {
    return AppDb.instance.getMealTemplateItemsJoined(widget.templateId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addFoodToTemplate,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _loadJoinedItems(),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final list = snap.data ?? const [];

            if (list.isEmpty) {
              return const Center(
                child: Text('No items yet. Tap + to add foods.'),
              );
            }

            return ListView(
              children: list.map((row) {
                final it = MealTemplateItem.fromMap({
                  'id': row['id'],
                  'template_id': row['template_id'],
                  'food_id': row['food_id'],
                  'amount': row['amount'],
                  'unit': row['unit'],
                  'base_amount': row['base_amount'],
                  'sort_order': row['sort_order'],
                });

                final hasFood = (row['food_name'] as String?) != null;

                final food = hasFood
                    ? Food(
                        id: row['food_id'] as int?,
                        name: (row['food_name'] as String?) ?? 'Unknown',
                        calories: ((row['calories'] as num?) ?? 0).toDouble(),
                        protein: ((row['protein'] as num?) ?? 0).toDouble(),
                        carbs: ((row['carbs'] as num?) ?? 0).toDouble(),
                        fat: ((row['fat'] as num?) ?? 0).toDouble(),
                        fiber: 0,
                        sugar: 0,
                        sodium: 0,
                        unit: (row['food_unit'] as String?) ?? 'g',
                        baseAmount:
                            ((row['food_base_amount'] as num?) ?? 100).toDouble(),
                        isSystem: false,
                        category: null,
                      )
                    : null;

                final name = food?.name ?? 'Food #${it.foodId} (missing)';
                final amountStr = it.amount.toStringAsFixed(
                  it.amount == it.amount.roundToDouble() ? 0 : 1,
                );

                final safeBase = it.baseAmount <= 0 ? 1.0 : it.baseAmount;
                final factor = it.amount / safeBase;

                final calories = (food?.calories ?? 0) * factor;
                final protein = (food?.protein ?? 0) * factor;
                final carbs = (food?.carbs ?? 0) * factor;
                final fat = (food?.fat ?? 0) * factor;

                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(name),
                    subtitle: Text(
                      '$amountStr ${it.unit}\n'
                      '${_macroLine(
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                      )}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (it.id == null) return;
                        await AppDb.instance.deleteMealTemplateItem(it.id!);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              }).toList(),
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

// ---------------- HISTORY ----------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _date = _fmtDate(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_date) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: initial,
    );
    if (picked != null) setState(() => _date = _fmtDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BrandedAppBarTitle(title: 'History', subtitle: _date),
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
            tooltip: 'Reset targets for this date',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await AppDb.instance.clearTargetsForDate(_date);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Using default targets for this date')));
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
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

            final data = snap.data as List<Object?>?;
            final totals = (data?[0] as DayTotals?) ?? const DayTotals();
            final targets = (data?[1] as MacroTargets?) ?? const MacroTargets(calories: 2000, protein: 150, carbs: 200, fat: 70);
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
                    final name = (r['name'] as String?) ?? 'Unknown';
                    final subtitle = _logSubtitleFromRow(r);

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
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
