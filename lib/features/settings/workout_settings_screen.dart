import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/widgets/common.dart';
import '../fitness/data/fitness_repository.dart';
import '../fitness/domain/equipment_filter.dart';
import '../fitness/domain/exercise_collections.dart';
import '../fitness/domain/exercise_format.dart';
import '../fitness/domain/workout_preferences.dart';

/// Settings → Workout. Lets the user choose exactly which equipment and which
/// muscle-group categories may appear in the generated daily workout. The
/// selection is persisted on [WorkoutPreferences] (`equipment` and
/// `goalMuscles`), so it survives restarts and drives every generated day.
class WorkoutSettingsScreen extends ConsumerStatefulWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  ConsumerState<WorkoutSettingsScreen> createState() =>
      _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends ConsumerState<WorkoutSettingsScreen> {
  WorkoutPreferences? _prefs;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(workoutPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workoutSettings)),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (loaded) {
          _prefs ??= loaded;
          final prefs = _prefs!;
          final equipment = _selectedEquipment(prefs);
          final muscles = prefs.goalMuscles.toSet();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Text(
                l10n.workoutCategoriesHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _sectionHeader(l10n.equipment),
              for (final key in kSelectableEquipment)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: equipment.contains(key),
                  title: Text(_equipmentLabel(l10n, key)),
                  onChanged: (on) => _toggleEquipment(prefs, key, on ?? false),
                ),
              const SizedBox(height: 8),
              _sectionHeader(l10n.focusMusclesLabel),
              for (final group in kSelectableMuscleGroups)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: muscles.contains(group),
                  title: Text(exerciseCategoryLabel(l10n, group)),
                  onChanged: (on) => _toggleMuscle(prefs, group, on ?? false),
                ),
              const SizedBox(height: 20),
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

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Set<String> _selectedEquipment(WorkoutPreferences prefs) {
    if (prefs.equipment.isEmpty) {
      return defaultEquipmentSelection().toSet();
    }
    return prefs.equipment.map((e) => e.trim().toLowerCase()).toSet();
  }

  /// Never lets the user clear the last piece of equipment: at least bodyweight
  /// has to remain so a workout can always be generated.
  void _toggleEquipment(WorkoutPreferences prefs, String key, bool on) {
    final next = _selectedEquipment(prefs);
    if (on) {
      next.add(key);
    } else {
      next.remove(key);
    }
    if (next.isEmpty) return;
    // Persist in the canonical order so the stored list stays stable.
    final ordered = [
      for (final k in kSelectableEquipment)
        if (next.contains(k)) k,
    ];
    _update(prefs.copyWith(equipment: ordered));
  }

  /// Never lets the user clear the last muscle group, so the day is never empty.
  void _toggleMuscle(WorkoutPreferences prefs, int group, bool on) {
    final next = prefs.goalMuscles.toSet();
    if (on) {
      next.add(group);
    } else {
      next.remove(group);
    }
    if (next.isEmpty) return;
    final ordered = [
      for (final g in kSelectableMuscleGroups)
        if (next.contains(g)) g,
    ];
    _update(prefs.copyWith(goalMuscles: ordered));
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

  String _equipmentLabel(AppLocalizations l10n, String key) {
    if (key == 'bodyweight') return l10n.equipmentBodyweight;
    return equipmentLabel(key);
  }
}
