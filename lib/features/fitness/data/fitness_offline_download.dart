import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/yoga.dart';
import 'exercise_catalog.dart';
import 'exercise_gif_cache.dart';
import 'fitness_media_settings.dart';
import 'fitness_offline_storage.dart';
import 'yoga_repository.dart';

Map<String, dynamic> _yogaPoseToJson(YogaPose pose) {
  return {
    'english_name': pose.englishName,
    if (pose.sanskritName.isNotEmpty)
      'sanskrit_name_adapted': pose.sanskritName,
    if (pose.translation.isNotEmpty) 'translation_name': pose.translation,
    if (pose.description.isNotEmpty) 'pose_description': pose.description,
    if (pose.imageUrl.isNotEmpty) 'url_png': pose.imageUrl,
    'difficulty_level': switch (pose.difficulty) {
      YogaDifficulty.advanced => 'Advanced',
      YogaDifficulty.intermediate => 'Intermediate',
      _ => 'Beginner',
    },
    if (pose.apiId != null) 'id': pose.apiId,
  };
}

Future<void> downloadFitnessOfflinePack(
  WidgetRef ref, {
  void Function(int done, int total)? onProgress,
}) async {
  final catalog = await ref.read(exerciseCatalogProvider).load();
  final poses = await ref.read(yogaRepositoryProvider).loadPoses();
  final gifTargets =
      catalog.where((e) => e.gifUrl.trim().isNotEmpty).toList();
  final yogaTargets =
      poses.where((p) => p.imageUrl.trim().isNotEmpty).toList();
  final total = gifTargets.length + yogaTargets.length + 2;
  var done = 0;

  void tick() {
    done++;
    onProgress?.call(done, total);
  }

  final root = await fitnessOfflineRootDir();
  final gifsDir = Directory(p.join(root.path, 'gifs'));
  final yogaDir = Directory(p.join(root.path, 'yoga'));
  await gifsDir.create(recursive: true);
  await yogaDir.create(recursive: true);

  for (final entry in gifTargets) {
    final name = fileNameFromMediaUrl(entry.gifUrl);
    if (name != null) {
      final out = File(p.join(gifsDir.path, name));
      if (!out.existsSync()) {
        try {
          final response = await http
              .get(Uri.parse(entry.gifUrl))
              .timeout(const Duration(seconds: 45));
          if (response.statusCode == 200) {
            await out.writeAsBytes(response.bodyBytes, flush: true);
          }
        } catch (_) {}
      }
    }
    tick();
  }

  for (final pose in yogaTargets) {
    final name = fileNameFromMediaUrl(pose.imageUrl);
    if (name != null) {
      final out = File(p.join(yogaDir.path, name));
      if (!out.existsSync()) {
        try {
          final response = await http
              .get(Uri.parse(pose.imageUrl))
              .timeout(const Duration(seconds: 45));
          if (response.statusCode == 200) {
            await out.writeAsBytes(response.bodyBytes, flush: true);
          }
        } catch (_) {}
      }
    }
    tick();
  }

  final bundledExercises = await rootBundle.loadString(ExerciseCatalog.assetPath);
  await File(p.join(root.path, 'exercises.json')).writeAsString(
    bundledExercises,
    flush: true,
  );
  tick();

  final yogaJson = jsonEncode([
    for (final pose in poses) _yogaPoseToJson(pose),
  ]);
  await File(p.join(root.path, 'yoga_poses.json')).writeAsString(
    yogaJson,
    flush: true,
  );
  tick();

  await ref.read(fitnessMediaSettingsProvider.notifier).markOfflinePackReady();
}

Future<void> runFitnessOfflineDownload(WidgetRef ref) async {
  ref.read(gifDownloadProgressProvider.notifier).state = (done: 0, total: 1);
  await downloadFitnessOfflinePack(
    ref,
    onProgress: (done, total) {
      ref.read(gifDownloadProgressProvider.notifier).state = (
        done: done,
        total: total,
      );
    },
  );
  ref.read(gifDownloadProgressProvider.notifier).state = null;
}
