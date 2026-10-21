import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/common.dart';
import '../alarms/data/alarm_repository.dart';
import '../schedule/data/event_repository.dart';
import '../tasks/data/task_repository.dart';
import 'data/briefing_scheduler.dart';
import 'data/llama_runtime.dart';
import 'data/memory_repository.dart';
import 'data/model_manager.dart';
import 'domain/chat_models.dart';
import 'domain/memory_retrieval.dart';
import 'presentation/jarvis_controller.dart';

/// The Jarvis assistant: chat, model management, and memory management in
/// one screen. Everything runs on-device; the model tab is the only place
/// that ever touches the network (a single explicit download).
class JarvisScreen extends ConsumerWidget {
  const JarvisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.jarvisTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.jarvisChat),
              Tab(text: l10n.jarvisModel),
              Tab(text: l10n.jarvisMemories),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ChatTab(), _ModelTab(), _MemoriesTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat tab
// ---------------------------------------------------------------------------

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab();

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab>
    with AutomaticKeepAliveClientMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _confirmationOpen = false;

  /// Whether a speech recognition service was discovered; false in widget
  /// tests and on devices without one — the mic button simply stays hidden.
  bool _speechReady = false;
  bool _listening = false;
  bool _speakReplies = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize();
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {
      // No speech service here; the mic button stays hidden.
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showConfirmation(JarvisConfirmation confirmation) async {
    if (_confirmationOpen) return;
    _confirmationOpen = true;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isDismissible: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.jarvisAllowAction, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(confirmation.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: Text(l10n.jarvisDecline),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: Text(l10n.jarvisAllow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    _confirmationOpen = false;
    if (!mounted) return;
    ref.read(jarvisChatProvider.notifier).resolveConfirmation(confirmed ?? false);
  }

  void _send() {
    final text = _inputController.text;
    _inputController.clear();
    ref.read(jarvisChatProvider.notifier).send(text);
  }

  /// Push-to-talk: starts recognition while the mic is held. Partial results
  /// stream into the input field; the final result is sent automatically.
  Future<void> _startListening() async {
    if (!_speechReady || _listening || ref.read(jarvisChatProvider).busy) {
      return;
    }
    _listening = true;
    final notifier = ref.read(jarvisChatProvider.notifier);
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(partialResults: true),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _inputController.text = result.recognizedWords);
          if (result.finalResult) {
            _listening = false;
            final text = _inputController.text;
            if (text.trim().isNotEmpty) {
              _inputController.clear();
              notifier.send(text);
            }
          }
        },
      );
    } catch (_) {
      _listening = false;
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    try {
      await _speech.stop();
    } catch (_) {
      _listening = false;
    }
  }

  /// Best-effort read-aloud of the latest assistant reply.
  Future<void> _speakLastReply() async {
    if (!_speakReplies) return;
    final messages = ref.read(jarvisChatProvider).messages;
    String? text;
    for (final message in messages.reversed) {
      if (message.role == ChatRole.assistant && !message.isToolResult) {
        text = message.text;
        break;
      }
    }
    if (text == null || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      final locale = ref.read(localeCodeProvider);
      if (locale != null) {
        try {
          await _tts.setLanguage(locale);
        } catch (_) {
          // Fall back to the device's default TTS voice.
        }
      }
      await _tts.speak(text);
    } catch (_) {
      // TTS unavailable: chat stays fully usable without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(jarvisChatProvider);
    final notifier = ref.read(jarvisChatProvider.notifier);

    ref.listen(jarvisChatProvider.select((s) => s.pendingConfirmation), (
      previous,
      next,
    ) {
      if (next != null) _showConfirmation(next);
    });

    ref.listen(jarvisChatProvider.select((s) => s.busy), (previous, next) {
      if (previous == true && next == false) _speakLastReply();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());

    return Column(
      children: [
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
            actions: [
              TextButton(
                onPressed: notifier.clearError,
                child: Text(l10n.ok),
              ),
            ],
          ),
        Expanded(
          child:
              state.messages.isEmpty
                  ? EmptyState(
                    icon: Icons.smart_toy_outlined,
                    message: l10n.jarvisChatEmpty,
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: state.messages.length,
                    itemBuilder:
                        (context, index) =>
                            _MessageBubble(message: state.messages[index]),
                  ),
        ),
        if (state.busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.jarvisThinking,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: l10n.jarvisInputHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                if (_speechReady)
                  Tooltip(
                    message: l10n.jarvisMicHold,
                    child: GestureDetector(
                      onLongPressStart: (_) => _startListening(),
                      onLongPressEnd: (_) => _stopListening(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        child: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color:
                              _listening
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: l10n.jarvisSpeakReplies,
                  icon: Icon(
                    _speakReplies ? Icons.volume_up : Icons.volume_off,
                    color:
                        _speakReplies
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() => _speakReplies = !_speakReplies);
                    if (!_speakReplies) _tts.stop();
                  },
                ),
                IconButton.filled(
                  tooltip: state.busy ? l10n.jarvisStop : l10n.jarvisSend,
                  icon: Icon(state.busy ? Icons.stop : Icons.send),
                  onPressed:
                      state.busy
                          ? notifier.stop
                          : (_inputController.text.trim().isEmpty
                              ? null
                              : _send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final JarvisChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isToolResult) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.handyman_outlined, size: 13, color: theme.hintColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color:
              isUser
                  ? theme.colorScheme.primaryContainer
                  : softTint(context, ModuleAccents.jarvis, 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(message.text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model tab
// ---------------------------------------------------------------------------

class _ModelTab extends ConsumerStatefulWidget {
  const _ModelTab();

  @override
  ConsumerState<_ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends ConsumerState<_ModelTab>
    with AutomaticKeepAliveClientMixin {
  ModelInstallProgress? _progress;
  String? _installError;

  @override
  bool get wantKeepAlive => true;

  Future<void> _download() async {
    final manager = ref.read(jarvisModelManagerProvider);
    setState(() {
      _progress = null;
      _installError = null;
    });
    try {
      await for (final progress in manager.download()) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      if (!mounted) return;
      setState(() => _progress = null);
      await ref.read(jarvisChatProvider.notifier).refreshModelReady();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _installError = '$e';
      });
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: context.l10n.jarvisImportModel,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() => _installError = null);
    try {
      await ref.read(jarvisModelManagerProvider).importFromFile(path);
      if (!mounted) return;
      await ref.read(jarvisChatProvider.notifier).refreshModelReady();
    } catch (e) {
      if (!mounted) return;
      setState(() => _installError = '$e');
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.jarvisDeleteModel),
            content: Text(l10n.jarvisDeleteModelWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final notifier = ref.read(jarvisChatProvider.notifier);
    await notifier.unloadModel();
    await ref.read(jarvisModelManagerProvider).deleteModel();
    await notifier.refreshModelReady();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(jarvisChatProvider);
    final prefs = ref.watch(appPreferencesProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory, color: ModuleAccents.jarvis),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.modelReady
                            ? l10n.jarvisModelInstalled
                            : l10n.jarvisNoModel,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Chip(
                      label: Text(
                        state.engineState == LlamaRuntimeState.ready
                            ? l10n.jarvisModelLoaded
                            : l10n.jarvisModelNotLoaded,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _progress == null ? _download : null,
                      icon: const Icon(Icons.download),
                      label: Text(l10n.jarvisDownloadModel),
                    ),
                    OutlinedButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(l10n.jarvisImportModel),
                    ),
                    if (state.modelReady)
                      state.engineState == LlamaRuntimeState.ready
                          ? OutlinedButton.icon(
                            onPressed: ref
                                .read(jarvisChatProvider.notifier)
                                .unloadModel,
                            icon: const Icon(Icons.power_settings_new),
                            label: Text(l10n.jarvisUnloadModel),
                          )
                          : FilledButton.tonalIcon(
                            onPressed:
                                () => ref
                                    .read(jarvisChatProvider.notifier)
                                    .loadModel(),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.jarvisLoadModel),
                          ),
                    if (state.modelReady)
                      IconButton.outlined(
                        tooltip: l10n.jarvisDeleteModel,
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: _delete,
                      ),
                  ],
                ),
                if (_progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _progress!.fraction),
                  const SizedBox(height: 6),
                  Text(
                    switch (_progress!.phase) {
                      ModelInstallPhase.downloading =>
                        '${l10n.jarvisDownloading} '
                            '${_formatBytes(_progress!.receivedBytes)}'
                            '${_progress!.totalBytes > 0 ? ' / ${_formatBytes(_progress!.totalBytes)}' : ''}',
                      ModelInstallPhase.verifying => l10n.jarvisVerifying,
                      ModelInstallPhase.installed => l10n.jarvisModelInstalled,
                    },
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (_installError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _installError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.jarvisCpuThreads, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  isExpanded: true,
                  value: prefs.jarvisModelThreads,
                  items: [
                    for (var i = 1; i <= 8; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      prefs.setJarvisModelThreads(value);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.jarvisContextSize,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  isExpanded: true,
                  value: prefs.jarvisModelContextSize,
                  items: const [
                    DropdownMenuItem(value: 1024, child: Text('1024')),
                    DropdownMenuItem(value: 2048, child: Text('2048')),
                    DropdownMenuItem(value: 4096, child: Text('4096')),
                    DropdownMenuItem(value: 8192, child: Text('8192')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      prefs.setJarvisModelContextSize(value);
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: Icon(
              Icons.wb_sunny_outlined,
              color: ModuleAccents.jarvis,
            ),
            title: Text(l10n.jarvisBriefingToggle),
            subtitle: Text(l10n.jarvisBriefingToggleHint),
            value: prefs.jarvisBriefingEnabled,
            onChanged: (value) async {
              await prefs.setJarvisBriefingEnabled(value);
              if (!mounted) return;
              setState(() {});
              try {
                await reconcileDailyBriefing(
                  reminders: ref.read(notificationServiceProvider),
                  prefs: prefs,
                  tasks: ref.read(taskRepositoryProvider),
                  events: ref.read(eventRepositoryProvider),
                  alarms: ref.read(alarmRepositoryProvider),
                );
              } catch (_) {
                // Swallowed like the other best-effort reconciles.
              }
            },
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

// ---------------------------------------------------------------------------
// Memories tab
// ---------------------------------------------------------------------------

class _MemoriesTab extends ConsumerStatefulWidget {
  const _MemoriesTab();

  @override
  ConsumerState<_MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends ConsumerState<_MemoriesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _addMemory() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.jarvisAddMemory),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(hintText: l10n.jarvisMemoryHint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    final text = content?.trim();
    if (text == null || text.isEmpty) return;
    await ref
        .read(jarvisMemoryRepositoryProvider)
        .save(content: text, confirmed: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final repo = ref.watch(jarvisMemoryRepositoryProvider);

    return StreamBuilder<List<MemoryRecord>>(
      stream: repo.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) return const LoadingState();
        final memories = snapshot.data!;
        if (memories.isEmpty) {
          return EmptyState(
            icon: Icons.psychology_outlined,
            message: l10n.jarvisNoMemories,
          );
        }
        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final memory = memories[index];
                return _MemoryTile(
                  memory: memory,
                  onConfirm:
                      () => repo.setConfirmed(memory.id, !memory.confirmed),
                  onForget: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (dialogContext) => AlertDialog(
                            title: Text(l10n.jarvisForgetMemory),
                            content: Text(memory.content),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: Text(l10n.cancel),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(dialogContext).colorScheme.error,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: Text(l10n.delete),
                              ),
                            ],
                          ),
                    );
                    if (confirmed == true) await repo.delete(memory.id);
                  },
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'jarvisAddMemory',
                onPressed: _addMemory,
                icon: const Icon(Icons.add),
                label: Text(l10n.jarvisAddMemory),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.memory,
    required this.onConfirm,
    required this.onForget,
  });

  final MemoryRecord memory;
  final VoidCallback onConfirm;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(memory.content, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: softTint(context, ModuleAccents.jarvis, 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    memory.category.name,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const Spacer(),
                if (!memory.confirmed)
                  TextButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(l10n.jarvisConfirmMemory),
                  )
                else
                  Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: ModuleAccents.jarvis,
                  ),
                IconButton(
                  tooltip: l10n.jarvisForgetMemory,
                  icon: Icon(Icons.delete_outline, size: 20),
                  onPressed: onForget,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
