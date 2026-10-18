import 'package:flutter/material.dart';

import 'background_config.dart';

/// Which screen a background applies to. Home and alarm backgrounds are stored
/// and customised independently.
enum BackgroundSlot {
  home,
  alarm;

  /// Short, stable identifier used for preference keys and file names.
  String get key => name;
}

/// Bundled background images (see `assets/ASSET_SOURCES.md` for licences).
class BackgroundAssets {
  const BackgroundAssets._();

  static const homeSunriseLakeMatheson =
      'assets/images/backgrounds/home/home_sunrise_lake_matheson.jpg';
  static const homeMistySunriseLakeAndes =
      'assets/images/backgrounds/home/home_misty_sunrise_lake_andes.jpg';
  static const homeSunriseLakeOkanagan =
      'assets/images/backgrounds/home/home_sunrise_lake_okanagan.jpg';
  static const homeSunriseCanarySpring =
      'assets/images/backgrounds/home/home_sunrise_canary_spring.jpg';
  static const alarmFullMoonNight01 =
      'assets/images/backgrounds/alarm/alarm_full_moon_night_01.jpg';
  static const alarmFullMoonNight02 =
      'assets/images/backgrounds/alarm/alarm_full_moon_night_02.jpg';
  static const alarmStarrySkyTekapo =
      'assets/images/backgrounds/alarm/alarm_starry_sky_tekapo.jpg';

  /// The default ringing backdrop bundled with the alarm redesign.
  static const alarmBackdrop = 'assets/images/alarm_background.png';

  /// Every bundled background asset, used to validate stored values.
  static const all = <String>{
    homeSunriseLakeMatheson,
    homeMistySunriseLakeAndes,
    homeSunriseLakeOkanagan,
    homeSunriseCanarySpring,
    alarmFullMoonNight01,
    alarmFullMoonNight02,
    alarmStarrySkyTekapo,
    alarmBackdrop,
  };
}

/// A named, one-tap background option offered in settings.
class BackgroundPreset {
  const BackgroundPreset({
    required this.id,
    required this.label,
    required this.config,
  });

  final String id;
  final String label;
  final BackgroundConfig config;
}

/// Built-in presets and defaults for each slot.
class BackgroundPresets {
  const BackgroundPresets._();

  // Calm, near-white daylight wash: the clean default dashboard backdrop.
  static const _homeLightGradient = BackgroundConfig.gradient(<int>[
    0xFFFFFFFF,
    0xFFEAF3FB,
  ], label: 'Soft daylight');

  // Deep navy wash: the dark-theme counterpart of the daylight dashboard, kept
  // close to the dark surface so overlaid text and cards stay readable.
  static const _homeDarkGradient = BackgroundConfig.gradient(<int>[
    0xFF0E1116,
    0xFF18202B,
  ], label: 'Midnight');

  // Warm sunrise-inspired gradient: cream → amber → deep orange.
  static const _homeWarmGradient = BackgroundConfig.gradient(<int>[
    0xFFFFF3E0,
    0xFFFFB74D,
    0xFFEF6C00,
  ], label: 'Warm sunrise');

  // Dark navy → near-black, for a readable night-sky alarm.
  static const _alarmNightGradient = BackgroundConfig.gradient(<int>[
    0xFF0B1F3A,
    0xFF050A14,
  ], label: 'Night sky');

  static const homeDefault = _homeLightGradient;

  /// The alarm ringing default: the bundled backdrop image, scrimmed so the
  /// time and challenge text stay readable.
  static const alarmDefault = BackgroundConfig.asset(
    BackgroundAssets.alarmBackdrop,
    label: 'Alarm backdrop',
    dim: 0.45,
  );

  static const _homePresets = <BackgroundPreset>[
    BackgroundPreset(
      id: 'home_warm',
      label: 'Warm sunrise',
      config: _homeWarmGradient,
    ),
    BackgroundPreset(
      id: 'home_lake_matheson',
      label: 'Misty lake sunrise',
      config: BackgroundConfig.asset(
        BackgroundAssets.homeSunriseLakeMatheson,
        label: 'Misty lake sunrise',
        dim: 0.2,
      ),
    ),
    BackgroundPreset(
      id: 'home_misty_andes',
      label: 'Sunrise wetland',
      config: BackgroundConfig.asset(
        BackgroundAssets.homeMistySunriseLakeAndes,
        label: 'Sunrise wetland',
        dim: 0.2,
      ),
    ),
    BackgroundPreset(
      id: 'home_okanagan',
      label: 'Warm winter sunrise',
      config: BackgroundConfig.asset(
        BackgroundAssets.homeSunriseLakeOkanagan,
        label: 'Warm winter sunrise',
        dim: 0.2,
      ),
    ),
    BackgroundPreset(
      id: 'home_canary_spring',
      label: 'Canary Spring sunrise',
      config: BackgroundConfig.asset(
        BackgroundAssets.homeSunriseCanarySpring,
        label: 'Canary Spring sunrise',
        dim: 0.2,
      ),
    ),
  ];

  static const _alarmPresets = <BackgroundPreset>[
    BackgroundPreset(
      id: 'alarm_backdrop',
      label: 'Alarm backdrop',
      config: alarmDefault,
    ),
    BackgroundPreset(
      id: 'alarm_moon_01',
      label: 'Moonlit sky',
      config: BackgroundConfig.asset(
        BackgroundAssets.alarmFullMoonNight01,
        label: 'Moonlit sky',
        dim: 0.5,
      ),
    ),
    BackgroundPreset(
      id: 'alarm_moon_02',
      label: 'Full moon',
      config: BackgroundConfig.asset(
        BackgroundAssets.alarmFullMoonNight02,
        label: 'Full moon',
        dim: 0.5,
      ),
    ),
    BackgroundPreset(
      id: 'alarm_starry',
      label: 'Starry sky',
      config: BackgroundConfig.asset(
        BackgroundAssets.alarmStarrySkyTekapo,
        label: 'Starry sky',
        dim: 0.45,
      ),
    ),
  ];

  /// Image presets for a slot (used by the settings screen's image row).
  static List<BackgroundPreset> imagePresets(BackgroundSlot slot) {
    return (switch (slot) {
      BackgroundSlot.home => _homePresets,
      BackgroundSlot.alarm => _alarmPresets,
    }).where((p) => p.config.isImage).toList();
  }

  /// Solid-colour swatches offered for a slot.
  static List<BackgroundConfig> solidPresets(BackgroundSlot slot) {
    return switch (slot) {
      BackgroundSlot.home => const [
        BackgroundConfig.solid(0xFFFFF3E0, label: 'Cream'),
        BackgroundConfig.solid(0xFFFFE0B2, label: 'Peach'),
        BackgroundConfig.solid(0xFFB3E5FC, label: 'Sky'),
        BackgroundConfig.solid(0xFFC8E6C9, label: 'Meadow'),
        BackgroundConfig.solid(0xFFE1BEE7, label: 'Lilac'),
      ],
      BackgroundSlot.alarm => const [
        BackgroundConfig.solid(0xFF0B1F3A, label: 'Dark navy'),
        BackgroundConfig.solid(0xFF05070D, label: 'Near black'),
        BackgroundConfig.solid(0xFF101C33, label: 'Midnight'),
        BackgroundConfig.solid(0xFF1A1033, label: 'Deep violet'),
      ],
    };
  }

  /// Gradient swatches offered for a slot.
  static List<BackgroundConfig> gradientPresets(BackgroundSlot slot) {
    return switch (slot) {
      BackgroundSlot.home => const [
        _homeLightGradient,
        _homeWarmGradient,
        BackgroundConfig.gradient(<int>[
          0xFFFFF8E1,
          0xFFFFCC80,
          0xFFFF8A65,
        ], label: 'Golden hour'),
        BackgroundConfig.gradient(<int>[
          0xFFE1F5FE,
          0xFFB3E5FC,
          0xFF81D4FA,
        ], label: 'Morning sky'),
      ],
      BackgroundSlot.alarm => const [
        _alarmNightGradient,
        BackgroundConfig.gradient(<int>[
          0xFF1A1033,
          0xFF05070D,
        ], label: 'Violet night'),
        BackgroundConfig.gradient(<int>[
          0xFF0B1F3A,
          0xFF0E8C86,
        ], label: 'Navy teal'),
      ],
    };
  }

  /// The default configuration for a slot, used on first run and on reset.
  ///
  /// The Home default adapts to the active theme so dark mode never shows the
  /// light daylight wash behind dark cards and headings.
  static BackgroundConfig defaultFor(
    BackgroundSlot slot, {
    Brightness brightness = Brightness.light,
  }) => switch (slot) {
    BackgroundSlot.home =>
      brightness == Brightness.dark ? _homeDarkGradient : homeDefault,
    BackgroundSlot.alarm => alarmDefault,
  };
}
