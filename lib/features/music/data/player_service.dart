import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/db/database.dart';
import 'music_repository.dart';

enum RepeatMode { off, all, one }

/// Overridden in `main` with the handler returned by `AudioService.init`.
///
/// It is `null` in tests and whenever background audio could not be
/// initialised, in which case [MusicPlayerController] falls back to an
/// in-process player.
final audioHandlerProvider = Provider<AalumaiAudioHandler?>((ref) => null);

/// Bridges `just_audio` to the Android media session so playback continues in
/// the background and is controllable from the lock screen / notification.
///
/// The handler owns the [AudioPlayer]; the controller drives it and pushes
/// metadata. Transport buttons pressed outside the app are routed back through
/// [onNext] / [onPrevious].
class AalumaiAudioHandler extends BaseAudioHandler with SeekHandler {
  AalumaiAudioHandler(this.player) {
    player.playbackEventStream.listen(_broadcast, onError: (_, __) {});
  }

  final AudioPlayer player;

  int _index = 0;

  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;

  /// Replaces the advertised queue and highlights [index].
  void publishQueue(List<MediaItem> items, int index) {
    _index = index;
    queue.add(items);
    _setCurrent(items, index);
    _broadcast();
  }

  void _setCurrent(List<MediaItem> items, int index) {
    if (index >= 0 && index < items.length) {
      mediaItem.add(items[index]);
    }
  }

  void _broadcast([PlaybackEvent? event]) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessing(player.processingState),
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index,
      ),
    );
  }

  AudioProcessingState _mapProcessing(ProcessingState value) => switch (value) {
    ProcessingState.idle => AudioProcessingState.idle,
    ProcessingState.loading => AudioProcessingState.loading,
    ProcessingState.buffering => AudioProcessingState.buffering,
    ProcessingState.ready => AudioProcessingState.ready,
    ProcessingState.completed => AudioProcessingState.completed,
  };

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }
}

class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.index = -1,
    this.playing = false,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.error,
  });

  final List<MusicTrack> queue;
  final int index;
  final bool playing;
  final bool shuffle;
  final RepeatMode repeat;
  final Duration duration;
  final Duration position;
  final String? error;

  MusicTrack? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  bool get hasTrack => current != null;

  PlayerState copyWith({
    List<MusicTrack>? queue,
    int? index,
    bool? playing,
    bool? shuffle,
    RepeatMode? repeat,
    Duration? duration,
    Duration? position,
    String? error,
    bool clearError = false,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Music player built on `just_audio`, with optional `audio_service` background
/// playback. When [audioHandlerProvider] is overridden (in `main`) playback
/// continues in the background with media-notification controls; otherwise it
/// plays in-process only (as in tests).
///
/// This session is intentionally separate from the alarm audio session so that
/// music actions can never replace an active alarm sound.
class MusicPlayerController extends Notifier<PlayerState> {
  AudioPlayer? _ownPlayer;
  Timer? _sleepTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  AalumaiAudioHandler? get _handler => ref.read(audioHandlerProvider);

  AudioPlayer get _player => _handler?.player ?? (_ownPlayer ??= AudioPlayer());

  List<MediaItem> _mediaItems() => [
    for (final t in state.queue) _toMediaItem(t),
  ];

  MediaItem _toMediaItem(MusicTrack track) => MediaItem(
    id: track.id.toString(),
    title: track.title,
    artist: track.artist.isEmpty ? null : track.artist,
    album: track.album.isEmpty ? null : track.album,
    duration:
        track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null,
    artUri:
        (track.albumId != null && track.albumId! > 0)
            ? Uri.parse(
              'content://media/external/audio/albumart/${track.albumId}',
            )
            : null,
  );

  @override
  PlayerState build() {
    ref.onDispose(() {
      _sleepTimer?.cancel();
      _posSub?.cancel();
      _stateSub?.cancel();
      _durSub?.cancel();
      _interruptionSub?.cancel();
      _noisySub?.cancel();
      _ownPlayer?.dispose();
    });

    final handler = _handler;
    handler?.onNext = next;
    handler?.onPrevious = previous;

    final player = _player;
    _posSub = player.positionStream.listen((pos) {
      if (state.position.inSeconds != pos.inSeconds) {
        state = state.copyWith(position: pos);
      }
    });
    _durSub = player.durationStream.listen((d) {
      // `null` means the duration is not known yet (or no longer known). Zero
      // makes the timeline fall back to the track's own metadata instead of
      // holding on to the previous track's duration.
      state = state.copyWith(duration: d ?? Duration.zero);
    });
    _stateSub = player.playerStateStream.listen((ps) {
      state = state.copyWith(playing: ps.playing);
      if (ps.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });
    unawaited(_configureSession());
    return const PlayerState();
  }

  /// Configures the audio session for music, handling audio focus changes,
  /// transient ducking and headphone-unplug (becoming noisy).
  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.4);
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _player.pause();
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1);
            case AudioInterruptionType.pause:
              _player.play();
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        _player.pause();
      });
    } catch (_) {
      // No audio session (e.g. tests/desktop): play without focus handling.
    }
  }

  Future<void> playQueue(List<MusicTrack> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    if (startIndex < 0 || startIndex >= tracks.length) startIndex = 0;
    state = state.copyWith(
      queue: List<MusicTrack>.from(tracks),
      index: startIndex,
      clearError: true,
    );
    await _loadCurrent();
  }

  /// Plays a single track immediately, replacing the queue.
  Future<void> playTrack(MusicTrack track) => playQueue([track], 0);

  Future<void> _loadCurrent() async {
    final track = state.current;
    if (track == null) return;
    // Drop the previous track's timeline before the new source loads, so the
    // seek bar can never show the old position/duration (and let the user scrub
    // against a length that belongs to another track). The displayed maximum
    // falls back to `track.durationMs` while the real one is unknown.
    state = state.copyWith(
      duration: Duration.zero,
      position: Duration.zero,
      clearError: true,
    );
    try {
      await _setSource(track.uri);
      _handler?.publishQueue(_mediaItems(), state.index);
      state = state.copyWith(clearError: true);
      await _player.play();
      // Record only after the track actually starts, so failed loads and
      // previews never inflate the count.
      try {
        await ref.read(musicRepositoryProvider).recordPlay(track.id);
      } catch (_) {}
    } catch (e) {
      state = state.copyWith(error: 'unavailable', playing: false);
    }
  }

  Future<void> _setSource(String uri) async {
    if (uri.startsWith('content://')) {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
    } else {
      await _player.setFilePath(uri.replaceFirst('file://', ''));
    }
  }

  void _onCompleted() {
    switch (state.repeat) {
      case RepeatMode.one:
        _player.seek(Duration.zero);
        _player.play();
      case RepeatMode.all:
        next();
      case RepeatMode.off:
        if (state.index < state.queue.length - 1) {
          next();
        } else {
          state = state.copyWith(playing: false);
        }
    }
  }

  Future<void> togglePlay() async {
    if (state.current == null) return;
    if (state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    final nextIndex =
        state.shuffle ? _randomIndex() : (state.index + 1) % state.queue.length;
    state = state.copyWith(index: nextIndex);
    await _loadCurrent();
  }

  int _randomIndex() {
    if (state.queue.length <= 1) return state.index;
    var i = state.index;
    while (i == state.index) {
      i = Random().nextInt(state.queue.length);
    }
    return i;
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prevIndex =
        (state.index - 1 + state.queue.length) % state.queue.length;
    state = state.copyWith(index: prevIndex);
    await _loadCurrent();
  }

  /// Seeks the current track and reflects the new position in the state
  /// immediately.
  ///
  /// Publishing the target here is what keeps the timeline honest: the position
  /// stream is deliberately coarse, so without this the thumb would snap back
  /// to where it was until the next tick landed after the user let go.
  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _player.seek(position);
  }

  /// Jumps to [index] within the current queue and starts playback.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(index: index, clearError: true);
    await _loadCurrent();
  }

  /// Inserts [track] right after the current track.
  Future<void> playNext(MusicTrack track) async {
    final queue = [...state.queue];
    if (state.current == null) {
      await playQueue([track], 0);
      return;
    }
    queue.insert(state.index + 1, track);
    state = state.copyWith(queue: queue);
    _handler?.publishQueue(_mediaItems(), state.index);
  }

  /// Appends [track] to the end of the queue (or starts it if empty).
  Future<void> addToQueue(MusicTrack track) async {
    if (state.current == null) {
      await playQueue([track], 0);
      return;
    }
    state = state.copyWith(queue: [...state.queue, track]);
    _handler?.publishQueue(_mediaItems(), state.index);
  }

  Future<void> addManyToQueue(List<MusicTrack> tracks) async {
    if (tracks.isEmpty) return;
    if (state.current == null) {
      await playQueue(tracks, 0);
      return;
    }
    state = state.copyWith(queue: [...state.queue, ...tracks]);
    _handler?.publishQueue(_mediaItems(), state.index);
  }

  /// Removes the queue entry at [index]. Removing the current track advances to
  /// the following one; removing the last remaining track stops playback.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final queue = [...state.queue]..removeAt(index);
    if (queue.isEmpty) {
      state = const PlayerState();
      await _player.stop();
      return;
    }
    var newIndex = state.index;
    if (index < state.index) {
      newIndex = state.index - 1;
    } else if (index == state.index) {
      newIndex = state.index.clamp(0, queue.length - 1);
    }
    final wasCurrent = index == state.index;
    state = state.copyWith(queue: queue, index: newIndex);
    if (wasCurrent) {
      await _loadCurrent();
    } else {
      _handler?.publishQueue(_mediaItems(), state.index);
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final queue = [...state.queue];
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex.clamp(0, queue.length), item);
    var index = state.index;
    if (oldIndex == state.index) {
      index = newIndex;
    } else if (oldIndex < state.index && newIndex >= state.index) {
      index = state.index - 1;
    } else if (oldIndex > state.index && newIndex <= state.index) {
      index = state.index + 1;
    }
    state = state.copyWith(queue: queue, index: index);
    _handler?.publishQueue(_mediaItems(), state.index);
  }

  void clearQueue() {
    state = const PlayerState();
    _player.stop();
  }

  void setShuffle(bool value) {
    state = state.copyWith(shuffle: value);
    _persist();
  }

  void setRepeat(RepeatMode mode) {
    state = state.copyWith(repeat: mode);
    _persist();
  }

  void cycleRepeat() {
    final next = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    setRepeat(next);
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () {
      _player.pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  void _persist() {
    final track = state.current;
    unawaited(
      Future(() async {
        try {
          await ref
              .read(musicRepositoryProvider)
              .saveState(
                lastTrackId: track?.id,
                shuffle: state.shuffle,
                repeatMode: state.repeat.index,
              );
        } catch (_) {}
      }),
    );
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerController, PlayerState>(
      MusicPlayerController.new,
    );
