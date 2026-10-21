import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/session_flow.dart';
import 'domain/workout_queue.dart';
import 'widgets/exercise_gif.dart';

/// The full guided workout experience. Steps through a plan's exercises set by
/// set, with countdown timers for timed holds, a rest countdown between sets,
/// pause/resume, skip and previous/next navigation, live elapsed timing and a
/// summary at the end. Progress is persisted so an interrupted workout can be
/// resumed without losing logged sets.
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.title,
    required this.steps,
    this.planId,
    this.scheduledId,
    this.resumeSessionId,
    this.startIndex = 0,
    this.checkReadiness = false,
  });

  final String title;
  final List<WorkoutStep> steps;
  final int? planId;

  /// When launched from the weekly planner, the schedule entry this session
  /// fulfils so completion can be recorded against it.
  final int? scheduledId;

  /// When resuming an interrupted workout, the existing session id.
  final int? resumeSessionId;
  final int startIndex;

  /// Prompts for a self-reported readiness check before the session starts.
  /// The session is never created if the user backs out.
  final bool checkReadiness;

  @override
  ConsumerState<WorkoutPlayerScreen> createState() =>
      _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  final Stopwatch _stopwatch = Stopwatch()..start();
  final Stopwatch _stepWatch = Stopwatch();
  Timer? _timer;
  late int _index = widget.startIndex;
  int _remaining = 0;
  int? _sessionId;
  bool _paused = false;
  bool _finished = false;
  bool _loading = true;
  String? _error;
  ReadinessReport? _readiness;
  SessionOutcome? _outcome;

  bool get _done => _index >= widget.steps.length;

  @override
  void initState() {
    super.initState();
    // Bootstrap after the first frame so inherited widgets (Localizations via
    // `context.l10n`, Navigator via `showDialog`) are safe to look up. Calling
    // it directly here throws a lifecycle assertion during initState, which
    // left the player stuck on its loading spinner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(fitnessRepositoryProvider);
    try {
      if (widget.checkReadiness && widget.resumeSessionId == null) {
        final report = await _showReadinessCheck();
        if (!mounted) return;
        if (report == null) {
          Navigator.of(context).pop();
          return;
        }
        setState(() => _readiness = report);
      }
      _sessionId =
          widget.resumeSessionId ??
          await repo.startSession(
            name: widget.title,
            planId: widget.planId,
            scheduledId: widget.scheduledId,
            totalSteps: widget.steps.length,
            routeJson: WorkoutQueue.encodeSteps(widget.steps),
          );
      // The wakelock plugin is unavailable on some platforms/embeds, so never
      // block the workout on it.
      unawaited(WakelockPlus.enable().catchError((_) {}));
      if (!mounted) return;
      setState(() {
        _error = null;
        _loading = false;
      });
      _enterStep();
    } catch (e) {
      if (!mounted) return;
      // Never leave the player on an endless spinner: surface the failure and
      // let the user retry.
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

  /// A short self-reported readiness check. Returns null when the user backs
  /// out, in which case no session is created.
  Future<ReadinessReport?> _showReadinessCheck() {
    var energy = 3;
    var soreness = 3;
    var sleep = 3;
    final noteCtrl = TextEditingController();
    final l10n = context.l10n;
    return showDialog<ReadinessReport>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setLocal) {
              final preview = ReadinessReport(
                energy: energy,
                soreness: soreness,
                sleep: sleep,
              );
              final low = preview.shouldReduceIntensity;
              return AlertDialog(
                title: Text(l10n.readinessCheck),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.readinessIntro),
                      const SizedBox(height: 16),
                      _ReadinessSlider(
                        label: l10n.energyLabel,
                        value: energy,
                        onChanged: (v) => setLocal(() => energy = v),
                      ),
                      _ReadinessSlider(
                        label: l10n.sorenessLabel,
                        value: soreness,
                        onChanged: (v) => setLocal(() => soreness = v),
                      ),
                      _ReadinessSlider(
                        label: l10n.sleepLabel,
                        value: sleep,
                        onChanged: (v) => setLocal(() => sleep = v),
                      ),
                      if (low) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.lowReadinessHint,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteCtrl,
                        decoration: InputDecoration(labelText: l10n.notes),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed:
                        () => Navigator.pop(
                          context,
                          ReadinessReport(
                            energy: energy,
                            soreness: soreness,
                            sleep: sleep,
                            note: noteCtrl.text.trim(),
                          ),
                        ),
                    child: Text(l10n.iAmReady),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  void _enterStep() {
    _timer?.cancel();
    _stepWatch
      ..stop()
      ..reset();
    if (_done) {
      _finish();
      return;
    }
    if (!_paused) _stepWatch.start();
    final step = widget.steps[_index];
    setState(() => _remaining = step.isTimedCountdown ? step.durationSec : 0);
    _persistProgress();
    if (step.isTimedCountdown && !_paused) _startTimer();
  }

  void _persistProgress() {
    if (_sessionId != null) {
      ref
          .read(fitnessRepositoryProvider)
          .updateSessionProgress(_sessionId!, _index);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final step = widget.steps[_index];
    if (!step.isTimedCountdown) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        setState(() => _remaining = 0);
        _advance(log: step.isWork);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _logCurrentSet({int? reps, int? weightGrams}) async {
    if (_sessionId == null) return;
    final step = widget.steps[_index];
    if (!step.isWork) return;
    final repo = ref.read(fitnessRepositoryProvider);
    final loggedReps = reps ?? step.reps;
    final loggedWeight = weightGrams ?? 0;
    // Timed steps store how long the user actually held the position, which
    // is shorter than the plan when they finish or skip early.
    final loggedDuration = step.isTimed ? _stepWatch.elapsed.inSeconds : 0;
    await repo.logSet(
      sessionId: _sessionId!,
      exerciseId: step.exerciseId,
      setIndex: step.setIndex,
      reps: loggedReps,
      weightGrams: loggedWeight,
      durationSec: loggedDuration,
    );
    final records = <bool>[];
    if (loggedWeight > 0) {
      records.add(
        await repo.updatePersonalRecord(
          exerciseId: step.exerciseId,
          recordType: PersonalRecordKind.weightGrams.index,
          value: loggedWeight,
        ),
      );
    }
    if (loggedReps > 0) {
      records.add(
        await repo.updatePersonalRecord(
          exerciseId: step.exerciseId,
          recordType: PersonalRecordKind.reps.index,
          value: loggedReps,
        ),
      );
    }
    if (loggedDuration > 0) {
      records.add(
        await repo.updatePersonalRecord(
          exerciseId: step.exerciseId,
          recordType: PersonalRecordKind.durationSec.index,
          value: loggedDuration,
        ),
      );
    }
    if (records.contains(true) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.newPersonalBest)));
    }
  }

  Future<void> _advance({required bool log}) async {
    _timer?.cancel();
    if (_done) return;
    final step = widget.steps[_index];
    if (log && step.isWork) await _logCurrentSet();
    if (!mounted) return;
    setState(() => _index++);
    _enterStep();
  }

  Future<void> _completeRepSet() => _promptSetDialog();

  Future<void> _promptSetDialog() async {
    final step = widget.steps[_index];
    final l10n = context.l10n;
    final repsCtrl = TextEditingController(text: '${step.reps}');
    final weightCtrl = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(step.exerciseName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${l10n.targetReps}: ${step.reps}'),
                const SizedBox(height: 12),
                TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.actualReps),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.weightUsed),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.skip),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.completeSet),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (save == false) {
      await _advance(log: false);
      return;
    }
    if (save != true) return;
    final reps = int.tryParse(repsCtrl.text.trim()) ?? step.reps;
    final weightKg = double.tryParse(weightCtrl.text.trim()) ?? 0;
    await _logCurrentSet(reps: reps, weightGrams: (weightKg * 1000).round());
    if (!mounted) return;
    setState(() => _index++);
    _enterStep();
  }

  Future<void> _nextExercise() async {
    final target = _adjacentExercise(_index, forward: true);
    if (target == null) {
      await _finish();
      return;
    }
    _timer?.cancel();
    setState(() => _index = target);
    _enterStep();
  }

  Future<void> _previousExercise() async {
    final target = _adjacentExercise(_index, forward: false);
    if (target == null) return;
    _timer?.cancel();
    setState(() => _index = target);
    _enterStep();
  }

  /// Finds the first step of the next/previous distinct exercise relative to
  /// [from].
  int? _adjacentExercise(int from, {required bool forward}) {
    final steps = widget.steps;
    if (steps.isEmpty) return null;
    final current = steps[from.clamp(0, steps.length - 1)].exerciseId;
    if (forward) {
      for (var i = from + 1; i < steps.length; i++) {
        if (steps[i].isWork && steps[i].exerciseId != current) return i;
      }
      return null;
    }
    for (var i = from - 1; i >= 0; i--) {
      if (steps[i].isWork && steps[i].exerciseId != current) {
        // Jump to the first step of that exercise.
        var j = i;
        while (j > 0 &&
            steps[j - 1].isWork &&
            steps[j - 1].exerciseId == steps[i].exerciseId) {
          j--;
        }
        return j;
      }
    }
    return null;
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
      _stopwatch.stop();
      _stepWatch.stop();
    } else {
      _stopwatch.start();
      _stepWatch.start();
      _startTimer();
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _stopwatch.stop();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    final outcome =
        _done
            ? SessionOutcome.completed
            : (_index > 0 ? SessionOutcome.partial : SessionOutcome.cancelled);
    _outcome = outcome;
    if (_sessionId != null) {
      await ref
          .read(fitnessRepositoryProvider)
          .finishSession(
            _sessionId!,
            durationSec: _stopwatch.elapsed.inSeconds,
            outcome: outcome.index,
          );
    }
    if (mounted) setState(() {});
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
          title: Text(widget.title),
          actions: [
            TextButton(onPressed: _confirmEnd, child: Text(l10n.endWorkout)),
          ],
        ),
        body:
            _loading
                ? const LoadingState()
                : _error != null
                ? ErrorState(message: _error!, onRetry: _retry)
                : (_finished || _done)
                ? _SummaryView(
                  l10n: l10n,
                  sessionId: _sessionId,
                  steps: widget.steps,
                  fallbackDuration: _stopwatch.elapsed.inSeconds,
                  outcome: _outcome,
                  onDone: () => Navigator.of(context).pop(_outcome),
                )
                : _buildPlayer(l10n),
      ),
    );
  }

  Future<void> _confirmEnd() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.endWorkout),
            content: Text(l10n.unsavedChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.endWorkout),
              ),
            ],
          ),
    );
    if (ok == true) await _finish();
  }

  bool get _lowReadiness => _readiness?.shouldReduceIntensity ?? false;

  String _phaseName(AppLocalizations l10n, SessionPhase phase) =>
      switch (phase) {
        SessionPhase.warmUp => l10n.warmUp,
        SessionPhase.main => l10n.mainWork,
        SessionPhase.coolDown => l10n.coolDown,
      };

  Widget _buildPlayer(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final step = widget.steps[_index];
    final progress = _index / widget.steps.length;
    final totalSec = _stopwatch.elapsed.inSeconds;
    final elapsed =
        '${(totalSec ~/ 60).toString().padLeft(2, '0')}:'
        '${(totalSec % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _phaseName(l10n, widget.steps[_index].phase),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_lowReadiness)
                Expanded(
                  child: Text(
                    l10n.lowerIntensityHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text('${l10n.elapsed}: $elapsed'),
              const Spacer(),
              Text(
                '${_index + 1} / ${widget.steps.length}',
                style: theme.textTheme.labelLarge,
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
          ExerciseGif(
            gifUrl: step.gifUrl,
            category: step.category,
            size: 160,
            borderRadius: 24,
            timed: step.isTimed,
          ),
          const SizedBox(height: 20),
          if (step.isRest)
            _RestContent(remaining: _remaining, l10n: l10n)
          else
            _WorkContent(step: step, remaining: _remaining, l10n: l10n),
          const Spacer(),
          if (_paused)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.workoutPaused,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          _primaryAction(step, l10n),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousExercise,
                  icon: const Icon(Icons.skip_previous),
                  label: Text(l10n.previousExercise),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _nextExercise,
                  icon: const Icon(Icons.skip_next),
                  label: Text(l10n.nextExercise),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryAction(WorkoutStep step, AppLocalizations l10n) {
    if (step.isRest) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _advance(log: false),
          icon: const Icon(Icons.fast_forward),
          label: Text(l10n.skip),
        ),
      );
    }
    if (step.isTimed) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _togglePause,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          label: Text(_paused ? l10n.resume : l10n.pause),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _completeRepSet,
        icon: const Icon(Icons.check),
        label: Text(l10n.completeSet),
      ),
    );
  }
}

class _WorkContent extends StatelessWidget {
  const _WorkContent({
    required this.step,
    required this.remaining,
    required this.l10n,
  });

  final WorkoutStep step;
  final int remaining;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          step.exerciseName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.setProgress(step.setIndex + 1, step.totalSets),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (step.isTimed)
          Text(
            '${remaining}s',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w300,
              color: theme.colorScheme.secondary,
            ),
          )
        else
          Text(
            '${step.reps} ${l10n.reps}',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _RestContent extends StatelessWidget {
  const _RestContent({required this.remaining, required this.l10n});
  final int remaining;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.self_improvement,
          size: 44,
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(height: 8),
        Text(l10n.rest, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${remaining}s',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w300,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

/// Post-workout summary: total time, exercises and sets completed, reps,
/// weight and skipped exercises, all derived from the logged sets.
class _SummaryView extends ConsumerWidget {
  const _SummaryView({
    required this.l10n,
    required this.sessionId,
    required this.steps,
    required this.fallbackDuration,
    required this.onDone,
    this.outcome,
  });

  final AppLocalizations l10n;
  final int? sessionId;
  final List<WorkoutStep> steps;
  final int fallbackDuration;
  final VoidCallback onDone;
  final SessionOutcome? outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logsAsync =
        sessionId == null
            ? const AsyncValue<List<WorkoutSetLog>>.data([])
            : ref.watch(workoutSetLogsProvider(sessionId!));
    return logsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (logs) {
        final planned = steps.where((s) => s.isWork).toList();
        final plannedExercises = <int>{for (final s in planned) s.exerciseId};
        final completedExercises = <int>{
          for (final log in logs) log.exerciseId,
        };
        var reps = 0;
        var weight = 0;
        for (final log in logs) {
          reps += log.reps;
          weight += log.weightGrams;
        }
        var totalDuration = fallbackDuration;
        // Prefer the persisted session duration when available.
        final sessions = ref.watch(workoutSessionsProvider).valueOrNull;
        if (sessions != null && sessionId != null) {
          for (final s in sessions) {
            if (s.id == sessionId && s.durationSec > 0) {
              totalDuration = s.durationSec;
            }
          }
        }
        final skipped =
            plannedExercises
                .where((e) => !completedExercises.contains(e))
                .length;
        final mins = totalDuration ~/ 60;
        final secs = totalDuration % 60;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Icon(
              Icons.emoji_events,
              size: 72,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.workoutComplete,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.workoutSaved,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (outcome != null) ...[
              const SizedBox(height: 8),
              Text(
                _outcomeLabel(outcome!),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _SummaryRow(
              icon: Icons.timer_outlined,
              label: l10n.totalTime,
              value: '$mins min $secs s',
            ),
            _SummaryRow(
              icon: Icons.fitness_center,
              label: l10n.exercisesCompleted,
              value:
                  '${completedExercises.length} / ${plannedExercises.length}',
            ),
            _SummaryRow(
              icon: Icons.checklist,
              label: l10n.setsCompleted,
              value:
                  '${logs.where((l) => l.isCompleted).length} / ${planned.length}',
            ),
            _SummaryRow(
              icon: Icons.repeat,
              label: l10n.totalReps,
              value: '$reps',
            ),
            if (weight > 0)
              _SummaryRow(
                icon: Icons.monitor_weight_outlined,
                label: l10n.weightUsed,
                value: '${(weight / 1000).toStringAsFixed(1)} kg',
              ),
            if (skipped > 0)
              _SummaryRow(
                icon: Icons.skip_next,
                label: l10n.skippedExercises,
                value: '$skipped',
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onDone, child: Text(l10n.done)),
          ],
        );
      },
    );
  }

  String _outcomeLabel(SessionOutcome outcome) => switch (outcome) {
    SessionOutcome.completed => l10n.statusCompleted,
    SessionOutcome.partial => l10n.sessionOutcomePartial,
    SessionOutcome.skipped => l10n.statusSkipped,
    SessionOutcome.cancelled => l10n.sessionOutcomeCancelled,
  };
}

/// A single 1–5 readiness question row used by the pre-session check.
class _ReadinessSlider extends StatelessWidget {
  const _ReadinessSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: theme.textTheme.labelLarge),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
}
