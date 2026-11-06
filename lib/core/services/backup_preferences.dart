import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keys persisted in backup bundles (app settings + backgrounds).
final backupPreferenceKeys = <String>{
  'locale_code',
  'theme_mode',
  'first_run_complete',
  'dashboard_order',
  'learning_source_lang',
  'notifications_enabled',
  'workout_music_enabled',
  'workout_music_pause_rest',
  'workout_music_stop_end',
  'daily_water_goal_ml',
  'step_goal',
  'last_backup_at',
  'quick_water_ml',
  'recent_quick_actions',
  'dashboard_hidden',
  'fitness_media_online',
  'fitness_offline_pack_ready',
  'alarm_voice_language',
  'alarm_voice_name',
  'alarm_voice_gender',
  'alarm_voice_rate',
  'alarm_voice_pitch',
  'alarm_voice_volume',
  'background_home',
  'background_alarm',
};

Map<String, Object?> exportPreferences(SharedPreferences prefs) {
  final out = <String, Object?>{};
  for (final key in backupPreferenceKeys) {
    final value = prefs.get(key);
    if (value != null) out[key] = value;
  }
  return out;
}

Future<void> importPreferences(
  SharedPreferences prefs,
  Map<String, Object?> data,
) async {
  for (final entry in data.entries) {
    if (!backupPreferenceKeys.contains(entry.key)) continue;
    final value = entry.value;
    if (value is bool) {
      await prefs.setBool(entry.key, value);
    } else if (value is int) {
      await prefs.setInt(entry.key, value);
    } else if (value is double) {
      await prefs.setDouble(entry.key, value);
    } else if (value is String) {
      await prefs.setString(entry.key, value);
    } else if (value is List) {
      await prefs.setStringList(
        entry.key,
        value.map((e) => e.toString()).toList(),
      );
    }
  }
}

String encodePreferences(Map<String, Object?> data) =>
    jsonEncode(data);

Map<String, Object?> decodePreferences(String raw) =>
    (jsonDecode(raw) as Map<String, dynamic>).cast<String, Object?>();
