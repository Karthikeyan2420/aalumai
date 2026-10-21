import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/yoga_repository.dart';
import 'domain/indian_yoga.dart';
import 'domain/yoga.dart';
import 'widgets/yoga_labels.dart';
import 'widgets/yoga_pose_image.dart';

/// A guided yoga practice: one pose at a time, each held for its scheduled
/// duration with a countdown, pause/resume, previous/next, skip and a finish
/// summary. Progress is persisted so an interrupted practice can be resumed.
class YogaPlayerScreen extends ConsumerStatefulWidget {
  const YogaPlayerScreen({
    super.key,
    required this.routine,
    this.resumeSessionId,
    this.startIndex = 0,
  });

  final YogaRoutine routine;

  /// Existing session to continue, when resuming.
  final int? resumeSessionId;
  final int startIndex;

  @override
  ConsumerState<YogaPlayerScreen> createState() => _YogaPlayerScreenState();
}

class _YogaPlayerScreenState extends ConsumerState<YogaPlayerScreen> {
  static const _prepareSeconds = 5;

  final Stopwatch _total = Stopwatch()..start();
  final Stopwatch _step = Stopwatch();
  final Set<int> _logged = {};
  Timer? _timer;
  late int _index = widget.startIndex;
  int _remaining = 0;
  int _preparing = _prepareSeconds;
  int? _sessionId;
  bool _paused = false;
  bool _finished = false;
  bool _loading = true;
  String? _error;
  int _completed = 0;
  YogaSessionOutcome? _outcome;

  List<YogaPlanItem> get _items => widget.routine.items;
  bool get _done => _index >= _items.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(yogaRepositoryProvider);
    try {
      _sessionId =
          widget.resumeSessionId ??
          await repo.startSession(
            routineKey: widget.routine.kind.name,
            title: widget.routine.kind.label,
            difficulty: widget.routine.difficulty.index,
            poseCount: _items.length,
          );
      unawaited(WakelockPlus.enable().catchError((_) {}));
      if (!mounted) return;
      setState(() => _loading = false);
      if (_index == 0) {
        _startPrepare();
      } else {
        _enterStep();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  void _startPrepare() {
    _timer?.cancel();
    setState(() => _preparing = _prepareSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      if (_preparing <= 1) {
        _timer?.cancel();
        _enterStep();
      } else {
        setState(() => _preparing--);
      }
    });
  }

  void _enterStep() {
    _timer?.cancel();
    _step
      ..stop()
      ..reset();
    if (_done) {
      _finish();
      return;
    }
    if (!_paused) _step.start();
    setState(() => _remaining = _items[_index].durationSec);
    _persistProgress();
    if (!_paused) _startTimer();
  }

  void _persistProgress() {
    if (_sessionId != null) {
      ref.read(yogaRepositoryProvider).updateSessionProgress(_sessionId!, _index);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        setState(() => _remaining = 0);
        _advance(outcome: YogaPoseOutcome.completed);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _logPose(int index, YogaPoseOutcome outcome) async {
    if (_sessionId == null || _logged.contains(index)) return;
    _logged.add(index);
    final item = _items[index];
    await ref.read(yogaRepositoryProvider).logPose(
      sessionId: _sessionId!,
      pose: item.pose,
      positionIndex: index,
      plannedSec: item.durationSec,
      actualSec: _step.elapsed.inSeconds,
      outcome: outcome,
    );
  }

  Future<void> _advance({required YogaPoseOutcome outcome}) async {
    _timer?.cancel();
    if (_done) return;
    final leaving = _index;
    if (outcome == YogaPoseOutcome.completed) _completed++;
    await _logPose(leaving, outcome);
    if (!mounted) return;
    setState(() => _index++);
    _enterStep();
  }

  void _previous() {
    if (_index <= 0) return;
    _timer?.cancel();
    setState(() => _index--);
    _enterStep();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
      _total.stop();
      _step.stop();
    } else {
      _total.start();
      _step.start();
      if (_index >= _items.length && _preparing > 0) {
        _startPrepare();
      } else {
        _startTimer();
      }
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _total.stop();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    final outcome =
        _completed >= _items.length
            ? YogaSessionOutcome.completed
            : (_completed > 0
                ? YogaSessionOutcome.partial
                : YogaSessionOutcome.cancelled);
    _outcome = outcome;
    if (_sessionId != null) {
      await ref
          .read(yogaRepositoryProvider)
          .finishSession(
            _sessionId!,
            durationSec: _total.elapsed.inSeconds,
            completedPoses: _completed,
            outcome: outcome,
          );
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmEnd() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.yogaFinishPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.yogaFinish),
              ),
            ],
          ),
    );
    if (ok == true) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmEnd();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine.kind.label),
          actions: [
            TextButton(onPressed: _confirmEnd, child: Text(l10n.yogaFinish)),
          ],
        ),
        body:
            _loading
                ? const LoadingState()
                : _error != null
                ? ErrorState(message: _error!, onRetry: _retry)
                : (_finished || _done)
                ? _summary(l10n)
                : _player(l10n),
      ),
    );
  }

  Widget _player(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final seconds = _index >= _items.length ? 0 : _remaining;
    final progress =
        _items.isEmpty ? 0.0 : _index / _items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                l10n.yogaPoseOf(_index + 1, _items.length),
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                l10n.yogaMinutes(
                  (_total.elapsed.inSeconds / 60).ceil(),
                ),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 8,
            ),
          ),
          const Spacer(),
          if (_index < _items.length)
            YogaPoseImage(
              imageUrl: _items[_index].pose.imageUrl,
              size: 200,
              borderRadius: 24,
              noImageLabel: l10n.yogaNoImage,
            ),
          const SizedBox(height: 20),
          if (_index < _items.length) ...[
            Text(
              _items[_index].pose.englishName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (_items[_index].pose.sanskritName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _items[_index].pose.sanskritName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            '${seconds}s',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w300,
              color: theme.colorScheme.secondary,
            ),
          ),
          if (_items.isNotEmpty && _index < _items.length) ...[
            const SizedBox(height: 12),
            if (_items[_index].pose.breathing.isNotEmpty)
              Text(
                _items[_index].pose.breathing,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              label: Text(_paused ? l10n.yogaResume : l10n.yogaPause),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index > 0 ? _previous : null,
                  icon: const Icon(Icons.skip_previous),
                  label: Text(l10n.yogaPrevious),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => _advance(outcome: YogaPoseOutcome.skipped),
                  icon: const Icon(Icons.skip_next),
                  label: Text(l10n.yogaSkip),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final mins = _total.elapsed.inSeconds ~/ 60;
    final secs = _total.elapsed.inSeconds % 60;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Icon(
          Icons.self_improvement,
          size: 72,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.yogaSessionComplete,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        _row(
          theme,
          Icons.timer_outlined,
          l10n.totalTime,
          '$mins min $secs s',
        ),
        _row(
          theme,
          Icons.self_improvement,
          l10n.yogaPoses,
          '$_completed / ${_items.length}',
        ),
        _row(
          theme,
          Icons.local_fire_department_outlined,
          l10n.yogaLevel,
          yogaDifficultyLabel(l10n, widget.routine.difficulty),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.yogaSafetyNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_outcome),
          child: Text(l10n.yogaDone),
        ),
      ],
    );
  }

  Widget _row(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: theme.colorScheme.secondary),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
