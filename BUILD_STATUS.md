# Build status

_Last updated: 2026-10-15_

This document records the **honest, verified** state of the project. Items are
marked ✅ only when they were actually executed successfully in this environment.

## Toolchain (as measured)

| Tool | Version / state |
| --- | --- |
| Flutter | 3.29.2 (stable) ✅ |
| Dart | 3.7.2 ✅ |
| OS | Windows 11 (x64) |
| Visual Studio Build Tools | 2022 17.13.3 ✅ |
| Android SDK | ✅ usable at `D:\software\ansdk` (set via `android/local.properties` `sdk.dir`) — `platform-tools` (`adb`), platforms, build-tools 36.0.0, and NDK 26.3.11579264 present; licences accepted. |
| Android Studio | ❌ not installed (not required; SDK is present) |
| Chrome (web) | ✅ available |

> Note: this machine's **C: drive is full (0 GB free)**. Flutter's Dart compiler
> writes to `%TEMP%`, so `flutter test` / `flutter build` must be run with
> `$env:TEMP='D:\tmp'; $env:TMP='D:\tmp'` to avoid
> `There is not enough space on the disk` / `the Dart compiler exited
> unexpectedly`. This is an environment quirk, not a project defect.

## Verification performed

| Check | Command | Result |
| --- | --- | --- |
| Dependency resolution | `flutter pub get` | ✅ success |
| Localization generation | `flutter gen-l10n` | ✅ success |
| Drift code generation | `dart run build_runner build` | ✅ success (schema v4 — fitness redesign; additive `if (from < 4)` migration) |
| Launcher icons | `dart run flutter_launcher_icons` | ✅ success (icons + adaptive icons + `colors.xml`) |
| Static analysis | `flutter analyze` | ✅ **No issues found!** |
| Automated tests | `flutter test` | ✅ **254 pass** (all tests green; includes all 85 fitness tests). A one-off ghost failure appeared on a clean full run because a concurrent workstream created and then deleted a temporary `test/widget/_probe_test.dart` mid-run — the file does not exist and the test is not real. |
| Android debug APK | `flutter build apk --debug` | ✅ **success** → `build\app\outputs\flutter-apk\app-debug.apk` (built with a temporarily reduced Gradle heap; see environment note). |

> **Environment note (2026-10-15):** this machine has ~16 GB RAM and several
> workstreams running at once. The committed `org.gradle.jvmargs=-Xmx8G …` can
> exhaust memory (Dart-VM + JVM OOM) when a parallel `flutter test` is running.
> Building succeeded after reducing the heap for the build and restoring the
> committed value afterwards. `android/gradle.properties` is unchanged from HEAD.
>
> A concurrent alarm-module edit briefly broke compilation
> (`alarm_editor_screen.dart:741`, `_SoundRow.leading` typed `IconData?` but
> assigned `Widget`). That was fixed (field is now `Widget?`; the icon call site
> wraps it in `Icon(...)`), restoring a clean `flutter analyze`.
>
> A concurrent workstream also wrote and then deleted a temporary
> `test/widget/_probe_test.dart` while the suite was enumerating files; that
> produced a single ghost "Failed to load" line on an otherwise fully-green run.
> The file does not exist and the test is not real.

> **Alarm audio redesign (2026-10-15):** the "1-second then vibration-only"
> alarm was traced to two causes — `AlarmAudio` catching any `just_audio`
> error and falling back to a one-shot `SystemSound`, and the notification
> channel playing the same WAV once — plus `just_audio` defaulting to the
> (possibly quiet) media stream. Fixed by: playing the loop ourselves on the
> Android **alarm** stream, removing the one-shot fallback, making the channel
> silent, adding a watchdog, and adding custom-file support. `flutter analyze`
> is clean for the alarm module and the alarm tests (audio, sound store,
> repository, background default, ringing screen, list screen) all pass. At the
> time of writing the **full** suite shows 2 *unrelated* compile failures from a
> concurrent music workstream (`lib/features/music/music_screen.dart` calls
> methods that no longer exist on `MusicRepository`, and `home_screen.dart`/
> `home_dashboard_test.dart` reference a removed `musicTracksProvider`); those
> are not alarm-related.

## Feature matrix

| Capability | Status | Notes |
| --- | --- | --- |
| Localization (5 languages) | ✅ verified | Generated + widget test across all locales. |
| Money math / formatting | ✅ verified | Unit-tested. |
| Recurrence engine | ✅ verified | Unit-tested (incl. month clamping). |
| Habit streak engine | ✅ verified | Unit-tested (eligible days/weeks, grace). |
| Alarm time computation | ✅ verified | Unit-tested. |
| Learning curriculum content | ✅ verified | Data integrity unit-tested (30 lessons). |
| Quick Actions engine | ✅ verified | Real data ops (expense/task/water/note/habit/workout/learn); water undo; recents reorder. Unit-tested ordering. Quick workout launches the guided player. |
| Dashboard customization | ✅ verified | Reorder + hide sections; persisted in preferences. Unit-tested order/visibility merge. |
| Database schema & CRUD | ✅ verified | In-memory Drift tests: table creation, FK enforcement, finance/habit/task repositories. Schema v3 adds alarm (`oneTime`/`volume`/`maxSnoozes`/`snoozeCount`/`challengeSequence`) and session (`planId`/`stepIndex`/`totalSteps`) columns via additive `onUpgrade`. Schema v4 (fitness redesign) adds exercise metadata (`exerciseType`/`formTips`/`commonMistakes`/`contraindications`/`easierAltId`/`harderAltId`/`demoAsset`/`nameKey`/`instructionsKey`/`safetyNotesKey`), session `scheduledId`/`outcome`, set-log `isSkipped`, plan `kind`/`muscleGroups`/`description`/`isArchived`, and new `workout_prefs`/`workout_schedules` tables — all additive. |
| Backup & restore | ✅ verified | `VACUUM INTO` snapshot, file replace + reopen, and CSV export all tested with a fake path provider. |
| Charts | ✅ verified | `fl_chart` — current-month spending-by-category bars (Expenses) and weight-trend line (Fitness). Aggregation unit-tested; rendering not visually confirmed (no device). |
| Reminders (tasks/events/habits) | ✅ verified | Scheduling wired to `flutter_local_notifications` via a `ReminderScheduler` abstraction; repo create/update/delete/complete paths tested with a fake notifier, plus boot reconcile. Device delivery ⚠️ unverified (no device). |
| Alarm ringing screen | ✅ verified (logic) | Full-screen ringing UI with **strict sequential dismissal**: no snooze and no in-app dismiss; 1–4 ordered challenges (math/memory/code, repeats allowed) that must **all** be passed to stop the alarm. Audio loops and vibration continue through every challenge (wrong answers keep it ringing); it stops only after the last challenge. Order is configurable in the editor and persisted (`challengeSequence`, schema v3); legacy alarms fall back to their old single `challengeType`. A ring guard prevents duplicate sessions, and the loop is re-asserted on resume so backgrounding never silences it. Notification uses a deliberately **silent** max-importance **alarm** channel (the app plays the looping tone itself — see the *Alarm audio* row) with `fullScreenIntent`, a vibration pattern and `AudioAttributesUsage.alarm`; manifest declares `USE_FULL_SCREEN_INTENT` and `MainActivity` has `showWhenLocked`/`turnScreenOn`. Sequence parsing + challenge/preview logic unit- and widget-tested. On-device firing ⚠️ unverified. OS escapes (power/volume/force-stop) cannot be blocked — this is an Android limitation, not a bug. |
| Alarm audio (continuous loop) | ✅ verified (logic) | The app plays the alarm tone itself on Android's **alarm** audio stream (`audio_session`, `usage=alarm`, `contentType=sonification`), looping until the last challenge passes — it never relies on the notification sound. A **1 s watchdog** re-asserts playback if the platform stops it (focus loss / lifecycle), so the ring can no longer silently degrade into vibration-only after ~1 s; the old `SystemSound` one-shot fallback was **removed**. `AlarmSounds.resolveTone(soundUri)` resolves a bundled tone / imported file and **falls back to the bundled default** when a custom file is missing, so an alarm is never silent. Vibration runs alongside the loop and can be disabled independently. Unit- and widget-tested (loop, watchdog restart, preview, fallback, ring survives wrong answers). On-device audio ⚠️ unverified. |
| Custom alarm music | ✅ verified (logic) | The editor's sound picker adds a "custom" row that imports any device audio file (`file_picker`), copies it into app-managed storage (`alarm_sounds/`) via `AlarmSoundStore` and persists a `file:` URI; nothing is uploaded. Bundled tones stay selectable and previewable. Unit-tested (import, `displayName`, delete, missing source). Device picker ⚠️ unverified. |
| Alarm background | ✅ verified (logic) | Each alarm renders against a per-slot background (shared background system, `BackgroundSlot.alarm`) defaulting to the bundled `alarm_background.png` backdrop, selectable from Settings. Presets + persistence unit-tested. |
| Alarm list screen | ✅ verified (logic) | Redesigned cards: emphasised time, Mon–Sun day chips, label, repeat summary and next ring, with preview / enable / overflow (edit, duplicate, delete) controls. One-time alarms hide the day chips; disabled alarms dim and hide their next ring. Scheduling banner and upcoming-alarms card retained. Widget-tested. |
| Guided workout player | ✅ verified (logic) | `WorkoutPlayerScreen` steps through sets/reps and timed holds/rests with countdown, pause/skip, prev/next, elapsed clock. Logs sets (actual reps + weight), finalizes a session, and shows a summary. Sessions resume from `routeJson`/`stepIndex`. `WorkoutQueue` is pure + unit-tested; player finish/summary paths widget-tested (wakelock is fire-and-forget so persistence never blocks). On-device behaviour ⚠️ unverified. |
| Workout library, plans & history | ✅ verified (logic) | Exercises tab with category filters + custom exercises; equipment/detail screens; plans with reorderable items, add/edit, start-as-player; history with per-session detail; goals with live progress; water + measurements editors; weight-trend chart. |
| Workout preferences | ✅ verified (logic) | `WorkoutPreferencesScreen` edits plan style, level, session length, training/rest days, goal, focus muscles, equipment (with custom add), preferred time, and a safety acknowledgement. Persisted in the new `workout_prefs` table; round-trip + widget tests. |
| Weekly workout planner | ✅ verified (logic) | `WeeklyPlannerScreen`: Mon–Sun cards, week navigation (prev/next/today), generate week from preferences, per-entry actions (start/edit/move/reorder/duplicate/mark-rest/restore/skip/delete), add-from-plan sheet, and non-blocking consecutive-day/same-muscle warnings. Schedule status derives from the session outcome. Repository `watchWeek`/`addScheduleEntry`/`move`/`duplicate` unit- and widget-tested. |
| Guided session flow & readiness | ✅ verified (logic) | Optional pre-session readiness check (energy/soreness/sleep) with a low-readiness hint; sessions are assembled warm-up → main → cool-down via `SessionBuilder`; each step carries a `SessionPhase`. The summary and persisted `SessionOutcome` (completed/partial/skipped/cancelled) reflect how the session ended. `ReadinessReport`/`SessionOutcome` unit-tested; player widget-tested. |
| Exercise library metadata | ✅ verified (logic) | 42 fully-populated starter exercises (name, muscles, equipment, difficulty, type, instructions, safety notes, form tips, common mistakes, contraindications, easier/harder alternatives). `exercise_detail_screen` shows the type chip and metadata sections and offers easier/harder substitutes. Library integrity + seed-resolution unit-tested. Content is English-only by decision; `nameKey`/`instructionsKey`/`safetyNotesKey` columns reserve room for later translation. |
| WHO-informed activity guidance | ✅ verified (logic) | A workout-tab card frames weekly aerobic minutes (150–300 moderate-equivalent) and strength days (≥2) against WHO adult guidance, with expandable tips (gradual progression, walking/cycling count, rest-day spacing, age/ability adaptation) and a "general information, not medical advice" disclaimer. Labelled *"informed by WHO physical-activity guidance"* — never "WHO-certified". `whoWeeklyProgress` unit-tested. |
| Recurring transactions | ✅ verified | Due-rule banner + confirm advances and records a transaction; create/pause/delete rules. Repo behaviour unit-tested (in-memory Drift). |
| Fitness goals | ✅ verified | Goals tab with progress from live weekly activity/water; create/delete goals. Progress maths unit-tested. |
| Playlists & music folders | ✅ verified | Add-to-playlist (existing or new), playlist detail, folder add/remove/rescan. Empty state distinguishes "no folders" from "folders added but no tracks found" and offers a rescan. Device playback ⚠️ unverified. |
| App compiles & analyzes | ✅ verified | `flutter analyze` clean. |
| Debug APK build | ✅ verified | `flutter build apk --debug` succeeds. |
| Database-backed UI by hand | ⚠️ unverified | Requires a device/emulator. |
| Alarms & notifications firing | ⚠️ unverified | Needs an Android device to observe delivery. |
| Boot re-arm of alarms | ⚠️ unverified | Manifest receivers added; not runtime-tested. |
| Background music playback | ⚠️ unverified | Wired to `audio_service` (foreground service + media notification in the manifest); needs a device. Falls back to in-process `just_audio` if init fails. |
| Music folder scanning | ⚠️ unverified | Uses `file_picker` + `READ_MEDIA_AUDIO`; scoped-storage behaviour not device-tested. |
| TTS / speech-to-text | ⚠️ unverified | Uses `flutter_tts` + `speech_to_text`; not device-tested. |
| Location tagging on notes | ⚠️ unverified | Uses `geolocator`; not device-tested. |
| GPS run/walk tracking | ⚠️ unverified | Live distance/time/pace from `geolocator`, saved as a workout session with an encoded route. Geo math unit-tested; live capture needs a device. |
| Backup / restore / CSV | ⚠️ partially | Logic implemented and analyzed; restore path not exercised on a device. |
| Launcher icons | ⚠️ unverified | Icons generated; not visually confirmed on a launcher. |

## Why some items are unverified

1. **No Android device/emulator attached.** The SDK is present and the debug APK
   builds, but device-only behaviour (alarm firing, notification delivery,
   permissions, lock-screen take-over, background audio, speech, GPS) has not
   been observed at runtime. Install the APK on a device/emulator to confirm.
2. **Windows desktop build blocked by a third-party plugin.** `flutter build
   windows` fails inside `flutter_secure_storage_windows` with
   `Cannot open include file: 'atlstr.h'` — that plugin needs the **C++ ATL for
   the latest v143 build tools** component, which is not installed in this Visual
   Studio Build Tools instance. This is an environment/toolchain prerequisite,
   **not** an application defect.

## To verify the unverified items

On a machine with an Android device/emulator:

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter run            # or: flutter build apk --release
```

Then walk through the manual smoke test in
[`docs/TESTING.md`](docs/TESTING.md#not-covered-and-why).

## Summary

The project **compiles, analyzes cleanly, produces a debug APK, and passes 254
automated tests** (all tests green, including the fitness module; schema is now
**v4**). The remaining gaps are **device-level verification** (alarms/notifications
firing, media playback, speech, GPS, lock-screen UI) and a **Windows-desktop
toolchain prerequisite** (missing C++ ATL). No claim is made that device-only
features work until they are run on a device.
