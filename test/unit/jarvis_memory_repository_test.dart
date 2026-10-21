import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/jarvis/data/memory_repository.dart';
import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MemoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MemoryRepository(db);
  });

  tearDown(() => db.close());

  test('save maps a row to the domain record with defaults', () async {
    final id = await repo.save(content: 'User drinks filter coffee.');
    expect(id, greaterThan(0));

    final all = await repo.all();
    expect(all, hasLength(1));
    expect(all.first.id, id);
    expect(all.first.content, 'User drinks filter coffee.');
    expect(all.first.category, MemoryCategory.fact);
    expect(all.first.confirmed, isFalse);
  });

  test('category round-trips through the text column', () async {
    await repo.save(
      content: 'Prefers metric units.',
      category: MemoryCategory.preference,
    );
    final all = await repo.all();
    expect(all.first.category, MemoryCategory.preference);
  });

  test('an exact duplicate refreshes the row instead of stacking copies',
      () async {
    final first = await repo.save(content: 'User hates coriander.');
    final again = await repo.save(content: 'User hates coriander.');
    expect(again, first);
    expect(await repo.count(), 1);
  });

  test('re-saving never silently un-confirms a confirmed memory', () async {
    final id = await repo.save(content: 'Daughter is Ana.', confirmed: true);
    await repo.save(content: 'Daughter is Ana.');
    final record = await repo.getById(id);
    expect(record!.confirmed, isTrue);
  });

  test('setConfirmed flips the flag', () async {
    final id = await repo.save(content: 'Training for a 10K.');
    await repo.setConfirmed(id, true);
    expect((await repo.getById(id))!.confirmed, isTrue);
    await repo.setConfirmed(id, false);
    expect((await repo.getById(id))!.confirmed, isFalse);
  });

  test('delete removes the row; getById misses afterwards', () async {
    final id = await repo.save(content: 'Temp fact.');
    await repo.delete(id);
    expect(await repo.getById(id), isNull);
    expect(await repo.all(), isEmpty);
  });

  test('all() orders by recency, newest first', () async {
    await repo.save(content: 'Older fact.');
    await repo.save(content: 'Newer fact.');
    final all = await repo.all();
    expect(all.first.content, 'Newer fact.');
  });

  test('watchAll emits the current set and later changes', () async {
    await repo.save(content: 'First.');
    expect((await repo.watchAll().first).map((m) => m.content), ['First.']);

    await repo.save(content: 'Second.');
    expect(
      (await repo.watchAll().first).map((m) => m.content),
      ['Second.', 'First.'],
    );
  });

  test('count reflects the store', () async {
    expect(await repo.count(), 0);
    await repo.save(content: 'One.');
    await repo.save(content: 'Two.');
    expect(await repo.count(), 2);
  });
}
