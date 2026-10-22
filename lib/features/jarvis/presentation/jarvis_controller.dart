import 'dart:async';

import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/jarvis/data/llama_runtime.dart';
import 'package:aalumai/features/jarvis/data/memory_repository.dart';
import 'package:aalumai/features/jarvis/data/model_manager.dart';
import 'package:aalumai/features/jarvis/data/tool_executor.dart';
import 'package:aalumai/features/jarvis/domain/action_protocol.dart';
import 'package:aalumai/features/jarvis/domain/chat_models.dart';
import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:aalumai/features/jarvis/domain/prompt_builder.dart';
import 'package:aalumai/features/jarvis/domain/safety_policy.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One chat line as shown in the UI.
class JarvisChatMessage {
  const JarvisChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.toolName,
  });

  final int id;
  final ChatRole role;
  final String text;

  /// Set on `TOOL RESULT` turns so the UI can render them as compact,
  /// dimmed system lines instead of chat bubbles.
  final String? toolName;

  bool get isToolResult => toolName != null;

  JarvisChatMessage copyWith({String? text}) => JarvisChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    toolName: toolName,
  );
}

/// A sensitive/destructive/external action waiting for the user's yes/no.
class JarvisConfirmation {
  const JarvisConfirmation({
    required this.tool,
    required this.description,
  });

  final String tool;
  final String description;
}

class JarvisChatState {
  const JarvisChatState({
    this.messages = const [],
    this.busy = false,
    this.pendingConfirmation,
    this.error,
    this.engineState = LlamaRuntimeState.idle,
    this.modelReady = false,
  });

  final List<JarvisChatMessage> messages;
  final bool busy;
  final JarvisConfirmation? pendingConfirmation;
  final String? error;
  final LlamaRuntimeState engineState;

  /// A model file is installed (independent of whether it is loaded).
  final bool modelReady;

  JarvisChatState copyWith({
    List<JarvisChatMessage>? messages,
    bool? busy,
    JarvisConfirmation? pendingConfirmation,
    bool clearConfirmation = false,
    String? error,
    bool clearError = false,
    LlamaRuntimeState? engineState,
    bool? modelReady,
  }) => JarvisChatState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    pendingConfirmation:
        clearConfirmation ? null : (pendingConfirmation ?? this.pendingConfirmation),
    error: clearError ? null : (error ?? this.error),
    engineState: engineState ?? this.engineState,
    modelReady: modelReady ?? this.modelReady,
  );
}

final jarvisChatProvider =
    NotifierProvider<JarvisChatController, JarvisChatState>(
      JarvisChatController.new,
    );

/// Drives one chat session: builds prompts, streams generations, parses the
/// action protocol, consults the safety policy, executes tools, and feeds
/// results back — all without ever letting a tool or model failure kill the
/// loop.
class JarvisChatController extends Notifier<JarvisChatState> {
  /// Domain-history (system prompt excluded; rebuilt fresh each turn).
  final List<ChatTurn> _history = [];
  int _nextMessageId = 1;
  Completer<bool>? _confirmationCompleter;
  bool _stopRequested = false;

  @override
  JarvisChatState build() {
    final runtime = ref.watch(llamaRuntimeProvider);
    final sub = runtime.states.listen((next) {
      state = state.copyWith(engineState: next);
    });
    ref.onDispose(sub.cancel);
    refreshModelReady();
    return JarvisChatState(engineState: runtime.state);
  }

  /// Re-checks whether a model file is installed; call after install/delete.
  Future<void> refreshModelReady() async {
    final path = await ref.read(jarvisModelManagerProvider).modelPathIfPresent();
    state = state.copyWith(modelReady: path != null);
  }

  /// Loads the installed model into memory using the user's settings.
  Future<void> loadModel() async {
    final manager = ref.read(jarvisModelManagerProvider);
    final prefs = ref.read(appPreferencesProvider);
    final path = await manager.modelPathIfPresent();
    if (path == null) {
      state = state.copyWith(
        error: 'No model is installed yet. Download or import one first.',
      );
      return;
    }
    state = state.copyWith(clearError: true);
    try {
      await ref.read(llamaRuntimeProvider).load(
        modelPath: path,
        contextSize: prefs.jarvisModelContextSize,
        threads: prefs.jarvisModelThreads,
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> unloadModel() async {
    await ref.read(llamaRuntimeProvider).unload();
  }

  /// Cancels the in-flight generation (partial reply is kept as history).
  Future<void> stop() async {
    _stopRequested = true;
    await ref.read(llamaRuntimeProvider).stop();
  }

  /// Answers the pending confirmation dialog.
  void resolveConfirmation(bool confirmed) {
    final completer = _confirmationCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(confirmed);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void clearChat() {
    _history.clear();
    state = state.copyWith(messages: const [], clearError: true);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final runtime = ref.read(llamaRuntimeProvider);
    if (runtime.state != LlamaRuntimeState.ready) {
      state = state.copyWith(
        error: 'The model is not loaded. Load it from the Model tab first.',
      );
      return;
    }

    _stopRequested = false;
    state = state.copyWith(busy: true, clearError: true, clearConfirmation: true);
    _addMessage(role: ChatRole.user, text: trimmed);
    _history.add(ChatTurn.user(trimmed));
    // Note: _history mirrors only domain turns; UI messages are separate so
    // tool results can be styled differently while staying in the context.

    try {
      await _runToolLoop();
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return;
    }
    state = state.copyWith(busy: false);
  }

  Future<void> _runToolLoop() async {
    final runtime = ref.read(llamaRuntimeProvider);
    final executor = ref.read(jarvisToolExecutorProvider);
    final memoryRepo = ref.read(jarvisMemoryRepositoryProvider);
    final prefs = ref.read(appPreferencesProvider);

    for (var step = 0; step < 4; step++) {
      if (_stopRequested) return;

      final memories = rankMemories(
        memories: await memoryRepo.all(),
        limit: 6,
      );
      final systemPrompt = buildSystemPrompt(
        PromptContext(
          now: DateTime.now(),
          uiLocale: ref.read(localeCodeProvider) ?? 'en',
          memories: [for (final hit in memories) hit.record.content],
          workspaceFacts: await _workspaceFacts(),
        ),
      );
      final conversation = buildConversation(
        systemPrompt: systemPrompt,
        history: _history,
        tokenBudget: prefs.jarvisModelContextSize,
      );

      // Nudge the newest user turn out of Qwen3's thinking mode (the plugin
      // cannot pass `enable_thinking=false`; the `/no_think` soft switch is
      // the only lever). The stored history stays untouched.
      if (conversation.isNotEmpty &&
          conversation.last.role == ChatRole.user) {
        conversation[conversation.length - 1] =
            withNoThinkDirective(conversation.last);
      }

      final assistantId = _addMessage(role: ChatRole.assistant, text: '');
      final buffer = StringBuffer();
      await for (final token in runtime.chat(history: conversation)) {
        buffer.write(token);
        _updateMessage(assistantId, stripThinking(buffer.toString()));
      }
      final raw = stripThinking(buffer.toString());

      if (_stopRequested) {
        _history.add(ChatTurn.assistant(raw));
        return;
      }

      final parsed = parseAction(raw);
      if (parsed is ActionParseText) {
        _history.add(ChatTurn.assistant(parsed.text));
        _updateMessage(assistantId, parsed.text);
        return;
      }
      if (parsed is ActionParseInvalid) {
        _history.add(ChatTurn.assistant(raw));
        _history.add(
          toolResultTurn(
            'protocol',
            'Your reply was not valid: ${parsed.reason} '
            'Reply again, either in plain text or with exactly one '
            '```action fence.',
          ),
        );
        _addMessage(
          role: ChatRole.user,
          text: 'Action rejected: ${parsed.reason}',
          toolName: 'protocol',
        );
        continue;
      }

      // A well-formed action request.
      final request = (parsed as ActionParseRequest).request;
      _history.add(ChatTurn.assistant(raw));
      _updateMessage(assistantId, raw);

      final decision = decideAction(request.tool);
      if (decision == Decision.unknownTool) {
        final outcome = await executor.execute(request.tool, request.args);
        _feedToolResult(request.tool, outcome.message);
        continue;
      }

      if (decision == Decision.confirm) {
        final completer = Completer<bool>();
        _confirmationCompleter = completer;
        state = state.copyWith(
          busy: false,
          pendingConfirmation: JarvisConfirmation(
            tool: request.tool,
            description: describeAction(request.tool, request.args),
          ),
        );
        final confirmed = await completer.future;
        _confirmationCompleter = null;
        state = state.copyWith(busy: true, clearConfirmation: true);
        if (!confirmed) {
          _feedToolResult(
            request.tool,
            'The user declined this action. Do not retry it; acknowledge '
            'and move on.',
          );
          continue;
        }
      }

      final outcome = await executor.execute(request.tool, request.args);
      _feedToolResult(request.tool, outcome.message);
    }

    // Ran out of tool-loop steps: tell the model to stop acting for now.
    _history.add(
      toolResultTurn(
        'protocol',
        'Too many actions in one request. Give the user a plain-language '
        'summary of what you did and stop.',
      ),
    );
    _addMessage(
      role: ChatRole.user,
      text: 'Stopping: too many actions in one request.',
      toolName: 'protocol',
    );
  }

  void _feedToolResult(String tool, String message) {
    _history.add(toolResultTurn(tool, message));
    _addMessage(role: ChatRole.user, text: message, toolName: tool);
  }

  Future<List<String>> _workspaceFacts() async {
    final facts = <String>[];
    try {
      final today = await ref.read(taskRepositoryProvider).watchToday().first;
      final open = today.where((row) => !row.task.isCompleted).length;
      facts.add('$open task(s) due today.');
    } on Exception {
      // A failing read must never break the chat.
    }
    try {
      final next = await ref.read(alarmRepositoryProvider).nextAlarm();
      if (next != null) {
        final hour = next.hour.toString().padLeft(2, '0');
        final minute = next.minute.toString().padLeft(2, '0');
        final label = next.label.isEmpty ? '' : ' "${next.label}"';
        facts.add('Next alarm: $hour:$minute$label.');
      }
    } on Exception {
      // Ignored: facts are best-effort.
    }
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final events = await ref
          .read(eventRepositoryProvider)
          .eventsBetween(
            todayStart,
            todayStart.add(const Duration(days: 1)),
          );
      facts.add('${events.length} event(s) today.');
    } on Exception {
      // Ignored: facts are best-effort.
    }
    return facts;
  }

  int _addMessage({
    required ChatRole role,
    required String text,
    String? toolName,
  }) {
    final id = _nextMessageId++;
    final message = JarvisChatMessage(
      id: id,
      role: role,
      text: text,
      toolName: toolName,
    );
    state = state.copyWith(messages: [...state.messages, message]);
    return id;
  }

  void _updateMessage(int id, String text) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == id ? message.copyWith(text: text) : message,
      ],
    );
  }
}
