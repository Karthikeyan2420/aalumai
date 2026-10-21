import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/core/utils/alarm_time.dart';
import 'package:aalumai/core/widgets/common.dart';
import 'package:aalumai/features/alarms/alarm_editor_screen.dart';
import 'package:aalumai/features/alarms/alarms_screen.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements AlarmScheduler {
  @override
  String? get lastError => null;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}

  @override
  Future<void> scheduleAlarm(Alarm alarm) async {}

  @override
  Future<void> cancelAlarm(int alarmId) async {}

  @override
  Future<void> cancelAlarmSnooze(int alarmId) async {}

  @override
  Future<void> reconcile(List<Alarm> alarms) async {}
}

/// Bounded pumping: `pumpAndSettle` waits forever while a never-ending frame
/// schedule is pending (e.g. a busy loading spinner), so advance a fixed
/// number of frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Alarm _alarm({
  int id = 1,
  int hour = 7,
  int minute = 30,
  String label = 'Wake up',
  bool isEnabled = true,
  bool oneTime = false,
  int repeatDaysMask = 0,
}) => Alarm(
  id: id,
  hour: hour,
  minute: minute,
  label: label,
  isEnabled: isEnabled,
  repeatDaysMask: repeatDaysMask,
  oneTime: oneTime,
  soundUri: '',
  soundStartMs: 0,
  soundEndMs: 0,
  volume: 100,
  gradualVolume: false,
  gradientDurationSec: 30,
  snoozeMinutes: 5,
  maxSnoozes: 0,
  snoozeCount: 0,
  challengeType: 1,
  challengeParam: '',
  challengeSequence: 'math',
  vibrate: false,
  createdAt: DateTime(2024),
  soundMode: 2,
  message: '',
  finalMessage: '',
  musicIntervalSec: 10,
  voiceTiming: 1,
  voicePauseSec: 5,
);

/// Renders [AlarmsScreen] against an explicit list of alarms.
///
/// The alarm providers are overridden with plain streams/values so the test
/// never subscribes to a Drift query stream: those schedule timers on
/// cancellation that the widget-test framework treats as a failure. Database
/// behaviour is covered by `test/unit/alarm_repository_test.dart`.
Widget wrap(List<Alarm> alarms) => ProviderScope(
  overrides: [
    alarmsProvider.overrideWith((ref) => Stream<List<Alarm>>.value(alarms)),
    upcomingAlarmsProvider.overrideWith((ref) async => const <UpcomingAlarm>[]),
    alarmRepositoryProvider.overrideWithValue(
      AlarmRepository(
        AppDatabase.forTesting(NativeDatabase.memory()),
        _FakeScheduler(),
      ),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AlarmsScreen(),
  ),
);

void main() {
  // Each test builds its own in-memory database, so drift's "database opened
  // twice" heuristic would otherwise warn (the executors are independent).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('shows an empty state when there are no alarms', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('renders an enabled alarm card with its controls', (
    tester,
  ) async {
    final alarm = _alarm(repeatDaysMask: 0x1F);
    await tester.pumpWidget(wrap([alarm]));
    await pumpFrames(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(AlarmsScreen)));

    expect(find.byType(EmptyState), findsNothing);
    expect(
      find.text(AlarmTime.format(alarm.hour, alarm.minute)),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.previewAlarm), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    // Next ring is shown for an enabled alarm.
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // Mon–Fri chips are lit for the 0x1F mask.
    expect(find.text('M'), findsOneWidget);
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets('a disabled alarm hides its next ring', (tester) async {
    final alarm = _alarm(repeatDaysMask: 0x1F, isEnabled: false);
    await tester.pumpWidget(wrap([alarm]));
    await pumpFrames(tester);

    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('a one-time alarm hides the day chips', (tester) async {
    final alarm = _alarm(oneTime: true, repeatDaysMask: 0);
    await tester.pumpWidget(wrap([alarm]));
    await pumpFrames(tester);

    expect(find.text('M'), findsNothing);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
  });

  testWidgets('tapping an alarm card opens the editor', (tester) async {
    await tester.pumpWidget(wrap([_alarm(repeatDaysMask: 0x1F)]));
    await pumpFrames(tester);

    final card = find.ancestor(
      of: find.byType(Switch),
      matching: find.byType(InkWell),
    );
    expect(card, findsOneWidget);

    await tester.tap(card);
    await pumpFrames(tester);

    expect(find.byType(AlarmEditorScreen), findsOneWidget);
  });
}
