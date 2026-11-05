import 'package:flutter/painting.dart';

import '../../../core/db/database.dart';
import 'equipment_filter.dart';
import 'exercise_collections.dart';
import 'workout_preferences.dart';

/// How a poster cover is cropped inside a workout focus card.
class GymCoverFrame {
  const GymCoverFrame({required this.alignment, this.scale = 1.0});

  final Alignment alignment;
  final double scale;
}

/// Teal accent used across the gym-style fitness shell.
const kGymTeal = 0xFF0E8C86; // AppColors.teal — unified brand accent

/// Keys persisted in [WorkoutPreferences.focusAreaOrder].
enum GymFocusKey {
  armShoulder,
  backChest,
  abs,
  leg,
  cardio,
  warmUpStretch;

  String get storageKey => switch (this) {
    GymFocusKey.armShoulder => 'arm_shoulder',
    GymFocusKey.backChest => 'back_chest',
    GymFocusKey.abs => 'abs',
    GymFocusKey.leg => 'leg',
    GymFocusKey.cardio => 'cardio',
    GymFocusKey.warmUpStretch => 'warm_up_stretch',
  };

  static GymFocusKey? fromKey(String raw) {
    for (final v in GymFocusKey.values) {
      if (v.storageKey == raw.trim()) return v;
    }
    return null;
  }

  String get title => switch (this) {
    GymFocusKey.armShoulder => 'ARM & SHOULDER',
    GymFocusKey.backChest => 'BACK & CHEST',
    GymFocusKey.abs => 'ABS',
    GymFocusKey.leg => 'LEG',
    GymFocusKey.cardio => 'CARDIO',
    GymFocusKey.warmUpStretch => 'WARM UP & STRETCH',
  };

  String subtitle(bool dumbbellMode) => switch (this) {
    GymFocusKey.cardio || GymFocusKey.warmUpStretch => '4 Workouts',
    _ => '3 levels',
  };

  String coverAsset(WorkoutMode mode) {
    if (this == GymFocusKey.warmUpStretch) {
      return 'assets/images/fitness/cover_warmup_bodyweight.png';
    }
    if (this == GymFocusKey.cardio) {
      return 'assets/images/fitness/cover_cardio_bodyweight.png';
    }
    return 'assets/gym/$storageKey.png';
  }

  /// Per-asset framing: gym photos use natural scale; legacy posters need zoom.
  GymCoverFrame coverFrame(WorkoutMode mode) {
    if (this != GymFocusKey.cardio && this != GymFocusKey.warmUpStretch) {
      return const GymCoverFrame(alignment: Alignment.center, scale: 1);
    }
    return const GymCoverFrame(
      alignment: Alignment.bottomCenter,
      scale: 1.85,
    );
  }

  List<int> get muscleGroups => switch (this) {
    GymFocusKey.armShoulder => const [0, 1],
    GymFocusKey.backChest => const [2, 3],
    GymFocusKey.abs => const [5],
    GymFocusKey.leg => const [4],
    GymFocusKey.cardio => const [6],
    GymFocusKey.warmUpStretch => const [7],
  };
}

List<GymFocusKey> defaultFocusOrder({required bool dumbbellMode}) {
  if (dumbbellMode) {
    return const [
      GymFocusKey.armShoulder,
      GymFocusKey.backChest,
      GymFocusKey.abs,
      GymFocusKey.leg,
    ];
  }
  return const [
    GymFocusKey.armShoulder,
    GymFocusKey.backChest,
    GymFocusKey.abs,
    GymFocusKey.leg,
    GymFocusKey.cardio,
    GymFocusKey.warmUpStretch,
  ];
}

List<GymFocusKey> resolveFocusOrder(WorkoutPreferences prefs, WorkoutMode mode) {
  final parsed = [
    for (final key in prefs.focusAreaOrder)
      if (GymFocusKey.fromKey(key) case final area?) area,
  ];
  final defaults = defaultFocusOrder(dumbbellMode: mode == WorkoutMode.dumbbell);
  if (parsed.isEmpty) return defaults;
  final out = <GymFocusKey>[...parsed];
  for (final d in defaults) {
    if (!out.contains(d)) out.add(d);
  }
  return out.where(defaults.contains).toList();
}

bool _matchesFocus(Exercise e, GymFocusKey focus) {
  final groups = focus.muscleGroups.toSet();
  if (e.category >= 0 && groups.contains(e.category)) return true;
  // Warm-up: also accept stretching source rows filed as category 7.
  if (focus == GymFocusKey.warmUpStretch) {
    return e.sourceCategory.trim().toLowerCase() == 'stretching' ||
        e.category == 7 ||
        e.category == 8;
  }
  if (focus == GymFocusKey.cardio) {
    return e.category == 6 ||
        e.sourceCategory.trim().toLowerCase() == 'cardio' ||
        e.bodyPart.trim().toLowerCase() == 'cardio';
  }
  return false;
}

bool _preferredForMode(Exercise e, WorkoutMode mode) {
  final collection = exerciseCollection(e);
  if (collection == WorkoutCollection.gym) return false;
  if (!isHomeCompatible(e.equipment, mode)) return false;
  if (mode == WorkoutMode.dumbbell) {
    return collection == WorkoutCollection.dumbbell ||
        e.equipment.trim().toLowerCase() == 'dumbbell' ||
        e.equipment.trim().toLowerCase() == 'kettlebell';
  }
  // Bodyweight mode: bodyweight / empty / band (home, no free weights).
  final key = e.equipment.trim().toLowerCase();
  return key.isEmpty ||
      key == 'none' ||
      key == 'bodyweight' ||
      key == 'band' ||
      collection == WorkoutCollection.bodyweight ||
      collection == WorkoutCollection.stretching;
}

/// Picks exercises for a focus-area workout at [levelIndex] 0..2.
///
/// Always tries to return a full session. Prefers mode-matched equipment, then
/// falls back to any home-compatible exercise in the focus muscle groups.
List<Exercise> pickFocusExercises({
  required List<Exercise> all,
  required GymFocusKey focus,
  required WorkoutMode mode,
  required int levelIndex,
  required int count,
}) {
  final level = levelIndex.clamp(0, 2);
  final take = (count + level * 2).clamp(8, 20);

  final inFocus = all.where((e) => _matchesFocus(e, focus)).toList();
  final preferred =
      inFocus.where((e) => _preferredForMode(e, mode)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final fallback =
      inFocus
          .where(
            (e) =>
                exerciseCollection(e) != WorkoutCollection.gym &&
                isHomeCompatible(
                  e.equipment,
                  // Abs/cardio often need bodyweight even on dumbbell tab.
                  mode == WorkoutMode.dumbbell
                      ? WorkoutMode.dumbbell
                      : WorkoutMode.bodyweight,
                ),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  var pool = preferred.isNotEmpty ? preferred : fallback;
  if (pool.isEmpty) {
    // Last resort: any home exercise for this mode (keeps Level 1–3 usable).
    pool =
        all
            .where(
              (e) =>
                  exerciseCollection(e) != WorkoutCollection.gym &&
                  isHomeCompatible(e.equipment, mode),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
  }
  if (pool.isEmpty) return const [];

  // Level shifts the window so Level 1 / 2 / 3 are different sessions.
  final start = (level * (pool.length ~/ 3).clamp(1, 8)) % pool.length;
  final out = <Exercise>[];
  final seen = <int>{};
  for (var i = 0; i < pool.length && out.length < take; i++) {
    final e = pool[(start + i) % pool.length];
    if (seen.add(e.id)) out.add(e);
  }
  // Pad from fallback if preferred pool was short.
  if (out.length < take) {
    for (final e in fallback) {
      if (out.length >= take) break;
      if (seen.add(e.id)) out.add(e);
    }
  }
  return out;
}
