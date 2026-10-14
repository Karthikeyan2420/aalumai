import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import '../providers/providers.dart';

class BackupResult {
  const BackupResult({required this.file, required this.bytes});

  final File file;
  final int bytes;
}

/// Offline backup / restore and CSV export.
///
/// Backups are consistent snapshots of the SQLite database taken with
/// `VACUUM INTO`, so they are safe to create while the app is running. Restore
/// closes the live connection and replaces the database file; Riverpod is then
/// asked to rebuild every data provider against the restored file.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

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

  /// Writes a timestamped snapshot to the app's `backups/` folder.
  Future<BackupResult> exportBackup() async {
    final dir = await _backupDir();
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final target = File(p.join(dir.path, 'aalumai_backup_$stamp.sqlite'));
    if (await target.exists()) {
      await target.delete();
    }
    // VACUUM INTO produces a compact, fully-checkpointed copy.
    final escaped = target.path.replaceAll("'", "''");
    await _db.customStatement("VACUUM INTO '$escaped'");
    final bytes = await target.length();
    return BackupResult(file: target, bytes: bytes);
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupDir();
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sqlite'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Replaces the live database with [source]. Callers should invalidate
  /// [appDatabaseProvider] afterwards so every dependent provider rebuilds
  /// against the restored data.
  Future<void> restore(File source) async {
    final target = await _dbFile();
    await _db.close();
    await source.copy(target.path);
    // Sidecar journal files from the previous database are no longer valid.
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final side = File('${target.path}$suffix');
      if (await side.exists()) {
        await side.delete();
      }
    }
  }

  /// Exports all transactions to CSV text (for spreadsheets / accounting).
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
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);
