import 'dart:convert';
import 'dart:io';

import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/features/jarvis/data/model_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late AppPreferences prefs;
  late ModelManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = AppPreferences(await SharedPreferences.getInstance());
    tempDir = await Directory.systemTemp.createTemp('jarvis_models_test');
    manager = ModelManager(prefs, modelsDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('import copies the file into app storage and records its hash',
      () async {
    final source = File(p.join(tempDir.path, 'source.gguf'));
    source.writeAsStringSync('fake-gguf-bytes');

    final path = await manager.importFromFile(source.path);

    expect(await File(path).readAsString(), 'fake-gguf-bytes');
    expect(await manager.modelPathIfPresent(), path);
    expect(await manager.modelSizeBytes(), 'fake-gguf-bytes'.length);
    expect(
      prefs.jarvisModelSha256,
      sha256.convert(utf8.encode('fake-gguf-bytes')).toString(),
    );
  });

  test('importing a missing file throws and leaves state untouched',
      () async {
    await expectLater(
      manager.importFromFile(p.join(tempDir.path, 'nope.gguf')),
      throwsA(isA<FileSystemException>()),
    );
    expect(await manager.modelPathIfPresent(), isNull);
  });

  test('deleteModel removes the file and clears the install record',
      () async {
    final source = File(p.join(tempDir.path, 'source.gguf'))
      ..writeAsStringSync('bytes');
    final path = await manager.importFromFile(source.path);

    await manager.deleteModel();

    expect(await File(path).exists(), isFalse);
    expect(await manager.modelPathIfPresent(), isNull);
    expect(prefs.jarvisModelSha256, isEmpty);
  });

  test('re-import replaces a previous model', () async {
    final source = File(p.join(tempDir.path, 'source.gguf'))
      ..writeAsStringSync('version-1');
    await manager.importFromFile(source.path);
    source.writeAsStringSync('version-2');

    final path = await manager.importFromFile(source.path);

    expect(await File(path).readAsString(), 'version-2');
    expect(await manager.modelSizeBytes(), 'version-2'.length);
  });

  test('settings clamp to safe ranges', () async {
    await prefs.setJarvisModelThreads(64);
    expect(prefs.jarvisModelThreads, 8);
    await prefs.setJarvisModelThreads(0);
    expect(prefs.jarvisModelThreads, 1);

    await prefs.setJarvisModelContextSize(999999);
    expect(prefs.jarvisModelContextSize, 8192);
    await prefs.setJarvisModelContextSize(10);
    expect(prefs.jarvisModelContextSize, 1024);
  });
}
