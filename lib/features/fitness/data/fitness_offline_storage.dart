import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Root folder under app documents for downloaded fitness media.
const kFitnessOfflineRoot = 'fitness_offline';

String? fileNameFromMediaUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  return segments.join('_').replaceAll(RegExp(r'[^\w\.\-]+'), '_');
}

Future<Directory> fitnessOfflineRootDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, kFitnessOfflineRoot));
  await dir.create(recursive: true);
  return dir;
}

Future<File?> localOfflineGifFile(String gifUrl) async {
  final name = fileNameFromMediaUrl(gifUrl);
  if (name == null) return null;
  final file = File(p.join((await fitnessOfflineRootDir()).path, 'gifs', name));
  return file.existsSync() ? file : null;
}

Future<File?> localOfflineYogaImageFile(String imageUrl) async {
  final name = fileNameFromMediaUrl(imageUrl);
  if (name == null) return null;
  final file = File(
    p.join((await fitnessOfflineRootDir()).path, 'yoga', name),
  );
  return file.existsSync() ? file : null;
}
