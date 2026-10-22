import 'dart:io';

import 'package:aalumai/features/alarms/alarm_audio.dart';
import 'package:aalumai/features/alarms/alarm_playback.dart';
import 'package:aalumai/features/alarms/alarm_tts.dart';
import 'package:aalumai/features/alarms/data/alarm_voice_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// A recording player so the loop/watchdog lifecycle can be asserted without
/// touching `just_audio` or the platform.
class _FakePlayer implements AlarmAudioPlayer {
  bool playing = false;
  int playCount = 0;
  bool loop = false;
  AlarmTone? tone;
  double volume = 1;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> play(AlarmTone tone, double volume, {required bool loop}) async {
    this.tone = tone;
    this.volume = volume;
    this.loop = loop;
    playing = true;
    playCount++;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    playing = false;
  }
}

/// A recording TTS backend, so the voice loop's start can be observed without
/// the platform.
class _FakeTts implements AlarmTts {
  int speakCount = 0;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => true;

  @override
  Future<List<TtsVoice>> voices() async => const [];

  @override
  Future<void> configure(AlarmVoiceSettings settings, String languageCode) async {}

  @override
  Future<void> speak(String text) async {
    speakCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  group('AlarmSounds.resolveTone', () {
    test('bundled ids resolve to their bundled asset', () {
      expect(
        AlarmSounds.resolveTone('classic'),
        const AlarmTone.asset('assets/audio/alarm_classic.wav'),
      );
      expect(
        AlarmSounds.resolveTone('urgent'),
        const AlarmTone.asset('assets/audio/alarm_urgent.wav'),
      );
    });

    test('unknown, empty and system ids fall back to the default tone', () {
      const def = AlarmTone.asset('assets/audio/alarm_classic.wav');
      expect(AlarmSounds.resolveTone(''), def);
      expect(AlarmSounds.resolveTone('system'), def);
      expect(AlarmSounds.resolveTone('mystery'), def);
    });

    test('an existing custom file resolves to a file tone', () {
      final dir = Directory.systemTemp.createTempSync('alarm_tone');
      final file = File('${dir.path}${Platform.pathSeparator}song.mp3')
        ..writeAsStringSync('x');
      final uri = AlarmSounds.customUri(file.path);
      expect(AlarmSounds.isCustom(uri), isTrue);
      expect(AlarmSounds.resolveTone(uri), AlarmTone.file(file.path));
      dir.deleteSync(recursive: true);
    });

    test('a missing custom file falls back to the default tone', () {
      expect(
        AlarmSounds.resolveTone('file:/no/such/alarm.mp3'),
        const AlarmTone.asset('assets/audio/alarm_classic.wav'),
      );
    });
  });

  testWidgets('ring loops continuously and re-asserts playback if stopped', (
    tester,
  ) async {
    final player = _FakePlayer();
    final audio = AlarmAudio(player: player);

    await audio.ring(soundId: 'classic', vibrate: false);
    expect(audio.isRinging, isTrue);
    expect(player.playing, isTrue);
    expect(player.loop, isTrue);

    // The loop must survive well past the ~1s mark that previously fell back
    // to a one-shot sound.
    await tester.pump(const Duration(seconds: 3));
    expect(player.playing, isTrue);

    // Simulate the platform stopping playback mid-ring: the watchdog restarts it.
    player.playing = false;
    await tester.pump(const Duration(seconds: 2));
    expect(player.playing, isTrue);
    expect(player.playCount, greaterThanOrEqualTo(2));

    await audio.stop();
    expect(audio.isRinging, isFalse);
    expect(player.playing, isFalse);
    await audio.dispose();
  });

  testWidgets('preview plays a single non-looping pass', (tester) async {
    final player = _FakePlayer();
    final audio = AlarmAudio(player: player);

    await audio.preview(soundId: 'gentle');
    expect(player.playing, isTrue);
    expect(player.loop, isFalse);
    expect(audio.isRinging, isFalse);

    await audio.dispose();
  });

  testWidgets(
    'a native-owned ring starts neither Dart music nor the Dart voice loop',
    (tester) async {
      final player = _FakePlayer();
      final tts = _FakeTts();
      final audio = AlarmAudio(player: player, tts: tts);

      // The native service is playing music and speaking the message.
      await audio.start(
        const AlarmPlaybackConfig(
          mode: AlarmSoundMode.musicAndVoice,
          soundId: 'classic',
          message: 'Wake up and shine',
          musicIntervalSec: 1,
          vibrate: false,
        ),
        musicAlreadyPlaying: true,
        voiceAlreadyPlaying: true,
      );

      expect(audio.isRinging, isTrue);
      // No second music player and no Dart speech: the native service owns both.
      expect(player.playCount, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(tts.speakCount, 0);

      await audio.dispose();
    },
  );

  testWidgets('a Dart-owned ring speaks the message on the interval', (
    tester,
  ) async {
    final player = _FakePlayer();
    final tts = _FakeTts();
    final audio = AlarmAudio(player: player, tts: tts);

    await audio.start(
      const AlarmPlaybackConfig(
        mode: AlarmSoundMode.musicAndVoice,
        soundId: 'classic',
        message: 'Wake up and shine',
        musicIntervalSec: 1,
        vibrate: false,
      ),
    );

    await tester.pump(const Duration(milliseconds: 1200));
    expect(tts.speakCount, greaterThanOrEqualTo(1));
    expect(player.playing, isTrue);

    await audio.dispose();
  });
}
