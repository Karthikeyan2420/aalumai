import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../preferences/app_preferences.dart';

/// Overridden in [main] once [SharedPreferences] is loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The selected interface language code (`en`, `ta`, `te`, `ml`, `kn`).
/// `null` means "follow the system locale".
final localeCodeProvider = NotifierProvider<LocaleController, String?>(
  LocaleController.new,
);

class LocaleController extends Notifier<String?> {
  @override
  String? build() => ref.watch(appPreferencesProvider).localeCode;

  Future<void> setLocale(String? code) async {
    final prefs = ref.read(appPreferencesProvider);
    if (code == null) {
      await prefs.setLocaleCode('');
    } else {
      await prefs.setLocaleCode(code);
    }
    state = code;
  }
}

enum AppThemeMode { system, light, dark }

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final value = ref.watch(appPreferencesProvider).themeMode;
    return AppThemeMode.values[value.clamp(0, 2)];
  }

  Future<void> setMode(AppThemeMode mode) async {
    await ref.read(appPreferencesProvider).setThemeMode(mode.index);
    state = mode;
  }
}

/// Notifier used to force a rebuild after bulk data changes (e.g. restore).
final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);

class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
