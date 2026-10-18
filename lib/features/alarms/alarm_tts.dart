import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'data/alarm_voice_settings.dart';

/// A single voice reported by the installed Android TTS engine.
@immutable
class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.gender = VoiceGender.any,
    this.quality,
  });

  /// Engine voice name (used when selecting the voice back on the platform).
  final String name;

  /// BCP-47-ish locale such as `en-US`, `ta-IN`.
  final String locale;

  /// Best-effort gender, or [VoiceGender.any] when the engine does not say.
  final VoiceGender gender;

  /// Optional engine quality value (iOS reports it); unused on Android.
  final int? quality;

  /// Lower-case primary language subtag, e.g. `en` for `en-GB`.
  String get languageCode {
    final normalised = locale.replaceAll('_', '-');
    final dash = normalised.indexOf('-');
    return (dash == -1 ? normalised : normalised.substring(0, dash))
        .toLowerCase();
  }

  Map<String, String> toPlatformVoice() => {'name': name, 'locale': locale};

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() => 'TtsVoice($name, $locale, ${gender.name})';
}

/// Chooses a voice from the installed set. Pure so the selection rules are
/// unit-testable without a TTS engine.
class AlarmVoiceResolver {
  const AlarmVoiceResolver._();

  /// Infers a gender from a voice's name where the engine hints at one
  /// (e.g. Google voices ending in `#female_1-local`). Returns [VoiceGender.any]
  /// when there is no reliable hint rather than guessing.
  static VoiceGender inferGender(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('female')) return VoiceGender.female;
    if (lower.contains('male')) return VoiceGender.male;
    return VoiceGender.any;
  }

  /// Picks the best voice for [languageCode], honouring an explicit
  /// [preferredName] and a [gender] preference. Returns `null` when no voice
  /// for the language is installed (the caller then falls back to the engine's
  /// default voice for that language, if it supports it at all).
  static TtsVoice? choose(
    List<TtsVoice> voices, {
    required String languageCode,
    VoiceGender gender = VoiceGender.any,
    String? preferredName,
  }) {
    final forLanguage =
        voices.where((v) => v.languageCode == languageCode).toList();
    if (forLanguage.isEmpty) return null;

    if (preferredName != null && preferredName.isNotEmpty) {
      for (final v in forLanguage) {
        if (v.name == preferredName) return v;
      }
    }

    if (gender != VoiceGender.any) {
      for (final v in forLanguage) {
        if (v.gender == gender) return v;
      }
    }
    return forLanguage.first;
  }

  /// Resolves [requested] (a bare language code like `ta`) to the concrete
  /// locale an installed voice uses (`ta-IN`), so the engine can select it.
  /// Falls back to [requested] unchanged when nothing matches.
  static String resolveLanguage(List<TtsVoice> voices, String requested) {
    final code = requested.toLowerCase();
    for (final v in voices) {
      if (v.locale.toLowerCase() == code) return v.locale;
    }
    for (final v in voices) {
      if (v.languageCode == code) return v.locale;
    }
    return requested;
  }
}

/// Backend for alarm text-to-speech. Abstracted so the playback coordinator can
/// be unit-tested with a fake instead of the platform engine.
abstract class AlarmTts {
  /// Whether the device can speak [languageCode] at all.
  Future<bool> isLanguageAvailable(String languageCode);

  /// Every installed voice, across all languages.
  Future<List<TtsVoice>> voices();

  /// Applies [settings] for [languageCode] (already resolved to a concrete code,
  /// never empty). Selects an installed voice when one matches, otherwise lets
  /// the engine use its default voice for the language.
  Future<void> configure(AlarmVoiceSettings settings, String languageCode);

  /// Speaks [text], completing when the utterance finishes (or is stopped).
  Future<void> speak(String text);

  Future<void> stop();

  Future<void> dispose();
}

/// The real backend, built on `flutter_tts`.
class FlutterTtsAlarmTts implements AlarmTts {
  FlutterTtsAlarmTts([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _awaitedCompletion = false;
  List<TtsVoice>? _cachedVoices;

  Future<void> _ensureCompletionMode() async {
    if (_awaitedCompletion) return;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Best-effort; without it speak() resolves immediately and the
      // scheduler simply moves on.
    }
    _awaitedCompletion = true;
  }

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    try {
      final result = await _tts.isLanguageAvailable(languageCode);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TtsVoice>> voices() async {
    if (_cachedVoices != null) return _cachedVoices!;
    try {
      final raw = await _tts.getVoices;
      final result = <TtsVoice>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            final locale = (item['locale'] ?? '').toString();
            if (name.isEmpty) continue;
            final genderRaw = (item['gender'] ?? '').toString().toLowerCase();
            final gender =
                genderRaw == 'female'
                    ? VoiceGender.female
                    : genderRaw == 'male'
                    ? VoiceGender.male
                    : AlarmVoiceResolver.inferGender(name);
            final qualityRaw = item['quality'];
            result.add(
              TtsVoice(
                name: name,
                locale: locale.isEmpty ? name : locale,
                gender: gender,
                quality: qualityRaw is int ? qualityRaw : null,
              ),
            );
          }
        }
      }
      _cachedVoices = result;
      return result;
    } catch (_) {
      _cachedVoices = const [];
      return _cachedVoices!;
    }
  }

  @override
  Future<void> configure(
    AlarmVoiceSettings settings,
    String languageCode,
  ) async {
    await _ensureCompletionMode();
    try {
      await _tts.setLanguage(languageCode);
    } catch (_) {}
    try {
      final all = await voices();
      final voice = AlarmVoiceResolver.choose(
        all,
        languageCode: languageCode,
        gender: settings.gender,
        preferredName: settings.voiceName,
      );
      if (voice != null) {
        await _tts.setVoice(voice.toPlatformVoice());
      }
    } catch (_) {}
    try {
      await _tts.setSpeechRate(settings.rate);
    } catch (_) {}
    try {
      await _tts.setPitch(settings.pitch);
    } catch (_) {}
    try {
      await _tts.setVolume(settings.volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureCompletionMode();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// A shared TTS backend for UI previews (the ringing alarm creates its own via
/// [AlarmAudio] so an active ring is never interrupted by a settings preview).
final alarmTtsProvider = Provider<AlarmTts>((ref) {
  final tts = FlutterTtsAlarmTts();
  ref.onDispose(tts.dispose);
  return tts;
});
