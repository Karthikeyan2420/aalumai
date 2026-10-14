import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/music/data/player_service.dart';
import 'package:flutter_test/flutter_test.dart';

MusicTrack _track(int id, String title) => MusicTrack(
  id: id,
  uri: 'file:///song$id.mp3',
  title: title,
  artist: 'Artist',
  album: 'Album',
  durationMs: 180000,
  folderPath: '/music',
  isFavorite: false,
  playCount: 0,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  group('PlayerState', () {
    test('current is null without a queue or valid index', () {
      expect(const PlayerState().current, isNull);
      expect(PlayerState(queue: [_track(1, 'A')], index: -1).current, isNull);
      expect(PlayerState(queue: [_track(1, 'A')], index: 5).current, isNull);
    });

    test('current returns the track at the index', () {
      final state = PlayerState(
        queue: [_track(1, 'A'), _track(2, 'B')],
        index: 1,
      );
      expect(state.current?.title, 'B');
    });

    test('copyWith updates fields and preserves the rest', () {
      final state = PlayerState(queue: [_track(1, 'A')], index: 0);
      final next = state.copyWith(playing: true, repeat: RepeatMode.all);
      expect(next.playing, isTrue);
      expect(next.repeat, RepeatMode.all);
      expect(next.index, 0);
      expect(next.current?.title, 'A');
    });

    test('copyWith can clear an error', () {
      final state = const PlayerState(error: 'unavailable');
      expect(state.copyWith(clearError: true).error, isNull);
      expect(state.copyWith(error: 'again').error, 'again');
    });
  });
}
