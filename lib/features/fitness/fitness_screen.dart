import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/exercise_collections.dart';
import 'domain/exercise_format.dart';
import 'domain/fitness_goal.dart';
import 'domain/geo.dart';
import 'domain/session_flow.dart';
import 'domain/workout_queue.dart';
import 'exercise_category_screen.dart';
import 'exercise_detail_screen.dart';
import 'run_walk_screen.dart';
import 'weekly_planner_screen.dart';
import 'widgets/daily_workout_card.dart';
import 'widgets/exercise_art.dart';
import 'workout_plan_screen.dart';
import 'workout_player_screen.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.fitness),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.workout),
              Tab(text: l10n.exercises),
              Tab(text: l10n.plans),
              Tab(text: l10n.goals),
              Tab(text: l10n.water),
              Tab(text: l10n.workoutHistory),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WorkoutTab(),
            _ExercisesTab(),
            _PlansTab(),
            _GoalsTab(),
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
    final plans = ref.watch(plansProvider).valueOrNull ?? const <WorkoutPlan>[];
    final active =
        sessions.valueOrNull?.where((s) => s.endedAt == null).toList() ??
        const <WorkoutSession>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DailyWorkoutCard(),
        const SizedBox(height: 16),
        if (active.isNotEmpty) ...[
          _ResumeCard(session: active.first),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: () => startQuickWorkout(context, ref),
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.startWorkout),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WeeklyPlannerScreen(),
                ),
              ),
          icon: const Icon(Icons.view_week_outlined),
          label: Text(l10n.weeklyPlanner),
        ),
        const SizedBox(height: 16),
        const _WhoProgressCard(),
        const SizedBox(height: 16),
        if (plans.isNotEmpty) ...[
          Text(l10n.plans, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final plan in plans)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
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
              ),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),
        const _WaterQuickAdd(),
        const _WeightTrendCard(),
      ],
    );
  }
}

/// Card shown at the top of the workout tab when an un-finished session exists.
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

/// Starts an ad-hoc workout from a set of exercises chosen by the user.
Future<void> startQuickWorkout(BuildContext context, WidgetRef ref) async {
  final exercises = await ref.read(exercisesProvider.future);
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
                      secondary: ExerciseArt(
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

class _ExercisesTab extends ConsumerStatefulWidget {
  const _ExercisesTab();

  @override
  ConsumerState<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<_ExercisesTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercises = ref.watch(exercisesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fitnessAddExercise',
        onPressed: () => _addCustomExercise(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newExercise),
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
              _LibraryCard(
                icon: Icons.grid_view_rounded,
                title: l10n.all,
                count: list.length,
                onTap: () => _openCollection(context, null),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.category,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final collection in WorkoutCollection.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LibraryCard(
                    icon: _collectionIcon(collection),
                    title: workoutCollectionLabel(l10n, collection),
                    count: counts[collection] ?? 0,
                    onTap: () => _openCollection(context, collection),
                  ),
                ),
              if (custom.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.yourExercises,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final e in custom)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: ExerciseArt(
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
                              builder: (_) => ExerciseDetailScreen(exercise: e),
                            ),
                          ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openCollection(BuildContext context, WorkoutCollection? collection) {
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

  Future<void> _addCustomExercise(BuildContext context) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final musclesCtrl = TextEditingController();
    final equipmentCtrl = TextEditingController();
    final instructionsCtrl = TextEditingController();
    var category = 0;
    var isTimed = false;
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(l10n.newExercise),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          autofocus: true,
                          decoration: InputDecoration(labelText: l10n.name),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: category,
                          decoration: InputDecoration(labelText: l10n.category),
                          items: [
                            for (var c = 0; c <= 8; c++)
                              DropdownMenuItem(
                                value: c,
                                child: Text(exerciseCategoryLabel(l10n, c)),
                              ),
                          ],
                          onChanged:
                              (v) => setState(() => category = v ?? category),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: musclesCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.targetMuscles,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: equipmentCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.equipment,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: instructionsCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(labelText: l10n.howTo),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isTimed,
                          onChanged: (v) => setState(() => isTimed = v),
                          title: Text(l10n.timedExercise),
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
    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    await ref
        .read(fitnessRepositoryProvider)
        .addCustomExercise(
          name: nameCtrl.text.trim(),
          category: category,
          targetMuscles: musclesCtrl.text.trim(),
          equipment: equipmentCtrl.text.trim(),
          instructions: instructionsCtrl.text.trim(),
          isTimed: isTimed,
          reps: isTimed ? 0 : 10,
          durationSec: isTimed ? 30 : 0,
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

class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plans = ref.watch(plansProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fitnessAddPlan',
        onPressed: () => _createPlan(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newPlan),
      ),
      body: plans.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.list_alt,
              message: l10n.plans,
              actionLabel: l10n.newPlan,
              onAction: () => _createPlan(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final plan = list[i];
              return ListTile(
                leading: const Icon(Icons.fitness_center),
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
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
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

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(fitnessGoalsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fitnessAddGoal',
        onPressed: () => showGoalEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newGoal),
      ),
      body: goals.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              message: l10n.goals,
              actionLabel: l10n.newGoal,
              onAction: () => showGoalEditor(context, ref),
            );
          }
          final week = ref.watch(weeklyActivityProvider);
          final water = (ref.watch(waterTodayProvider).valueOrNull ?? const [])
              .fold<int>(0, (s, w) => s + w.amountMl);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final goal = list[i];
              final current = goalCurrentValue(
                metric: goal.metric,
                workoutsThisWeek: week.workouts,
                waterTodayMl: water,
                distanceThisWeekMeters: week.distanceMeters,
              );
              final ratio = goalProgress(
                metric: goal.metric,
                targetValue: goal.targetValue,
                workoutsThisWeek: week.workouts,
                waterTodayMl: water,
                distanceThisWeekMeters: week.distanceMeters,
              );
              final unit = goalUnit(goal.metric, ml: 'ml', meters: 'm');
              return ListTile(
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
                    await ref
                        .read(fitnessRepositoryProvider)
                        .deleteGoal(goal.id);
                  }
                },
              );
            },
          );
        },
      ),
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
                        title: Text(l10n.taskDue),
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
              onTap: s.type == 0 ? () => showSessionDetail(context, s) : null,
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
                            '${log.reps} ${l10n.reps}'
                            '${log.weightGrams > 0 ? ' · ${(log.weightGrams / 1000).toStringAsFixed(1)} kg' : ''}',
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

/// Weekly activity progress framed against the WHO physical-activity guidance.
/// Advisory only — never presented as medical advice or a "WHO certification".
class _WhoProgressCard extends ConsumerWidget {
  const _WhoProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final progress = ref.watch(whoWeeklyProgressProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.activityGuidance,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (progress.meetsAll)
                  Chip(
                    label: Text(l10n.whoGoalMet),
                    avatar: const Icon(Icons.check_circle, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.whoAttribution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _WhoRow(
              icon: Icons.favorite_outline,
              label: l10n.whoAerobicLabel,
              value: l10n.whoAerobicValue(progress.moderateEquivalentMinutes),
              goal: l10n.whoAerobicGoal,
              met: progress.meetsAerobic,
              progress: progress.aerobicProgress,
            ),
            const SizedBox(height: 12),
            _WhoRow(
              icon: Icons.fitness_center,
              label: l10n.whoStrengthLabel,
              value: l10n.whoStrengthValue(progress.strengthDays),
              goal: l10n.whoStrengthGoal,
              met: progress.meetsStrength,
              progress: progress.strengthProgress,
            ),
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(Icons.tips_and_updates_outlined, size: 20),
                title: Text(
                  l10n.whoTips,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  _WhoTip(text: l10n.whoTipProgression),
                  _WhoTip(text: l10n.whoTipWalking),
                  _WhoTip(text: l10n.whoTipStrength),
                  _WhoTip(text: l10n.whoTipAdapt),
                ],
              ),
            ),
            Text(
              l10n.whoDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhoRow extends StatelessWidget {
  const _WhoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.met,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String goal;
  final bool met;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              met ? Icons.check_circle : icon,
              size: 18,
              color:
                  met ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
        const SizedBox(height: 2),
        Text(
          goal,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WhoTip extends StatelessWidget {
  const _WhoTip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
