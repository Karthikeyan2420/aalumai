import 'dart:convert';

import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/fitness/data/yoga_api_service.dart';
import 'package:aalumai/features/fitness/data/yoga_catalog.dart';
import 'package:aalumai/features/fitness/data/yoga_repository.dart';
import 'package:aalumai/features/fitness/domain/indian_yoga.dart';
import 'package:aalumai/features/fitness/domain/yoga.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A catalogue that serves the curated poses without touching the asset bundle,
/// so the repository can be tested in isolation.
class _FakeCatalog extends YogaCatalog {
  @override
  Future<List<YogaPose>> load() async => kIndianYogaPoses;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  YogaRepository repoWith({List<YogaPose>? apiPoses}) {
    final client = MockClient((_) async {
      final poses = apiPoses ?? const <YogaPose>[];
      return http.Response(
        jsonEncode([
          for (final pose in poses)
            {
              'id': pose.apiId,
              'english_name': pose.englishName,
              'sanskrit_name_adapted': pose.sanskritName,
              'url_png': pose.imageUrl,
            },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return YogaRepository(
      db,
      catalog: _FakeCatalog(),
      api: YogaApiService(client: client, baseUrl: 'https://example.test/v1'),
    );
  }

  test('loadPoses works offline from the curated catalogue', () async {
    final poses = await repoWith().loadPoses();
    expect(poses.map((p) => p.key), contains('vrikshasana'));
    final tree = poses.firstWhere((p) => p.key == 'vrikshasana');
    expect(tree.hasImage, isTrue, reason: 'curated poses carry verified art');
  });

  test('syncFromApi caches poses and merges them into the catalogue', () async {
    final repo = repoWith(
      apiPoses: const [
        YogaPose(
          key: 'warrior-one',
          englishName: 'Warrior One',
          imageUrl: 'https://cdn.test/warrior-one.png',
          apiId: 44,
          source: YogaPoseSource.api,
        ),
      ],
    );
    final count = await repo.syncFromApi();
    expect(count, 1);
    expect(await db.select(db.yogaPoseCache).get(), hasLength(1));
    expect(await repo.lastSyncAt(), isNotNull);

    final poses = await repo.loadPoses();
    expect(poses.map((p) => p.key), contains('warrior-one'));
    expect(poses.map((p) => p.key), contains('vrikshasana'));
  });

  test('favourites toggle on and off', () async {
    final repo = repoWith();
    expect(await repo.watchFavorites().first, isEmpty);
    await repo.toggleFavorite('tadasana');
    expect(await repo.watchFavorites().first, {'tadasana'});
    await repo.toggleFavorite('tadasana');
    expect(await repo.watchFavorites().first, isEmpty);
  });

  test('a yoga session records its poses and finishes with an outcome',
      () async {
    final repo = repoWith();
    final sessionId = await repo.startSession(
      routineKey: YogaRoutineKind.morning.name,
      title: YogaRoutineKind.morning.label,
      difficulty: YogaDifficulty.beginner.index,
      poseCount: 2,
    );
    await repo.logPose(
      sessionId: sessionId,
      pose: kIndianYogaPoses.first,
      positionIndex: 0,
      plannedSec: 60,
      actualSec: 58,
      outcome: YogaPoseOutcome.completed,
    );
    await repo.finishSession(
      sessionId,
      durationSec: 120,
      completedPoses: 1,
      outcome: YogaSessionOutcome.partial,
    );

    final logs = await repo.watchPoseLogs(sessionId).first;
    expect(logs, hasLength(1));
    expect(logs.single.poseKey, kIndianYogaPoses.first.key);

    final session = await repo.watchSessions().first;
    expect(session, hasLength(1));
    expect(session.single.endedAt, isNotNull);
    expect(session.single.outcome, YogaSessionOutcome.partial.index);
    expect(session.single.durationSec, 120);
  });

  test('deleting a session also removes its pose logs', () async {
    final repo = repoWith();
    final sessionId = await repo.startSession(
      routineKey: YogaRoutineKind.short.name,
      title: 'Short',
      difficulty: 0,
      poseCount: 1,
    );
    await repo.logPose(
      sessionId: sessionId,
      pose: kIndianYogaPoses.first,
      positionIndex: 0,
      plannedSec: 30,
      actualSec: 30,
      outcome: YogaPoseOutcome.completed,
    );
    await repo.deleteSession(sessionId);
    expect(await repo.watchSessions().first, isEmpty);
    expect(await db.select(db.yogaPoseLogs).get(), isEmpty);
  });
}
