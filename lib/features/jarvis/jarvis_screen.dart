import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/services/notification_service.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/common.dart';
import '../alarms/data/alarm_repository.dart';
import '../schedule/data/event_repository.dart';
import '../tasks/data/task_repository.dart';
import 'conversation/assistant_providers.dart';
import 'conversation/assistant_reply.dart';
import 'data/briefing_scheduler.dart';
import 'data/memory_repository.dart';
import 'domain/memory_retrieval.dart';
import 'presentation/jarvis_controller.dart';

/// The assistant: chat, voice settings and memory management.
///
/// Everything runs on-device with no language model. Online lookups happen
/// only for questions outside the local knowledge base, and only when the
/// user has left online answers enabled.
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
              Tab(text: l10n.jarvisSettings),
              Tab(text: l10n.jarvisMemories),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ChatTab(), _VoiceTab(), _MemoriesTab()],
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
  bool _confirmationOpen = false;
  bool _voiceReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await ref.read(voiceServiceProvider).initialize();
    if (mounted) setState(() => _voiceReady = ok);
  }

  @override
  void dispose() {
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
    ref
        .read(jarvisChatProvider.notifier)
        .resolveConfirmation(confirmed ?? false);
  }

  void _send() {
    final text = _inputController.text;
    _inputController.clear();
    ref.read(jarvisChatProvider.notifier).send(text);
  }

  Future<void> _toggleMic() async {
    final notifier = ref.read(jarvisChatProvider.notifier);
    final state = ref.read(jarvisChatProvider);
    if (state.listening) {
      await notifier.stopListening();
      return;
    }
    // Stream transcripts into the field; final results send automatically.
    final voice = ref.read(voiceServiceProvider);
    if (!_voiceReady && !await voice.initialize()) return;
    ref.read(voiceServiceProvider).transcripts.listen((text) {
      if (!mounted) return;
      setState(() => _inputController.text = text);
    });
    await notifier.startListening();
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());

    return Column(
      children: [
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
            actions: [
              TextButton(onPressed: notifier.clearError, child: Text(l10n.ok)),
            ],
          ),
        Expanded(
          child: state.messages.isEmpty
              ? EmptyState(
                  icon: Icons.smart_toy_outlined,
                  message: l10n.jarvisChatEmpty,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: state.messages[index]),
                ),
        ),
        if (state.listening)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.mic, size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(l10n.jarvisThinking, style: theme.textTheme.bodySmall),
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
                if (_voiceReady)
                  Tooltip(
                    message: l10n.jarvisMicTap,
                    child: IconButton(
                      icon: Icon(
                        state.listening ? Icons.mic : Icons.mic_none,
                        color: state.listening
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleMic,
                    ),
                  ),
                IconButton(
                  tooltip: l10n.jarvisStopSpeaking,
                  icon: const Icon(Icons.volume_off),
                  onPressed: notifier.stopSpeaking,
                ),
                IconButton.filled(
                  tooltip: state.busy ? l10n.jarvisStop : l10n.jarvisSend,
                  icon: const Icon(Icons.send),
                  onPressed: _inputController.text.trim().isEmpty
                      ? null
                      : _send,
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
    final l10n = context.l10n;
    final isUser = message.isUser;

    final bubbleColor = isUser
        ? theme.colorScheme.primaryContainer
        : message.isError
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
            : softTint(context, ModuleAccents.jarvis, 0.10);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser && message.kind == ReplyKind.online) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 13, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    l10n.jarvisOnlineBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (!isUser && message.kind == ReplyKind.knowledge) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 13, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    l10n.jarvisOfflineBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(message.text, style: theme.textTheme.bodyMedium),
            if (message.hasSources) ...[
              const SizedBox(height: 8),
              Text(
                l10n.jarvisSourcesTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 2),
              for (final source in message.sources)
                InkWell(
                  onTap: () => _openUrl(source.sourceUrl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            source.sourceName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Voice / settings tab
// ---------------------------------------------------------------------------

class _VoiceTab extends ConsumerStatefulWidget {
  const _VoiceTab();

  @override
  ConsumerState<_VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends ConsumerState<_VoiceTab>
    with AutomaticKeepAliveClientMixin {
  List<String> _languages = const [];
  bool _loadingLanguages = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final langs = await ref
        .read(assistantVoiceServiceProvider)
        .availableLanguages();
    if (!mounted) return;
    setState(() {
      _languages = langs;
      _loadingLanguages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(appPreferencesProvider);
    final engine = ref.read(assistantEngineProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: Text(l10n.jarvisSpeakReplies),
                value: prefs.assistantSpeechEnabled,
                onChanged: (value) async {
                  await prefs.setAssistantSpeechEnabled(value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.mic_none),
                title: Text(l10n.jarvisWakeWord),
                subtitle: Text(l10n.jarvisWakeWordHint),
                value: prefs.assistantWakeWordEnabled,
                onChanged: (value) async {
                  await prefs.setAssistantWakeWordEnabled(value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.public),
                title: Text(l10n.jarvisOnlineSearch),
                subtitle: Text(l10n.jarvisOnlineSearchHint),
                value: prefs.assistantOnlineSearchEnabled,
                onChanged: (value) async {
                  await prefs.setAssistantOnlineSearchEnabled(value);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.jarvisVoiceSection, style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (_loadingLanguages)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: prefs.assistantSpeechLanguage.isEmpty
                        ? ''
                        : prefs.assistantSpeechLanguage,
                    decoration: InputDecoration(
                      labelText: l10n.jarvisSpeechLanguage,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.jarvisSpeechLanguageDefault),
                      ),
                      for (final code in _languages)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (value) async {
                      await prefs.setAssistantSpeechLanguage(value ?? '');
                      await ref
                          .read(assistantVoiceServiceProvider)
                          .refreshSettings();
                      setState(() {});
                    },
                  ),
                const SizedBox(height: 16),
                _SliderRow(
                  label: l10n.jarvisSpeechRate,
                  value: prefs.assistantSpeechRate,
                  min: 0.3,
                  max: 1.8,
                  onChanged: (v) async {
                    await prefs.setAssistantSpeechRate(v);
                    await ref
                        .read(assistantVoiceServiceProvider)
                        .refreshSettings();
                    setState(() {});
                  },
                ),
                _SliderRow(
                  label: l10n.jarvisSpeechPitch,
                  value: prefs.assistantSpeechPitch,
                  min: 0.5,
                  max: 1.6,
                  onChanged: (v) async {
                    await prefs.setAssistantSpeechPitch(v);
                    await ref
                        .read(assistantVoiceServiceProvider)
                        .refreshSettings();
                    setState(() {});
                  },
                ),
                _SliderRow(
                  label: l10n.jarvisSpeechVolume,
                  value: prefs.assistantSpeechVolume,
                  min: 0.2,
                  max: 1.0,
                  onChanged: (v) async {
                    await prefs.setAssistantSpeechVolume(v);
                    await ref
                        .read(assistantVoiceServiceProvider)
                        .refreshSettings();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.jarvisVoicePreview),
                    onPressed: () =>
                        ref.read(assistantVoiceServiceProvider).preview(),
                  ),
                ),
                const Divider(height: 24),
                TextField(
                  controller: TextEditingController.fromValue(
                    TextEditingValue(text: prefs.assistantUserName),
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.jarvisUserName,
                    helperText: l10n.jarvisUserNameHint,
                  ),
                  onSubmitted: (value) async {
                    await prefs.setAssistantUserName(value.trim());
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
                // Best-effort, like the other reconciles.
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '${engine.knowledge.entries.length} offline knowledge topics',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
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
                  onConfirm: () =>
                      repo.setConfirmed(memory.id, !memory.confirmed),
                  onForget: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
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
                  icon: const Icon(Icons.delete_outline, size: 20),
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
