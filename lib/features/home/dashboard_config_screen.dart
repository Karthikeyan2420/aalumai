import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_sections.dart';

String _sectionLabel(BuildContext context, DashboardSection section) {
  final l10n = context.l10n;
  return switch (section) {
    DashboardSection.quickActions => l10n.quickActions,
    DashboardSection.summary => l10n.today,
    DashboardSection.events => l10n.todaysEvents,
    DashboardSection.tasks => l10n.navTasks,
    DashboardSection.habits => l10n.habits,
  };
}

class DashboardConfigScreen extends ConsumerWidget {
  const DashboardConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final config = ref.watch(dashboardConfigProvider);
    final controller = ref.read(dashboardConfigProvider.notifier);
    final order = config.order;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customizeDashboard)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              8,
              AppSpacing.screen,
              12,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Drag to reorder · toggle to show or hide',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                32,
              ),
              onReorder: (oldIndex, newIndex) {
                final next = [...order];
                if (newIndex > oldIndex) newIndex -= 1;
                final item = next.removeAt(oldIndex);
                next.insert(newIndex, item);
                controller.setOrder(next);
              },
              children: [
                for (final section in order)
                  Card(
                    key: ValueKey(section.name),
                    margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                    child: SwitchListTile(
                      value: !config.hidden.contains(section),
                      title: Text(_sectionLabel(context, section)),
                      secondary: const Icon(Icons.drag_handle),
                      onChanged:
                          (visible) => controller.setVisible(section, visible),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
