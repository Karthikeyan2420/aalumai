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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
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
    Locale('te')
  ];

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle all'**
  String get shuffleAll;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @createLabel.
  ///
  /// In en, this message translates to:
  /// **'New label'**
  String get createLabel;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @scanDevice.
  ///
  /// In en, this message translates to:
  /// **'Scan device'**
  String get scanDevice;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get grantPermission;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get mostPlayed;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @totalSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get totalSongs;

  /// No description provided for @duplicates.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicates'**
  String get duplicates;

  /// No description provided for @missingFiles.
  ///
  /// In en, this message translates to:
  /// **'Missing files'**
  String get missingFiles;

  /// No description provided for @changeColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get changeColor;

  /// No description provided for @coverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get coverImage;

  /// No description provided for @noFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get noFolders;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOne;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @scanComplete.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get scanComplete;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

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

  /// No description provided for @restorePartial.
  ///
  /// In en, this message translates to:
  /// **'Data restored, but some alarms or reminders could not be re-armed. Please check them.'**
  String get restorePartial;

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

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get everyWeek;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @everyYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get everyYear;

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

  /// No description provided for @addRecurring.
  ///
  /// In en, this message translates to:
  /// **'New recurring'**
  String get addRecurring;

  /// No description provided for @dueRecurring.
  ///
  /// In en, this message translates to:
  /// **'Due recurring'**
  String get dueRecurring;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

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

  /// No description provided for @dismissAlarm.
  ///
  /// In en, this message translates to:
  /// **'Dismiss alarm'**
  String get dismissAlarm;

  /// No description provided for @memorizeDigits.
  ///
  /// In en, this message translates to:
  /// **'Memorize these digits'**
  String get memorizeDigits;

  /// No description provided for @enterAnswer.
  ///
  /// In en, this message translates to:
  /// **'Enter your answer'**
  String get enterAnswer;

  /// No description provided for @wrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'That\'s not right. Try again.'**
  String get wrongAnswer;

  /// No description provided for @passAllChallenges.
  ///
  /// In en, this message translates to:
  /// **'Pass every challenge to dismiss the alarm.'**
  String get passAllChallenges;

  /// No description provided for @challengeStep.
  ///
  /// In en, this message translates to:
  /// **'Challenge {current} of {total}'**
  String challengeStep(int current, int total);

  /// No description provided for @addChallenge.
  ///
  /// In en, this message translates to:
  /// **'Add challenge'**
  String get addChallenge;

  /// No description provided for @codeLength.
  ///
  /// In en, this message translates to:
  /// **'Code length'**
  String get codeLength;

  /// No description provided for @codeLengthValue.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String codeLengthValue(int count);

  /// No description provided for @removeChallenge.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeChallenge;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @previewAlarm.
  ///
  /// In en, this message translates to:
  /// **'Test alarm'**
  String get previewAlarm;

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

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Empty playlist'**
  String get emptyPlaylist;

  /// No description provided for @removeFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get removeFolder;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select folder'**
  String get selectFolder;

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

  /// No description provided for @plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plans;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @planName.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get planName;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @newGoal.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoal;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @goalWorkoutsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Workouts this week'**
  String get goalWorkoutsPerWeek;

  /// No description provided for @goalWaterDaily.
  ///
  /// In en, this message translates to:
  /// **'Water today (ml)'**
  String get goalWaterDaily;

  /// No description provided for @goalDistanceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Distance this week (m)'**
  String get goalDistanceWeekly;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise;

  /// No description provided for @setProgress.
  ///
  /// In en, this message translates to:
  /// **'Set {index} of {total}'**
  String setProgress(int index, int total);

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout complete'**
  String get workoutComplete;

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

  /// No description provided for @waitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS…'**
  String get waitingForGps;

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

  /// No description provided for @dumbbellWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell workouts'**
  String get dumbbellWorkouts;

  /// No description provided for @bodyweightWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight workouts'**
  String get bodyweightWorkouts;

  /// No description provided for @stretchingWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Stretching'**
  String get stretchingWorkouts;

  /// No description provided for @bandWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Resistance bands'**
  String get bandWorkouts;

  /// No description provided for @gymWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Gym workouts'**
  String get gymWorkouts;

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get searchExercises;

  /// No description provided for @noExercisesMatch.
  ///
  /// In en, this message translates to:
  /// **'No exercises match your filters.'**
  String get noExercisesMatch;

  /// No description provided for @difficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficultyLabel;

  /// No description provided for @yourExercises.
  ///
  /// In en, this message translates to:
  /// **'Your exercises'**
  String get yourExercises;

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

  /// No description provided for @atStart.
  ///
  /// In en, this message translates to:
  /// **'At start time'**
  String get atStart;

  /// No description provided for @minutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{count} min before'**
  String minutesBefore(int count);

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

  /// No description provided for @oneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get oneTime;

  /// No description provided for @repeatDays.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatDays;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @vibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get vibrate;

  /// No description provided for @maxSnoozes.
  ///
  /// In en, this message translates to:
  /// **'Max snoozes'**
  String get maxSnoozes;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @upcomingAlarms.
  ///
  /// In en, this message translates to:
  /// **'Upcoming alarms'**
  String get upcomingAlarms;

  /// No description provided for @nextRing.
  ///
  /// In en, this message translates to:
  /// **'Next ring'**
  String get nextRing;

  /// No description provided for @soundClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic beep'**
  String get soundClassic;

  /// No description provided for @soundGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle chime'**
  String get soundGentle;

  /// No description provided for @soundUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get soundUrgent;

  /// No description provided for @soundSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get soundSystem;

  /// No description provided for @snoozeDuration.
  ///
  /// In en, this message translates to:
  /// **'Snooze length'**
  String get snoozeDuration;

  /// No description provided for @ringsTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get ringsTomorrow;

  /// No description provided for @noUpcomingAlarms.
  ///
  /// In en, this message translates to:
  /// **'No upcoming alarms.'**
  String get noUpcomingAlarms;

  /// No description provided for @previewSound.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get previewSound;

  /// No description provided for @alarmSoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get alarmSoundCustom;

  /// No description provided for @customSoundFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add that sound. Try another file.'**
  String get customSoundFailed;

  /// No description provided for @alarmBackground.
  ///
  /// In en, this message translates to:
  /// **'Alarm background'**
  String get alarmBackground;

  /// No description provided for @exactAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms'**
  String get exactAlarmTitle;

  /// No description provided for @exactAlarmBody.
  ///
  /// In en, this message translates to:
  /// **'Android is blocking exact alarms, so alarms may ring late. Allow exact alarms in system settings.'**
  String get exactAlarmBody;

  /// No description provided for @exactAlarmAction.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get exactAlarmAction;

  /// No description provided for @alarmScheduleError.
  ///
  /// In en, this message translates to:
  /// **'Alarm could not be scheduled'**
  String get alarmScheduleError;

  /// No description provided for @chooseExercises.
  ///
  /// In en, this message translates to:
  /// **'Choose exercises'**
  String get chooseExercises;

  /// No description provided for @newWorkout.
  ///
  /// In en, this message translates to:
  /// **'New workout'**
  String get newWorkout;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get elapsed;

  /// No description provided for @logSet.
  ///
  /// In en, this message translates to:
  /// **'Log set'**
  String get logSet;

  /// No description provided for @completeSet.
  ///
  /// In en, this message translates to:
  /// **'Complete set'**
  String get completeSet;

  /// No description provided for @previousExercise.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousExercise;

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextExercise;

  /// No description provided for @workoutSummary.
  ///
  /// In en, this message translates to:
  /// **'Workout summary'**
  String get workoutSummary;

  /// No description provided for @exercisesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Exercises completed'**
  String get exercisesCompleted;

  /// No description provided for @setsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sets completed'**
  String get setsCompleted;

  /// No description provided for @totalReps.
  ///
  /// In en, this message translates to:
  /// **'Total reps'**
  String get totalReps;

  /// No description provided for @skippedExercises.
  ///
  /// In en, this message translates to:
  /// **'Skipped exercises'**
  String get skippedExercises;

  /// No description provided for @restComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest complete'**
  String get restComplete;

  /// No description provided for @workoutPaused.
  ///
  /// In en, this message translates to:
  /// **'Workout paused'**
  String get workoutPaused;

  /// No description provided for @resumeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get resumeWorkout;

  /// No description provided for @endWorkout.
  ///
  /// In en, this message translates to:
  /// **'End workout'**
  String get endWorkout;

  /// No description provided for @restartWorkout.
  ///
  /// In en, this message translates to:
  /// **'Restart workout'**
  String get restartWorkout;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @workoutInProgress.
  ///
  /// In en, this message translates to:
  /// **'Workout in progress'**
  String get workoutInProgress;

  /// No description provided for @resumeOrDiscard.
  ///
  /// In en, this message translates to:
  /// **'You have a workout in progress.'**
  String get resumeOrDiscard;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @actualReps.
  ///
  /// In en, this message translates to:
  /// **'Actual reps'**
  String get actualReps;

  /// No description provided for @weightUsed.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightUsed;

  /// No description provided for @targetReps.
  ///
  /// In en, this message translates to:
  /// **'Target reps'**
  String get targetReps;

  /// No description provided for @timed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get timed;

  /// No description provided for @startRest.
  ///
  /// In en, this message translates to:
  /// **'Start rest'**
  String get startRest;

  /// No description provided for @setDone.
  ///
  /// In en, this message translates to:
  /// **'Set done'**
  String get setDone;

  /// No description provided for @markSetDone.
  ///
  /// In en, this message translates to:
  /// **'Mark set done'**
  String get markSetDone;

  /// No description provided for @completeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Complete workout'**
  String get completeWorkout;

  /// No description provided for @workoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout saved'**
  String get workoutSaved;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get totalTime;

  /// No description provided for @resting.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get resting;

  /// No description provided for @workSet.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get workSet;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @resumeLastWorkout.
  ///
  /// In en, this message translates to:
  /// **'Resume last workout'**
  String get resumeLastWorkout;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'Plan progress'**
  String get planProgress;

  /// No description provided for @starterPlans.
  ///
  /// In en, this message translates to:
  /// **'Starter plans'**
  String get starterPlans;

  /// No description provided for @exerciseDetail.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exerciseDetail;

  /// No description provided for @howTo.
  ///
  /// In en, this message translates to:
  /// **'How to do it'**
  String get howTo;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editItem;

  /// No description provided for @musicScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t scan that folder. Check that access is granted and try again.'**
  String get musicScanFailed;

  /// No description provided for @musicAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder that contains your music. AALUMAI scans files on your device only.'**
  String get musicAccessNeeded;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan folders'**
  String get rescan;

  /// No description provided for @noMusicYet.
  ///
  /// In en, this message translates to:
  /// **'No music added yet. Add a folder to get started.'**
  String get noMusicYet;

  /// No description provided for @musicAddedCount.
  ///
  /// In en, this message translates to:
  /// **'tracks added'**
  String get musicAddedCount;

  /// No description provided for @armsLabel.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get armsLabel;

  /// No description provided for @shouldersLabel.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get shouldersLabel;

  /// No description provided for @chestLabel.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chestLabel;

  /// No description provided for @backLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backLabel;

  /// No description provided for @legsLabel.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legsLabel;

  /// No description provided for @coreLabel.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get coreLabel;

  /// No description provided for @cardioLabel.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get cardioLabel;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get secondsShort;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @emptyWorkoutExercises.
  ///
  /// In en, this message translates to:
  /// **'Add or select at least one exercise to start.'**
  String get emptyWorkoutExercises;

  /// No description provided for @newExercise.
  ///
  /// In en, this message translates to:
  /// **'New exercise'**
  String get newExercise;

  /// No description provided for @timedExercise.
  ///
  /// In en, this message translates to:
  /// **'Timed exercise'**
  String get timedExercise;

  /// No description provided for @noSetsLogged.
  ///
  /// In en, this message translates to:
  /// **'No sets were logged for this workout.'**
  String get noSetsLogged;

  /// No description provided for @workoutPreferences.
  ///
  /// In en, this message translates to:
  /// **'Workout preferences'**
  String get workoutPreferences;

  /// No description provided for @planStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan style'**
  String get planStyleLabel;

  /// No description provided for @planStyleBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get planStyleBalanced;

  /// No description provided for @planStyleMuscleSplit.
  ///
  /// In en, this message translates to:
  /// **'Muscle split'**
  String get planStyleMuscleSplit;

  /// No description provided for @planStyleFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full body'**
  String get planStyleFullBody;

  /// No description provided for @planStyleCardioFocus.
  ///
  /// In en, this message translates to:
  /// **'Cardio focus'**
  String get planStyleCardioFocus;

  /// No description provided for @fitnessLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Fitness level'**
  String get fitnessLevelLabel;

  /// No description provided for @sessionLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Session length'**
  String get sessionLengthLabel;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @trainingDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Training days'**
  String get trainingDaysLabel;

  /// No description provided for @restDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest days'**
  String get restDaysLabel;

  /// No description provided for @primaryGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary goal'**
  String get primaryGoalLabel;

  /// No description provided for @goalGeneralHealth.
  ///
  /// In en, this message translates to:
  /// **'General health'**
  String get goalGeneralHealth;

  /// No description provided for @goalStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get goalStrength;

  /// No description provided for @goalEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get goalEndurance;

  /// No description provided for @goalFlexibility.
  ///
  /// In en, this message translates to:
  /// **'Flexibility'**
  String get goalFlexibility;

  /// No description provided for @goalWeightManagement.
  ///
  /// In en, this message translates to:
  /// **'Weight management'**
  String get goalWeightManagement;

  /// No description provided for @focusMusclesLabel.
  ///
  /// In en, this message translates to:
  /// **'Focus muscles'**
  String get focusMusclesLabel;

  /// No description provided for @availableEquipment.
  ///
  /// In en, this message translates to:
  /// **'Available equipment'**
  String get availableEquipment;

  /// No description provided for @equipmentHint.
  ///
  /// In en, this message translates to:
  /// **'Add equipment'**
  String get equipmentHint;

  /// No description provided for @preferredTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred time'**
  String get preferredTimeLabel;

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @clearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLabel;

  /// No description provided for @safetyGuidanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Health & safety'**
  String get safetyGuidanceTitle;

  /// No description provided for @safetyGuidanceBody.
  ///
  /// In en, this message translates to:
  /// **'Warm up first and work within your limits. Stop if you feel pain, dizziness or shortness of breath. This guidance is informed by WHO physical-activity advice for adults aged 18-64 and is not medical advice - seek professional guidance if you have a health condition.'**
  String get safetyGuidanceBody;

  /// No description provided for @safetyAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'I understand and will stay within my limits'**
  String get safetyAcknowledged;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferences;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get preferencesSaved;

  /// No description provided for @weeklyPlanner.
  ///
  /// In en, this message translates to:
  /// **'Weekly planner'**
  String get weeklyPlanner;

  /// No description provided for @clearUnstarted.
  ///
  /// In en, this message translates to:
  /// **'Clear un-started days'**
  String get clearUnstarted;

  /// No description provided for @clearUnstartedBody.
  ///
  /// In en, this message translates to:
  /// **'Remove planned, missed and rest days for this week. Completed sessions are kept.'**
  String get clearUnstartedBody;

  /// No description provided for @generateWeek.
  ///
  /// In en, this message translates to:
  /// **'Generate week'**
  String get generateWeek;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @weekGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sessions generated} =1{1 session generated} other{{count} sessions generated}}'**
  String weekGenerated(int count);

  /// No description provided for @weekCleared.
  ///
  /// In en, this message translates to:
  /// **'Un-started days cleared'**
  String get weekCleared;

  /// No description provided for @noPlansYet.
  ///
  /// In en, this message translates to:
  /// **'Create a workout plan first'**
  String get noPlansYet;

  /// No description provided for @selectPlan.
  ///
  /// In en, this message translates to:
  /// **'Select a plan'**
  String get selectPlan;

  /// No description provided for @addSession.
  ///
  /// In en, this message translates to:
  /// **'Add session'**
  String get addSession;

  /// No description provided for @editSession.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get editSession;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session title'**
  String get sessionTitle;

  /// No description provided for @muscleGroupsLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle groups'**
  String get muscleGroupsLabel;

  /// No description provided for @moveToDay.
  ///
  /// In en, this message translates to:
  /// **'Move to another day'**
  String get moveToDay;

  /// No description provided for @deleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the session from the planner. Logged workout history is kept.'**
  String get deleteSessionBody;

  /// No description provided for @noSessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No sessions planned'**
  String get noSessionsThisWeek;

  /// No description provided for @planWarnings.
  ///
  /// In en, this message translates to:
  /// **'Plan check'**
  String get planWarnings;

  /// No description provided for @warningConsecutiveDays.
  ///
  /// In en, this message translates to:
  /// **'Several training days in a row - consider a rest day'**
  String get warningConsecutiveDays;

  /// No description provided for @warningConsecutiveSameMuscle.
  ///
  /// In en, this message translates to:
  /// **'The same muscle group appears on back-to-back days'**
  String get warningConsecutiveSameMuscle;

  /// No description provided for @restDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDayLabel;

  /// No description provided for @markRestDay.
  ///
  /// In en, this message translates to:
  /// **'Mark rest day'**
  String get markRestDay;

  /// No description provided for @statusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPlanned;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// Primary call-to-action button on the landing screen.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Romanised AALUMAI brand name shown on the landing screen.
  ///
  /// In en, this message translates to:
  /// **'AALUMAI'**
  String get landingBrandLatin;

  /// Tamil-script AALUMAI brand name shown on the landing screen.
  ///
  /// In en, this message translates to:
  /// **'ஆளுமை'**
  String get landingBrandNative;

  /// English tagline shown on the landing screen.
  ///
  /// In en, this message translates to:
  /// **'Your life. Your control.'**
  String get landingTaglineEnglish;

  /// Tamil tagline shown on the landing screen.
  ///
  /// In en, this message translates to:
  /// **'உங்கள் வாழ்க்கை. உங்கள் கட்டுப்பாடு.'**
  String get landingTaglineNative;

  /// No description provided for @featureSmartAlarms.
  ///
  /// In en, this message translates to:
  /// **'Smart Alarms'**
  String get featureSmartAlarms;

  /// No description provided for @featureSmartAlarmsDesc.
  ///
  /// In en, this message translates to:
  /// **'Wake up with purpose'**
  String get featureSmartAlarmsDesc;

  /// No description provided for @featureFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness & Workouts'**
  String get featureFitness;

  /// No description provided for @featureFitnessDesc.
  ///
  /// In en, this message translates to:
  /// **'Be healthy and strong'**
  String get featureFitnessDesc;

  /// No description provided for @featureMusic.
  ///
  /// In en, this message translates to:
  /// **'Music Player'**
  String get featureMusic;

  /// No description provided for @featureMusicDesc.
  ///
  /// In en, this message translates to:
  /// **'Your songs, your mood'**
  String get featureMusicDesc;

  /// No description provided for @featureHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits & Tasks'**
  String get featureHabits;

  /// No description provided for @featureHabitsDesc.
  ///
  /// In en, this message translates to:
  /// **'Build a better routine'**
  String get featureHabitsDesc;

  /// No description provided for @featureExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses & Savings'**
  String get featureExpenses;

  /// No description provided for @featureExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Track and grow'**
  String get featureExpensesDesc;

  /// No description provided for @featureCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar & Notes'**
  String get featureCalendar;

  /// No description provided for @featureCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'Stay organized'**
  String get featureCalendarDesc;

  /// No description provided for @formTips.
  ///
  /// In en, this message translates to:
  /// **'Form tips'**
  String get formTips;

  /// No description provided for @commonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get commonMistakes;

  /// No description provided for @contraindications.
  ///
  /// In en, this message translates to:
  /// **'When to avoid'**
  String get contraindications;

  /// No description provided for @alternatives.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get alternatives;

  /// No description provided for @easierAlternative.
  ///
  /// In en, this message translates to:
  /// **'Easier'**
  String get easierAlternative;

  /// No description provided for @harderAlternative.
  ///
  /// In en, this message translates to:
  /// **'Harder'**
  String get harderAlternative;

  /// No description provided for @typeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get typeStrength;

  /// No description provided for @typeCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get typeCardio;

  /// No description provided for @typeMobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get typeMobility;

  /// No description provided for @typeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get typeBalance;

  /// No description provided for @readinessCheck.
  ///
  /// In en, this message translates to:
  /// **'Readiness check'**
  String get readinessCheck;

  /// No description provided for @readinessIntro.
  ///
  /// In en, this message translates to:
  /// **'A quick check before you train'**
  String get readinessIntro;

  /// No description provided for @energyLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energyLabel;

  /// No description provided for @sorenessLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle soreness'**
  String get sorenessLabel;

  /// No description provided for @sleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Sleep quality'**
  String get sleepLabel;

  /// No description provided for @lowReadinessHint.
  ///
  /// In en, this message translates to:
  /// **'Your readiness looks low. Consider a lighter, shorter session.'**
  String get lowReadinessHint;

  /// No description provided for @iAmReady.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready'**
  String get iAmReady;

  /// No description provided for @mainWork.
  ///
  /// In en, this message translates to:
  /// **'Main work'**
  String get mainWork;

  /// No description provided for @lowerIntensityHint.
  ///
  /// In en, this message translates to:
  /// **'Ease off the intensity today.'**
  String get lowerIntensityHint;

  /// No description provided for @sessionOutcomePartial.
  ///
  /// In en, this message translates to:
  /// **'Partly completed'**
  String get sessionOutcomePartial;

  /// No description provided for @sessionOutcomeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ended early'**
  String get sessionOutcomeCancelled;

  /// No description provided for @activityGuidance.
  ///
  /// In en, this message translates to:
  /// **'Activity guidance'**
  String get activityGuidance;

  /// No description provided for @whoAttribution.
  ///
  /// In en, this message translates to:
  /// **'Informed by WHO physical-activity guidance'**
  String get whoAttribution;

  /// No description provided for @dailyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Daily workout'**
  String get dailyWorkout;

  /// No description provided for @startTodaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start today\'s workout'**
  String get startTodaysWorkout;

  /// No description provided for @cardioEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Cardio every day'**
  String get cardioEveryDay;

  /// No description provided for @yogaCooldown.
  ///
  /// In en, this message translates to:
  /// **'Yoga cool-down'**
  String get yogaCooldown;

  /// No description provided for @activeRecoveryDay.
  ///
  /// In en, this message translates to:
  /// **'Active recovery'**
  String get activeRecoveryDay;

  /// No description provided for @yogaAfterWorkout.
  ///
  /// In en, this message translates to:
  /// **'Yoga is best after the workout, as a cool-down.'**
  String get yogaAfterWorkout;

  /// No description provided for @whoAerobicLabel.
  ///
  /// In en, this message translates to:
  /// **'Aerobic activity'**
  String get whoAerobicLabel;

  /// No description provided for @whoStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle strengthening'**
  String get whoStrengthLabel;

  /// No description provided for @whoAerobicValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} / 150 min'**
  String whoAerobicValue(int minutes);

  /// No description provided for @whoStrengthValue.
  ///
  /// In en, this message translates to:
  /// **'{days} / 2 days'**
  String whoStrengthValue(int days);

  /// No description provided for @whoAerobicGoal.
  ///
  /// In en, this message translates to:
  /// **'Aim for 150-300 minutes a week'**
  String get whoAerobicGoal;

  /// No description provided for @whoStrengthGoal.
  ///
  /// In en, this message translates to:
  /// **'Aim for at least 2 days a week'**
  String get whoStrengthGoal;

  /// No description provided for @whoDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'General information, not medical advice. If you have a health condition, seek professional guidance before starting.'**
  String get whoDisclaimer;

  /// No description provided for @whoGoalMet.
  ///
  /// In en, this message translates to:
  /// **'Guideline met'**
  String get whoGoalMet;

  /// No description provided for @whoKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get whoKeepGoing;

  /// No description provided for @whoTips.
  ///
  /// In en, this message translates to:
  /// **'Guidance tips'**
  String get whoTips;

  /// No description provided for @whoTipProgression.
  ///
  /// In en, this message translates to:
  /// **'Start gradually and increase a little each week.'**
  String get whoTipProgression;

  /// No description provided for @whoTipWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking and cycling count toward your aerobic goal.'**
  String get whoTipWalking;

  /// No description provided for @whoTipStrength.
  ///
  /// In en, this message translates to:
  /// **'Spread strength days across the week, with rest days in between.'**
  String get whoTipStrength;

  /// No description provided for @whoTipAdapt.
  ///
  /// In en, this message translates to:
  /// **'Adjust intensity to your age and ability, and choose easier variations when needed.'**
  String get whoTipAdapt;

  /// No description provided for @safetyTemplateNote.
  ///
  /// In en, this message translates to:
  /// **'Exercises such as push-ups and planks are examples you can adjust - choose easier variations or swap them out as needed.'**
  String get safetyTemplateNote;

  /// No description provided for @alarmSoundAndMotivation.
  ///
  /// In en, this message translates to:
  /// **'Alarm Sound & Motivation'**
  String get alarmSoundAndMotivation;

  /// No description provided for @alarmMusic.
  ///
  /// In en, this message translates to:
  /// **'Alarm music'**
  String get alarmMusic;

  /// No description provided for @alarmMusicHint.
  ///
  /// In en, this message translates to:
  /// **'Plays while the alarm rings'**
  String get alarmMusicHint;

  /// No description provided for @soundMode.
  ///
  /// In en, this message translates to:
  /// **'Sound mode'**
  String get soundMode;

  /// No description provided for @soundModeMusicVoice.
  ///
  /// In en, this message translates to:
  /// **'Music + Motivation Voice'**
  String get soundModeMusicVoice;

  /// No description provided for @soundModeVoiceOnly.
  ///
  /// In en, this message translates to:
  /// **'Voice Only'**
  String get soundModeVoiceOnly;

  /// No description provided for @soundModeMusicOnly.
  ///
  /// In en, this message translates to:
  /// **'Music Only'**
  String get soundModeMusicOnly;

  /// No description provided for @motivationalMessage.
  ///
  /// In en, this message translates to:
  /// **'Motivational message'**
  String get motivationalMessage;

  /// No description provided for @motivationalMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Repeats on the music interval while you solve challenges'**
  String get motivationalMessageHint;

  /// No description provided for @finalMotivationalMessage.
  ///
  /// In en, this message translates to:
  /// **'Final motivation'**
  String get finalMotivationalMessage;

  /// No description provided for @finalMotivationalMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Spoken once after every challenge — tap Done to close'**
  String get finalMotivationalMessageHint;

  /// No description provided for @useSampleMessage.
  ///
  /// In en, this message translates to:
  /// **'Use sample message'**
  String get useSampleMessage;

  /// No description provided for @voicePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview voice'**
  String get voicePreview;

  /// No description provided for @voicePreviewing.
  ///
  /// In en, this message translates to:
  /// **'Previewing…'**
  String get voicePreviewing;

  /// No description provided for @voicePreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice preview isn\'t available. Check the alarm voice settings.'**
  String get voicePreviewFailed;

  /// No description provided for @alarmVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'{gender} voice · {language}'**
  String alarmVoiceLabel(String gender, String language);

  /// No description provided for @changeInSettings.
  ///
  /// In en, this message translates to:
  /// **'Change in Settings'**
  String get changeInSettings;

  /// No description provided for @musicInterval.
  ///
  /// In en, this message translates to:
  /// **'Music interval'**
  String get musicInterval;

  /// No description provided for @musicIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'How long music plays before the next message while ringing'**
  String get musicIntervalHint;

  /// No description provided for @customInterval.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customInterval;

  /// No description provided for @customIntervalSeconds.
  ///
  /// In en, this message translates to:
  /// **'Custom interval (seconds)'**
  String get customIntervalSeconds;

  /// No description provided for @customIntervalValue.
  ///
  /// In en, this message translates to:
  /// **'{count} sec'**
  String customIntervalValue(int count);

  /// No description provided for @voiceTiming.
  ///
  /// In en, this message translates to:
  /// **'Voice timing'**
  String get voiceTiming;

  /// No description provided for @voiceTimingBeforeMusic.
  ///
  /// In en, this message translates to:
  /// **'Speak before music starts'**
  String get voiceTimingBeforeMusic;

  /// No description provided for @voiceTimingBetweenSegments.
  ///
  /// In en, this message translates to:
  /// **'Speak between music segments'**
  String get voiceTimingBetweenSegments;

  /// No description provided for @voiceTimingOverMusic.
  ///
  /// In en, this message translates to:
  /// **'Speak over the music'**
  String get voiceTimingOverMusic;

  /// No description provided for @voicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause between messages'**
  String get voicePause;

  /// No description provided for @voiceOnlyNeedsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a message, or choose Music Only.'**
  String get voiceOnlyNeedsMessage;

  /// No description provided for @invalidInterval.
  ///
  /// In en, this message translates to:
  /// **'Enter a value greater than zero.'**
  String get invalidInterval;

  /// No description provided for @settingsAlarmVoice.
  ///
  /// In en, this message translates to:
  /// **'Alarm voice'**
  String get settingsAlarmVoice;

  /// No description provided for @settingsAlarmVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Voice, language, rate and pitch for alarms'**
  String get settingsAlarmVoiceDesc;

  /// No description provided for @alarmVoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Alarm Voice Settings'**
  String get alarmVoiceSettings;

  /// No description provided for @voiceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Voice language'**
  String get voiceLanguage;

  /// No description provided for @followAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow app language'**
  String get followAppLanguage;

  /// No description provided for @voiceSelect.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceSelect;

  /// No description provided for @voiceDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'Device default'**
  String get voiceDeviceDefault;

  /// No description provided for @voiceDeviceDefaultDesc.
  ///
  /// In en, this message translates to:
  /// **'Use any available voice'**
  String get voiceDeviceDefaultDesc;

  /// No description provided for @voiceGender.
  ///
  /// In en, this message translates to:
  /// **'Voice gender'**
  String get voiceGender;

  /// No description provided for @genderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default / Any'**
  String get genderDefault;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @speechPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get speechPitch;

  /// No description provided for @speechVolume.
  ///
  /// In en, this message translates to:
  /// **'Speech volume'**
  String get speechVolume;

  /// No description provided for @resetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetDefault;

  /// No description provided for @voicesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading voices…'**
  String get voicesLoading;

  /// No description provided for @noInstalledVoices.
  ///
  /// In en, this message translates to:
  /// **'No installed voices were found.'**
  String get noInstalledVoices;

  /// No description provided for @voiceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the installed voices.'**
  String get voiceLoadFailed;

  /// No description provided for @openTtsSettings.
  ///
  /// In en, this message translates to:
  /// **'Open TTS settings'**
  String get openTtsSettings;

  /// No description provided for @ttsSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the system TTS settings.'**
  String get ttsSettingsUnavailable;

  /// No description provided for @voiceUnavailableForLanguage.
  ///
  /// In en, this message translates to:
  /// **'No {language} voice is installed. Install a language pack in Android settings.'**
  String voiceUnavailableForLanguage(String language);

  /// No description provided for @voiceGenderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The chosen gender isn\'t available for this voice; using the closest match.'**
  String get voiceGenderUnavailable;

  /// No description provided for @voiceFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'The selected voice is no longer available, so the device default is used.'**
  String get voiceFallbackNote;

  /// No description provided for @previewSentence.
  ///
  /// In en, this message translates to:
  /// **'This is how your alarm voice will sound.'**
  String get previewSentence;

  /// No description provided for @saveActivityPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save this activity?'**
  String get saveActivityPrompt;

  /// No description provided for @personalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best'**
  String get personalBest;

  /// No description provided for @newPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'New personal best'**
  String get newPersonalBest;

  /// No description provided for @unfinishedPlan.
  ///
  /// In en, this message translates to:
  /// **'This plan has an unfinished workout.'**
  String get unfinishedPlan;

  /// No description provided for @startFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get startFresh;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get yoga;

  /// No description provided for @yogaToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s yoga'**
  String get yogaToday;

  /// No description provided for @yogaRecommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get yogaRecommendedForYou;

  /// No description provided for @yogaRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get yogaRoutines;

  /// No description provided for @yogaPoses.
  ///
  /// In en, this message translates to:
  /// **'Poses'**
  String get yogaPoses;

  /// No description provided for @yogaStartRoutine.
  ///
  /// In en, this message translates to:
  /// **'Start routine'**
  String get yogaStartRoutine;

  /// No description provided for @yogaSync.
  ///
  /// In en, this message translates to:
  /// **'Update poses'**
  String get yogaSync;

  /// No description provided for @yogaSynced.
  ///
  /// In en, this message translates to:
  /// **'Updated {count} poses'**
  String yogaSynced(int count);

  /// No description provided for @yogaSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the yoga service. Showing offline poses.'**
  String get yogaSyncFailed;

  /// No description provided for @yogaOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Poses are stored on your device and work offline.'**
  String get yogaOfflineNote;

  /// No description provided for @yogaLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get yogaLevel;

  /// No description provided for @yogaLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get yogaLevelBeginner;

  /// No description provided for @yogaLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get yogaLevelIntermediate;

  /// No description provided for @yogaLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get yogaLevelAdvanced;

  /// No description provided for @yogaPoseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} poses'**
  String yogaPoseCount(int count);

  /// No description provided for @yogaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String yogaMinutes(int count);

  /// No description provided for @yogaInstructions.
  ///
  /// In en, this message translates to:
  /// **'How to practise'**
  String get yogaInstructions;

  /// No description provided for @yogaBenefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get yogaBenefits;

  /// No description provided for @yogaBreathing.
  ///
  /// In en, this message translates to:
  /// **'Breathing'**
  String get yogaBreathing;

  /// No description provided for @yogaTakeCare.
  ///
  /// In en, this message translates to:
  /// **'Take care'**
  String get yogaTakeCare;

  /// No description provided for @yogaNoImage.
  ///
  /// In en, this message translates to:
  /// **'No verified image is available for this pose.'**
  String get yogaNoImage;

  /// No description provided for @yogaAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get yogaAddFavorite;

  /// No description provided for @yogaRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get yogaRemoveFavorite;

  /// No description provided for @yogaFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get yogaFavorites;

  /// No description provided for @yogaNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favourite poses yet.'**
  String get yogaNoFavorites;

  /// No description provided for @yogaHistory.
  ///
  /// In en, this message translates to:
  /// **'Yoga history'**
  String get yogaHistory;

  /// No description provided for @yogaNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No yoga sessions yet.'**
  String get yogaNoHistory;

  /// No description provided for @yogaSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get yogaSkip;

  /// No description provided for @yogaNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get yogaNext;

  /// No description provided for @yogaPrevious.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get yogaPrevious;

  /// No description provided for @yogaPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get yogaPause;

  /// No description provided for @yogaResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get yogaResume;

  /// No description provided for @yogaFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get yogaFinish;

  /// No description provided for @yogaFinishPrompt.
  ///
  /// In en, this message translates to:
  /// **'Finish the session?'**
  String get yogaFinishPrompt;

  /// No description provided for @yogaSessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Yoga session complete'**
  String get yogaSessionComplete;

  /// No description provided for @yogaPoseOf.
  ///
  /// In en, this message translates to:
  /// **'Pose {current} of {total}'**
  String yogaPoseOf(int current, int total);

  /// No description provided for @yogaSearchPoses.
  ///
  /// In en, this message translates to:
  /// **'Search poses'**
  String get yogaSearchPoses;

  /// No description provided for @yogaAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get yogaAllCategories;

  /// No description provided for @yogaCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get yogaCategoryOther;

  /// No description provided for @yogaGetReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready'**
  String get yogaGetReady;

  /// No description provided for @yogaDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get yogaDone;

  /// No description provided for @yogaAttribution.
  ///
  /// In en, this message translates to:
  /// **'Pose data from the yoga-api open dataset. General information only — not medical advice.'**
  String get yogaAttribution;

  /// No description provided for @yogaSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Move within a comfortable range. Stop if you feel pain, and see a health professional if you have a medical condition.'**
  String get yogaSafetyNote;

  /// No description provided for @yogaPickLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose a level'**
  String get yogaPickLevel;

  /// No description provided for @yogaLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last updated {when}'**
  String yogaLastSynced(String when);

  /// No description provided for @yogaNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not yet updated from the service'**
  String get yogaNeverSynced;

  /// No description provided for @yogaStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get yogaStart;

  /// No description provided for @yogaOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get yogaOverview;

  /// No description provided for @yogaNoResults.
  ///
  /// In en, this message translates to:
  /// **'No yoga poses match your search.'**
  String get yogaNoResults;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @customizeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Customize workout'**
  String get customizeWorkout;

  /// No description provided for @dumbbellWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell and barbell exercises use your own weights. Log the weight you lift during each set.'**
  String get dumbbellWeightHint;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDay;

  /// No description provided for @workoutSettings.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutSettings;

  /// No description provided for @workoutSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the equipment and muscle groups for your daily workout'**
  String get workoutSettingsDesc;

  /// No description provided for @workoutCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Tick the equipment and muscle groups you want in your daily workout. Only the ticked options are used to build each day.'**
  String get workoutCategoriesHint;

  /// No description provided for @equipmentBodyweight.
  ///
  /// In en, this message translates to:
  /// **'No equipment (bodyweight)'**
  String get equipmentBodyweight;

  /// No description provided for @jarvisTitle.
  ///
  /// In en, this message translates to:
  /// **'Jarvis'**
  String get jarvisTitle;

  /// No description provided for @jarvisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On-device AI assistant'**
  String get jarvisSubtitle;

  /// No description provided for @jarvisChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get jarvisChat;

  /// No description provided for @jarvisModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get jarvisModel;

  /// No description provided for @jarvisMemories.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get jarvisMemories;

  /// No description provided for @jarvisChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Ask anything — Jarvis runs entirely on this device.'**
  String get jarvisChatEmpty;

  /// No description provided for @jarvisInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message Jarvis…'**
  String get jarvisInputHint;

  /// No description provided for @jarvisSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get jarvisSend;

  /// No description provided for @jarvisStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get jarvisStop;

  /// No description provided for @jarvisClearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get jarvisClearChat;

  /// No description provided for @jarvisThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get jarvisThinking;

  /// No description provided for @jarvisAllowAction.
  ///
  /// In en, this message translates to:
  /// **'Allow this action?'**
  String get jarvisAllowAction;

  /// No description provided for @jarvisAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get jarvisAllow;

  /// No description provided for @jarvisDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get jarvisDecline;

  /// No description provided for @jarvisNoModel.
  ///
  /// In en, this message translates to:
  /// **'No model installed yet.'**
  String get jarvisNoModel;

  /// No description provided for @jarvisModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Model installed'**
  String get jarvisModelInstalled;

  /// No description provided for @jarvisModelLoaded.
  ///
  /// In en, this message translates to:
  /// **'Model loaded — ready for chat'**
  String get jarvisModelLoaded;

  /// No description provided for @jarvisModelNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Model not loaded'**
  String get jarvisModelNotLoaded;

  /// No description provided for @jarvisDownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download model (~1.3 GB)'**
  String get jarvisDownloadModel;

  /// No description provided for @jarvisImportModel.
  ///
  /// In en, this message translates to:
  /// **'Import a GGUF file'**
  String get jarvisImportModel;

  /// No description provided for @jarvisDeleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get jarvisDeleteModel;

  /// No description provided for @jarvisLoadModel.
  ///
  /// In en, this message translates to:
  /// **'Load model'**
  String get jarvisLoadModel;

  /// No description provided for @jarvisUnloadModel.
  ///
  /// In en, this message translates to:
  /// **'Unload model'**
  String get jarvisUnloadModel;

  /// No description provided for @jarvisDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get jarvisDownloading;

  /// No description provided for @jarvisVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get jarvisVerifying;

  /// No description provided for @jarvisCpuThreads.
  ///
  /// In en, this message translates to:
  /// **'CPU threads'**
  String get jarvisCpuThreads;

  /// No description provided for @jarvisContextSize.
  ///
  /// In en, this message translates to:
  /// **'Context size'**
  String get jarvisContextSize;

  /// No description provided for @jarvisNoMemories.
  ///
  /// In en, this message translates to:
  /// **'No memories saved yet.'**
  String get jarvisNoMemories;

  /// No description provided for @jarvisConfirmMemory.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get jarvisConfirmMemory;

  /// No description provided for @jarvisPendingMemory.
  ///
  /// In en, this message translates to:
  /// **'Pending confirmation'**
  String get jarvisPendingMemory;

  /// No description provided for @jarvisForgetMemory.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get jarvisForgetMemory;

  /// No description provided for @jarvisAddMemory.
  ///
  /// In en, this message translates to:
  /// **'Save a memory'**
  String get jarvisAddMemory;

  /// No description provided for @jarvisMemoryHint.
  ///
  /// In en, this message translates to:
  /// **'A fact or preference Jarvis should remember'**
  String get jarvisMemoryHint;

  /// No description provided for @jarvisDeleteModelWarning.
  ///
  /// In en, this message translates to:
  /// **'Delete the installed model? You can download or import it again later.'**
  String get jarvisDeleteModelWarning;

  /// No description provided for @jarvisMicHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to speak'**
  String get jarvisMicHold;

  /// No description provided for @jarvisSpeakReplies.
  ///
  /// In en, this message translates to:
  /// **'Speak replies'**
  String get jarvisSpeakReplies;

  /// No description provided for @jarvisBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning briefing'**
  String get jarvisBriefingTitle;

  /// No description provided for @jarvisBriefingTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks due'**
  String jarvisBriefingTasks(Object count);

  /// No description provided for @jarvisBriefingEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} events today'**
  String jarvisBriefingEvents(Object count);

  /// No description provided for @jarvisBriefingAlarm.
  ///
  /// In en, this message translates to:
  /// **'Next alarm {time}'**
  String jarvisBriefingAlarm(Object time);

  /// No description provided for @jarvisBriefingQuiet.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today — a clear morning.'**
  String get jarvisBriefingQuiet;

  /// No description provided for @jarvisBriefingToggle.
  ///
  /// In en, this message translates to:
  /// **'Daily briefing'**
  String get jarvisBriefingToggle;

  /// No description provided for @jarvisBriefingToggleHint.
  ///
  /// In en, this message translates to:
  /// **'A summary notification at 08:00 each morning.'**
  String get jarvisBriefingToggleHint;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'kn', 'ml', 'ta', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'kn': return AppLocalizationsKn();
    case 'ml': return AppLocalizationsMl();
    case 'ta': return AppLocalizationsTa();
    case 'te': return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
