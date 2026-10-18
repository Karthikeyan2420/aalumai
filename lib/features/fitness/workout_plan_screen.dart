import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/session_flow.dart';
import 'widgets/exercise_art.dart';
import 'workout_player_screen.dart';

/// Details of a saved workout plan: its exercises (reorderable, editable), an
/// "add exercise" editor and a button to launch the guided player.
class WorkoutPlanScreen extends ConsumerWidget {
  const WorkoutPlanScreen({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = ref.watch(planItemsProvider(plan.id));
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? const [];
    final byId = {for (final e in exercises) e.id: e};
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workoutPlanAdd',
        onPressed: () => _addItem(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addExercise),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final list = await ref.read(
                    planItemsProvider(plan.id).future,
                  );
                  if (!context.mounted || list.isEmpty) return;
                  final steps = SessionBuilder.buildSession(
                    allExercises: exercises,
                    items: list,
                  );
                  if (steps.isEmpty || !context.mounted) return;
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
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startWorkout),
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.fitness_center,
                    message: l10n.emptyWorkouts,
                    actionLabel: l10n.addExercise,
                    onAction: () => _addItem(context, ref),
                  );
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final reordered = [...list];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    ref
                        .read(fitnessRepositoryProvider)
                        .reorderPlanItems(reordered);
                  },
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final exercise = byId[item.exerciseId];
                    final detail =
                        item.durationSec > 0
                            ? '${item.sets} × ${item.durationSec}s'
                            : '${item.sets} × ${item.reps} ${l10n.reps}';
                    return ListTile(
                      key: ValueKey(item.id),
                      leading: ExerciseArt(
                        category: exercise?.category ?? 0,
                        size: 48,
                        borderRadius: 10,
                        timed: item.durationSec > 0,
                      ),
                      title: Text(exercise?.name ?? ''),
                      subtitle: Text(detail),
                      onTap: () => _editItem(context, ref, item),
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
                              .deletePlanItem(item.id);
                        }
                      },
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlanItem item,
  ) async {
    final l10n = context.l10n;
    final setsCtrl = TextEditingController(text: '${item.sets}');
    final repsCtrl = TextEditingController(text: '${item.reps}');
    final durationCtrl = TextEditingController(text: '${item.durationSec}');
    final save = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.editItem),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.sets),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.reps),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${l10n.duration} (s)',
                    ),
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
    );
    if (save != true) return;
    await ref
        .read(fitnessRepositoryProvider)
        .updatePlanItem(
          itemId: item.id,
          sets: int.tryParse(setsCtrl.text.trim()) ?? item.sets,
          reps: int.tryParse(repsCtrl.text.trim()) ?? item.reps,
          durationSec:
              int.tryParse(durationCtrl.text.trim()) ?? item.durationSec,
        );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final repo = ref.read(fitnessRepositoryProvider);
    final exercises = await ref.read(exercisesProvider.future);
    if (!context.mounted || exercises.isEmpty) return;

    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => ListView(
            children: [
              for (final e in exercises)
                ListTile(
                  leading: ExerciseArt(
                    category: e.category,
                    size: 44,
                    borderRadius: 10,
                    timed: e.isTimed,
                  ),
                  title: Text(e.name),
                  subtitle: Text(e.targetMuscles),
                  onTap: () => Navigator.pop(context, e),
                ),
            ],
          ),
    );
    if (exercise == null || !context.mounted) return;

    final setsCtrl = TextEditingController(text: '${exercise.defaultSets}');
    final repsCtrl = TextEditingController(text: '${exercise.defaultReps}');
    final durationCtrl = TextEditingController(
      text: '${exercise.defaultDurationSec}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(exercise.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.sets),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.reps),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${l10n.duration} (s)',
                    ),
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
    );
    if (save != true) return;

    final existing = await repo.watchPlanItems(plan.id).first;
    await repo.addPlanItem(
      planId: plan.id,
      exerciseId: exercise.id,
      orderIndex: existing.length,
      sets: int.tryParse(setsCtrl.text.trim()) ?? exercise.defaultSets,
      reps: int.tryParse(repsCtrl.text.trim()) ?? exercise.defaultReps,
      durationSec: int.tryParse(durationCtrl.text.trim()) ?? 0,
    );
  }
}
