import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backgrounds/background_config.dart';
import '../backgrounds/background_presets.dart';
import '../backgrounds/background_store.dart';
import '../db/database.dart';
import '../providers/providers.dart';
import 'backup_preferences.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupResult {
  const BackupResult({required this.file, required this.bytes});

  final File file;
  final int bytes;
}

/// Offline backup / restore and CSV export.
class BackupService {
  BackupService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  static const bundleFormatVersion = 1;
  static const minSchemaVersion = 1;
  static const maxSchemaVersion = 14;

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _dbFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'aalumai.sqlite'));
  }

  Future<Directory> _alarmSoundsDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'alarm_sounds'));
  }

  Future<String> _fileSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<int> _readSchemaVersion(File file) async {
    final executor = NativeDatabase(file, logStatements: false);
    final probe = AppDatabase.forTesting(executor);
    try {
      final row = await probe.customSelect('PRAGMA user_version').getSingle();
      return row.data.values.first as int;
    } finally {
      await probe.close();
    }
  }

  Future<void> _validateSqliteFile(File file) async {
    if (!await file.exists()) {
      throw BackupException('Database file missing');
    }
    final raf = await file.open();
    try {
      final header = await raf.read(16);
      if (String.fromCharCodes(header) != 'SQLite format 3\u0000') {
        throw BackupException('Not a SQLite database');
      }
    } finally {
      await raf.close();
    }
    final version = await _readSchemaVersion(file);
    if (version < minSchemaVersion || version > maxSchemaVersion) {
      throw BackupException('Unsupported database version ($version)');
    }
  }

  Future<Directory> _createPreRestoreSafetyCopy() async {
    final dir = await _backupDir();
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final safety = Directory(p.join(dir.path, 'pre_restore_$stamp'));
    await safety.create(recursive: true);

    final dbTarget = File(p.join(safety.path, 'database.sqlite'));
    final escaped = dbTarget.path.replaceAll("'", "''");
    await _db.customStatement("VACUUM INTO '$escaped'");

    final prefsFile = File(p.join(safety.path, 'preferences.json'));
    await prefsFile.writeAsString(
      encodePreferences(exportPreferences(_prefs)),
    );

    final alarmSrc = await _alarmSoundsDir();
    if (await alarmSrc.exists()) {
      await _copyDirectory(
        alarmSrc,
        Directory(p.join(safety.path, 'alarm_sounds')),
      );
    }
    return safety;
  }

  Future<void> _rollbackFromSafetyCopy(Directory safety) async {
    final dbBackup = File(p.join(safety.path, 'database.sqlite'));
    if (await dbBackup.exists()) {
      await _db.close();
      final target = await _dbFile();
      await dbBackup.copy(target.path);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final side = File('${target.path}$suffix');
        if (await side.exists()) await side.delete();
      }
    }
    final prefsFile = File(p.join(safety.path, 'preferences.json'));
    if (await prefsFile.exists()) {
      await importPreferences(
        _prefs,
        decodePreferences(await prefsFile.readAsString()),
      );
    }
    final alarmBackup = Directory(p.join(safety.path, 'alarm_sounds'));
    if (await alarmBackup.exists()) {
      final dest = await _alarmSoundsDir();
      if (await dest.exists()) await dest.delete(recursive: true);
      await _copyDirectory(alarmBackup, dest);
    }
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    if (!await to.exists()) await to.create(recursive: true);
    await for (final entity in from.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: from.path);
      final dest = File(p.join(to.path, relative));
      await dest.parent.create(recursive: true);
      await entity.copy(dest.path);
    }
  }

  List<File> _backgroundFilesToInclude() {
    final store = BackgroundStore(_prefs);
    final files = <File>[];
    for (final slot in BackgroundSlot.values) {
      final config = store.read(
        slot,
        BackgroundPresets.defaultFor(slot),
      );
      if (config.kind == BackgroundKind.file) {
        final path = config.filePath;
        if (path != null && path.isNotEmpty) {
          final f = File(path);
          if (f.existsSync()) files.add(f);
        }
      }
    }
    return files;
  }

  /// Writes a timestamped ZIP bundle to the app's `backups/` folder.
  Future<BackupResult> exportBackup() async {
    final dir = await _backupDir();
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final zipPath = p.join(dir.path, 'aalumai_backup_$stamp.zip');

    final temp = await Directory(
      p.join((await getTemporaryDirectory()).path, 'backup_export_$stamp'),
    ).create(recursive: true);

    try {
      final dbOut = File(p.join(temp.path, 'database.sqlite'));
      final escaped = dbOut.path.replaceAll("'", "''");
      await _db.customStatement("VACUUM INTO '$escaped'");
      await _validateSqliteFile(dbOut);

      final schemaVersion = await _readSchemaVersion(dbOut);

      var appVersion = '0.0.0';
      var buildNumber = '0';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
        buildNumber = info.buildNumber;
      } catch (_) {}
      final manifestFiles = <Map<String, String>>[
        {'path': 'database.sqlite', 'sha256': await _fileSha256(dbOut)},
      ];

      final prefsOut = File(p.join(temp.path, 'preferences.json'));
      await prefsOut.writeAsString(
        encodePreferences(exportPreferences(_prefs)),
      );
      manifestFiles.add({
        'path': 'preferences.json',
        'sha256': await _fileSha256(prefsOut),
      });

      final alarmSrc = await _alarmSoundsDir();
      if (await alarmSrc.exists()) {
        final alarmDest = Directory(p.join(temp.path, 'alarm_sounds'));
        await _copyDirectory(alarmSrc, alarmDest);
        await for (final f in alarmDest.list(recursive: true)) {
          if (f is File) {
            manifestFiles.add({
              'path': p.relative(f.path, from: temp.path).replaceAll('\\', '/'),
              'sha256': await _fileSha256(f),
            });
          }
        }
      }

      final bgDir = Directory(p.join(temp.path, 'backgrounds'));
      for (final src in _backgroundFilesToInclude()) {
        if (!await bgDir.exists()) await bgDir.create(recursive: true);
        final name = p.basename(src.path);
        final dest = File(p.join(bgDir.path, name));
        if (!await dest.exists()) await src.copy(dest.path);
        manifestFiles.add({
          'path': 'backgrounds/$name',
          'sha256': await _fileSha256(dest),
        });
      }

      final manifest = {
        'formatVersion': bundleFormatVersion,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'schemaVersion': schemaVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'files': manifestFiles,
      };
      final manifestFile = File(p.join(temp.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest));

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await for (final entity in temp.list(recursive: true)) {
        if (entity is File) {
          final arc = p.relative(entity.path, from: temp.path);
          encoder.addFile(entity, arc.replaceAll('\\', '/'));
        }
      }
      encoder.close();

      final zipFile = File(zipPath);
      return BackupResult(file: zipFile, bytes: await zipFile.length());
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupDir();
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.sqlite') || f.path.endsWith('.zip'),
            )
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> restore(File source) async {
    if (source.path.toLowerCase().endsWith('.zip')) {
      await _restoreBundle(source);
    } else {
      await _restoreLegacySqlite(source);
    }
  }

  Future<void> _restoreLegacySqlite(File source) async {
    await _validateSqliteFile(source);
    final safety = await _createPreRestoreSafetyCopy();
    try {
      await _replaceLiveDatabase(source);
    } catch (e) {
      await _rollbackFromSafetyCopy(safety);
      rethrow;
    }
  }

  Future<void> _restoreBundle(File zipFile) async {
    final temp = await Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'backup_restore_${DateTime.now().millisecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    Directory? safety;
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (!entry.isFile || entry.name.isEmpty) continue;
        final name = entry.name.replaceAll('\\', '/');
        final out = File(p.join(temp.path, name));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);
      }

      final manifestFile = File(p.join(temp.path, 'manifest.json'));
      final dbFile = File(p.join(temp.path, 'database.sqlite'));
      if (!await manifestFile.exists() || !await dbFile.exists()) {
        throw BackupException('Invalid backup bundle');
      }

      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final format = manifest['formatVersion'] as int? ?? 0;
      if (format != bundleFormatVersion) {
        throw BackupException('Unsupported backup format');
      }
      final schema = manifest['schemaVersion'] as int? ?? 0;
      if (schema < minSchemaVersion || schema > maxSchemaVersion) {
        throw BackupException('Unsupported database version in backup');
      }

      final files = manifest['files'] as List<dynamic>? ?? [];
      for (final entry in files) {
        if (entry is! Map) continue;
        final path = entry['path'] as String?;
        final expected = entry['sha256'] as String?;
        if (path == null || expected == null) continue;
        final f = File(p.join(temp.path, path));
        if (!await f.exists()) {
          throw BackupException('Backup incomplete: missing $path');
        }
        final actual = await _fileSha256(f);
        if (actual != expected) {
          throw BackupException('Backup corrupted: $path');
        }
      }

      await _validateSqliteFile(dbFile);
      safety = await _createPreRestoreSafetyCopy();

      await _replaceLiveDatabase(dbFile);

      final prefsFile = File(p.join(temp.path, 'preferences.json'));
      if (await prefsFile.exists()) {
        await importPreferences(
          _prefs,
          decodePreferences(await prefsFile.readAsString()),
        );
      }

      final alarmBundle = Directory(p.join(temp.path, 'alarm_sounds'));
      if (await alarmBundle.exists()) {
        final dest = await _alarmSoundsDir();
        if (await dest.exists()) await dest.delete(recursive: true);
        await _copyDirectory(alarmBundle, dest);
      }

      final bgBundle = Directory(p.join(temp.path, 'backgrounds'));
      if (await bgBundle.exists()) {
        await for (final f in bgBundle.list()) {
          if (f is! File) continue;
          for (final slot in BackgroundSlot.values) {
            final key = BackgroundStore.keyFor(slot);
            final raw = _prefs.getString(key);
            if (raw == null || raw.isEmpty) continue;
            try {
              final config = BackgroundConfig.tryParse(jsonDecode(raw));
              if (config?.kind != BackgroundKind.file) continue;
              final path = config!.filePath;
              if (path != null && p.basename(path) == p.basename(f.path)) {
                await f.copy(path);
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (safety != null) {
        await _rollbackFromSafetyCopy(safety);
      }
      if (e is BackupException) rethrow;
      throw BackupException('Restore failed');
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Future<void> _replaceLiveDatabase(File source) async {
    final target = await _dbFile();
    await _db.close();
    await source.copy(target.path);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final side = File('${target.path}$suffix');
      if (await side.exists()) {
        await side.delete();
      }
    }
  }

  Future<String> transactionsCsv() async {
    final accounts = await _db.select(_db.accounts).get();
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categories = await _db.select(_db.categories).get();
    final categoryNames = {for (final c in categories) c.id: c.name};
    final txns = await _db.select(_db.transactions).get();

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Amount', 'Account', 'Category', 'Note'],
    ];
    for (final t in txns) {
      rows.add([
        t.date.toIso8601String().split('T').first,
        _typeName(t.type),
        (t.amountPaise / 100).toStringAsFixed(2),
        accountNames[t.accountId] ?? '',
        t.categoryId == null ? '' : (categoryNames[t.categoryId] ?? ''),
        t.note,
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  String _typeName(int type) => switch (type) {
    0 => 'Income',
    1 => 'Expense',
    2 => 'Transfer',
    _ => 'Unknown',
  };
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);
