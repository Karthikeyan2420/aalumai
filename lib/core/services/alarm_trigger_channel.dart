import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One armed schedule slot of an alarm, described exactly as the native
/// trigger pipeline needs it.
///
/// The payload deliberately mirrors `AlarmPlaybackConfig` *after* its
/// effective-mode fallbacks, so the ring a user hears is the same whether the
/// Flutter engine is alive when the alarm fires or not.
@immutable
class AlarmTriggerSlot {
  const AlarmTriggerSlot({
    required this.slotId,
    required this.alarmId,
    required this.triggerAtMs,
    required this.soundUri,
    required this.volume,
    required this.vibrate,
    required this.mode,
    required this.message,
    required this.musicIntervalSec,
    required this.voicePauseSec,
    required this.voiceTiming,
    required this.languageCode,
    required this.voiceName,
    required this.speechRate,
    required this.speechPitch,
    required this.speechVolume,
    required this.label,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.weekday,
  });

  /// Stable notification/slot id (`AlarmPlanner.slotId`).
  final int slotId;

  final int alarmId;

  /// Absolute local trigger time in epoch milliseconds.
  final int triggerAtMs;

  /// Persisted `Alarms.soundUri`: a bundled id, `system`, or `file:/path`.
  final String soundUri;

  /// Music volume, 0–100.
  final int volume;

  final bool vibrate;

  /// `musicAndVoice`, `voiceOnly` or `musicOnly` (`AlarmSoundMode.name`).
  final String mode;

  final String message;

  final int musicIntervalSec;
  final int voicePauseSec;

  /// `beforeMusic`, `betweenSegments` or `overMusic` (`VoiceTiming.name`).
  final String voiceTiming;

  /// Concrete TTS language code; empty lets the platform fall back to the
  /// device locale (used when the voice follows the app language).
  final String languageCode;

  final String voiceName;
  final double speechRate;
  final double speechPitch;
  final double speechVolume;

  final String label;
  final int hour;
  final int minute;

  /// `once`, `daily` or `weekly`; only used to re-arm the slot after it fires.
  final String repeat;

  /// ISO weekday 1 = Monday … 7 = Sunday, for [repeat] == `weekly`.
  final int weekday;

  Map<String, Object?> toJson() => <String, Object?>{
    'slotId': slotId,
    'alarmId': alarmId,
    'triggerAtMs': triggerAtMs,
    'soundUri': soundUri,
    'volume': volume,
    'vibrate': vibrate,
    'mode': mode,
    'message': message,
    'musicIntervalSec': musicIntervalSec,
    'voicePauseSec': voicePauseSec,
    'voiceTiming': voiceTiming,
    'languageCode': languageCode,
    'voiceName': voiceName,
    'speechRate': speechRate,
    'speechPitch': speechPitch,
    'speechVolume': speechVolume,
    'label': label,
    'hour': hour,
    'minute': minute,
    'repeat': repeat,
    'weekday': weekday,
  };

  @override
  bool operator ==(Object other) =>
      other is AlarmTriggerSlot &&
      other.slotId == slotId &&
      other.alarmId == alarmId &&
      other.triggerAtMs == triggerAtMs;

  @override
  int get hashCode => Object.hash(slotId, alarmId, triggerAtMs);
}

/// Global voice preferences needed to build a native trigger payload.
///
/// Deliberately expressed as primitives rather than `AlarmVoiceSettings` so the
/// payload can be assembled from `core` without a layering inversion.
@immutable
class NativeVoiceSettings {
  const NativeVoiceSettings({
    this.languageCode = '',
    this.voiceName = '',
    this.rate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  /// Concrete TTS language code. Empty lets the platform use the device locale,
  /// which is what "follow app language" means when the app itself follows the
  /// system language.
  final String languageCode;

  final String voiceName;
  final double rate;
  final double pitch;

  /// Speech volume, 0–1. Also scales the music ducking while speaking.
  final double volume;
}

/// Result of asking the native ring service whether it is currently ringing.
@immutable
class AlarmRingState {
  const AlarmRingState({required this.ringing, required this.alarmId});

  final bool ringing;
  final int alarmId;

  /// Whether the native service is ringing for [alarmId].
  bool isFor(int alarmId) => ringing && this.alarmId == alarmId;

  static const AlarmRingState idle = AlarmRingState(
    ringing: false,
    alarmId: -1,
  );
}

/// Bridge to the native exact-alarm trigger pipeline (`AlarmTriggerPlugin`).
///
/// Every call is best-effort: on a platform without the plugin — or if the
/// channel is unavailable — the app silently keeps its existing behaviour,
/// where the ringing screen plays the alarm itself once the notification is
/// opened. Nothing here can fail a schedule, so alarms are never lost.
class AlarmTriggerChannel {
  const AlarmTriggerChannel._();

  static const MethodChannel _channel = MethodChannel('aalumai/alarm_trigger');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static bool _listening = false;

  /// Called when the native ring service starts for an alarm while the Flutter
  /// engine is alive. Android suppresses a full-screen intent while the device
  /// is unlocked, so this is the in-app path for that case: the ringing screen
  /// is shown without waiting for the user to tap the notification.
  static void Function(int alarmId)? onRingStarted;

  /// Called when the user taps the active-alarm notification (or its full-screen
  /// intent) and the app is already running.
  static void Function(int alarmId)? onOpenAlarm;

  /// Starts forwarding native alarm events to [onRingStarted] / [onOpenAlarm].
  /// Idempotent; safe to call more than once.
  static void ensureListening() {
    if (_listening || !_supported) return;
    _listening = true;
    _channel.setMethodCallHandler(_handle);
  }

  static Future<void> _handle(MethodCall call) async {
    final alarmId = (call.arguments as num?)?.toInt();
    debugPrint('ALARMDBG channel ${call.method} args=${call.arguments}');
    if (alarmId == null || alarmId < 0) return;
    switch (call.method) {
      case 'ringStarted':
        onRingStarted?.call(alarmId);
      case 'openAlarm':
        onOpenAlarm?.call(alarmId);
    }
  }

  /// Consumes an alarm id carried by a cold-start launch intent (the user
  /// tapped the alarm notification while the app was not running), or `null`.
  static Future<int?> takePendingOpenAlarm() async {
    if (!_supported) return null;
    try {
      final pending = await _channel.invokeMethod<int>('takePendingOpenAlarm');
      debugPrint('ALARMDBG takePendingOpenAlarm -> $pending');
      return pending;
    } catch (e) {
      debugPrint('Native pending alarm read failed: $e');
      return null;
    }
  }

  /// Mirrors [slots] into `AlarmManager`, dropping any previously armed slot of
  /// the same alarm that is no longer part of the plan.
  static Future<void> syncAlarm(
    int alarmId,
    List<AlarmTriggerSlot> slots,
  ) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('syncAlarm', <String, Object?>{
        'alarmId': alarmId,
        'payloadsJson': jsonEncode([for (final s in slots) s.toJson()]),
      });
    } catch (e) {
      debugPrint('Native alarm trigger sync failed: $e');
    }
  }

  /// Cancels every armed slot belonging to [alarmId].
  static Future<void> cancelAlarm(int alarmId) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('cancelAlarm', <String, Object?>{
        'alarmId': alarmId,
      });
    } catch (e) {
      debugPrint('Native alarm trigger cancel failed: $e');
    }
  }

  /// Stops native TTS while the ring service keeps playing music. Used when the
  /// ringing screen takes over speech on the Flutter main isolate.
  static Future<void> delegateSpeechToFlutter() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('delegateSpeechToFlutter');
    } catch (e) {
      debugPrint('Native speech handoff failed: $e');
    }
  }

  /// Asks the ring service to stop. Safe to call when it is not running.
  static Future<void> stopRing() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      debugPrint('Native alarm ring stop failed: $e');
    }
  }

  /// Whether the native service is ringing right now, and for which alarm.
  static Future<AlarmRingState> ringState() async {
    if (!_supported) return AlarmRingState.idle;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('isRinging');
      return AlarmRingState(
        ringing: raw?['ringing'] == true,
        alarmId: (raw?['alarmId'] as num?)?.toInt() ?? -1,
      );
    } catch (_) {
      return AlarmRingState.idle;
    }
  }
}
