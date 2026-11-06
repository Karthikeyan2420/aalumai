import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// A group of configurable menus/tabs shown on the Permissions settings page.
enum PermissionGroup { navigation, life, wellness, finance }

/// Every menu or tab whose visibility can be controlled from Settings.
///
/// The [key] is persisted in shared preferences, so it must remain stable even
/// if the enum name changes.
enum AppFeature {
  navHome('nav.home', PermissionGroup.navigation),
  navTasks('nav.tasks', PermissionGroup.navigation),
  navFitness('nav.fitness', PermissionGroup.navigation),
  navExpenses('nav.expenses', PermissionGroup.navigation),
  navMore('nav.more', PermissionGroup.navigation),
  lifeSchedule('life.schedule', PermissionGroup.life),
  lifeNotes('life.notes', PermissionGroup.life),
  lifeAlarms('life.alarms', PermissionGroup.life),
  lifeHabits('life.habits', PermissionGroup.life),
  wellnessMusic('wellness.music', PermissionGroup.wellness),
  financeOverview('finance.overview', PermissionGroup.finance),
  financeDashboard('finance.dashboard', PermissionGroup.finance),
  financeAdd('finance.add', PermissionGroup.finance),
  financeBudgets('finance.budgets', PermissionGroup.finance),
  financeDebts('finance.debts', PermissionGroup.finance),
  financeSavingsGoals('finance.savingsGoals', PermissionGroup.finance);

  const AppFeature(this.key, this.group);

  final String key;
  final PermissionGroup group;

  static AppFeature? fromKey(String key) {
    for (final feature in values) {
      if (feature.key == key) return feature;
    }
    return null;
  }

  static List<AppFeature> inGroup(PermissionGroup group) =>
      values.where((feature) => feature.group == group).toList();
}

class FeaturePermissions {
  const FeaturePermissions(this.hidden);

  final Set<AppFeature> hidden;

  /// More is always visible because it is the only entry point to Settings and
  /// this Permissions page.
  bool isVisible(AppFeature feature) =>
      feature == AppFeature.navMore || !hidden.contains(feature);

  int visibleCount(PermissionGroup group) =>
      AppFeature.inGroup(group).where(isVisible).length;
}

class FeaturePermissionsController extends Notifier<FeaturePermissions> {
  @override
  FeaturePermissions build() {
    final stored = ref.watch(appPreferencesProvider).hiddenFeatures;
    return FeaturePermissions(
      stored.map(AppFeature.fromKey).whereType<AppFeature>().toSet(),
    );
  }

  Future<void> setVisible(AppFeature feature, bool visible) async {
    final hidden = {...state.hidden};
    if (visible) {
      hidden.remove(feature);
    } else {
      hidden.add(feature);
    }
    await ref
        .read(appPreferencesProvider)
        .setHiddenFeatures(hidden.map((feature) => feature.key).toList());
    state = FeaturePermissions(hidden);
  }

  Future<void> reset() async {
    await ref.read(appPreferencesProvider).setHiddenFeatures(const []);
    state = const FeaturePermissions({});
  }
}

final featurePermissionsProvider =
    NotifierProvider<FeaturePermissionsController, FeaturePermissions>(
      FeaturePermissionsController.new,
    );

/// The icon shown beside each feature on the Permissions page.
IconData featureIcon(AppFeature feature) => switch (feature) {
  AppFeature.navHome => Icons.home_outlined,
  AppFeature.navTasks => Icons.checklist_outlined,
  AppFeature.navFitness => Icons.fitness_center_outlined,
  AppFeature.navExpenses => Icons.payments_outlined,
  AppFeature.navMore => Icons.grid_view_outlined,
  AppFeature.lifeSchedule => Icons.calendar_month_outlined,
  AppFeature.lifeNotes => Icons.edit_note,
  AppFeature.lifeAlarms => Icons.alarm,
  AppFeature.lifeHabits => Icons.check_circle_outline,
  AppFeature.wellnessMusic => Icons.library_music_outlined,
  AppFeature.financeOverview => Icons.receipt_long_outlined,
  AppFeature.financeDashboard => Icons.insights_outlined,
  AppFeature.financeAdd => Icons.add_circle_outline,
  AppFeature.financeBudgets => Icons.savings_outlined,
  AppFeature.financeDebts => Icons.account_balance_outlined,
  AppFeature.financeSavingsGoals => Icons.flag_outlined,
};
