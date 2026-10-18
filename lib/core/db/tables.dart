import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Daily organisation
// ---------------------------------------------------------------------------

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get scheduleType => integer().withDefault(const Constant(0))();
  IntColumn get weekdaysMask => integer().withDefault(const Constant(0))();
  IntColumn get targetPerWeek => integer().withDefault(const Constant(7))();
  BoolColumn get isMeasurable => boolean().withDefault(const Constant(false))();
  RealColumn get goalValue => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get reminderMinuteOfDay =>
      integer().withDefault(const Constant(-1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class HabitCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get day => dateTime()();
  RealColumn get value => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get color => text().withDefault(const Constant(''))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get dueMinuteOfDay => integer().withDefault(const Constant(-1))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  IntColumn get parentId =>
      integer().nullable().references(
        Tasks,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get recurrenceRule => text().withDefault(const Constant(''))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  TextColumn get tagIds => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().withDefault(const Constant(''))();
  IntColumn get reminderMinutes => integer().withDefault(const Constant(-1))();
  BoolColumn get isBirthday => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class EventExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId =>
      integer().references(Events, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get originalDate => dateTime()();
  DateTimeColumn get newStartAt => dateTime().nullable()();
  DateTimeColumn get newEndAt => dateTime().nullable()();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get kind => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  TextColumn get tagIds => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// Finance
// ---------------------------------------------------------------------------

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get openingBalancePaise =>
      integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get kind => integer().withDefault(const Constant(1))();
  TextColumn get icon => text().withDefault(const Constant(''))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => integer()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get frequency => integer().withDefault(const Constant(1))();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get lastRun => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get type => integer()();
  IntColumn get amountPaise => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get paymentMethod => integer().withDefault(const Constant(0))();
  IntColumn get transferAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get recurringRuleId =>
      integer().nullable().references(RecurringRules, #id)();
  TextColumn get attachmentPath => text().withDefault(const Constant(''))();
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get amountPaise => integer()();
  IntColumn get period => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get alertThresholdPercent =>
      integer().withDefault(const Constant(80))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get principalPaise => integer()();
  RealColumn get interestRatePercent => real().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get contactName => text().withDefault(const Constant(''))();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId =>
      integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountPaise => integer()();
  IntColumn get principalPaise => integer().withDefault(const Constant(0))();
  IntColumn get interestPaise => integer().withDefault(const Constant(0))();
  DateTimeColumn get date => dateTime()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetPaise => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get icon => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SavingsContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId =>
      integer().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountPaise => integer()();
  BoolColumn get isWithdrawal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id)();
}

// ---------------------------------------------------------------------------
// Fitness
// ---------------------------------------------------------------------------

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get category => integer().withDefault(const Constant(0))();

  /// Broad movement type: 0 strength, 1 cardio, 2 mobility, 3 balance.
  IntColumn get exerciseType => integer().withDefault(const Constant(0))();

  TextColumn get targetMuscles => text().withDefault(const Constant(''))();
  TextColumn get equipment => text().withDefault(const Constant(''))();
  IntColumn get difficulty => integer().withDefault(const Constant(0))();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  TextColumn get safetyNotes => text().withDefault(const Constant(''))();

  /// Coaching cues for good form, common errors to avoid and any condition
  /// that should make the user pick an alternative.
  TextColumn get formTips => text().withDefault(const Constant(''))();
  TextColumn get commonMistakes => text().withDefault(const Constant(''))();
  TextColumn get contraindications => text().withDefault(const Constant(''))();

  /// Easier / harder substitute exercise ids (null when none). Not a hard FK:
  /// the target may be removed, in which case the reference is simply ignored.
  IntColumn get easierAltId => integer().nullable()();
  IntColumn get harderAltId => integer().nullable()();

  /// Optional demo asset reference, resolved by the app from bundled offline
  /// assets (empty means "use the built-in illustration").
  TextColumn get demoAsset => text().withDefault(const Constant(''))();

  /// Optional localization keys. When present the UI looks up a translated
  /// string; otherwise it falls back to the English [name]/[instructions]/
  /// [safetyNotes]. Empty by default so bundled content stays valid.
  TextColumn get nameKey => text().withDefault(const Constant(''))();
  TextColumn get instructionsKey => text().withDefault(const Constant(''))();
  TextColumn get safetyNotesKey => text().withDefault(const Constant(''))();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isTimed => boolean().withDefault(const Constant(false))();
  IntColumn get defaultSets => integer().withDefault(const Constant(3))();
  IntColumn get defaultReps => integer().withDefault(const Constant(10))();
  IntColumn get defaultDurationSec =>
      integer().withDefault(const Constant(0))();
  IntColumn get restSec => integer().withDefault(const Constant(60))();
  TextColumn get mediaPath => text().withDefault(const Constant(''))();

  // --- Bundled dataset fields (Exercise Gym GIFs DB) ------------------------
  // Empty for exercises the user created themselves and for records written
  // before the library was replaced. [sourceId] is the dataset's own stable
  // identifier ("chest/push-up") and is what the seeder uses to detect an
  // already-imported library.
  TextColumn get sourceId => text().withDefault(const Constant(''))();
  TextColumn get slug => text().withDefault(const Constant(''))();

  /// Coarse body region from the dataset: arms, legs, chest, back, core,
  /// shoulders or cardio.
  TextColumn get bodyPart => text().withDefault(const Constant(''))();

  /// Extra muscles worked, comma-separated in the dataset's own vocabulary.
  TextColumn get secondaryMuscles => text().withDefault(const Constant(''))();

  /// The dataset's movement category: strength, stretching, cardio or
  /// plyometrics. Kept alongside [category] (a muscle-group index) because it
  /// is what separates stretching and mobility work from strength work.
  TextColumn get sourceCategory => text().withDefault(const Constant(''))();

  /// Remote animated demonstration (dataset GIF). Empty when the dataset has
  /// no media for this exercise, in which case the UI falls back to the
  /// built-in illustration.
  TextColumn get gifUrl => text().withDefault(const Constant(''))();
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get type => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get distanceMeters => integer().withDefault(const Constant(0))();
  IntColumn get avgPaceSecPerKm => integer().withDefault(const Constant(0))();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get routeJson => text().withDefault(const Constant(''))();

  /// Source plan when the session came from a guided plan (null for a quick
  /// workout or a run/walk). Enables resuming an interrupted guided workout.
  IntColumn get planId => integer().nullable()();

  /// Weekly-planner entry this session fulfils, when launched from the planner.
  IntColumn get scheduledId => integer().nullable()();

  /// How the session ended: 0 completed, 1 partial, 2 skipped, 3 cancelled.
  /// Only meaningful once [endedAt] is set.
  IntColumn get outcome => integer().withDefault(const Constant(0))();

  /// Last step the guided player reached, and the total number of steps, so an
  /// interrupted workout can be restored exactly.
  IntColumn get stepIndex => integer().withDefault(const Constant(0))();
  IntColumn get totalSteps => integer().withDefault(const Constant(0))();
}

class WorkoutSetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get weightGrams => integer().withDefault(const Constant(0))();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get restSec => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();
}

class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get dayOfWeek => integer().withDefault(const Constant(-1))();

  /// 0 custom, 1 generated from preferences, 2 built-in starter template.
  IntColumn get kind => integer().withDefault(const Constant(0))();

  /// Comma-separated muscle-group category indexes this plan targets.
  TextColumn get muscleGroups => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class WorkoutPlanItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(WorkoutPlans, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  IntColumn get reps => integer().withDefault(const Constant(10))();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
}

/// User-configurable workout preferences. A single row (id == 1) holds the
/// current configuration so the weekly planner can generate suitable sessions.
class WorkoutPrefs extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Preferred overall plan style: see PlanStyle for the index mapping.
  IntColumn get planStyle => integer().withDefault(const Constant(0))();

  /// Fitness level, aligned with exercise difficulty (0 beginner … 2 advanced).
  IntColumn get fitnessLevel => integer().withDefault(const Constant(0))();

  /// Comma-separated equipment tags the user has available.
  TextColumn get equipment => text().withDefault(const Constant(''))();

  /// Target session length in minutes.
  IntColumn get sessionMinutes => integer().withDefault(const Constant(30))();

  /// Days the user wants to train, as bits 0..6 = Monday..Sunday.
  IntColumn get trainingDaysMask => integer().withDefault(const Constant(0))();

  /// Days explicitly marked as rest, bits 0..6 = Monday..Sunday.
  IntColumn get restDaysMask => integer().withDefault(const Constant(0))();

  /// Primary goal: see WorkoutGoal for the index mapping.
  IntColumn get goal => integer().withDefault(const Constant(0))();

  /// Comma-separated muscle-group category indexes the user wants to focus on.
  TextColumn get goalMuscles => text().withDefault(const Constant(''))();

  /// Preferred time of day to train, minutes since midnight (-1 = any time).
  IntColumn get preferredMinuteOfDay =>
      integer().withDefault(const Constant(-1))();

  /// Comma-separated "from>to" exercise-id substitutions the user prefers.
  TextColumn get substitutions => text().withDefault(const Constant(''))();

  /// Whether the user has acknowledged the health/safety guidance.
  BoolColumn get safetyAcknowledged =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single entry in the weekly planner: a planned workout (or rest day) on a
/// specific calendar date. Historic rows are kept so past weeks remain visible.
class WorkoutSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();

  /// Source plan/template (null for a free-form or rest day).
  IntColumn get planId => integer().nullable()();

  TextColumn get title => text().withDefault(const Constant(''))();

  /// Comma-separated muscle-group category indexes for this day.
  TextColumn get muscleGroups => text().withDefault(const Constant(''))();

  /// 0 planned, 1 completed, 2 skipped, 3 rest, 4 missed.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// Ordering within a day when more than one session is scheduled.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// The workout session that fulfilled this entry, once started.
  IntColumn get sessionId => integer().nullable()();

  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMl => integer()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}

class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get weightGrams => integer().withDefault(const Constant(0))();
  RealColumn get bodyFatPercent => real().withDefault(const Constant(0))();
  RealColumn get chestCm => real().withDefault(const Constant(0))();
  RealColumn get waistCm => real().withDefault(const Constant(0))();
  RealColumn get hipCm => real().withDefault(const Constant(0))();
  RealColumn get armCm => real().withDefault(const Constant(0))();
  RealColumn get thighCm => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class PersonalRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get recordType => integer().withDefault(const Constant(0))();
  IntColumn get value => integer()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
}

class FitnessGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get metric => integer()();
  IntColumn get targetValue => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

// ---------------------------------------------------------------------------
// Music
// ---------------------------------------------------------------------------

class MusicFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

class MusicTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uri => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get artist => text().withDefault(const Constant(''))();
  TextColumn get album => text().withDefault(const Constant(''))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get folderPath => text().withDefault(const Constant(''))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  // Metadata captured from the device media library (schema v5). All optional
  // with defaults so previously indexed rows migrate without rewriting.
  TextColumn get mediaId => text().withDefault(const Constant(''))();
  IntColumn get albumId => integer().nullable()();
  IntColumn get artistId => integer().nullable()();
  TextColumn get genre => text().withDefault(const Constant(''))();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateModified => dateTime().nullable()();
  TextColumn get albumArtUri => text().withDefault(const Constant(''))();
  IntColumn get trackNumber => integer().withDefault(const Constant(0))();
  BoolColumn get isMissing => boolean().withDefault(const Constant(false))();
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Custom collections (schema v5): a "label" and a "playlist" share storage.
  IntColumn get accentColor => integer().nullable()();
  TextColumn get coverUri => text().withDefault(const Constant(''))();
  TextColumn get kind => text().withDefault(const Constant('playlist'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class PlaylistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId => integer().references(MusicTracks, #id)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// A local listening-history log. One row per completed/started play, used for
/// "recently played" and statistics. Never leaves the device.
class MusicHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(MusicTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

class MusicState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastTrackId => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  BoolColumn get shuffle => boolean().withDefault(const Constant(false))();
  IntColumn get repeatMode => integer().withDefault(const Constant(0))();
  TextColumn get queueJson => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Alarms
// ---------------------------------------------------------------------------

class Alarms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get label => text().withDefault(const Constant(''))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// Zero means "no specific days": a daily alarm, or a single one-off when
  /// [oneTime] is true. Otherwise bits 0..6 = Monday..Sunday.
  IntColumn get repeatDaysMask => integer().withDefault(const Constant(0))();

  /// When true (and [repeatDaysMask] is zero) the alarm rings once and then
  /// disables itself instead of repeating daily.
  BoolColumn get oneTime => boolean().withDefault(const Constant(false))();

  TextColumn get soundUri => text().withDefault(const Constant(''))();
  IntColumn get soundStartMs => integer().withDefault(const Constant(0))();
  IntColumn get soundEndMs => integer().withDefault(const Constant(0))();

  /// Playback volume for the ringing audio, 0–100.
  IntColumn get volume => integer().withDefault(const Constant(100))();
  BoolColumn get gradualVolume =>
      boolean().withDefault(const Constant(false))();
  IntColumn get gradientDurationSec =>
      integer().withDefault(const Constant(30))();
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(5))();

  /// Maximum consecutive snoozes allowed before the next fire forces a
  /// dismissal. Zero means unlimited.
  IntColumn get maxSnoozes => integer().withDefault(const Constant(0))();

  /// How many times the current ringing instance has been snoozed. Reset when
  /// the alarm is dismissed or edited.
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
  IntColumn get challengeType => integer().withDefault(const Constant(0))();
  TextColumn get challengeParam => text().withDefault(const Constant(''))();

  /// Ordered dismissal challenges that must all be passed before the alarm
  /// stops, stored as comma-separated kind names (e.g. "math,memory,code").
  /// Repeated kinds are allowed. Empty falls back to [challengeType] (legacy).
  TextColumn get challengeSequence => text().withDefault(const Constant(''))();
  BoolColumn get vibrate => boolean().withDefault(const Constant(true))();

  /// Which alarm sound experience to play while ringing (schema v6):
  /// 0 = music + motivational voice, 1 = voice only, 2 = music/tone only.
  /// Defaults to 2 so alarms created before this feature keep their existing
  /// music-only behaviour.
  IntColumn get soundMode => integer().withDefault(const Constant(2))();

  /// Per-alarm motivational message spoken by TTS while ringing. Each alarm
  /// keeps its own copy; empty means "no spoken message".
  TextColumn get message => text().withDefault(const Constant(''))();

  /// Seconds of music played before the next spoken message in
  /// music + voice mode. Never determines how long the whole alarm runs.
  IntColumn get musicIntervalSec => integer().withDefault(const Constant(10))();

  /// When the spoken message plays relative to the music: 0 = before the
  /// music starts, 1 = between music segments, 2 = over the music.
  IntColumn get voiceTiming => integer().withDefault(const Constant(1))();

  /// Seconds to wait between spoken repetitions in voice-only mode.
  IntColumn get voicePauseSec => integer().withDefault(const Constant(5))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// Meals
// ---------------------------------------------------------------------------

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get servings => integer().withDefault(const Constant(1))();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId =>
      integer().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant(''))();
}

class MealPlanEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get day => dateTime()();
  IntColumn get mealType => integer().withDefault(const Constant(0))();
  IntColumn get recipeId => integer().nullable().references(Recipes, #id)();
  TextColumn get customName => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class GroceryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  BoolColumn get isManual => boolean().withDefault(const Constant(true))();
  IntColumn get sourceMealId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// English learning
// ---------------------------------------------------------------------------

class LearningCourses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceLang => text().withDefault(const Constant('ta'))();
  TextColumn get targetLang => text().withDefault(const Constant('en'))();
  TextColumn get title => text()();
  IntColumn get level => integer().withDefault(const Constant(0))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

class Lessons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(LearningCourses, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayNumber => integer()();
  TextColumn get title => text()();
  TextColumn get grammarJson => text().withDefault(const Constant(''))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

class Vocabulary extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lessonId => integer().nullable().references(Lessons, #id)();
  TextColumn get word => text()();
  TextColumn get meaningTa => text().withDefault(const Constant(''))();
  TextColumn get meaningEn => text().withDefault(const Constant(''))();
  TextColumn get pronunciationTa => text().withDefault(const Constant(''))();
  TextColumn get exampleEn => text().withDefault(const Constant(''))();
  TextColumn get exampleTa => text().withDefault(const Constant(''))();
  IntColumn get level => integer().withDefault(const Constant(0))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

class LearningExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lessonId => integer().references(Lessons, #id)();
  IntColumn get type => integer().withDefault(const Constant(0))();
  TextColumn get question => text()();
  TextColumn get optionsJson => text().withDefault(const Constant(''))();
  TextColumn get answer => text()();
  TextColumn get explanationTa => text().withDefault(const Constant(''))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

class LearningAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(
        LearningExercises,
        #id,
        onDelete: KeyAction.cascade,
      )();
  BoolColumn get isCorrect => boolean()();
  TextColumn get userAnswer => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class VocabReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vocabId => integer().references(Vocabulary, #id)();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
}

class PronunciationAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vocabId => integer().references(Vocabulary, #id)();
  TextColumn get recognizedText => text().withDefault(const Constant(''))();
  IntColumn get score => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class LearningProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lessonId =>
      integer().references(Lessons, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get score => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
