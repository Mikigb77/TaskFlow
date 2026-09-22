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

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No text added.'**
  String get noteEmptyBody;

  /// No description provided for @fileNone.
  ///
  /// In en, this message translates to:
  /// **'No attachments.'**
  String get fileNone;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note title'**
  String get noteTitle;

  /// No description provided for @noteBody.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get noteBody;

  /// No description provided for @notesHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep information, ideas and reference material. Use a task for something you need to do.'**
  String get notesHelp;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'A place for your thoughts'**
  String get notesEmpty;

  /// No description provided for @notesEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Write or dictate a note. Add links or a checklist when useful.'**
  String get notesEmptyHelp;

  /// No description provided for @findNote.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get findNote;

  /// No description provided for @reviewNote.
  ///
  /// In en, this message translates to:
  /// **'Review note'**
  String get reviewNote;

  /// No description provided for @saveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNote;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @recordNote.
  ///
  /// In en, this message translates to:
  /// **'Dictate a note'**
  String get recordNote;

  /// No description provided for @noteCaptureHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep your words as one note. Typed notes stay on your phone until sync; saved recordings need online transcription.'**
  String get noteCaptureHelp;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Ideas, meeting details, useful links…'**
  String get noteHint;

  /// No description provided for @deleteNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get deleteNoteQuestion;

  /// No description provided for @keepNote.
  ///
  /// In en, this message translates to:
  /// **'Keep note'**
  String get keepNote;

  /// No description provided for @viewOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'View-only note. The list owner manages editing access.'**
  String get viewOnlyNote;

  /// No description provided for @linkOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link. You can copy it from the note.'**
  String get linkOpenError;

  /// No description provided for @noteLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get noteLinks;

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned for'**
  String get plannedFor;

  /// No description provided for @plannedForHelp.
  ///
  /// In en, this message translates to:
  /// **'When you intend to do this task. A deadline can be set separately in More details.'**
  String get plannedForHelp;

  /// No description provided for @planning.
  ///
  /// In en, this message translates to:
  /// **'Duration & deadline'**
  String get planning;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @durationUnset.
  ///
  /// In en, this message translates to:
  /// **'No duration set'**
  String get durationUnset;

  /// No description provided for @durationEstimateHelp.
  ///
  /// In en, this message translates to:
  /// **'An estimate until you choose a planned start time.'**
  String get durationEstimateHelp;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationInput.
  ///
  /// In en, this message translates to:
  /// **'Minutes (1–1440)'**
  String get durationInput;

  /// No description provided for @durationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 1440.'**
  String get durationInvalid;

  /// No description provided for @removeDuration.
  ///
  /// In en, this message translates to:
  /// **'Remove duration'**
  String get removeDuration;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadline;

  /// No description provided for @deadlineUnset.
  ///
  /// In en, this message translates to:
  /// **'No deadline'**
  String get deadlineUnset;

  /// No description provided for @deadlineHelp.
  ///
  /// In en, this message translates to:
  /// **'Must be finished by this date. Moving the planned start keeps this deadline.'**
  String get deadlineHelp;

  /// No description provided for @deadlineTime.
  ///
  /// In en, this message translates to:
  /// **'Deadline time'**
  String get deadlineTime;

  /// No description provided for @deadlineEndDay.
  ///
  /// In en, this message translates to:
  /// **'By the end of the day'**
  String get deadlineEndDay;

  /// No description provided for @removeDeadline.
  ///
  /// In en, this message translates to:
  /// **'Remove deadline'**
  String get removeDeadline;

  /// No description provided for @deadlineRecurringHelp.
  ///
  /// In en, this message translates to:
  /// **'This deadline repeats with each original occurrence. Moving one planned occurrence keeps its deadline; changing the series start keeps the first deadline and changes the gap for later ones.'**
  String get deadlineRecurringHelp;

  /// No description provided for @deadlineLatePlan.
  ///
  /// In en, this message translates to:
  /// **'This plan finishes after the deadline. Check the start or duration.'**
  String get deadlineLatePlan;

  /// No description provided for @deadlineOverdue.
  ///
  /// In en, this message translates to:
  /// **'Deadline passed'**
  String get deadlineOverdue;

  /// No description provided for @deadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String deadlineLabel(String date);

  /// No description provided for @reminderAnchor.
  ///
  /// In en, this message translates to:
  /// **'Remind me relative to'**
  String get reminderAnchor;

  /// No description provided for @reminderAnchorHelp.
  ///
  /// In en, this message translates to:
  /// **'One reminder per occurrence, using the date selected here.'**
  String get reminderAnchorHelp;

  /// No description provided for @dayTimeline.
  ///
  /// In en, this message translates to:
  /// **'Day timeline'**
  String get dayTimeline;

  /// No description provided for @timelineFirstPlan.
  ///
  /// In en, this message translates to:
  /// **'Jump to first timed item'**
  String get timelineFirstPlan;

  /// No description provided for @timelineLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 timed items. Use the agenda to see every task.'**
  String get timelineLimit;

  /// No description provided for @timelineHelp.
  ///
  /// In en, this message translates to:
  /// **'Planned work and phone events. Deadlines mark when something must be finished.'**
  String get timelineHelp;

  /// No description provided for @timelineUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Without a time block'**
  String get timelineUnblocked;

  /// No description provided for @timelineNoBlocks.
  ///
  /// In en, this message translates to:
  /// **'No timed plans for this day. Add a start time and duration to reserve a block.'**
  String get timelineNoBlocks;

  /// No description provided for @timelinePoint.
  ///
  /// In en, this message translates to:
  /// **'No duration · time only'**
  String get timelinePoint;

  /// No description provided for @timelineShortBlocks.
  ///
  /// In en, this message translates to:
  /// **'Short events have larger tap targets; the accent bar shows their actual duration.'**
  String get timelineShortBlocks;

  /// No description provided for @timelineHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours in this day'**
  String timelineHours(int hours);

  /// No description provided for @deviceCalendars.
  ///
  /// In en, this message translates to:
  /// **'Phone calendars'**
  String get deviceCalendars;

  /// No description provided for @deviceCalendarHelp.
  ///
  /// In en, this message translates to:
  /// **'See events from calendars connected to this phone beside your tasks.'**
  String get deviceCalendarHelp;

  /// No description provided for @deviceCalendarPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Choose which calendars to display. Events are read-only in TaskFlow and stay on this device; they are not uploaded or sent to AI. Manage their reminders in your calendar app.'**
  String get deviceCalendarPrivacy;

  /// No description provided for @calendarEnable.
  ///
  /// In en, this message translates to:
  /// **'Connect phone calendars'**
  String get calendarEnable;

  /// No description provided for @calendarDisable.
  ///
  /// In en, this message translates to:
  /// **'Hide calendar events'**
  String get calendarDisable;

  /// No description provided for @calendarChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose calendars'**
  String get calendarChoose;

  /// No description provided for @calendarChooseHelp.
  ///
  /// In en, this message translates to:
  /// **'Select up to 50 calendars. Calendar times follow your device; all-day dates stay on their original days.'**
  String get calendarChooseHelp;

  /// No description provided for @calendarDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow calendar access to display your events. Your tasks still work without it.'**
  String get calendarDenied;

  /// No description provided for @calendarBlocked.
  ///
  /// In en, this message translates to:
  /// **'Calendar access is off. You can enable it in the phone’s app settings.'**
  String get calendarBlocked;

  /// No description provided for @calendarUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Phone calendar display is currently available on Android.'**
  String get calendarUnsupported;

  /// No description provided for @calendarSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get calendarSettings;

  /// No description provided for @calendarEmptySources.
  ///
  /// In en, this message translates to:
  /// **'No visible calendars are synced to this phone. Connect an account in your calendar app, then refresh here.'**
  String get calendarEmptySources;

  /// No description provided for @calendarRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh calendars'**
  String get calendarRefresh;

  /// No description provided for @calendarClear.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get calendarClear;

  /// No description provided for @calendarReadError.
  ///
  /// In en, this message translates to:
  /// **'Calendar events could not be read. Refresh to try again; this view may be missing commitments.'**
  String get calendarReadError;

  /// No description provided for @calendarPreferenceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save that calendar choice. Try again. You can select up to 50 calendars.'**
  String get calendarPreferenceError;

  /// No description provided for @calendarTruncated.
  ///
  /// In en, this message translates to:
  /// **'This calendar result is too large to show in full. Select fewer calendars to see the remaining events.'**
  String get calendarTruncated;

  /// No description provided for @calendarEvents.
  ///
  /// In en, this message translates to:
  /// **'Calendar events'**
  String get calendarEvents;

  /// No description provided for @calendarReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Calendar event · view only'**
  String get calendarReadOnly;

  /// No description provided for @calendarNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events from your selected calendars on this day.'**
  String get calendarNoEvents;

  /// No description provided for @calendarNoSelection.
  ///
  /// In en, this message translates to:
  /// **'Choose calendars to show your existing commitments.'**
  String get calendarNoSelection;

  /// No description provided for @calendarAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calendarAllDay;

  /// No description provided for @calendarUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get calendarUntitled;

  /// No description provided for @calendarShowAll.
  ///
  /// In en, this message translates to:
  /// **'See all calendar events'**
  String get calendarShowAll;

  /// No description provided for @calendarOpenEvent.
  ///
  /// In en, this message translates to:
  /// **'Open in calendar app'**
  String get calendarOpenEvent;

  /// No description provided for @calendarOpenError.
  ///
  /// In en, this message translates to:
  /// **'The calendar app could not open this event.'**
  String get calendarOpenError;

  /// No description provided for @calendarEventGone.
  ///
  /// In en, this message translates to:
  /// **'This event is no longer available in the selected calendars.'**
  String get calendarEventGone;

  /// No description provided for @noScheduledTasks.
  ///
  /// In en, this message translates to:
  /// **'No TaskFlow tasks scheduled'**
  String get noScheduledTasks;

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

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get yourAccount;

  /// No description provided for @accountHeading.
  ///
  /// In en, this message translates to:
  /// **'Your own little space.'**
  String get accountHeading;

  /// No description provided for @backupHeading.
  ///
  /// In en, this message translates to:
  /// **'Your plans, kept close.'**
  String get backupHeading;

  /// No description provided for @accountBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Tasks and notes are saved on this phone and backed up when connected. New attachments upload after saving; check their status in item details. Older device-only files need an explicit Upload.'**
  String get accountBackupHelp;

  /// No description provided for @accountUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your tasks and notes are up to date.'**
  String get accountUpToDate;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @importLocalItems.
  ///
  /// In en, this message translates to:
  /// **'Import local tasks and notes'**
  String get importLocalItems;

  /// No description provided for @importLocalItemsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Import local tasks and notes?'**
  String get importLocalItemsQuestion;

  /// No description provided for @importLocalItemsHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move 1 item from this phone into your account} other{Move {count} items from this phone into your account}} to back up your tasks and notes. Attachments stay on this phone until you choose Upload in item details.'**
  String importLocalItemsHelp(int count);

  /// No description provided for @importItems.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importItems;

  /// No description provided for @noLocalItems.
  ///
  /// In en, this message translates to:
  /// **'There are no local tasks or notes to import.'**
  String get noLocalItems;

  /// No description provided for @itemsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item imported.} other{{count} items imported.}}'**
  String itemsImported(int count);

  /// No description provided for @connectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Connection details'**
  String get connectionDetails;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @recoveryHeading.
  ///
  /// In en, this message translates to:
  /// **'Let’s get you back in.'**
  String get recoveryHeading;

  /// No description provided for @registerHeading.
  ///
  /// In en, this message translates to:
  /// **'A space for your plans.'**
  String get registerHeading;

  /// No description provided for @signInHeading.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get signInHeading;

  /// No description provided for @recoveryHelp.
  ///
  /// In en, this message translates to:
  /// **'Request a recovery email, then use the code to set a new password.'**
  String get recoveryHelp;

  /// No description provided for @accountSignInHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to back up your tasks and notes and get a larger voice allowance.'**
  String get accountSignInHelp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// No description provided for @recoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryCode;

  /// No description provided for @recoveryCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to request an email.'**
  String get recoveryCodeHelp;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 12 characters'**
  String get passwordHelp;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters'**
  String get passwordTooShort;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @continueRecovery.
  ///
  /// In en, this message translates to:
  /// **'Continue recovery'**
  String get continueRecovery;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @accountGuestHelp.
  ///
  /// In en, this message translates to:
  /// **'You can also use TaskFlow without an account. Your local tasks and notes stay on this phone.'**
  String get accountGuestHelp;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get connectionSettings;

  /// No description provided for @backendAddress.
  ///
  /// In en, this message translates to:
  /// **'Backend address'**
  String get backendAddress;

  /// No description provided for @backendAddressHelp.
  ///
  /// In en, this message translates to:
  /// **'Emulator: http://10.0.2.2:8088\nPhone: your computer’s LAN IP on the same Wi-Fi.'**
  String get backendAddressHelp;

  /// No description provided for @recoveryEmailRequested.
  ///
  /// In en, this message translates to:
  /// **'If that account exists, a recovery email has been sent.'**
  String get recoveryEmailRequested;

  /// No description provided for @passwordResetComplete.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Sign in with your new password.'**
  String get passwordResetComplete;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get editList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get listName;

  /// No description provided for @listNameHint.
  ///
  /// In en, this message translates to:
  /// **'Work, Personal, Shopping…'**
  String get listNameHint;

  /// No description provided for @listNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name your list.'**
  String get listNameRequired;

  /// No description provided for @colorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorViolet;

  /// No description provided for @colorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// No description provided for @colorRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get colorRose;

  /// No description provided for @saveList.
  ///
  /// In en, this message translates to:
  /// **'Save list'**
  String get saveList;

  /// No description provided for @listSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this list. Please retry.'**
  String get listSaveError;

  /// No description provided for @listRestored.
  ///
  /// In en, this message translates to:
  /// **'List restored'**
  String get listRestored;

  /// No description provided for @listArchivedHelp.
  ///
  /// In en, this message translates to:
  /// **'List archived. Contents kept.'**
  String get listArchivedHelp;

  /// No description provided for @listUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this list. Please retry.'**
  String get listUpdateError;

  /// No description provided for @chooseListDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose list details'**
  String get chooseListDetails;

  /// No description provided for @listConflictHelp.
  ///
  /// In en, this message translates to:
  /// **'This phone: {local}\n\nOther device: {remote}\n\nTask and note contents will stay the same.'**
  String listConflictHelp(String local, String remote);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @useOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Use other device'**
  String get useOtherDevice;

  /// No description provided for @useThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Use this phone'**
  String get useThisPhone;

  /// No description provided for @listResolveError.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve this list. Please retry.'**
  String get listResolveError;

  /// No description provided for @retryLists.
  ///
  /// In en, this message translates to:
  /// **'Retry lists'**
  String get retryLists;

  /// No description provided for @refreshLists.
  ///
  /// In en, this message translates to:
  /// **'Refresh lists and invitations'**
  String get refreshLists;

  /// No description provided for @listsHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep work, life and everything else in their own lists. Inbox still collects tasks without a date.'**
  String get listsHelp;

  /// No description provided for @listsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'A place for each part of life'**
  String get listsEmptyTitle;

  /// No description provided for @listsEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Start with Work, Personal or Shopping. Tasks can move whenever you like.'**
  String get listsEmptyHelp;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get roleEditor;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @sharedListRole.
  ///
  /// In en, this message translates to:
  /// **'{role} · shared'**
  String sharedListRole(String role);

  /// No description provided for @listConflict.
  ///
  /// In en, this message translates to:
  /// **'Changed on another device · choose details'**
  String get listConflict;

  /// No description provided for @archivedListHelp.
  ///
  /// In en, this message translates to:
  /// **'Archived · tasks and notes still available'**
  String get archivedListHelp;

  /// No description provided for @listItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks or notes} =1{1 task or note} other{{count} tasks and notes}}'**
  String listItemCount(int count);

  /// No description provided for @manageItem.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String manageItem(String name);

  /// No description provided for @restoreList.
  ///
  /// In en, this message translates to:
  /// **'Restore list'**
  String get restoreList;

  /// No description provided for @archiveList.
  ///
  /// In en, this message translates to:
  /// **'Archive list'**
  String get archiveList;

  /// No description provided for @sharingAndPeople.
  ///
  /// In en, this message translates to:
  /// **'Sharing and people'**
  String get sharingAndPeople;

  /// No description provided for @chooseDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose details'**
  String get chooseDetails;

  /// No description provided for @sharedListVisibility.
  ///
  /// In en, this message translates to:
  /// **'Shared · everyone in this list can see tasks, notes and uploaded files'**
  String get sharedListVisibility;

  /// No description provided for @invitationCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get invitationCode;

  /// No description provided for @invitationCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the intended person through a channel you trust. They need it and the invited TaskFlow account to accept. The code is shown only now; replacing an invitation invalidates its previous code.'**
  String get invitationCodeHelp;

  /// No description provided for @accountChanged.
  ///
  /// In en, this message translates to:
  /// **'The account changed.'**
  String get accountChanged;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @sharingUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update sharing. Check the connection and retry.'**
  String get sharingUpdateError;

  /// No description provided for @inviteToList.
  ///
  /// In en, this message translates to:
  /// **'Invite to this list'**
  String get inviteToList;

  /// No description provided for @inviteHelp.
  ///
  /// In en, this message translates to:
  /// **'All tasks, notes and uploaded files in this list will be visible after they accept. The invitation appears in their TaskFlow account; no email is sent. Give them the code shown next. It expires in 7 days.'**
  String get inviteHelp;

  /// No description provided for @inviteeEmail.
  ///
  /// In en, this message translates to:
  /// **'Their account email'**
  String get inviteeEmail;

  /// No description provided for @enterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter an email address.'**
  String get enterEmailAddress;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @sharingRolesHelp.
  ///
  /// In en, this message translates to:
  /// **'Editors can add, change, complete and delete tasks and files. Only the owner manages the list and people. Shared tasks stay in this list; exporting creates a personal copy.'**
  String get sharingRolesHelp;

  /// No description provided for @createInvitation.
  ///
  /// In en, this message translates to:
  /// **'Create invitation'**
  String get createInvitation;

  /// No description provided for @listSharing.
  ///
  /// In en, this message translates to:
  /// **'List sharing'**
  String get listSharing;

  /// No description provided for @sharingLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load sharing.'**
  String get sharingLoadError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @yourRole.
  ///
  /// In en, this message translates to:
  /// **'Your role: {role}'**
  String yourRole(String role);

  /// No description provided for @sharingHelp.
  ///
  /// In en, this message translates to:
  /// **'Share shopping and chores. Changes sync when the app connects or you refresh.'**
  String get sharingHelp;

  /// No description provided for @invitePerson.
  ///
  /// In en, this message translates to:
  /// **'Invite a person'**
  String get invitePerson;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @noOtherMembers.
  ///
  /// In en, this message translates to:
  /// **'Only you have accepted access so far.'**
  String get noOtherMembers;

  /// No description provided for @makeEditor.
  ///
  /// In en, this message translates to:
  /// **'Make editor'**
  String get makeEditor;

  /// No description provided for @makeViewer.
  ///
  /// In en, this message translates to:
  /// **'Make viewer'**
  String get makeViewer;

  /// No description provided for @removeAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get removeAccess;

  /// No description provided for @removeAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'This person will lose access to this list and its tasks, notes and files. Their unsent shared edits will be removed on the next successful sync.'**
  String get removeAccessHelp;

  /// No description provided for @pendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'Pending invitations'**
  String get pendingInvitations;

  /// No description provided for @pendingRole.
  ///
  /// In en, this message translates to:
  /// **'{role} · pending'**
  String pendingRole(String role);

  /// No description provided for @revokeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Revoke invitation'**
  String get revokeInvitation;

  /// No description provided for @replaceInvitationHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a pending invitation to replace its code.'**
  String get replaceInvitationHelp;

  /// No description provided for @howSharingWorks.
  ///
  /// In en, this message translates to:
  /// **'How sharing works'**
  String get howSharingWorks;

  /// No description provided for @sharedDataHelp.
  ///
  /// In en, this message translates to:
  /// **'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Task reminder choices are shared, but each phone must enable its own notifications.'**
  String get sharedDataHelp;

  /// No description provided for @sharingRemovalHelp.
  ///
  /// In en, this message translates to:
  /// **'Leaving or losing access removes this phone’s shared tasks, notes, pending edits and downloaded copies at the next successful sync. Offline devices and copies already exported cannot be remotely erased.'**
  String get sharingRemovalHelp;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteList;

  /// No description provided for @deleteListHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete this list and all its tasks, notes and uploaded files for everyone? This cannot be undone.'**
  String get deleteListHelp;

  /// No description provided for @deleteListForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete list for everyone'**
  String get deleteListForEveryone;

  /// No description provided for @leaveList.
  ///
  /// In en, this message translates to:
  /// **'Leave list'**
  String get leaveList;

  /// No description provided for @leaveListHelp.
  ///
  /// In en, this message translates to:
  /// **'Shared tasks, notes, files and any unsent edits will be removed from this phone. Other members keep the list.'**
  String get leaveListHelp;

  /// No description provided for @enterInvitationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invitation code'**
  String get enterInvitationCode;

  /// No description provided for @requestInvitationCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask the list owner for the code they received when inviting you.'**
  String get requestInvitationCodeHelp;

  /// No description provided for @invitationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the full invitation code.'**
  String get invitationCodeRequired;

  /// No description provided for @joinList.
  ///
  /// In en, this message translates to:
  /// **'Join list'**
  String get joinList;

  /// No description provided for @invitationResponseError.
  ///
  /// In en, this message translates to:
  /// **'Could not respond. Retry when connected.'**
  String get invitationResponseError;

  /// No description provided for @retryInvitations.
  ///
  /// In en, this message translates to:
  /// **'Retry invitations'**
  String get retryInvitations;

  /// No description provided for @invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get invitations;

  /// No description provided for @joinListHelp.
  ///
  /// In en, this message translates to:
  /// **'Join as {role}. Shared tasks, notes and uploaded files will sync to your account.'**
  String joinListHelp(String role);

  /// No description provided for @acceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInvitation;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments. Add a file when editing.'**
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

  /// No description provided for @notificationLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notification settings. Please retry.'**
  String get notificationLoadError;

  /// No description provided for @notificationSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save reminder settings. Please retry.'**
  String get notificationSaveError;

  /// No description provided for @enableReminders.
  ///
  /// In en, this message translates to:
  /// **'Enable reminders'**
  String get enableReminders;

  /// No description provided for @deviceReminderScope.
  ///
  /// In en, this message translates to:
  /// **'For this account on this device. Task choices sync; device preferences stay here.'**
  String get deviceReminderScope;

  /// No description provided for @mobileNotificationsOnly.
  ///
  /// In en, this message translates to:
  /// **'Mobile notifications only'**
  String get mobileNotificationsOnly;

  /// No description provided for @notificationPermissionOn.
  ///
  /// In en, this message translates to:
  /// **'System permission is on'**
  String get notificationPermissionOn;

  /// No description provided for @notificationPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'System permission is off'**
  String get notificationPermissionOff;

  /// No description provided for @preciseAlarmsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Precise alarm access available'**
  String get preciseAlarmsAvailable;

  /// No description provided for @approximateAlarmsHelp.
  ///
  /// In en, this message translates to:
  /// **'Alerts are approximate until precise alarm access is enabled'**
  String get approximateAlarmsHelp;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get openSystemSettings;

  /// No description provided for @allowPreciseAlarms.
  ///
  /// In en, this message translates to:
  /// **'Allow precise alarms'**
  String get allowPreciseAlarms;

  /// No description provided for @taskDefaults.
  ///
  /// In en, this message translates to:
  /// **'Task defaults'**
  String get taskDefaults;

  /// No description provided for @timedTasks.
  ///
  /// In en, this message translates to:
  /// **'Timed tasks'**
  String get timedTasks;

  /// No description provided for @dateOnlyTasks.
  ///
  /// In en, this message translates to:
  /// **'Date-only tasks'**
  String get dateOnlyTasks;

  /// No description provided for @dailyCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Daily check-ins'**
  String get dailyCheckIns;

  /// No description provided for @dailyCheckInsHelp.
  ///
  /// In en, this message translates to:
  /// **'A gentle prompt to review your current tasks.'**
  String get dailyCheckInsHelp;

  /// No description provided for @morningCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morningCheckIn;

  /// No description provided for @eveningCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get eveningCheckIn;

  /// No description provided for @upcomingAlerts.
  ///
  /// In en, this message translates to:
  /// **'Upcoming alerts'**
  String get upcomingAlerts;

  /// No description provided for @scheduledAlertHelp.
  ///
  /// In en, this message translates to:
  /// **'Scheduled means your phone accepted the alert. Battery restrictions, system settings and force-stop can delay or prevent delivery.'**
  String get scheduledAlertHelp;

  /// No description provided for @androidAlertRefreshHelp.
  ///
  /// In en, this message translates to:
  /// **'The window refreshes on app use and through an hourly background job when Android permits.'**
  String get androidAlertRefreshHelp;

  /// No description provided for @backgroundAlertRefreshHelp.
  ///
  /// In en, this message translates to:
  /// **'The window refreshes on app use and when the system allows background refresh.'**
  String get backgroundAlertRefreshHelp;

  /// No description provided for @noUpcomingAlerts.
  ///
  /// In en, this message translates to:
  /// **'No upcoming alerts. Choose a reminder on a scheduled task.'**
  String get noUpcomingAlerts;

  /// No description provided for @repeatsDaily.
  ///
  /// In en, this message translates to:
  /// **'repeats daily'**
  String get repeatsDaily;

  /// No description provided for @retryScheduling.
  ///
  /// In en, this message translates to:
  /// **'Refresh and retry scheduling'**
  String get retryScheduling;

  /// No description provided for @alertPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get alertPending;

  /// No description provided for @alertScheduled.
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get alertScheduled;

  /// No description provided for @alertApproximate.
  ///
  /// In en, this message translates to:
  /// **'approximate'**
  String get alertApproximate;

  /// No description provided for @alertBlocked.
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get alertBlocked;

  /// No description provided for @alertFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get alertFailed;

  /// No description provided for @alertInactive.
  ///
  /// In en, this message translates to:
  /// **'inactive'**
  String get alertInactive;

  /// No description provided for @alertElapsed.
  ///
  /// In en, this message translates to:
  /// **'elapsed'**
  String get alertElapsed;

  /// No description provided for @reminderPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled in system settings.'**
  String get reminderPermissionError;

  /// No description provided for @reminderScheduleError.
  ///
  /// In en, this message translates to:
  /// **'The phone could not schedule this alert. Retry from Settings.'**
  String get reminderScheduleError;

  /// No description provided for @reminderBackgroundError.
  ///
  /// In en, this message translates to:
  /// **'Background refresh could not finish. Open TaskFlow to retry.'**
  String get reminderBackgroundError;

  /// No description provided for @reminderBackgroundUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Automatic background refresh is unavailable. Alerts refresh when you open TaskFlow.'**
  String get reminderBackgroundUnavailable;

  /// No description provided for @reminderActionError.
  ///
  /// In en, this message translates to:
  /// **'A notification action could not finish. Open the task to retry.'**
  String get reminderActionError;

  /// No description provided for @reminderSetupError.
  ///
  /// In en, this message translates to:
  /// **'Notification setup could not finish. Retry from Settings.'**
  String get reminderSetupError;

  /// No description provided for @reminderAccountError.
  ///
  /// In en, this message translates to:
  /// **'Account reminders could not refresh. Open notification settings to retry.'**
  String get reminderAccountError;

  /// No description provided for @reminderRefreshError.
  ///
  /// In en, this message translates to:
  /// **'Reminders could not refresh. Your tasks are saved; retry from notification settings.'**
  String get reminderRefreshError;

  /// No description provided for @transferError.
  ///
  /// In en, this message translates to:
  /// **'Could not finish. Your existing tasks and notes are unchanged. Please retry.'**
  String get transferError;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Export saved. Keep the file somewhere private.'**
  String get exportSaved;

  /// No description provided for @keepYourTasks.
  ///
  /// In en, this message translates to:
  /// **'Keep your tasks with you.'**
  String get keepYourTasks;

  /// No description provided for @archiveContentsHelp.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow exports include tasks, notes, schedules, recurring date changes, completion, checklists, labels and personal lists. Attachment names are listed; file contents, account credentials, device preferences and unfinished captures are excluded.'**
  String get archiveContentsHelp;

  /// No description provided for @exportTaskFlowFile.
  ///
  /// In en, this message translates to:
  /// **'Export TaskFlow file'**
  String get exportTaskFlowFile;

  /// No description provided for @chooseImportFile.
  ///
  /// In en, this message translates to:
  /// **'Choose import file'**
  String get chooseImportFile;

  /// No description provided for @chooseImportFileHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a TaskFlow JSON export or Todoist project CSV (up to 32 MB / 5,000 tasks and notes). You will review it before importing.'**
  String get chooseImportFileHelp;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Import preview'**
  String get importPreview;

  /// No description provided for @importCopiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Selected tasks, notes and the file’s lists are added as personal copies. Existing content is kept. Re-importing this same file skips records already imported on this phone; a changed or newly exported file counts as a different import.'**
  String get importCopiesHelp;

  /// No description provided for @listsIncluded.
  ///
  /// In en, this message translates to:
  /// **'Lists included'**
  String get listsIncluded;

  /// No description provided for @archivedPersonalCopy.
  ///
  /// In en, this message translates to:
  /// **'Archived personal copy'**
  String get archivedPersonalCopy;

  /// No description provided for @personalCopy.
  ///
  /// In en, this message translates to:
  /// **'Personal copy'**
  String get personalCopy;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already imported on this phone'**
  String get alreadyImported;

  /// No description provided for @taskFlowExportSource.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow export'**
  String get taskFlowExportSource;

  /// No description provided for @todoistCsvSource.
  ///
  /// In en, this message translates to:
  /// **'Todoist project CSV'**
  String get todoistCsvSource;

  /// No description provided for @deferredAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 later alert is} other{{count} later alerts are}} outside the current window. The next refresh adds the earliest ones that fit.'**
  String deferredAlerts(int count);

  /// No description provided for @turnOffReminder.
  ///
  /// In en, this message translates to:
  /// **'Turn off {title}'**
  String turnOffReminder(String title);

  /// No description provided for @importResult.
  ///
  /// In en, this message translates to:
  /// **'Added {items, plural, =1{1 item} other{{items} items}} and {lists, plural, =1{1 list} other{{lists} lists}}.'**
  String importResult(int items, int lists);

  /// No description provided for @importSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count, plural, =1{1 already imported item} other{{count} already imported items}}.'**
  String importSkipped(int count);

  /// No description provided for @importCounts.
  ///
  /// In en, this message translates to:
  /// **'{source} · {tasks} tasks · {notes} notes · {lists} lists'**
  String importCounts(String source, int tasks, int notes, int lists);

  /// No description provided for @cannotImport.
  ///
  /// In en, this message translates to:
  /// **'Cannot import: {reason}'**
  String cannotImport(String reason);

  /// No description provided for @importSelected.
  ///
  /// In en, this message translates to:
  /// **'Import {count, plural, =1{1 selected item} other{{count} selected items}} and lists'**
  String importSelected(int count);

  /// No description provided for @importRow.
  ///
  /// In en, this message translates to:
  /// **'Record {row}'**
  String importRow(int row);

  /// No description provided for @archiveFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a file smaller than 32 MB.'**
  String get archiveFileTooLarge;

  /// No description provided for @archiveUnsupportedArchive.
  ///
  /// In en, this message translates to:
  /// **'This is not a supported TaskFlow export (versions 1 and 2).'**
  String get archiveUnsupportedArchive;

  /// No description provided for @archiveInvalidList.
  ///
  /// In en, this message translates to:
  /// **'Invalid list metadata.'**
  String get archiveInvalidList;

  /// No description provided for @archiveDuplicateLists.
  ///
  /// In en, this message translates to:
  /// **'Duplicate list identifiers.'**
  String get archiveDuplicateLists;

  /// No description provided for @archiveInvalidListStyle.
  ///
  /// In en, this message translates to:
  /// **'Invalid list color or archive status.'**
  String get archiveInvalidListStyle;

  /// No description provided for @archiveInvalidTask.
  ///
  /// In en, this message translates to:
  /// **'Invalid task record.'**
  String get archiveInvalidTask;

  /// No description provided for @archiveDuplicateTask.
  ///
  /// In en, this message translates to:
  /// **'Duplicate task identifier.'**
  String get archiveDuplicateTask;

  /// No description provided for @archiveInvalidAttachments.
  ///
  /// In en, this message translates to:
  /// **'Invalid attachment information.'**
  String get archiveInvalidAttachments;

  /// No description provided for @archiveMissingList.
  ///
  /// In en, this message translates to:
  /// **'The task refers to a list missing from this file.'**
  String get archiveMissingList;

  /// No description provided for @archiveInvalidTaskFields.
  ///
  /// In en, this message translates to:
  /// **'Invalid task fields.'**
  String get archiveInvalidTaskFields;

  /// No description provided for @archiveUnsupportedKind.
  ///
  /// In en, this message translates to:
  /// **'Unsupported task or note type.'**
  String get archiveUnsupportedKind;

  /// No description provided for @archiveInvalidCompletion.
  ///
  /// In en, this message translates to:
  /// **'Invalid completion status.'**
  String get archiveInvalidCompletion;

  /// No description provided for @archiveTwoSchedules.
  ///
  /// In en, this message translates to:
  /// **'A task cannot have two schedules.'**
  String get archiveTwoSchedules;

  /// No description provided for @archiveTwoDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Choose a timed or date-only deadline.'**
  String get archiveTwoDeadlines;

  /// No description provided for @archiveInvalidReminderDate.
  ///
  /// In en, this message translates to:
  /// **'Choose an available reminder date.'**
  String get archiveInvalidReminderDate;

  /// No description provided for @archiveUnsupportedRepeat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported repeat rule.'**
  String get archiveUnsupportedRepeat;

  /// No description provided for @archiveWeekdaysNeedWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekdays require a weekly repeat.'**
  String get archiveWeekdaysNeedWeekly;

  /// No description provided for @archiveRepeatNeedsStart.
  ///
  /// In en, this message translates to:
  /// **'A repeating task needs a start date.'**
  String get archiveRepeatNeedsStart;

  /// No description provided for @archiveInvalidOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Invalid occurrence change.'**
  String get archiveInvalidOccurrence;

  /// No description provided for @archiveDuplicateOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Duplicate occurrence changes.'**
  String get archiveDuplicateOccurrence;

  /// No description provided for @archiveInvalidSkipped.
  ///
  /// In en, this message translates to:
  /// **'Invalid skipped date.'**
  String get archiveInvalidSkipped;

  /// No description provided for @archiveInvalidOccurrenceSchedule.
  ///
  /// In en, this message translates to:
  /// **'Invalid occurrence schedule.'**
  String get archiveInvalidOccurrenceSchedule;

  /// No description provided for @archiveRepeatSettingsNeedRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat settings need a repeating task.'**
  String get archiveRepeatSettingsNeedRepeat;

  /// No description provided for @archiveRepeatUsesCompletedDates.
  ///
  /// In en, this message translates to:
  /// **'Repeating tasks use individual completed dates.'**
  String get archiveRepeatUsesCompletedDates;

  /// No description provided for @archiveInvalidChecklist.
  ///
  /// In en, this message translates to:
  /// **'Invalid checklist item.'**
  String get archiveInvalidChecklist;

  /// No description provided for @archiveDuplicateChecklist.
  ///
  /// In en, this message translates to:
  /// **'Duplicate checklist identifiers.'**
  String get archiveDuplicateChecklist;

  /// No description provided for @archiveInvalidChecklistProgress.
  ///
  /// In en, this message translates to:
  /// **'Invalid checklist progress.'**
  String get archiveInvalidChecklistProgress;

  /// No description provided for @archiveRepeatEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Repeat end precedes the start.'**
  String get archiveRepeatEndBeforeStart;

  /// No description provided for @archiveOccurrenceOutsideRepeat.
  ///
  /// In en, this message translates to:
  /// **'An occurrence change is outside this repeat rule.'**
  String get archiveOccurrenceOutsideRepeat;

  /// No description provided for @archiveExportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This export exceeds the supported 32 MB or 5,000-task limit.'**
  String get archiveExportTooLarge;

  /// No description provided for @archiveInvalidDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Dates must use YYYY-MM-DD.'**
  String get archiveInvalidDateFormat;

  /// No description provided for @archiveInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid calendar date.'**
  String get archiveInvalidDate;

  /// No description provided for @archiveMissingTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timed dates need an ISO time and timezone offset.'**
  String get archiveMissingTimezone;

  /// No description provided for @archiveInvalidClock.
  ///
  /// In en, this message translates to:
  /// **'Invalid clock time.'**
  String get archiveInvalidClock;

  /// No description provided for @archiveInvalidOffset.
  ///
  /// In en, this message translates to:
  /// **'Invalid timezone offset.'**
  String get archiveInvalidOffset;

  /// No description provided for @archiveInvalidTimedDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid timed date.'**
  String get archiveInvalidTimedDate;

  /// No description provided for @archiveFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read. Choose a local copy.'**
  String get archiveFileUnreadable;

  /// No description provided for @archiveEmptyCsv.
  ///
  /// In en, this message translates to:
  /// **'This CSV is empty.'**
  String get archiveEmptyCsv;

  /// No description provided for @archiveCsvHeader.
  ///
  /// In en, this message translates to:
  /// **'Choose a Todoist project CSV with TYPE and CONTENT columns.'**
  String get archiveCsvHeader;

  /// No description provided for @archiveCsvTaskLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV with at most 5,000 tasks.'**
  String get archiveCsvTaskLimit;

  /// No description provided for @archiveCsvPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority must be 1–4.'**
  String get archiveCsvPriority;

  /// No description provided for @archiveCsvIndent.
  ///
  /// In en, this message translates to:
  /// **'Indent must be 1–4.'**
  String get archiveCsvIndent;

  /// No description provided for @archiveCsvRecordLimit.
  ///
  /// In en, this message translates to:
  /// **'This CSV has too many records.'**
  String get archiveCsvRecordLimit;

  /// No description provided for @archiveCsvQuoting.
  ///
  /// In en, this message translates to:
  /// **'Malformed CSV quoting.'**
  String get archiveCsvQuoting;

  /// No description provided for @archiveCsvUnclosedQuote.
  ///
  /// In en, this message translates to:
  /// **'An unfinished quoted CSV field was found.'**
  String get archiveCsvUnclosedQuote;

  /// No description provided for @archiveNotesTooLong.
  ///
  /// In en, this message translates to:
  /// **'Task and comments exceed 8,000 note characters.'**
  String get archiveNotesTooLong;

  /// No description provided for @archiveInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'The file is not valid JSON or UTF-8 text.'**
  String get archiveInvalidFile;

  /// No description provided for @archiveUnknownFields.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized task fields will be omitted.'**
  String get archiveUnknownFields;

  /// No description provided for @archivePersonalCopies.
  ///
  /// In en, this message translates to:
  /// **'Imports create new personal copies. Account access, files, notification preferences and unfinished captures are not included.'**
  String get archivePersonalCopies;

  /// No description provided for @archiveCsvPriorities.
  ///
  /// In en, this message translates to:
  /// **'Todoist priorities 3 and 4 both become Low. Subtasks become separate tasks.'**
  String get archiveCsvPriorities;

  /// No description provided for @archiveCsvDates.
  ///
  /// In en, this message translates to:
  /// **'Only ISO calendar dates and times with explicit timezone offsets are scheduled. Other date expressions are kept in notes for you to review.'**
  String get archiveCsvDates;

  /// No description provided for @archiveCsvPersonalCopies.
  ///
  /// In en, this message translates to:
  /// **'This creates personal copies. Assignments, files and sharing access are not transferred. Todoist project CSV exports may omit completed tasks.'**
  String get archiveCsvPersonalCopies;

  /// No description provided for @archiveReviewSchedule.
  ///
  /// In en, this message translates to:
  /// **'The original schedule needs review; this task will go to Inbox.'**
  String get archiveReviewSchedule;

  /// No description provided for @archiveFlattenedSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtask nesting will be flattened.'**
  String get archiveFlattenedSubtasks;

  /// No description provided for @archiveInlineLabels.
  ///
  /// In en, this message translates to:
  /// **'Inline @labels remain in the title.'**
  String get archiveInlineLabels;

  /// No description provided for @archiveAttachmentsOmitted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment file is} other{{count} attachment files are}} not included.'**
  String archiveAttachmentsOmitted(int count);

  /// No description provided for @archiveInvalidCollection.
  ///
  /// In en, this message translates to:
  /// **'Invalid {field} (maximum {max}).'**
  String archiveInvalidCollection(String field, int max);

  /// No description provided for @archiveInvalidText.
  ///
  /// In en, this message translates to:
  /// **'Invalid {field} (maximum {max} characters).'**
  String archiveInvalidText(String field, int max);

  /// No description provided for @archiveInvalidInteger.
  ///
  /// In en, this message translates to:
  /// **'Invalid {field} ({min}–{max}).'**
  String archiveInvalidInteger(String field, int min, int max);

  /// No description provided for @archiveInvalidIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Invalid {field}.'**
  String archiveInvalidIdentifier(String field);

  /// No description provided for @archiveCsvExtraFields.
  ///
  /// In en, this message translates to:
  /// **'Row {row} has more fields than the header.'**
  String archiveCsvExtraFields(int row);

  /// No description provided for @archiveCsvInvalidSection.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: section name is invalid; its tasks will have no list.'**
  String archiveCsvInvalidSection(int row);

  /// No description provided for @archiveCsvListDescription.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: list descriptions are not supported.'**
  String archiveCsvListDescription(int row);

  /// No description provided for @archiveCsvOrphanComment.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: comment has no valid preceding task; it will be skipped.'**
  String archiveCsvOrphanComment(int row);

  /// No description provided for @archiveCsvUnsupportedRow.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: unsupported record type; it will be skipped.'**
  String archiveCsvUnsupportedRow(int row);

  /// No description provided for @archiveCsvFieldInNotes.
  ///
  /// In en, this message translates to:
  /// **'{field} will be kept as text in notes.'**
  String archiveCsvFieldInNotes(String field);

  /// No description provided for @archiveField.
  ///
  /// In en, this message translates to:
  /// **'{field, select, export_id{export_id} tasks{tasks} lists{lists} list_id{list id} list_name{list name} task_identifier{task identifier} title{title} notes{notes} priority{priority} duration{duration} repeat_interval{repeat interval} repeat_weekdays{repeat weekdays} weekday{weekday} completed_dates{completed dates} individual_date_changes{individual date changes} list_identifier{list identifier} labels{labels} label{label} checklist{checklist} checklist_identifier{checklist identifier} checklist_title{checklist title} checklist_dates{checklist dates} reminder_lead{reminder lead} reminder_time{reminder time} other{field}}'**
  String archiveField(String field);
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
