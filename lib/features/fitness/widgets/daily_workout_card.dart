import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/localization/l10n_extension.dart';
import '../data/fitness_repository.dart';
import '../domain/equipment_filter.dart';
import '../domain/exercise_format.dart';
import '../domain/session_flow.dart';
import '../domain/workout_preferences.dart';
import '../domain/workout_queue.dart';
import '../workout_player_screen.dart';
import 'exercise_gif.dart';

/// Shows today's home workout at the top of the Home tab: the muscle-group
/// focus for the weekday, the workout mode, an estimated duration, the
/// exercise count, and a GIF preview.
///
/// The card previews the actual exercises that will be performed, grouped by
/// phase (warm-up → main work → cool-down), so the user can see the full
/// schedule before starting.
class DailyWorkoutCard extends ConsumerWidget {
  const DailyWorkoutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;
    final exercises = ref.watch(exercisesProvider).valueOrNull;
    if (prefs == null || exercises == null || exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final today = DateTime.now();
    final mode = workoutModeFromEquipment(prefs.equipment);
    final day = WeekPlanGenerator.generateHomeDay(
      date: today,
      preferences: prefs,
      exercises: exercises,
      substitutions: prefs.substitutions,
    );
    if (day == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final focus = WhoDailyPlan.focusFor(today.weekday);
    final recovery = WhoDailyPlan.isRecovery(today.weekday);
    final focusLabel =
        recovery
            ? l10n.activeRecoveryDay
            : focus.map((g) => exerciseCategoryLabel(l10n, g)).join(' + ');
    final weekday = DateFormat.EEEE(
      Localizations.localeOf(context).toString(),
    ).format(today);

    final byId = {for (final e in exercises) e.id: e};
    final mainExercises = <Exercise>[
      for (final item in day.items)
        if (byId[item.exerciseId] case final e?)
          if (e.category != WhoDailyPlan.yoga) e,
    ];
    final warmUps = SessionBuilder.selectWarmUps(exercises, count: 6);
    final coolDowns = SessionBuilder.selectCoolDowns(exercises, count: 3);

    final totalExercises =
        warmUps.length + mainExercises.length + coolDowns.length;
    final estimatedMinutes =
        (WeekPlanGenerator.estimateDurationSec(day.items) / 60).round().clamp(
          10,
          120,
        );
    final modeLabel =
        mode == WorkoutMode.dumbbell
            ? l10n.dumbbellWorkouts
            : l10n.bodyweightWorkouts;

    // Build the same session composition the player will use, so the preview
    // is always truthful.
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.dailyWorkout,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Chip(
                  label: Text(modeLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surface.withValues(alpha: 0.7),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.whoAttribution,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$weekday — $focusLabel',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$modeLabel · $estimatedMinutes ${l10n.minutesShort} · $totalExercises ${l10n.exercises}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            _PhasePreview(
              label: l10n.warmUp,
              icon: Icons.accessibility_new,
              exercises: warmUps,
            ),
            const SizedBox(height: 10),
            _PhasePreview(
              label: l10n.mainWork,
              icon: Icons.fitness_center,
              exercises: mainExercises,
            ),
            const SizedBox(height: 10),
            _PhasePreview(
              label: l10n.coolDown,
              icon: Icons.self_improvement,
              exercises: coolDowns,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _start(context, ref, prefs, exercises),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startTodaysWorkout),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the warm-up, main work and cool-down blocks for today's session.
  /// The day's yoga item becomes the cool-down phase rather than a main set, so
  /// mobility work is never duplicated.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    WorkoutPreferences prefs,
    List<Exercise> exercises,
  ) async {
    final l10n = context.l10n;
    final today = DateTime.now();
    final day = WeekPlanGenerator.generateHomeDay(
      date: today,
      preferences: prefs,
      exercises: exercises,
    );
    if (day == null) return;

    final byId = {for (final e in exercises) e.id: e};
    final main = <Exercise>[
      for (final item in day.items)
        if (byId[item.exerciseId] case final e?)
          if (e.category != WhoDailyPlan.yoga) e,
    ];
    final steps = SessionBuilder.compose(
      warmUp: WorkoutQueue.buildFromExercises(
        SessionBuilder.selectWarmUps(exercises, count: 6),
        phase: SessionPhase.warmUp,
      ),
      main: WorkoutQueue.buildFromExercises(main, phase: SessionPhase.main),
      coolDown: WorkoutQueue.buildFromExercises(
        SessionBuilder.selectCoolDowns(exercises, count: 3),
        phase: SessionPhase.coolDown,
      ),
    );
    if (steps.isEmpty || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => WorkoutPlayerScreen(
              title: l10n.dailyWorkout,
              steps: steps,
              checkReadiness: true,
            ),
      ),
    );
  }
}

/// One phase of the daily session, with its exercises listed compactly.
class _PhasePreview extends StatelessWidget {
  const _PhasePreview({
    required this.label,
    required this.icon,
    required this.exercises,
  });

  final String label;
  final IconData icon;
  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (exercises.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final e in exercises) _ExerciseChip(exercise: e)],
        ),
      ],
    );
  }
}

/// A compact exercise preview: small GIF thumbnail + name.
class _ExerciseChip extends StatelessWidget {
  const _ExerciseChip({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExerciseGif(
            gifUrl: exercise.gifUrl,
            category: exercise.category,
            size: 40,
            borderRadius: 8,
            timed: exercise.isTimed,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              exercise.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
