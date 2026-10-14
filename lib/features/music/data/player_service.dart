import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
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
class MusicPlayerController extends Notifier<PlayerState> {
  AudioPlayer? _ownPlayer;
  Timer? _sleepTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription<Duration?>? _durSub;

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
  );

  @override
  PlayerState build() {
    ref.onDispose(() {
      _sleepTimer?.cancel();
      _posSub?.cancel();
      _stateSub?.cancel();
      _durSub?.cancel();
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
      if (d != null) state = state.copyWith(duration: d);
    });
    _stateSub = player.playerStateStream.listen((ps) {
      state = state.copyWith(playing: ps.playing);
      if (ps.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });
    return const PlayerState();
  }

  Future<void> playQueue(List<MusicTrack> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    final queue = List<MusicTrack>.from(tracks);
    state = state.copyWith(queue: queue, index: startIndex, clearError: true);
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final track = state.current;
    if (track == null) return;
    try {
      await _player.setFilePath(track.uri);
      _handler?.publishQueue(_mediaItems(), state.index);
      await ref.read(musicRepositoryProvider).markPlayed(track.id);
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: 'unavailable', playing: false);
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

  Future<void> seek(Duration position) => _player.seek(position);

  void setShuffle(bool value) {
    state = state.copyWith(shuffle: value);
  }

  void setRepeat(RepeatMode mode) => state = state.copyWith(repeat: mode);

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
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerController, PlayerState>(
      MusicPlayerController.new,
    );
