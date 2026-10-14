import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _txn({
  required int amountPaise,
  required DateTime date,
  int type = 1,
  int? categoryId,
}) {
  return Transaction(
    id: 0,
    accountId: 1,
    categoryId: categoryId,
    type: type,
    amountPaise: amountPaise,
    date: date,
    note: '',
    paymentMethod: 0,
    attachmentPath: '',
    isReconciled: false,
    createdAt: date,
  );
}

void main() {
  final month = DateTime(2026, 3, 15);
  final names = {1: 'Food', 2: 'Rent'};

  test('groups, filters by month and sums per category', () {
    final result = aggregateSpending(
      month: month,
      categoryNames: names,
      transactions: [
        _txn(amountPaise: 1500, date: DateTime(2026, 3, 2), categoryId: 1),
        _txn(amountPaise: 500, date: DateTime(2026, 3, 9), categoryId: 1),
        _txn(amountPaise: 9000, date: DateTime(2026, 3, 4), categoryId: 2),
        // Ignored: previous month.
        _txn(amountPaise: 9999, date: DateTime(2026, 2, 28), categoryId: 1),
        // Ignored: income.
        _txn(
          amountPaise: 5000,
          date: DateTime(2026, 3, 10),
          type: 0,
          categoryId: 1,
        ),
      ],
    );

    expect(result, hasLength(2));
    expect(result.first.label, 'Rent');
    expect(result.first.amountPaise, 9000);
    expect(result.last.label, 'Food');
    expect(result.last.amountPaise, 2000);
  });

  test('unknown and uncategorised expenses use a placeholder label', () {
    final result = aggregateSpending(
      month: month,
      categoryNames: names,
      transactions: [
        _txn(amountPaise: 100, date: DateTime(2026, 3, 1), categoryId: 77),
        _txn(amountPaise: 200, date: DateTime(2026, 3, 1)),
      ],
    );
    expect(result, hasLength(2));
    expect(result.every((s) => s.label == '—'), isTrue);
  });

  test('empty input yields an empty breakdown', () {
    expect(
      aggregateSpending(month: month, categoryNames: names, transactions: []),
      isEmpty,
    );
  });
}
