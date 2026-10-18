import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;
  late int accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db);
    accountId = await repo.createAccount(name: 'Cash');
  });

  tearDown(() => db.close());

  test('a rule is due when nextDate is today or earlier', () async {
    final now = DateTime.now();
    await repo.createRecurring(
      type: TransactionType.expense.index,
      accountId: accountId,
      amountPaise: 10000,
      nextDate: now,
      frequency: RecurrenceFrequency.monthly.index,
    );
    await repo.createRecurring(
      type: TransactionType.expense.index,
      accountId: accountId,
      amountPaise: 20000,
      nextDate: now.add(const Duration(days: 5)),
      frequency: RecurrenceFrequency.monthly.index,
    );
    final due = await repo.dueRecurringRules(now);
    expect(due, hasLength(1));
    expect(due.single.amountPaise, 10000);
  });

  test(
    'confirming a rule records a transaction and advances nextDate',
    () async {
      final now = DateTime.now();
      final id = await repo.createRecurring(
        type: TransactionType.expense.index,
        accountId: accountId,
        amountPaise: 50000,
        nextDate: now,
        note: 'Rent',
        frequency: RecurrenceFrequency.monthly.index,
      );
      final rule = (await repo.dueRecurringRules(now)).single;

      await repo.confirmRecurring(rule);

      final txns = await repo.watchTransactions().first;
      expect(txns, hasLength(1));
      expect(txns.single.amountPaise, 50000);
      expect(txns.single.note, 'Rent');

      final next = await repo.dueRecurringRules(
        now.add(const Duration(days: 40)),
      );
      expect(next, hasLength(1));
      expect(next.single.id, id);
      expect(next.single.lastRun, isNotNull);
    },
  );

  test('paused rules are not due', () async {
    final now = DateTime.now();
    final id = await repo.createRecurring(
      type: TransactionType.expense.index,
      accountId: accountId,
      amountPaise: 10000,
      nextDate: now,
      frequency: RecurrenceFrequency.monthly.index,
    );
    await repo.setRecurringActive(id, false);
    expect(await repo.dueRecurringRules(now), isEmpty);
    await repo.setRecurringActive(id, true);
    expect(await repo.dueRecurringRules(now), hasLength(1));
  });

  test('deleting a rule removes it', () async {
    final now = DateTime.now();
    final id = await repo.createRecurring(
      type: TransactionType.expense.index,
      accountId: accountId,
      amountPaise: 10000,
      nextDate: now,
    );
    await repo.deleteRecurring(id);
    expect(await repo.dueRecurringRules(now), isEmpty);
  });
}
