import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/recurrence.dart';
import '../../../core/utils/money.dart';

enum AccountType {
  cash,
  bank,
  wallet,
  credit,
  other;

  static AccountType fromIndex(int v) =>
      AccountType.values[v.clamp(0, AccountType.values.length - 1)];
}

enum TransactionType {
  income,
  expense,
  transfer;

  static TransactionType fromIndex(int v) =>
      TransactionType.values[v.clamp(0, TransactionType.values.length - 1)];
}

enum CategoryKind {
  income,
  expense;

  static CategoryKind fromIndex(int v) =>
      CategoryKind.values[v.clamp(0, CategoryKind.values.length - 1)];
}

class AccountBalance {
  const AccountBalance({required this.account, required this.balancePaise});
  final Account account;
  final int balancePaise;
}

class FinanceRepository {
  FinanceRepository(this._db);

  final AppDatabase _db;

  // ---- Accounts -----------------------------------------------------------

  Stream<List<Account>> watchAccounts() =>
      (_db.select(_db.accounts)
            ..where((t) => t.isArchived.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<int> createAccount({
    required String name,
    AccountType type = AccountType.cash,
    int openingBalancePaise = 0,
    String currency = 'INR',
  }) {
    return _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name,
            type: Value(type.index),
            openingBalancePaise: Value(openingBalancePaise),
            currency: Value(currency),
          ),
        );
  }

  Future<void> updateAccount(Account account) =>
      _db.update(_db.accounts).replace(account);

  Future<void> deleteAccount(int id) =>
      (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();

  /// Computes balances: opening balance + income − expense + transfers in/out.
  /// Transfers are neither income nor expense.
  Future<List<AccountBalance>> balances() async {
    final accounts =
        await (_db.select(_db.accounts)
          ..where((t) => t.isArchived.equals(false))).get();
    final txns = await _db.select(_db.transactions).get();
    final map = <int, int>{
      for (final a in accounts) a.id: a.openingBalancePaise,
    };
    for (final t in txns) {
      switch (TransactionType.fromIndex(t.type)) {
        case TransactionType.income:
          map[t.accountId] = (map[t.accountId] ?? 0) + t.amountPaise;
        case TransactionType.expense:
          map[t.accountId] = (map[t.accountId] ?? 0) - t.amountPaise;
        case TransactionType.transfer:
          map[t.accountId] = (map[t.accountId] ?? 0) - t.amountPaise;
          if (t.transferAccountId != null) {
            map[t.transferAccountId!] =
                (map[t.transferAccountId!] ?? 0) + t.amountPaise;
          }
      }
    }
    return [
      for (final a in accounts)
        AccountBalance(account: a, balancePaise: map[a.id] ?? 0),
    ];
  }

  Stream<int> watchTotalBalance() {
    return _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM transactions',
          readsFrom: {_db.accounts, _db.transactions},
        )
        .watch()
        .asyncMap((_) async {
          final list = await balances();
          return list.fold<int>(0, (sum, b) => sum + b.balancePaise);
        });
  }

  // ---- Categories ---------------------------------------------------------

  Stream<List<Category>> watchCategories() =>
      (_db.select(_db.categories)
            ..where((t) => t.isArchived.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<void> seedDefaultCategories() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;
    const expense = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Health',
      'Education',
      'Entertainment',
      'Rent',
      'Other',
    ];
    const income = ['Salary', 'Business', 'Gift', 'Interest', 'Other'];
    var order = 0;
    for (final name in expense) {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: name,
              kind: const Value(1),
              sortOrder: Value(order++),
            ),
          );
    }
    for (final name in income) {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: name,
              kind: const Value(0),
              sortOrder: Value(order++),
            ),
          );
    }
  }

  Future<int> createCategory(
    String name,
    CategoryKind kind, {
    String icon = '',
  }) {
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: Value(kind.index),
            icon: Value(icon),
            isCustom: const Value(true),
          ),
        );
  }

  // ---- Transactions -------------------------------------------------------

  Stream<List<Transaction>> watchTransactions({int limit = 500}) =>
      (_db.select(_db.transactions)
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .watch();

  Stream<List<Transaction>> watchTransactionsBetween(
    DateTime from,
    DateTime to,
  ) =>
      (_db.select(_db.transactions)
            ..where((t) => t.date.isBetweenValues(from, to))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<int> addTransaction({
    required int accountId,
    required TransactionType type,
    required int amountPaise,
    required DateTime date,
    int? categoryId,
    String note = '',
    int? transferAccountId,
    int paymentMethod = 0,
  }) {
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            type: type.index,
            amountPaise: amountPaise,
            date: date,
            categoryId: Value(categoryId),
            note: Value(note),
            transferAccountId: Value(transferAccountId),
            paymentMethod: Value(paymentMethod),
          ),
        );
  }

  Future<int> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountPaise,
    required DateTime date,
    String note = '',
  }) {
    return addTransaction(
      accountId: fromAccountId,
      type: TransactionType.transfer,
      amountPaise: amountPaise,
      date: date,
      note: note,
      transferAccountId: toAccountId,
    );
  }

  Future<void> deleteTransaction(int id) =>
      (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  /// Aggregates income/expense totals for a period, excluding transfers.
  Future<({int income, int expense})> totals(DateTime from, DateTime to) async {
    final txns =
        await (_db.select(_db.transactions)
          ..where((t) => t.date.isBetweenValues(from, to))).get();
    var income = 0;
    var expense = 0;
    for (final t in txns) {
      switch (TransactionType.fromIndex(t.type)) {
        case TransactionType.income:
          income += t.amountPaise;
        case TransactionType.expense:
          expense += t.amountPaise;
        case TransactionType.transfer:
          break;
      }
    }
    return (income: income, expense: expense);
  }

  /// Spending grouped by category id for a period (expenses only).
  Future<Map<int?, int>> expenseByCategory(DateTime from, DateTime to) async {
    final txns =
        await (_db.select(_db.transactions)..where(
          (t) =>
              t.type.equals(TransactionType.expense.index) &
              t.date.isBetweenValues(from, to),
        )).get();
    final map = <int?, int>{};
    for (final t in txns) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountPaise;
    }
    return map;
  }

  // ---- Budgets ------------------------------------------------------------

  Stream<List<Budget>> watchBudgets() =>
      (_db.select(_db.budgets)..where((t) => t.isActive.equals(true))).watch();

  Future<int> createBudget({
    int? categoryId,
    required int amountPaise,
    required DateTime startDate,
    int period = 0,
    int alertThresholdPercent = 80,
  }) {
    return _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            amountPaise: amountPaise,
            startDate: startDate,
            period: Value(period),
            alertThresholdPercent: Value(alertThresholdPercent),
          ),
        );
  }

  Future<void> deleteBudget(int id) =>
      (_db.delete(_db.budgets)..where((t) => t.id.equals(id))).go();

  /// Amount spent against a budget for the current month/year.
  Future<int> budgetSpent(Budget budget, DateTime now) async {
    final from =
        budget.period == 0
            ? DateTime(now.year, now.month, 1)
            : DateTime(now.year, 1, 1);
    final to =
        budget.period == 0
            ? DateTime(now.year, now.month + 1, 0, 23, 59, 59)
            : DateTime(now.year, 12, 31, 23, 59, 59);
    final txns =
        await (_db.select(_db.transactions)..where(
          (t) =>
              t.type.equals(TransactionType.expense.index) &
              t.date.isBetweenValues(from, to) &
              (budget.categoryId == null
                  ? const Constant(true)
                  : t.categoryId.equals(budget.categoryId!)),
        )).get();
    return txns.fold<int>(0, (sum, t) => sum + t.amountPaise);
  }

  // ---- Recurring rules ----------------------------------------------------

  Future<List<RecurringRule>> dueRecurringRules(DateTime now) =>
      (_db.select(_db.recurringRules)..where(
        (t) => t.isActive.equals(true) & t.nextDate.isSmallerOrEqualValue(now),
      )).get();

  /// Confirms a due recurring occurrence: records the transaction and advances
  /// the rule. Recurring rules never silently mark an expense as paid.
  Future<void> confirmRecurring(RecurringRule rule) async {
    await _db.transaction(() async {
      await addTransaction(
        accountId: rule.accountId,
        type: TransactionType.fromIndex(rule.type),
        amountPaise: rule.amountPaise,
        date: DateTime.now(),
        categoryId: rule.categoryId,
        note: rule.note,
      );
      final freq = RecurrenceFrequency.values[rule.frequency.clamp(0, 4)];
      final next = Recurrence(
        frequency: freq,
        interval: rule.interval,
      ).next(rule.nextDate);
      await (_db.update(_db.recurringRules)
        ..where((t) => t.id.equals(rule.id))).write(
        RecurringRulesCompanion(
          nextDate: Value(next),
          lastRun: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<int> createRecurring({
    required int type,
    required int accountId,
    required int amountPaise,
    required DateTime nextDate,
    int? categoryId,
    String note = '',
    int frequency = 1,
    int interval = 1,
  }) {
    return _db
        .into(_db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            type: type,
            accountId: accountId,
            amountPaise: amountPaise,
            nextDate: nextDate,
            categoryId: Value(categoryId),
            note: Value(note),
            frequency: Value(frequency),
            interval: Value(interval),
          ),
        );
  }

  // ---- Debts --------------------------------------------------------------

  Stream<List<Debt>> watchDebts() =>
      (_db.select(_db.debts)
            ..where((t) => t.isClosed.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  Future<int> createDebt({
    required String name,
    required int type,
    required int principalPaise,
    required DateTime startDate,
    double interestRatePercent = 0,
    DateTime? dueDate,
    String contactName = '',
    String note = '',
  }) {
    return _db
        .into(_db.debts)
        .insert(
          DebtsCompanion.insert(
            name: name,
            type: Value(type),
            principalPaise: principalPaise,
            startDate: startDate,
            interestRatePercent: Value(interestRatePercent),
            dueDate: Value(dueDate),
            contactName: Value(contactName),
            note: Value(note),
          ),
        );
  }

  Stream<List<DebtPayment>> watchPayments(int debtId) =>
      (_db.select(_db.debtPayments)
            ..where((t) => t.debtId.equals(debtId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<void> addPayment({
    required int debtId,
    required int principalPaise,
    required int interestPaise,
    required DateTime date,
    int? accountId,
    String note = '',
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              amountPaise: principalPaise + interestPaise,
              principalPaise: Value(principalPaise),
              interestPaise: Value(interestPaise),
              date: date,
              accountId: Value(accountId),
              note: Value(note),
            ),
          );
      // Interest and fees are recorded as an expense; principal repayment is
      // not counted as an ordinary expense.
      if (interestPaise > 0 && accountId != null) {
        await addTransaction(
          accountId: accountId,
          type: TransactionType.expense,
          amountPaise: interestPaise,
          date: date,
          note: 'Interest',
        );
      }
    });
  }

  Future<int> debtPaidPrincipal(int debtId) async {
    final payments =
        await (_db.select(_db.debtPayments)
          ..where((t) => t.debtId.equals(debtId))).get();
    return payments.fold<int>(0, (sum, p) => sum + p.principalPaise);
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(appDatabaseProvider)),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(financeRepositoryProvider).watchAccounts(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(financeRepositoryProvider).watchCategories(),
);

final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(financeRepositoryProvider).watchTransactions(),
);

final totalBalanceProvider = StreamProvider<int>(
  (ref) => ref.watch(financeRepositoryProvider).watchTotalBalance(),
);

final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(financeRepositoryProvider).watchBudgets(),
);

final debtsProvider = StreamProvider<List<Debt>>(
  (ref) => ref.watch(financeRepositoryProvider).watchDebts(),
);

/// Formats paise for display using the app locale.
String formatMoney(int paise, String localeCode) {
  return Money.formatCompact(paise, locale: localeCode);
}

/// One row of the current-month spending breakdown.
class CategorySpend {
  const CategorySpend({required this.label, required this.amountPaise});

  final String label;
  final int amountPaise;
}

/// Expenses within [month] grouped by category, largest first. Pure helper so
/// the aggregation can be unit-tested without a database.
List<CategorySpend> aggregateSpending({
  required List<Transaction> transactions,
  required Map<int, String> categoryNames,
  required DateTime month,
}) {
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  final byCategory = <int?, int>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense.index) continue;
    if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
    byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountPaise;
  }
  final list =
      byCategory.entries.map((e) {
          final key = e.key;
          return CategorySpend(
            label: key == null ? '—' : (categoryNames[key] ?? '—'),
            amountPaise: e.value,
          );
        }).toList()
        ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
  return list;
}

/// Expenses in the current calendar month grouped by category, largest first.
/// Reacts to new transactions and category changes.
final spendingByCategoryProvider = Provider<List<CategorySpend>>((ref) {
  final txns = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return aggregateSpending(
    transactions: txns,
    categoryNames: {for (final c in cats) c.id: c.name},
    month: DateTime.now(),
  );
});
