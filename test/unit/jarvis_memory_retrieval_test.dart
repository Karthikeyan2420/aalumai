import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 19, 17, 5);

  MemoryRecord memory(
    int id,
    String content, {
    MemoryCategory category = MemoryCategory.fact,
    bool confirmed = true,
    DateTime? updated,
  }) => MemoryRecord(
    id: id,
    content: content,
    category: category,
    confirmed: confirmed,
    createdAt: updated ?? now.subtract(const Duration(days: 40)),
    updatedAt: updated ?? now.subtract(const Duration(days: 40)),
  );

  group('ranking', () {
    final memories = [
      memory(
        1,
        'User drinks filter coffee every morning.',
        updated: now.subtract(const Duration(days: 2)),
      ),
      memory(2, 'User is training for a 10K run in December.'),
      memory(3, 'User prefers dark theme everywhere.'),
      memory(4, "User's daughter is named Ana."),
      memory(5, 'User hates coriander in food.'),
    ];

    test('query matches relevant memories only', () {
      final hits = rankMemories(
        memories: memories,
        query: 'coffee preference',
        now: now,
      );
      expect(hits, isNotEmpty);
      expect(hits.first.record.id, 1);
      expect(hits.map((h) => h.record.id), isNot(contains(2)));
    });

    test('training query surfaces the running goal', () {
      final hits = rankMemories(
        memories: memories,
        query: 'running training',
        now: now,
      );
      expect(hits.map((h) => h.record.id), contains(2));
    });

    test('no query returns everything ordered by recency', () {
      final fresh = [
        memory(1, 'old fact'),
        memory(2, 'brand new fact', updated: now),
      ];
      final hits = rankMemories(memories: fresh, now: now);
      expect(hits.map((h) => h.record.id), [2, 1]);
    });

    test('recent and confirmed memories rank above stale unconfirmed ones', () {
      final recentUnconfirmed = memory(
        10,
        'User mentioned a dentist appointment.',
        confirmed: false,
        updated: now.subtract(const Duration(hours: 2)),
      );
      final staleConfirmed = memory(11, 'User once mentioned a dentist.');
      final hits = rankMemories(
        memories: [staleConfirmed, recentUnconfirmed],
        query: 'dentist',
        now: now,
      );
      expect(hits.first.record.id, 10);
    });

    test('respects limit and token budget', () {
      final many = [
        for (var i = 0; i < 20; i++)
          memory(i, 'Fact number $i about the user daily routine.'),
      ];
      final hits = rankMemories(
        memories: many,
        query: 'fact user',
        now: now,
        limit: 5,
      );
      expect(hits.length, lessThanOrEqualTo(5));

      final tight = rankMemories(
        memories: many,
        query: 'fact user',
        now: now,
        tokenBudget: 40,
      );
      expect(tight.length, lessThan(5));
      expect(tight, isNotEmpty);
    });
  });

  group('forget matching', () {
    final memories = [
      memory(1, 'User drinks filter coffee every morning.'),
      memory(2, 'User is training for a 10K run in December.'),
      memory(3, 'Coffee beans should be ground coarse.'),
    ];

    test('substring matches multiple candidates', () {
      final matches = matchMemories(memories, 'coffee');
      expect(matches.map((m) => m.id), containsAll([1, 3]));
    });

    test('prefix match ranks first', () {
      final matches = matchMemories(memories, 'coffee beans');
      expect(matches.first.id, 3);
    });

    test('all-words match without contiguous substring', () {
      final matches = matchMemories(memories, 'training december');
      expect(matches.map((m) => m.id), [2]);
    });

    test('no match returns empty', () {
      expect(matchMemories(memories, 'swimming'), isEmpty);
      expect(matchMemories(memories, '  '), isEmpty);
    });
  });

  test('category parsing falls back to fact', () {
    expect(memoryCategoryFromDb('preference'), MemoryCategory.preference);
    expect(memoryCategoryFromDb('bogus'), MemoryCategory.fact);
    expect(memoryCategoryFromDb(null), MemoryCategory.fact);
  });
}
