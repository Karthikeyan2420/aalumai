import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/chat_models.dart';

/// Lifecycle of the local GGUF inference runtime.
enum LlamaRuntimeState {
  /// The native runtime cannot run on this device (non-Android, or the
  /// arm64 native library failed to load). Retrying is cheap and harmless.
  unavailable,

  /// No model loaded yet.
  idle,

  /// A model file is being mapped/loaded.
  loading,

  /// Model loaded, ready to generate.
  ready,

  /// A generation is in flight.
  generating,
}

/// Thrown when the local runtime cannot be used on this device.
class LlamaUnavailableException implements Exception {
  const LlamaUnavailableException([this.cause]);

  final String? cause;

  @override
  String toString() =>
      'LlamaUnavailableException(${cause ?? 'Local AI is not supported on this device.'})';
}

/// Thrown when an operation is attempted in the wrong state (e.g. a second
/// generation started while one is still streaming).
class LlamaBusyException implements Exception {
  const LlamaBusyException(this.message);

  final String message;

  @override
  String toString() => 'LlamaBusyException($message)';
}

/// Generation parameters for a single chat completion.
class LlamaGenParams {
  const LlamaGenParams({
    this.maxTokens = 512,
    this.temperature = 0.6,
    this.topP = 0.95,
    this.topK = 40,
    this.repeatPenalty = 1.1,
    this.seed,
  });

  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final double repeatPenalty;
  final int? seed;
}

/// App-facing contract of the local inference runtime.
///
/// Implementations are safe to call from the UI layer: [chat] returns a
/// buffered stream (events emitted before the caller listens are kept) and
/// only one generation may be in flight at a time.
abstract class LlamaEngine {
  LlamaRuntimeState get state;

  Stream<LlamaRuntimeState> get states;

  /// 0.0–1.0 model load progress (broadcast).
  Stream<double> get loadProgress;

  /// Loads [modelPath] (absolute path to a local `.gguf` file).
  ///
  /// Throws [LlamaUnavailableException] when the device cannot run the
  /// native runtime; other failures surface as [PlatformException].
  Future<void> load({
    required String modelPath,
    int contextSize,
    int threads,
  });

  /// Frees the loaded model. Safe to call when nothing is loaded.
  Future<void> unload();

  /// Streams a completion for the full [history].
  ///
  /// The native KV cache is reset first, so every call is a stateless
  /// full-history turn: [history] must contain the system prompt and all
  /// prior turns in order. Chat-template formatting happens natively.
  Stream<String> chat({
    required List<ChatTurn> history,
    String template = 'chatml',
    LlamaGenParams params = const LlamaGenParams(),
  });

  /// Cancels the in-flight generation. The [chat] stream still receives a
  /// normal (non-error) close event afterwards.
  Future<void> stop();

  /// Chat template names the native side supports (device check).
  Future<List<String>> supportedTemplates();

  /// KV-cache usage after the last generation, or null while unloaded.
  Future<({int tokensUsed, int contextSize})?> contextInfo();
}

/// [LlamaEngine] implementation backed by `llama_flutter_android`.
///
/// Plugin quirks this wrapper papers over:
///
/// * The plugin returns a **broadcast** token stream created before the
///   native side starts. This wrapper subscribes synchronously and re-emits
///   into a buffered single-subscription controller, so no early token is
///   dropped even if the caller listens a frame later.
/// * The native KV cache persists across `generate` calls; we reset it
///   before every turn (full-history stateless mode) so history is never
///   decoded twice into the cache.
/// * [llama.LlamaController] installs itself as the global platform-bridge
///   handler and closes its streams permanently on dispose, so a fresh
///   controller is created for every load cycle.
class LlamaRuntime implements LlamaEngine {
  final StreamController<LlamaRuntimeState> _states =
      StreamController<LlamaRuntimeState>.broadcast();
  final StreamController<double> _loadProgress =
      StreamController<double>.broadcast();

  LlamaRuntimeState _state = LlamaRuntimeState.idle;
  llama.LlamaController? _controller;
  StreamSubscription<String>? _activeBridge;
  StreamController<String>? _activeOut;

  @override
  LlamaRuntimeState get state => _state;

  @override
  Stream<LlamaRuntimeState> get states => _states.stream;

  @override
  Stream<double> get loadProgress => _loadProgress.stream;

  void _setState(LlamaRuntimeState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  @override
  Future<void> load({
    required String modelPath,
    int contextSize = 4096,
    int threads = 4,
  }) async {
    if (!Platform.isAndroid) {
      _setState(LlamaRuntimeState.unavailable);
      throw const LlamaUnavailableException('Local AI requires Android.');
    }
    if (_state == LlamaRuntimeState.loading ||
        _state == LlamaRuntimeState.generating) {
      throw const LlamaBusyException('Cannot load while the runtime is busy.');
    }
    if (_state == LlamaRuntimeState.ready &&
        (await _controller?.isModelLoaded() ?? false)) {
      return; // Idempotent: already loaded.
    }
    if (_state == LlamaRuntimeState.ready) await unload();

    _setState(LlamaRuntimeState.loading);
    await _cancelBridge();
    await _disposeController();

    final controller = llama.LlamaController();
    _controller = controller;

    final progressSub = controller.loadProgress.listen(
      (value) {
        if (!_loadProgress.isClosed) _loadProgress.add(value);
      },
      onError: (Object _) {},
    );

    try {
      await controller.loadModel(
        modelPath: modelPath,
        contextSize: contextSize,
        threads: threads,
        gpuLayers: 0, // Plugin ships CPU-only (Vulkan compiled out).
      );
      if (!await controller.isModelLoaded()) {
        throw const LlamaUnavailableException();
      }
      _setState(LlamaRuntimeState.ready);
    } on PlatformException catch (e) {
      await _disposeController();
      _setState(LlamaRuntimeState.unavailable);
      throw LlamaUnavailableException(e.message);
    } catch (_) {
      await _disposeController();
      _setState(LlamaRuntimeState.idle);
      rethrow;
    } finally {
      await progressSub.cancel();
    }
  }

  @override
  Future<void> unload() async {
    // Unload while a turn is streaming: close the caller's stream first so
    // it can never hang, then let dispose() deliver the native terminal
    // event to the bridge (FIFO main-thread posts make this deterministic),
    // and finally reap the subscription.
    final activeOut = _activeOut;
    _activeOut = null;
    if (activeOut != null) _finishTurn(activeOut);
    await _disposeController();
    await _cancelBridge();
    if (_state != LlamaRuntimeState.unavailable) {
      _setState(LlamaRuntimeState.idle);
    }
  }

  @override
  Stream<String> chat({
    required List<ChatTurn> history,
    String template = 'chatml',
    LlamaGenParams params = const LlamaGenParams(),
  }) {
    final controller = _controller;
    final out = StreamController<String>();

    if (controller == null || _state != LlamaRuntimeState.ready) {
      out.addError(StateError('Model is not loaded (state: ${_state.name}).'));
      out.close();
      return out.stream;
    }

    _setState(LlamaRuntimeState.generating);
    _activeOut = out;
    unawaited(_runTurn(controller, history, template, params, out));
    return out.stream;
  }

  Future<void> _runTurn(
    llama.LlamaController controller,
    List<ChatTurn> history,
    String template,
    LlamaGenParams params,
    StreamController<String> out,
  ) async {
    StreamSubscription<String>? bridge;
    var finished = false;
    try {
      // Full-history stateless mode: drop any KV state from a previous turn
      // so re-sent history is never decoded twice.
      await controller.clearContext();

      final src = controller.generateChat(
        messages: [
          for (final turn in history)
            llama.ChatMessage(role: turn.role.name, content: turn.content),
        ],
        template: template,
        maxTokens: params.maxTokens,
        temperature: params.temperature,
        topP: params.topP,
        topK: params.topK,
        repeatPenalty: params.repeatPenalty,
        seed: params.seed,
      );

      final done = Completer<void>();
      // Synchronous subscription: platform messages cannot be delivered
      // while this Dart turn runs, so tokens can never arrive pre-subscribe;
      // the buffered `out` covers any caller-side listen delay.
      bridge = src.listen(
        (token) {
          if (!out.isClosed) out.add(token);
      },
        onError: (Object e) {
          finished = true;
          _finishTurn(out, error: e);
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          finished = true;
          _finishTurn(out);
          if (!done.isCompleted) done.complete();
        },
      );
      _activeBridge = bridge;
      await done.future;
      await bridge.cancel();
    } catch (e) {
      finished = true;
      _finishTurn(out, error: e);
    } finally {
      if (bridge != null && identical(_activeBridge, bridge)) {
        _activeBridge = null;
      }
      // Safety net: never leave the caller's stream open if the terminal
      // callback somehow did not run. State already normalised by
      // _finishTurn in every normal path — and a turn that starts after
      // ours (state flipped to ready in _finishTurn) is never touched here.
      if (!finished) {
        _finishTurn(out, error: const LlamaBusyException('Turn ended.'));
      }
    }
  }

  /// Normalises state *before* closing [out]: the caller's onDone handler
  /// may synchronously start a new turn, which must observe [ready].
  void _finishTurn(StreamController<String> out, {Object? error}) {
    if (identical(_activeOut, out)) _activeOut = null;
    _setState(LlamaRuntimeState.ready);
    if (out.isClosed) return;
    if (error != null) out.addError(error);
    out.close();
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    if (controller == null || !controller.isGenerating) return;
    await controller.stop();
    // The native side still delivers a terminal onDone, which closes the
    // caller's stream and flips state back to ready.
  }

  @override
  Future<List<String>> supportedTemplates() async {
    final controller = _controller;
    if (controller == null) return const [];
    try {
      return await controller.getSupportedTemplates();
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<({int tokensUsed, int contextSize})?> contextInfo() async {
    final controller = _controller;
    if (controller == null || _state.index < LlamaRuntimeState.ready.index) {
      return null;
    }
    try {
      final info = await controller.getContextInfo();
      return (tokensUsed: info.tokensUsed, contextSize: info.contextSize);
    } on PlatformException {
      return null;
    }
  }

  Future<void> _cancelBridge() async {
    final bridge = _activeBridge;
    _activeBridge = null;
    if (bridge != null) {
      await bridge.cancel();
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.dispose();
    } on Exception {
      // Disposing a half-loaded controller must never block the caller.
    }
  }

  /// Releases all Dart-side streams. Call when the owning provider is
  /// disposed for good.
  Future<void> shutdown() async {
    await unload();
    await _states.close();
    await _loadProgress.close();
  }
}

/// App-wide inference runtime. One instance per process: the plugin binds a
/// global platform handler, so a second concurrent runtime would steal it.
final llamaRuntimeProvider = Provider<LlamaEngine>((ref) {
  final runtime = LlamaRuntime();
  ref.onDispose(() {
    // ignore: discarded_futures
    runtime.shutdown();
  });
  return runtime;
});
