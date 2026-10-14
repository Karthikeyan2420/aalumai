import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';

enum NoteKind {
  note,
  journal;

  static NoteKind fromIndex(int v) =>
      NoteKind.values[v.clamp(0, NoteKind.values.length - 1)];
}

class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;

  Stream<List<Note>> watchAll() =>
      (_db.select(_db.notes)..orderBy([
        (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ])).watch();

  Stream<List<Note>> search(String query) {
    final q = '%${query.trim()}%';
    return (_db.select(_db.notes)
          ..where((t) => t.title.like(q) | t.body.like(q))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<Note?> getById(int id) =>
      (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create({
    String title = '',
    String body = '',
    NoteKind kind = NoteKind.note,
    String tagIds = '',
  }) {
    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            title: Value(title),
            body: Value(body),
            kind: Value(kind.index),
            tagIds: Value(tagIds),
          ),
        );
  }

  Future<void> updateNote(Note note) async {
    await _db
        .update(_db.notes)
        .replace(note.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();

  Future<void> togglePinned(Note note) => (_db.update(_db.notes)..where(
    (t) => t.id.equals(note.id),
  )).write(NotesCompanion(isPinned: Value(!note.isPinned)));

  Future<void> toggleFavorite(Note note) => (_db.update(_db.notes)..where(
    (t) => t.id.equals(note.id),
  )).write(NotesCompanion(isFavorite: Value(!note.isFavorite)));

  Future<void> toggleLocked(Note note, bool locked) => (_db.update(_db.notes)
    ..where(
      (t) => t.id.equals(note.id),
    )).write(NotesCompanion(isLocked: Value(locked)));
}

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(appDatabaseProvider)),
);

final allNotesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).watchAll(),
);
