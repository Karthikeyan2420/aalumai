import 'package:flutter_test/flutter_test.dart';
import 'package:aalumai/features/home/dashboard_sections.dart';

void main() {
  group('DashboardSection.fromKey', () {
    test('resolves known keys', () {
      expect(DashboardSection.fromKey('habits'), DashboardSection.habits);
    });

    test('returns null for unknown keys', () {
      expect(DashboardSection.fromKey('nope'), isNull);
    });
  });

  group('resolveDashboardOrder', () {
    test('uses stored order first then appends the rest', () {
      final order = resolveDashboardOrder(['habits', 'tasks']);
      expect(order.take(2), [DashboardSection.habits, DashboardSection.tasks]);
      expect(order.length, DashboardSection.values.length);
    });

    test('ignores unknown and duplicate keys', () {
      final order = resolveDashboardOrder(['tasks', 'bogus', 'tasks']);
      expect(order.first, DashboardSection.tasks);
      expect(order.where((s) => s == DashboardSection.tasks).length, 1);
      expect(order.length, DashboardSection.values.length);
    });

    test('empty stored list yields the default order', () {
      expect(resolveDashboardOrder(const []), DashboardSection.values);
    });
  });

  group('DashboardConfig.visible', () {
    test('removes hidden sections while preserving order', () {
      const config = DashboardConfig(
        order: DashboardSection.values,
        hidden: {DashboardSection.summary, DashboardSection.tasks},
      );
      expect(config.visible, [
        DashboardSection.quickActions,
        DashboardSection.events,
        DashboardSection.habits,
      ]);
    });
  });
}
