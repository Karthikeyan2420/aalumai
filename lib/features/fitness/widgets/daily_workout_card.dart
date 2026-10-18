import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/localization/l10n_extension.dart';
import '../data/fitness_repository.dart';
import '../domain/exercise_format.dart';
import '../domain/session_flow.dart';
import '../domain/workout_preferences.dart';
import '../domain/workout_queue.dart';
import '../workout_player_screen.dart';

/// Shows today's WHO-informed session at the top of the workout tab: the
/// strength focus for the weekday plus a cardio block, finished with yoga.
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
    final day = WeekPlanGenerator.generateWhoDay(
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
              '$weekday · $focusLabel',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: l10n.cardioEveryDay, icon: Icons.directions_run),
                _Chip(label: l10n.yogaCooldown, icon: Icons.self_improvement),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.yogaAfterWorkout,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
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
    final day = WeekPlanGenerator.generateWhoDay(
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
        SessionBuilder.selectWarmUps(exercises, count: 3),
        phase: SessionPhase.warmUp,
      ),
      main: WorkoutQueue.buildFromExercises(main, phase: SessionPhase.main),
      coolDown: WorkoutQueue.buildFromExercises(
        SessionBuilder.selectCoolDowns(exercises, count: 2),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurface),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
