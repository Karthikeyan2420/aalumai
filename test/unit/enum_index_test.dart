import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/meals/data/meal_repository.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every enum exposes a `fromIndex` that clamps out-of-range values to a valid
/// member. These tests pin that behaviour so corrupt DB rows can never crash.
void main() {
  group('fromIndex clamping', () {
    test('TaskPriority', () {
      expect(TaskPriority.fromIndex(-1), TaskPriority.values.first);
      expect(TaskPriority.fromIndex(999), TaskPriority.values.last);
    });

    test('AccountType', () {
      expect(AccountType.fromIndex(-5), AccountType.values.first);
      expect(AccountType.fromIndex(999), AccountType.values.last);
    });

    test('TransactionType', () {
      expect(TransactionType.fromIndex(-5), TransactionType.values.first);
      expect(TransactionType.fromIndex(999), TransactionType.values.last);
    });

    test('CategoryKind', () {
      expect(CategoryKind.fromIndex(-5), CategoryKind.values.first);
      expect(CategoryKind.fromIndex(999), CategoryKind.values.last);
    });

    test('NoteKind', () {
      expect(NoteKind.fromIndex(-5), NoteKind.values.first);
      expect(NoteKind.fromIndex(999), NoteKind.values.last);
    });

    test('MealType', () {
      expect(MealType.fromIndex(-5), MealType.values.first);
      expect(MealType.fromIndex(999), MealType.values.last);
    });

    test('AlarmChallenge', () {
      expect(AlarmChallenge.fromIndex(-5), AlarmChallenge.values.first);
      expect(AlarmChallenge.fromIndex(999), AlarmChallenge.values.last);
    });
  });
}
