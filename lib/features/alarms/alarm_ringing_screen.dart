import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/backgrounds/background_presets.dart';
import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/services/alarm_trigger_channel.dart';
import '../../core/widgets/background_view.dart';
import 'alarm_audio.dart';
import 'alarm_challenges.dart';
import 'alarm_playback.dart';
import 'alarm_tts.dart';
import 'data/alarm_repository.dart';
import 'data/alarm_voice_settings.dart';

/// Full-screen alarm ringing experience.
///
/// The alarm plays its selected tone on a loop (with the configured vibration)
/// and only stops after the user passes **every** challenge in the alarm's
/// ordered challenge sequence. There is deliberately no snooze or dismiss
/// button: incorrect answers never stop the audio, and passing all challenges
/// is the only in-app way to complete the ring.
///
/// Note: this cannot block OS-level escapes — the power/volume buttons, a force
/// stop or a reboot are controlled by Android, not the app.
class AlarmRingingScreen extends ConsumerStatefulWidget {
  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.isPreview = false,
    this.audio,
    this.challengeBuilder,
  });

  final Alarm alarm;

  /// When true the screen is a UI preview: it plays the tone once, shows a
  /// close button and never touches the database or notifications.
  final bool isPreview;

  /// Injectable audio backend, primarily for tests.
  final AlarmAudio? audio;

  /// Injectable challenge generator, primarily for deterministic tests.
  final AlarmChallengeData Function(AlarmChallenge kind, Random random)?
  challengeBuilder;

  @override
  ConsumerState<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends ConsumerState<AlarmRingingScreen>
    with WidgetsBindingObserver {
  late final AlarmTts? _tts =
      widget.audio == null ? ref.read(alarmTtsProvider) : null;
  late final AlarmAudio _audio = widget.audio ?? AlarmAudio(tts: _tts);
  late final List<AlarmChallenge> _sequence = AlarmChallengeSequence.resolve(
    widget.alarm.challengeSequence,
    widget.alarm.challengeType,
  );
  final Random _random = Random();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AlarmChallengeSettings _settings = AlarmChallengeSettings.decode(
    widget.alarm.challengeParam,
  );

  int _step = 0;
  late AlarmChallengeData _challenge;
  bool _wrong = false;
  bool _revealed = false;
  bool _completed = false;
  bool _showFinalMotivation = false;
  bool _allowDismiss = false;
  Timer? _revealTimer;

  int get _total => _sequence.length;
  AlarmChallenge get _kind => _sequence[_step];
  bool get _isMemory => _kind == AlarmChallenge.memory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareStep();
    // A ringing alarm must be visible and interactive for as long as it rings,
    // so keep the screen awake while this full-screen experience is on top.
    if (!widget.isPreview) {
      unawaited(WakelockPlus.enable().catchError((_) {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAudio();
      }
    });
  }

  /// Generates the data for the current step. Memory challenges reveal their
  /// digits for a few seconds, then hide them so the user must recall them.
  void _prepareStep() {
    _wrong = false;
    _input.clear();
    _revealed = _isMemory;
    final builder = widget.challengeBuilder;
    _challenge =
        builder != null
            ? builder(_kind, _random)
            : AlarmChallengeGenerator.generate(
              _kind,
              _random,
              codeLength: _settings.codeLength,
            );
    _revealTimer?.cancel();
    if (_isMemory) {
      _revealTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_completed) setState(() => _revealed = false);
      });
    }
    // Focus is re-requested on every step (including the very first one) so the
    // matching keyboard variant opens automatically. Without this the numeric
    // keyboard requested by a preceding math/memory step would stay up for a
    // later "type a code" step, and letters could not be typed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_completed && _focus.canRequestFocus) {
        _focus.requestFocus();
      }
    });
  }

  Future<void> _startAudio() async {
    final config = await _buildConfig();
    if (widget.isPreview) {
      await _preview(config);
      return;
    }
    // The native ring service may already be looping the tone from the moment
    // the alarm triggered. It also speaks the message through the alarm audio
    // stream. Flutter must then stay silent for both, otherwise the music plays
    // twice and the speech is routed over STREAM_MUSIC, which Android silences
    // as background playback while the foreground ring service owns the alarm
    // stream. We only drive audio here when no native ring is active.
    final native = await AlarmTriggerChannel.ringState();
    final nativeRinging = native.isFor(widget.alarm.id);
    await _audio.start(
      config,
      musicAlreadyPlaying: nativeRinging,
      voiceAlreadyPlaying: nativeRinging && config.speaks,
    );
  }

  /// Builds the playback configuration from the alarm's own sound settings and
  /// the current global voice preferences. When the global voice language is
  /// set to follow the app, the active locale is resolved here — at ring time.
  Future<AlarmPlaybackConfig> _buildConfig() async {
    final settings = ref.read(alarmVoiceSettingsProvider);
    final appLanguage = Localizations.localeOf(context).languageCode;
    var language =
        settings.followsAppLanguage ? appLanguage : settings.languageCode!;
    final tts = _tts;
    if (tts != null) {
      try {
        final voices = await tts.voices();
        language = AlarmVoiceResolver.resolveLanguage(voices, language);
      } catch (_) {
        // No voice list available: use the language code as-is.
      }
    }
    return AlarmPlaybackConfig(
      mode: AlarmSoundMode.fromIndex(widget.alarm.soundMode),
      soundId: widget.alarm.soundUri,
      message: widget.alarm.message,
      finalMessage: widget.alarm.finalMessage,
      musicIntervalSec: widget.alarm.musicIntervalSec,
      voicePauseSec: widget.alarm.voicePauseSec,
      voiceTiming: VoiceTiming.fromIndex(widget.alarm.voiceTiming),
      volumePercent: widget.alarm.volume,
      vibrate: widget.alarm.vibrate,
      voice: settings,
      languageCode: language,
    );
  }

  /// A one-shot UI preview: plays the tone once and speaks the message once,
  /// without looping or touching the database.
  Future<void> _preview(AlarmPlaybackConfig config) async {
    if (config.playsMusic) {
      await _audio.preview(
        soundId: config.soundId,
        volumePercent: config.volumePercent,
      );
    }
    if (config.speaks) {
      final tts = _tts;
      if (tts != null) {
        try {
          await tts.configure(config.voice, config.languageCode);
          await tts.speak(config.message.trim());
        } catch (_) {}
      }
    }
  }

  Future<void> _ring() => _audio.reassert();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android may pause playback while the activity is covered/backgrounded.
    // Re-assert the loop on return so solving a challenge never silences the
    // alarm; audio is never stopped on background transitions.
    if (state == AppLifecycleState.resumed &&
        !widget.isPreview &&
        !_completed) {
      _ring();
    }
  }

  /// Correct answers advance (or complete); incorrect answers keep ringing.
  void _submit() {
    if (_completed) return;
    if (!_challenge.matches(_input.text)) {
      setState(() => _wrong = true);
      return;
    }
    if (_step + 1 >= _total) {
      _complete();
    } else {
      setState(() {
        _step += 1;
        _prepareStep();
      });
    }
  }

  /// Every challenge passed: stop the tone, optionally show the final
  /// motivation (spoken + on screen) until the user taps Done.
  Future<void> _complete() async {
    if (_completed) return;
    setState(() => _completed = true);
    await AlarmTriggerChannel.stopRing();
    await _audio.stop();
    if (!widget.isPreview) {
      await ref.read(alarmRepositoryProvider).complete(widget.alarm);
    }
    final config = await _buildConfig();
    final finalText = config.finalMessage.trim();
    if (finalText.isEmpty) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
      _popRingingScreen();
      return;
    }
    if (mounted) setState(() => _showFinalMotivation = true);
    await _speakText(config, finalText);
  }

  Future<void> _speakText(AlarmPlaybackConfig config, String text) async {
    final tts = _tts;
    if (tts == null || text.isEmpty) return;
    try {
      await tts.configure(config.voice, config.languageCode);
      await tts.speak(text);
    } catch (_) {}
  }

  Future<void> _dismissFinalMotivation() async {
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _popRingingScreen();
  }

  void _popRingingScreen() {
    if (!mounted) return;
    setState(() => _allowDismiss = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealTimer?.cancel();
    _focus.dispose();
    _input.dispose();
    // Leaving the screen can never leave audio, vibration or a screen wake lock
    // running in the background.
    if (!widget.isPreview) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
    // Stops the loop and releases the player so leaving the screen can never
    // leave audio (or vibration) running in the background.
    _audio.dispose();
    super.dispose();
  }

  /// Accent used across the ringing UI (blue/teal) so controls and progress
  /// read clearly against the darkened alarm backdrop.
  static const Color _accent = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isPreview || _allowDismiss,
      child: CustomBackground(
        slot: BackgroundSlot.alarm,
        overlayColor: Colors.black,
        minOverlay: 0.35,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child:
                  widget.isPreview
                      ? _buildPreview(context)
                      : _buildChallenges(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const Spacer(),
        _RingingBeacon(color: _accent),
        const SizedBox(height: 16),
        _AlarmTimeText(alarm: widget.alarm, color: Colors.white),
        const SizedBox(height: 8),
        _AlarmLabelText(alarm: widget.alarm, color: Colors.white70),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            label: Text(l10n.close),
          ),
        ),
      ],
    );
  }

  Widget _buildChallenges(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_showFinalMotivation) {
      final text = widget.alarm.finalMessage.trim();
      return Column(
        children: [
          const Spacer(),
          Icon(Icons.record_voice_over, size: 72, color: _accent),
          const SizedBox(height: 16),
          Text(
            l10n.finalMotivationalMessage,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _dismissFinalMotivation,
              icon: const Icon(Icons.check),
              label: Text(
                l10n.done,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _RingingBeacon(color: _accent),
        const SizedBox(height: 8),
        _AlarmTimeText(alarm: widget.alarm, color: Colors.white),
        const SizedBox(height: 4),
        _AlarmLabelText(alarm: widget.alarm, color: Colors.white70),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _total,
                  minHeight: 6,
                  color: _accent,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.challengeStep(_step + 1, _total),
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.passAllChallenges,
            textAlign: TextAlign.left,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: _challengeCard(context, l10n),
          ),
        ),
      ],
    );
  }

  Widget _challengeCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final kind = _kind;
    final title = switch (kind) {
      AlarmChallenge.math => l10n.challengeMath,
      AlarmChallenge.memory => l10n.challengeMemory,
      AlarmChallenge.code => l10n.challengeCode,
      AlarmChallenge.none => l10n.challengeNone,
    };
    final isLast = _step + 1 >= _total;
    final isCode = kind == AlarmChallenge.code;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_isMemory && _revealed) ...[
            Text(
              l10n.memorizeDigits,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _challenge.prompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                letterSpacing: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            if (!_isMemory)
              Text(
                _challenge.prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              // A fresh field per step forces Flutter to rebuild the input
              // connection, so the keyboard switches between numeric and text
              // when the challenge kind changes.
              key: ValueKey('challenge-field-$_step'),
              controller: _input,
              focusNode: _focus,
              autofocus: true,
              enabled: !_completed,
              // Code challenges are alphanumeric; math/memory are numeric.
              keyboardType: isCode ? TextInputType.text : TextInputType.number,
              textCapitalization:
                  isCode
                      ? TextCapitalization.characters
                      : TextCapitalization.none,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: InputDecoration(
                labelText: l10n.enterAnswer,
                labelStyle: const TextStyle(color: Colors.white70),
                errorText: _wrong ? l10n.wrongAnswer : null,
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _accent, width: 2),
                ),
                errorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _completed ? null : _submit,
              icon: const Icon(Icons.check),
              label: Text(
                isLast ? l10n.done : l10n.next,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The alarm's configured time, large and readable.
class _AlarmTimeText extends StatelessWidget {
  const _AlarmTimeText({required this.alarm, required this.color});

  final Alarm alarm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      TimeOfDay(hour: alarm.hour, minute: alarm.minute).format(context),
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w300,
        color: color,
      ),
    );
  }
}

class _AlarmLabelText extends StatelessWidget {
  const _AlarmLabelText({required this.alarm, required this.color});

  final Alarm alarm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(
      alarm.label.isEmpty ? l10n.alarms : alarm.label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// A gently pulsing alarm glyph conveying the "ringing" state.
class _RingingBeacon extends StatefulWidget {
  const _RingingBeacon({required this.color});
  final Color color;

  @override
  State<_RingingBeacon> createState() => _RingingBeaconState();
}

class _RingingBeaconState extends State<_RingingBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => Transform.scale(
            scale: 1 + 0.12 * _controller.value,
            child: Icon(Icons.alarm, size: 72, color: widget.color),
          ),
    );
  }
}
