import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'background_config.dart';
import 'background_presets.dart';

/// Persists the Home and Alarm background selection in [SharedPreferences].
///
/// This deliberately uses its own preference keys instead of extending the
/// shared `AppPreferences` wrapper, so background customisation stays isolated
/// from unrelated settings.
class BackgroundStore {
  BackgroundStore(this._prefs);

  final SharedPreferences _prefs;

  static String keyFor(BackgroundSlot slot) => 'background_${slot.key}';

  /// Reads the stored configuration for [slot], or returns [fallback] when no
  /// value is stored or the stored value is corrupt/incomplete.
  BackgroundConfig read(BackgroundSlot slot, BackgroundConfig fallback) {
    final raw = _prefs.getString(keyFor(slot));
    if (raw == null || raw.isEmpty) return fallback;
    try {
      return BackgroundConfig.tryParse(jsonDecode(raw)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> write(BackgroundSlot slot, BackgroundConfig config) =>
      _prefs.setString(keyFor(slot), jsonEncode(config.toJson()));

  Future<void> clear(BackgroundSlot slot) => _prefs.remove(keyFor(slot));
}
