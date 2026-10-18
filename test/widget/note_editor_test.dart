import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/notes/note_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await tester.pump();
}

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Note>> storedNotes(WidgetTester tester) => tester
      .runAsync(() => db.select(db.notes).get())
      .then((v) => v ?? <Note>[]);

  Future<void> pumpHost(WidgetTester tester, {int? noteId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder:
                  (ctx) => TextButton(
                    onPressed: () => showNoteEditor(ctx, noteId: noteId),
                    child: Text(noteId == null ? 'NEW' : 'EDIT'),
                  ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('saving an empty new note persists nothing', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.text('NEW'));
    await _settle(tester);
    expect(find.byType(NoteEditorScreen), findsOneWidget);
    expect(find.text('NEW'), findsNothing);

    await tester.tap(find.byIcon(Icons.check));
    await _settle(tester);

    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(await storedNotes(tester), isEmpty);
  });

  testWidgets('a new note is saved when content is entered', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('NEW'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Weekly plan');
    await tester.enterText(find.byType(TextField).at(1), 'Buy groceries');
    await tester.tap(find.byIcon(Icons.check));
    await _settle(tester);

    final notes = await storedNotes(tester);
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Weekly plan');
    expect(notes.single.body, 'Buy groceries');
  });

  testWidgets('a whitespace-only draft is discarded', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('NEW'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.enterText(find.byType(TextField).at(1), '  \n  ');
    await tester.tap(find.byIcon(Icons.check));
    await _settle(tester);

    expect(await storedNotes(tester), isEmpty);
  });

  testWidgets('leaving an empty draft via back persists nothing', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('NEW'));
    await _settle(tester);

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(await storedNotes(tester), isEmpty);
  });

  testWidgets('the lock button is disabled for a new draft', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('NEW'));
    await _settle(tester);

    final lockButton = find.ancestor(
      of: find.byIcon(Icons.lock_open),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(lockButton).onPressed, isNull);
  });

  testWidgets('editing an existing note updates it in place', (tester) async {
    final id = await repo.create(title: 'Old title', body: 'old body');
    await pumpHost(tester, noteId: id);

    await tester.tap(find.text('EDIT'));
    await _settle(tester);
    expect(find.byType(NoteEditorScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'New title');
    await tester.tap(find.byIcon(Icons.check));
    await _settle(tester);

    final notes = await storedNotes(tester);
    expect(notes, hasLength(1));
    expect(notes.single.id, id);
    expect(notes.single.title, 'New title');
    expect(notes.single.body, 'old body');
  });
}
