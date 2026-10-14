import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';

class SavingsGoalProgress {
  const SavingsGoalProgress({required this.goal, required this.savedPaise});

  final SavingsGoal goal;
  final int savedPaise;

  double get ratio =>
      goal.targetPaise <= 0
          ? 0
          : (savedPaise / goal.targetPaise).clamp(0.0, 1.0).toDouble();

  bool get isReached => savedPaise >= goal.targetPaise;
}

class SavingsRepository {
  SavingsRepository(this._db);

  final AppDatabase _db;

  Stream<List<SavingsGoal>> watchGoals() =>
      (_db.select(_db.savingsGoals)..orderBy([
        (t) => OrderingTerm(expression: t.isCompleted),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])).watch();

  Future<int> createGoal({
    required String name,
    required int targetPaise,
    DateTime? targetDate,
    String note = '',
  }) {
    return _db
        .into(_db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: name,
            targetPaise: targetPaise,
            targetDate: Value(targetDate),
            note: Value(note),
          ),
        );
  }

  Future<void> updateGoal(SavingsGoal goal) =>
      _db.update(_db.savingsGoals).replace(goal);

  Future<void> deleteGoal(int id) =>
      (_db.delete(_db.savingsGoals)..where((t) => t.id.equals(id))).go();

  Stream<List<SavingsContribution>> watchContributions(int goalId) =>
      (_db.select(_db.savingsContributions)
            ..where((t) => t.goalId.equals(goalId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Records a contribution (or withdrawal). The contribution is *not* also
  /// recorded as income, avoiding double counting in the finance module.
  Future<void> addContribution({
    required int goalId,
    required int amountPaise,
    required DateTime date,
    bool isWithdrawal = false,
    String note = '',
    int? transactionId,
  }) {
    return _db
        .into(_db.savingsContributions)
        .insert(
          SavingsContributionsCompanion.insert(
            goalId: goalId,
            amountPaise: amountPaise,
            date: date,
            isWithdrawal: Value(isWithdrawal),
            note: Value(note),
            transactionId: Value(transactionId),
          ),
        );
  }

  Future<int> savedFor(int goalId) async {
    final rows =
        await (_db.select(_db.savingsContributions)
          ..where((t) => t.goalId.equals(goalId))).get();
    var total = 0;
    for (final r in rows) {
      total += r.isWithdrawal ? -r.amountPaise : r.amountPaise;
    }
    return total;
  }

  Future<List<SavingsGoalProgress>> progressList() async {
    final goals =
        await (_db.select(_db.savingsGoals)
          ..where((t) => t.isCompleted.equals(false))).get();
    final result = <SavingsGoalProgress>[];
    for (final g in goals) {
      result.add(
        SavingsGoalProgress(goal: g, savedPaise: await savedFor(g.id)),
      );
    }
    return result;
  }
}

final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => SavingsRepository(ref.watch(appDatabaseProvider)),
);

final savingsGoalsProvider = StreamProvider<List<SavingsGoal>>(
  (ref) => ref.watch(savingsRepositoryProvider).watchGoals(),
);
