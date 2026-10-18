import 'package:flutter/foundation.dart';

import 'data/alarm_voice_settings.dart';

/// How an alarm produces sound while ringing.
enum AlarmSoundMode {
  /// Music/tone plus a spoken motivational message.
  musicAndVoice,

  /// The spoken message only.
  voiceOnly,

  /// The music/tone only (the behaviour of alarms created before this feature).
  musicOnly;

  /// New alarms default to the richest experience.
  static const AlarmSoundMode fallback = musicAndVoice;

  /// Applied to alarms migrated from an earlier schema: they keep their
  /// existing music-only behaviour.
  static const AlarmSoundMode legacy = musicOnly;

  static AlarmSoundMode fromIndex(int v) =>
      AlarmSoundMode.values[v.clamp(0, AlarmSoundMode.values.length - 1)];
}

/// When the spoken message plays relative to the music segments.
enum VoiceTiming {
  beforeMusic,
  betweenSegments,
  overMusic;

  static const VoiceTiming fallback = betweenSegments;

  static VoiceTiming fromIndex(int v) =>
      VoiceTiming.values[v.clamp(0, VoiceTiming.values.length - 1)];
}

/// The selectable preset music intervals, in seconds.
const List<int> kMusicIntervalPresets = [5, 10, 15, 30];

/// Default number of seconds between music and the next spoken message.
const int kDefaultMusicIntervalSec = 10;

/// Default pause between spoken repetitions in voice-only mode.
const int kDefaultVoicePauseSec = 5;

/// Everything the playback coordinator needs to ring an alarm. Built from an
/// `Alarm` row plus the current global voice settings, so the alarm editor only
/// ever stores per-alarm values.
@immutable
class AlarmPlaybackConfig {
  const AlarmPlaybackConfig({
    required this.mode,
    required this.soundId,
    this.message = '',
    this.musicIntervalSec = kDefaultMusicIntervalSec,
    this.voicePauseSec = kDefaultVoicePauseSec,
    this.voiceTiming = VoiceTiming.betweenSegments,
    this.volumePercent = 100,
    this.vibrate = true,
    this.voice = const AlarmVoiceSettings(),
    this.languageCode = 'en',
  });

  final AlarmSoundMode mode;

  /// Resolved music/tone selection (bundled id, `system`, or a `file:` uri).
  final String soundId;

  final String message;
  final int musicIntervalSec;
  final int voicePauseSec;
  final VoiceTiming voiceTiming;

  /// Music playback volume 0–100.
  final int volumePercent;

  final bool vibrate;

  /// Global voice preferences applied to the TTS engine.
  final AlarmVoiceSettings voice;

  /// The concrete TTS language code to speak in (never empty). When the global
  /// setting follows the app language this is resolved from the active locale.
  final String languageCode;

  /// Music is played unless the effective mode is voice-only. A voice-only
  /// alarm with an empty message falls back to music so the alarm is never
  /// silent.
  AlarmSoundMode get effectiveMode =>
      mode == AlarmSoundMode.voiceOnly && message.trim().isEmpty
          ? AlarmSoundMode.musicOnly
          : mode;

  bool get playsMusic => effectiveMode != AlarmSoundMode.voiceOnly;

  bool get speaks =>
      effectiveMode != AlarmSoundMode.musicOnly && message.trim().isNotEmpty;

  int get safeMusicIntervalSec => musicIntervalSec.clamp(1, 3600);

  int get safeVoicePauseSec => voicePauseSec.clamp(1, 3600);

  AlarmPlaybackConfig copyWith({
    AlarmSoundMode? mode,
    String? soundId,
    String? message,
    int? musicIntervalSec,
    int? voicePauseSec,
    VoiceTiming? voiceTiming,
    int? volumePercent,
    bool? vibrate,
    AlarmVoiceSettings? voice,
    String? languageCode,
  }) {
    return AlarmPlaybackConfig(
      mode: mode ?? this.mode,
      soundId: soundId ?? this.soundId,
      message: message ?? this.message,
      musicIntervalSec: musicIntervalSec ?? this.musicIntervalSec,
      voicePauseSec: voicePauseSec ?? this.voicePauseSec,
      voiceTiming: voiceTiming ?? this.voiceTiming,
      volumePercent: volumePercent ?? this.volumePercent,
      vibrate: vibrate ?? this.vibrate,
      voice: voice ?? this.voice,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
