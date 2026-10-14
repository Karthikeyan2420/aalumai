import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../music/data/music_repository.dart';
import '../music/data/player_service.dart';
import 'data/fitness_repository.dart';
import 'domain/geo.dart';
import 'run_walk_screen.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.fitness),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.workout),
              Tab(text: l10n.exercises),
              Tab(text: l10n.water),
              Tab(text: l10n.workoutHistory),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WorkoutTab(),
            _ExercisesTab(),
            _WaterTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTab extends ConsumerWidget {
  const _WorkoutTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(workoutSessionsProvider);
    final active =
        sessions.valueOrNull?.where((s) => s.endedAt == null).toList() ??
        const <WorkoutSession>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _WaterQuickAdd(),
        const SizedBox(height: 12),
        if (active.isEmpty)
          FilledButton.icon(
            onPressed: () async {
              final id = await ref
                  .read(fitnessRepositoryProvider)
                  .startSession(name: l10n.workout);
              if (!context.mounted) return;
              await _startWorkout(context, ref, id);
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startWorkout),
          )
        else
          FilledButton.icon(
            onPressed: () => _startWorkout(context, ref, active.first.id),
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.resume),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showMeasurementEditor(context, ref),
          icon: const Icon(Icons.monitor_weight_outlined),
          label: Text(l10n.measurements),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RunWalkScreen())),
          icon: const Icon(Icons.directions_run),
          label: Text('${l10n.run} / ${l10n.walk}'),
        ),
        const _WeightTrendCard(),
      ],
    );
  }

  Future<void> _startWorkout(
    BuildContext context,
    WidgetRef ref,
    int sessionId,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(sessionId: sessionId),
      ),
    );
  }
}

class _WeightTrendCard extends ConsumerWidget {
  const _WeightTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final measurements = ref.watch(measurementsProvider);
    final points =
        (measurements.valueOrNull ?? const [])
            .where((m) => m.weightGrams > 0)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (points.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        title: l10n.weightTrend,
        icon: Icons.show_chart,
        child: SimpleLineChart(
          points: [
            for (final m in points)
              ChartSlice(
                label: DateFormat.Md().format(m.date),
                value: m.weightGrams / 1000,
              ),
          ],
        ),
      ),
    );
  }
}

class _WaterQuickAdd extends ConsumerWidget {
  const _WaterQuickAdd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final water = ref.watch(waterTodayProvider);
    final goal = ref.watch(appPreferencesProvider).dailyWaterGoalMl;
    final total = (water.valueOrNull ?? const []).fold<int>(
      0,
      (s, w) => s + w.amountMl,
    );
    final ratio = goal <= 0 ? 0.0 : (total / goal).clamp(0.0, 1.0);
    return SectionCard(
      title: l10n.waterIntake,
      icon: Icons.water_drop_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: ratio.toDouble()),
          const SizedBox(height: 8),
          Text('$total / $goal ml'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final ml in [200, 300, 500])
                ActionChip(
                  label: Text('+$ml ml'),
                  onPressed:
                      () => ref.read(fitnessRepositoryProvider).addWater(ml),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExercisesTab extends ConsumerWidget {
  const _ExercisesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider);
    return exercises.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data:
          (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(e.name),
                subtitle: Text('${e.targetMuscles} · ${e.equipment}'),
                onTap: () => _showExercise(context, e),
              );
            },
          ),
    );
  }

  void _showExercise(BuildContext context, Exercise e) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(e.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${l10n.targetMuscles}: ${e.targetMuscles}'),
                Text('${l10n.equipment}: ${e.equipment}'),
                Text(
                  '${l10n.sets}: ${e.defaultSets} · ${l10n.reps}: ${e.defaultReps}',
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.instructions,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(e.instructions),
                if (e.safetyNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.safetyNotes,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(e.safetyNotes),
                ],
              ],
            ),
          ),
    );
  }
}

class _WaterTab extends ConsumerWidget {
  const _WaterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _WaterQuickAdd();
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final sessions = ref.watch(workoutSessionsProvider);
    return sessions.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (list) {
        final done = list.where((s) => s.endedAt != null).toList();
        if (done.isEmpty) {
          return EmptyState(icon: Icons.history, message: l10n.emptyWorkouts);
        }
        return ListView.builder(
          itemCount: done.length,
          itemBuilder: (context, i) {
            final s = done[i];
            final mins = (s.durationSec / 60).round();
            final icon = switch (s.type) {
              1 => Icons.directions_run,
              2 => Icons.directions_walk,
              _ => Icons.fitness_center,
            };
            final trailing =
                s.distanceMeters > 0
                    ? '${formatDistanceKm(s.distanceMeters.toDouble())} · $mins ${l10n.duration}'
                    : '$mins ${l10n.duration}';
            return ListTile(
              leading: Icon(icon),
              title: Text(s.name.isEmpty ? l10n.workout : s.name),
              subtitle: Text(
                DateFormat.yMMMd(locale).add_Hm().format(s.startedAt),
              ),
              trailing: Text(trailing),
              onLongPress: () async {
                final ok = await confirmDialog(
                  context,
                  title: l10n.deleteConfirmTitle,
                  body: l10n.deleteConfirmBody,
                  confirmLabel: l10n.delete,
                );
                if (ok) {
                  await ref.read(fitnessRepositoryProvider).deleteSession(s.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

/// A live workout: logs sets and runs a simple rest timer.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _restTimer;
  int _restRemaining = 0;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.workoutMusicEnabled) {
      final tracks = ref.read(musicTracksProvider).valueOrNull ?? const [];
      if (tracks.isNotEmpty) {
        ref.read(musicPlayerProvider.notifier).playQueue(tracks, 0);
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.workoutMusicEnabled && prefs.workoutMusicPauseOnRest) {
      ref.read(musicPlayerProvider.notifier).togglePlay();
    }
    setState(() => _restRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() => _restRemaining = 0);
        if (prefs.workoutMusicEnabled && prefs.workoutMusicPauseOnRest) {
          ref.read(musicPlayerProvider.notifier).togglePlay();
        }
      } else {
        setState(() => _restRemaining--);
      }
    });
  }

  Future<void> _addSet() async {
    final l10n = context.l10n;
    final exercises = await ref.read(exercisesProvider.future);
    if (!mounted || exercises.isEmpty) return;
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => ListView(
            children: [
              for (final e in exercises)
                ListTile(
                  title: Text(e.name),
                  subtitle: Text(e.targetMuscles),
                  onTap: () => Navigator.pop(context, e),
                ),
            ],
          ),
    );
    if (exercise == null || !mounted) return;

    final repsCtrl = TextEditingController(text: '${exercise.defaultReps}');
    final weightCtrl = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(exercise.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.reps),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.weight),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (save != true) return;
    final reps = int.tryParse(repsCtrl.text.trim()) ?? exercise.defaultReps;
    final weightKg = double.tryParse(weightCtrl.text.trim()) ?? 0;
    final logs =
        await ref
            .read(fitnessRepositoryProvider)
            .watchSetLogs(widget.sessionId)
            .first;
    await ref
        .read(fitnessRepositoryProvider)
        .logSet(
          sessionId: widget.sessionId,
          exerciseId: exercise.id,
          setIndex: logs.length,
          reps: reps,
          weightGrams: (weightKg * 1000).round(),
          restSec: exercise.restSec,
        );
    await ref
        .read(fitnessRepositoryProvider)
        .updatePersonalRecord(
          exerciseId: exercise.id,
          recordType: 0,
          value: (weightKg * 1000).round(),
        );
    _startRest(exercise.restSec);
  }

  Future<void> _finish() async {
    await ref
        .read(fitnessRepositoryProvider)
        .finishSession(
          widget.sessionId,
          durationSec: _stopwatch.elapsed.inSeconds,
        );
    if (ref.read(appPreferencesProvider).workoutMusicStopAtEnd) {
      ref.read(musicPlayerProvider.notifier).togglePlay();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final logs = ref.watch(_setLogsProvider(widget.sessionId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workout),
        actions: [
          TextButton(onPressed: _finish, child: Text(l10n.finishWorkout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSet,
        icon: const Icon(Icons.add),
        label: Text(l10n.sets),
      ),
      body: Column(
        children: [
          if (_restRemaining > 0)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Text('${l10n.rest}: ${_restRemaining}s'),
                ],
              ),
            ),
          Expanded(
            child: logs.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data:
                  (list) =>
                      list.isEmpty
                          ? EmptyState(
                            icon: Icons.fitness_center,
                            message: l10n.emptyWorkouts,
                            actionLabel: l10n.sets,
                            onAction: _addSet,
                          )
                          : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final log = list[i];
                              return ListTile(
                                leading: CircleAvatar(child: Text('${i + 1}')),
                                title: Text('${log.reps} ${l10n.reps}'),
                                subtitle: Text(
                                  '${(log.weightGrams / 1000).toStringAsFixed(1)} kg',
                                ),
                              );
                            },
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

final _setLogsProvider = StreamProvider.family<List<WorkoutSetLog>, int>((
  ref,
  sessionId,
) {
  return ref.watch(fitnessRepositoryProvider).watchSetLogs(sessionId);
});

Future<void> showMeasurementEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final weightCtrl = TextEditingController();
  final waistCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.measurements),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.bodyweight),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waistCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.measurements),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
  );
  final weight = double.tryParse(weightCtrl.text.trim());
  final waist = double.tryParse(waistCtrl.text.trim()) ?? 0;
  if (saved == true && weight != null && weight > 0) {
    await ref
        .read(fitnessRepositoryProvider)
        .addMeasurement(
          date: DateTime.now(),
          weightGrams: (weight * 1000).round(),
          waistCm: waist,
        );
  }
}
