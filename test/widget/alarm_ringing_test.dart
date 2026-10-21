import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/alarms/alarm_audio.dart';
import 'package:aalumai/features/alarms/alarm_challenges.dart';
import 'package:aalumai/features/alarms/alarm_ringing_screen.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Alarm _alarm({
  String label = 'Wake up',
  String challengeSequence = 'math',
  String finalMessage = '',
}) =>
    Alarm(
      id: 1,
      hour: 7,
      minute: 30,
      label: label,
      isEnabled: true,
      repeatDaysMask: 0,
      oneTime: true,
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
      challengeSequence: challengeSequence,
      vibrate: false,
      createdAt: DateTime(2024),
      soundMode: 2,
      message: '',
      finalMessage: finalMessage,
      musicIntervalSec: 10,
      voiceTiming: 1,
      voicePauseSec: 5,
    );

/// Records playback so tests can assert the alarm never stops early.
class _FakeAudioPlayer implements AlarmAudioPlayer {
  bool playing = false;
  int playCount = 0;
  bool lastLoop = false;
  AlarmTone? lastTone;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> play(AlarmTone tone, double volume, {required bool loop}) async {
    playing = true;
    lastLoop = loop;
    lastTone = tone;
    playCount++;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    playing = false;
  }
}

class _FakeScheduler implements AlarmScheduler {
  final List<int> cancelledAlarms = [];
  final List<Alarm> scheduled = [];

  @override
  String? get lastError => null;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}

  @override
  Future<void> scheduleAlarm(Alarm alarm) async => scheduled.add(alarm);

  @override
  Future<void> cancelAlarm(int alarmId) async => cancelledAlarms.add(alarmId);

  @override
  Future<void> cancelAlarmSnooze(int alarmId) async {}

  @override
  Future<void> reconcile(List<Alarm> alarms) async {}
}

void main() {
  late AppDatabase db;
  late AlarmRepository repo;
  late _FakeScheduler scheduler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scheduler = _FakeScheduler();
    repo = AlarmRepository(db, scheduler);
  });

  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
    overrides: [alarmRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  testWidgets('preview shows the label and a close action, never a snooze', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(),
          isPreview: true,
          audio: AlarmAudio(player: _FakeAudioPlayer()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Wake up'), findsOneWidget);
    expect(find.textContaining('Snooze'), findsNothing);
    expect(find.text('Dismiss alarm'), findsNothing);
  });

  testWidgets('ringing shows the challenge with no snooze or dismiss action', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(),
          audio: AlarmAudio(player: _FakeAudioPlayer()),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Challenge 1 of 1'), findsOneWidget);
    expect(find.textContaining('Snooze'), findsNothing);
    expect(find.text('Dismiss alarm'), findsNothing);
  });

  testWidgets('a wrong answer keeps the audio playing and does not advance', (
    tester,
  ) async {
    final player = _FakeAudioPlayer();
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(challengeSequence: 'math,math'),
          audio: AlarmAudio(player: player),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Challenge 1 of 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '999');
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Challenge 1 of 2'), findsOneWidget);
    expect(player.playing, isTrue);
  });

  testWidgets(
    'final motivation stays on screen until Done when finalMessage is set',
    (tester) async {
      final player = _FakeAudioPlayer();
      final ringing = AlarmRingingScreen(
        alarm: _alarm(finalMessage: 'You crushed it!'),
        audio: AlarmAudio(player: player),
        challengeBuilder:
            (kind, random) =>
                const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
      );
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ringing),
                      ),
                  child: const Text('Open ring'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open ring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(player.playing, isFalse);
      expect(find.text('You crushed it!'), findsOneWidget);
      expect(find.text('Final motivation'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets(
    'passing every challenge stops the audio and completes the ring',
    (tester) async {
      final player = _FakeAudioPlayer();
      final answers = ['4', '7'];
      var calls = 0;
      await tester.pumpWidget(
        wrap(
          AlarmRingingScreen(
            alarm: _alarm(challengeSequence: 'math,code'),
            audio: AlarmAudio(player: player),
            challengeBuilder:
                (kind, random) =>
                    AlarmChallengeData(prompt: 'Q', answer: answers[calls++]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Challenge 1 of 2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Between challenges the alarm must keep ringing.
      expect(find.text('Challenge 2 of 2'), findsOneWidget);
      expect(player.playing, isTrue);

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(player.playing, isFalse);
      expect(scheduler.cancelledAlarms, contains(1));
    },
  );

  testWidgets('a code challenge offers an alphanumeric (text) keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(challengeSequence: 'code'),
          audio: AlarmAudio(player: _FakeAudioPlayer()),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: 'Type AB12', answer: 'AB12'),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.text);
    expect(field.textCapitalization, TextCapitalization.characters);
  });

  testWidgets('a math challenge offers a numeric keyboard', (tester) async {
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(challengeSequence: 'math'),
          audio: AlarmAudio(player: _FakeAudioPlayer()),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
  });

  testWidgets('the ring keeps looping while challenges are solved', (
    tester,
  ) async {
    final player = _FakeAudioPlayer();
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(challengeSequence: 'math,math'),
          audio: AlarmAudio(player: player),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
        ),
      ),
    );
    await tester.pump();

    expect(player.lastLoop, isTrue);

    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Moving to the next challenge must not stop or un-loop the alarm.
    expect(find.text('Challenge 2 of 2'), findsOneWidget);
    expect(player.playing, isTrue);
    expect(player.lastLoop, isTrue);
  });

  testWidgets('the answer control stays reachable when the keyboard opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AlarmRingingScreen(
          alarm: _alarm(challengeSequence: 'math'),
          audio: AlarmAudio(player: _FakeAudioPlayer()),
          challengeBuilder:
              (kind, random) =>
                  const AlarmChallengeData(prompt: '2 + 2', answer: '4'),
        ),
      ),
    );
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);

    await tester.pump();
    await tester.ensureVisible(find.text('Done'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
