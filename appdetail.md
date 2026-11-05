# AALUMAI — application details

**ஆளுமை · AALUMAI**  
Tagline: *Your life. Your control.* / *உங்கள் வாழ்க்கை. உங்கள் கட்டுப்பாடு.*

| | |
| --- | --- |
| Package | `aalumai` |
| Version | `1.0.0+1` (First Version) |
| Developer | Karthikeyan Asaithambi |
| Platform | Android (primary); Flutter also targets Windows for development |
| Stack | Flutter, Material 3, Riverpod, go_router, Drift (SQLite) |
| Languages | English, Tamil, Telugu, Malayalam, Kannada |
| Data model | Offline-first. No account. No cloud sync. No telemetry. |

AALUMAI is a personal life-management app. It puts habits, tasks, calendar, notes, money, savings, meals, fitness, music, alarms, English learning, and a local assistant into one app that stores data on the device.

---

## What the app is for

People who want one private place for daily life instead of a dozen cloud apps. Typical use:

- See today at a glance (events, tasks, habits, water, steps, next alarm, money).
- Plan and track work, health, and money without creating an account.
- Back up the local database and restore it later.

---

## Navigation

Bottom bar (main shell):

1. **Home** — dashboard
2. **Schedule** — calendar
3. **Tasks**
4. **Fitness**
5. **More** — expenses, savings, meals, habits, learning, alarms, music, notes, Jarvis, settings, about

First launch shows a welcome screen (language and branding). After that, the app opens on Home.

---

## Modules

### Home

- Sections for today’s events, due tasks, habit progress, water, next alarm, balance, fitness/watch snippets.
- Sections can be shown, hidden, and reordered.
- Quick actions: expense, task, water, note, habit, workout, learn. Recently used actions move up.

### Schedule

- Day and agenda events, all-day events, birthdays.
- Recurrence with exceptions for single occurrences.

### Tasks

- Priority, due date and time, sub-tasks, tags, recurrence, reminders.
- Filters: today, upcoming, overdue, completed, all.
- Undo after completing a task.

### Habits

- Daily, selected weekdays, or weekly targets.
- Measurable goals and streaks counted from scheduled days (not every calendar day).
- Reminders.

### Notes

- Notes and checklists, pin, favourite.
- Optional PIN lock. The PIN hash is stored in the platform secure store, not in SQLite.

### Expenses

- Multiple accounts.
- Income, expense, and transfer.
- Categories, budgets with thresholds, recurring rules.
- Debts with principal and interest payments.
- Monthly spending-by-category chart.
- Amounts stored as integer **paise**.
- CSV export of transactions.

### Savings

- Goals with target amount and date.
- Contributions and withdrawals.
- Progress toward the goal.

### Meals

- Weekly meal plan.
- Recipes with ingredients.
- Grocery list generated from the plan.

### Fitness

- Exercise catalogue (bundled library, 1000+ moves with GIF demos cached on disk).
- Gym-style module: Daily, 30-day plan, Workout, Me.
- Daily template: about 10 minutes of stretch, then a weekday focus (shoulders, chest, back, arms, legs, core, Sunday mix).
- Session length 30 / 60 / 90 / 120 minutes, with sets, reps, and rest sized to that length.
- Onboarding: gender, focus areas, level, height, weight.
- Workout player: sets, rest timer, screen stay-awake.
- Water log, body measurements, weight trend.
- Yoga screen and GPS run/walk with an OpenStreetMap track (no map API key).
- Watch / Health Connect: steps and health samples (heart rate, SpO2, sleep) when the user grants access. BLE discovery is present for compatible watches (for example Fire-Boltt / Da Fit via Health Connect).

### Music

- Scan on-device audio.
- Folders, favourites, collections, recently played.
- Player with shuffle, repeat, sleep timer, background playback, and media controls.

### Alarms

- Multiple alarms, weekday repeat, label, snooze, vibrate, volume ramp.
- Re-armed after reboot.
- Optional spoken alarm (TTS) from alarm voice settings.

### English learning

- Structured course (Tamil-oriented English practice): grammar, vocabulary, quizzes.
- Spaced review (SM-2 style lite).
- Text-to-speech and speech-to-text pronunciation practice.

### Jarvis

- On-device assistant: chat, settings, and memories.
- Answers from local data (tasks, events, alarms, memories).
- Optional online lookup only when the user turns that on and the question is outside local knowledge.
- There is no large language model inside the app.

### Settings and about

- Language, light / dark / system theme, home and alarm backgrounds.
- Water goal, workout music, notifications.
- Backup and restore of the SQLite file, CSV export, note lock.
- About: version, developer, privacy statement, licences.

---

## Design

- One Material 3 theme (`AppTheme`): navy, teal, gold.
- Each module has its own accent colour so cards stay recognisable.
- Fitness uses the same app theme (light or dark) as the rest of the app, with teal as the fitness accent.
- Shared pieces: `AppCard`, section headers, module headers, day progress ring, streak badge.

---

## How it is built

```
lib/
  main.dart          bootstrap, seed data, notifications, audio
  app.dart           MaterialApp, locale, theme
  core/              database, theme, router, l10n, backup, notifications
  features/          one folder per module (data, domain, screens)
```

- Repositories expose Drift streams. Screens watch those streams with Riverpod.
- Database file: `aalumai.sqlite` in the app documents directory.
- Backup uses SQLite `VACUUM INTO`. Restore replaces the live file and reloads the database.
- Schema changes are versioned migrations in Drift (current work includes plan-item rest time).

---

## Privacy and permissions

- No account and no analytics SDK in the product design.
- Data stays on the device unless the user exports a backup, a CSV, or turns on an optional online answer in Jarvis.
- Android permissions are requested only for features that need them: notifications and exact alarms, storage/audio for music, location for run/walk, Health Connect / Bluetooth for watch data, microphone for speech practice.
- Exercise GIFs and yoga pose images are downloaded when those features are used. Map tiles for run/walk come from OpenStreetMap while tracking.

---

## Advantages

- **One app for daily life.** Tasks, money, health, music, and alarms share one home screen instead of separate products.
- **Private by default.** Local SQLite, no required login, backup you control.
- **Works without a constant network.** Core planning, notes, habits, and money do not need a server.
- **South Indian languages.** UI in English plus Tamil, Telugu, Malayalam, and Kannada.
- **Honest money math.** Integer paise avoids floating-point rounding in ledgers.
- **Fitness is structured.** Fixed weekday focus, stretch opener, and time-based sets/reps/rest instead of an empty rest day.
- **Watch path exists.** Health Connect step sync is implemented for phones that expose steps (for example Da Fit writing into Health Connect).
- **Music and alarms are real system features.** Background audio and boot-rescheduled alarms, not only in-app timers.
- **Testable core.** Money, streaks, recurrence, and the daily workout builder have unit tests.

---

## Disadvantages

- **Large surface.** Many modules in one codebase. A bug or a rough screen in one area makes the whole app feel unfinished.
- **GUI is still uneven.** Shared theme exists, but not every screen has the same polish. Fitness was rebuilt more recently than some other modules.
- **Not a cloud product.** No multi-device sync. A new phone needs a manual backup restore. Losing the device without a backup loses the data.
- **Fitness media depends on downloads.** Exercise GIFs and cover photos can be missing, slow, or rate-limited. Covers are local assets; some photo refreshes from the web have failed.
- **Watch support is indirect.** The app does not replace Da Fit. Steps and vitals appear only if Health Connect (or the BLE path) actually returns data. Permissions and vendor apps still matter.
- **Jarvis is not ChatGPT.** It is a local rule-and-memory assistant. Answers are limited to what the app stored or a small online lookup.
- **English course is narrow.** It is a built-in curriculum, not a full language school.
- **Android-first.** Desktop/Windows is for development and can be blocked by native plugin setup. iOS is not the shipping target of this tree.
- **Permissions feel heavy** if you only want notes and tasks, because the same APK also asks for health, location, audio, and Bluetooth when those features are opened.
- **First-version maturity.** Labelled “First Version”. Edge cases (migrations on old installs, OEM alarm restrictions, Health Connect gaps) still show up on real phones.

---

## Who it fits

**Fits** someone who wants a private, offline daily organizer with Tamil-family language support and is willing to keep their own backup.

**Fits less** someone who wants cloud sync, a social fitness network, a coach, or a general AI chatbot.
