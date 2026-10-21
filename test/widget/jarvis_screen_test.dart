import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/widgets/common.dart';
import 'package:aalumai/features/jarvis/data/llama_runtime.dart';
import 'package:aalumai/features/jarvis/data/memory_repository.dart';
import 'package:aalumai/features/jarvis/domain/chat_models.dart';
import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:aalumai/features/jarvis/jarvis_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEngine implements LlamaEngine {
  LlamaRuntimeState _state = LlamaRuntimeState.ready;
  final List<List<String>> queuedReplies = [];

  @override
  LlamaRuntimeState get state => _state;

  @override
  Stream<LlamaRuntimeState> get states => const Stream.empty();

  @override
  Stream<double> get loadProgress => const Stream.empty();

  @override
  Future<void> load({
    required String modelPath,
    int contextSize = 4096,
    int threads = 4,
  }) async {
    _state = LlamaRuntimeState.ready;
  }

  @override
  Future<void> unload() async {
    _state = LlamaRuntimeState.idle;
  }

  @override
  Stream<String> chat({
    required List<ChatTurn> history,
    String template = 'chatml',
    LlamaGenParams params = const LlamaGenParams(),
  }) {
    if (queuedReplies.isEmpty) return const Stream.empty();
    return Stream.fromIterable(queuedReplies.removeAt(0));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<String>> supportedTemplates() async => const ['chatml'];

  @override
  Future<({int tokensUsed, int contextSize})?> contextInfo() async => null;
}

class _FakeMemoryRepository implements MemoryRepository {
  List<MemoryRecord> memories;

  _FakeMemoryRepository([this.memories = const []]);

  @override
  Future<List<MemoryRecord>> all() async => memories;

  @override
  Stream<List<MemoryRecord>> watchAll() => Stream.value(memories);

  @override
  Future<MemoryRecord?> getById(int id) async {
    for (final memory in memories) {
      if (memory.id == id) return memory;
    }
    return null;
  }

  @override
  Future<int> count() async => memories.length;

  @override
  Future<int> save({
    required String content,
    MemoryCategory category = MemoryCategory.fact,
    bool confirmed = false,
  }) async =>
      1;

  @override
  Future<void> setConfirmed(int id, bool confirmed) async {}

  @override
  Future<void> delete(int id) async {}
}

/// Bounded pumping: `pumpAndSettle` waits forever while the busy spinner
/// animates, so advance a fixed number of frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<Widget> _wrap({_FakeEngine? engine, _FakeMemoryRepository? memories}) async {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(
        AppDatabase.forTesting(NativeDatabase.memory()),
      ),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      llamaRuntimeProvider.overrideWithValue(engine ?? _FakeEngine()),
      jarvisMemoryRepositoryProvider.overrideWithValue(
        memories ?? _FakeMemoryRepository(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const JarvisScreen(),
    ),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('opens on the chat tab with an empty state', (tester) async {
    await tester.pumpWidget(await _wrap());
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(JarvisScreen)));
    expect(find.text(l10n.jarvisChat), findsOneWidget);
    expect(find.text(l10n.jarvisModel), findsOneWidget);
    expect(find.text(l10n.jarvisMemories), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    // No speech service in the test environment: the hold-to-talk mic stays
    // hidden while the always-present read-aloud toggle remains.
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byTooltip(l10n.jarvisSpeakReplies), findsOneWidget);
  });

  testWidgets('sends a message and renders the streamed reply', (
    tester,
  ) async {
    final engine = _FakeEngine()..queuedReplies.add(['Hello', ' there.']);
    await tester.pumpWidget(await _wrap(engine: engine));
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(JarvisScreen)));
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.jarvisSend));
    await pumpFrames(tester);

    expect(find.text('hi'), findsOneWidget);
    expect(find.text('Hello there.'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('a sensitive action opens the confirmation sheet', (
    tester,
  ) async {
    final engine =
        _FakeEngine()
          ..queuedReplies.add([
            '```action\n{"tool": "task.delete", "args": {"match": "Buy milk"}}\n```',
          ])
          ..queuedReplies.add(['Understood.']);
    await tester.pumpWidget(await _wrap(engine: engine));
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(JarvisScreen)));
    await tester.enterText(find.byType(TextField), 'delete my task');
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.jarvisSend));
    await pumpFrames(tester);

    expect(find.text(l10n.jarvisAllowAction), findsOneWidget);

    await tester.tap(find.text(l10n.jarvisDecline));
    await pumpFrames(tester);

    expect(find.text(l10n.jarvisAllowAction), findsNothing);
    expect(find.text('Understood.'), findsOneWidget);
  });

  testWidgets('memories tab lists saved memories with confirm control', (
    tester,
  ) async {
    final memories = _FakeMemoryRepository([
      MemoryRecord(
        id: 1,
        content: 'User prefers metric units',
        category: MemoryCategory.preference,
        confirmed: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(await _wrap(memories: memories));
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(JarvisScreen)));
    await tester.tap(find.text(l10n.jarvisMemories));
    await pumpFrames(tester);

    expect(find.text('User prefers metric units'), findsOneWidget);
    expect(find.text(l10n.jarvisConfirmMemory), findsOneWidget);
    expect(find.byTooltip(l10n.jarvisForgetMemory), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('model tab shows install status and download action', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(JarvisScreen)));
    await tester.tap(find.text(l10n.jarvisModel));
    await pumpFrames(tester);

    expect(find.text(l10n.jarvisNoModel), findsOneWidget);
    expect(find.text(l10n.jarvisDownloadModel), findsOneWidget);
    expect(find.text(l10n.jarvisImportModel), findsOneWidget);
    expect(find.text(l10n.jarvisCpuThreads), findsOneWidget);
    expect(find.text(l10n.jarvisContextSize), findsOneWidget);
    expect(find.text(l10n.jarvisLoadModel), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text(l10n.jarvisBriefingToggle), findsOneWidget);
  });
}


