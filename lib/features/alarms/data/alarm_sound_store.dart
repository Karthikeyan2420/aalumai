import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../alarm_audio.dart';

/// Imports user-chosen audio files into app-managed storage so an alarm keeps a
/// stable, local copy even if the original file is moved or deleted.
///
/// Nothing is uploaded anywhere; the copied file lives in the app's support
/// directory and is referenced by a `file:` `soundUri`.
class AlarmSoundStore {
  AlarmSoundStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'alarm_sounds'));
  }

  /// Copies [sourcePath] into app storage and returns the persisted `file:`
  /// soundUri, or `null` when the source is missing or the copy fails.
  Future<String?> import(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!source.existsSync()) return null;
      final dir = await _directory();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ext = p.extension(sourcePath).toLowerCase();
      final name = 'alarm_${DateTime.now().microsecondsSinceEpoch}$ext';
      final dest = p.join(dir.path, name);
      await source.copy(dest);
      return AlarmSounds.customUri(dest);
    } catch (_) {
      return null;
    }
  }

  /// The display name of the file behind a custom `soundUri`, or `null` when it
  /// is not a custom file.
  static String? displayName(String soundUri) {
    final path = AlarmSounds.customPath(soundUri);
    if (path == null || path.isEmpty) return null;
    return p.basename(path);
  }

  /// Best-effort removal of an imported file that an alarm no longer uses.
  Future<void> delete(String soundUri) async {
    final path = AlarmSounds.customPath(soundUri);
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}

final alarmSoundStoreProvider = Provider<AlarmSoundStore>(
  (ref) => AlarmSoundStore(),
);
