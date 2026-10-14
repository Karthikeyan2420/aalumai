# Testing

AALUMAI is validated with **static analysis** and an automated test suite.

```bash
flutter analyze      # must report "No issues found!"
flutter test         # all tests must pass
```

## Strategy

The test suite deliberately focuses on **pure, deterministic logic** — the parts
most likely to hide bugs (streaks, recurrence, money, alarm timing) — plus a
widget test that proves the localization stack is wired correctly. This keeps the
suite fast and free of platform plugins.

| Area | File | What it verifies |
| --- | --- | --- |
| Money | `test/unit/money_test.dart` | Rupee⇄paise conversion without FP drift; currency formatting. |
| Recurrence | `test/unit/recurrence_test.dart` | Parse/encode round-trips, interval clamping, `next()` for daily/weekly/monthly (month clamping)/yearly. |
| Habit streaks | `test/unit/habit_streak_test.dart` | Eligible-day checks, current day streak (incl. grace for today), week streak, best week streak, `startOfWeek`, enum clamping. |
| Event expansion | `test/unit/event_repository_test.dart` | Non-recurring in/out-of-range, daily expansion count + preserved duration, cancelled occurrences dropped, moved occurrences, sort order. |
| Enum safety | `test/unit/enum_index_test.dart` | `fromIndex` clamps out-of-range values for every persisted enum. |
| Alarm times | `test/unit/alarm_time_test.dart` | Next fire time (today/tomorrow/weekday mask), weekday decoding, 12/24-hour formatting. |
| Curriculum | `test/unit/curriculum_test.dart` | 30 sequential lessons with complete content; grammar JSON encode/decode + graceful failure. |
| Dashboard config | `test/unit/dashboard_sections_test.dart` | Section-key parsing, order merge with unknown/duplicate keys, hidden filtering. |
| Player state | `test/unit/player_state_test.dart` | `current` bounds, `copyWith` field preservation and error clearing. |
| Geo / run tracking | `test/unit/geo_test.dart` | Haversine distance, jitter-filtered path length, pace, distance/duration formatting, `GeoPoint` JSON round-trip. |
| Database | `test/unit/database_test.dart` | In-memory Drift: table creation, FK enforcement, finance balances/transfers/aggregates/recurring/debt rules, habit completion, task recurrence. |
| Backup / restore | `test/unit/backup_service_test.dart` | `VACUUM INTO` snapshot, restore + reopen, CSV export (uses a fake path provider). |
| Localization | `test/widget_test.dart` | `AppLocalizations` resolves for every supported locale. |
| Dashboard UI | `test/widget/dashboard_config_test.dart` | Every section listed; toggling a switch persists the hidden set. |

Run a single file:

```bash
flutter test test/unit/habit_streak_test.dart
```

## Not covered (and why)

The following are intentionally **not** covered because they require a device,
emulator, or host-only native libraries that are unavailable in this
environment:

- **Plugin behaviour:** local notifications / exact alarms, `just_audio`
  playback, `flutter_tts`, `speech_to_text`, `file_picker`, `geolocator`,
  `flutter_secure_storage`, `package_info_plus`.
- **Android-specific flows:** boot re-arm of alarms, runtime permission dialogs,
  launcher-icon rendering.

Database integration tests **do** run here: Drift's native `sqlite3` library is
loadable in the host test VM on this machine, so `test/unit/database_test.dart`
and `test/unit/backup_service_test.dart` exercise the real schema and SQL.

These are tracked as **unverified** in [`../BUILD_STATUS.md`](../BUILD_STATUS.md).
On a machine with an Android SDK and a device/emulator, the recommended manual
smoke test is:

1. Complete language setup; confirm the UI switches languages.
2. Add a habit, complete it a few days in a row, confirm the streak.
3. Add an income/expense/transfer; confirm balances and budgets.
4. Start a workout; log sets; confirm PRs.
5. Create an alarm 1 minute ahead; lock the screen; confirm it fires.
6. Add a music folder; play a track; test shuffle/repeat/sleep timer.
7. Export a backup, add data, then restore the backup and confirm rollback.
