# Database schema

AALUMAI stores everything in a single SQLite database, `aalumai.sqlite`, in the
app documents directory. The schema is defined with **Drift** in
`lib/core/db/tables.dart` and wired in `lib/core/db/database.dart`
(`AppDatabase`, `schemaVersion == 1`, `PRAGMA foreign_keys = ON`).

## Conventions

- Every table has an auto-incrementing integer `id` primary key unless noted.
- **Money** is stored as integer **paise** — column names end in `Paise`
  (1 INR = 100 paise). Never floating point.
- **Weight** is stored in **grams** (`weightGrams`), **distance** in **meters**
  (`distanceMeters`).
- **Time of day** is stored as **minutes since midnight** (`...MinuteOfDay`),
  `-1` meaning "unset".
- **Repeat masks** use bit 0 = Monday … bit 6 = Sunday; a mask of `0` means
  "every day".
- `dateTime` columns use ISO-8601 text through Drift.

---

## Daily organisation

### `habits`
id, name, note, scheduleType, weekdaysMask, targetPerWeek, isMeasurable,
goalValue (real), unit, isArchived, sortOrder, reminderMinuteOfDay, createdAt.

### `habit_completions`
id, habitId → habits (cascade), day, value (real), note, createdAt.

### `tags`
id, name (1–60), color.

### `tasks`
id, title, notes, dueDate (nullable), dueMinuteOfDay, priority, parentId →
tasks (cascade, nullable), recurrenceRule, isCompleted, completedAt (nullable),
reminderAt (nullable), tagIds, sortOrder, createdAt.

### `events`
id, title, description, location, startAt, endAt, allDay, recurrenceRule,
reminderMinutes, isBirthday, createdAt.

### `event_exceptions`
id, eventId → events (cascade), originalDate, newStartAt (nullable),
newEndAt (nullable), isCancelled.

### `notes`
id, title, body, kind, isPinned, isFavorite, isLocked, tagIds, createdAt,
updatedAt.

---

## Finance

### `accounts`
id, name, type, openingBalancePaise, currency (INR), isArchived, sortOrder,
createdAt.

### `categories`
id, name, kind, icon, isCustom, isArchived, sortOrder.
Default categories are seeded on first launch.

### `recurring_rules`
id, type, accountId → accounts, categoryId → categories (nullable), amountPaise,
note, frequency, interval, nextDate, lastRun (nullable), isActive.

### `transactions`
id, accountId → accounts, categoryId → categories (nullable), type
(income / expense / **transfer**), amountPaise, date, note, paymentMethod,
transferAccountId → accounts (nullable), recurringRuleId → recurring_rules
(nullable), attachmentPath, isReconciled, createdAt.

> A **transfer** is not income or expense; it moves money between accounts.
> A **debt principal repayment** is likewise not an ordinary expense.

### `budgets`
id, categoryId → categories (nullable), amountPaise, period,
startDate, alertThresholdPercent, isActive.

### `debts`
id, name, type, principalPaise, interestRatePercent (real), startDate,
dueDate (nullable), contactName, isClosed, note, createdAt.

### `debt_payments`
id, debtId → debts (cascade), amountPaise, principalPaise, interestPaise, date,
accountId → accounts (nullable), note.

### `savings_goals`
id, name, targetPaise, targetDate (nullable), note, isCompleted, icon, createdAt.

### `savings_contributions`
id, goalId → savings_goals (cascade), amountPaise, isWithdrawal, date, note,
transactionId → transactions (nullable).

---

## Fitness

### `exercises`
id, name, category, targetMuscles, equipment, difficulty, instructions,
safetyNotes, isCustom, isTimed, defaultSets, defaultReps, defaultDurationSec,
restSec, mediaPath.
The starter library is seeded on first launch.

### `workout_sessions`
id, name, type, startedAt, endedAt (nullable), durationSec, distanceMeters,
avgPaceSecPerKm, calories, notes, routeJson.

### `workout_set_logs`
id, sessionId → workout_sessions (cascade), exerciseId → exercises (cascade),
setIndex, reps, weightGrams, durationSec, restSec, isCompleted.

### `workout_plans`
id, name, dayOfWeek, notes.

### `workout_plan_items`
id, planId → workout_plans (cascade), exerciseId → exercises (cascade),
orderIndex, sets, reps, durationSec.

### `water_logs`
id, amountMl, loggedAt, source.

### `body_measurements`
id, date, weightGrams, bodyFatPercent (real), chestCm (real), waistCm (real),
hipCm (real), armCm (real), thighCm (real), note.

### `personal_records`
id, exerciseId → exercises, recordType, value, recordedAt.

### `fitness_goals`
id, metric, targetValue, targetDate (nullable), note.

---

## Music

### `music_folders`
id, path, addedAt.

### `music_tracks`
id, uri, title, artist, album, durationMs, folderPath, isFavorite,
lastPlayedAt (nullable), playCount, addedAt.

### `playlists`
id, name, createdAt.

### `playlist_items`
id, playlistId → playlists (cascade), trackId → music_tracks, orderIndex.

### `music_state` (single row, `id == 1`)
id (PK, default 1), lastTrackId (nullable), positionMs, shuffle, repeatMode,
queueJson.

---

## Alarms

### `alarms`
id, hour, minute, label, isEnabled, repeatDaysMask, soundUri, soundStartMs,
soundEndMs, gradualVolume, gradientDurationSec, snoozeMinutes, challengeType,
challengeParam, vibrate, createdAt.

---

## Meals

### `recipes`
id, name, servings, instructions, notes, createdAt.

### `recipe_ingredients`
id, recipeId → recipes (cascade), name, quantity (real), unit.

### `meal_plan_entries`
id, day, mealType, recipeId → recipes (nullable), customName, note.

### `grocery_items`
id, name, quantity (real), unit, category, isChecked, isManual, sourceMealId
(nullable), createdAt.

---

## English learning

### `learning_courses`
id, sourceLang (ta), targetLang (en), title, level, description, orderIndex.

### `lessons`
id, courseId → learning_courses (cascade), dayNumber, title, grammarJson,
orderIndex.

### `vocabulary`
id, lessonId → lessons (nullable), word, meaningTa, meaningEn, pronunciationTa,
exampleEn, exampleTa, level, orderIndex.

### `learning_exercises`
id, lessonId → lessons, type, question, optionsJson, answer, explanationTa,
orderIndex.
Questions are derived from vocabulary when the course is seeded.

### `learning_attempts`
id, exerciseId → learning_exercises (cascade), isCorrect, userAnswer, createdAt.

### `vocab_reviews`
id, vocabId → vocabulary, easeFactor (real, default 2.5), intervalDays,
repetitions, dueDate, lastReviewedAt (nullable).
Implements SM-2 *lite* spaced repetition.

### `pronunciation_attempts`
id, vocabId → vocabulary, recognizedText, score, createdAt.

### `learning_progress`
id, lessonId → lessons (cascade), isCompleted, score, completedAt (nullable).

---

## Dashboard configuration

Dashboard section order and visibility are **not** stored in the database.
They are user preferences persisted via `SharedPreferences` (keys
`dashboard_order` and `dashboard_hidden`), loaded/saved by
`AppPreferences` and exposed reactively through `dashboardConfigProvider`
(`lib/features/home/dashboard_sections.dart`).

---

## Backups

- **Export** uses SQLite `VACUUM INTO` to produce a consistent snapshot of the
  database file.
- **Restore** closes the database, replaces `aalumai.sqlite` (and removes stale
  `-wal`/`-shm`/`-journal` files), then invalidates `appDatabaseProvider` so the
  UI reconnects to the restored data.
- **CSV export** serialises all `transactions` to `aalumai_transactions.csv`.

See `lib/core/services/backup_service.dart`.
