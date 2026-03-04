import 'package:shared_preferences/shared_preferences.dart';

class RetentionSettings {
  static const _kDays = 'retention_days';

  /// Default: keep 365 days
  static Future<int> getRetentionDays() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kDays) ?? 365;
  }

  static Future<void> setRetentionDays(int days) async {
    final sp = await SharedPreferences.getInstance();
    // clamp to reasonable range
    final v = days.clamp(7, 3650);
    await sp.setInt(_kDays, v);
  }
}