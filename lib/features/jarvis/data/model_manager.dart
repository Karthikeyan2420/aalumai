import 'dart:async';
import 'dart:io';

import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Phases of a model download/import.
enum ModelInstallPhase { downloading, verifying, installed }

class ModelInstallProgress {
  const ModelInstallProgress({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  final ModelInstallPhase phase;
  final int receivedBytes;

  /// -1 when the server did not report a length.
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

/// Owns the app-private GGUF model file: download from Hugging Face, import
/// from a user-picked file, integrity bookkeeping, deletion.
///
/// The model never ships inside the APK. It lives under
/// `<documents>/models/` so storage scales with the file, updates are just
/// a re-download, and nothing is written outside app-private storage.
class ModelManager {
  ModelManager(this._prefs, {Directory? modelsDirectory})
    : _modelsDir = modelsDirectory;

  final AppPreferences _prefs;
  Directory? _modelsDir;

  static const kModelFileName = 'qwen3-1.7b-q4_k_m.gguf';
  // Qwen's own GGUF repo ships only a Q8_0 build; this is the llama.cpp
  // org's Q4_K_M quant of the same base model (~1.28 GB), verified reachable.
  static const kModelUrl =
      'https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/'
      'Qwen3-1.7B-Q4_K_M.gguf';

  /// Integrity pin: the LFS object id (= SHA-256 of the file) published by
  /// Hugging Face for [kModelUrl].
  static const kExpectedSha256 =
      'd2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5';

  Future<Directory> _dir() async {
    final existing = _modelsDir;
    if (existing != null) return existing;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models'));
    await dir.create(recursive: true);
    _modelsDir = dir;
    return dir;
  }

  /// Absolute path of the installed model, or null when none is installed.
  Future<String?> modelPathIfPresent() async {
    final name = _prefs.jarvisModelFile;
    if (name.isEmpty) return null;
    final file = File(p.join((await _dir()).path, name));
    if (!await file.exists()) return null;
    return file.path;
  }

  Future<int> modelSizeBytes() async {
    final path = await modelPathIfPresent();
    if (path == null) return 0;
    return File(path).length();
  }

  /// Downloads the model, verifying its SHA-256, and installs it into the
  /// models directory. Progress is streamed for the UI; the final event is
  /// [ModelInstallPhase.installed].
  Stream<ModelInstallProgress> download() async* {
    final dir = await _dir();
    final target = File(p.join(dir.path, kModelFileName));
    final part = File('${target.path}.part');
    final client = HttpClient()..autoUncompress = false;

    try {
      final request = await client.getUrl(Uri.parse(kModelUrl));
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download failed with HTTP ${response.statusCode}.',
          uri: Uri.parse(kModelUrl),
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          yield ModelInstallProgress(
            phase: ModelInstallPhase.downloading,
            receivedBytes: received,
            totalBytes: total,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      yield ModelInstallProgress(
        phase: ModelInstallPhase.verifying,
        receivedBytes: received,
        totalBytes: total > 0 ? total : received,
      );
      final digest = await sha256.bind(part.openRead()).first;
      final hex = digest.toString();
      if (kExpectedSha256.isNotEmpty &&
          hex.toLowerCase() != kExpectedSha256.toLowerCase()) {
        await part.delete();
        throw const FormatException(
          'The downloaded model failed its integrity check.',
        );
      }

      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      await _prefs.setJarvisModelFile(kModelFileName);
      await _prefs.setJarvisModelSha256(hex);
      yield ModelInstallProgress(
        phase: ModelInstallPhase.installed,
        receivedBytes: received,
        totalBytes: total > 0 ? total : received,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Copies a user-picked `.gguf` file (e.g. from a USB drive or browser
  /// download) into the models directory, recording its hash.
  Future<String> importFromFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('File not found', sourcePath);
    }
    final dir = await _dir();
    final target = File(p.join(dir.path, kModelFileName));
    if (await target.exists()) await target.delete();
    await source.copy(target.path);
    final digest = await sha256.bind(target.openRead()).first;
    await _prefs.setJarvisModelFile(kModelFileName);
    await _prefs.setJarvisModelSha256(digest.toString());
    return target.path;
  }

  Future<void> deleteModel() async {
    final path = await modelPathIfPresent();
    if (path != null) await File(path).delete();
    await _prefs.setJarvisModelFile('');
    await _prefs.setJarvisModelSha256('');
  }
}

final jarvisModelManagerProvider = Provider<ModelManager>(
  (ref) => ModelManager(ref.watch(appPreferencesProvider)),
);
