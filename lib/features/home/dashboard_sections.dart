import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';

/// The reorderable, hideable sections of the Home dashboard.
enum DashboardSection {
  quickActions,
  summary,
  events,
  tasks,
  habits;

  static DashboardSection? fromKey(String key) =>
      DashboardSection.values.where((s) => s.name == key).firstOrNull;
}

class DashboardConfig {
  const DashboardConfig({required this.order, required this.hidden});

  final List<DashboardSection> order;
  final Set<DashboardSection> hidden;

  /// Sections to render, in order, with hidden ones removed.
  List<DashboardSection> get visible =>
      order.where((s) => !hidden.contains(s)).toList();
}

/// Merges a persisted key list with the known sections, keeping known keys in
/// stored order first and appending any sections added in later app versions.
List<DashboardSection> resolveDashboardOrder(List<String> storedKeys) {
  final order = <DashboardSection>[];
  for (final key in storedKeys) {
    final section = DashboardSection.fromKey(key);
    if (section != null && !order.contains(section)) order.add(section);
  }
  for (final section in DashboardSection.values) {
    if (!order.contains(section)) order.add(section);
  }
  return order;
}

class DashboardConfigController extends Notifier<DashboardConfig> {
  @override
  DashboardConfig build() {
    final prefs = ref.watch(appPreferencesProvider);
    return DashboardConfig(
      order: resolveDashboardOrder(prefs.dashboardOrder),
      hidden:
          prefs.dashboardHidden
              .map(DashboardSection.fromKey)
              .whereType<DashboardSection>()
              .toSet(),
    );
  }

  Future<void> setOrder(List<DashboardSection> order) async {
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setDashboardOrder(order.map((s) => s.name).toList());
    state = DashboardConfig(order: order, hidden: state.hidden);
  }

  Future<void> setVisible(DashboardSection section, bool visible) async {
    final prefs = ref.read(appPreferencesProvider);
    final hidden = {...state.hidden};
    if (visible) {
      hidden.remove(section);
    } else {
      hidden.add(section);
    }
    await prefs.setDashboardHidden(hidden.map((s) => s.name).toList());
    state = DashboardConfig(order: state.order, hidden: hidden);
  }
}

final dashboardConfigProvider =
    NotifierProvider<DashboardConfigController, DashboardConfig>(
      DashboardConfigController.new,
    );
