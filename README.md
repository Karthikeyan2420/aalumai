# AALUMAI (ஆளுமை)

**Your life. Your control.** · *உங்கள் வாழ்க்கை. உங்கள் கட்டுப்பாடு.*

AALUMAI is an **offline-first personal life management app** for Android (with a
Windows desktop target for development). It bundles the daily tools people
usually need a dozen apps for — habits, tasks, calendar, notes, money, savings,
debts, fitness, water, body measurements, music, alarms, meal planning and an
English-learning course — into **one private app that keeps all of its data on
your device**.

There is no account, no cloud sync and no telemetry. Everything lives in a local
SQLite database.

---

## Table of contents

- [Feature overview](#feature-overview)
- [Architecture at a glance](#architecture-at-a-glance)
- [Project layout](#project-layout)
- [Getting started](#getting-started)
- [Data, backup & privacy](#data-backup--privacy)
- [Localization](#localization)
- [Testing](#testing)
- [Build status & known limitations](#build-status--known-limitations)
- [Documentation index](#documentation-index)

---

## Feature overview

| Module | Highlights |
| --- | --- |
| **Home / Dashboard** | Daily overview: today's events, due tasks, habit progress, water, next alarm, account balance. Reorderable/hideable sections and one-tap Quick Actions. |
| **Habits** | Daily / selected-weekday / weekly-target schedules, measurable goals, streak engine computed from *eligible scheduled days*, reminders. |
| **Tasks** | Priorities, due date + time, sub-tasks, tags, recurrence, reminders, undo on complete. |
| **Schedule (Calendar)** | Day/agenda events, all-day events, birthdays, recurrence with per-occurrence exceptions. |
| **Notes** | Notes / checklists, pinning, favourites, and optional PIN-locked notes. |
| **Expenses** | Multiple accounts, income/expense/transfer transactions, categories, budgets with thresholds, recurring rules, debts with principal/interest payments, and a monthly spending-by-category chart. Money is stored as integer **paise**. |
| **Savings** | Goals with target amounts & dates, contributions and withdrawals, progress ring. |
| **Fitness** | Seeded exercise library (~50 exercises), live workout sessions with set logging, rest timer, personal records, workout plans, water logging, body measurements, a weight-trend chart, and GPS run/walk tracking. |
| **Music** | Folder scanning, favourites, recently played, playlists, a player bar with shuffle/repeat, a sleep timer, and background playback with lock-screen/media controls. |
| **Alarms** | Multiple alarms, per-weekday repeat, label, snooze, vibrate and volume ramp. Re-armed on boot. |
| **Meals** | Weekly meal plan, recipes with ingredients, and an auto-generated grocery list. |
| **English Learning** | A 30-day Tamil→English course with grammar notes, vocabulary, quizzes, spaced-repetition review (SM-2 *lite*), text-to-speech and speech-to-text pronunciation practice. |
| **Settings** | Language, light/dark theme, water goal, notifications, backup/restore, CSV export, note lock. |
| **About** | App identity, version, developer, privacy statement and open-source licences. |

---

## Architecture at a glance

- **Flutter** (Material 3) with **Riverpod** for state and **go_router** for
  navigation.
- **Drift** (SQLite) for persistence; all repositories expose reactive `Stream`s
  that the UI watches.
- A thin `core/` layer holds the database, theme, router, localization,
  notifications, backup, and dependency-free utilities.
- A `features/` layer holds one folder per module, each with its own
  `data/` (repository), `domain/` (pure logic) and screen widgets.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full breakdown.

---

## Project layout

```
lib/
├── main.dart                 # bootstrap: seed data, init services, run app
├── app.dart                  # MaterialApp, theme, locale, routing
├── core/
│   ├── db/                   # Drift database, tables, generated code
│   ├── localization/         # ARB sources + generated AppLocalizations
│   ├── preferences/          # SharedPreferences-backed settings
│   ├── providers/            # cross-cutting providers (db, prefs, ...)
│   ├── router/               # go_router configuration
│   ├── services/             # notifications, backup/restore/CSV
│   ├── shell/                # bottom-navigation shell
│   ├── theme/                # light & dark Material themes
│   ├── utils/                # money, recurrence, alarm-time helpers
│   └── widgets/              # shared UI widgets
└── features/                 # one directory per module
```

---

## Getting started

Requirements: Flutter 3.29+ / Dart 3.7+, and (for Android) the Android SDK.

```bash
flutter pub get

# Regenerate localizations after editing *.arb
flutter gen-l10n

# Regenerate Drift code after changing tables.dart
dart run build_runner build

# Regenerate launcher icons
dart run flutter_launcher_icons

# Static analysis + tests
flutter analyze
flutter test

# Run
flutter run                # on a connected device/emulator
flutter build apk --release
```

---

## Data, backup & privacy

- The database file is `aalumai.sqlite` in the app documents directory.
- **Backup** exports a consistent snapshot using SQLite `VACUUM INTO`, stored in
  the documents directory.
- **Restore** replaces the live database with a chosen backup (the app closes the
  database, copies the file over, and invalidates the provider so the UI reloads).
- **CSV export** writes all transactions to `aalumai_transactions.csv`.
- **Note lock** stores a hashed PIN in the platform secure store
  (`flutter_secure_storage`).

See [`docs/PRIVACY_AND_PERMISSIONS.md`](docs/PRIVACY_AND_PERMISSIONS.md) for the
full permission list and rationale.

---

## Localization

The UI ships in **five languages**: English (`en`), Tamil (`ta`), Telugu (`te`),
Malayalam (`ml`) and Kannada (`kn`). Translations are maintained as ARB files in
`lib/core/localization/l10n/`, with generated Dart in
`lib/core/localization/generated/`. Use `context.l10n` in widgets.

See [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md).

---

## Testing

Pure logic (money, recurrence, habit streaks, alarm times, curriculum content,
localization wiring) is covered by unit/widget tests under `test/`. Run
`flutter test`.

See [`docs/TESTING.md`](docs/TESTING.md) for what is and isn't covered.

---

## Build status & known limitations

The app **analyzes cleanly** (`flutter analyze` → *No issues found*) and **all
tests pass**. See [`BUILD_STATUS.md`](BUILD_STATUS.md) for the current, honest
state of each capability — including items that could **not** be verified in the
development environment (no Android SDK; Windows build blocked by a
`nuget.exe` requirement in a third-party plugin).

---

## Documentation index

| Document | Contents |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, state flow, repositories. |
| [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | Every table and column. |
| [`docs/TESTING.md`](docs/TESTING.md) | Test strategy and coverage. |
| [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md) | Adding/editing languages. |
| [`docs/PRIVACY_AND_PERMISSIONS.md`](docs/PRIVACY_AND_PERMISSIONS.md) | Privacy model and Android permissions. |
| [`BUILD_STATUS.md`](BUILD_STATUS.md) | Verified / unverified feature matrix. |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history. |
