import '../../../core/db/database.dart';

/// The two supported workout modes. The app never offers gym machines.
///
/// [dumbbell] covers a home setup with dumbbells and a barbell/ez-bar; the
/// heavier free weights are treated as home equipment, not gym-only.
enum WorkoutMode { bodyweight, dumbbell }

/// Equipment values that are allowed for home use — everything else is
/// gym-only and filtered out of every generation, browsing, and
/// substitution path in the app.
const kHomeEquipment = {
  'bodyweight',
  '',
  'dumbbell',
  'barbell',
  'ez-bar',
  'band',
  'kettlebell',
};

/// Equipment values that require a gym. Never selectable, never generated.
const kGymEquipment = {'cable', 'machine', 'lever', 'smith', 'sled', 'other'};

/// Free-weight equipment unlocked by the dumbbell (home weights) mode.
const kDumbbellModeEquipment = {'dumbbell', 'barbell', 'ez-bar'};

/// The home equipment keys a user can choose from in Settings → Workout, in
/// display order. This is the subset the app supports for home training; gym
/// machines are never offered.
const kSelectableEquipment = <String>[
  'bodyweight',
  'dumbbell',
  'barbell',
  'ez-bar',
  'band',
  'kettlebell',
];

/// Equipment the user has selected that can appear in a generated day.
///
/// Bodyweight (and rows with no equipment recorded) is always usable and is
/// gated on the user selecting "No equipment"; any other key must have been
/// explicitly selected.
bool isEquipmentSelected(String equipment, Set<String> selected) {
  final key = equipment.trim().toLowerCase();
  if (key.isEmpty || key == 'none' || key == 'bodyweight') {
    return selected.contains('bodyweight');
  }
  return selected.contains(key);
}

/// The default equipment selection when the user has never configured one:
/// bodyweight plus the common home free weights.
List<String> defaultEquipmentSelection() => const [
  'bodyweight',
  'dumbbell',
  'barbell',
];

/// The muscle-group category indexes a user can enable for the daily workout,
/// in display order (0 arms … 7 yoga/mobility). Cardio and mobility are included
/// so the user can drop the aerobic or cool-down blocks too.
const kSelectableMuscleGroups = <int>[0, 1, 2, 3, 4, 5, 6, 7];

/// Returns true when [equipment] can be performed at home with the selected
/// mode. Bodyweight exercises are always allowed; free weights (dumbbell,
/// barbell, ez-bar) are allowed only when the user has chosen the weights mode.
bool isHomeCompatible(String equipment, WorkoutMode mode) {
  final key = equipment.trim().toLowerCase();
  if (key.isEmpty || key == 'none' || key == 'bodyweight') return true;
  if (mode == WorkoutMode.dumbbell && kDumbbellModeEquipment.contains(key)) {
    return true;
  }
  return false;
}

/// Returns true when [equipment] requires gym-only machines or bars.
bool isGymEquipment(String equipment) {
  return kGymEquipment.contains(equipment.trim().toLowerCase());
}

/// Filters [exercises] down to those compatible with [mode].
///
/// This is the single entry point every generation, browsing, and
/// substitution path uses. It must never be bypassed.
List<Exercise> filterHomeExercises(List<Exercise> exercises, WorkoutMode mode) {
  return exercises
      .where((e) => isHomeCompatible(e.equipment, mode))
      .toList();
}

/// Derives the workout mode from a stored equipment list. The list is the
/// CSV-persisted `WorkoutPrefs.equipment` column. Any free weight implies the
/// weights mode.
WorkoutMode workoutModeFromEquipment(List<String> equipment) {
  final hasWeights = equipment.any((e) {
    final key = e.trim().toLowerCase();
    return kDumbbellModeEquipment.any(key.contains);
  });
  return hasWeights ? WorkoutMode.dumbbell : WorkoutMode.bodyweight;
}

/// The equipment list to persist for a given mode.
List<String> equipmentForMode(WorkoutMode mode) {
  return switch (mode) {
    WorkoutMode.bodyweight => const ['bodyweight'],
    WorkoutMode.dumbbell => const ['bodyweight', 'dumbbell', 'barbell'],
  };
}
