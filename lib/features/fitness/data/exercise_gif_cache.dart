import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import 'exercise_catalog.dart';
import 'fitness_offline_storage.dart';

/// Downloads home-compatible exercise GIFs into app documents storage.
class ExerciseGifCache {
  ExerciseGifCache(this._catalog);

  final ExerciseCatalog _catalog;

  Directory? _root;

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'exercise_gifs'));
    await _root!.create(recursive: true);
    return _root!;
  }

  Future<File?> localFileForUrl(String gifUrl) async {
    if (gifUrl.trim().isEmpty) return null;
    final offline = await localOfflineGifFile(gifUrl);
    if (offline != null) return offline;
    final fileName = _fileNameFromUrl(gifUrl);
    if (fileName == null) return null;
    final file = File(p.join((await _dir()).path, fileName));
    return file.existsSync() ? file : null;
  }

  Future<File?> localFileForExercise(Exercise exercise) =>
      localFileForUrl(exercise.gifUrl);

  String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    return segments.join('_').replaceAll(RegExp(r'[^\w\.\-]+'), '_');
  }

  Future<({int done, int total})> downloadHomeGifs({
    void Function(int done, int total)? onProgress,
  }) async {
    final catalog = await _catalog.load();
    final targets = catalog.where((e) {
      final eq = e.equipment.trim().toLowerCase();
      if (e.category.trim().toLowerCase() == 'stretching') return true;
      return eq == 'bodyweight' ||
          eq == 'dumbbell' ||
          eq == 'band' ||
          eq == 'kettlebell' ||
          eq.isEmpty;
    }).where((e) => e.gifUrl.trim().isNotEmpty).toList();
    final total = targets.length;
    var done = 0;
    final dir = await _dir();
    for (final entry in targets) {
      final name = _fileNameFromUrl(entry.gifUrl);
      if (name == null) {
        done++;
        onProgress?.call(done, total);
        continue;
      }
      final out = File(p.join(dir.path, name));
      if (!out.existsSync()) {
        try {
          final response = await http
              .get(Uri.parse(entry.gifUrl))
              .timeout(const Duration(seconds: 45));
          if (response.statusCode == 200) {
            await out.writeAsBytes(response.bodyBytes, flush: true);
          }
        } catch (_) {
          // Skip failed downloads; network GIF remains fallback.
        }
      }
      done++;
      onProgress?.call(done, total);
    }
    return (done: done, total: total);
  }
}

final exerciseGifCacheProvider = Provider<ExerciseGifCache>(
  (ref) => ExerciseGifCache(ref.watch(exerciseCatalogProvider)),
);

final gifDownloadProgressProvider = StateProvider<({int done, int total})?>(
  (ref) => null,
);
