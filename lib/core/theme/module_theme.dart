import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Restrained module accent family — recognisable hues in 36px icon wells only.
class ModuleAccents {
  const ModuleAccents._();

  static const blue = Color(0xFF3B82F6);
  static const teal = AppColors.teal;
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFEAB308);
  static const coral = Color(0xFFF87171);
  static const violet = Color(0xFF8B5CF6);
  static const slate = Color(0xFF64748B);

  static const alarm = coral;
  static const music = violet;
  static const fitness = teal;
  static const habits = emerald;
  static const tasks = blue;
  static const schedule = blue;
  static const notes = teal;
  static const expenses = Color(0xFFF97316);
  static const savings = amber;
  static const water = Color(0xFF60A5FA);
  static const settings = slate;
}

/// A soft, tinted background derived from an accent colour — used behind
/// icons and inside cards so full-saturation colour never dominates.
///
/// The tint is blended onto the *active theme's* surface so it stays legible in
/// both light and dark mode instead of always washing toward white.
Color softTint(BuildContext context, Color accent, [double alpha = 0.12]) {
  final scheme = Theme.of(context).colorScheme;
  final base =
      scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : Colors.white;
  return Color.alphaBlend(accent.withValues(alpha: alpha), base);
}

/// The palette entry for a dashboard module.
enum DashboardModule {
  alarm,
  music,
  fitness,
  habits,
  tasks,
  schedule,
  notes,
  expenses,
  savings;

  Color get accent => switch (this) {
    DashboardModule.alarm => ModuleAccents.alarm,
    DashboardModule.music => ModuleAccents.music,
    DashboardModule.fitness => ModuleAccents.fitness,
    DashboardModule.habits => ModuleAccents.habits,
    DashboardModule.tasks => ModuleAccents.tasks,
    DashboardModule.schedule => ModuleAccents.schedule,
    DashboardModule.notes => ModuleAccents.notes,
    DashboardModule.expenses => ModuleAccents.expenses,
    DashboardModule.savings => ModuleAccents.savings,
  };

  IconData get icon => switch (this) {
    DashboardModule.alarm => Icons.alarm,
    DashboardModule.music => Icons.music_note,
    DashboardModule.fitness => Icons.fitness_center,
    DashboardModule.habits => Icons.check_circle_outline,
    DashboardModule.tasks => Icons.checklist,
    DashboardModule.schedule => Icons.calendar_month,
    DashboardModule.notes => Icons.edit_note,
    DashboardModule.expenses => Icons.account_balance_wallet,
    DashboardModule.savings => Icons.savings,
  };
}
