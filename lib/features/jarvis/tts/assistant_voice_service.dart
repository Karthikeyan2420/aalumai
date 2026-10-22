import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for the assistant, honouring the user's voice preferences
/// (enabled, language, voice, rate, pitch, volume).
///
/// Wraps [FlutterTts] so screens and tests do not touch the plugin directly.
/// Every call is defensive: a TTS failure must never break the chat.
class AssistantVoiceService {
  AssistantVoiceService({required this.prefs, FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  final AppPreferences prefs;
  final FlutterTts _tts;

  bool _configured = false;
  bool _speaking = false;

  /// Whether the assistant is currently talking.
  bool get isSpeaking => _speaking;

  /// Languages/voices reported by the platform (for the settings screen).
  Future<List<String>> availableLanguages() async {
    try {
      final result = await _tts.getLanguages;
      if (result is List) return result.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('TTS getLanguages failed: $e');
    }
    return const [];
  }

  Future<List<Map<String, String>>> availableVoices() async {
    try {
      final result = await _tts.getVoices;
      if (result is List) {
        return [
          for (final voice in result)
            if (voice is Map)
              {for (final e in voice.entries) '${e.key}': '${e.value}'},
        ];
      }
    } catch (e) {
      debugPrint('TTS getVoices failed: $e');
    }
    return const [];
  }

  /// Speaks [text] if speech is enabled. Returns whether it spoke.
  Future<bool> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !prefs.assistantSpeechEnabled) return false;
    try {
      await _configure();
      await _tts.stop();
      await _tts.speak(trimmed);
      _speaking = true;
      return true;
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
    _speaking = false;
  }

  /// Re-applies preferences after the user changes them in settings.
  Future<void> refreshSettings() async {
    _configured = false;
    await _configure();
  }

  /// Speaks a short sample so the user can preview their settings.
  Future<void> preview() async {
    final wasEnabled = prefs.assistantSpeechEnabled;
    if (!wasEnabled) {
      // Preview should work even while speech is off.
      try {
        await _configure();
        await _tts.speak('This is how I will sound.');
      } catch (e) {
        debugPrint('TTS preview failed: $e');
      }
      return;
    }
    await speak('This is how I will sound.');
  }

  Future<void> _configure() async {
    if (_configured) return;
    final language = prefs.assistantSpeechLanguage.trim();
    if (language.isNotEmpty) {
      try {
        await _tts.setLanguage(language);
      } catch (_) {
        // Language may be unavailable; keep the platform default.
      }
    }
    final voice = prefs.assistantVoiceName.trim();
    if (voice.isNotEmpty) {
      try {
        await _tts.setVoice({'name': voice});
      } catch (_) {}
    }
    try {
      await _tts.setSpeechRate(prefs.assistantSpeechRate);
      await _tts.setPitch(prefs.assistantSpeechPitch);
      await _tts.setVolume(prefs.assistantSpeechVolume);
    } catch (e) {
      debugPrint('TTS config failed: $e');
    }
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
    _configured = true;
  }
}
