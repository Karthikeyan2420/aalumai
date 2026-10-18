import '../../../core/localization/generated/app_localizations.dart';
import 'exercise_collections.dart';

/// Human-readable label for a workout collection.
String workoutCollectionLabel(
  AppLocalizations l10n,
  WorkoutCollection collection,
) {
  return switch (collection) {
    WorkoutCollection.dumbbell => l10n.dumbbellWorkouts,
    WorkoutCollection.bodyweight => l10n.bodyweightWorkouts,
    WorkoutCollection.stretching => l10n.stretchingWorkouts,
    WorkoutCollection.band => l10n.bandWorkouts,
    WorkoutCollection.gym => l10n.gymWorkouts,
  };
}

/// Human-readable label for an exercise category index.
String exerciseCategoryLabel(AppLocalizations l10n, int category) {
  return switch (category.clamp(0, 8)) {
    0 => l10n.armsLabel,
    1 => l10n.shouldersLabel,
    2 => l10n.chestLabel,
    3 => l10n.backLabel,
    4 => l10n.legsLabel,
    5 => l10n.coreLabel,
    6 => l10n.cardioLabel,
    7 => l10n.yogaAndMobility,
    _ => l10n.warmUp,
  };
}

/// Difficulty value used when the source dataset publishes none. The UI must
/// not claim a level it cannot verify, so unknown is stored distinctly from
/// "beginner" and the difficulty chip is simply hidden.
const kUnknownDifficulty = -1;

/// True when [difficulty] came from real metadata rather than the unknown
/// placeholder.
bool hasKnownDifficulty(int difficulty) => difficulty >= 0;

/// Human-readable label for an exercise difficulty. Empty when the difficulty
/// is unknown, so callers can hide the value instead of inventing one.
String exerciseDifficultyLabel(AppLocalizations l10n, int difficulty) {
  return switch (difficulty) {
    0 => l10n.difficultyBeginner,
    1 => l10n.difficultyIntermediate,
    2 => l10n.difficultyAdvanced,
    _ => '',
  };
}

/// Human-readable label for an exercise type (0 strength … 3 balance).
String exerciseTypeLabel(AppLocalizations l10n, int type) {
  return switch (type.clamp(0, 3)) {
    0 => l10n.typeStrength,
    1 => l10n.typeCardio,
    2 => l10n.typeMobility,
    _ => l10n.typeBalance,
  };
}

/// A short prescription summary, e.g. "3 × 12 reps" or "3 × 30 sec".
String exercisePrescription({
  required AppLocalizations l10n,
  required int sets,
  required int reps,
  required int durationSec,
}) {
  if (durationSec > 0) return '$sets × $durationSec ${l10n.secondsShort}';
  return '$sets × $reps ${l10n.reps}';
}
