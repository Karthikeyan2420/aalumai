import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('schema', () {
    test('creates every domain table on first open', () async {
      final rows =
          await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name NOT LIKE 'sqlite_%'",
              )
              .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>{
          'habits',
          'habit_completions',
          'tasks',
          'events',
          'notes',
          'accounts',
          'categories',
          'transactions',
          'budgets',
          'debts',
          'savings_goals',
          'exercises',
          'workout_sessions',
          'workout_set_logs',
          'workout_plans',
          'workout_plan_items',
          'workout_prefs',
          'workout_schedules',
          'water_logs',
          'music_tracks',
          'alarms',
          'recipes',
          'lessons',
          'learning_progress',
        }),
      );
      // The retired dashboard table must not be present.
      expect(names, isNot(contains('dashboard_sections')));
    });

    test('enables foreign key enforcement', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);
    });
  });

  group('FinanceRepository', () {
    late FinanceRepository repo;

    setUp(() => repo = FinanceRepository(db));

    test('seeds default categories exactly once', () async {
      await repo.seedDefaultCategories();
      await repo.seedDefaultCategories();
      final cats = await db.select(db.categories).get();
      expect(cats, hasLength(14));
      expect(
        cats.where((c) => c.kind == CategoryKind.expense.index),
        hasLength(9),
      );
      expect(
        cats.where((c) => c.kind == CategoryKind.income.index),
        hasLength(5),
      );
    });

    test('balances combine opening balance, income and expense', () async {
      final account = await repo.createAccount(
        name: 'Cash',
        openingBalancePaise: 100000,
      );
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.income,
        amountPaise: 50000,
        date: DateTime(2026, 1, 5),
      );
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 20000,
        date: DateTime(2026, 1, 6),
      );
      final balances = await repo.balances();
      expect(balances.single.balancePaise, 130000);
    });

    test(
      'transfer moves money without affecting income/expense totals',
      () async {
        final a = await repo.createAccount(
          name: 'A',
          openingBalancePaise: 100000,
        );
        final b = await repo.createAccount(name: 'B');
        await repo.addTransfer(
          fromAccountId: a,
          toAccountId: b,
          amountPaise: 40000,
          date: DateTime(2026, 2, 1),
        );
        final balances = {
          for (final e in await repo.balances()) e.account.id: e.balancePaise,
        };
        expect(balances[a], 60000);
        expect(balances[b], 40000);
        final totals = await repo.totals(
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 28, 23, 59, 59),
        );
        expect(totals.income, 0);
        expect(totals.expense, 0);
      },
    );

    test('expenseByCategory aggregates only expenses in range', () async {
      final account = await repo.createAccount(name: 'Cash');
      final food = await repo.createCategory('Food', CategoryKind.expense);
      final rent = await repo.createCategory('Rent', CategoryKind.expense);
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 1500,
        date: DateTime(2026, 3, 2),
        categoryId: food,
      );
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 500,
        date: DateTime(2026, 3, 3),
        categoryId: food,
      );
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 9000,
        date: DateTime(2026, 3, 4),
        categoryId: rent,
      );
      // Outside the window and an income that must be ignored.
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.expense,
        amountPaise: 777,
        date: DateTime(2026, 4, 1),
        categoryId: food,
      );
      await repo.addTransaction(
        accountId: account,
        type: TransactionType.income,
        amountPaise: 999,
        date: DateTime(2026, 3, 5),
        categoryId: food,
      );
      final byCat = await repo.expenseByCategory(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31, 23, 59, 59),
      );
      expect(byCat[food], 2000);
      expect(byCat[rent], 9000);
    });

    test(
      'confirmRecurring records a transaction and advances the rule',
      () async {
        final account = await repo.createAccount(name: 'Cash');
        final id = await repo.createRecurring(
          type: TransactionType.expense.index,
          accountId: account,
          amountPaise: 9999,
          nextDate: DateTime(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly.index,
        );
        final rule =
            (await repo.dueRecurringRules(DateTime(2026, 1, 15))).single;
        await repo.confirmRecurring(rule);
        final txns = await db.select(db.transactions).get();
        expect(txns.single.amountPaise, 9999);
        final updated =
            await (db.select(db.recurringRules)
              ..where((t) => t.id.equals(id))).getSingle();
        expect(updated.nextDate, DateTime(2026, 2, 1));
        // Nothing else is due now.
        expect(await repo.dueRecurringRules(DateTime(2026, 1, 20)), isEmpty);
      },
    );

    test(
      'debt interest is an expense but principal repayment is not',
      () async {
        final account = await repo.createAccount(name: 'Cash');
        final debt = await repo.createDebt(
          name: 'Loan',
          type: 0,
          principalPaise: 100000,
          startDate: DateTime(2026, 1, 1),
        );
        await repo.addPayment(
          debtId: debt,
          principalPaise: 5000,
          interestPaise: 800,
          date: DateTime(2026, 1, 10),
          accountId: account,
        );
        final txns = await db.select(db.transactions).get();
        expect(txns, hasLength(1));
        expect(txns.single.amountPaise, 800);
        expect(txns.single.type, TransactionType.expense.index);
        expect(await repo.debtPaidPrincipal(debt), 5000);
      },
    );
  });

  group('HabitRepository', () {
    late HabitRepository repo;

    setUp(() => repo = HabitRepository(db));

    test('create / complete / uncomplete round-trips', () async {
      final id = await repo.create(name: 'Read');
      final day = DateTime(2026, 5, 4, 13);
      expect(await repo.isCompleted(id, day), isFalse);
      await repo.setCompleted(id, day, completed: true);
      expect(await repo.isCompleted(id, day), isTrue);
      await repo.setCompleted(id, day, completed: false);
      expect(await repo.isCompleted(id, day), isFalse);
      expect(await repo.completedDays(id), isEmpty);
    });

    test('normalises day so time-of-day does not create duplicates', () async {
      final id = await repo.create(name: 'Walk');
      await repo.setCompleted(id, DateTime(2026, 5, 5, 8), completed: true);
      await repo.setCompleted(id, DateTime(2026, 5, 5, 21), completed: true);
      final rows = await repo.completionsForHabit(id);
      expect(rows, hasLength(1));
    });

    test('archive hides a habit from the active list', () async {
      final id = await repo.create(name: 'Journal');
      await repo.setArchived(id, true);
      final active = await repo.watchActive().first;
      expect(active, isEmpty);
    });
  });

  group('TaskRepository', () {
    late TaskRepository repo;

    setUp(() => repo = TaskRepository(db));

    test('completing a non-recurring task just marks it done', () async {
      final id = await repo.create(title: 'Buy milk');
      final task = (await repo.getById(id))!;
      await repo.setCompleted(task, true);
      final after = (await repo.getById(id))!;
      expect(after.isCompleted, isTrue);
      expect(after.completedAt, isNotNull);
    });

    test(
      'completing a recurring task spawns the next occurrence once',
      () async {
        final id = await repo.create(
          title: 'Standup',
          dueDate: DateTime(2026, 6, 1),
          recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        );
        final task = (await repo.getById(id))!;
        await repo.setCompleted(task, true);
        await repo.setCompleted((await repo.getById(id))!, true);
        final all = await db.select(db.tasks).get();
        expect(all, hasLength(2));
        final next = all.firstWhere((t) => !t.isCompleted);
        expect(next.dueDate, DateTime(2026, 6, 2));
      },
    );

    test('an undated open task appears in today', () async {
      await repo.create(title: 'Inbox item');
      final done = (await repo.getById(await repo.create(title: 'Finished')))!;
      await repo.setCompleted(done, true);

      final today = await repo.watchToday().first;
      final titles = today.map((e) => e.task.title);
      expect(titles, contains('Inbox item'));
      expect(titles, isNot(contains('Finished')));
    });

    test('subtasks are linked to their parent', () async {
      final parent = await repo.create(title: 'Trip');
      await repo.create(title: 'Book hotel', parentId: parent);
      final subs = await repo.subtasksOf(parent);
      expect(subs.single.title, 'Book hotel');
      expect(subs.single.parentId, parent);
    });
  });
}
