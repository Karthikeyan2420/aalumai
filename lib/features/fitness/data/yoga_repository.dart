import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../domain/indian_yoga.dart';
import '../domain/yoga.dart';
import 'yoga_api_service.dart';
import 'yoga_catalog.dart';

/// Bridges the yoga domain with the database and the yoga API.
///
/// The curated Indian catalogue plus the bundled API snapshot are always
/// available offline. When the network allows, [syncFromApi] refreshes the
/// cached API poses; the catalogue then merges the cache on top of the bundled
/// content so the newest images/metadata win without losing offline support.
class YogaRepository {
  YogaRepository(
    this._db, {
    YogaCatalog? catalog,
    YogaApiService? api,
  }) : _catalog = catalog ?? YogaCatalog(),
       _api = api ?? YogaApiService();

  final AppDatabase _db;
  final YogaCatalog _catalog;
  final YogaApiService _api;

  // ---- Catalogue ----------------------------------------------------------

  /// The full yoga catalogue: curated poses merged with bundled and cached API
  /// metadata. Never throws: a missing asset or cache yields the curated list.
  Future<List<YogaPose>> loadPoses() async {
    final base = await _catalog.load();
    final cached = await _cachedApiPoses();
    if (cached.isEmpty) return base;
    return mergeYogaPoses(curated: base, apiPoses: cached);
  }

  Future<List<YogaPose>> _cachedApiPoses() async {
    final rows = await _db.select(_db.yogaPoseCache).get();
    return [
      for (final row in rows)
        YogaPose(
          key: row.poseKey,
          englishName: row.englishName,
          sanskritName: row.sanskritName,
          translation: row.translation,
          description: row.description,
          benefits: row.benefits,
          imageUrl: row.imageUrl,
          category: row.category,
          difficulty: YogaDifficulty.values[
              row.difficulty.clamp(0, YogaDifficulty.values.length - 1)],
          apiId: row.apiId,
          source: YogaPoseSource.api,
        ),
    ];
  }

  /// Downloads poses from the yoga API and replaces the cache. Returns the
  /// number of poses stored. Throws [YogaApiException] when the API is
  /// unreachable, so the caller can surface a gentle offline message.
  Future<int> syncFromApi() async {
    final poses = await _api.fetchPoses();
    if (poses.isEmpty) return 0;
    await _db.transaction(() async {
      await _db.delete(_db.yogaPoseCache).go();
      await _db.batch((batch) {
        for (final pose in poses) {
          batch.insert(
            _db.yogaPoseCache,
            YogaPoseCacheCompanion.insert(
              poseKey: pose.key,
              englishName: pose.englishName,
              sanskritName: Value(pose.sanskritName),
              translation: Value(pose.translation),
              description: Value(pose.description),
              benefits: Value(pose.benefits),
              imageUrl: Value(pose.imageUrl),
              category: Value(pose.category),
              difficulty: Value(pose.difficulty.index),
              apiId: Value(pose.apiId),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });
    });
    return poses.length;
  }

  Future<DateTime?> lastSyncAt() async {
    final row =
        await (_db.select(_db.yogaPoseCache)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.updatedAt;
  }

  // ---- Sessions -----------------------------------------------------------

  Future<int> startSession({
    required String routineKey,
    required String title,
    required int difficulty,
    required int poseCount,
  }) {
    return _db
        .into(_db.yogaSessions)
        .insert(
          YogaSessionsCompanion.insert(
            routineKey: Value(routineKey),
            title: Value(title),
            difficulty: Value(difficulty),
            poseCount: Value(poseCount),
            startedAt: DateTime.now(),
          ),
        );
  }

  Future<void> updateSessionProgress(int sessionId, int stepIndex) {
    return (_db.update(_db.yogaSessions)..where(
      (t) => t.id.equals(sessionId),
    )).write(YogaSessionsCompanion(stepIndex: Value(stepIndex)));
  }

  Future<void> finishSession(
    int sessionId, {
    required int durationSec,
    required int completedPoses,
    required YogaSessionOutcome outcome,
    String notes = '',
  }) {
    return (_db.update(_db.yogaSessions)..where(
      (t) => t.id.equals(sessionId),
    )).write(
      YogaSessionsCompanion(
        endedAt: Value(DateTime.now()),
        durationSec: Value(durationSec),
        completedPoses: Value(completedPoses),
        outcome: Value(outcome.index),
        notes: Value(notes),
      ),
    );
  }

  Future<void> logPose({
    required int sessionId,
    required YogaPose pose,
    required int positionIndex,
    required int plannedSec,
    required int actualSec,
    required YogaPoseOutcome outcome,
  }) {
    return _db
        .into(_db.yogaPoseLogs)
        .insert(
          YogaPoseLogsCompanion.insert(
            sessionId: sessionId,
            poseKey: pose.key,
            englishName: Value(pose.englishName),
            positionIndex: Value(positionIndex),
            plannedSec: Value(plannedSec),
            actualSec: Value(actualSec),
            outcome: Value(outcome.index),
          ),
        );
  }

  Stream<List<YogaSession>> watchSessions({int limit = 100}) =>
      (_db.select(_db.yogaSessions)
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .watch();

  Future<YogaSession?> latestInProgressSession() => (_db.select(_db.yogaSessions)
        ..where((t) => t.endedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
        ])
        ..limit(1))
      .getSingleOrNull();

  Stream<List<YogaPoseLog>> watchPoseLogs(int sessionId) =>
      (_db.select(_db.yogaPoseLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.positionIndex)]))
          .watch();

  Future<void> deleteSession(int sessionId) =>
      (_db.delete(_db.yogaSessions)..where((t) => t.id.equals(sessionId))).go();

  /// The most recent completed/abandoned session per routine kind, used to show
  /// "last practised" on the routine cards.
  Stream<List<YogaSession>> watchRecentSessions() =>
      watchSessions(limit: 30);

  // ---- Favourites ---------------------------------------------------------

  Stream<Set<String>> watchFavorites() => _db
      .select(_db.yogaFavorites)
      .watch()
      .map((rows) => rows.map((r) => r.poseKey).toSet());

  Future<void> toggleFavorite(String poseKey) async {
    final existing =
        await (_db.select(_db.yogaFavorites)
              ..where((t) => t.poseKey.equals(poseKey))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.delete(_db.yogaFavorites)
            ..where((t) => t.poseKey.equals(poseKey)))
          .go();
    } else {
      await _db
          .into(_db.yogaFavorites)
          .insert(YogaFavoritesCompanion.insert(poseKey: poseKey));
    }
  }
}

final yogaCatalogProvider = Provider<YogaCatalog>((ref) => YogaCatalog());

final yogaApiServiceProvider = Provider<YogaApiService>((ref) {
  final service = YogaApiService();
  ref.onDispose(service.dispose);
  return service;
});

final yogaRepositoryProvider = Provider<YogaRepository>(
  (ref) => YogaRepository(
    ref.watch(appDatabaseProvider),
    catalog: ref.watch(yogaCatalogProvider),
    api: ref.watch(yogaApiServiceProvider),
  ),
);

/// The merged yoga catalogue. Re-runs whenever [dataRevisionProvider] is bumped
/// (for example after a successful API sync).
final yogaPosesProvider = FutureProvider<List<YogaPose>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(yogaRepositoryProvider).loadPoses();
});

/// Completed/abandoned yoga sessions, newest first.
final yogaSessionsProvider = StreamProvider<List<YogaSession>>(
  (ref) => ref.watch(yogaRepositoryProvider).watchSessions(),
);

final yogaPoseLogsProvider = StreamProvider.family<List<YogaPoseLog>, int>(
  (ref, sessionId) => ref.watch(yogaRepositoryProvider).watchPoseLogs(sessionId),
);

final yogaFavoritesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(yogaRepositoryProvider).watchFavorites(),
);

/// Wraps an API sync so the UI can await progress and refresh the catalogue.
final yogaApiSyncProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final count = await ref.read(yogaRepositoryProvider).syncFromApi();
    ref.read(dataRevisionProvider.notifier).bump();
    return count;
  };
});
