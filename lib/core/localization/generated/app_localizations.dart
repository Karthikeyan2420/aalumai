import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kn'),
    Locale('ml'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'AALUMAI'**
  String get appName;

  /// No description provided for @appNameScript.
  ///
  /// In en, this message translates to:
  /// **'AALUMAI'**
  String get appNameScript;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your life. Your control.'**
  String get tagline;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Karthikeyan Asaithambi'**
  String get developer;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @releaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get releaseLabel;

  /// No description provided for @firstVersion.
  ///
  /// In en, this message translates to:
  /// **'First Version'**
  String get firstVersion;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get navFitness;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @permissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get permissionDeniedTitle;

  /// No description provided for @permissionDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This feature needs a permission that was denied. Open settings to grant it.'**
  String get permissionDeniedBody;

  /// No description provided for @emptyTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add your first task.'**
  String get emptyTasks;

  /// No description provided for @emptyHabits.
  ///
  /// In en, this message translates to:
  /// **'No habits yet. Build a routine.'**
  String get emptyHabits;

  /// No description provided for @emptyEvents.
  ///
  /// In en, this message translates to:
  /// **'No events scheduled.'**
  String get emptyEvents;

  /// No description provided for @emptyNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes yet.'**
  String get emptyNotes;

  /// No description provided for @emptyExpenses.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded.'**
  String get emptyExpenses;

  /// No description provided for @emptyAlarms.
  ///
  /// In en, this message translates to:
  /// **'No alarms set.'**
  String get emptyAlarms;

  /// No description provided for @emptyMusic.
  ///
  /// In en, this message translates to:
  /// **'No music found in the selected folders.'**
  String get emptyMusic;

  /// No description provided for @emptyWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged yet.'**
  String get emptyWorkouts;

  /// No description provided for @emptyMeals.
  ///
  /// In en, this message translates to:
  /// **'No meals planned.'**
  String get emptyMeals;

  /// No description provided for @emptySavings.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet.'**
  String get emptySavings;

  /// No description provided for @emptyLessons.
  ///
  /// In en, this message translates to:
  /// **'No lessons available.'**
  String get emptyLessons;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @quickAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get quickAddExpense;

  /// No description provided for @quickAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get quickAddTask;

  /// No description provided for @quickWater.
  ///
  /// In en, this message translates to:
  /// **'Record water'**
  String get quickWater;

  /// No description provided for @quickNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get quickNote;

  /// No description provided for @quickWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get quickWorkout;

  /// No description provided for @quickLearn.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get quickLearn;

  /// No description provided for @quickHabit.
  ///
  /// In en, this message translates to:
  /// **'Complete habit'**
  String get quickHabit;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @nextAlarm.
  ///
  /// In en, this message translates to:
  /// **'Next alarm'**
  String get nextAlarm;

  /// No description provided for @todaysEvents.
  ///
  /// In en, this message translates to:
  /// **'Today\'s events'**
  String get todaysEvents;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @habitChecklist.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habitChecklist;

  /// No description provided for @habits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habits;

  /// No description provided for @workoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutPlan;

  /// No description provided for @waterIntake.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get waterIntake;

  /// No description provided for @expenseSummary.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get expenseSummary;

  /// No description provided for @upcomingReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get upcomingReminders;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get continueLearning;

  /// No description provided for @customizeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Customize dashboard'**
  String get customizeDashboard;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & permissions'**
  String get settingsPrivacy;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data & backup'**
  String get settingsData;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get settingsFitness;

  /// No description provided for @settingsLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get settingsLearning;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About AALUMAI'**
  String get settingsAbout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get languageSubtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up data'**
  String get backupNow;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreBackup;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvDescription.
  ///
  /// In en, this message translates to:
  /// **'Export supported data as CSV files.'**
  String get exportCsvDescription;

  /// No description provided for @backupDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a complete local backup of your data.'**
  String get backupDescription;

  /// No description provided for @restoreWarning.
  ///
  /// In en, this message translates to:
  /// **'Restoring will overwrite your current data. Continue?'**
  String get restoreWarning;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup created successfully.'**
  String get backupSuccess;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored successfully.'**
  String get restoreSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed.'**
  String get backupFailed;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. The file may be invalid.'**
  String get restoreFailed;

  /// No description provided for @noBackupFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected.'**
  String get noBackupFile;

  /// No description provided for @languageNameEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @languageNameTa.
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get languageNameTa;

  /// No description provided for @languageNameTe.
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get languageNameTe;

  /// No description provided for @languageNameMl.
  ///
  /// In en, this message translates to:
  /// **'മലയാളം'**
  String get languageNameMl;

  /// No description provided for @languageNameKn.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get languageNameKn;

  /// No description provided for @privacyLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on your device by default. AALUMAI is offline-first and does not upload your personal information.'**
  String get privacyLocalFirst;

  /// No description provided for @permissionsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Permissions are requested only when a feature needs them.'**
  String get permissionsExplanation;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicenses;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'AALUMAI is an offline-first personal life management app.'**
  String get aboutDescription;

  /// No description provided for @madeWith.
  ///
  /// In en, this message translates to:
  /// **'Made for everyday life.'**
  String get madeWith;

  /// No description provided for @habitStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get habitStreak;

  /// No description provided for @habitBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get habitBest;

  /// No description provided for @habitComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get habitComplete;

  /// No description provided for @habitArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get habitArchived;

  /// No description provided for @habitGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get habitGoal;

  /// No description provided for @timesPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Times per week'**
  String get timesPerWeek;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @selectedDays.
  ///
  /// In en, this message translates to:
  /// **'Selected days'**
  String get selectedDays;

  /// No description provided for @taskDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get taskDue;

  /// No description provided for @taskOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskOverdue;

  /// No description provided for @taskUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get taskUpcoming;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskCompleted;

  /// No description provided for @subtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasks;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markComplete;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get taskTitleHint;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @eventStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventStart;

  /// No description provided for @eventEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventEnd;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday / anniversary'**
  String get birthday;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @journalEntry.
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get journalEntry;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @noteLock.
  ///
  /// In en, this message translates to:
  /// **'Lock this note'**
  String get noteLock;

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Last modified'**
  String get lastModified;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts & loans'**
  String get debts;

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get debt;

  /// No description provided for @principal.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get principal;

  /// No description provided for @interest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interest;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingBalance;

  /// No description provided for @monthlySummary.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get monthlySummary;

  /// No description provided for @yearlySummary.
  ///
  /// In en, this message translates to:
  /// **'Yearly summary'**
  String get yearlySummary;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccount;

  /// No description provided for @savingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get savingsGoals;

  /// No description provided for @savingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get savingsGoal;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmount;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDate;

  /// No description provided for @contribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get contribution;

  /// No description provided for @addContribution.
  ///
  /// In en, this message translates to:
  /// **'Add contribution'**
  String get addContribution;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @alarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarms;

  /// No description provided for @newAlarm.
  ///
  /// In en, this message translates to:
  /// **'New alarm'**
  String get newAlarm;

  /// No description provided for @alarmLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get alarmLabel;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get snooze;

  /// No description provided for @alarmSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get alarmSound;

  /// No description provided for @challenge.
  ///
  /// In en, this message translates to:
  /// **'Dismiss challenge'**
  String get challenge;

  /// No description provided for @challengeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get challengeNone;

  /// No description provided for @challengeMath.
  ///
  /// In en, this message translates to:
  /// **'Arithmetic'**
  String get challengeMath;

  /// No description provided for @challengeMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get challengeMemory;

  /// No description provided for @challengeCode.
  ///
  /// In en, this message translates to:
  /// **'Type a code'**
  String get challengeCode;

  /// No description provided for @gradualVolume.
  ///
  /// In en, this message translates to:
  /// **'Gradual volume'**
  String get gradualVolume;

  /// No description provided for @emergencyDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss anyway'**
  String get emergencyDismiss;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @addMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Add music folder'**
  String get addMusicFolder;

  /// No description provided for @fitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get fitness;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @workoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Workout history'**
  String get workoutHistory;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout'**
  String get finishWorkout;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @walk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walk;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @addWater.
  ///
  /// In en, this message translates to:
  /// **'Add water'**
  String get addWater;

  /// No description provided for @glasses.
  ///
  /// In en, this message translates to:
  /// **'glasses'**
  String get glasses;

  /// No description provided for @personalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get personalRecords;

  /// No description provided for @measurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// No description provided for @warmUp.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get warmUp;

  /// No description provided for @coolDown.
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get coolDown;

  /// No description provided for @yogaAndMobility.
  ///
  /// In en, this message translates to:
  /// **'Yoga & mobility'**
  String get yogaAndMobility;

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// No description provided for @dumbbells.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells'**
  String get dumbbells;

  /// No description provided for @difficultyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get difficultyBeginner;

  /// No description provided for @difficultyIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get difficultyIntermediate;

  /// No description provided for @difficultyAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get difficultyAdvanced;

  /// No description provided for @safetyNotes.
  ///
  /// In en, this message translates to:
  /// **'Safety notes'**
  String get safetyNotes;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @targetMuscles.
  ///
  /// In en, this message translates to:
  /// **'Target muscles'**
  String get targetMuscles;

  /// No description provided for @learnEnglish.
  ///
  /// In en, this message translates to:
  /// **'Learn English'**
  String get learnEnglish;

  /// No description provided for @learningTagline.
  ///
  /// In en, this message translates to:
  /// **'Learn in Tamil, speak in English.'**
  String get learningTagline;

  /// No description provided for @vocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get vocabulary;

  /// No description provided for @lesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get lesson;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @grammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get grammar;

  /// No description provided for @practice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practice;

  /// No description provided for @quiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quiz;

  /// No description provided for @pronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get pronunciation;

  /// No description provided for @pronunciationGuide.
  ///
  /// In en, this message translates to:
  /// **'Say it like this'**
  String get pronunciationGuide;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speak;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @playAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// No description provided for @slowSpeed.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get slowSpeed;

  /// No description provided for @normalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalSpeed;

  /// No description provided for @meaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get meaning;

  /// No description provided for @example.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get example;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get streakDays;

  /// No description provided for @reviewDue.
  ///
  /// In en, this message translates to:
  /// **'Due for review'**
  String get reviewDue;

  /// No description provided for @checkAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get checkAnswer;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get incorrect;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to practise speaking.'**
  String get microphonePermission;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @mealPlan.
  ///
  /// In en, this message translates to:
  /// **'Meal plan'**
  String get mealPlan;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get snacks;

  /// No description provided for @recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes;

  /// No description provided for @groceryList.
  ///
  /// In en, this message translates to:
  /// **'Grocery list'**
  String get groceryList;

  /// No description provided for @addToGrocery.
  ///
  /// In en, this message translates to:
  /// **'Add to grocery list'**
  String get addToGrocery;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @checkedItems.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get checkedItems;

  /// No description provided for @generateList.
  ///
  /// In en, this message translates to:
  /// **'Generate from meal plan'**
  String get generateList;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get reminderSet;

  /// No description provided for @scheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {time}'**
  String scheduledFor(String time);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteConfirmBody;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Discard them?'**
  String get unsavedChanges;

  /// No description provided for @spendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendingByCategory;

  /// No description provided for @weightTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get weightTrend;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kn', 'ml', 'ta', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
