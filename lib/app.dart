import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/language_setup_screen.dart';

class AalumaiApp extends ConsumerStatefulWidget {
  const AalumaiApp({super.key});

  @override
  ConsumerState<AalumaiApp> createState() => _AalumaiAppState();
}

class _AalumaiAppState extends ConsumerState<AalumaiApp> {
  late final GoRouter _router = createRouter();
  late bool _needsSetup;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPreferencesProvider);
    _needsSetup = !prefs.firstRunComplete;
  }

  ThemeMode _themeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(localeCodeProvider);
    final themeMode = ref.watch(themeModeProvider);

    final locale =
        (localeCode == null || localeCode.isEmpty) ? null : Locale(localeCode);

    const delegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

    if (_needsSetup) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode(themeMode),
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LanguageSetupScreen(
          onFinished: () => setState(() => _needsSetup = false),
        ),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode(themeMode),
      locale: locale,
      localizationsDelegates: delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
