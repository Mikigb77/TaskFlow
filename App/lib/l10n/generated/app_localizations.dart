import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('es')
  ];

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @yourCalendar.
  ///
  /// In en, this message translates to:
  /// **'Your calendar'**
  String get yourCalendar;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @inboxCount.
  ///
  /// In en, this message translates to:
  /// **'Inbox · {count}'**
  String inboxCount(int count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDate;

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get chooseDate;

  /// No description provided for @chooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose time'**
  String get chooseTime;

  /// No description provided for @removeDate.
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get removeDate;

  /// No description provided for @removeTime.
  ///
  /// In en, this message translates to:
  /// **'Remove time'**
  String get removeTime;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @sayTask.
  ///
  /// In en, this message translates to:
  /// **'Say a task'**
  String get sayTask;

  /// No description provided for @typeTasks.
  ///
  /// In en, this message translates to:
  /// **'Type tasks'**
  String get typeTasks;

  /// No description provided for @unfinishedCaptures.
  ///
  /// In en, this message translates to:
  /// **'Unfinished captures'**
  String get unfinishedCaptures;

  /// No description provided for @captureDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Capture diagnostics'**
  String get captureDiagnostics;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @noList.
  ///
  /// In en, this message translates to:
  /// **'No list'**
  String get noList;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

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

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @neverRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get neverRepeat;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @addNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get addNotes;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

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

  /// No description provided for @keepChanges.
  ///
  /// In en, this message translates to:
  /// **'Keep changes'**
  String get keepChanges;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get createTask;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitle;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get additionalNotes;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetails;

  /// No description provided for @fewerDetails.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get fewerDetails;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @chooseAppearance.
  ///
  /// In en, this message translates to:
  /// **'Choose your appearance'**
  String get chooseAppearance;

  /// No description provided for @appearanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose your look, or follow your device.'**
  String get appearanceHelp;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @yourSpace.
  ///
  /// In en, this message translates to:
  /// **'Your space'**
  String get yourSpace;

  /// No description provided for @welcomeSettings.
  ///
  /// In en, this message translates to:
  /// **'Make yourself at home'**
  String get welcomeSettings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Reminder choices and upcoming alerts'**
  String get notificationsHelp;

  /// No description provided for @accountBackup.
  ///
  /// In en, this message translates to:
  /// **'Account & backup'**
  String get accountBackup;

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks'**
  String get completedTasks;

  /// No description provided for @progressHelp.
  ///
  /// In en, this message translates to:
  /// **'A little record of your progress'**
  String get progressHelp;

  /// No description provided for @exportImport.
  ///
  /// In en, this message translates to:
  /// **'Export & import'**
  String get exportImport;

  /// No description provided for @exportImportHelp.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow backups and Todoist CSV migration'**
  String get exportImportHelp;

  /// No description provided for @regionalSettings.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get regionalSettings;

  /// No description provided for @regionalSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Language, clock, week start and capture timezone'**
  String get regionalSettingsHelp;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @deviceDefault.
  ///
  /// In en, this message translates to:
  /// **'Follow device'**
  String get deviceDefault;

  /// No description provided for @clockFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get clockFormat;

  /// No description provided for @clock12.
  ///
  /// In en, this message translates to:
  /// **'12-hour clock'**
  String get clock12;

  /// No description provided for @clock24.
  ///
  /// In en, this message translates to:
  /// **'24-hour clock'**
  String get clock24;

  /// No description provided for @weekStart.
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get weekStart;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @captureTimezone.
  ///
  /// In en, this message translates to:
  /// **'Capture timezone'**
  String get captureTimezone;

  /// No description provided for @timezoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Used to interpret dates in new captures. Existing tasks and unfinished captures keep their schedules. Task times are displayed in your device timezone.'**
  String get timezoneHelp;

  /// No description provided for @searchTimezone.
  ///
  /// In en, this message translates to:
  /// **'Find a timezone'**
  String get searchTimezone;

  /// No description provided for @regionHelp.
  ///
  /// In en, this message translates to:
  /// **'These preferences stay on this device. Changing them does not change stored task dates or times.'**
  String get regionHelp;

  /// No description provided for @preferenceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference. Please try again.'**
  String get preferenceError;

  /// No description provided for @timezoneFallback.
  ///
  /// In en, this message translates to:
  /// **'The device timezone is unavailable. New captures will use {zone}.'**
  String timezoneFallback(String zone);

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @syncTasks.
  ///
  /// In en, this message translates to:
  /// **'Sync tasks'**
  String get syncTasks;

  /// No description provided for @previousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous month or week'**
  String get previousPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next month or week'**
  String get nextPeriod;

  /// No description provided for @moreClarity.
  ///
  /// In en, this message translates to:
  /// **'More clarity. More room for life.'**
  String get moreClarity;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get licenses;

  /// No description provided for @weekView.
  ///
  /// In en, this message translates to:
  /// **'Week view'**
  String get weekView;

  /// No description provided for @monthView.
  ///
  /// In en, this message translates to:
  /// **'Month view'**
  String get monthView;

  /// No description provided for @todayAgenda.
  ///
  /// In en, this message translates to:
  /// **'Today’s agenda'**
  String get todayAgenda;

  /// No description provided for @breathingRoom.
  ///
  /// In en, this message translates to:
  /// **'A little breathing room.'**
  String get breathingRoom;

  /// No description provided for @loadTasksError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your tasks'**
  String get loadTasksError;

  /// No description provided for @refreshCalendar.
  ///
  /// In en, this message translates to:
  /// **'Try refreshing your calendar.'**
  String get refreshCalendar;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @rememberPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to remember?'**
  String get rememberPrompt;

  /// No description provided for @calendarEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap Say a task and speak naturally, or New task to type. Dates are optional; unscheduled tasks go to Inbox.'**
  String get calendarEmpty;

  /// No description provided for @planTask.
  ///
  /// In en, this message translates to:
  /// **'Plan a task'**
  String get planTask;

  /// No description provided for @homeCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture from your home screen'**
  String get homeCapture;

  /// No description provided for @homeCaptureHelp.
  ///
  /// In en, this message translates to:
  /// **'Android mic widget, app shortcuts and text sharing'**
  String get homeCaptureHelp;

  /// No description provided for @homeCaptureInstructions.
  ///
  /// In en, this message translates to:
  /// **'On Android, long-press the TaskFlow icon for capture shortcuts, or add the Say a task widget from your launcher. Share text to TaskFlow from another app.'**
  String get homeCaptureInstructions;

  /// No description provided for @widgetPickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Add the TaskFlow widget from your launcher’s widget picker.'**
  String get widgetPickerHelp;

  /// No description provided for @signInHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your tasks with you'**
  String get signInHelp;

  /// No description provided for @diagnosticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Local timing and counters, without your words'**
  String get diagnosticsHelp;

  /// No description provided for @appearanceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your appearance preference.'**
  String get appearanceError;

  /// No description provided for @appearanceChangedError.
  ///
  /// In en, this message translates to:
  /// **'Appearance changed. Could not save the preference on this device.'**
  String get appearanceChangedError;

  /// No description provided for @switchLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchLight;

  /// No description provided for @switchDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchDark;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @archivedList.
  ///
  /// In en, this message translates to:
  /// **'Archived list'**
  String get archivedList;

  /// No description provided for @yourList.
  ///
  /// In en, this message translates to:
  /// **'Your list'**
  String get yourList;

  /// No description provided for @yourTasks.
  ///
  /// In en, this message translates to:
  /// **'Your tasks'**
  String get yourTasks;

  /// No description provided for @everythingToDo.
  ///
  /// In en, this message translates to:
  /// **'Everything you want to do'**
  String get everythingToDo;

  /// No description provided for @noDateNeeded.
  ///
  /// In en, this message translates to:
  /// **'No date needed'**
  String get noDateNeeded;

  /// No description provided for @findTask.
  ///
  /// In en, this message translates to:
  /// **'Find a task…'**
  String get findTask;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasks;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get highPriority;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by label'**
  String get filterLabel;

  /// No description provided for @allLabels.
  ///
  /// In en, this message translates to:
  /// **'All labels'**
  String get allLabels;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get noMatches;

  /// No description provided for @freshStart.
  ///
  /// In en, this message translates to:
  /// **'A fresh start'**
  String get freshStart;

  /// No description provided for @differentFilter.
  ///
  /// In en, this message translates to:
  /// **'Try a different word or filter.'**
  String get differentFilter;

  /// No description provided for @listEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a task to this list. Its date and reminder are yours to choose.'**
  String get listEmpty;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Use Say a task to speak, or New task to type.\nAdd a date now or leave it for later.'**
  String get tasksEmpty;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Keep ideas and to-dos here until you choose a date.\nUse Say a task or New task to begin.'**
  String get inboxEmpty;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your saved tasks are still on your device.'**
  String get savedOnDevice;

  /// No description provided for @checkCaptures.
  ///
  /// In en, this message translates to:
  /// **'Check unfinished captures'**
  String get checkCaptures;

  /// No description provided for @createVoiceTask.
  ///
  /// In en, this message translates to:
  /// **'Create task with voice'**
  String get createVoiceTask;

  /// No description provided for @createTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get createTaskTooltip;

  /// No description provided for @reviewTask.
  ///
  /// In en, this message translates to:
  /// **'Review task'**
  String get reviewTask;

  /// No description provided for @fineTunePlan.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune your plan.'**
  String get fineTunePlan;

  /// No description provided for @onYourMind.
  ///
  /// In en, this message translates to:
  /// **'What’s on your mind?'**
  String get onYourMind;

  /// No description provided for @wordsPlan.
  ///
  /// In en, this message translates to:
  /// **'Your words, a clear plan.'**
  String get wordsPlan;

  /// No description provided for @seriesEdits.
  ///
  /// In en, this message translates to:
  /// **'Edits apply to the whole repeating task.'**
  String get seriesEdits;

  /// No description provided for @giveName.
  ///
  /// In en, this message translates to:
  /// **'Give it a name. Add a date whenever you’re ready.'**
  String get giveName;

  /// No description provided for @checkBeforeAdd.
  ///
  /// In en, this message translates to:
  /// **'Check the details before adding it to your calendar.'**
  String get checkBeforeAdd;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title.'**
  String get titleRequired;

  /// No description provided for @nameTask.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get nameTask;

  /// No description provided for @chooseReminder.
  ///
  /// In en, this message translates to:
  /// **'Choose reminder'**
  String get chooseReminder;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @useReminder.
  ///
  /// In en, this message translates to:
  /// **'Use reminder'**
  String get useReminder;

  /// No description provided for @dateForReminder.
  ///
  /// In en, this message translates to:
  /// **'Add a date to use a reminder'**
  String get dateForReminder;

  /// No description provided for @chooseAlertTime.
  ///
  /// In en, this message translates to:
  /// **'Choose alert time'**
  String get chooseAlertTime;

  /// No description provided for @defaultTime.
  ///
  /// In en, this message translates to:
  /// **'Use default time'**
  String get defaultTime;

  /// No description provided for @reminderDefaultsError.
  ///
  /// In en, this message translates to:
  /// **'Reminder defaults could not load. Check notification settings.'**
  String get reminderDefaultsError;

  /// No description provided for @loadingReminders.
  ///
  /// In en, this message translates to:
  /// **'Loading reminder settings…'**
  String get loadingReminders;

  /// No description provided for @remindersDisabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off on this device'**
  String get remindersDisabled;

  /// No description provided for @repeatInterval.
  ///
  /// In en, this message translates to:
  /// **'Repeat interval'**
  String get repeatInterval;

  /// No description provided for @repeatOn.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get repeatOn;

  /// No description provided for @repeatUsesStart.
  ///
  /// In en, this message translates to:
  /// **'Uses the weekday of the start date.'**
  String get repeatUsesStart;

  /// No description provided for @intervalRange.
  ///
  /// In en, this message translates to:
  /// **'Choose a number from 1 to 99.'**
  String get intervalRange;

  /// No description provided for @removeEndDate.
  ///
  /// In en, this message translates to:
  /// **'Remove end date'**
  String get removeEndDate;

  /// No description provided for @keepRepeat.
  ///
  /// In en, this message translates to:
  /// **'Keep repeat'**
  String get keepRepeat;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get weeks;

  /// No description provided for @months.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get months;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @deleteTaskQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskQuestion;

  /// No description provided for @keepTask.
  ///
  /// In en, this message translates to:
  /// **'Keep task'**
  String get keepTask;

  /// No description provided for @deleteTaskError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this task. Please try again.'**
  String get deleteTaskError;

  /// No description provided for @attachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This attachment is not available on this device.'**
  String get attachmentUnavailable;

  /// No description provided for @attachmentOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this attachment.'**
  String get attachmentOpenError;

  /// No description provided for @taskUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Task unavailable'**
  String get taskUnavailable;

  /// No description provided for @occurrenceChanged.
  ///
  /// In en, this message translates to:
  /// **'Occurrence changed'**
  String get occurrenceChanged;

  /// No description provided for @taskRemoved.
  ///
  /// In en, this message translates to:
  /// **'This task may have been removed.'**
  String get taskRemoved;

  /// No description provided for @occurrenceSkipped.
  ///
  /// In en, this message translates to:
  /// **'This date is skipped or no longer part of the repeating schedule.'**
  String get occurrenceSkipped;

  /// No description provided for @editRepeating.
  ///
  /// In en, this message translates to:
  /// **'Edit repeating task'**
  String get editRepeating;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Your next step'**
  String get nextStep;

  /// No description provided for @moveError.
  ///
  /// In en, this message translates to:
  /// **'Could not move this task. Please retry.'**
  String get moveError;

  /// No description provided for @occurrence.
  ///
  /// In en, this message translates to:
  /// **'Occurrence'**
  String get occurrence;

  /// No description provided for @starts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get starts;

  /// No description provided for @inboxDate.
  ///
  /// In en, this message translates to:
  /// **'No date · Inbox'**
  String get inboxDate;

  /// No description provided for @updateReminderError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the reminder. Please retry.'**
  String get updateReminderError;

  /// No description provided for @thisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'This occurrence'**
  String get thisOccurrence;

  /// No description provided for @wholeSeries.
  ///
  /// In en, this message translates to:
  /// **'Whole series'**
  String get wholeSeries;

  /// No description provided for @skipOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence'**
  String get skipOccurrence;

  /// No description provided for @resetOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Reset this occurrence'**
  String get resetOccurrence;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @captureThought.
  ///
  /// In en, this message translates to:
  /// **'Capture a thought'**
  String get captureThought;

  /// No description provided for @captureIntro.
  ///
  /// In en, this message translates to:
  /// **'One task or several. Say it naturally, or type your plan.'**
  String get captureIntro;

  /// No description provided for @stopDraft.
  ///
  /// In en, this message translates to:
  /// **'Stop and create draft'**
  String get stopDraft;

  /// No description provided for @recordTasks.
  ///
  /// In en, this message translates to:
  /// **'Record tasks'**
  String get recordTasks;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @puttingPlanTogether.
  ///
  /// In en, this message translates to:
  /// **'Putting your plan together…'**
  String get puttingPlanTogether;

  /// No description provided for @recordingKept.
  ///
  /// In en, this message translates to:
  /// **'Recording kept on this phone'**
  String get recordingKept;

  /// No description provided for @tapSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapSpeak;

  /// No description provided for @inputLevel.
  ///
  /// In en, this message translates to:
  /// **'Microphone input level'**
  String get inputLevel;

  /// No description provided for @tapStopHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap stop when you’re finished. Up to 60 seconds.'**
  String get tapStopHelp;

  /// No description provided for @returnCaptureHelp.
  ///
  /// In en, this message translates to:
  /// **'You can leave and return. Unfinished recordings are kept.'**
  String get returnCaptureHelp;

  /// No description provided for @speechOptions.
  ///
  /// In en, this message translates to:
  /// **'Speech options'**
  String get speechOptions;

  /// No description provided for @onDeviceTranscript.
  ///
  /// In en, this message translates to:
  /// **'On-device live transcript'**
  String get onDeviceTranscript;

  /// No description provided for @onlineAudio.
  ///
  /// In en, this message translates to:
  /// **'Saved audio · online transcription'**
  String get onlineAudio;

  /// No description provided for @liveTranscript.
  ///
  /// In en, this message translates to:
  /// **'Live transcript'**
  String get liveTranscript;

  /// No description provided for @savedAudio.
  ///
  /// In en, this message translates to:
  /// **'Saved audio'**
  String get savedAudio;

  /// No description provided for @speechLanguage.
  ///
  /// In en, this message translates to:
  /// **'Speech language'**
  String get speechLanguage;

  /// No description provided for @deviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get deviceLanguage;

  /// No description provided for @onDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'On-device speech is unavailable for this language on this device. Record audio for online processing, or type.'**
  String get onDeviceUnavailable;

  /// No description provided for @setUpSpeech.
  ///
  /// In en, this message translates to:
  /// **'Set up on-device speech'**
  String get setUpSpeech;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @holdTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdTalk;

  /// No description provided for @holdTalkHelp.
  ///
  /// In en, this message translates to:
  /// **'Hold the mic, then release. Tapping still works.'**
  String get holdTalkHelp;

  /// No description provided for @typePlan.
  ///
  /// In en, this message translates to:
  /// **'Or type your plan'**
  String get typePlan;

  /// No description provided for @examplePlan.
  ///
  /// In en, this message translates to:
  /// **'Doctor Friday at 5 p.m. Bring my results. Also buy coffee.'**
  String get examplePlan;

  /// No description provided for @tryRecording.
  ///
  /// In en, this message translates to:
  /// **'Try this recording'**
  String get tryRecording;

  /// No description provided for @reviewText.
  ///
  /// In en, this message translates to:
  /// **'Review tasks from text'**
  String get reviewText;

  /// No description provided for @discardCapture.
  ///
  /// In en, this message translates to:
  /// **'Discard capture'**
  String get discardCapture;

  /// No description provided for @discardCaptureQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard this capture?'**
  String get discardCaptureQuestion;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @guestTrialHelp.
  ///
  /// In en, this message translates to:
  /// **'Try voice without an account. A small daily allowance is shared by devices on this connection.'**
  String get guestTrialHelp;

  /// No description provided for @capturePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Live transcription uses on-device speech where available; no audio is retained in that mode. AI task extraction still needs the internet and sends your words to Google. Saved audio is transcribed online. Unfinished input stays on this phone until you save or discard it.'**
  String get capturePrivacy;

  /// No description provided for @checkTasks.
  ///
  /// In en, this message translates to:
  /// **'Check your tasks'**
  String get checkTasks;

  /// No description provided for @lookRight.
  ///
  /// In en, this message translates to:
  /// **'Look right?'**
  String get lookRight;

  /// No description provided for @finalSay.
  ///
  /// In en, this message translates to:
  /// **'Tap a detail to change it. You have the final say.'**
  String get finalSay;

  /// No description provided for @changePriority.
  ///
  /// In en, this message translates to:
  /// **'Change priority'**
  String get changePriority;

  /// No description provided for @changeRepeat.
  ///
  /// In en, this message translates to:
  /// **'Change repeat'**
  String get changeRepeat;

  /// No description provided for @confirmedDetails.
  ///
  /// In en, this message translates to:
  /// **'I’ve checked this task'**
  String get confirmedDetails;

  /// No description provided for @agendaCounts.
  ///
  /// In en, this message translates to:
  /// **'{remaining} to do · {done} completed'**
  String agendaCounts(int remaining, int done);

  /// No description provided for @completionCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} tasks completed'**
  String completionCount(int done, int total);

  /// No description provided for @pendingCaptureCount.
  ///
  /// In en, this message translates to:
  /// **'Unfinished captures · {count}'**
  String pendingCaptureCount(int count);

  /// No description provided for @listeningSeconds.
  ///
  /// In en, this message translates to:
  /// **'Listening · {time}'**
  String listeningSeconds(String time);

  /// No description provided for @nativeSpeechHelp.
  ///
  /// In en, this message translates to:
  /// **'On-device speech · {language}. Words appear below and are kept as you speak.'**
  String nativeSpeechHelp(String language);

  /// No description provided for @repeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {interval} {unit}'**
  String repeatEvery(int interval, String unit);

  /// No description provided for @repeatEveryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Repeat every… {unit}'**
  String repeatEveryPrompt(String unit);

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @readyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ready to save'**
  String readyCount(int count);

  /// No description provided for @needsCheckCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task needs} other{{count} tasks need}} a quick check. Save the ready ones whenever you like.'**
  String needsCheckCount(int count);

  /// No description provided for @priorityValue.
  ///
  /// In en, this message translates to:
  /// **'{priority} priority'**
  String priorityValue(String priority);

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickDate;

  /// No description provided for @typeTask.
  ///
  /// In en, this message translates to:
  /// **'Type a task'**
  String get typeTask;

  /// No description provided for @addStepDialog.
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get addStepDialog;

  /// No description provided for @editStep.
  ///
  /// In en, this message translates to:
  /// **'Edit step'**
  String get editStep;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @shortStep.
  ///
  /// In en, this message translates to:
  /// **'Add a short step.'**
  String get shortStep;

  /// No description provided for @keepStep.
  ///
  /// In en, this message translates to:
  /// **'Keep step'**
  String get keepStep;

  /// No description provided for @repeatingSteps.
  ///
  /// In en, this message translates to:
  /// **'These steps repeat with the task. Check them off from an occurrence’s details.'**
  String get repeatingSteps;

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

  /// No description provided for @removeStep.
  ///
  /// In en, this message translates to:
  /// **'Remove step'**
  String get removeStep;

  /// No description provided for @addChecklist.
  ///
  /// In en, this message translates to:
  /// **'Add checklist'**
  String get addChecklist;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get addStep;

  /// No description provided for @listUnavailable.
  ///
  /// In en, this message translates to:
  /// **'List unavailable'**
  String get listUnavailable;

  /// No description provided for @moveToList.
  ///
  /// In en, this message translates to:
  /// **'Move to a list'**
  String get moveToList;

  /// No description provided for @moveToListHelp.
  ///
  /// In en, this message translates to:
  /// **'Your date, reminder and task details stay the same.'**
  String get moveToListHelp;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @createListHelp.
  ///
  /// In en, this message translates to:
  /// **'Create your first list from Tasks → Lists.'**
  String get createListHelp;

  /// No description provided for @taskReopened.
  ///
  /// In en, this message translates to:
  /// **'Task reopened'**
  String get taskReopened;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get taskCompleted;

  /// No description provided for @undoError.
  ///
  /// In en, this message translates to:
  /// **'Could not undo. Please try again.'**
  String get undoError;

  /// No description provided for @taskUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this task. Please try again.'**
  String get taskUpdateError;

  /// No description provided for @occurrenceSkippedNotice.
  ///
  /// In en, this message translates to:
  /// **'Occurrence skipped'**
  String get occurrenceSkippedNotice;

  /// No description provided for @originalRestored.
  ///
  /// In en, this message translates to:
  /// **'Original date restored'**
  String get originalRestored;

  /// No description provided for @movedInbox.
  ///
  /// In en, this message translates to:
  /// **'Moved to Inbox'**
  String get movedInbox;

  /// No description provided for @scheduleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Schedule updated'**
  String get scheduleUpdated;

  /// No description provided for @scheduleChangedAgain.
  ///
  /// In en, this message translates to:
  /// **'The schedule changed again. Open the task to review it.'**
  String get scheduleChangedAgain;

  /// No description provided for @scheduleError.
  ///
  /// In en, this message translates to:
  /// **'Could not change the schedule. Please try again.'**
  String get scheduleError;

  /// No description provided for @rescheduleRepeating.
  ///
  /// In en, this message translates to:
  /// **'Reschedule repeating task'**
  String get rescheduleRepeating;

  /// No description provided for @rescheduleTask.
  ///
  /// In en, this message translates to:
  /// **'Reschedule task'**
  String get rescheduleTask;

  /// No description provided for @seriesRescheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Changes the start of the series and resets individual moves or skips. Inbox stops the repeat.'**
  String get seriesRescheduleHelp;

  /// No description provided for @occurrenceRescheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Other dates in the series stay the same.'**
  String get occurrenceRescheduleHelp;

  /// No description provided for @saveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save schedule'**
  String get saveSchedule;

  /// No description provided for @restoreOriginal.
  ///
  /// In en, this message translates to:
  /// **'Restore original date'**
  String get restoreOriginal;

  /// No description provided for @progressSmall.
  ///
  /// In en, this message translates to:
  /// **'Progress starts small'**
  String get progressSmall;

  /// No description provided for @completedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every task you finish will find a home here.'**
  String get completedEmpty;

  /// No description provided for @progressHeading.
  ///
  /// In en, this message translates to:
  /// **'Look how far you’ve come.'**
  String get progressHeading;

  /// No description provided for @completedLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load completed tasks'**
  String get completedLoadError;

  /// No description provided for @tryLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get tryLater;

  /// No description provided for @suggestionApplied.
  ///
  /// In en, this message translates to:
  /// **'Schedule suggestion applied'**
  String get suggestionApplied;

  /// No description provided for @changeSeriesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Change the repeating schedule?'**
  String get changeSeriesQuestion;

  /// No description provided for @changeSeriesHelp.
  ///
  /// In en, this message translates to:
  /// **'This resets individual moved or skipped dates to the new schedule. Your completed dates remain in history.'**
  String get changeSeriesHelp;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @resetSave.
  ///
  /// In en, this message translates to:
  /// **'Reset and save'**
  String get resetSave;

  /// No description provided for @taskSavedInbox.
  ///
  /// In en, this message translates to:
  /// **'Task saved to Inbox'**
  String get taskSavedInbox;

  /// No description provided for @taskAddedCalendar.
  ///
  /// In en, this message translates to:
  /// **'Task added to your calendar'**
  String get taskAddedCalendar;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// No description provided for @taskSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your task. Please try again.'**
  String get taskSaveError;

  /// No description provided for @localAttachmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Attachments currently stay on this phone. Signing in restores your tasks, but these files will not appear on another device.'**
  String get localAttachmentHelp;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get attachFile;

  /// No description provided for @attachError.
  ///
  /// In en, this message translates to:
  /// **'Could not attach that file. Please try again.'**
  String get attachError;

  /// No description provided for @capturedWords.
  ///
  /// In en, this message translates to:
  /// **'Captured from your words'**
  String get capturedWords;

  /// No description provided for @titleRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get titleRequiredField;

  /// No description provided for @keepAsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep as title'**
  String get keepAsTitle;

  /// No description provided for @ambiguousTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose AM/PM or add the time yourself. No hour has been inferred.'**
  String get ambiguousTimeHelp;

  /// No description provided for @clearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get clearDate;

  /// No description provided for @optionalTime.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get optionalTime;

  /// No description provided for @resetDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Reset a date, then save your changes.'**
  String get resetDateHelp;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @theDetails.
  ///
  /// In en, this message translates to:
  /// **'The details'**
  String get theDetails;

  /// No description provided for @labelLimit.
  ///
  /// In en, this message translates to:
  /// **'Use up to 10 labels, each under 33 characters.'**
  String get labelLimit;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Anything you’d like to remember…'**
  String get notesHint;

  /// No description provided for @addAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get addAttachment;

  /// No description provided for @localAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments stay on this device.'**
  String get localAttachments;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saveChangesSentence.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChangesSentence;

  /// No description provided for @useSchedule.
  ///
  /// In en, this message translates to:
  /// **'Use {schedule}'**
  String useSchedule(String schedule);

  /// No description provided for @checklistCount.
  ///
  /// In en, this message translates to:
  /// **'Checklist · {done}/{total}'**
  String checklistCount(int done, int total);

  /// No description provided for @checklistSemantics.
  ///
  /// In en, this message translates to:
  /// **'Checklist, {done} of {total} steps completed'**
  String checklistSemantics(int done, int total);

  /// No description provided for @useDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get useDefault;

  /// No description provided for @atScheduledTime.
  ///
  /// In en, this message translates to:
  /// **'At the scheduled time'**
  String get atScheduledTime;

  /// No description provided for @hourBefore.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get hourBefore;

  /// No description provided for @dayBefore.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get dayBefore;

  /// No description provided for @deviceOff.
  ///
  /// In en, this message translates to:
  /// **'device off'**
  String get deviceOff;

  /// No description provided for @defaultChoice.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get defaultChoice;

  /// No description provided for @minutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes before'**
  String minutesBefore(int minutes);

  /// No description provided for @reminderValue.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {value}'**
  String reminderValue(String value);

  /// No description provided for @fileLocal.
  ///
  /// In en, this message translates to:
  /// **'Only on this device'**
  String get fileLocal;

  /// No description provided for @fileQueued.
  ///
  /// In en, this message translates to:
  /// **'Upload queued'**
  String get fileQueued;

  /// No description provided for @fileBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Backed up to your account'**
  String get fileBackedUp;

  /// No description provided for @fileDownloadAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available to download'**
  String get fileDownloadAvailable;

  /// No description provided for @fileMissing.
  ///
  /// In en, this message translates to:
  /// **'File unavailable on this device'**
  String get fileMissing;

  /// No description provided for @fileRemovalPending.
  ///
  /// In en, this message translates to:
  /// **'Removal pending'**
  String get fileRemovalPending;

  /// No description provided for @fileUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get fileUpload;

  /// No description provided for @fileDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get fileDownload;

  /// No description provided for @fileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fileOpen;

  /// No description provided for @fileRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry transfer'**
  String get fileRetry;

  /// No description provided for @fileRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get fileRemove;

  /// No description provided for @fileRemoveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this attachment?'**
  String get fileRemoveQuestion;

  /// No description provided for @fileRemoveHelp.
  ///
  /// In en, this message translates to:
  /// **'This removes it from the task and, if uploaded, your other devices when they sync. Your original file is not deleted.'**
  String get fileRemoveHelp;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments. Add a file when editing this task.'**
  String get fileEmpty;

  /// No description provided for @fileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load attachment status. Please retry.'**
  String get fileLoadError;

  /// No description provided for @fileActionError.
  ///
  /// In en, this message translates to:
  /// **'Could not complete this action. Your task is saved; please retry.'**
  String get fileActionError;

  /// No description provided for @fileSignInHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload your files and restore them on another device.'**
  String get fileSignInHelp;

  /// No description provided for @fileUploadHelp.
  ///
  /// In en, this message translates to:
  /// **'New files upload to your account after saving: up to 6 MiB each, 64 MiB per account. Older local files stay on this device until you choose Upload in task details.'**
  String get fileUploadHelp;

  /// No description provided for @fileLocalHelp.
  ///
  /// In en, this message translates to:
  /// **'Files stay on this device until you sign in and choose Upload in task details. Up to 6 MiB per file.'**
  String get fileLocalHelp;

  /// No description provided for @fileLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose a non-empty file up to 6 MiB. You can attach up to 20 files per task.'**
  String get fileLimit;

  /// No description provided for @fileManageHelp.
  ///
  /// In en, this message translates to:
  /// **'Open task details to download, upload, or remove account attachments.'**
  String get fileManageHelp;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
