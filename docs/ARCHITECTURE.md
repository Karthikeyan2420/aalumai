# Architecture

AALUMAI is a single Flutter application organised around three ideas:

1. **Offline-first.** SQLite (via Drift) is the source of truth. Every screen
   watches reactive query streams, so the UI updates the moment data changes.
2. **Feature isolation.** Each module owns its own repository and screens and
   depends only on the shared `core/` layer and its own `data/` + `domain/`
   code.
3. **Testable core.** Anything that can be pure (money, recurrence, streaks,
   alarm times, curriculum data) is kept free of Flutter/plugin dependencies.

---

## Layers

```
┌───────────────────────────────────────────────────────────────┐
│  UI (features/*/*_screen.dart, editors, widgets)               │
│  ConsumerWidget / ConsumerStatefulWidget — reads providers      │
└───────────────▲───────────────────────────────────────────────┘
                │ ref.watch(streamProvider)
┌───────────────┴───────────────────────────────────────────────┐
│  Repositories (features/*/data/*_repository.dart)              │
│  Wrap AppDatabase; expose Streams + command methods            │
└───────────────▲───────────────────────────────────────────────┘
                │ drift queries
┌───────────────┴───────────────────────────────────────────────┐
│  AppDatabase (core/db) — Drift over native SQLite (aalumai.sqlite)│
└───────────────────────────────────────────────────────────────┘

Cross-cutting (core/): providers, router, theme, localization,
notifications, backup, preferences, utils.
```

### State management

- **Riverpod** providers are the only state mechanism.
- The database is exposed via `appDatabaseProvider` (a `Provider<AppDatabase>`),
  kept alive for the app's lifetime.
- Repositories are exposed via `Provider`s (e.g. `financeRepositoryProvider`).
- UI state is exposed as `StreamProvider`s that call repository `watchX()`
  methods.
- Ephemeral UI state (form fields, timers) stays in `StatefulWidget` state.

### Navigation

`go_router` with a `StatefulShellRoute.indexedStack` gives five persistent
bottom-navigation branches (Home, Schedule, Tasks, Fitness, More). Secondary
modules (Expenses, Music, Alarms, Habits, Notes, Savings, Meals, Learning,
Settings, About) are top-level routes pushed over the shell.

### Dependency inversion for tests

`sharedPreferencesProvider` is overridden at startup with a real
`SharedPreferences` instance (see `main.dart`), and can be overridden in tests
with a fake. `AppDatabase.forTesting(executor)` allows an in-memory executor.

---

## Startup sequence (`lib/main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `initializeDateFormatting()` so non-English date locales render.
3. `AudioService.init(...)` to create the background music handler (`null` if
   it fails, in which case music plays in-process).
4. Load `SharedPreferences` and build a `ProviderContainer` with it and the
   audio handler overridden.
5. **Best-effort bootstrap** (each step wrapped in `try/catch` so a plugin or DB
   hiccup never blocks launch):
   - `financeRepository.seedDefaultCategories()`
   - `fitnessRepository.seedExercises()`
   - `learningRepository.seedCourse()`
   - `notificationService.init()` (+ request permission if enabled)
   - `alarmRepository.reconcile()` — re-arm scheduled alarms.
6. `runApp(UncontrolledProviderScope(container: container, child: AalumaiApp()))`.

---

## Repositories

Every repository follows the same shape:

- Constructor takes `AppDatabase` (and a `Ref` when it needs other providers).
- `watchX()` / `xProvider` return Drift `.watch()` streams.
- Mutations are `Future` command methods (`addX`, `updateX`, `deleteX`, ...).
- Money is always passed around as integer **paise**; use `Money` helpers.

Examples:

| Repository | Notable behaviour |
| --- | --- |
| `FinanceRepository` | Seeds default categories; accounts, transactions (income/expense/**transfer**), budgets, debts, recurring rules; balances computed from opening balance + transaction effects. |
| `HabitRepository` | Records completions keyed by normalised day; streaks via `HabitStreak`. |
| `FitnessRepository` | Seeds the exercise library; workout sessions, set logs, PRs, water, measurements. |
| `AlarmRepository` | Persists alarms and, on `reconcile()`, (re)schedules the OS notifications. |
| `LearningRepository` | Seeds the 30-lesson course; derives quiz questions from vocabulary; SM-2 *lite* spaced repetition. |
| `MusicRepository` | Scans folders for audio files, keeps a `countMissingFiles()` check (rows are retained so playlists survive), favourites, recents, playlists. |
| `RunTrackerController` | Streams `geolocator` positions for a run/walk, accumulates distance/pace (`domain/geo.dart`), and saves the finished session via `FitnessRepository.finishSession`. |
| `BackupService` | `exportBackup()` (`VACUUM INTO`), `listBackups()`, `restore(File)` (close → swap file → invalidate `appDatabaseProvider`), `transactionsCsv()`. |

---

## Cross-cutting services

- **`NotificationService`** — wraps `flutter_local_notifications` + `timezone`.
  All methods are best-effort and no-op on unsupported platforms. Exposes
  `init()`, `requestPermissions()`, `canScheduleExactAlarms()`,
  `scheduleAlarm()`, `cancelAlarm()`, `scheduleReminder()`, `reconcile()`.
- **`BackupService`** — snapshot, restore and CSV export.
- **`AppPreferences`** — typed access to `SharedPreferences` (locale, theme,
  first-run flag, notification/water/workout-music settings, last backup time).
- **`LockService`** — hashed note PIN in the platform secure store.

---

## Pure utilities (`core/utils/`)

These have no Flutter dependency and are unit-tested:

- `Money` — paise ⇄ rupees, locale-aware formatting.
- `Recurrence` — `FREQ=…;INTERVAL=n` parse/encode and `next()` with month-length
  clamping.
- `AlarmTime` — next fire time from hour/minute/repeat-mask and 12/24h formatting.
- `HabitStreak` — eligible-day and eligible-week streak calculations.

---

## Error handling philosophy

- Startup steps are individually guarded — the app must always reach the UI.
- Platform plugins are treated as optional; failures surface as honest snackbars
  (e.g. "microphone permission denied") rather than crashes.
- Android-only facilities that cannot run elsewhere (notifications, exact
  alarms, background audio, TTS, speech-to-text, file pickers) are documented as
  **unverified** wherever they could not be exercised — see `BUILD_STATUS.md`.
