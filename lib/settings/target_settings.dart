// lib/settings/target_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class TargetSettings {
  static const _kCalories = 'target_calories';
  static const _kProtein = 'target_protein';
  static const _kCarbs = 'target_carbs';
  static const _kFat = 'target_fat';

  static const int defaultCalories = 2000;
  static const int defaultProtein = 150; // g
  static const int defaultCarbs = 200; // g
  static const int defaultFat = 70; // g

  static Future<int> getCalories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kCalories) ?? defaultCalories;
  }

  static Future<int> getProtein() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kProtein) ?? defaultProtein;
  }

  static Future<int> getCarbs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kCarbs) ?? defaultCarbs;
  }

  static Future<int> getFat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kFat) ?? defaultFat;
  }

  static Future<void> setCalories(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCalories, v);
  }

  static Future<void> setProtein(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProtein, v);
  }

  static Future<void> setCarbs(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCarbs, v);
  }

  static Future<void> setFat(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFat, v);
  }

  // ✅ Test helper: clears saved targets so defaults apply again
  static Future<void> resetAllTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCalories);
    await prefs.remove(_kProtein);
    await prefs.remove(_kCarbs);
    await prefs.remove(_kFat);
  }
}