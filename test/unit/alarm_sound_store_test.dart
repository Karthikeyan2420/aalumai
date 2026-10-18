import 'dart:io';

import 'package:aalumai/features/alarms/alarm_audio.dart';
import 'package:aalumai/features/alarms/data/alarm_sound_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('alarm_sound_store'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    'import copies the file into app storage and returns a file uri',
    () async {
      final source = File('${tmp.path}${Platform.pathSeparator}song.mp3')
        ..writeAsStringSync('abc');
      final destDir = Directory('${tmp.path}${Platform.pathSeparator}dest')
        ..createSync();
      final store = AlarmSoundStore(directory: () async => destDir);

      final uri = await store.import(source.path);
      expect(uri, isNotNull);
      expect(AlarmSounds.isCustom(uri!), isTrue);

      final copied = AlarmSounds.customPath(uri)!;
      expect(copied.startsWith(destDir.path), isTrue);
      expect(File(copied).existsSync(), isTrue);
      expect(File(copied).readAsStringSync(), 'abc');
      expect(AlarmSoundStore.displayName(uri), endsWith('.mp3'));
    },
  );

  test('import returns null for a missing source', () async {
    final store = AlarmSoundStore(directory: () async => tmp);
    expect(
      await store.import('${tmp.path}${Platform.pathSeparator}nope.mp3'),
      isNull,
    );
  });

  test('displayName is null for bundled ids', () {
    expect(AlarmSoundStore.displayName('classic'), isNull);
    expect(AlarmSoundStore.displayName('system'), isNull);
  });

  test('delete removes an imported file', () async {
    final source = File('${tmp.path}${Platform.pathSeparator}voice.wav')
      ..writeAsStringSync('abc');
    final destDir = Directory('${tmp.path}${Platform.pathSeparator}dest')
      ..createSync();
    final store = AlarmSoundStore(directory: () async => destDir);

    final uri = await store.import(source.path);
    final copied = AlarmSounds.customPath(uri!)!;
    expect(File(copied).existsSync(), isTrue);

    await store.delete(uri);
    expect(File(copied).existsSync(), isFalse);
  });
}
