import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drift-backed store for the assistant's memories (`jarvis_memories`,
/// schema v10). Mapping to the pure [MemoryRecord] shape keeps ranking and
/// retrieval logic in the domain layer.
class MemoryRepository {
  MemoryRepository(this._db);

  final AppDatabase _db;

  Future<List<MemoryRecord>> all() async {
    final rows =
        await (_db.select(_db.jarvisMemories)
              ..orderBy([
                (t) => OrderingTerm.desc(t.updatedAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return rows.map(_toRecord).toList();
  }

  Stream<List<MemoryRecord>> watchAll() =>
      (_db.select(_db.jarvisMemories)
            ..orderBy([
              (t) => OrderingTerm.desc(t.updatedAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch()
          .map((rows) => rows.map(_toRecord).toList());

  Future<MemoryRecord?> getById(int id) async {
    final row =
        await (_db.select(_db.jarvisMemories)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  Future<int> count() async {
    final countColumn = _db.jarvisMemories.id.count();
    final query =
        _db.selectOnly(_db.jarvisMemories)..addColumns([countColumn]);
    final row = await query.getSingle();
    return row.read(countColumn) ?? 0;
  }

  /// Saves [content] and returns its id. An exact duplicate (same text)
  /// refreshes the existing row's timestamp instead of stacking a second
  /// copy; confirming never silently un-confirms.
  Future<int> save({
    required String content,
    MemoryCategory category = MemoryCategory.fact,
    bool confirmed = false,
  }) async {
    final text = content.trim();
    final now = DateTime.now();
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.jarvisMemories)
                ..where((t) => t.content.equals(text))
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        await (_db.update(_db.jarvisMemories)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          JarvisMemoriesCompanion(
            updatedAt: Value(now),
            confirmed: confirmed ? const Value(true) : const Value.absent(),
          ),
        );
        return existing.id;
      }
      return _db.into(_db.jarvisMemories).insert(
        JarvisMemoriesCompanion.insert(
          content: text,
          category: Value(category.name),
          confirmed: Value(confirmed),
        ),
      );
    });
  }

  Future<void> setConfirmed(int id, bool confirmed) =>
      (_db.update(_db.jarvisMemories)..where((t) => t.id.equals(id))).write(
        JarvisMemoriesCompanion(confirmed: Value(confirmed)),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.jarvisMemories)..where((t) => t.id.equals(id))).go();

  static MemoryRecord _toRecord(JarvisMemory row) => MemoryRecord(
    id: row.id,
    content: row.content,
    category: memoryCategoryFromDb(row.category),
    confirmed: row.confirmed,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

final jarvisMemoryRepositoryProvider = Provider<MemoryRepository>(
  (ref) => MemoryRepository(ref.watch(appDatabaseProvider)),
);
