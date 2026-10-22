import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'wake_word.dart';

/// Voice input for the assistant: on-demand dictation plus optional
/// "Hey Jarvis" wake-word detection.
///
/// Wake-word detection is implemented by running continuous recognition and
/// scanning each partial transcript with [WakeWordDetector]. This is honest
/// about its limits: continuous listening drains battery and Android may
/// suspend it, so it is off by default and only active while this object's
/// listening loop runs.
class VoiceService {
  VoiceService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final WakeWordDetector _wakeWord = WakeWordDetector();

  bool _available = false;
  bool _listening = false;
  bool _wakeMode = false;

  final _transcript = StreamController<String>.broadcast();
  final _wake = StreamController<void>.broadcast();
  final _state = StreamController<bool>.broadcast();

  /// Partial/final transcripts (final ones emit once and reset).
  Stream<String> get transcripts => _transcript.stream;

  /// Fires when the wake word is heard while in wake mode.
  Stream<void> get wakeEvents => _wake.stream;

  /// Emits true when listening starts, false when it stops.
  Stream<bool> get listeningState => _state.stream;

  bool get isListening => _listening;
  bool get isAvailable => _available;

  /// Requests permissions and initialises the recogniser. Returns whether
  /// speech input is usable on this device.
  Future<bool> initialize() async {
    try {
      _available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _available = false;
    }
    return _available;
  }

  /// Starts dictation. Emits transcripts on [transcripts]; call [stop] to end.
  Future<bool> listen({String? localeId}) async {
    if (!_available && !await initialize()) return false;
    if (_listening && !_wakeMode) return true;
    _wakeMode = false;
    return _start(localeId: localeId);
  }

  /// Starts wake-word monitoring. Emits on [wakeEvents] when "Hey Jarvis"
  /// is heard, and keeps listening.
  Future<bool> listenForWakeWord({String? localeId}) async {
    if (!_available && !await initialize()) return false;
    _wakeMode = true;
    return _start(localeId: localeId);
  }

  Future<bool> _start({String? localeId}) async {
    try {
      _listening = true;
      _state.add(true);
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: _wakeMode
              ? ListenMode.dictation
              : ListenMode.confirmation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Speech listen failed: $e');
      _listening = false;
      _state.add(false);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Speech stop failed: $e');
    }
    if (_listening) {
      _listening = false;
      _state.add(false);
    }
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    if (_listening) {
      _listening = false;
      _state.add(false);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    if (_wakeMode) {
      if (_wakeWord.containsWakeWord(text)) {
        _wake.add(null);
      }
      return;
    }
    _transcript.add(text);
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg}');
    if (_wakeMode) {
      // Restart the wake loop after transient errors.
      _restartWake();
    }
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_wakeMode && _listening) {
        _restartWake();
      } else if (_listening) {
        _listening = false;
        _state.add(false);
      }
    }
  }

  void _restartWake() {
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      if (!_wakeMode) return;
      try {
        await _speech.listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            listenFor: const Duration(minutes: 1),
            pauseFor: const Duration(seconds: 4),
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.dictation,
          ),
        );
      } catch (e) {
        debugPrint('Wake restart failed: $e');
      }
    });
  }

  void dispose() {
    _wakeMode = false;
    _speech.cancel();
    _transcript.close();
    _wake.close();
    _state.close();
  }
}
