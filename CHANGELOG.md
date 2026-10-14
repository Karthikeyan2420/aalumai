# Changelog

All notable changes to AALUMAI are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — First Version

Initial release of **AALUMAI (ஆளுமை)** — an offline-first personal life
management app.

### Added

- **Local-first storage** — single SQLite database (`aalumai.sqlite`) via Drift;
  no account, no cloud, no telemetry.
- **Localization** in five languages: English, Tamil, Telugu, Malayalam, Kannada.
- **Home dashboard** — today's events, due tasks, habit progress, water, next
  alarm and account balance, with **reorderable, hideable sections** and
  **real Quick Actions** (add expense/task/note, log water with undo, tick off
  habits, start a workout, jump to learning) that reorder by recency.
- **Habits** — daily / selected-weekday / weekly-target schedules, measurable
  goals, eligibility-based streaks, reminders.
- **Tasks** — priorities, due date/time, sub-tasks, tags, recurrence, reminders,
  undo on completion.
- **Schedule** — day/agenda events, all-day events, birthdays, recurring events
  with per-occurrence exceptions.
- **Notes** — notes & checklists, pinning, favourites, optional PIN lock.
- **Expenses** — accounts, income/expense/transfer transactions, categories,
  budgets with thresholds, recurring rules, debts with principal/interest
  payments, and a monthly spending-by-category chart. Money stored as integer
  paise.
- **Savings** — goals, contributions and withdrawals, progress ring.
- **Fitness** — seeded exercise library, live workout sessions with set logging,
  rest timer, personal records, plans, water logging, body measurements, a
  weight-trend chart, and GPS **run/walk tracking** (live distance, time and
  pace; saved with the route).
- **Music** — folder scanning, favourites, recently played, playlists, a
  foreground player bar with shuffle, repeat and a sleep timer, plus
  **background playback and lock-screen/media-notification controls** via
  `audio_service`.
- **Alarms** — multiple alarms, per-weekday repeat, snooze, vibrate and volume
  ramp; re-armed after reboot.
- **Meals** — weekly meal plan, recipes with ingredients, generated grocery list.
- **English learning** — 30-day Tamil→English course with grammar, vocabulary,
  quizzes, SM-2 *lite* spaced repetition, TTS and speech-to-text pronunciation.
- **Settings** — language, light/dark theme, water goal, notifications,
  backup/restore, CSV export and note lock.
- **About** — identity, version, developer, privacy statement and licences.
- **Backup** — `VACUUM INTO` snapshots, restore, and CSV transaction export.
- **Tests** — unit tests for money, recurrence, habit streaks, alarm times,
  event expansion, curriculum and dashboard ordering/visibility; in-memory
  database tests (schema, foreign keys, finance/habit/task CRUD); backup/restore
  and CSV export tests; enum-clamping safety tests; widget tests for
  localization wiring and dashboard customization.

### Known limitations

- Background/media-notification music controls are wired via `audio_service`
  but were **not runtime-verified** (no Android device) — see `BUILD_STATUS.md`.
- Android device features (alarms firing, notifications, boot re-arm, speech,
  location, launcher icons) were **not runtime-verified** in the build
  environment (no Android SDK). See `BUILD_STATUS.md`.

[1.0.0]: https://example.com/aalumai/releases/1.0.0
