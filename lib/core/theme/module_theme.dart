import 'package:flutter/material.dart';

/// Colourful per-module accent palette for the 2026 design system.
///
/// Blue and teal are the primary brand accents; each feature module gets a
/// distinct, friendly hue so cards, icons and progress rings are instantly
/// recognisable while staying coherent.
class ModuleAccents {
  const ModuleAccents._();

  // Brand primaries.
  static const blue = Color(0xFF3B82F6);
  static const teal = Color(0xFF14B8A6);

  // Module accents.
  static const alarm = Color(0xFFF87171); // coral / red
  static const music = Color(0xFF8B5CF6); // purple
  static const fitness = Color(0xFF22C55E); // green
  static const habits = Color(0xFF10B981); // emerald
  static const tasks = Color(0xFF3B82F6); // blue
  static const schedule = Color(0xFF0EA5E9); // sky
  static const notes = Color(0xFF14B8A6); // teal
  static const expenses = Color(0xFFF97316); // orange
  static const savings = Color(0xFFEAB308); // amber
  static const meals = Color(0xFFEC4899); // pink
  static const learning = Color(0xFF06B6D4); // cyan
  static const water = Color(0xFF38BDF8); // light blue
  static const settings = Color(0xFF64748B); // slate
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
  savings,
  meals,
  learning;

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
    DashboardModule.meals => ModuleAccents.meals,
    DashboardModule.learning => ModuleAccents.learning,
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
    DashboardModule.meals => Icons.restaurant,
    DashboardModule.learning => Icons.school,
  };
}
