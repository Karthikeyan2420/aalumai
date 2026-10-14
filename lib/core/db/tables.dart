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
  TextColumn get targetMuscles => text().withDefault(const Constant(''))();
  TextColumn get equipment => text().withDefault(const Constant(''))();
  IntColumn get difficulty => integer().withDefault(const Constant(0))();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  TextColumn get safetyNotes => text().withDefault(const Constant(''))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isTimed => boolean().withDefault(const Constant(false))();
  IntColumn get defaultSets => integer().withDefault(const Constant(3))();
  IntColumn get defaultReps => integer().withDefault(const Constant(10))();
  IntColumn get defaultDurationSec =>
      integer().withDefault(const Constant(0))();
  IntColumn get restSec => integer().withDefault(const Constant(60))();
  TextColumn get mediaPath => text().withDefault(const Constant(''))();
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
}

class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get dayOfWeek => integer().withDefault(const Constant(-1))();
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
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PlaylistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId => integer().references(MusicTracks, #id)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
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
  IntColumn get repeatDaysMask => integer().withDefault(const Constant(0))();
  TextColumn get soundUri => text().withDefault(const Constant(''))();
  IntColumn get soundStartMs => integer().withDefault(const Constant(0))();
  IntColumn get soundEndMs => integer().withDefault(const Constant(0))();
  BoolColumn get gradualVolume =>
      boolean().withDefault(const Constant(false))();
  IntColumn get gradientDurationSec =>
      integer().withDefault(const Constant(30))();
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(5))();
  IntColumn get challengeType => integer().withDefault(const Constant(0))();
  TextColumn get challengeParam => text().withDefault(const Constant(''))();
  BoolColumn get vibrate => boolean().withDefault(const Constant(true))();
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
