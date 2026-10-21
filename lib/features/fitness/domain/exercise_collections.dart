import '../../../core/db/database.dart';

/// The equipment-based collections the exercise library is browsed by.
///
/// Declaration order is the order the categories are presented in the UI.
enum WorkoutCollection { dumbbell, bodyweight, stretching, band, gym }

/// The collections shown in the app. Only gym machines are excluded — the app
/// supports bodyweight, free-weight, band and kettlebell home workouts.
const kHomeCollections = <WorkoutCollection>{
  WorkoutCollection.bodyweight,
  WorkoutCollection.dumbbell,
  WorkoutCollection.stretching,
  WorkoutCollection.band,
};

/// The equipment-based collections the exercise library is browsed by.
/// Only home-compatible collections are included.
List<WorkoutCollection> homeCollections() =>
    WorkoutCollection.values.where(kHomeCollections.contains).toList();

/// Files an exercise into a [WorkoutCollection] from its *metadata* — the
/// equipment it needs and the movement category the dataset publishes — never
/// from its name, so an exercise can never be filed by a coincidence of
/// wording.
///
/// Returns null when a row carries nothing classifiable (for example an
/// exercise the user typed in by hand); such rows stay visible under "All"
/// instead of being mis-filed into a collection they do not belong to.
WorkoutCollection? workoutCollectionFor({
  required String equipment,
  required String sourceCategory,
}) {
  // Stretching wins over equipment: a band or dumbbell stretch is mobility
  // work, not a strength exercise.
  if (sourceCategory.trim().toLowerCase() == 'stretching') {
    return WorkoutCollection.stretching;
  }
  return switch (equipment.trim().toLowerCase()) {
    'dumbbell' || 'barbell' || 'ez-bar' || 'kettlebell' =>
      WorkoutCollection.dumbbell,
    'band' => WorkoutCollection.band,
    'bodyweight' => WorkoutCollection.bodyweight,
    'cable' || 'machine' || 'lever' || 'smith' || 'sled' || 'other' =>
      WorkoutCollection.gym,
    _ => null,
  };
}

/// The collection a stored exercise row belongs to (null when unclassified).
WorkoutCollection? exerciseCollection(Exercise exercise) =>
    workoutCollectionFor(
      equipment: exercise.equipment,
      sourceCategory: exercise.sourceCategory,
    );

const _equipmentLabels = <String, String>{
  'bodyweight': 'Bodyweight',
  'dumbbell': 'Dumbbell',
  'barbell': 'Barbell',
  'cable': 'Cable',
  'machine': 'Machine',
  'lever': 'Lever machine',
  'smith': 'Smith machine',
  'ez-bar': 'EZ bar',
  'kettlebell': 'Kettlebell',
  'band': 'Resistance band',
  'sled': 'Sled',
  'other': 'Other',
};

/// Normalises the dataset's equipment key into a display name. Unknown keys
/// fall back to a readable title-cased form rather than leaking the raw value.
String equipmentLabel(String equipment) {
  final key = equipment.trim().toLowerCase();
  if (key.isEmpty) return '';
  return _equipmentLabels[key] ?? _titleCase(key);
}

const _muscleLabels = <String, String>{
  'abductors': 'Abductors',
  'abs': 'Abs',
  'adductors': 'Adductors',
  'biceps': 'Biceps',
  'calves': 'Calves',
  'cardio': 'Cardio',
  'delts': 'Shoulders',
  'forearms': 'Forearms',
  'glutes': 'Glutes',
  'hamstrings': 'Hamstrings',
  'lats': 'Lats',
  'levator-scapulae': 'Levator scapulae',
  'pectorals': 'Chest',
  'quads': 'Quads',
  'serratus-anterior': 'Serratus anterior',
  'spine': 'Spine',
  'traps': 'Traps',
  'triceps': 'Triceps',
  'upper-back': 'Upper back',
};

/// Normalises a dataset muscle key into a display name.
String muscleLabel(String muscle) {
  final key = muscle.trim().toLowerCase();
  if (key.isEmpty) return '';
  return _muscleLabels[key] ?? _titleCase(key);
}

/// The primary muscle label of a stored exercise.
///
/// [exerciseTargetMuscles] writes the primary muscle first, followed by the
/// secondary ones, so the segment before the first separator is the muscle the
/// exercise is filed under.
String exercisePrimaryMuscle(Exercise exercise) {
  final value = exercise.targetMuscles;
  final cut = value.indexOf(',');
  return (cut < 0 ? value : value.substring(0, cut)).trim();
}

/// The muscle line shown on cards: primary muscle first, then the dataset's
/// secondary muscles, de-duplicated.
String exerciseTargetMuscles({
  required String muscle,
  required List<String> secondaryMuscles,
}) {
  final primary = muscle.trim().toLowerCase();
  final parts = <String>[muscleLabel(muscle)];
  for (final extra in secondaryMuscles) {
    if (extra.trim().toLowerCase() == primary) continue;
    final label = muscleLabel(extra);
    if (label.isEmpty || parts.contains(label)) continue;
    parts.add(label);
  }
  return parts.where((p) => p.isNotEmpty).join(', ');
}

String _titleCase(String value) {
  final words = value
      .replaceAll(RegExp('[-_]'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty);
  return words
      .map(
        (word) =>
            word.length == 1
                ? word.toUpperCase()
                : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
