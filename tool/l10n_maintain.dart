// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Syncs regional ARB files with English keys and removes dead Jarvis keys.
void main() {
  final l10nDir = Directory('lib/core/localization/l10n');
  final enFile = File('${l10nDir.path}/app_en.arb');
  final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  for (final locale in ['en', 'ta', 'te', 'ml', 'kn']) {
    final path = '${l10nDir.path}/app_$locale.arb';
    final file = File(path);
    if (!file.existsSync()) continue;
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (entry.key.startsWith('jarvis')) continue;
      if (entry.key.startsWith('@')) continue;
      out[entry.key] = entry.value;
    }
    for (final entry in en.entries) {
      if (entry.key.startsWith('@')) continue;
      if (entry.key.startsWith('jarvis')) continue;
      out.putIfAbsent(entry.key, () => entry.value);
    }
    for (final entry in en.entries) {
      if (!entry.key.startsWith('@')) continue;
      final base = entry.key.substring(1);
      if (base.startsWith('jarvis')) continue;
      if (out.containsKey(base)) {
        out[entry.key] = entry.value;
      }
    }
    final encoded = const JsonEncoder.withIndent('  ').convert(out);
    file.writeAsStringSync('$encoded\n');
    print('Updated app_$locale.arb (${out.length} keys)');
  }
}
