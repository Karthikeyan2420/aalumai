import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
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
    final config = ref.watch(dashboardConfigProvider);
    final controller = ref.read(dashboardConfigProvider.notifier);
    final order = config.order;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customizeDashboard)),
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onReorder: (oldIndex, newIndex) {
          final next = [...order];
          if (newIndex > oldIndex) newIndex -= 1;
          final item = next.removeAt(oldIndex);
          next.insert(newIndex, item);
          controller.setOrder(next);
        },
        children: [
          for (final section in order)
            SwitchListTile(
              key: ValueKey(section.name),
              value: !config.hidden.contains(section),
              title: Text(_sectionLabel(context, section)),
              secondary: const Icon(Icons.drag_handle),
              onChanged: (visible) => controller.setVisible(section, visible),
            ),
        ],
      ),
    );
  }
}
