import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backgrounds/background_presets.dart';
import '../../core/backgrounds/background_providers.dart';
import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../settings/alarm_voice_settings_screen.dart';
import '../settings/background_settings_screen.dart';
import 'alarm_audio.dart';
import 'alarm_challenges.dart';
import 'alarm_messages.dart';
import 'alarm_playback.dart';
import 'alarm_tts.dart';
import 'data/alarm_repository.dart';
import 'data/alarm_sound_store.dart';
import 'data/alarm_voice_settings.dart';

/// Sentinel returned by the sound picker when the user wants to import a file.
const _customSoundSentinel = '__custom_sound__';

/// Opens the full-screen alarm editor for a new ([alarm] == null) or existing
/// alarm.
Future<void> showAlarmEditor(
  BuildContext context,
  WidgetRef ref, {
  Alarm? alarm,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => AlarmEditorScreen(alarm: alarm)),
  );
}

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _challengeName(AppLocalizations l10n, AlarmChallenge kind) =>
    switch (kind) {
      AlarmChallenge.math => l10n.challengeMath,
      AlarmChallenge.memory => l10n.challengeMemory,
      AlarmChallenge.code => l10n.challengeCode,
      AlarmChallenge.none => l10n.challengeNone,
    };

class AlarmEditorScreen extends ConsumerStatefulWidget {
  const AlarmEditorScreen({super.key, this.alarm});
  final Alarm? alarm;

  @override
  ConsumerState<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends ConsumerState<AlarmEditorScreen> {
  final _audio = AlarmAudio();
  final _labelCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  late int _hour = widget.alarm?.hour ?? 7;
  late int _minute = widget.alarm?.minute ?? 0;
  late int _mask = widget.alarm?.repeatDaysMask ?? 0;
  late bool _oneTime = widget.alarm?.oneTime ?? false;
  late String _soundId = widget.alarm?.soundUri ?? AlarmSounds.defaultId;
  late int _volume = widget.alarm?.volume ?? 100;
  late bool _vibrate = widget.alarm?.vibrate ?? true;
  late List<AlarmChallenge> _challenges = AlarmChallengeSequence.resolve(
    widget.alarm?.challengeSequence ?? '',
    widget.alarm?.challengeType ?? 0,
  );
  late bool _enabled = widget.alarm?.isEnabled ?? true;
  late AlarmChallengeSettings _challengeSettings =
      AlarmChallengeSettings.decode(widget.alarm?.challengeParam ?? '');

  /// New alarms default to the richest experience; alarms migrated from an
  /// earlier schema keep their music-only behaviour.
  late AlarmSoundMode _soundMode = AlarmSoundMode.fromIndex(
    widget.alarm?.soundMode ?? AlarmSoundMode.fallback.index,
  );
  late int _musicInterval =
      widget.alarm?.musicIntervalSec ?? kDefaultMusicIntervalSec;
  late int _voicePause = widget.alarm?.voicePauseSec ?? kDefaultVoicePauseSec;
  late VoiceTiming _voiceTiming = VoiceTiming.fromIndex(
    widget.alarm?.voiceTiming ?? VoiceTiming.fallback.index,
  );

  bool _previewingVoice = false;
  bool _saving = false;

  /// True when [musicIntervalSec] is not one of the preset choices.
  late bool _customInterval = !kMusicIntervalPresets.contains(_musicInterval);

  bool get _isEditing => widget.alarm != null;

  @override
  void initState() {
    super.initState();
    _labelCtrl.text = widget.alarm?.label ?? '';
    _messageCtrl.text = widget.alarm?.message ?? '';
  }

  @override
  void dispose() {
    _audio.dispose();
    _labelCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: context.l10n.time,
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
    // Returning focus to the editor so the role is announced correctly.
  }

  void _toggleDay(int index) {
    setState(() {
      _oneTime = false;
      _mask ^= (1 << index);
    });
  }

  /// Validates the sound/motivation configuration. Returns a localized error,
  /// or `null` when the configuration is acceptable.
  String? _validationError() {
    if (_soundMode == AlarmSoundMode.voiceOnly &&
        _messageCtrl.text.trim().isEmpty) {
      return context.l10n.voiceOnlyNeedsMessage;
    }
    if (_soundMode == AlarmSoundMode.musicAndVoice &&
        _messageCtrl.text.trim().isEmpty) {
      // Music still plays, so an empty message is allowed — no error.
    }
    if (_musicInterval <= 0) return context.l10n.invalidInterval;
    if (_voicePause <= 0) return context.l10n.invalidInterval;
    return null;
  }

  Future<void> _save() async {
    final error = _validationError();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(alarmRepositoryProvider);
    final sequence = _effectiveSequence();
    final encoded = AlarmChallengeSequence.encode(sequence);
    final primary = sequence.first;
    final message = _messageCtrl.text.trim();
    try {
      if (_isEditing) {
        final updated = widget.alarm!.copyWith(
          hour: _hour,
          minute: _minute,
          label: _labelCtrl.text.trim(),
          repeatDaysMask: _mask,
          oneTime: _oneTime && _mask == 0,
          soundUri: _soundId,
          volume: _volume,
          vibrate: _vibrate,
          challengeType: primary.index,
          challengeParam: _challengeSettings.encode(),
          challengeSequence: encoded,
          isEnabled: _enabled,
          soundMode: _soundMode.index,
          message: message,
          musicIntervalSec: _musicInterval,
          voiceTiming: _voiceTiming.index,
          voicePauseSec: _voicePause,
        );
        await repo.updateAlarm(updated);
      } else {
        await repo.create(
          hour: _hour,
          minute: _minute,
          label: _labelCtrl.text.trim(),
          repeatDaysMask: _mask,
          oneTime: _oneTime && _mask == 0,
          soundUri: _soundId,
          volume: _volume,
          vibrate: _vibrate,
          challenge: primary,
          challengeParam: _challengeSettings.encode(),
          challengeSequence: encoded,
          isEnabled: _enabled,
          soundMode: _soundMode.index,
          message: message,
          musicIntervalSec: _musicInterval,
          voiceTiming: _voiceTiming.index,
          voicePauseSec: _voicePause,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Normalises the edited list, guaranteeing at least one challenge so the
  /// alarm can always be dismissed.
  List<AlarmChallenge> _effectiveSequence() {
    final normalized = AlarmChallengeSequence.normalize(_challenges);
    return normalized.isEmpty
        ? List.of(AlarmChallengeSequence.defaultSequence)
        : normalized;
  }

  void _addChallenge() async {
    if (_challenges.length >= AlarmChallengeSequence.maxLength) return;
    final kind = await _pickChallengeKind();
    if (kind != null &&
        mounted &&
        _challenges.length < AlarmChallengeSequence.maxLength) {
      setState(() => _challenges = [..._challenges, kind]);
    }
  }

  void _removeChallengeAt(int index) {
    setState(() {
      final next = [..._challenges]..removeAt(index);
      _challenges = next;
    });
  }

  void _moveChallenge(int from, int to) {
    if (to < 0 || to >= _challenges.length) return;
    setState(() {
      final next = [..._challenges];
      final item = next.removeAt(from);
      next.insert(to, item);
      _challenges = next;
    });
  }

  Future<AlarmChallenge?> _pickChallengeKind() {
    final l10n = context.l10n;
    return showModalBottomSheet<AlarmChallenge>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.addChallenge,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final kind in AlarmChallengeSequence.selectable)
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined),
                    title: Text(_challengeName(l10n, kind)),
                    onTap: () => Navigator.of(sheetContext).pop(kind),
                  ),
              ],
            ),
          ),
    );
  }

  /// Lets the user choose how many characters a "type a code" challenge shows.
  Future<void> _pickCodeLength() async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.codeLength,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final length in AlarmChallengeSettings.codeLengthPresets)
                  ListTile(
                    leading: Icon(
                      length == _challengeSettings.codeLength
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(l10n.codeLengthValue(length)),
                    onTap: () => Navigator.of(sheetContext).pop(length),
                  ),
              ],
            ),
          ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _challengeSettings = _challengeSettings.copyWith(codeLength: chosen);
    });
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteConfirmTitle),
            content: Text(l10n.deleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (ok == true) {
      await ref.read(alarmRepositoryProvider).delete(widget.alarm!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nextRing =
        _isEditing && _enabled
            ? ref.read(alarmRepositoryProvider).nextRing(widget.alarm!)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.alarms : l10n.newAlarm),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _TimeCard(
            hour: _hour,
            minute: _minute,
            onTap: _pickTime,
            onToggleEnabled: (v) => setState(() => _enabled = v),
            enabled: _enabled,
          ),
          const SizedBox(height: 16),
          _SectionLabel(l10n.repeatDays),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        _DayToggle(
                          label: _weekdayLabels[i],
                          selected: _mask & (1 << i) != 0,
                          enabled: !_oneTime,
                          onTap: () => _toggleDay(i),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.oneTime),
                    value: _oneTime,
                    onChanged:
                        (v) => setState(() {
                          _oneTime = v;
                          if (v) _mask = 0;
                        }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.alarmLabel),
          ),
          const SizedBox(height: 20),
          ..._soundSection(l10n),
          _SettingTile(
            icon: Icons.wallpaper_outlined,
            title: l10n.alarmBackground,
            value: ref.watch(alarmBackgroundProvider).label ?? '',
            onTap: _openAlarmBackground,
          ),
          _SliderTile(
            icon: Icons.volume_up_outlined,
            title: l10n.volume,
            value: _volume,
            onChanged: (v) => setState(() => _volume = v),
            label: '$_volume%',
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(l10n.vibrate),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
          ),
          _ChallengeSequenceTile(
            sequence: _challenges,
            onAdd:
                _challenges.length >= AlarmChallengeSequence.maxLength
                    ? null
                    : _addChallenge,
            onRemoveAt: _removeChallengeAt,
            onMove: _moveChallenge,
          ),
          if (_challenges.contains(AlarmChallenge.code))
            _SettingTile(
              icon: Icons.password_outlined,
              title: l10n.codeLength,
              value: l10n.codeLengthValue(_challengeSettings.codeLength),
              onTap: _pickCodeLength,
            ),
          if (nextRing != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.alarm_on,
                  color: theme.colorScheme.secondary,
                ),
                title: Text(l10n.nextRing),
                subtitle: Text(_formatNext(context, nextRing)),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ),
      ),
    );
  }

  String _formatNext(BuildContext context, DateTime next) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final diff = day.difference(today).inDays;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(next));
    final l10n = context.l10n;
    final dayLabel = switch (diff) {
      0 => l10n.today,
      1 => l10n.tomorrow,
      _ => MaterialLocalizations.of(context).formatMediumDate(next),
    };
    return '$dayLabel · $time';
  }

  String _soundName(AppLocalizations l10n, String id) {
    final custom = AlarmSoundStore.displayName(id);
    if (custom != null) return custom;
    return switch (id) {
      'gentle' => l10n.soundGentle,
      'urgent' => l10n.soundUrgent,
      'system' => l10n.soundSystem,
      _ => l10n.soundClassic,
    };
  }

  String _soundModeLabel(AppLocalizations l10n, AlarmSoundMode mode) =>
      switch (mode) {
        AlarmSoundMode.musicAndVoice => l10n.soundModeMusicVoice,
        AlarmSoundMode.voiceOnly => l10n.soundModeVoiceOnly,
        AlarmSoundMode.musicOnly => l10n.soundModeMusicOnly,
      };

  /// The "Alarm Sound & Motivation" block. Its contents adapt to the selected
  /// [AlarmSoundMode]; voice settings themselves are global (see Settings) so
  /// only a read-only summary lives here.
  List<Widget> _soundSection(AppLocalizations l10n) {
    final playsMusic = _soundMode != AlarmSoundMode.voiceOnly;
    final speaks = _soundMode != AlarmSoundMode.musicOnly;
    return [
      _SectionLabel(l10n.alarmSoundAndMotivation),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in AlarmSoundMode.values)
                    ChoiceChip(
                      label: Text(_soundModeLabel(l10n, mode)),
                      selected: _soundMode == mode,
                      onSelected: (_) => setState(() => _soundMode = mode),
                    ),
                ],
              ),
              if (playsMusic) ...[
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(l10n.alarmMusic),
                  subtitle: Text(_soundName(l10n, _soundId)),
                  onTap: _pickSound,
                  trailing: IconButton(
                    tooltip: l10n.previewSound,
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed:
                        () => _audio.preview(
                          soundId: _soundId,
                          volumePercent: _volume,
                        ),
                  ),
                ),
              ],
              if (speaks) ...[
                const Divider(height: 24),
                TextField(
                  controller: _messageCtrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.motivationalMessage,
                    hintText: l10n.motivationalMessageHint,
                    suffixIcon:
                        _previewingVoice
                            ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                            : IconButton(
                              tooltip: l10n.voicePreview,
                              icon: const Icon(
                                Icons.record_voice_over_outlined,
                              ),
                              onPressed: _previewVoice,
                            ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _useSampleMessage,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l10n.useSampleMessage),
                  ),
                ),
                if (_soundMode == AlarmSoundMode.musicAndVoice) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.musicInterval,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.musicIntervalHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final seconds in kMusicIntervalPresets)
                        ChoiceChip(
                          label: Text(l10n.customIntervalValue(seconds)),
                          selected:
                              !_customInterval && _musicInterval == seconds,
                          onSelected:
                              (_) => setState(() {
                                _musicInterval = seconds;
                                _customInterval = false;
                              }),
                        ),
                      ChoiceChip(
                        label: Text(
                          _customInterval
                              ? l10n.customIntervalValue(_musicInterval)
                              : l10n.customInterval,
                        ),
                        selected: _customInterval,
                        onSelected: (_) => _editCustomInterval(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VoiceTiming>(
                    value: _voiceTiming,
                    decoration: InputDecoration(labelText: l10n.voiceTiming),
                    items: [
                      for (final timing in VoiceTiming.values)
                        DropdownMenuItem(
                          value: timing,
                          child: Text(_voiceTimingLabel(l10n, timing)),
                        ),
                    ],
                    onChanged:
                        (v) => setState(() => _voiceTiming = v ?? _voiceTiming),
                  ),
                ],
                if (_soundMode == AlarmSoundMode.voiceOnly) ...[
                  const SizedBox(height: 8),
                  _SliderTile(
                    icon: Icons.timer_outlined,
                    title: l10n.voicePause,
                    value: _voicePause.clamp(1, 60),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    onChanged: (v) => setState(() => _voicePause = v),
                    label: l10n.customIntervalValue(_voicePause),
                  ),
                ],
                const Divider(height: 24),
                _VoiceSummaryTile(
                  subtitle: _voiceSummaryLabel(l10n),
                  onTap: _openVoiceSettings,
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  String _voiceTimingLabel(AppLocalizations l10n, VoiceTiming timing) =>
      switch (timing) {
        VoiceTiming.beforeMusic => l10n.voiceTimingBeforeMusic,
        VoiceTiming.betweenSegments => l10n.voiceTimingBetweenSegments,
        VoiceTiming.overMusic => l10n.voiceTimingOverMusic,
      };

  String _voiceSummaryLabel(AppLocalizations l10n) {
    final settings = ref.watch(alarmVoiceSettingsProvider);
    final gender = switch (settings.gender) {
      VoiceGender.female => l10n.genderFemale,
      VoiceGender.male => l10n.genderMale,
      VoiceGender.any => l10n.genderDefault,
    };
    final language =
        settings.followsAppLanguage
            ? l10n.followAppLanguage
            : settings.languageCode!;
    return l10n.alarmVoiceLabel(gender, language);
  }

  /// Speaks the current message (or a sample sentence when empty) using the
  /// global voice settings, purely as an in-editor preview.
  Future<void> _previewVoice() async {
    final text =
        _messageCtrl.text.trim().isEmpty
            ? context.l10n.previewSentence
            : _messageCtrl.text.trim();
    setState(() => _previewingVoice = true);
    try {
      final tts = ref.read(alarmTtsProvider);
      final settings = ref.read(alarmVoiceSettingsProvider);
      final appLanguage = Localizations.localeOf(context).languageCode;
      var language =
          settings.followsAppLanguage ? appLanguage : settings.languageCode!;
      try {
        final voices = await tts.voices();
        language = AlarmVoiceResolver.resolveLanguage(voices, language);
      } catch (_) {
        // Fall back to the bare language code.
      }
      await tts.configure(settings, language);
      await tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.voicePreviewFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _previewingVoice = false);
    }
  }

  void _useSampleMessage() {
    final code = Localizations.localeOf(context).languageCode;
    _messageCtrl.text = AlarmMessages.sampleFor(code);
    setState(() {});
  }

  Future<void> _openVoiceSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AlarmVoiceSettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editCustomInterval() async {
    final controller = TextEditingController(text: '$_musicInterval');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.customIntervalSeconds),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 's'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    dialogContext,
                    int.tryParse(controller.text.trim()),
                  ),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null && result > 0 && mounted) {
      setState(() {
        _musicInterval = result;
        _customInterval = true;
      });
    }
  }

  Future<void> _pickSound() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SoundPickerSheet(selected: _soundId),
    );
    if (!mounted || selected == null) return;
    if (selected == _customSoundSentinel) {
      await _pickCustomSound();
      return;
    }
    setState(() => _soundId = selected);
  }

  /// Lets the user import an audio file from the device, copies it into
  /// app-managed storage and selects it for this alarm. Nothing is uploaded.
  Future<void> _pickCustomSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path == null) return;
      final uri = await ref.read(alarmSoundStoreProvider).import(path);
      if (!mounted) return;
      if (uri == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.customSoundFailed)));
        return;
      }
      setState(() => _soundId = uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.customSoundFailed)));
      }
    }
  }

  void _openAlarmBackground() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => const BackgroundSettingsScreen(slot: BackgroundSlot.alarm),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.hour,
    required this.minute,
    required this.onTap,
    required this.onToggleEnabled,
    required this.enabled,
  });

  final int hour;
  final int minute;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleEnabled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TimeOfDay(hour: hour, minute: minute).format(context),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w300,
                          color: enabled ? null : scheme.outline,
                        ),
                      ),
                      Text(
                        l10n.time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Switch(value: enabled, onChanged: onToggleEnabled),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg =
        selected
            ? scheme.secondary
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final fg =
        selected
            ? scheme.onSecondary
            : scheme.onSurfaceVariant.withValues(alpha: enabled ? 1 : 0.4);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _VoiceSummaryTile extends StatelessWidget {
  const _VoiceSummaryTile({required this.subtitle, required this.onTap});

  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.campaign_outlined),
      title: Text(l10n.settingsAlarmVoice),
      subtitle: Text(subtitle),
      trailing: Text(
        l10n.changeInSettings,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      onTap: onTap,
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = 0,
    this.max = 100,
    this.divisions = 20,
  });

  final IconData icon;
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final String label;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                Text(label),
              ],
            ),
            Slider(
              value: value.toDouble().clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: (v) => onChanged(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundPickerSheet extends StatelessWidget {
  const _SoundPickerSheet({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = AlarmSounds.isCustom(selected);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.alarmSound,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final sound in AlarmSounds.options)
            _SoundRow(
              id: sound.id,
              label: switch (sound.id) {
                'gentle' => l10n.soundGentle,
                'urgent' => l10n.soundUrgent,
                _ => l10n.soundClassic,
              },
              selected: sound.id == selected,
            ),
          const Divider(height: 1),
          _SoundRow(
            id: 'system',
            label: l10n.soundSystem,
            selected: selected == 'system',
          ),
          _SoundRow(
            id: _customSoundSentinel,
            label: l10n.alarmSoundCustom,
            selected: custom,
            subtitle: custom ? AlarmSoundStore.displayName(selected) : null,
            previewId: custom ? selected : null,
            leading: const Icon(Icons.library_music_outlined),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatefulWidget {
  const _SoundRow({
    required this.id,
    required this.label,
    required this.selected,
    this.subtitle,
    this.previewId,
    this.leading,
  });

  final String id;
  final String label;
  final bool selected;
  final String? subtitle;
  final String? previewId;
  final Widget? leading;

  @override
  State<_SoundRow> createState() => _SoundRowState();
}

class _SoundRowState extends State<_SoundRow> {
  final _audio = AlarmAudio();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previewable = (widget.previewId ?? widget.id) != _customSoundSentinel;
    return ListTile(
      leading:
          widget.leading ??
          Icon(
            widget.selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color:
                widget.selected
                    ? Theme.of(context).colorScheme.secondary
                    : null,
          ),
      title: Text(widget.label),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: IconButton(
        tooltip: l10n.previewSound,
        icon: const Icon(Icons.play_arrow),
        onPressed:
            previewable
                ? () => _audio.preview(soundId: widget.previewId ?? widget.id)
                : null,
      ),
      onTap: () => Navigator.of(context).pop(widget.id),
    );
  }
}

/// Editor for an alarm's ordered dismissal-challenge sequence.
///
/// Challenges are shown in the order they will be presented while ringing; the
/// user can add up to [AlarmChallengeSequence.maxLength], reorder them and
/// remove any (keeping at least one so the alarm stays dismissable).
class _ChallengeSequenceTile extends StatelessWidget {
  const _ChallengeSequenceTile({
    required this.sequence,
    required this.onAdd,
    required this.onRemoveAt,
    required this.onMove,
  });

  final List<AlarmChallenge> sequence;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemoveAt;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canRemove = sequence.length > AlarmChallengeSequence.minLength;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 20),
                const SizedBox(width: 12),
                Text(
                  l10n.challenge,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < sequence.length; i++)
              _ChallengeRow(
                position: i + 1,
                kind: sequence[i],
                canMoveUp: i > 0,
                canMoveDown: i < sequence.length - 1,
                canRemove: canRemove,
                onUp: () => onMove(i, i - 1),
                onDown: () => onMove(i, i + 1),
                onRemove: () => onRemoveAt(i),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.addChallenge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.position,
    required this.kind,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final int position;
  final AlarmChallenge kind;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.secondaryContainer,
          child: Text(
            '$position',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(_challengeName(l10n, kind))),
        IconButton(
          tooltip: l10n.moveUp,
          icon: const Icon(Icons.arrow_upward),
          onPressed: canMoveUp ? onUp : null,
        ),
        IconButton(
          tooltip: l10n.moveDown,
          icon: const Icon(Icons.arrow_downward),
          onPressed: canMoveDown ? onDown : null,
        ),
        IconButton(
          tooltip: l10n.removeChallenge,
          icon: const Icon(Icons.close),
          onPressed: canRemove ? onRemove : null,
        ),
      ],
    );
  }
}
