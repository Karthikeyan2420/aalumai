import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/l10n_extension.dart';
import '../permissions/app_permissions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final permissions = ref.watch(featurePermissionsProvider);

    final allEntries = <_NavEntry>[
      _NavEntry(
        AppFeature.navHome,
        0,
        Icons.home_outlined,
        Icons.home,
        l10n.navHome,
      ),
      _NavEntry(
        AppFeature.navTasks,
        1,
        Icons.checklist_outlined,
        Icons.checklist,
        l10n.navTasks,
      ),
      _NavEntry(
        AppFeature.navFitness,
        2,
        Icons.fitness_center_outlined,
        Icons.fitness_center,
        l10n.navFitness,
      ),
      _NavEntry(
        AppFeature.navExpenses,
        3,
        Icons.payments_outlined,
        Icons.payments,
        l10n.expenses,
      ),
      _NavEntry(
        AppFeature.navMore,
        4,
        Icons.grid_view_outlined,
        Icons.grid_view,
        l10n.navMore,
      ),
    ];
    final visible =
        allEntries
            .where((entry) => permissions.isVisible(entry.feature))
            .toList();
    // NavigationBar needs at least two destinations. The Permissions page
    // enforces this too; this guard also protects against stale preferences.
    final entries = visible.length >= 2 ? visible : allEntries;

    final currentBranch = navigationShell.currentIndex;
    final selectedDisplay = entries.indexWhere(
      (entry) => entry.branchIndex == currentBranch,
    );

    // If the currently open branch was hidden, move to the first visible one so
    // the highlighted destination always matches the displayed module.
    if (selectedDisplay < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          navigationShell.goBranch(entries.first.branchIndex);
        }
      });
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Material(
        color: scheme.surface,
        elevation: 0,
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedDisplay < 0 ? 0 : selectedDisplay,
            onDestinationSelected:
                (index) => navigationShell.goBranch(
                  entries[index].branchIndex,
                  initialLocation:
                      entries[index].branchIndex ==
                      navigationShell.currentIndex,
                ),
            destinations: [
              for (final entry in entries)
                NavigationDestination(
                  icon: Icon(entry.icon),
                  selectedIcon: Icon(entry.selectedIcon),
                  label: entry.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry(
    this.feature,
    this.branchIndex,
    this.icon,
    this.selectedIcon,
    this.label,
  );

  final AppFeature feature;
  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
