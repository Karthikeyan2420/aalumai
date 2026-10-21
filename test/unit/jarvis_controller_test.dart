import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/jarvis/data/llama_runtime.dart';
import 'package:aalumai/features/jarvis/domain/chat_models.dart';
import 'package:aalumai/features/jarvis/presentation/jarvis_controller.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEngine implements LlamaEngine {
  LlamaRuntimeState _state = LlamaRuntimeState.ready;

  /// Scripted replies; one entry per [chat] call, each a list of tokens.
  final List<List<String>> queuedReplies = [];
  final List<List<ChatTurn>> conversations = [];

  void setStateForTest(LlamaRuntimeState value) => _state = value;

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
    conversations.add(history);
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

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue, reason: 'condition never became true');
}

void main() {
  late ProviderContainer container;
  late _FakeEngine engine;
  late AppDatabase db;
  late JarvisChatController notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = _FakeEngine();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        llamaRuntimeProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    notifier = container.read(jarvisChatProvider.notifier);
  });

  test('a plain reply streams into the chat with the system prompt first',
      () async {
    engine.queuedReplies.add(['Hello', ' there.']);

    await notifier.send('hi');

    final state = container.read(jarvisChatProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.messages.map((m) => m.text), ['hi', 'Hello there.']);
    expect(engine.conversations.single.first.role, ChatRole.system);
  });

  test('a valid action runs the tool and feeds the result back', () async {
    engine.queuedReplies.add([
      'On it.\n```action\n'
          '{"tool": "task.create", "args": {"title": "Buy milk"}}\n```',
    ]);
    engine.queuedReplies.add(['Done — task created.']);

    await notifier.send('make a task for milk');

    final tasks = await container.read(taskRepositoryProvider).watchAll().first;
    expect(tasks.single.task.title, 'Buy milk');

    final state = container.read(jarvisChatProvider);
    expect(state.messages.last.text, 'Done — task created.');
    final toolMessages = state.messages.where((m) => m.isToolResult).toList();
    expect(toolMessages.single.toolName, 'task.create');
    expect(toolMessages.single.text, contains('Buy milk'));

    // The follow-up generation saw the tool result.
    expect(engine.conversations, hasLength(2));
    expect(
      engine.conversations.last.last.content,
      startsWith('TOOL RESULT [task.create]'),
    );
  });

  test('a declined confirmation never touches the store', () async {
    await container.read(taskRepositoryProvider).create(title: 'Buy milk');
    engine.queuedReplies.add([
      '```action\n{"tool": "task.delete", "args": {"match": "Buy milk"}}\n```',
    ]);
    engine.queuedReplies.add(['Understood, I left it alone.']);

    final running = notifier.send('delete my task');
    await _waitUntil(
      () => container.read(jarvisChatProvider).pendingConfirmation != null,
    );

    var state = container.read(jarvisChatProvider);
    expect(state.busy, isFalse);
    expect(state.pendingConfirmation!.tool, 'task.delete');
    expect(state.pendingConfirmation!.description, contains('Buy milk'));

    notifier.resolveConfirmation(false);
    await running;

    final tasks = await container.read(taskRepositoryProvider).watchAll().first;
    expect(tasks, hasLength(1));

    state = container.read(jarvisChatProvider);
    expect(state.messages.last.text, 'Understood, I left it alone.');
    final declined = state.messages
        .where((m) => m.toolName == 'task.delete')
        .toList();
    expect(declined.single.text, contains('declined'));
  });

  test('an accepted confirmation executes the action', () async {
    final id = await container
        .read(taskRepositoryProvider)
        .create(title: 'Buy milk');
    engine.queuedReplies.add([
      '```action\n{"tool": "task.delete", "args": {"match": "Buy milk"}}\n```',
    ]);
    engine.queuedReplies.add(['The task is gone now.']);

    final running = notifier.send('delete my task');
    await _waitUntil(
      () => container.read(jarvisChatProvider).pendingConfirmation != null,
    );
    notifier.resolveConfirmation(true);
    await running;

    expect(
      await container.read(taskRepositoryProvider).getById(id),
      isNull,
    );
    expect(
      container.read(jarvisChatProvider).messages.last.text,
      'The task is gone now.',
    );
  });

  test('an invalid action block is reported back and the model recovers',
      () async {
    engine.queuedReplies.add(['```action\n{"tool": ']);
    engine.queuedReplies.add(['Sorry about that.']);

    await notifier.send('do the impossible');

    final state = container.read(jarvisChatProvider);
    expect(state.error, isNull);
    expect(state.messages.last.text, 'Sorry about that.');
    final protocol = state.messages
        .where((m) => m.toolName == 'protocol')
        .toList();
    expect(protocol, hasLength(1));
    expect(protocol.single.text, contains('truncated'));
  });

  test('an unknown tool is fed back without killing the loop', () async {
    engine.queuedReplies.add([
      '```action\n{"tool": "shell.exec", "args": {}}\n```',
    ]);
    engine.queuedReplies.add(['I cannot run shell commands.']);

    await notifier.send('run ls');

    final state = container.read(jarvisChatProvider);
    expect(state.messages.last.text, 'I cannot run shell commands.');
    expect(
      state.messages.where((m) => m.toolName == 'shell.exec').single.text,
      contains('Unknown tool'),
    );
  });

  test('sending while the model is unloaded fails cleanly', () async {
    engine.setStateForTest(LlamaRuntimeState.idle);

    await notifier.send('hi');

    final state = container.read(jarvisChatProvider);
    expect(state.messages, isEmpty);
    expect(state.error, contains('not loaded'));
    expect(state.busy, isFalse);
  });

  test('clearChat empties the visible chat', () async {
    engine.queuedReplies.add(['Hello.']);
    await notifier.send('hi');
    notifier.clearChat();
    expect(container.read(jarvisChatProvider).messages, isEmpty);
  });
}
