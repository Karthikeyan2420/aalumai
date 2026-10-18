import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// Audio container extensions AALUMAI indexes. Playback of a container still
/// depends on the platform codec, so unsupported items are reported rather
/// than silently dropped.
const kSupportedAudioExtensions = <String>{
  'mp3',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'opus',
  'flac',
};

/// Whether [extension] (with or without a leading dot) is a supported audio
/// container.
bool isSupportedAudioExtension(String extension) => kSupportedAudioExtensions
    .contains(extension.replaceFirst('.', '').toLowerCase());

/// Best-effort MIME type for a container [extension].
String mimeTypeForExtension(String extension) {
  switch (extension.replaceFirst('.', '').toLowerCase()) {
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'opus':
      return 'audio/opus';
    case 'flac':
      return 'audio/flac';
    default:
      return 'audio/*';
  }
}

/// Outcome of a runtime permission request for music access.
enum MusicPermissionStatus { granted, denied, permanentlyDenied }

/// One audio file discovered on the device, before it is persisted as a
/// `MusicTrack`. Keeps both a playable [uri] and the on-disk [filePath] so the
/// library can group by folder even when playback goes through a content URI.
class ScannedTrack {
  const ScannedTrack({
    required this.uri,
    required this.title,
    this.filePath = '',
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.folderPath = '',
    this.mediaId = '',
    this.albumId,
    this.artistId,
    this.genre = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.dateModified,
    this.dateAdded,
    this.trackNumber = 0,
  });

  /// Playable URI. Prefers the MediaStore content URI; falls back to a
  /// constructed `content://media/external/audio/media/<id>`.
  final String uri;

  /// Absolute path of the file on disk, when the platform exposes it.
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String folderPath;

  /// Stable MediaStore identifier used to deduplicate across rescans.
  final String mediaId;
  final int? albumId;
  final int? artistId;
  final String genre;
  final String mimeType;
  final int sizeBytes;
  final DateTime? dateModified;

  /// MediaStore `date_added`, when the platform reports it.
  final DateTime? dateAdded;
  final int trackNumber;

  /// Maps a MediaStore [song] to a [ScannedTrack]. Pure: no platform calls, so
  /// it is unit-testable by constructing [SongModel] from a plain map.
  factory ScannedTrack.fromSong(SongModel song, String extension) {
    final ext = extension.replaceFirst('.', '').toLowerCase();
    final filePath = song.data;
    final title =
        song.title.trim().isNotEmpty
            ? song.title.trim()
            : song.displayNameWOExt.trim();
    final reportedUri = song.uri;
    return ScannedTrack(
      uri:
          (reportedUri != null && reportedUri.isNotEmpty)
              ? reportedUri
              : 'content://media/external/audio/media/${song.id}',
      filePath: filePath,
      title: title,
      artist: (song.artist ?? '').trim(),
      album: (song.album ?? '').trim(),
      durationMs: song.duration ?? 0,
      folderPath: filePath.isNotEmpty ? p.dirname(filePath) : '',
      mediaId: song.id.toString(),
      albumId: song.albumId,
      artistId: song.artistId,
      genre: (song.genre ?? '').trim(),
      mimeType: mimeTypeForExtension(ext),
      sizeBytes: song.size,
      dateModified: _seconds(song.dateModified),
      dateAdded: _seconds(song.dateAdded),
      trackNumber: song.track ?? 0,
    );
  }

  static DateTime? _seconds(int? value) =>
      (value == null || value <= 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
}

/// Reads the device's media library through Android MediaStore
/// (`on_audio_query`). Only the audio-read permission the running Android
/// version needs is requested: `READ_MEDIA_AUDIO` on API 33+, otherwise
/// `READ_EXTERNAL_STORAGE`.
class MediaScanner {
  MediaScanner([OnAudioQuery? query]) : _query = query ?? OnAudioQuery();

  final OnAudioQuery _query;

  Future<bool> hasPermission() async {
    if ((await Permission.audio.status).isGranted) return true;
    return (await Permission.storage.status).isGranted;
  }

  Future<MusicPermissionStatus> requestPermission() async {
    PermissionStatus audio = PermissionStatus.denied;
    PermissionStatus storage = PermissionStatus.denied;
    try {
      audio = await Permission.audio.request();
    } catch (_) {
      // Not a runtime permission on this OS version; fall through to storage.
    }
    if (audio.isGranted) return MusicPermissionStatus.granted;
    try {
      storage = await Permission.storage.request();
    } catch (_) {}
    if (storage.isGranted) return MusicPermissionStatus.granted;
    if (audio.isPermanentlyDenied || storage.isPermanentlyDenied) {
      return MusicPermissionStatus.permanentlyDenied;
    }
    return MusicPermissionStatus.denied;
  }

  /// The container extension MediaStore reports for [song], normalised without
  /// a leading dot and lower-cased.
  static String extensionOf(SongModel song) {
    if (song.fileExtension.isNotEmpty) {
      return song.fileExtension.toLowerCase();
    }
    return p.extension(song.data).replaceFirst('.', '').toLowerCase();
  }

  /// Queries all music on the device. Ringtones, alarms, notifications and
  /// unsupported containers are skipped.
  Future<List<ScannedTrack>> scanDevice({int maxFiles = 5000}) async {
    final songs = await _query.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final out = <ScannedTrack>[];
    for (final song in songs) {
      if (song.isMusic == false ||
          song.isRingtone == true ||
          song.isAlarm == true ||
          song.isNotification == true) {
        continue;
      }
      final ext = extensionOf(song);
      if (!isSupportedAudioExtension(ext)) continue;
      out.add(ScannedTrack.fromSong(song, ext));
      if (out.length >= maxFiles) break;
    }
    return out;
  }
}

final mediaScannerProvider = Provider<MediaScanner>((ref) => MediaScanner());
