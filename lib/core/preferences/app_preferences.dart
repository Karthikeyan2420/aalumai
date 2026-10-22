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
  static const _kJarvisBriefingEnabled = 'jarvis_briefing_enabled';
  static const _kJarvisBriefingId = 'jarvis_briefing_id';
  static const _kRecentQuickActions = 'recent_quick_actions';
  static const _kDashboardHidden = 'dashboard_hidden';

  // Jarvis assistant voice preferences (shared by chat & wake-word flow).
  static const _kAssistantSpeechEnabled = 'assistant_speech_enabled';
  static const _kAssistantWakeWordEnabled = 'assistant_wake_word_enabled';
  static const _kAssistantBackgroundListening =
      'assistant_background_listening';
  static const _kAssistantOnlineSearchEnabled =
      'assistant_online_search_enabled';
  static const _kAssistantSpeechRate = 'assistant_speech_rate';
  static const _kAssistantSpeechPitch = 'assistant_speech_pitch';
  static const _kAssistantSpeechVolume = 'assistant_speech_volume';
  static const _kAssistantVoiceName = 'assistant_voice_name';
  static const _kAssistantSpeechLanguage = 'assistant_speech_language';
  static const _kAssistantUserName = 'assistant_user_name';

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

  // ------------------------------------------------------ Jarvis assistant

  /// Whether the assistant speaks its replies aloud.
  bool get assistantSpeechEnabled =>
      _prefs.getBool(_kAssistantSpeechEnabled) ?? true;

  Future<void> setAssistantSpeechEnabled(bool value) =>
      _prefs.setBool(_kAssistantSpeechEnabled, value);

  /// Whether "Hey Jarvis" wake-word detection is enabled.
  bool get assistantWakeWordEnabled =>
      _prefs.getBool(_kAssistantWakeWordEnabled) ?? false;

  Future<void> setAssistantWakeWordEnabled(bool value) =>
      _prefs.setBool(_kAssistantWakeWordEnabled, value);

  /// Whether the assistant keeps listening in the background. Only honoured
  /// when a foreground service is running; Android restrictions may still
  /// suspend it.
  bool get assistantBackgroundListening =>
      _prefs.getBool(_kAssistantBackgroundListening) ?? false;

  Future<void> setAssistantBackgroundListening(bool value) =>
      _prefs.setBool(_kAssistantBackgroundListening, value);

  /// Whether questions not covered locally may be answered with online
  /// research (Wikipedia, weather, etc.).
  bool get assistantOnlineSearchEnabled =>
      _prefs.getBool(_kAssistantOnlineSearchEnabled) ?? true;

  Future<void> setAssistantOnlineSearchEnabled(bool value) =>
      _prefs.setBool(_kAssistantOnlineSearchEnabled, value);

  double get assistantSpeechRate =>
      _prefs.getDouble(_kAssistantSpeechRate) ?? 1.0;

  Future<void> setAssistantSpeechRate(double value) =>
      _prefs.setDouble(_kAssistantSpeechRate, value);

  double get assistantSpeechPitch =>
      _prefs.getDouble(_kAssistantSpeechPitch) ?? 1.0;

  Future<void> setAssistantSpeechPitch(double value) =>
      _prefs.setDouble(_kAssistantSpeechPitch, value);

  /// Speech volume, 0.0 (silent) – 1.0 (loudest). Defaults to full.
  double get assistantSpeechVolume =>
      _prefs.getDouble(_kAssistantSpeechVolume) ?? 1.0;

  Future<void> setAssistantSpeechVolume(double value) =>
      _prefs.setDouble(_kAssistantSpeechVolume, value);

  /// Installed TTS voice name to use, or empty for the device default.
  String get assistantVoiceName =>
      _prefs.getString(_kAssistantVoiceName) ?? '';

  Future<void> setAssistantVoiceName(String value) =>
      _prefs.setString(_kAssistantVoiceName, value);

  /// BCP-47 language tag for assistant speech, or empty to follow the app.
  String get assistantSpeechLanguage =>
      _prefs.getString(_kAssistantSpeechLanguage) ?? '';

  Future<void> setAssistantSpeechLanguage(String value) =>
      _prefs.setString(_kAssistantSpeechLanguage, value);

  /// The user's preferred name, used to answer "who am I?"; empty when the
  /// user has not configured one.
  String get assistantUserName =>
      _prefs.getString(_kAssistantUserName) ?? '';

  Future<void> setAssistantUserName(String value) =>
      _prefs.setString(_kAssistantUserName, value);

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
