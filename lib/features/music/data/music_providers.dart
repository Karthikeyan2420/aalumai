import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import 'media_scanner.dart';
import 'music_repository.dart';

// ---- Library query (search / sort / filter) --------------------------------

enum TrackSort { dateAdded, dateModified, title, artist, album, duration, size }

enum TrackFilter { all, favorites, missing }

class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.sort = TrackSort.dateAdded,
    this.ascending = false,
    this.filter = TrackFilter.all,
    this.compact = false,
  });

  final String search;
  final TrackSort sort;
  final bool ascending;
  final TrackFilter filter;
  final bool compact;

  LibraryQuery copyWith({
    String? search,
    TrackSort? sort,
    bool? ascending,
    TrackFilter? filter,
    bool? compact,
  }) => LibraryQuery(
    search: search ?? this.search,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    filter: filter ?? this.filter,
    compact: compact ?? this.compact,
  );
}

class LibraryQueryController extends Notifier<LibraryQuery> {
  @override
  LibraryQuery build() => const LibraryQuery();

  void setSearch(String value) => state = state.copyWith(search: value);
  void setSort(TrackSort sort, {bool? ascending}) {
    if (state.sort == sort && ascending == null) {
      state = state.copyWith(ascending: !state.ascending);
    } else {
      state = state.copyWith(sort: sort, ascending: ascending ?? false);
    }
  }

  void setFilter(TrackFilter filter) => state = state.copyWith(filter: filter);
  void toggleCompact() => state = state.copyWith(compact: !state.compact);
}

final libraryQueryProvider =
    NotifierProvider<LibraryQueryController, LibraryQuery>(
      LibraryQueryController.new,
    );

/// The timestamp used for "date added" grouping/sorting. MediaStore's
/// `date_added` is stored in `addedAt` at index time; when a file was never
/// given a date it keeps its local index time, so we never invent a value.
DateTime dateAddedOf(MusicTrack t) => t.addedAt;

/// Applies [query]'s search, filter and sort to [tracks]. Pure and synchronous
/// so it never triggers a rescan.
List<MusicTrack> applyTrackQuery(List<MusicTrack> tracks, LibraryQuery query) {
  final term = query.search.trim().toLowerCase();
  Iterable<MusicTrack> out = tracks;
  if (query.filter == TrackFilter.favorites) {
    out = out.where((t) => t.isFavorite);
  } else if (query.filter == TrackFilter.missing) {
    out = out.where((t) => t.isMissing);
  }
  if (term.isNotEmpty) {
    out = out.where(
      (t) =>
          t.title.toLowerCase().contains(term) ||
          t.artist.toLowerCase().contains(term) ||
          t.album.toLowerCase().contains(term) ||
          t.genre.toLowerCase().contains(term) ||
          p.basename(t.uri.replaceAll('\\', '/')).toLowerCase().contains(term),
    );
  }
  final list = out.toList();
  int compare(MusicTrack a, MusicTrack b) {
    switch (query.sort) {
      case TrackSort.dateAdded:
        return a.addedAt.compareTo(b.addedAt);
      case TrackSort.dateModified:
        return (a.dateModified ?? a.addedAt).compareTo(
          b.dateModified ?? b.addedAt,
        );
      case TrackSort.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case TrackSort.artist:
        return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      case TrackSort.album:
        return a.album.toLowerCase().compareTo(b.album.toLowerCase());
      case TrackSort.duration:
        return a.durationMs.compareTo(b.durationMs);
      case TrackSort.size:
        return a.sizeBytes.compareTo(b.sizeBytes);
    }
  }

  list.sort((a, b) {
    final c = compare(a, b);
    return query.ascending ? c : -c;
  });
  return list;
}

/// Date buckets used to group the Songs tab.
enum DateBucket { today, yesterday, thisWeek, earlier, unknown }

DateBucket bucketFor(DateTime? date, DateTime now) {
  if (date == null) return DateBucket.unknown;
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return DateBucket.today;
  if (diff == 1) return DateBucket.yesterday;
  if (diff < 7) return DateBucket.thisWeek;
  return DateBucket.earlier;
}

// ---- Async library streams -------------------------------------------------

final musicTracksProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchTracks(),
);

final musicFavoritesProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchFavorites(),
);

final musicRecentProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchRecent(),
);

final musicHistoryProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchHistory(),
);

final musicFolderSummariesProvider = StreamProvider<List<MusicFolderSummary>>(
  (ref) => ref.watch(musicRepositoryProvider).watchFolderSummaries(),
);

/// All songs with the current search/sort/filter applied.
final visibleTracksProvider = StreamProvider<List<MusicTrack>>((ref) {
  final query = ref.watch(libraryQueryProvider);
  return ref
      .watch(musicRepositoryProvider)
      .watchTracks()
      .map((tracks) => applyTrackQuery(tracks, query));
});

final playlistsProvider = StreamProvider<List<Playlist>>(
  (ref) =>
      ref.watch(musicRepositoryProvider).watchCollections(kind: 'playlist'),
);

final labelsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(musicRepositoryProvider).watchCollections(kind: 'label'),
);

final allCollectionsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(musicRepositoryProvider).watchCollections(),
);

final collectionTracksProvider = StreamProvider.family<List<MusicTrack>, int>(
  (ref, id) => ref.watch(musicRepositoryProvider).watchCollectionTracks(id),
);

final libraryStatsProvider = FutureProvider<LibraryStats>(
  (ref) => ref.watch(musicRepositoryProvider).computeStats(),
);

final duplicatesProvider = FutureProvider<List<DuplicateGroup>>(
  (ref) => ref.watch(musicRepositoryProvider).findDuplicates(),
);

final missingCountProvider = FutureProvider<int>(
  (ref) => ref.watch(musicRepositoryProvider).countMissingFiles(),
);

// ---- Scan controller -------------------------------------------------------

enum ScanPhase {
  idle,
  scanning,
  done,
  permissionDenied,
  permissionPermanentlyDenied,
}

class ScanController extends Notifier<ScanPhase> {
  ScanResult? lastResult;

  @override
  ScanPhase build() => ScanPhase.idle;

  /// Requests the audio permission (when [requestPermission]) and scans the
  /// device media library. Safe to call repeatedly; rescans never clear
  /// favorites, play counts or custom collections.
  Future<void> scan({bool requestPermission = true}) async {
    if (requestPermission) {
      final status = await ref.read(mediaScannerProvider).requestPermission();
      if (status == MusicPermissionStatus.denied) {
        state = ScanPhase.permissionDenied;
        return;
      }
      if (status == MusicPermissionStatus.permanentlyDenied) {
        state = ScanPhase.permissionPermanentlyDenied;
        return;
      }
    }
    state = ScanPhase.scanning;
    lastResult = await ref.read(musicRepositoryProvider).scanDevice();
    state = ScanPhase.done;
  }

  void reset() => state = ScanPhase.idle;
}

final scanControllerProvider = NotifierProvider<ScanController, ScanPhase>(
  ScanController.new,
);
