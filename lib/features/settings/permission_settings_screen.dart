import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/permissions/app_permissions.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashboard_components.dart';

String _groupLabel(PermissionGroup group) => switch (group) {
  PermissionGroup.navigation => 'Navigation',
  PermissionGroup.life => 'Life',
  PermissionGroup.wellness => 'Wellness',
  PermissionGroup.finance => 'Finance tabs',
};

String _featureLabel(BuildContext context, AppFeature feature) {
  final l10n = context.l10n;
  return switch (feature) {
    AppFeature.navHome => l10n.navHome,
    AppFeature.navTasks => l10n.navTasks,
    AppFeature.navFitness => l10n.navFitness,
    AppFeature.navExpenses => l10n.expenses,
    AppFeature.navMore => l10n.navMore,
    AppFeature.lifeSchedule => l10n.navSchedule,
    AppFeature.lifeNotes => l10n.notes,
    AppFeature.lifeAlarms => l10n.alarms,
    AppFeature.lifeHabits => l10n.habits,
    AppFeature.wellnessMusic => l10n.music,
    AppFeature.financeOverview => 'Overview',
    AppFeature.financeDashboard => l10n.dashboard,
    AppFeature.financeAdd => l10n.add,
    AppFeature.financeBudgets => l10n.budgets,
    AppFeature.financeDebts => l10n.debts,
    AppFeature.financeSavingsGoals => l10n.savingsGoals,
  };
}

class PermissionSettingsScreen extends ConsumerWidget {
  const PermissionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(featurePermissionsProvider);
    final controller = ref.read(featurePermissionsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        actions: [
          TextButton(onPressed: controller.reset, child: const Text('Reset')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.rule_folder_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Check a menu or tab to show it, and uncheck it to hide '
                      'it. At least two navigation items and one finance tab '
                      'stay visible.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final group in PermissionGroup.values)
            SettingsGroup(
              title: _groupLabel(group),
              children: [
                for (final feature in AppFeature.inGroup(group))
                  CheckboxListTile(
                    key: ValueKey(feature.key),
                    secondary: Icon(featureIcon(feature)),
                    title: Text(_featureLabel(context, feature)),
                    subtitle:
                        feature == AppFeature.navMore
                            ? const Text(
                              'Always shown so Settings stays reachable',
                            )
                            : null,
                    value: permissions.isVisible(feature),
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged:
                        feature == AppFeature.navMore
                            ? null
                            : (visible) {
                              final next = visible ?? false;
                              if (!next) {
                                final minimum =
                                    group == PermissionGroup.navigation ? 2 : 0;
                                final minimumFinance =
                                    group == PermissionGroup.finance ? 1 : 0;
                                final required =
                                    minimum > minimumFinance
                                        ? minimum
                                        : minimumFinance;
                                if (permissions.visibleCount(group) <=
                                    required) {
                                  final message = switch (group) {
                                    PermissionGroup.navigation =>
                                      'Keep at least two navigation items visible.',
                                    PermissionGroup.finance =>
                                      'Keep at least one finance tab visible.',
                                    _ => 'Keep at least one item visible.',
                                  };
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                  return;
                                }
                              }
                              controller.setVisible(feature, next);
                            },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
