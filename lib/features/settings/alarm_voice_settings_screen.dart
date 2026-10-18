import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../alarms/alarm_tts.dart';
import '../alarms/data/alarm_voice_settings.dart';

/// Languages the app ships translations for, shared by the app language and the
/// alarm voice language pickers.
const _voiceLanguages = <(String, String)>[
  ('en', 'English'),
  ('ta', 'தமிழ்'),
  ('te', 'తెలుగు'),
  ('ml', 'മലയാളം'),
  ('kn', 'ಕನ್ನಡ'),
];

/// Global alarm voice settings: language, installed voice, gender, and the
/// speech rate/pitch/volume applied to every motivational message. These are
/// resolved when an alarm rings, so per-alarm messages and timings are never
/// affected by changes made here.
class AlarmVoiceSettingsScreen extends ConsumerStatefulWidget {
  const AlarmVoiceSettingsScreen({super.key});

  @override
  ConsumerState<AlarmVoiceSettingsScreen> createState() =>
      _AlarmVoiceSettingsScreenState();
}

class _AlarmVoiceSettingsScreenState
    extends ConsumerState<AlarmVoiceSettingsScreen> {
  List<TtsVoice>? _voices;
  bool _loading = true;
  bool _failed = false;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final voices = await ref.read(alarmTtsProvider).voices();
      if (mounted) {
        setState(() {
          _voices = voices;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  /// The concrete language whose voices are shown: the app language when the
  /// setting follows it, otherwise the chosen code.
  String _effectiveLanguage(AlarmVoiceSettings settings) {
    if (settings.followsAppLanguage) {
      return Localizations.localeOf(context).languageCode;
    }
    return settings.languageCode!;
  }

  List<TtsVoice> _voicesFor(String language) =>
      (_voices ?? const <TtsVoice>[])
          .where((v) => v.languageCode == language)
          .toList();

  String _languageLabel(String code) {
    for (final lang in _voiceLanguages) {
      if (lang.$1 == code) return lang.$2;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(alarmVoiceSettingsProvider);
    final controller = ref.read(alarmVoiceSettingsProvider.notifier);
    final language = _effectiveLanguage(settings);
    final voices = _voicesFor(language);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alarmVoiceSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language),
            title: Text(l10n.voiceLanguage),
            subtitle: Text(
              settings.followsAppLanguage
                  ? l10n.followAppLanguage
                  : _languageLabel(language),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(settings),
          ),
          const Divider(),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text(l10n.voicesLoading),
                ],
              ),
            )
          else ...[
            if (_failed)
              _InfoBanner(
                text: l10n.voiceLoadFailed,
                action: l10n.retry,
                onRetry: _loadVoices,
              )
            else if (voices.isEmpty)
              _InfoBanner(
                text: l10n.voiceUnavailableForLanguage(
                  _languageLabel(language),
                ),
                action: l10n.retry,
                onRetry: _loadVoices,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.record_voice_over_outlined),
              title: Text(l10n.voiceSelect),
              subtitle: Text(
                settings.usesDefaultVoice
                    ? l10n.voiceDeviceDefault
                    : settings.voiceName!,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: voices.isEmpty ? null : () => _pickVoice(settings, voices),
            ),
            if (!settings.usesDefaultVoice &&
                !voices.any((v) => v.name == settings.voiceName))
              _InfoBanner(text: l10n.voiceFallbackNote),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              l10n.voiceGender,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          SegmentedButton<VoiceGender>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: VoiceGender.any,
                label: Text(l10n.genderDefault),
              ),
              ButtonSegment(
                value: VoiceGender.female,
                label: Text(l10n.genderFemale),
              ),
              ButtonSegment(
                value: VoiceGender.male,
                label: Text(l10n.genderMale),
              ),
            ],
            selected: {settings.gender},
            onSelectionChanged:
                (selection) => controller.setGender(selection.first),
          ),
          if (settings.gender != VoiceGender.any &&
              voices.isNotEmpty &&
              !voices.any((v) => v.gender == settings.gender))
            _InfoBanner(text: l10n.voiceGenderUnavailable),
          const Divider(),
          _LabeledSlider(
            title: l10n.speechRate,
            value: settings.rate,
            min: AlarmVoiceSettings.minRate,
            max: AlarmVoiceSettings.maxRate,
            onChanged: controller.setRate,
            onReset: controller.resetRate,
          ),
          _LabeledSlider(
            title: l10n.speechPitch,
            value: settings.pitch,
            min: AlarmVoiceSettings.minPitch,
            max: AlarmVoiceSettings.maxPitch,
            onChanged: controller.setPitch,
            onReset: controller.resetPitch,
          ),
          _LabeledSlider(
            title: l10n.speechVolume,
            value: settings.volume,
            min: 0,
            max: 1,
            onChanged: controller.setVolume,
            onReset: controller.resetVolume,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _previewing ? null : _preview,
            icon:
                _previewing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.play_arrow),
            label: Text(_previewing ? l10n.voicePreviewing : l10n.voicePreview),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(AlarmVoiceSettings settings) async {
    final l10n = context.l10n;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.followAppLanguage),
                  trailing:
                      settings.followsAppLanguage
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final lang in _voiceLanguages)
                  ListTile(
                    title: Text(lang.$2),
                    trailing:
                        settings.languageCode == lang.$1
                            ? const Icon(Icons.check)
                            : null,
                    onTap: () => Navigator.pop(context, lang.$1),
                  ),
              ],
            ),
          ),
    );
    if (result == null) return;
    final controller = ref.read(alarmVoiceSettingsProvider.notifier);
    await controller.setLanguageCode(result.isEmpty ? null : result);
    // A voice from one language usually can't speak another; drop an explicit
    // selection so the engine picks a matching voice automatically.
    await controller.setVoiceName(null);
  }

  Future<void> _pickVoice(
    AlarmVoiceSettings settings,
    List<TtsVoice> voices,
  ) async {
    final l10n = context.l10n;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.voiceDeviceDefault),
                  subtitle: Text(l10n.voiceDeviceDefaultDesc),
                  trailing:
                      settings.usesDefaultVoice
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final voice in voices)
                  ListTile(
                    title: Text(voice.name),
                    subtitle: Text(voice.locale),
                    trailing:
                        settings.voiceName == voice.name
                            ? const Icon(Icons.check)
                            : null,
                    onTap: () => Navigator.pop(context, voice.name),
                  ),
              ],
            ),
          ),
    );
    if (result == null) return;
    await ref
        .read(alarmVoiceSettingsProvider.notifier)
        .setVoiceName(result.isEmpty ? null : result);
  }

  Future<void> _preview() async {
    final l10n = context.l10n;
    setState(() => _previewing = true);
    try {
      final tts = ref.read(alarmTtsProvider);
      final settings = ref.read(alarmVoiceSettingsProvider);
      var language = _effectiveLanguage(settings);
      try {
        final voices = await tts.voices();
        language = AlarmVoiceResolver.resolveLanguage(voices, language);
      } catch (_) {
        // Use the bare language code.
      }
      await tts.configure(settings, language);
      await tts.speak(l10n.previewSentence);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.voicePreviewFailed)));
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.action, this.onRetry});

  final String text;
  final String? action;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (action != null && onRetry != null)
            TextButton(onPressed: onRetry, child: Text(action!)),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onReset,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final label = value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              Text(label),
              IconButton(
                tooltip: context.l10n.resetDefault,
                icon: const Icon(Icons.restart_alt, size: 20),
                onPressed: onReset,
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 0.05).round(),
            label: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
