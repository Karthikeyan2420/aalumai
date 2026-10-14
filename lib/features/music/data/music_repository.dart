import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';

const _audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.ogg',
  '.opus',
  '.flac',
};

class MusicRepository {
  MusicRepository(this._db);

  final AppDatabase _db;

  Stream<List<MusicTrack>> watchTracks() =>
      (_db.select(_db.musicTracks)
        ..orderBy([(t) => OrderingTerm(expression: t.title)])).watch();

  Stream<List<MusicTrack>> watchFavorites() =>
      (_db.select(_db.musicTracks)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.title)]))
          .watch();

  Stream<List<MusicTrack>> watchRecent() =>
      (_db.select(_db.musicTracks)
            ..where((t) => t.lastPlayedAt.isNotNull())
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(50))
          .watch();

  Future<int> trackCount() async {
    final rows = await _db.select(_db.musicTracks).get();
    return rows.length;
  }

  Stream<List<MusicFolder>> watchFolders() =>
      (_db.select(_db.musicFolders)
        ..orderBy([(t) => OrderingTerm(expression: t.addedAt)])).watch();

  /// Adds a folder and scans it for supported audio files.
  /// Scanning is bounded to the selected folder and only inserts new files.
  Future<int> addFolder(String path, {int maxFiles = 2000}) async {
    await _db
        .into(_db.musicFolders)
        .insert(MusicFoldersCompanion.insert(path: path));
    return scanFolder(path, maxFiles: maxFiles);
  }

  Future<int> scanFolder(String path, {int maxFiles = 2000}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    final existing =
        (await _db.select(_db.musicTracks).get()).map((t) => t.uri).toSet();
    var added = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_audioExtensions.contains(ext)) continue;
      if (existing.contains(entity.path)) continue;
      final base = p.basenameWithoutExtension(entity.path);
      await _db
          .into(_db.musicTracks)
          .insert(
            MusicTracksCompanion.insert(
              uri: entity.path,
              title: Value(base),
              folderPath: Value(dir.path),
            ),
          );
      added++;
      if (added >= maxFiles) break;
    }
    return added;
  }

  Future<void> removeFolder(int id) async {
    final folder =
        await (_db.select(_db.musicFolders)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (folder == null) return;
    await (_db.delete(_db.musicTracks)
      ..where((t) => t.folderPath.equals(folder.path))).go();
    await (_db.delete(_db.musicFolders)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleFavorite(MusicTrack track) => (_db.update(_db.musicTracks)
    ..where(
      (t) => t.id.equals(track.id),
    )).write(MusicTracksCompanion(isFavorite: Value(!track.isFavorite)));

  /// Records a play. Position writes are throttled by the player, not here.
  Future<void> markPlayed(int trackId) async {
    final track =
        await (_db.select(_db.musicTracks)
          ..where((t) => t.id.equals(trackId))).getSingleOrNull();
    if (track == null) return;
    await (_db.update(_db.musicTracks)
      ..where((t) => t.id.equals(trackId))).write(
      MusicTracksCompanion(
        lastPlayedAt: Value(DateTime.now()),
        playCount: Value(track.playCount + 1),
      ),
    );
  }

  /// Counts tracks whose files can no longer be found. Rows are intentionally
  /// kept so playlists that reference them remain intact; playback surfaces a
  /// clear error for unavailable tracks.
  Future<int> countMissingFiles() async {
    final tracks = await _db.select(_db.musicTracks).get();
    var missing = 0;
    for (final t in tracks) {
      if (!File(t.uri).existsSync()) missing++;
    }
    return missing;
  }

  // ---- Playlists ----------------------------------------------------------

  Stream<List<Playlist>> watchPlaylists() =>
      (_db.select(_db.playlists)
        ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<int> createPlaylist(String name) =>
      _db.into(_db.playlists).insert(PlaylistsCompanion.insert(name: name));

  Future<void> deletePlaylist(int id) =>
      (_db.delete(_db.playlists)..where((t) => t.id.equals(id))).go();

  Future<void> addToPlaylist(int playlistId, int trackId) => _db
      .into(_db.playlistItems)
      .insert(
        PlaylistItemsCompanion.insert(playlistId: playlistId, trackId: trackId),
      );

  Stream<List<MusicTrack>> watchPlaylistTracks(int playlistId) {
    final query =
        _db.select(_db.musicTracks).join([
            innerJoin(
              _db.playlistItems,
              _db.playlistItems.trackId.equalsExp(_db.musicTracks.id),
            ),
          ])
          ..where(_db.playlistItems.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(_db.playlistItems.orderIndex)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.musicTracks)).toList(),
    );
  }

  // ---- Playback state -----------------------------------------------------

  Future<MusicStateData?> loadState() =>
      (_db.select(_db.musicState)
        ..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> saveState({
    int? lastTrackId,
    int positionMs = 0,
    bool? shuffle,
    int? repeatMode,
  }) async {
    final existing = await loadState();
    if (existing == null) {
      await _db
          .into(_db.musicState)
          .insert(
            MusicStateCompanion.insert(
              id: const Value(1),
              lastTrackId: Value(lastTrackId),
              positionMs: Value(positionMs),
              shuffle: Value(shuffle ?? false),
              repeatMode: Value(repeatMode ?? 0),
            ),
          );
    } else {
      await (_db.update(_db.musicState)..where((t) => t.id.equals(1))).write(
        MusicStateCompanion(
          lastTrackId:
              lastTrackId == null ? const Value.absent() : Value(lastTrackId),
          positionMs: Value(positionMs),
          shuffle: shuffle == null ? const Value.absent() : Value(shuffle),
          repeatMode:
              repeatMode == null ? const Value.absent() : Value(repeatMode),
        ),
      );
    }
  }
}

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(ref.watch(appDatabaseProvider)),
);

final musicTracksProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchTracks(),
);

final musicFavoritesProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchFavorites(),
);

final musicRecentProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchRecent(),
);

final musicFoldersProvider = StreamProvider<List<MusicFolder>>(
  (ref) => ref.watch(musicRepositoryProvider).watchFolders(),
);

final playlistsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(musicRepositoryProvider).watchPlaylists(),
);
