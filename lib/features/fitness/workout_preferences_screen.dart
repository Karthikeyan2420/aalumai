import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/equipment_filter.dart';
import 'domain/exercise_format.dart';
import 'domain/workout_preferences.dart';

/// Edits the user-configurable workout preferences. Equipment is a simple
/// two-mode choice: bodyweight-only or dumbbells-at-home. No gym selection
/// is offered.
class WorkoutPreferencesScreen extends ConsumerStatefulWidget {
  const WorkoutPreferencesScreen({super.key});

  @override
  ConsumerState<WorkoutPreferencesScreen> createState() =>
      _WorkoutPreferencesScreenState();
}

class _WorkoutPreferencesScreenState
    extends ConsumerState<WorkoutPreferencesScreen> {
  WorkoutPreferences? _prefs;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(workoutPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.customizeWorkout)),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (loaded) {
          _prefs ??= loaded;
          final prefs = _prefs!;
          final mode = workoutModeFromEquipment(prefs.equipment);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              // Equipment mode: bodyweight or dumbbells.
              _section(
                l10n.equipment,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<WorkoutMode>(
                      segments: [
                        ButtonSegment(
                          value: WorkoutMode.bodyweight,
                          label: Text(l10n.bodyweightWorkouts),
                          icon: const Icon(Icons.sports_gymnastics),
                        ),
                        ButtonSegment(
                          value: WorkoutMode.dumbbell,
                          label: Text(l10n.dumbbellWorkouts),
                          icon: const Icon(Icons.fitness_center),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) {
                        final next = s.first;
                        _update(
                          prefs.copyWith(equipment: equipmentForMode(next)),
                        );
                      },
                    ),
                    if (mode == WorkoutMode.dumbbell) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.dumbbellWeightHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Fitness level.
              _section(
                l10n.fitnessLevelLabel,
                _choiceChips<FitnessLevel>(
                  values: FitnessLevel.values,
                  selected: prefs.fitnessLevel,
                  label: (v) => exerciseDifficultyLabel(l10n, v.index),
                  onSelected: (v) => _update(prefs.copyWith(fitnessLevel: v)),
                ),
              ),
              // Goal.
              _section(l10n.primaryGoalLabel, _goalDropdown(prefs, l10n)),
              // Session duration.
              _section(l10n.sessionLengthLabel, _minutesSlider(prefs, l10n)),
              // Training days.
              _section(
                l10n.trainingDaysLabel,
                _dayToggleRow(prefs.trainingDaysMask, l10n, (mask) {
                  _update(prefs.copyWith(trainingDaysMask: mask));
                }),
              ),
              // Rest days.
              _section(
                l10n.restDaysLabel,
                _dayToggleRow(prefs.restDaysMask, l10n, (mask) {
                  _update(prefs.copyWith(restDaysMask: mask));
                }),
              ),
              // Target muscles.
              _section(l10n.focusMusclesLabel, _muscleChips(prefs, l10n)),
              // Safety.
              _safetyCard(prefs, l10n),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.savePreferences),
              ),
            ],
          );
        },
      ),
    );
  }

  void _update(WorkoutPreferences next) => setState(() => _prefs = next);

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() => _saving = true);
    await ref.read(fitnessRepositoryProvider).savePreferences(prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.preferencesSaved)));
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _choiceChips<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: v == selected,
          onSelected: (_) => onSelected(v),
        ),
    ],
  );

  Widget _minutesSlider(WorkoutPreferences prefs, AppLocalizations l10n) {
    final minutes = prefs.sessionMinutes.clamp(30, 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$minutes ${l10n.minutesShort}'),
        Slider(
          value: minutes.toDouble(),
          min: 30,
          max: 120,
          divisions: 18,
          label: '$minutes ${l10n.minutesShort}',
          onChanged: (v) => _update(prefs.copyWith(sessionMinutes: v.round())),
        ),
      ],
    );
  }

  Widget _dayToggleRow(
    int mask,
    AppLocalizations l10n,
    ValueChanged<int> onChanged,
  ) {
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    return Wrap(
      spacing: 8,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++)
          FilterChip(
            label: Text(narrow[weekday % 7]),
            selected: TrainingDays.has(mask, weekday),
            onSelected: (_) => onChanged(TrainingDays.toggle(mask, weekday)),
          ),
      ],
    );
  }

  Widget _goalDropdown(WorkoutPreferences prefs, AppLocalizations l10n) {
    return DropdownButtonFormField<WorkoutGoal>(
      value: prefs.goal,
      items: [
        for (final g in WorkoutGoal.values)
          DropdownMenuItem(value: g, child: Text(_goalLabel(l10n, g))),
      ],
      onChanged: (v) {
        if (v != null) _update(prefs.copyWith(goal: v));
      },
    );
  }

  String _goalLabel(AppLocalizations l10n, WorkoutGoal g) {
    return switch (g) {
      WorkoutGoal.generalHealth => l10n.goalGeneralHealth,
      WorkoutGoal.strength => l10n.goalStrength,
      WorkoutGoal.endurance => l10n.goalEndurance,
      WorkoutGoal.flexibility => l10n.goalFlexibility,
      WorkoutGoal.weightManagement => l10n.goalWeightManagement,
    };
  }

  Widget _muscleChips(WorkoutPreferences prefs, AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var c = 0; c <= 7; c++)
          FilterChip(
            label: Text(exerciseCategoryLabel(l10n, c)),
            selected: prefs.goalMuscles.contains(c),
            onSelected: (selected) {
              final next = [...prefs.goalMuscles];
              if (selected) {
                next.add(c);
              } else {
                next.remove(c);
              }
              _update(prefs.copyWith(goalMuscles: next..sort()));
            },
          ),
      ],
    );
  }

  Widget _safetyCard(WorkoutPreferences prefs, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.safetyGuidanceTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.safetyGuidanceBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.safetyTemplateNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: prefs.safetyAcknowledged,
              onChanged:
                  (v) =>
                      _update(prefs.copyWith(safetyAcknowledged: v ?? false)),
              title: Text(l10n.safetyAcknowledged),
            ),
          ],
        ),
      ),
    );
  }
}
