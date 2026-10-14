import 'dart:io';

import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/backup_service.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Routes path_provider to a throwaway directory so backup/restore can be
/// exercised without a real platform.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aalumai_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exportBackup writes a readable snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final finance = FinanceRepository(db);
    await finance.createAccount(name: 'Cash', openingBalancePaise: 12345);
    final service = BackupService(db);

    final result = await service.exportBackup();

    expect(await result.file.exists(), isTrue);
    expect(result.bytes, greaterThan(0));
    expect(await service.listBackups(), hasLength(1));

    await db.close();
  });

  test('restore replaces the live database with the snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final finance = FinanceRepository(db);
    await finance.createAccount(name: 'Cash');
    await finance.addTransaction(
      accountId: 1,
      type: TransactionType.expense,
      amountPaise: 4200,
      date: DateTime(2026, 1, 1),
    );
    final service = BackupService(db);
    final backup = await service.exportBackup();

    await service.restore(backup.file);

    // A fresh connection at the restored location should see the data.
    final restored = AppDatabase.forTesting(
      NativeDatabase(File('${tempDir.path}/aalumai.sqlite')),
    );
    addTearDown(restored.close);
    final txns = await restored.select(restored.transactions).get();
    expect(txns, hasLength(1));
    expect(txns.single.amountPaise, 4200);
  });

  test(
    'transactionsCsv renders a header and one row per transaction',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final finance = FinanceRepository(db);
      final account = await finance.createAccount(name: 'Bank');
      final cat = await finance.createCategory('Food', CategoryKind.expense);
      await finance.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 1250,
        date: DateTime(2026, 7, 9),
        categoryId: cat,
        note: 'Lunch',
      );
      final csv = await BackupService(db).transactionsCsv();

      expect(csv, contains('Date,Type,Amount,Account,Category,Note'));
      expect(csv, contains('2026-07-09,Expense,12.50,Bank,Food,Lunch'));

      await db.close();
    },
  );
}
