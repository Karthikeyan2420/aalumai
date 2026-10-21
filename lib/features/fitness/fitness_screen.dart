import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/equipment_filter.dart';
import 'domain/exercise_collections.dart';
import 'domain/exercise_format.dart';
import 'domain/fitness_goal.dart';
import 'domain/geo.dart';
import 'domain/session_flow.dart';
import 'domain/workout_queue.dart';
import 'exercise_category_screen.dart';
import 'exercise_detail_screen.dart';
import 'run_walk_screen.dart';
import 'widgets/daily_workout_card.dart';
import 'widgets/exercise_gif.dart';
import 'widgets/progress_summary.dart';
import 'widgets/route_map.dart';
import 'widgets/weekly_preview.dart';
import 'workout_plan_screen.dart';
import 'workout_player_screen.dart';
import 'workout_preferences_screen.dart';
import 'yoga_screen.dart';

/// The Fitness module root: four tabs — Home, Workouts, Yoga, Progress.
///
/// Run/Walk is a prominent action on the Home tab, not a primary tab.
/// Gym-only exercises are excluded from every generation, browsing, and
/// substitution path via [isHomeCompatible].
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
            tabs: [
              Tab(text: l10n.navHome),
              Tab(text: l10n.workout),
              Tab(text: l10n.yoga),
              Tab(text: l10n.progress),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_HomeTab(), _WorkoutsTab(), _YogaTab(), _ProgressTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab
// ---------------------------------------------------------------------------

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sessions = ref.watch(workoutSessionsProvider);
    final active =
        sessions.valueOrNull?.where((s) => s.endedAt == null).toList() ??
        const <WorkoutSession>[];
    final now = DateTime.now();
    final dateStr = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header: title + date + settings.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fitness,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.workoutPreferences,
              icon: const Icon(Icons.tune),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WorkoutPreferencesScreen(),
                    ),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const DailyWorkoutCard(),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ResumeCard(session: active.first),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.quickActions,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _QuickActionsRow(),
        const SizedBox(height: 16),
        const WeeklyPreview(),
        const SizedBox(height: 16),
        const ProgressSummary(),
        const SizedBox(height: 16),
        const _WeightTrendCard(),
      ],
    );
  }
}

/// Row of quick-action buttons: Start Today, Customize, Yoga, Run/Walk.
class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => startQuickWorkout(context, ref),
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.startWorkout),
        ),
        OutlinedButton.icon(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutPreferencesScreen(),
                ),
              ),
          icon: const Icon(Icons.tune),
          label: Text(l10n.customizeWorkout),
        ),
        OutlinedButton.icon(
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const YogaScreen())),
          icon: const Icon(Icons.self_improvement),
          label: Text(l10n.yoga),
        ),
        OutlinedButton.icon(
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RunWalkScreen())),
          icon: const Icon(Icons.directions_run),
          label: Text('${l10n.run} / ${l10n.walk}'),
        ),
      ],
    );
  }
}

/// Card shown at the top of the Home tab when an un-finished session exists.
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final steps = WorkoutQueue.decodeSteps(session.routeJson);
    final canResume = steps.isNotEmpty;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.resumeWorkout,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              session.name.isEmpty ? l10n.workout : session.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canResume)
                  FilledButton.icon(
                    onPressed: () => resumeWorkout(context, ref, session),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.resume),
                  ),
                if (canResume) const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      () => ref
                          .read(fitnessRepositoryProvider)
                          .finishSession(
                            session.id,
                            durationSec: session.durationSec,
                          ),
                  child: Text(l10n.finishWorkout),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      () => ref
                          .read(fitnessRepositoryProvider)
                          .deleteSession(session.id),
                ),
              ],
            ),
          ],
        ),
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

// ---------------------------------------------------------------------------
// Workouts tab
// ---------------------------------------------------------------------------

class _WorkoutsTab extends ConsumerStatefulWidget {
  const _WorkoutsTab();

  @override
  ConsumerState<_WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends ConsumerState<_WorkoutsTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final exercises = ref.watch(exercisesProvider);
    final plans = ref.watch(plansProvider).valueOrNull ?? const <WorkoutPlan>[];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fitnessAddPlan',
        onPressed: _createPlan,
        icon: const Icon(Icons.add),
        label: Text(l10n.newPlan),
      ),
      body: exercises.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          final counts = <WorkoutCollection, int>{};
          final custom = <Exercise>[];
          for (final e in list) {
            if (e.isCustom) custom.add(e);
            final collection = exerciseCollection(e);
            if (collection != null) {
              counts.update(collection, (v) => v + 1, ifAbsent: () => 1);
            }
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // Exercise library.
              Text(
                l10n.exercises,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _LibraryCard(
                icon: Icons.grid_view_rounded,
                title: l10n.all,
                count: list.length,
                onTap: () => _openCollection(null),
              ),
              const SizedBox(height: 8),
              for (final collection in homeCollections())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LibraryCard(
                    icon: _collectionIcon(collection),
                    title: workoutCollectionLabel(l10n, collection),
                    count: counts[collection] ?? 0,
                    onTap: () => _openCollection(collection),
                  ),
                ),
              if (custom.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.yourExercises,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in custom)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: ExerciseGif(
                        gifUrl: e.gifUrl,
                        category: e.category,
                        size: 52,
                        borderRadius: 12,
                        timed: e.isTimed,
                      ),
                      title: Text(e.name),
                      subtitle:
                          e.targetMuscles.isEmpty
                              ? null
                              : Text(e.targetMuscles),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => ExerciseDetailScreen(exercise: e),
                            ),
                          ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              // Saved routines / plans.
              Text(
                l10n.plans,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (plans.isEmpty)
                EmptyState(
                  icon: Icons.list_alt,
                  message: l10n.plans,
                  actionLabel: l10n.newPlan,
                  onAction: _createPlan,
                )
              else
                for (final plan in plans)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.fitness_center),
                      ),
                      title: Text(plan.name),
                      trailing: IconButton.filledTonal(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => startGuidedPlan(context, ref, plan),
                      ),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WorkoutPlanScreen(plan: plan),
                            ),
                          ),
                      onLongPress: () async {
                        final ok = await confirmDialog(
                          context,
                          title: l10n.deleteConfirmTitle,
                          body: l10n.deleteConfirmBody,
                          confirmLabel: l10n.delete,
                        );
                        if (ok) {
                          await ref
                              .read(fitnessRepositoryProvider)
                              .deletePlan(plan.id);
                        }
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _openCollection(WorkoutCollection? collection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseCategoryScreen(collection: collection),
      ),
    );
  }

  static IconData _collectionIcon(WorkoutCollection collection) {
    return switch (collection) {
      WorkoutCollection.dumbbell => Icons.fitness_center,
      WorkoutCollection.bodyweight => Icons.sports_gymnastics,
      WorkoutCollection.stretching => Icons.self_improvement,
      WorkoutCollection.band => Icons.waves,
      WorkoutCollection.gym => Icons.warehouse_outlined,
    };
  }

  Future<void> _createPlan() async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.newPlan),
            content: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.planName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(fitnessRepositoryProvider).createPlan(name);
  }
}

// ---------------------------------------------------------------------------
// Yoga tab
// ---------------------------------------------------------------------------

class _YogaTab extends ConsumerWidget {
  const _YogaTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const YogaScreen();
  }
}

// ---------------------------------------------------------------------------
// Progress tab
// ---------------------------------------------------------------------------

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final sessions = ref.watch(workoutSessionsProvider);
    final runs = ref.watch(runsProvider);
    final goals = ref.watch(fitnessGoalsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.progress,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        // Goals.
        goals.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            final week = ref.watch(weeklyActivityProvider);
            final water =
                (ref.watch(waterTodayProvider).valueOrNull ?? const [])
                    .fold<int>(0, (s, w) => s + w.amountMl);
            return SectionCard(
              title: l10n.goals,
              icon: Icons.flag_outlined,
              child: Column(
                children: [
                  for (final goal in list)
                    _GoalTile(goal: goal, week: week, waterTodayMl: water),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Workout history.
        Text(
          l10n.workoutHistory,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        sessions.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (list) {
            final finishedRuns =
                runs.hasValue
                    ? runs.value!.where((s) => s.endedAt != null)
                    : list.where(
                      (s) =>
                          s.endedAt != null && (s.type == 1 || s.type == 2),
                    );
            final done = [
              ...list.where((s) => s.endedAt != null && s.type == 0),
              ...finishedRuns,
            ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
            if (done.isEmpty) {
              return EmptyState(
                icon: Icons.history,
                message: l10n.emptyWorkouts,
              );
            }
            return Column(
              children: [
                for (final s in done)
                  _HistoryTile(session: s, locale: locale),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showMeasurementEditor(context, ref),
          icon: const Icon(Icons.monitor_weight_outlined),
          label: Text(l10n.measurements),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showGoalEditor(context, ref),
          icon: const Icon(Icons.flag_outlined),
          label: Text(l10n.newGoal),
        ),
      ],
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({
    required this.goal,
    required this.week,
    required this.waterTodayMl,
  });

  final FitnessGoal goal;
  final WeeklyActivity week;
  final int waterTodayMl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = goalCurrentValue(
      metric: goal.metric,
      workoutsThisWeek: week.workouts,
      waterTodayMl: waterTodayMl,
      distanceThisWeekMeters: week.distanceMeters,
    );
    final ratio = goalProgress(
      metric: goal.metric,
      targetValue: goal.targetValue,
      workoutsThisWeek: week.workouts,
      waterTodayMl: waterTodayMl,
      distanceThisWeekMeters: week.distanceMeters,
    );
    final unit = goalUnit(goal.metric, ml: 'ml', meters: 'm');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined),
      title: Text(_goalMetricLabel(l10n, goal.metric)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio),
          const SizedBox(height: 4),
          Text('$current / ${goal.targetValue} $unit'.trim()),
        ],
      ),
      onLongPress: () async {
        final ok = await confirmDialog(
          context,
          title: l10n.deleteConfirmTitle,
          body: l10n.deleteConfirmBody,
          confirmLabel: l10n.delete,
        );
        if (ok) {
          await ref.read(fitnessRepositoryProvider).deleteGoal(goal.id);
        }
      },
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.session, required this.locale});

  final WorkoutSession session;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mins = (session.durationSec / 60).round();
    final icon = switch (session.type) {
      1 => Icons.directions_run,
      2 => Icons.directions_walk,
      _ => Icons.fitness_center,
    };
    final trailing =
        session.distanceMeters > 0
            ? '${formatDistanceKm(session.distanceMeters.toDouble())} · $mins ${l10n.duration}'
            : '$mins ${l10n.duration}';
    return ListTile(
      leading: Icon(icon),
      title: Text(session.name.isEmpty ? l10n.workout : session.name),
      subtitle: Text(
        DateFormat.yMMMd(locale).add_Hm().format(session.startedAt),
      ),
      trailing: Text(trailing),
      onTap:
          () =>
              session.type == 1 || session.type == 2
                  ? showRunRoute(context, session)
                  : showSessionDetail(context, session),
      onLongPress: () async {
        final ok = await confirmDialog(
          context,
          title: l10n.deleteConfirmTitle,
          body: l10n.deleteConfirmBody,
          confirmLabel: l10n.delete,
        );
        if (ok) {
          await ref.read(fitnessRepositoryProvider).deleteSession(session.id);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers (exported for use by other modules)
// ---------------------------------------------------------------------------

/// Starts an ad-hoc workout from a set of exercises chosen by the user.
/// Only home-compatible exercises are offered.
Future<void> startQuickWorkout(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(workoutPreferencesProvider).valueOrNull;
  final mode =
      prefs != null
          ? workoutModeFromEquipment(prefs.equipment)
          : WorkoutMode.bodyweight;
  final allExercises = await ref.read(exercisesProvider.future);
  final exercises = filterHomeExercises(allExercises, mode);
  if (!context.mounted) return;
  if (exercises.isEmpty) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.emptyWorkoutExercises)));
    return;
  }
  final chosen = await showModalBottomSheet<List<Exercise>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ExercisePickerSheet(exercises: exercises),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  final steps = WorkoutQueue.buildFromExercises(chosen);
  if (steps.isEmpty) return;
  final l10n = context.l10n;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkoutPlayerScreen(title: l10n.workout, steps: steps),
    ),
  );
}

/// Builds the queue for [plan] and opens the guided player.
Future<void> startGuidedPlan(
  BuildContext context,
  WidgetRef ref,
  WorkoutPlan plan,
) async {
  final repo = ref.read(fitnessRepositoryProvider);
  final items = await repo.watchPlanItems(plan.id).first;
  final exercises = await ref.read(exercisesProvider.future);
  if (!context.mounted) return;
  final existing = await repo.activeSessionForPlan(plan.id);
  if (existing != null && context.mounted) {
    final saved = WorkoutQueue.decodeSteps(existing.routeJson);
    if (saved.isNotEmpty) {
      final l10n = context.l10n;
      final resume = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(l10n.resumeWorkout),
              content: Text(l10n.unfinishedPlan),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.startFresh),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.resume),
                ),
              ],
            ),
      );
      if (!context.mounted || resume == null) return;
      if (resume) {
        await resumeWorkout(context, ref, existing);
        return;
      }
      await repo.finishSession(
        existing.id,
        durationSec: existing.durationSec,
        outcome: SessionOutcome.cancelled.index,
      );
    }
  }
  if (!context.mounted) return;
  final steps = SessionBuilder.buildSession(
    allExercises: exercises,
    items: items,
  );
  if (steps.isEmpty) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.emptyWorkoutExercises)));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => WorkoutPlayerScreen(
            title: plan.name,
            steps: steps,
            planId: plan.id,
            checkReadiness: true,
          ),
    ),
  );
}

/// Restores an interrupted workout at the step it was left on.
Future<void> resumeWorkout(
  BuildContext context,
  WidgetRef ref,
  WorkoutSession session,
) async {
  final steps = WorkoutQueue.decodeSteps(session.routeJson);
  if (steps.isEmpty || !context.mounted) return;
  final l10n = context.l10n;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => WorkoutPlayerScreen(
            title: session.name.isEmpty ? l10n.workout : session.name,
            steps: steps,
            planId: session.planId,
            resumeSessionId: session.id,
            startIndex: session.stepIndex.clamp(0, steps.length - 1),
          ),
    ),
  );
}

/// Multi-select sheet used by the quick workout flow.
class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.exercises});
  final List<Exercise> exercises;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder:
          (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.startWorkout,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          _selected.isEmpty
                              ? null
                              : () => Navigator.pop(
                                context,
                                widget.exercises
                                    .where((e) => _selected.contains(e.id))
                                    .toList(),
                              ),
                      child: Text('${l10n.start} (${_selected.length})'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: widget.exercises.length,
                  itemBuilder: (context, i) {
                    final e = widget.exercises[i];
                    final checked = _selected.contains(e.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged:
                          (v) => setState(() {
                            if (v == true) {
                              _selected.add(e.id);
                            } else {
                              _selected.remove(e.id);
                            }
                          }),
                      secondary: ExerciseGif(
                        gifUrl: e.gifUrl,
                        category: e.category,
                        size: 44,
                        borderRadius: 10,
                        timed: e.isTimed,
                      ),
                      title: Text(e.name),
                      subtitle: Text(
                        exercisePrescription(
                          l10n: l10n,
                          sets: e.defaultSets,
                          reps: e.defaultReps,
                          durationSec: e.defaultDurationSec,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

/// Shows the recorded GPS track for a finished run or walk.
Future<void> showRunRoute(BuildContext context, WorkoutSession session) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _RunRouteSheet(session: session),
  );
}

class _RunRouteSheet extends StatelessWidget {
  const _RunRouteSheet({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = decodeRoute(session.routeJson);
    final pace = paceSecondsPerKm(session.distanceMeters, session.durationSec);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder:
          (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                session.name.isEmpty ? l10n.route : session.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDistanceKm(session.distanceMeters.toDouble())} · ${formatRunDuration(session.durationSec)} · ${formatPace(pace)}',
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: RouteMapView(points: points, emptyHint: l10n.none),
              ),
            ],
          ),
    );
  }
}

/// Shows the set-by-set breakdown of a completed workout session.
Future<void> showSessionDetail(BuildContext context, WorkoutSession session) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _SessionDetailSheet(session: session),
  );
}

class _SessionDetailSheet extends ConsumerWidget {
  const _SessionDetailSheet({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = ref.watch(workoutSetLogsProvider(session.id));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder:
          (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                session.name.isEmpty ? l10n.workout : session.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().add_Hm().format(session.startedAt),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              logs.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: e.toString()),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(l10n.noSetsLogged);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final log in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text('${log.setIndex + 1}'),
                          ),
                          title: Text(
                            exerciseNameFor(context, ref, log.exerciseId) ??
                                l10n.exercise,
                          ),
                          subtitle: Text(
                            [
                              if (log.reps > 0) '${log.reps} ${l10n.reps}',
                              if (log.durationSec > 0) '${log.durationSec}s',
                              if (log.weightGrams > 0)
                                '${(log.weightGrams / 1000).toStringAsFixed(1)} kg',
                            ].join(' · '),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
    );
  }
}

/// Looks up an exercise's name from the cached library, if available.
String? exerciseNameFor(BuildContext context, WidgetRef ref, int exerciseId) {
  final list = ref.watch(exercisesProvider).valueOrNull;
  if (list == null) return null;
  for (final e in list) {
    if (e.id == exerciseId) return e.name;
  }
  return null;
}

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

String _goalMetricLabel(AppLocalizations l10n, int metric) {
  final m =
      FitnessGoalMetric.values[metric.clamp(
        0,
        FitnessGoalMetric.values.length - 1,
      )];
  return switch (m) {
    FitnessGoalMetric.workoutsPerWeek => l10n.goalWorkoutsPerWeek,
    FitnessGoalMetric.waterDaily => l10n.goalWaterDaily,
    FitnessGoalMetric.distanceWeekly => l10n.goalDistanceWeekly,
  };
}

Future<void> showGoalEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final targetCtrl = TextEditingController();
  var metric = FitnessGoalMetric.workoutsPerWeek;
  DateTime? targetDate;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.newGoal),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<FitnessGoalMetric>(
                        value: metric,
                        decoration: InputDecoration(labelText: l10n.metric),
                        items: [
                          for (final m in FitnessGoalMetric.values)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_goalMetricLabel(l10n, m.index)),
                            ),
                        ],
                        onChanged: (v) => setState(() => metric = v ?? metric),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: targetCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.target),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(l10n.targetDate),
                        subtitle: Text(
                          targetDate == null
                              ? '—'
                              : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(targetDate!),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                targetDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => targetDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
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
        ),
  );
  final target = int.tryParse(targetCtrl.text.trim()) ?? 0;
  if (saved == true && target > 0) {
    await ref
        .read(fitnessRepositoryProvider)
        .createGoal(
          metric: metric.index,
          targetValue: target,
          targetDate: targetDate,
        );
  }
}

/// A tappable entry on the exercise library index.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text('$count ${context.l10n.exercises}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
