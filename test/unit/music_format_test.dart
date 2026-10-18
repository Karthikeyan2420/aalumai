import 'package:aalumai/features/music/data/media_scanner.dart';
import 'package:aalumai/features/music/widgets/music_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  group('formatDurationMs', () {
    test('formats minutes and seconds', () {
      expect(formatDurationMs(0), '0:00');
      expect(formatDurationMs(1000), '0:01');
      expect(formatDurationMs(65000), '1:05');
    });

    test('formats hours when present', () {
      expect(formatDurationMs(3600000), '1:00:00');
      expect(formatDurationMs(3723000), '1:02:03');
    });

    test('clamps non-positive values to zero', () {
      expect(formatDurationMs(-5), '0:00');
    });
  });

  group('formatStorageSize', () {
    test('formats bytes, kilobytes, megabytes and gigabytes', () {
      expect(formatStorageSize(0), '0 B');
      expect(formatStorageSize(512), '512 B');
      expect(formatStorageSize(1024), '1.0 KB');
      expect(formatStorageSize(1024 * 1024), '1.0 MB');
      expect(formatStorageSize(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });

  group('mime type and extension helpers', () {
    test('recognises supported extensions with or without a dot', () {
      expect(isSupportedAudioExtension('mp3'), isTrue);
      expect(isSupportedAudioExtension('.FLAC'), isTrue);
      expect(isSupportedAudioExtension('txt'), isFalse);
    });

    test('maps extensions to mime types', () {
      expect(mimeTypeForExtension('mp3'), 'audio/mpeg');
      expect(mimeTypeForExtension('.m4a'), 'audio/mp4');
      expect(mimeTypeForExtension('flac'), 'audio/flac');
      expect(mimeTypeForExtension('xyz'), 'audio/*');
    });
  });

  group('ScannedTrack.fromSong', () {
    SongModel song(Map<dynamic, dynamic> info) => SongModel(info);

    test('maps MediaStore fields onto a scanned track', () {
      final track = ScannedTrack.fromSong(
        song({
          '_id': 7,
          '_data': '/storage/emulated/0/Music/a.mp3',
          '_uri': 'content://media/external/audio/media/7',
          '_display_name': 'a.mp3',
          '_display_name_wo_ext': 'a',
          'title': 'My Song',
          'artist': 'Someone',
          'album': 'Album X',
          'duration': 123456,
          '_size': 4096,
          'file_extension': 'mp3',
          'date_added': 1700000000,
          'date_modified': 1700000100,
          'track': 3,
          'album_id': 9,
          'artist_id': 11,
          'genre': 'Rock',
        }),
        'mp3',
      );
      expect(track.uri, 'content://media/external/audio/media/7');
      expect(track.title, 'My Song');
      expect(track.artist, 'Someone');
      expect(track.album, 'Album X');
      expect(track.durationMs, 123456);
      expect(track.sizeBytes, 4096);
      expect(track.mediaId, '7');
      expect(track.albumId, 9);
      expect(track.artistId, 11);
      expect(track.genre, 'Rock');
      expect(track.trackNumber, 3);
      expect(track.folderPath, '/storage/emulated/0/Music');
      expect(track.mimeType, 'audio/mpeg');
      expect(
        track.dateAdded,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
    });

    test('falls back to a constructed uri and display name when missing', () {
      final track = ScannedTrack.fromSong(
        song({
          '_id': 42,
          '_data': '/music/song.mp3',
          '_display_name': 'song.mp3',
          '_display_name_wo_ext': 'song',
          'title': '',
          '_size': 10,
          'file_extension': 'mp3',
        }),
        'mp3',
      );
      expect(track.uri, 'content://media/external/audio/media/42');
      expect(track.title, 'song');
      expect(track.artist, '');
      expect(track.album, '');
    });
  });
}
