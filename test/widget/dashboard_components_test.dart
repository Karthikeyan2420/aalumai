import 'package:aalumai/core/theme/module_theme.dart';
import 'package:aalumai/core/widgets/dashboard_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(360, 640)}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: size.width, height: size.height, child: child),
    ),
  ),
);

void main() {
  group('ModuleAccents', () {
    test('every dashboard module has a distinct accent and an icon', () {
      final accents = <Color>{};
      final icons = <IconData>{};
      for (final module in DashboardModule.values) {
        accents.add(module.accent);
        icons.add(module.icon);
      }
      expect(accents.length, DashboardModule.values.length);
      expect(icons.length, DashboardModule.values.length);
    });

    test('requested brand mapping is honoured', () {
      expect(DashboardModule.fitness.accent, ModuleAccents.fitness);
      expect(DashboardModule.habits.accent, ModuleAccents.habits);
      expect(DashboardModule.alarm.accent, ModuleAccents.alarm);
      expect(DashboardModule.music.accent, ModuleAccents.music);
      expect(DashboardModule.expenses.accent, ModuleAccents.expenses);
      expect(DashboardModule.schedule.accent, ModuleAccents.schedule);
    });
  });

  group('ModuleCard', () {
    testWidgets('renders title, value and subtitle and fires onTap', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          ModuleCard(
            module: DashboardModule.alarm,
            title: 'Alarms',
            value: '07:00',
            subtitle: 'Next alarm',
            onTap: () => tapped++,
          ),
        ),
      );

      expect(find.text('Alarms'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('Next alarm'), findsOneWidget);

      await tester.tap(find.byType(ModuleCard));
      expect(tapped, 1);
    });

    testWidgets('does not overflow on a narrow phone width', (tester) async {
      await tester.pumpWidget(
        _host(
          ModuleCard(
            module: DashboardModule.savings,
            title: 'Savings goals',
            value: '₹1,23,456',
            subtitle: 'Total balance',
          ),
          size: const Size(160, 150),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ProgressRow', () {
    testWidgets('clamps overflow progress values', (tester) async {
      await tester.pumpWidget(
        _host(
          const ProgressRow(
            icon: Icons.check,
            label: 'Habits',
            valueLabel: '3/2',
            progress: 4.5,
            accent: ModuleAccents.habits,
          ),
        ),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('ScenicBackground', () {
    testWidgets('falls back cleanly when the asset fails to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ScenicBackground(
            asset: 'assets/does_not_exist.png',
            child: Text('content'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
    });
  });
}
