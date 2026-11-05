import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/daily_session_builder.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FitnessRepository repo;
  late List<Exercise> exercises;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
    await repo.seedExercises();
    exercises = await db.select(db.exercises).get();
  });

  tearDown(() => db.close());

  PlannedDay build({
    required DateTime date,
    required int sessionMinutes,
  }) {
    return DailySessionBuilder.buildDay(
          date: date,
          preferences: WorkoutPreferences(
            sessionMinutes: sessionMinutes,
            onboardingDone: true,
          ),
          exercises: exercises,
        ) ??
        (throw StateError('buildDay returned null'));
  }

  test('stretch block is first every day', () {
    final monday = DateTime(2026, 6, 1); // Monday
    final day = build(date: monday, sessionMinutes: 60);
    expect(day.items.length, greaterThan(6));
    final stretchCount = day.items.takeWhile((i) => i.sets == 1).length;
    expect(stretchCount, greaterThanOrEqualTo(6));
    expect(day.items[stretchCount].sets, greaterThan(1));
  });

  test('Monday focus is shoulders after stretch', () {
    final monday = DateTime(2026, 6, 1);
    final day = build(date: monday, sessionMinutes: 60);
    expect(DailySessionBuilder.focusLabel(monday.weekday), 'Shoulders');
    expect(day.title, 'Shoulders');
    final byId = {for (final e in exercises) e.id: e};
    final mainItems =
        day.items.where((i) => i.sets > 1).map((i) => byId[i.exerciseId]!);
    expect(mainItems, isNotEmpty);
    expect(mainItems.every((e) => e.category == 1), isTrue);
  });

  test('120 min session is longer than 30 min', () {
    final wednesday = DateTime(2026, 6, 3);
    final short = build(date: wednesday, sessionMinutes: 30);
    final long = build(date: wednesday, sessionMinutes: 120);
    final shortSec = WeekPlanGenerator.estimateDurationSec(short.items);
    final longSec = WeekPlanGenerator.estimateDurationSec(long.items);
    expect(longSec, greaterThan(shortSec));
    expect(shortSec, inInclusiveRange(27 * 60, 33 * 60));
    expect(longSec, inInclusiveRange(108 * 60, 132 * 60));
  });

  test('snapSessionMinutes maps to 30/60/90/120', () {
    expect(DailySessionBuilder.snapSessionMinutes(30), 30);
    expect(DailySessionBuilder.snapSessionMinutes(50), 60);
    expect(DailySessionBuilder.snapSessionMinutes(90), 90);
    expect(DailySessionBuilder.snapSessionMinutes(150), 120);
  });
}
