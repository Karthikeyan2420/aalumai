import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/indian_yoga.dart';
import '../domain/yoga.dart';

/// Loads the yoga catalogue that ships inside the app bundle.
///
/// `assets/data/yoga_poses.json` is a snapshot of the yoga API's `/v1/poses`
/// response. It is merged with the curated Indian pose list so the Yoga screen
/// works offline and never depends on a live request to show a routine.
class YogaCatalog {
  YogaCatalog({AssetBundle? bundle}) : _bundle = bundle;

  static const assetPath = 'assets/data/yoga_poses.json';

  final AssetBundle? _bundle;

  AssetBundle get _assetBundle => _bundle ?? rootBundle;

  Future<List<YogaPose>>? _pending;

  /// Parses the snapshot once per instance and merges it with the curated
  /// catalogue. A missing or malformed asset degrades to the curated list
  /// rather than failing.
  Future<List<YogaPose>> load() => _pending ??= _parse();

  Future<List<YogaPose>> _parse() async {
    final apiPoses = <YogaPose>[];
    try {
      final raw = await _assetBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final row in decoded) {
          if (row is! Map) continue;
          final pose = YogaPose.fromApiJson(row.cast<String, dynamic>());
          if (pose == null) continue;
          apiPoses.add(pose);
        }
      }
    } catch (_) {
      // No snapshot available (missing asset, malformed JSON, or a platform
      // without assets): the curated catalogue still stands on its own.
    }
    return mergeYogaPoses(curated: kIndianYogaPoses, apiPoses: apiPoses);
  }
}
