# Build status

_Last updated: 2026-10-14_

This document records the **honest, verified** state of the project. Items are
marked ✅ only when they were actually executed successfully in this environment.

## Toolchain (as measured)

| Tool | Version / state |
| --- | --- |
| Flutter | 3.29.2 (stable) ✅ |
| Dart | 3.7.2 ✅ |
| OS | Windows 11 (x64) |
| Visual Studio Build Tools | 2022 17.13.3 ✅ |
| Android SDK | ❌ **not installed** (`flutter doctor`: *Unable to locate Android SDK*) |
| Android Studio | ❌ not installed |
| Chrome (web) | ✅ available |

## Verification performed

| Check | Command | Result |
| --- | --- | --- |
| Dependency resolution | `flutter pub get` | ✅ success |
| Localization generation | `flutter gen-l10n` | ✅ success |
| Drift code generation | `dart run build_runner build` | ✅ success (one harmless "duplicate orderings" info on `$AccountsTable`) |
| Launcher icons | `dart run flutter_launcher_icons` | ✅ success (icons + adaptive icons + `colors.xml`) |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Automated tests | `flutter test` | ✅ **96 tests pass** |

## Feature matrix

| Capability | Status | Notes |
| --- | --- | --- |
| Localization (5 languages) | ✅ verified | Generated + widget test across all locales. |
| Money math / formatting | ✅ verified | Unit-tested. |
| Recurrence engine | ✅ verified | Unit-tested (incl. month clamping). |
| Habit streak engine | ✅ verified | Unit-tested (eligible days/weeks, grace). |
| Alarm time computation | ✅ verified | Unit-tested. |
| Learning curriculum content | ✅ verified | Data integrity unit-tested (30 lessons). |
| Quick Actions engine | ✅ verified | Real data ops (expense/task/water/note/habit/workout/learn); water undo; recents reorder. Unit-tested ordering. |
| Dashboard customization | ✅ verified | Reorder + hide sections; persisted in preferences. Unit-tested order/visibility merge. |
| Database schema & CRUD | ✅ verified | In-memory Drift tests: table creation, FK enforcement, finance/habit/task repositories. |
| Backup & restore | ✅ verified | `VACUUM INTO` snapshot, file replace + reopen, and CSV export all tested with a fake path provider. |
| Charts | ✅ verified | `fl_chart` — current-month spending-by-category bars (Expenses) and weight-trend line (Fitness). Aggregation unit-tested; rendering not visually confirmed (no device). |
| App compiles & analyzes | ✅ verified | `flutter analyze` clean. |
| Database-backed UI by hand | ⚠️ unverified | Requires a device/emulator (see below). |
| Alarms & notifications firing | ⚠️ unverified | Needs Android device; no SDK available. |
| Boot re-arm of alarms | ⚠️ unverified | Manifest receivers added; not runtime-tested. |
| Background music playback | ⚠️ unverified | Wired to `audio_service` (foreground service + media notification in the manifest); needs an Android device to confirm. Falls back to in-process `just_audio` if init fails. |
| Music folder scanning | ⚠️ unverified | Uses `file_picker` + `READ_MEDIA_AUDIO`; not device-tested. |
| TTS / speech-to-text | ⚠️ unverified | Uses `flutter_tts` + `speech_to_text`; not device-tested. |
| Location tagging on notes | ⚠️ unverified | Uses `geolocator`; not device-tested. |
| GPS run/walk tracking | ⚠️ unverified | Live distance/time/pace from `geolocator`, saved as a workout session with an encoded route. Geo math unit-tested; live capture needs a device. |
| Backup / restore / CSV | ⚠️ partially | Logic implemented and analyzed; restore path not exercised on a device. |
| Launcher icons | ⚠️ unverified | Icons generated; not visually confirmed on a launcher. |

## Why some items are unverified

1. **No Android SDK.** `flutter doctor` cannot locate it, so no APK can be built
   or run. This blocks all device-level verification (alarms, notifications,
   permissions, background audio, speech, GPS).
2. **Windows desktop build blocked by a third-party plugin.** `flutter build
   windows` fails inside `flutter_secure_storage_windows` with
   `Cannot open include file: 'atlstr.h'` — that plugin needs the **C++ ATL for
   the latest v143 build tools** component, which is not installed in this Visual
   Studio Build Tools instance. (An earlier blocker, `flutter_tts` requiring
   `nuget.exe`, was resolved by placing `nuget.exe` on `PATH`; the build then
   progressed to the ATL error.) Both are environment/toolchain prerequisites,
   **not** application defects. Installing the ATL component (or building on a
   machine that has it) is required to produce a Windows binary.

## To verify the unverified items

On a machine with the Android SDK + a device/emulator:

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter run            # or: flutter build apk --release
```

Then walk through the manual smoke test in
[`docs/TESTING.md`](docs/TESTING.md#not-covered-and-why).

## Summary

The project **compiles, analyzes cleanly, and passes its automated tests**. The
gaps above are **environmental** (missing Android SDK / missing `nuget.exe`) or
**explicitly scoped** (foreground-only audio), not known code defects. No claim
is made that device-only features work until they are run on a device.
