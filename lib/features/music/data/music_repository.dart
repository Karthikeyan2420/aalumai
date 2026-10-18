import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import 'media_scanner.dart';

/// Result of a library scan: how many rows were created, refreshed and flagged
/// as no-longer-available.
class ScanResult {
  const ScanResult({
    this.added = 0,
    this.updated = 0,
    this.missingMarked = 0,
    this.total = 0,
    this.permissionDenied = false,
  });

  final int added;
  final int updated;
  final int missingMarked;
  final int total;
  final bool permissionDenied;

  bool get isEmpty => added == 0 && updated == 0;

  ScanResult merge(ScanResult other) => ScanResult(
    added: added + other.added,
    updated: updated + other.updated,
    missingMarked: missingMarked + other.missingMarked,
    total: total + other.total,
    permissionDenied: permissionDenied || other.permissionDenied,
  );
}

/// A snapshot of the local music library used by the statistics screen.
class LibraryStats {
  const LibraryStats({
    required this.songCount,
    required this.totalDurationMs,
    required this.totalSizeBytes,
    required this.artistCount,
    required this.albumCount,
    required this.genreCount,
    required this.folderCount,
    required this.favoriteCount,
    required this.missingCount,
    required this.recentlyAdded,
    required this.mostPlayed,
  });

  final int songCount;
  final int totalDurationMs;
  final int totalSizeBytes;
  final int artistCount;
  final int albumCount;
  final int genreCount;
  final int folderCount;
  final int favoriteCount;
  final int missingCount;
  final List<MusicTrack> recentlyAdded;
  final List<MusicTrack> mostPlayed;

  static const empty = LibraryStats(
    songCount: 0,
    totalDurationMs: 0,
    totalSizeBytes: 0,
    artistCount: 0,
    albumCount: 0,
    genreCount: 0,
    folderCount: 0,
    favoriteCount: 0,
    missingCount: 0,
    recentlyAdded: [],
    mostPlayed: [],
  );
}

/// A set of tracks that share a title/artist/duration and therefore may be
/// duplicate files on the device.
class DuplicateGroup {
  const DuplicateGroup(this.key, this.tracks);
  final String key;
  final List<MusicTrack> tracks;
}

class MusicRepository {
  MusicRepository(this._db, this._scanner);

  final AppDatabase _db;
  final MediaScanner _scanner;

  static const _legacyExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.flac',
  };

  // ---- Reads --------------------------------------------------------------

  /// All indexed tracks, newest first, for the Songs tab.
  Stream<List<MusicTrack>> watchTracks() =>
      (_db.select(_db.musicTracks)..orderBy([
        (t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.title),
      ])).watch();

  Stream<List<MusicTrack>> watchFavorites() =>
      (_db.select(_db.musicTracks)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.title),
            ]))
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

  Future<List<MusicTrack>> allTracks() => _db.select(_db.musicTracks).get();

  Future<int> trackCount() async => (await allTracks()).length;

  /// Distinct folders that contain indexed audio, with counts and durations.
  Stream<List<MusicFolderSummary>> watchFolderSummaries() =>
      watchTracks().map(_summariseFolders);

  static List<MusicFolderSummary> _summariseFolders(List<MusicTrack> tracks) {
    final byFolder = <String, List<MusicTrack>>{};
    for (final t in tracks) {
      final folder = t.folderPath.isEmpty ? '' : t.folderPath;
      byFolder.putIfAbsent(folder, () => []).add(t);
    }
    final summaries = [
      for (final entry in byFolder.entries)
        MusicFolderSummary(
          path: entry.key,
          name:
              entry.key.isEmpty
                  ? ''
                  : p.basename(entry.key.replaceAll('\\', '/')),
          trackCount: entry.value.length,
          durationMs: entry.value.fold(0, (s, t) => s + t.durationMs),
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
  }

  // ---- Scanning -----------------------------------------------------------

  /// Scans the device media library, upserting metadata and flagging rows that
  /// are no longer present. Existing favorites, play counts and custom
  /// collections are always preserved.
  Future<ScanResult> scanDevice() async {
    List<ScannedTrack> scanned;
    try {
      scanned = await _scanner.scanDevice();
    } catch (_) {
      return const ScanResult(permissionDenied: true);
    }
    return _reconcile(scanned);
  }

  /// Adds a folder (legacy/manual import) and scans only that directory.
  Future<ScanResult> addFolder(String path, {int maxFiles = 2000}) async {
    final already =
        await (_db.select(_db.musicFolders)
          ..where((t) => t.path.equals(path))).getSingleOrNull();
    if (already == null) {
      await _db
          .into(_db.musicFolders)
          .insert(MusicFoldersCompanion.insert(path: path));
    }
    return scanFolder(path, maxFiles: maxFiles);
  }

  /// Walks [path] for supported audio files. Used only for manual folder
  /// import; device-wide discovery goes through [scanDevice].
  Future<ScanResult> scanFolder(String path, {int maxFiles = 2000}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return const ScanResult();
    final existing = (await allTracks()).map((t) => t.uri).toSet();
    var added = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (entity is Directory) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_legacyExtensions.contains(ext)) continue;
      if (existing.contains(entity.path)) continue;
      final base = p.basenameWithoutExtension(entity.path);
      await _db
          .into(_db.musicTracks)
          .insert(
            MusicTracksCompanion.insert(
              uri: entity.path,
              title: Value(base),
              folderPath: Value(dir.path),
              mimeType: Value(mimeTypeForExtension(ext)),
            ),
          );
      added++;
      if (added >= maxFiles) break;
    }
    return ScanResult(added: added, total: added);
  }

  Future<ScanResult> _reconcile(List<ScannedTrack> scanned) async {
    final existing = await allTracks();
    final byMediaId = <String, MusicTrack>{
      for (final t in existing)
        if (t.mediaId.isNotEmpty) t.mediaId: t,
    };
    final byUri = <String, MusicTrack>{for (final t in existing) t.uri: t};

    var added = 0;
    var updated = 0;
    final matched = <int>{};
    await _db.transaction(() async {
      for (final s in scanned) {
        final match =
            (s.mediaId.isNotEmpty ? byMediaId[s.mediaId] : null) ??
            byUri[s.uri];
        if (match == null) {
          await _db
              .into(_db.musicTracks)
              .insert(_companion(s, forInsert: true));
          added++;
        } else {
          matched.add(match.id);
          await (_db.update(_db.musicTracks)..where(
            (t) => t.id.equals(match.id),
          )).write(_companion(s, forInsert: false));
          updated++;
        }
      }
    });

    var missingMarked = 0;
    for (final t in existing) {
      if (matched.contains(t.id) || t.isMissing) continue;
      if (await _isGone(t)) {
        await (_db.update(_db.musicTracks)..where(
          (x) => x.id.equals(t.id),
        )).write(const MusicTracksCompanion(isMissing: Value(true)));
        missingMarked++;
      }
    }
    return ScanResult(
      added: added,
      updated: updated,
      missingMarked: missingMarked,
      total: scanned.length,
    );
  }

  Future<bool> _isGone(MusicTrack t) async {
    if (t.uri.startsWith('content://')) {
      // Not returned by the last MediaStore query: treated as removed.
      return true;
    }
    try {
      return !File(t.uri.replaceFirst('file://', '')).existsSync();
    } catch (_) {
      return true;
    }
  }

  MusicTracksCompanion _companion(ScannedTrack s, {required bool forInsert}) =>
      MusicTracksCompanion(
        uri: Value(s.uri),
        title: Value(s.title),
        artist: Value(s.artist),
        album: Value(s.album),
        durationMs: Value(s.durationMs),
        folderPath: Value(s.folderPath),
        mediaId: Value(s.mediaId),
        albumId: Value(s.albumId),
        artistId: Value(s.artistId),
        genre: Value(s.genre),
        mimeType: Value(s.mimeType),
        sizeBytes: Value(s.sizeBytes),
        dateModified: Value(s.dateModified),
        trackNumber: Value(s.trackNumber),
        isMissing: const Value(false),
        addedAt:
            forInsert
                ? Value(s.dateAdded ?? DateTime.now())
                : const Value.absent(),
      );

  Future<void> removeFolder(int id) async {
    final folder =
        await (_db.select(_db.musicFolders)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (folder == null) return;
    final tracks =
        await (_db.select(_db.musicTracks)
          ..where((t) => t.folderPath.equals(folder.path))).get();
    await _deleteTracks(tracks.map((t) => t.id).toList());
    await (_db.delete(_db.musicFolders)..where((t) => t.id.equals(id))).go();
  }

  /// Removes tracks from the index only. User files are never deleted.
  Future<void> _deleteTracks(List<int> ids) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      await (_db.delete(_db.playlistItems)
        ..where((t) => t.trackId.isIn(ids))).go();
      await (_db.delete(_db.musicHistory)
        ..where((t) => t.trackId.isIn(ids))).go();
      await (_db.delete(_db.musicTracks)..where((t) => t.id.isIn(ids))).go();
    });
  }

  // ---- Favorites / play metadata -----------------------------------------

  Future<void> toggleFavorite(MusicTrack track) =>
      setFavorite(track.id, !track.isFavorite);

  Future<void> setFavorite(int trackId, bool value) =>
      (_db.update(_db.musicTracks)..where(
        (t) => t.id.equals(trackId),
      )).write(MusicTracksCompanion(isFavorite: Value(value)));

  /// Records a genuine play: appends to history and bumps the counter.
  Future<void> recordPlay(int trackId) async {
    final track =
        await (_db.select(_db.musicTracks)
          ..where((t) => t.id.equals(trackId))).getSingleOrNull();
    if (track == null) return;
    await _db.transaction(() async {
      await _db
          .into(_db.musicHistory)
          .insert(MusicHistoryCompanion.insert(trackId: trackId));
      await (_db.update(_db.musicTracks)
        ..where((t) => t.id.equals(trackId))).write(
        MusicTracksCompanion(
          lastPlayedAt: Value(DateTime.now()),
          playCount: Value(track.playCount + 1),
        ),
      );
    });
  }

  Stream<List<MusicTrack>> watchHistory({int limit = 100}) {
    final query =
        _db.select(_db.musicTracks).join([
            innerJoin(
              _db.musicHistory,
              _db.musicHistory.trackId.equalsExp(_db.musicTracks.id),
            ),
          ])
          ..orderBy([OrderingTerm.desc(_db.musicHistory.playedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.musicTracks)).toList(),
    );
  }

  Future<void> clearHistory() => _db.delete(_db.musicHistory).go();

  Future<int> countMissingFiles() async {
    final tracks = await allTracks();
    var missing = 0;
    for (final t in tracks) {
      if (t.isMissing) {
        missing++;
      } else if (!t.uri.startsWith('content://') &&
          !File(t.uri.replaceFirst('file://', '')).existsSync()) {
        missing++;
      }
    }
    return missing;
  }

  // ---- Collections (playlists & labels) -----------------------------------

  Stream<List<Playlist>> watchCollections({String? kind}) {
    final query = _db.select(_db.playlists)..orderBy([
      (t) => OrderingTerm(expression: t.sortOrder),
      (t) => OrderingTerm(expression: t.name),
    ]);
    if (kind != null) query.where((t) => t.kind.equals(kind));
    return query.watch();
  }

  Future<int> createCollection({
    required String name,
    String kind = 'playlist',
    int? accentColor,
    String coverUri = '',
    String description = '',
  }) async {
    final maxOrder = (await (_db.select(_db.playlists)).get()).fold<int>(
      -1,
      (m, p) => math.max(m, p.sortOrder),
    );
    return _db
        .into(_db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: name,
            kind: Value(kind),
            accentColor: Value(accentColor),
            coverUri: Value(coverUri),
            description: Value(description),
            sortOrder: Value(maxOrder + 1),
          ),
        );
  }

  Future<void> updateCollection(
    int id, {
    String? name,
    int? accentColor,
    bool clearAccent = false,
    String? coverUri,
    String? description,
  }) => (_db.update(_db.playlists)..where((t) => t.id.equals(id))).write(
    PlaylistsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      accentColor:
          clearAccent
              ? const Value(null)
              : (accentColor == null
                  ? const Value.absent()
                  : Value(accentColor)),
      coverUri: coverUri == null ? const Value.absent() : Value(coverUri),
      description:
          description == null ? const Value.absent() : Value(description),
    ),
  );

  Future<void> deleteCollection(int id) =>
      (_db.delete(_db.playlists)..where((t) => t.id.equals(id))).go();

  Future<void> reorderCollections(List<int> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.playlists)..where(
          (t) => t.id.equals(orderedIds[i]),
        )).write(PlaylistsCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<void> addToCollection(int collectionId, int trackId) async {
    final existing =
        await (_db.select(_db.playlistItems)..where(
          (t) => t.playlistId.equals(collectionId) & t.trackId.equals(trackId),
        )).getSingleOrNull();
    if (existing != null) return;
    final order = await _nextOrder(collectionId);
    await _db
        .into(_db.playlistItems)
        .insert(
          PlaylistItemsCompanion.insert(
            playlistId: collectionId,
            trackId: trackId,
            orderIndex: Value(order),
          ),
        );
  }

  Future<void> addManyToCollection(int collectionId, List<int> trackIds) async {
    await _db.transaction(() async {
      var order = await _nextOrder(collectionId);
      final present =
          (await (_db.select(_db.playlistItems)
                ..where((t) => t.playlistId.equals(collectionId))).get())
              .map((r) => r.trackId)
              .toSet();
      for (final id in trackIds) {
        if (!present.add(id)) continue;
        await _db
            .into(_db.playlistItems)
            .insert(
              PlaylistItemsCompanion.insert(
                playlistId: collectionId,
                trackId: id,
                orderIndex: Value(order++),
              ),
            );
      }
    });
  }

  Future<int> _nextOrder(int collectionId) async {
    final rows =
        await (_db.select(_db.playlistItems)
          ..where((t) => t.playlistId.equals(collectionId))).get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.orderIndex).reduce(math.max) + 1;
  }

  Future<void> removeFromCollection(int collectionId, int trackId) =>
      (_db.delete(_db.playlistItems)..where(
        (t) => t.playlistId.equals(collectionId) & t.trackId.equals(trackId),
      )).go();

  Future<void> removeManyFromCollection(
    int collectionId,
    List<int> trackIds,
  ) async {
    if (trackIds.isEmpty) return;
    await (_db.delete(_db.playlistItems)..where(
      (t) => t.playlistId.equals(collectionId) & t.trackId.isIn(trackIds),
    )).go();
  }

  Future<void> reorderCollectionItems(
    int collectionId,
    List<int> orderedTrackIds,
  ) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.playlistItems)
            ..where((t) => t.playlistId.equals(collectionId))).get();
      final byTrack = {for (final r in rows) r.trackId: r.id};
      for (var i = 0; i < orderedTrackIds.length; i++) {
        final rowId = byTrack[orderedTrackIds[i]];
        if (rowId == null) continue;
        await (_db.update(_db.playlistItems)..where(
          (t) => t.id.equals(rowId),
        )).write(PlaylistItemsCompanion(orderIndex: Value(i)));
      }
    });
  }

  Stream<List<MusicTrack>> watchCollectionTracks(int collectionId) {
    final query =
        _db.select(_db.musicTracks).join([
            innerJoin(
              _db.playlistItems,
              _db.playlistItems.trackId.equalsExp(_db.musicTracks.id),
            ),
          ])
          ..where(_db.playlistItems.playlistId.equals(collectionId))
          ..orderBy([OrderingTerm.asc(_db.playlistItems.orderIndex)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.musicTracks)).toList(),
    );
  }

  /// Tracks that belong to at least one collection, keyed by track id, so song
  /// rows can show which labels they are already in.
  Future<Set<int>> collectionMemberIds(int collectionId) async {
    final rows =
        await (_db.select(_db.playlistItems)
          ..where((t) => t.playlistId.equals(collectionId))).get();
    return rows.map((r) => r.trackId).toSet();
  }

  // ---- Statistics ---------------------------------------------------------

  Future<LibraryStats> computeStats() async {
    final tracks = await allTracks();
    if (tracks.isEmpty) return LibraryStats.empty;
    final artists = <String>{};
    final albums = <String>{};
    final genres = <String>{};
    final folders = <String>{};
    var duration = 0;
    var size = 0;
    var favorites = 0;
    var missing = 0;
    for (final t in tracks) {
      if (t.artist.isNotEmpty) artists.add(t.artist.toLowerCase());
      if (t.album.isNotEmpty) albums.add(t.album.toLowerCase());
      if (t.genre.isNotEmpty) genres.add(t.genre.toLowerCase());
      folders.add(t.folderPath);
      duration += t.durationMs;
      size += t.sizeBytes;
      if (t.isFavorite) favorites++;
      if (t.isMissing) missing++;
    }
    final recent = [...tracks]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final played =
        tracks.where((t) => t.playCount > 0).toList()
          ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return LibraryStats(
      songCount: tracks.length,
      totalDurationMs: duration,
      totalSizeBytes: size,
      artistCount: artists.length,
      albumCount: albums.length,
      genreCount: genres.length,
      folderCount: folders.length,
      favoriteCount: favorites,
      missingCount: missing,
      recentlyAdded: recent.take(10).toList(),
      mostPlayed: played.take(10).toList(),
    );
  }

  /// Groups suspected duplicate files by title + artist + whole-second
  /// duration. The user reviews and confirms before anything is removed.
  Future<List<DuplicateGroup>> findDuplicates() async {
    final tracks = await allTracks();
    final groups = <String, List<MusicTrack>>{};
    for (final t in tracks) {
      if (t.title.isEmpty) continue;
      final key =
          '${t.title.toLowerCase()}|${t.artist.toLowerCase()}|${t.durationMs ~/ 1000}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    return [
      for (final entry in groups.entries)
        if (entry.value.length > 1) DuplicateGroup(entry.key, entry.value),
    ];
  }

  // ---- Persisted playback state ------------------------------------------

  Future<MusicStateData?> loadState() =>
      (_db.select(_db.musicState)
        ..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> saveState({
    int? lastTrackId,
    int positionMs = 0,
    bool? shuffle,
    int? repeatMode,
    String? queueJson,
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
              queueJson: Value(queueJson ?? ''),
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
          queueJson:
              queueJson == null ? const Value.absent() : Value(queueJson),
        ),
      );
    }
  }
}

/// A folder that contains indexed audio, with aggregate counts.
class MusicFolderSummary {
  const MusicFolderSummary({
    required this.path,
    required this.name,
    required this.trackCount,
    required this.durationMs,
  });

  final String path;
  final String name;
  final int trackCount;
  final int durationMs;
}

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaScannerProvider),
  ),
);
