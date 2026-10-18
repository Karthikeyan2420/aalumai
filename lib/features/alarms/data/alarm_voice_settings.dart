import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/app_preferences.dart';
import '../../../core/providers/providers.dart';

/// Voice gender preference for alarms.
///
/// Android does not expose a reliable gender field on every TTS voice, so
/// [any] is always offered and gender filtering is only applied when a matching
/// voice can actually be identified.
enum VoiceGender {
  any,
  female,
  male;

  static VoiceGender fromIndex(int v) =>
      VoiceGender.values[v.clamp(0, VoiceGender.values.length - 1)];
}

/// The globally configured alarm voice settings. These apply to new alarms and
/// are resolved when the alarm actually rings, so changing them never rewrites
/// the per-alarm sound/message/timing configuration.
@immutable
class AlarmVoiceSettings {
  const AlarmVoiceSettings({
    this.languageCode,
    this.voiceName,
    this.gender = VoiceGender.any,
    this.rate = defaultRate,
    this.pitch = defaultPitch,
    this.volume = defaultVolume,
  });

  static const double defaultRate = 1.0;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;

  static const double minRate = 0.5;
  static const double maxRate = 1.5;
  static const double minPitch = 0.5;
  static const double maxPitch = 2.0;

  /// Preferred TTS language code (e.g. `ta`), or `null` to follow the app
  /// language at ring time.
  final String? languageCode;

  /// The installed voice name to use, or `null`/empty for the device default.
  final String? voiceName;

  final VoiceGender gender;
  final double rate;
  final double pitch;
  final double volume;

  bool get followsAppLanguage => languageCode == null || languageCode!.isEmpty;

  bool get usesDefaultVoice => voiceName == null || voiceName!.isEmpty;

  AlarmVoiceSettings copyWith({
    Object? languageCode = _unset,
    Object? voiceName = _unset,
    VoiceGender? gender,
    double? rate,
    double? pitch,
    double? volume,
  }) {
    return AlarmVoiceSettings(
      languageCode:
          languageCode == _unset ? this.languageCode : languageCode as String?,
      voiceName: voiceName == _unset ? this.voiceName : voiceName as String?,
      gender: gender ?? this.gender,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is AlarmVoiceSettings &&
      other.languageCode == languageCode &&
      other.voiceName == voiceName &&
      other.gender == gender &&
      other.rate == rate &&
      other.pitch == pitch &&
      other.volume == volume;

  @override
  int get hashCode =>
      Object.hash(languageCode, voiceName, gender, rate, pitch, volume);
}

/// Reads the persisted [AlarmVoiceSettings] from [AppPreferences].
AlarmVoiceSettings readAlarmVoiceSettings(AppPreferences prefs) {
  return AlarmVoiceSettings(
    languageCode:
        prefs.alarmVoiceLanguage.isEmpty ? null : prefs.alarmVoiceLanguage,
    voiceName: prefs.alarmVoiceName.isEmpty ? null : prefs.alarmVoiceName,
    gender: VoiceGender.fromIndex(prefs.alarmVoiceGender),
    rate: prefs.alarmSpeechRate,
    pitch: prefs.alarmSpeechPitch,
    volume: prefs.alarmSpeechVolume,
  );
}

/// Persists [settings] to [AppPreferences].
Future<void> writeAlarmVoiceSettings(
  AppPreferences prefs,
  AlarmVoiceSettings settings,
) async {
  await prefs.setAlarmVoiceLanguage(settings.languageCode ?? '');
  await prefs.setAlarmVoiceName(settings.voiceName ?? '');
  await prefs.setAlarmVoiceGender(settings.gender.index);
  await prefs.setAlarmSpeechRate(settings.rate);
  await prefs.setAlarmSpeechPitch(settings.pitch);
  await prefs.setAlarmSpeechVolume(settings.volume);
}

/// Notifier exposing the current global alarm voice settings with mutation
/// methods that persist immediately. Degrades gracefully when preferences are
/// unavailable (e.g. a widget test without an override) by returning defaults.
class AlarmVoiceSettingsController extends Notifier<AlarmVoiceSettings> {
  @override
  AlarmVoiceSettings build() {
    try {
      return readAlarmVoiceSettings(ref.watch(appPreferencesProvider));
    } catch (_) {
      return const AlarmVoiceSettings();
    }
  }

  Future<void> _apply(AlarmVoiceSettings next) async {
    state = next;
    try {
      await writeAlarmVoiceSettings(ref.read(appPreferencesProvider), next);
    } catch (_) {
      // Preferences unavailable: keep the in-memory value for this session.
    }
  }

  Future<void> setLanguageCode(String? code) =>
      _apply(state.copyWith(languageCode: code));

  Future<void> setVoiceName(String? name) =>
      _apply(state.copyWith(voiceName: name));

  Future<void> setGender(VoiceGender gender) =>
      _apply(state.copyWith(gender: gender));

  Future<void> setRate(double rate) => _apply(
    state.copyWith(
      rate: rate.clamp(AlarmVoiceSettings.minRate, AlarmVoiceSettings.maxRate),
    ),
  );

  Future<void> setPitch(double pitch) => _apply(
    state.copyWith(
      pitch: pitch.clamp(
        AlarmVoiceSettings.minPitch,
        AlarmVoiceSettings.maxPitch,
      ),
    ),
  );

  Future<void> setVolume(double volume) =>
      _apply(state.copyWith(volume: volume.clamp(0.0, 1.0)));

  Future<void> resetRate() =>
      _apply(state.copyWith(rate: AlarmVoiceSettings.defaultRate));

  Future<void> resetPitch() =>
      _apply(state.copyWith(pitch: AlarmVoiceSettings.defaultPitch));

  Future<void> resetVolume() =>
      _apply(state.copyWith(volume: AlarmVoiceSettings.defaultVolume));
}

final alarmVoiceSettingsProvider =
    NotifierProvider<AlarmVoiceSettingsController, AlarmVoiceSettings>(
      AlarmVoiceSettingsController.new,
    );
