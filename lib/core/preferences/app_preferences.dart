import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for user-level settings that do not
/// belong in the SQLite database (fast, small, non-relational preferences).
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _kLocale = 'locale_code';
  static const _kThemeMode = 'theme_mode';
  static const _kFirstRun = 'first_run_complete';
  static const _kDashboardOrder = 'dashboard_order';
  static const _kLearningSourceLang = 'learning_source_lang';
  static const _kNotificationsEnabled = 'notifications_enabled';
  static const _kWorkoutMusicEnabled = 'workout_music_enabled';
  static const _kWorkoutMusicPauseOnRest = 'workout_music_pause_rest';
  static const _kWorkoutMusicStopAtEnd = 'workout_music_stop_end';
  static const _kDailyWaterGoal = 'daily_water_goal_ml';
  static const _kStepGoal = 'step_goal';
  static const _kLastBackupAt = 'last_backup_at';
  static const _kQuickWaterMl = 'quick_water_ml';
  static const _kRecentQuickActions = 'recent_quick_actions';
  static const _kDashboardHidden = 'dashboard_hidden';

  String? get localeCode => _prefs.getString(_kLocale);

  Future<void> setLocaleCode(String code) => _prefs.setString(_kLocale, code);

  int get themeMode => _prefs.getInt(_kThemeMode) ?? 0;

  Future<void> setThemeMode(int mode) => _prefs.setInt(_kThemeMode, mode);

  bool get firstRunComplete => _prefs.getBool(_kFirstRun) ?? false;

  Future<void> setFirstRunComplete(bool value) =>
      _prefs.setBool(_kFirstRun, value);

  List<String> get dashboardOrder {
    final raw = _prefs.getString(_kDashboardOrder);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> setDashboardOrder(List<String> order) =>
      _prefs.setString(_kDashboardOrder, jsonEncode(order));

  String get learningSourceLang =>
      _prefs.getString(_kLearningSourceLang) ?? 'ta';

  Future<void> setLearningSourceLang(String code) =>
      _prefs.setString(_kLearningSourceLang, code);

  bool get notificationsEnabled =>
      _prefs.getBool(_kNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_kNotificationsEnabled, value);

  bool get workoutMusicEnabled =>
      _prefs.getBool(_kWorkoutMusicEnabled) ?? false;

  Future<void> setWorkoutMusicEnabled(bool value) =>
      _prefs.setBool(_kWorkoutMusicEnabled, value);

  bool get workoutMusicPauseOnRest =>
      _prefs.getBool(_kWorkoutMusicPauseOnRest) ?? true;

  Future<void> setWorkoutMusicPauseOnRest(bool value) =>
      _prefs.setBool(_kWorkoutMusicPauseOnRest, value);

  bool get workoutMusicStopAtEnd =>
      _prefs.getBool(_kWorkoutMusicStopAtEnd) ?? false;

  Future<void> setWorkoutMusicStopAtEnd(bool value) =>
      _prefs.setBool(_kWorkoutMusicStopAtEnd, value);

  int get dailyWaterGoalMl => _prefs.getInt(_kDailyWaterGoal) ?? 2500;

  Future<void> setDailyWaterGoalMl(int value) =>
      _prefs.setInt(_kDailyWaterGoal, value);

  int get stepGoal => _prefs.getInt(_kStepGoal) ?? 6000;

  Future<void> setStepGoal(int value) => _prefs.setInt(_kStepGoal, value);

  DateTime? get lastBackupAt {
    final millis = _prefs.getInt(_kLastBackupAt);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastBackupAt(DateTime value) =>
      _prefs.setInt(_kLastBackupAt, value.millisecondsSinceEpoch);

  /// Last water amount used by the quick-add water action (defaults to 250 ml).
  int get quickWaterMl => _prefs.getInt(_kQuickWaterMl) ?? 250;

  Future<void> setQuickWaterMl(int value) =>
      _prefs.setInt(_kQuickWaterMl, value);

  /// Most-recently-used quick action keys, newest first.
  List<String> get recentQuickActions {
    final raw = _prefs.getString(_kRecentQuickActions);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> setRecentQuickActions(List<String> keys) =>
      _prefs.setString(_kRecentQuickActions, jsonEncode(keys));

  /// Dashboard section keys the user has hidden.
  List<String> get dashboardHidden {
    final raw = _prefs.getString(_kDashboardHidden);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> setDashboardHidden(List<String> keys) =>
      _prefs.setString(_kDashboardHidden, jsonEncode(keys));
}
