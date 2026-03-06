// lib/settings/target_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class TargetSettings {
  static const _kCalories = 'targets_calories';
  static const _kProtein = 'targets_protein';
  static const _kCarbs = 'targets_carbs';
  static const _kFat = 'targets_fat';

  static Future<int> getCalories() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kCalories) ?? 2000;
    }

  static Future<int> getProtein() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kProtein) ?? 150;
  }

  static Future<int> getCarbs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kCarbs) ?? 200;
  }

  static Future<int> getFat() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kFat) ?? 70;
  }

  static Future<void> setCalories(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kCalories, v);
  }

  static Future<void> setProtein(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kProtein, v);
  }

  static Future<void> setCarbs(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kCarbs, v);
  }

  static Future<void> setFat(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kFat, v);
  }

  static Future<void> resetAllTargets() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kCalories);
    await sp.remove(_kProtein);
    await sp.remove(_kCarbs);
    await sp.remove(_kFat);
  }
}