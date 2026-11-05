import 'package:flutter/material.dart';

/// AALUMAI brand palette: deep navy, teal, warm canvas, restrained gold.
class AppColors {
  static const navy = Color(0xFF0B1F3A);
  static const navyLight = Color(0xFF1B3A63);
  static const navyDark = Color(0xFF071525);
  static const teal = Color(0xFF0E8C86);
  static const tealLight = Color(0xFF3FB6AE);
  static const gold = Color(0xFFC9A227);
  static const canvasLight = Color(0xFFF4F7F6);
  static const surfaceTint = Color(0xFFF4F6F8);
}

/// Standard horizontal screen padding and card spacing.
abstract final class AppSpacing {
  static const screen = 20.0;
  static const cardGap = 12.0;
  static const cardRadius = 20.0;
}

class AppTheme {
  static ThemeData light() => _base(_lightScheme);

  static ThemeData dark() => _base(_darkScheme);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.teal,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD4F0EE),
    onPrimaryContainer: AppColors.navy,
    secondary: AppColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE0F5F3),
    onSecondaryContainer: AppColors.navy,
    tertiary: AppColors.gold,
    onTertiary: AppColors.navy,
    tertiaryContainer: Color(0xFFF5EAC8),
    onTertiaryContainer: AppColors.navy,
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.navy,
    onSurfaceVariant: Color(0xFF4A5F73),
    outline: Color(0xFF8A9BAB),
    outlineVariant: Color(0xFFD0D9E0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.navy,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.tealLight,
    surfaceTint: AppColors.teal,
    surfaceContainerHighest: Color(0xFFE8ECEF),
    surfaceContainerHigh: Color(0xFFEEF1F3),
    surfaceContainer: Color(0xFFF4F7F6),
    surfaceContainerLow: AppColors.canvasLight,
    surfaceContainerLowest: Colors.white,
    surfaceBright: Colors.white,
    surfaceDim: Color(0xFFDDE3E8),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.tealLight,
    onPrimary: AppColors.navyDark,
    primaryContainer: Color(0xFF0A4A47),
    onPrimaryContainer: Color(0xFFB8E8E4),
    secondary: AppColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF0D3D3A),
    onSecondaryContainer: Color(0xFFB8E8E4),
    tertiary: AppColors.gold,
    onTertiary: AppColors.navyDark,
    tertiaryContainer: Color(0xFF4A3F12),
    onTertiaryContainer: Color(0xFFF5EAC8),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: Color(0xFF0E1A28),
    onSurface: Color(0xFFE8EEF3),
    onSurfaceVariant: Color(0xFFB0BEC9),
    outline: Color(0xFF6B7D8E),
    outlineVariant: Color(0xFF3D4F5E),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE8EEF3),
    onInverseSurface: AppColors.navyDark,
    inversePrimary: AppColors.teal,
    surfaceTint: AppColors.tealLight,
    surfaceContainerHighest: Color(0xFF2A3848),
    surfaceContainerHigh: Color(0xFF243040),
    surfaceContainer: Color(0xFF1A2838),
    surfaceContainerLow: Color(0xFF121E2C),
    surfaceContainerLowest: AppColors.navyDark,
    surfaceBright: Color(0xFF1E2C3C),
    surfaceDim: Color(0xFF0A121C),
  );

  static ThemeData _base(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final scaffold =
        isLight ? AppColors.canvasLight : AppColors.navyDark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadius),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 2,
        extendedSizeConstraints: const BoxConstraints(minHeight: 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        secondarySelectedColor: scheme.primary.withValues(alpha: 0.22),
        checkmarkColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      textTheme: _textTheme(scheme),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base =
        scheme.brightness == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black;
    return base
        .copyWith(
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
  }
}
