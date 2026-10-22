import 'dart:async';

import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/jarvis/conversation/assistant_engine.dart';
import 'package:aalumai/features/jarvis/conversation/assistant_providers.dart';
import 'package:aalumai/features/jarvis/conversation/assistant_reply.dart';
import 'package:aalumai/features/jarvis/web_search/search_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who produced a chat line.
enum ChatRole { user, assistant }

/// One line in the chat transcript.
class JarvisChatMessage {
  const JarvisChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.kind = ReplyKind.answer,
    this.sources = const [],
  });

  final int id;
  final ChatRole role;
  final String text;

  /// Reply classification (drives styling and the source list).
  final ReplyKind kind;

  /// Online attribution shown under online answers.
  final List<SearchResult> sources;

  bool get isUser => role == ChatRole.user;
  bool get isError => kind == ReplyKind.unknown;
  bool get hasSources => sources.isNotEmpty;

  JarvisChatMessage copyWith({String? text}) => JarvisChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    kind: kind,
    sources: sources,
  );
}

/// A sensitive/destructive/external action waiting for the user's yes/no.
class JarvisConfirmation {
  const JarvisConfirmation({
    required this.tool,
    required this.description,
    required this.args,
  });

  final String tool;
  final String description;
  final Map<String, Object?> args;
}

class JarvisChatState {
  const JarvisChatState({
    this.messages = const [],
    this.busy = false,
    this.pendingConfirmation,
    this.error,
    this.listening = false,
    this.wakeWordEnabled = false,
  });

  final List<JarvisChatMessage> messages;
  final bool busy;
  final JarvisConfirmation? pendingConfirmation;
  final String? error;

  /// Whether the microphone is currently active.
  final bool listening;

  /// Whether the wake-word monitor is running.
  final bool wakeWordEnabled;

  JarvisChatState copyWith({
    List<JarvisChatMessage>? messages,
    bool? busy,
    JarvisConfirmation? pendingConfirmation,
    bool clearConfirmation = false,
    String? error,
    bool clearError = false,
    bool? listening,
    bool? wakeWordEnabled,
  }) => JarvisChatState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    pendingConfirmation: clearConfirmation
        ? null
        : (pendingConfirmation ?? this.pendingConfirmation),
    error: clearError ? null : (error ?? this.error),
    listening: listening ?? this.listening,
    wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
  );
}

final jarvisChatProvider =
    NotifierProvider<JarvisChatController, JarvisChatState>(
      JarvisChatController.new,
    );

/// Drives one chat session: feeds the user's text to the deterministic
/// [AssistantEngine], displays the reply, speaks it when enabled, and gates
/// sensitive actions behind a confirmation.
///
/// There is no language model and no model loading — the app is ready the
/// moment it starts.
class JarvisChatController extends Notifier<JarvisChatState> {
  int _nextMessageId = 1;
  Completer<bool>? _confirmationCompleter;

  @override
  JarvisChatState build() {
    final voice = ref.watch(voiceServiceProvider);
    final sub = voice.listeningState.listen((listening) {
      state = state.copyWith(listening: listening);
    });
    ref.onDispose(sub.cancel);
    return const JarvisChatState();
  }

  /// Clears the transcript and the engine's follow-up context.
  void clearChat() {
    ref.read(assistantEngineProvider).reset();
    state = state.copyWith(messages: const [], clearError: true);
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Handles a spoken transcript that starts with the wake word.
  void onWakeWordHeard() {
    state = state.copyWith(
      messages: [
        ...state.messages,
        JarvisChatMessage(
          id: _nextMessageId++,
          role: ChatRole.assistant,
          text: 'Yes? I am listening.',
          kind: ReplyKind.answer,
        ),
      ],
    );
  }

  /// Sends [text] to the engine and appends the reply.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    _addMessage(role: ChatRole.user, text: trimmed, kind: ReplyKind.answer);
    state = state.copyWith(busy: true, clearError: true, clearConfirmation: true);

    try {
      final reply = await ref.read(assistantEngineProvider).respond(trimmed);
      await _handleReply(reply);
    } catch (e) {
      state = state.copyWith(
        busy: false,
        error: 'Something went wrong: $e',
      );
      return;
    }
    state = state.copyWith(busy: false);
  }

  Future<void> _handleReply(AssistantReply reply) async {
    switch (reply.kind) {
      case ReplyKind.confirm:
        final completer = Completer<bool>();
        _confirmationCompleter = completer;
        state = state.copyWith(
          busy: false,
          pendingConfirmation: JarvisConfirmation(
            tool: reply.pendingTool ?? '',
            description: reply.text,
            args: reply.pendingArgs,
          ),
        );
        final confirmed = await completer.future;
        _confirmationCompleter = null;
        state = state.copyWith(busy: true, clearConfirmation: true);
        if (confirmed) {
          final outcome = await ref
              .read(assistantEngineProvider)
              .runConfirmed(reply.pendingTool ?? '', reply.pendingArgs);
          _appendReply(outcome);
        } else {
          _addMessage(
            role: ChatRole.assistant,
            text: 'Okay, I will not do that.',
            kind: ReplyKind.answer,
            speak: false,
          );
        }
        return;
      default:
        _appendReply(reply);
    }
  }

  void _appendReply(AssistantReply reply) {
    _addMessage(
      role: ChatRole.assistant,
      text: reply.text,
      kind: reply.kind,
      sources: reply.sources,
      speak: reply.kind != ReplyKind.unknown,
      spokenOverride: reply.spokenText,
    );
  }

  /// Answers the pending confirmation dialog.
  void resolveConfirmation(bool confirmed) {
    final completer = _confirmationCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(confirmed);
  }

  /// Starts/stops the microphone (push-to-talk). Returns a transcript via
  /// [VoiceService]; the start of dictation is best-effort.
  Future<void> startListening() async {
    final voice = ref.read(voiceServiceProvider);
    final locale = ref.read(appPreferencesProvider).assistantSpeechLanguage;
    await voice.listen(localeId: locale.isEmpty ? null : locale);
  }

  Future<void> stopListening() =>
      ref.read(voiceServiceProvider).stop();

  /// Toggles continuous wake-word monitoring ("Hey Jarvis").
  Future<bool> toggleWakeWord() async {
    final voice = ref.read(voiceServiceProvider);
    if (state.wakeWordEnabled) {
      state = state.copyWith(wakeWordEnabled: false);
      voice.stop();
      return false;
    }
    final locale = ref.read(appPreferencesProvider).assistantSpeechLanguage;
    final ok = await voice.listenForWakeWord(
      localeId: locale.isEmpty ? null : locale,
    );
    state = state.copyWith(wakeWordEnabled: ok);
    return ok;
  }

  /// Speaks [text] immediately (used by the "speak/stop" control).
  Future<void> speak(String text) =>
      ref.read(assistantVoiceServiceProvider).speak(text);

  Future<void> stopSpeaking() =>
      ref.read(assistantVoiceServiceProvider).stop();

  void _addMessage({
    required ChatRole role,
    required String text,
    required ReplyKind kind,
    List<SearchResult> sources = const [],
    bool speak = false,
    String? spokenOverride,
  }) {
    final message = JarvisChatMessage(
      id: _nextMessageId++,
      role: role,
      text: text,
      kind: kind,
      sources: sources,
    );
    state = state.copyWith(messages: [...state.messages, message]);
    if (speak) {
      final spoken = spokenOverride ?? text;
      unawaited(ref.read(assistantVoiceServiceProvider).speak(spoken));
    }
  }
}
