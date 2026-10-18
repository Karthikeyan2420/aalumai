import 'dart:convert';

import 'package:flutter/services.dart';

/// A single record from the bundled exercise dataset (Exercise Gym GIFs DB).
///
/// Deliberately free of Flutter widgets and of the database: the catalog owns
/// every detail of the dataset's shape, so the repository and the UI only ever
/// deal with plain values.
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.slug,
    required this.name,
    required this.muscle,
    required this.bodyPart,
    required this.equipment,
    required this.category,
    required this.secondaryMuscles,
    required this.instructions,
    required this.gifUrl,
  });

  factory CatalogExercise.fromJson(Map<String, dynamic> json) {
    return CatalogExercise(
      id: _string(json['id']),
      slug: _string(json['slug']),
      name: _string(json['name']),
      muscle: _string(json['muscle']),
      bodyPart: _string(json['bodyPart']),
      equipment: _string(json['equipment']),
      category: _string(json['category']),
      secondaryMuscles: _stringList(json['secondaryMuscles']),
      instructions: _stringList(json['instructions']),
      gifUrl: _string(json['gifUrl']),
    );
  }

  /// Stable dataset identifier, e.g. `chest/push-up`.
  final String id;
  final String slug;
  final String name;

  /// Primary muscle key, e.g. `pectorals`.
  final String muscle;

  /// Coarse region: arms, legs, chest, back, core, shoulders or cardio.
  final String bodyPart;

  /// Equipment key, e.g. bodyweight, dumbbell, barbell, cable, machine.
  final String equipment;

  /// Movement category: strength, stretching, cardio or plyometrics.
  final String category;

  final List<String> secondaryMuscles;

  /// Step-by-step form cues, exactly as published by the dataset.
  final List<String> instructions;

  /// Animated demonstration. Empty when the dataset ships no media.
  final String gifUrl;

  static String _string(Object? value) => value is String ? value.trim() : '';

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is String && entry.trim().isNotEmpty) entry.trim(),
    ];
  }
}

/// Loads and caches the exercise dataset that ships inside the app bundle.
///
/// The JSON is bundled as an asset rather than fetched, so the library works
/// offline and is never downloaded again after install. [load] additionally
/// memoises the parsed list, so every screen reuses one decode.
class ExerciseCatalog {
  ExerciseCatalog({AssetBundle? bundle}) : _bundle = bundle;

  /// Bundled copy of Exercise Gym GIFs DB (`api/en/exercises.json`, v1.1.0).
  static const assetPath = 'assets/data/exercises.json';

  final AssetBundle? _bundle;

  AssetBundle get _assetBundle => _bundle ?? rootBundle;

  Future<List<CatalogExercise>>? _pending;

  /// Parses the dataset once per instance. Records without a name, and any
  /// record whose id repeats an earlier one, are dropped so the library can
  /// never show the same exercise twice.
  Future<List<CatalogExercise>> load() => _pending ??= _parse();

  Future<List<CatalogExercise>> _parse() async {
    final raw = await _assetBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final rows = decoded['exercises'];
    if (rows is! List) return const [];
    final seen = <String>{};
    final result = <CatalogExercise>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final exercise = CatalogExercise.fromJson(row.cast<String, dynamic>());
      if (exercise.name.isEmpty) continue;
      final key = exercise.id.isEmpty ? exercise.name : exercise.id;
      if (!seen.add(key)) continue;
      result.add(exercise);
    }
    return List.unmodifiable(result);
  }
}
