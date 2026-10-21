import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/equipment_filter.dart';
import 'domain/exercise_collections.dart';
import 'domain/exercise_format.dart';
import 'exercise_detail_screen.dart';
import 'widgets/exercise_gif.dart';

/// The exercise list of one workout collection, with search and filters.
///
/// A null [collection] lists the whole library. Gym-machine exercises are
/// always excluded — the app supports home workouts (bodyweight, free weights,
/// bands and kettlebells) only.
class ExerciseCategoryScreen extends ConsumerStatefulWidget {
  const ExerciseCategoryScreen({super.key, this.collection});

  final WorkoutCollection? collection;

  @override
  ConsumerState<ExerciseCategoryScreen> createState() =>
      _ExerciseCategoryScreenState();
}

class _ExerciseCategoryScreenState
    extends ConsumerState<ExerciseCategoryScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _muscle;
  String? _equipment;
  int? _difficulty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _muscle != null || _equipment != null || _difficulty != null;

  List<Exercise> _visible(List<Exercise> all) {
    final query = _query.trim().toLowerCase();
    return [
      for (final e in all)
        if ((widget.collection == null ||
                exerciseCollection(e) == widget.collection) &&
            !isGymEquipment(e.equipment) &&
            (_muscle == null || exercisePrimaryMuscle(e) == _muscle) &&
            (_equipment == null || e.equipment == _equipment) &&
            (_difficulty == null || e.difficulty == _difficulty) &&
            (query.isEmpty || e.name.toLowerCase().contains(query)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final collection = widget.collection;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          collection == null
              ? l10n.exercises
              : workoutCollectionLabel(l10n, collection),
        ),
      ),
      body: ref
          .watch(exercisesProvider)
          .when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (all) {
              final options = _FilterOptions.from(all);
              final visible = _visible(all);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: l10n.searchExercises,
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                              suffixIcon:
                                  _query.isEmpty
                                      ? null
                                      : IconButton(
                                        icon: const Icon(Icons.close),
                                        tooltip: l10n.clear,
                                        onPressed: () {
                                          _search.clear();
                                          setState(() => _query = '');
                                        },
                                      ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: l10n.filter,
                          onPressed: () => _openFilters(options),
                          icon: Badge(
                            isLabelVisible: _hasFilters,
                            child: const Icon(Icons.tune),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${visible.length} ${l10n.exercises}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (_hasFilters)
                          TextButton.icon(
                            onPressed:
                                () => setState(() {
                                  _muscle = null;
                                  _equipment = null;
                                  _difficulty = null;
                                }),
                            icon: const Icon(Icons.filter_alt_off, size: 18),
                            label: Text(l10n.clear),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        visible.isEmpty
                            ? EmptyState(
                              icon: Icons.search_off,
                              message: l10n.noExercisesMatch,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 24,
                              ),
                              itemCount: visible.length,
                              itemBuilder:
                                  (context, i) =>
                                      _ExerciseTile(exercise: visible[i]),
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _openFilters(_FilterOptions options) async {
    final l10n = context.l10n;
    var muscle = _muscle;
    var equipment = _equipment;
    var difficulty = _difficulty;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheet) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.filter,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _FilterDropdown<String>(
                          label: l10n.muscleGroupsLabel,
                          value: muscle,
                          options: options.muscles,
                          labelFor: (v) => v,
                          onChanged: (v) => setSheet(() => muscle = v),
                        ),
                        const SizedBox(height: 12),
                        _FilterDropdown<String>(
                          label: l10n.equipment,
                          value: equipment,
                          options: options.equipment,
                          labelFor: equipmentLabel,
                          onChanged: (v) => setSheet(() => equipment = v),
                        ),
                        if (options.difficulties.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _FilterDropdown<int>(
                            label: l10n.difficultyLabel,
                            value: difficulty,
                            options: options.difficulties,
                            labelFor: (v) => exerciseDifficultyLabel(l10n, v),
                            onChanged: (v) => setSheet(() => difficulty = v),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => setSheet(() {
                                      muscle = null;
                                      equipment = null;
                                      difficulty = null;
                                    }),
                                child: Text(l10n.clear),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(l10n.done),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (applied == true) {
      setState(() {
        _muscle = muscle;
        _equipment = equipment;
        _difficulty = difficulty;
      });
    }
  }
}

/// One exercise row: animated demonstration, name, muscles, equipment and —
/// only when the dataset publishes one — a difficulty.
class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = [
      if (exercise.targetMuscles.isNotEmpty) exercise.targetMuscles,
      if (exercise.equipment.isNotEmpty) equipmentLabel(exercise.equipment),
      if (hasKnownDifficulty(exercise.difficulty))
        exerciseDifficultyLabel(l10n, exercise.difficulty),
    ].join(' · ');
    return ListTile(
      leading: ExerciseGif(
        gifUrl: exercise.gifUrl,
        category: exercise.category,
        size: 56,
        borderRadius: 12,
        timed: exercise.isTimed,
      ),
      title: Text(exercise.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExerciseDetailScreen(exercise: exercise),
            ),
          ),
    );
  }
}

/// The distinct filter values the loaded library actually contains.
class _FilterOptions {
  const _FilterOptions({
    required this.muscles,
    required this.equipment,
    required this.difficulties,
  });

  factory _FilterOptions.from(List<Exercise> all) {
    final muscles =
        <String>{
            for (final e in all)
              if (exercisePrimaryMuscle(e).isNotEmpty) exercisePrimaryMuscle(e),
          }.toList()
          ..sort();
    final equipment =
        <String>{
            for (final e in all)
              if (e.equipment.isNotEmpty && !isGymEquipment(e.equipment))
                e.equipment,
          }.toList()
          ..sort();
    final difficulties =
        <int>{
            for (final e in all)
              if (hasKnownDifficulty(e.difficulty)) e.difficulty,
          }.toList()
          ..sort();
    return _FilterOptions(
      muscles: muscles,
      equipment: equipment,
      difficulties: difficulties,
    );
  }

  final List<String> muscles;
  final List<String> equipment;

  /// Empty while the dataset publishes no difficulty, in which case the filter
  /// is hidden rather than offering a choice that matches nothing.
  final List<int> difficulties;
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(label),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(value: option, child: Text(labelFor(option))),
      ],
      onChanged: onChanged,
    );
  }
}
