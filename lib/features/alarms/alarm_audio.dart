import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'alarm_playback.dart';
import 'alarm_tts.dart';

/// A selectable, bundled alarm tone. [id] is what gets persisted in
/// `Alarms.soundUri` for the built-in tones.
class AlarmSound {
  const AlarmSound(this.id, this.asset);

  final String id;
  final String asset;

  String get labelKey => 'alarmSound_$id';
}

/// A resolved audio target for the ringing player: either a bundled asset or a
/// user-imported file on disk. Kept plugin-free so resolution is unit-testable.
@immutable
class AlarmTone {
  const AlarmTone.asset(String this.assetPath) : filePath = null;
  const AlarmTone.file(String this.filePath) : assetPath = null;

  /// Bundled asset key, or `null` for a file tone.
  final String? assetPath;

  /// Absolute local file path, or `null` for an asset tone.
  final String? filePath;

  bool get isFile => filePath != null;

  String get uri => filePath ?? assetPath ?? '';

  @override
  bool operator ==(Object other) =>
      other is AlarmTone &&
      other.assetPath == assetPath &&
      other.filePath == filePath;

  @override
  int get hashCode => Object.hash(assetPath, filePath);

  @override
  String toString() =>
      isFile ? 'AlarmTone.file($filePath)' : 'AlarmTone.asset($assetPath)';
}

/// The bundled, original alarm tones plus lookup/fallback rules.
class AlarmSounds {
  const AlarmSounds._();

  /// Prefix marking a persisted `soundUri` as a user-imported local file.
  static const String filePrefix = 'file:';

  /// Used when an alarm has no sound set, or references an unknown/missing one.
  static const defaultId = 'classic';

  static const options = <AlarmSound>[
    AlarmSound('classic', 'assets/audio/alarm_classic.wav'),
    AlarmSound('gentle', 'assets/audio/alarm_gentle.wav'),
    AlarmSound('urgent', 'assets/audio/alarm_urgent.wav'),
  ];

  static const _byId = {
    'classic': 'assets/audio/alarm_classic.wav',
    'gentle': 'assets/audio/alarm_gentle.wav',
    'urgent': 'assets/audio/alarm_urgent.wav',
  };

  /// Resolves [id] to a bundled asset, falling back to the default tone so a
  /// missing custom sound never leaves an alarm silent.
  static String assetFor(String id) => _byId[id] ?? _byId[defaultId]!;

  static AlarmSound? byId(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Whether [soundId] refers to a user-imported file rather than a bundled
  /// tone (or the system default).
  static bool isCustom(String soundId) => soundId.startsWith(filePrefix);

  /// The local file path for a custom [soundId], or `null` when it is a bundled
  /// tone.
  static String? customPath(String soundId) =>
      isCustom(soundId) ? soundId.substring(filePrefix.length) : null;

  /// Builds the persisted `soundUri` for an imported [path].
  static String customUri(String path) => '$filePrefix$path';

  /// Resolves a persisted `soundUri` to a playable [AlarmTone].
  ///
  /// Custom files are used when present; a missing or empty custom file falls
  /// back to the default bundled tone so the alarm is never silent. Unknown or
  /// `system` ids resolve to the default bundled tone too — the app always
  /// plays a looping tone itself, it never relies on the notification sound.
  static AlarmTone resolveTone(String soundUri) {
    final path = customPath(soundUri);
    if (path != null) {
      if (path.isNotEmpty && File(path).existsSync()) {
        return AlarmTone.file(path);
      }
      return AlarmTone.asset(assetFor(defaultId));
    }
    return AlarmTone.asset(assetFor(soundUri));
  }
}

/// The playback backend used by [AlarmAudio]. Abstracted so the start/stop
/// lifecycle can be unit-tested with a fake instead of `just_audio`/hardware.
abstract class AlarmAudioPlayer {
  /// Whether audio is currently playing. Used to re-assert the ring after an
  /// interruption or lifecycle transition.
  bool get isPlaying;

  Future<void> play(AlarmTone tone, double volume, {required bool loop});
  Future<void> stop();
  Future<void> dispose();
}

/// The real backend: a single, long-lived `just_audio` player, configured for
/// the Android **alarm** audio stream so the ring is audible at alarm volume
/// (not the media stream), independent of the music player.
class JustAudioAlarmPlayer implements AlarmAudioPlayer {
  AudioPlayer? _player;
  bool _sessionConfigured = false;
  AlarmTone? _currentTone;
  double _currentVolume = 1;
  bool _loop = true;

  /// Configures the shared audio session for alarm playback. Best-effort: if
  /// `audio_session` is unavailable the player falls back to just_audio's
  /// defaults and still loops.
  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.alarm,
            flags: AndroidAudioFlags.none,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: false,
        ),
      );
      _sessionConfigured = true;
    } catch (e) {
      debugPrint('Alarm audio session unavailable: $e');
    }
  }

  @override
  bool get isPlaying => _player?.playing ?? false;

  AudioSource _sourceFor(AlarmTone tone) =>
      tone.isFile
          ? AudioSource.file(tone.filePath!)
          : AudioSource.asset(tone.assetPath!);

  @override
  Future<void> play(AlarmTone tone, double volume, {required bool loop}) async {
    final player = _player ??= AudioPlayer();
    final vol = volume.clamp(0.0, 1.0).toDouble();
    // Re-asserting the same tone (lifecycle resume / watchdog) must not restart
    // the loop and glitch the audio — only adjust the volume if needed.
    if (_currentTone == tone && _loop == loop && player.playing) {
      if ((player.volume - vol).abs() > 0.001) await player.setVolume(vol);
      return;
    }
    await _ensureSession();
    await player.setAudioSource(_sourceFor(tone));
    await player.setVolume(vol);
    _loop = loop;
    _currentTone = tone;
    _currentVolume = vol;
    await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    // Deliberately not awaited: with LoopMode.one the play() future only
    // completes when playback finishes, which for a looping ring is never.
    unawaited(player.play());
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    _currentTone = null;
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _currentTone = null;
  }

  bool get isLooping => _loop;

  double get volume => _currentVolume;
}

/// The playback coordinator for a ringing alarm.
///
/// It owns the music backend ([AlarmAudioPlayer]), the optional speech backend
/// ([AlarmTts]) and the vibration pattern. It rings according to an
/// [AlarmPlaybackConfig]:
///
/// * **music only** — loops the selected tone;
/// * **voice only** — repeats the spoken message with a configurable pause;
/// * **music + voice** — loops the music and speaks the message according to
///   [VoiceTiming], ducking the music while speaking.
///
/// A lightweight watchdog re-asserts playback if the platform stops it (audio
/// focus loss, lifecycle transitions), so the ring cannot silently degrade into
/// vibration-only after a moment. Audio, speech and vibration are only stopped
/// by an explicit [stop] — the ringing screen calls it once every challenge has
/// been passed.
class AlarmAudio {
  AlarmAudio({AlarmAudioPlayer? player, AlarmTts? tts})
    : _player = player ?? JustAudioAlarmPlayer(),
      _tts = tts;

  final AlarmAudioPlayer _player;
  final AlarmTts? _tts;
  Timer? _vibrateTimer;
  Timer? _watchdog;
  Timer? _sleepTimer;
  Completer<void>? _sleepCompleter;

  bool _ringing = false;
  bool _loopActive = false;
  AlarmTone? _tone;
  double _volume = 1;
  AlarmPlaybackConfig? _config;

  bool get isRinging => _ringing;

  /// How often the ring is re-asserted if the platform stopped playback.
  static const Duration watchdogInterval = Duration(seconds: 1);

  /// Volume multiplier applied to music while a spoken message plays over it.
  static const double _duckFactor = 0.35;

  /// Starts a looping ring for [soundId] at [volumePercent] (0–100) using
  /// music only. Kept for the simple music-only path and existing callers.
  Future<void> ring({
    required String soundId,
    int volumePercent = 100,
    bool vibrate = true,
  }) {
    return start(
      AlarmPlaybackConfig(
        mode: AlarmSoundMode.musicOnly,
        soundId: soundId,
        volumePercent: volumePercent,
        vibrate: vibrate,
      ),
    );
  }

  /// Starts a ring using the full [config] (sound mode, message and timing).
  Future<void> start(AlarmPlaybackConfig config) async {
    await _resetSession();
    _config = config;
    _tone = AlarmSounds.resolveTone(config.soundId);
    _volume = (config.volumePercent / 100).clamp(0.0, 1.0).toDouble();
    _ringing = true;
    _startVibration(config.vibrate);
    if (config.playsMusic) await _ensurePlaying();
    _startWatchdog();
    _startVoiceLoop();
  }

  Future<void> _ensurePlaying() async {
    final tone = _tone;
    final config = _config;
    if (!_ringing || tone == null || config == null || !config.playsMusic) {
      return;
    }
    try {
      await _player.play(tone, _volume, loop: true);
    } catch (e) {
      debugPrint('Alarm audio failed for ${tone.uri}: $e');
    }
  }

  void _startVibration(bool vibrate) {
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    if (!vibrate) return;
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      HapticFeedback.vibrate();
    });
    HapticFeedback.vibrate();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(watchdogInterval, (_) {
      if (!_ringing) return;
      final config = _config;
      if (config == null) return;
      if (config.playsMusic && !_player.isPlaying) {
        _ensurePlaying();
      }
      // If the voice loop ended for any reason while still ringing, restart it.
      if (config.speaks && !_loopActive && _tts != null) {
        _startVoiceLoop();
      }
    });
  }

  void _startVoiceLoop() {
    final config = _config;
    final tts = _tts;
    if (config == null || tts == null || !config.speaks) return;
    _loopActive = true;
    unawaited(
      _runVoiceLoop(config, tts).whenComplete(() {
        _loopActive = false;
      }),
    );
  }

  Future<void> _runVoiceLoop(AlarmPlaybackConfig config, AlarmTts tts) async {
    try {
      await tts.configure(config.voice, config.languageCode);
    } catch (e) {
      debugPrint('Alarm voice setup failed: $e');
      // Without speech the alarm still rings with music (if any).
      return;
    }

    if (config.effectiveMode == AlarmSoundMode.voiceOnly) {
      while (_isActive(config)) {
        await _speak(config, tts, duck: false);
        if (!_isActive(config)) break;
        await _sleep(Duration(seconds: config.safeVoicePauseSec));
      }
      return;
    }

    while (_isActive(config)) {
      final timing = config.voiceTiming;
      if (timing == VoiceTiming.beforeMusic) {
        await _speak(config, tts, duck: true);
        if (!_isActive(config)) break;
        await _sleep(Duration(seconds: config.safeMusicIntervalSec));
      } else if (timing == VoiceTiming.betweenSegments) {
        await _sleep(Duration(seconds: config.safeMusicIntervalSec));
        if (!_isActive(config)) break;
        await _speak(config, tts, duck: true);
      } else {
        // Speak over the music: music keeps playing, ducked while speaking.
        await _sleep(Duration(seconds: config.safeMusicIntervalSec));
        if (!_isActive(config)) break;
        await _speak(config, tts, duck: false);
      }
    }
  }

  bool _isActive(AlarmPlaybackConfig config) =>
      _ringing && identical(_config, config);

  /// Speaks the configured message. [duck] mutes the music while speaking (used
  /// when the voice and music do not overlap); otherwise the music is ducked so
  /// the voice can be heard over it. Music volume is always restored afterwards.
  Future<void> _speak(
    AlarmPlaybackConfig config,
    AlarmTts tts, {
    required bool duck,
  }) async {
    final tone = _tone;
    final text = config.message.trim();
    try {
      if (config.playsMusic && tone != null) {
        final target = duck ? 0.0 : (_volume * _duckFactor).clamp(0.0, 1.0);
        await _player.play(tone, target, loop: true);
      }
      if (text.isNotEmpty) await tts.speak(text);
    } catch (e) {
      debugPrint('Alarm speech failed: $e');
    } finally {
      if (config.playsMusic && tone != null && _isActive(config)) {
        await _ensurePlaying();
      }
    }
  }

  /// A cancellable sleep that resolves early when the ring stops.
  Future<void> _sleep(Duration duration) {
    _sleepTimer?.cancel();
    final completer = Completer<void>();
    _sleepCompleter = completer;
    _sleepTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Re-asserts the current ring without restarting it: keeps the music loop
  /// alive and revives the voice loop if the platform stopped it (e.g. after a
  /// lifecycle transition). Safe to call when not ringing.
  Future<void> reassert() async {
    if (!_ringing) return;
    final config = _config;
    if (config == null) return;
    if (config.playsMusic) await _ensurePlaying();
    if (config.speaks && !_loopActive && _tts != null) _startVoiceLoop();
  }

  /// Plays a single short preview of [soundId] without looping.
  Future<void> preview({
    required String soundId,
    int volumePercent = 100,
  }) async {
    await stop();
    final tone = AlarmSounds.resolveTone(soundId);
    try {
      await _player.play(
        tone,
        (volumePercent / 100).clamp(0.0, 1.0).toDouble(),
        loop: false,
      );
    } catch (e) {
      debugPrint('Alarm preview failed for ${tone.uri}: $e');
    }
  }

  /// Clears timers/loops between rings without disposing the player.
  Future<void> _resetSession() async {
    _ringing = false;
    _watchdog?.cancel();
    _watchdog = null;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    final pending = _sleepCompleter;
    _sleepCompleter = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    _config = null;
    _loopActive = false;
  }

  /// Stops any playback, speech and vibration immediately.
  Future<void> stop() async {
    await _resetSession();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
