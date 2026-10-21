import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/geo.dart';
import 'fitness_repository.dart';

/// Which kind of GPS session is being recorded. Maps onto the workout session
/// `type` column (run = 1, walk = 2), matching [FitnessRepository.watchRuns].
enum RunType {
  run,
  walk;

  int get sessionType => index + 1;
}

class RunState {
  const RunState({
    this.type = RunType.run,
    this.name = '',
    this.sessionId,
    this.points = const [],
    this.elapsedSec = 0,
    this.active = false,
    this.paused = false,
    this.error,
  });

  final RunType type;
  final String name;
  final int? sessionId;
  final List<GeoPoint> points;
  final int elapsedSec;
  final bool active;
  final bool paused;
  final String? error;

  double get distanceMeters => pathDistanceMeters(points);

  int get pacePerKm => paceSecondsPerKm(distanceMeters.round(), elapsedSec);

  RunState copyWith({
    RunType? type,
    String? name,
    int? sessionId,
    List<GeoPoint>? points,
    int? elapsedSec,
    bool? active,
    bool? paused,
    String? error,
    bool clearError = false,
  }) {
    return RunState(
      type: type ?? this.type,
      name: name ?? this.name,
      sessionId: sessionId ?? this.sessionId,
      points: points ?? this.points,
      elapsedSec: elapsedSec ?? this.elapsedSec,
      active: active ?? this.active,
      paused: paused ?? this.paused,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Records a GPS run/walk: streams positions, accumulates distance and elapsed
/// time, and persists the finished session (with an encoded route) to the
/// existing workout-session schema.
class RunTrackerController extends AutoDisposeNotifier<RunState> {
  StreamSubscription<Position>? _posSub;
  Timer? _timer;

  @override
  RunState build() {
    ref.onDispose(() {
      final id = state.sessionId;
      final stillActive = state.active;
      _posSub?.cancel();
      _posSub = null;
      _timer?.cancel();
      _timer = null;
      // Leaving the screen must stop GPS. An unsaved session is removed so a
      // half-started run does not stay active in the background.
      if (stillActive && id != null) {
        unawaited(ref.read(fitnessRepositoryProvider).deleteSession(id));
      }
    });
    return const RunState();
  }

  Future<void> start({required RunType type, required String name}) async {
    if (state.active) return;
    final sessionId = await ref
        .read(fitnessRepositoryProvider)
        .startSession(name: name, type: type.sessionType);
    state = RunState(
      type: type,
      name: name,
      sessionId: sessionId,
      active: true,
    );

    if (await _ensurePermission()) {
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(_addPoint, onError: (_) => state = state.copyWith(error: 'gps'));
    } else {
      state = state.copyWith(error: 'permission');
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.active && !state.paused) {
        state = state.copyWith(elapsedSec: state.elapsedSec + 1);
      }
    });
  }

  void _addPoint(Position position) {
    if (!state.active || state.paused) return;
    final point = GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestampMs: position.timestamp.millisecondsSinceEpoch,
    );
    state = state.copyWith(points: [...state.points, point]);
  }

  void pause() {
    if (state.active) state = state.copyWith(paused: true);
  }

  void resume() {
    if (state.active) state = state.copyWith(paused: false);
  }

  /// Persists the session and returns its id (or null if none was created).
  Future<int?> stopAndSave() async {
    final distance = state.distanceMeters.round();
    final elapsed = state.elapsedSec;
    final route = jsonEncode([for (final p in state.points) p.toJson()]);
    final id = state.sessionId;
    await _teardown();
    if (id != null) {
      await ref
          .read(fitnessRepositoryProvider)
          .finishSession(
            id,
            durationSec: elapsed,
            distanceMeters: distance,
            routeJson: route,
          );
    }
    state = const RunState();
    return id;
  }

  /// Abandons the session, removing the placeholder row.
  Future<void> discard() async {
    final id = state.sessionId;
    await _teardown();
    if (id != null) {
      await ref.read(fitnessRepositoryProvider).deleteSession(id);
    }
    state = const RunState();
  }

  Future<void> _teardown() async {
    await _posSub?.cancel();
    _posSub = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}

final runTrackerProvider =
    NotifierProvider.autoDispose<RunTrackerController, RunState>(
      RunTrackerController.new,
    );
