// lib/settings/retention_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class RetentionSettings {
  static const _kRetentionDays = 'retention_days';

  static Future<int> getRetentionDays() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kRetentionDays) ?? 180;
  }

  static Future<void> setRetentionDays(int days) async {
    final sp = await SharedPreferences.getInstance();
    final clamped = days.clamp(7, 3650);
    await sp.setInt(_kRetentionDays, clamped);
  }
}