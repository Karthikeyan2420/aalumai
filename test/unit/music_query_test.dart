import 'package:aalumai/features/music/data/music_providers.dart';
import 'package:aalumai/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

MusicTrack track({
  int id = 1,
  String title = 'Song',
  String artist = 'A',
  String album = 'Album',
  int durationMs = 120000,
  String uri = 'file:/tmp/song.mp3',
  String folderPath = '/tmp',
  int sizeBytes = 1024,
  DateTime? addedAt,
  bool isFavorite = false,
  bool isMissing = false,
  int playCount = 0,
  int? albumId,
}) => MusicTrack(
  id: id,
  uri: uri,
  title: title,
  artist: artist,
  album: album,
  durationMs: durationMs,
  folderPath: folderPath,
  mediaId: '',
  mimeType: 'audio/mpeg',
  sizeBytes: sizeBytes,
  dateModified: null,
  trackNumber: 0,
  addedAt: addedAt ?? DateTime(2024, 1, 1),
  lastPlayedAt: null,
  isFavorite: isFavorite,
  isMissing: isMissing,
  playCount: playCount,
  albumId: albumId,
  genre: '',
  albumArtUri: '',
);

void main() {
  group('applyTrackQuery', () {
    test('searches across title, artist, album and path', () {
      final list = [
        track(id: 1, title: 'Dream', artist: 'Moon'),
        track(id: 2, title: 'Sun', artist: 'Wave', album: 'Heat'),
        track(id: 3, uri: 'file:/music/space.mp3'),
      ];
      final res = applyTrackQuery(list, const LibraryQuery(search: 'moon'));
      expect(res.map((e) => e.id), [1]);
      final res2 = applyTrackQuery(list, const LibraryQuery(search: 'space'));
      expect(res2.map((e) => e.id), [3]);
    });

    test('filters favorites and missing', () {
      final list = [
        track(id: 1, isFavorite: true),
        track(id: 2, isMissing: true),
        track(id: 3),
      ];
      expect(
        applyTrackQuery(
          list,
          const LibraryQuery(filter: TrackFilter.favorites),
        ).map((e) => e.id),
        [1],
      );
      expect(
        applyTrackQuery(
          list,
          const LibraryQuery(filter: TrackFilter.missing),
        ).map((e) => e.id),
        [2],
      );
    });

    test('sorts by title ascending and descending', () {
      final list = [track(id: 1, title: 'B'), track(id: 2, title: 'A')];
      final asc = applyTrackQuery(
        list,
        const LibraryQuery(sort: TrackSort.title, ascending: true),
      );
      expect(asc.map((e) => e.id), [2, 1]);
      final desc = applyTrackQuery(
        list,
        const LibraryQuery(sort: TrackSort.title, ascending: false),
      );
      expect(desc.map((e) => e.id), [1, 2]);
    });

    test('groups by date bucket with dateAdded', () {
      final now = DateTime(2024, 1, 10, 12);
      expect(bucketFor(DateTime(2024, 1, 10), now), DateBucket.today);
      expect(bucketFor(DateTime(2024, 1, 9), now), DateBucket.yesterday);
      expect(bucketFor(DateTime(2024, 1, 8), now), DateBucket.thisWeek);
      expect(bucketFor(DateTime(2023, 12, 28), now), DateBucket.earlier);
      expect(bucketFor(null, now), DateBucket.unknown);
    });
  });
}
