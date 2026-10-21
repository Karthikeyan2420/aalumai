import '../../../core/localization/generated/app_localizations.dart';
import '../domain/yoga.dart';

/// Localized label for a yoga difficulty level.
String yogaDifficultyLabel(AppLocalizations l10n, YogaDifficulty difficulty) =>
    switch (difficulty) {
      YogaDifficulty.beginner => l10n.yogaLevelBeginner,
      YogaDifficulty.intermediate => l10n.yogaLevelIntermediate,
      YogaDifficulty.advanced => l10n.yogaLevelAdvanced,
    };

/// Difficulty for a fitness level, used to preselect the yoga level.
YogaDifficulty yogaDifficultyFromLevelIndex(int index) =>
    YogaDifficulty.values[index.clamp(0, YogaDifficulty.values.length - 1)];
