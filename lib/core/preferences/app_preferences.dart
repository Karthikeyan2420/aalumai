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
  static const _kJarvisReminderSeq = 'jarvis_reminder_seq';
  static const _kJarvisModelFile = 'jarvis_model_file';
  static const _kJarvisModelSha = 'jarvis_model_sha256';
  static const _kJarvisModelThreads = 'jarvis_model_threads';
  static const _kJarvisModelContext = 'jarvis_model_context';
  static const _kJarvisBriefingEnabled = 'jarvis_briefing_enabled';
  static const _kJarvisBriefingId = 'jarvis_briefing_id';
  static const _kRecentQuickActions = 'recent_quick_actions';
  static const _kDashboardHidden = 'dashboard_hidden';

  // Global alarm voice preferences (shared by every ringing alarm).
  static const _kVoiceLanguage = 'alarm_voice_language';
  static const _kVoiceName = 'alarm_voice_name';
  static const _kVoiceGender = 'alarm_voice_gender';
  static const _kVoiceRate = 'alarm_voice_rate';
  static const _kVoicePitch = 'alarm_voice_pitch';
  static const _kVoiceVolume = 'alarm_voice_volume';

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

  /// Preferred TTS language for alarms. Empty means "follow the app language".
  String get alarmVoiceLanguage => _prefs.getString(_kVoiceLanguage) ?? '';

  Future<void> setAlarmVoiceLanguage(String code) =>
      _prefs.setString(_kVoiceLanguage, code);

  /// The installed TTS voice name to use, or empty for "device default / any".
  String get alarmVoiceName => _prefs.getString(_kVoiceName) ?? '';

  Future<void> setAlarmVoiceName(String name) =>
      _prefs.setString(_kVoiceName, name);

  /// Voice gender preference: 0 = default/any, 1 = female, 2 = male.
  int get alarmVoiceGender => _prefs.getInt(_kVoiceGender) ?? 0;

  Future<void> setAlarmVoiceGender(int value) =>
      _prefs.setInt(_kVoiceGender, value);

  double get alarmSpeechRate => _prefs.getDouble(_kVoiceRate) ?? 1.0;

  Future<void> setAlarmSpeechRate(double value) =>
      _prefs.setDouble(_kVoiceRate, value);

  double get alarmSpeechPitch => _prefs.getDouble(_kVoicePitch) ?? 1.0;

  Future<void> setAlarmSpeechPitch(double value) =>
      _prefs.setDouble(_kVoicePitch, value);

  /// Speech volume, 0.0 (silent) – 1.0 (loudest). Defaults to full.
  double get alarmSpeechVolume => _prefs.getDouble(_kVoiceVolume) ?? 1.0;

  Future<void> setAlarmSpeechVolume(double value) =>
      _prefs.setDouble(_kVoiceVolume, value);

  /// Jarvis one-shot reminders need notification ids that never collide with
  /// alarms (id*10), snooze (4 000 000+), task (1 000 000+), event
  /// (2 000 000+) or habit (3 000 000+) ids. Jarvis claims the 5 000 000+
  /// block and takes its sequence from this counter, persisted so ids stay
  /// unique across restarts.
  Future<int> nextJarvisReminderId() async {
    final seq = _prefs.getInt(_kJarvisReminderSeq) ?? 0;
    final next = seq >= 4999999 ? 0 : seq + 1;
    await _prefs.setInt(_kJarvisReminderSeq, next);
    return 5000000 + seq;
  }

  // ------------------------------------------------------ Jarvis AI model

  /// File name of the installed GGUF model inside the app-private models
  /// directory. Empty = no model installed yet.
  String get jarvisModelFile => _prefs.getString(_kJarvisModelFile) ?? '';

  Future<void> setJarvisModelFile(String value) =>
      _prefs.setString(_kJarvisModelFile, value);

  /// SHA-256 of the installed model, recorded at install time so later runs
  /// can detect silent corruption.
  String get jarvisModelSha256 => _prefs.getString(_kJarvisModelSha) ?? '';

  Future<void> setJarvisModelSha256(String value) =>
      _prefs.setString(_kJarvisModelSha, value);

  /// CPU threads for inference. Clamped to 1–8 (the practical range for the
  /// mid-range phones this app targets).
  int get jarvisModelThreads {
    final value = _prefs.getInt(_kJarvisModelThreads) ?? 4;
    return value.clamp(1, 8);
  }

  Future<void> setJarvisModelThreads(int value) =>
      _prefs.setInt(_kJarvisModelThreads, value.clamp(1, 8));

  /// Context window passed to llama.cpp (affects memory use, not file size).
  int get jarvisModelContextSize {
    final value = _prefs.getInt(_kJarvisModelContext) ?? 4096;
    return value.clamp(1024, 8192);
  }

  Future<void> setJarvisModelContextSize(int value) =>
      _prefs.setInt(_kJarvisModelContext, value.clamp(1024, 8192));

  /// Whether the morning briefing notification is armed (default on).
  bool get jarvisBriefingEnabled =>
      _prefs.getBool(_kJarvisBriefingEnabled) ?? true;

  Future<void> setJarvisBriefingEnabled(bool value) =>
      _prefs.setBool(_kJarvisBriefingEnabled, value);

  /// Notification id currently holding the briefing (0 = disarmed). Stored so
  /// re-arming always cancels the previous slot first.
  int get jarvisBriefingId => _prefs.getInt(_kJarvisBriefingId) ?? 0;

  Future<void> setJarvisBriefingId(int value) =>
      _prefs.setInt(_kJarvisBriefingId, value);
}
