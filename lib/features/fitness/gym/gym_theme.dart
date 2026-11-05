import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_theme.dart';

/// Fitness UI tokens derived from the app theme (no forced dark island).
abstract final class GymTheme {
  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surfaceHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Brand teal for fitness (matches dashboard module card).
  static Color get brandTeal => ModuleAccents.fitness;

  /// Legacy const — prefer [AppColors.teal] or [brandTeal].
  static const legacyTeal = AppColors.teal;
}

/// Cover art for daily focus (English filenames).
String dailyFocusCoverAsset(int weekday) => switch (weekday) {
  DateTime.monday => 'assets/images/fitness/cover_arm_shoulder_dumbbell.png',
  DateTime.tuesday => 'assets/images/fitness/cover_back_chest_dumbbell.png',
  DateTime.wednesday => 'assets/images/fitness/cover_back_chest_bodyweight.png',
  DateTime.thursday => 'assets/images/fitness/cover_arm_shoulder_bodyweight.png',
  DateTime.friday => 'assets/images/fitness/cover_leg_dumbbell.png',
  DateTime.saturday => 'assets/images/fitness/cover_abs_bodyweight.png',
  _ => 'assets/images/fitness/cover_cardio_bodyweight.png',
};
