import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
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
    Locale('ca'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @reviewSchedule.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get reviewSchedule;

  /// No description provided for @reviewChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date before adding a time.'**
  String get reviewChooseDate;

  /// No description provided for @chooseAmPm.
  ///
  /// In en, this message translates to:
  /// **'Choose AM or PM.'**
  String get chooseAmPm;

  /// Under the hour field of Change date, on a 24-hour clock, when the hour typed is not a valid one.
  ///
  /// In en, this message translates to:
  /// **'Hour from 0 to 23'**
  String get scheduleHourRange24;

  /// Under the hour field of Change date, on a 12-hour clock, when the hour typed is not a valid one.
  ///
  /// In en, this message translates to:
  /// **'Hour from 1 to 12'**
  String get scheduleHourRange12;

  /// Under the minutes field of Change date, when the minutes typed are not valid.
  ///
  /// In en, this message translates to:
  /// **'Minutes from 0 to 59'**
  String get scheduleMinuteRange;

  /// No description provided for @reviewOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get reviewOptions;

  /// No description provided for @reviewOriginal.
  ///
  /// In en, this message translates to:
  /// **'See what I said'**
  String get reviewOriginal;

  /// No description provided for @reviewOriginalText.
  ///
  /// In en, this message translates to:
  /// **'Original text'**
  String get reviewOriginalText;

  /// No description provided for @reviewRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get reviewRemoved;

  /// After Undo while the capture sheet stays open (some cards still wait): the tasks just saved are back in the sheet, unsaved. {count} is how many came back.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It’s back here, not saved yet.} other{They’re back here, not saved yet.}}'**
  String reviewUndoSaved(int count);

  /// No description provided for @reviewUndoChanged.
  ///
  /// In en, this message translates to:
  /// **'This task has changed. Your saved tasks were kept.'**
  String get reviewUndoChanged;

  /// No description provided for @reviewRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair text'**
  String get reviewRepair;

  /// No description provided for @reviewRepairHelp.
  ///
  /// In en, this message translates to:
  /// **'This text may have been saved with damaged accents. Review the correction before saving.'**
  String get reviewRepairHelp;

  /// No description provided for @reviewConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'That’s right'**
  String get reviewConfirmDetail;

  /// No description provided for @reviewNoTime.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get reviewNoTime;

  /// The time question for a result made on the phone, above the morning and evening time chips. Neutral between morning and evening; in Spanish it avoids `mañana`, which also means tomorrow.
  ///
  /// In en, this message translates to:
  /// **'What time?'**
  String get captureWhatTime;

  /// No description provided for @reviewEditDetail.
  ///
  /// In en, this message translates to:
  /// **'Change this detail'**
  String get reviewEditDetail;

  /// No description provided for @reviewResolved.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewResolved;

  /// No description provided for @reviewResolve.
  ///
  /// In en, this message translates to:
  /// **'Check this detail'**
  String get reviewResolve;

  /// This language's name in its own language, used in the language selector.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNativeName;

  /// Actionable sharing API errors. Reasons stay internal and never get translated.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, alreadyMember{This person already has access. Manage their role in Members.} memberLimit{This project supports up to 20 members and 20 pending invitations. Remove someone or cancel an invitation first.} accepted{This invitation was already accepted. Manage the person’s access in Members.} owner{The owner cannot leave. You can delete the project if it is no longer needed.} expired{This invitation is no longer available. Ask the owner for a new one.} code{Ask the project owner for the current invitation code.} refresh{This project changed. Refresh before deleting it.} ownerOnly{Only the project owner can manage sharing and project details.} other{This project is read-only for your account. Ask the owner for editing access.}}'**
  String sharingProblem(String reason);

  /// Sync notices with recovery instructions, including messages persisted by older app versions.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, assignmentChanged{The responsible person changed. Your unsent edit was kept as a personal copy.} listConflict{A project changed on another device. Choose which version to keep in Projects.} readOnly{This project is now read-only. Your unsent edit was kept as a personal copy.} accessChanged{Shared-project access changed. Refresh to finish syncing permitted edits.} taskConflict{A task changed on another device. Your edit was kept as an offline copy; a conflicting deletion was cancelled.} serverUpdate{Update this server before syncing notes. Your notes are kept on this phone.} other{The server did not preserve this content type. Your local copy is kept.}}'**
  String syncProblem(String reason);

  /// Localized account, sync and file error categories. Never display raw server exception text.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, signOutFirst{Sign out before changing servers.} https{Use an HTTPS server address for this build.} serverAddress{Enter a valid server address, such as https://your-server.example.} emailUsed{This email already has an account.} email{Enter a valid email address.} credentials{We couldn’t find that account, or the password is wrong.} session{Please sign in again to continue. Your local tasks are kept.} accountChanged{The account changed. Reopen this screen and try again.} password{Choose a password of 12–128 characters that is not common, entirely numeric or similar to your email.} recoveryCode{The recovery code is invalid or expired. Request a new one.} forbidden{This account cannot perform that action. Check your access.} rateLimit{Too many requests. Please wait a little before trying again.} fileLimit{Choose a non-empty file up to 6 MB.} fileChanged{The file has changed or could not be verified. Choose it again or retry the download.} network{No connection. Check Wi-Fi or mobile data and try again.} networkKept{No connection. Check Wi-Fi or mobile data and try again. Your tasks are still saved on this phone.} unavailable{The service is unavailable. Please try again later.} validation{Some details were not accepted. Review the information and try again.} other{Could not complete the request. Please try again.} otherKept{Could not complete the request. Please try again. Your tasks are still saved on this phone.}}'**
  String requestError(String reason);

  /// No description provided for @languageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get languageAutomatic;

  /// Summary of automatic language selection; language is the resolved language's native name.
  ///
  /// In en, this message translates to:
  /// **'Same as phone · {language}'**
  String languageFollowing(String language);

  /// No description provided for @regionalFormats.
  ///
  /// In en, this message translates to:
  /// **'Time & region'**
  String get regionalFormats;

  /// No description provided for @sharedCaptureRetained.
  ///
  /// In en, this message translates to:
  /// **'What you shared is kept. Open TaskFlow again to try again.'**
  String get sharedCaptureRetained;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

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

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'A place for your thoughts'**
  String get notesEmpty;

  /// Under «A place for your thoughts», the only help on an empty Notes tab: what a note is for, and that something to do is a task.
  ///
  /// In en, this message translates to:
  /// **'Keep ideas and things to remember. For something to do, use a task.'**
  String get notesEmptyHelp;

  /// No description provided for @findNote.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get findNote;

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

  /// The one button on Notes that adds a note: it opens the capture sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Ideas, meeting details, useful links…'**
  String get noteHint;

  /// Example placeholder in the note title field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Wi-Fi password'**
  String get noteTitleHint;

  /// No description provided for @noteTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give your note a title'**
  String get noteTitleRequired;

  /// No description provided for @noteNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noteNoMatches;

  /// No description provided for @notesSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your notes are still on this phone.'**
  String get notesSavedOnDevice;

  /// Banner on a note in a project the person can only view: who to ask to make changes.
  ///
  /// In en, this message translates to:
  /// **'View-only note. To make changes, ask the project’s owner.'**
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

  /// No description provided for @deadlineTime.
  ///
  /// In en, this message translates to:
  /// **'Deadline time'**
  String get deadlineTime;

  /// No description provided for @removeDeadline.
  ///
  /// In en, this message translates to:
  /// **'Remove deadline'**
  String get removeDeadline;

  /// No description provided for @deadlineRecurringHelp.
  ///
  /// In en, this message translates to:
  /// **'Each repeat has its own deadline.'**
  String get deadlineRecurringHelp;

  /// No description provided for @deadlineLatePlan.
  ///
  /// In en, this message translates to:
  /// **'This plan finishes after the deadline. Check the start or duration.'**
  String get deadlineLatePlan;

  /// No description provided for @deadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String deadlineLabel(String date);

  /// On a task's row and its page, in place of deadlineLabel once the deadline has passed: said once, in the row's usual grey. {date} is the weekday date, and the time when the deadline has one, as deadlineLabel gets it.
  ///
  /// In en, this message translates to:
  /// **'Was due {date}'**
  String deadlinePassedOn(String date);

  /// No description provided for @reminderAnchor.
  ///
  /// In en, this message translates to:
  /// **'Remind before'**
  String get reminderAnchor;

  /// No description provided for @dayTimeline.
  ///
  /// In en, this message translates to:
  /// **'Day timeline'**
  String get dayTimeline;

  /// No description provided for @timelineLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 timed items. Use the agenda to see every task.'**
  String get timelineLimit;

  /// Day timeline: heading above the day's tasks and all-day calendar events that have no time, so they are not drawn on the hours. The same words the task rows use for a task with no time.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get timelineUnblocked;

  /// Day timeline: shown when the shown day has no task, deadline or calendar event with a time.
  ///
  /// In en, this message translates to:
  /// **'Nothing with a time on this day.'**
  String get timelineNoBlocks;

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

  /// Phone calendars, before access: the one line above «Connect phone calendars». Says what connecting does and that events stay on the phone.
  ///
  /// In en, this message translates to:
  /// **'You’ll see your phone’s events in Calendar. They’re only read here, never uploaded.'**
  String get deviceCalendarIntro;

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

  /// Phone calendars: the first line while the phone’s events show in Calendar (access allowed and at least one calendar ticked).
  ///
  /// In en, this message translates to:
  /// **'Connected. Events show in Calendar.'**
  String get calendarConnected;

  /// No description provided for @calendarChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose calendars'**
  String get calendarChoose;

  /// No description provided for @calendarDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow calendar access to display your events. Your tasks still work without it.'**
  String get calendarDenied;

  /// Phone calendars, after the person refused calendar access: the one line above «Connect phone calendars».
  ///
  /// In en, this message translates to:
  /// **'Without permission, TaskFlow can’t see your events.'**
  String get calendarRefused;

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

  /// No description provided for @calendarReadRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read your events. Tap to try again.'**
  String get calendarReadRetry;

  /// No description provided for @changeView.
  ///
  /// In en, this message translates to:
  /// **'Change view'**
  String get changeView;

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

  /// Calendar agenda: the row after the day’s first three phone-calendar events, shown only when there are more than three; a tap opens the list of all the day’s events. count is always 4 or more.
  ///
  /// In en, this message translates to:
  /// **'See all {count} events'**
  String calendarSeeAllEvents(int count);

  /// No description provided for @calendarOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — your tasks are saved on this phone.'**
  String get calendarOffline;

  /// No description provided for @calendarUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get calendarUntitled;

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

  /// Calendar, an empty day while the phone's calendars are shown: the only line about tasks, followed by the line with the phone's events.
  ///
  /// In en, this message translates to:
  /// **'No tasks for this day.'**
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

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get inbox;

  /// No description provided for @inboxCount.
  ///
  /// In en, this message translates to:
  /// **'No date · {count}'**
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

  /// The day before today, before a time: when a kept capture was made (Yesterday, 18:05).
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

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

  /// No description provided for @removeDate.
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get removeDate;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// The app bar title of a task’s own page. A note’s page says Note instead.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskScreenTitle;

  /// The one button that adds a task: it opens the capture sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get addTask;

  /// No description provided for @typeTasks.
  ///
  /// In en, this message translates to:
  /// **'Type tasks'**
  String get typeTasks;

  /// No description provided for @unfinishedCaptures.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet'**
  String get unfinishedCaptures;

  /// No description provided for @captureDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Capture diagnostics'**
  String get captureDiagnostics;

  /// No description provided for @lists.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get lists;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @noList.
  ///
  /// In en, this message translates to:
  /// **'No project'**
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

  /// No description provided for @repeatNeedsDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date to repeat'**
  String get repeatNeedsDate;

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
  /// **'Files'**
  String get attachments;

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

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
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

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// Subtitle of the Reminders row in Settings when reminders are on; lead is the default reminder time, e.g. ‘10 minutes before’.
  ///
  /// In en, this message translates to:
  /// **'On · {lead}'**
  String remindersOnLead(String lead);

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindersOff;

  /// Subtitle of the Reminders row in Settings when reminders are on but the phone does not allow TaskFlow's notifications.
  ///
  /// In en, this message translates to:
  /// **'Blocked by your phone'**
  String get remindersBlocked;

  /// Subtitle of the Reminders row in Settings when reminders are on and notifications allowed, but “Alarms & reminders” is off, so reminders may come late.
  ///
  /// In en, this message translates to:
  /// **'On · may arrive late'**
  String get remindersOnLate;

  /// No description provided for @otherSettings.
  ///
  /// In en, this message translates to:
  /// **'Other settings'**
  String get otherSettings;

  /// Version line at the bottom of Other settings; version is the version and build, e.g. ‘1.0.5 (4007)’.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow {version}'**
  String appVersion(String version);

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks'**
  String get completedTasks;

  /// No description provided for @exportImport.
  ///
  /// In en, this message translates to:
  /// **'Export & import'**
  String get exportImport;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @deviceDefault.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
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

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZone;

  /// Time & region: the time-zone row’s value while it follows the phone. city is the phone zone’s city, such as Madrid.
  ///
  /// In en, this message translates to:
  /// **'Same as phone ({city})'**
  String timeZoneSameAsPhone(String city);

  /// No description provided for @timezoneHelp.
  ///
  /// In en, this message translates to:
  /// **'New tasks use this time zone to read dates.'**
  String get timezoneHelp;

  /// No description provided for @searchTimezone.
  ///
  /// In en, this message translates to:
  /// **'Find a timezone'**
  String get searchTimezone;

  /// No description provided for @preferenceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference. Please try again.'**
  String get preferenceError;

  /// No description provided for @timezoneFallback.
  ///
  /// In en, this message translates to:
  /// **'The device timezone is unavailable. New tasks will use {zone}.'**
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

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// Calendar's back arrow, read aloud, in the week view: shows the week before.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get previousWeek;

  /// Calendar's forward arrow, read aloud, in the week view: shows the week after.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// Calendar's back arrow, read aloud, in the month view: shows the month before.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// Calendar's forward arrow, read aloud, in the month view: shows the month after.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Read aloud for a day in Calendar's week or month strip: how many open tasks it has. Follows the day's date, after “today · ” when the day is today. Lowercase.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String dayTaskCount(int count);

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get licenses;

  /// Link that opens the website’s Privacy Policy in the app’s language: under the sign-in and create-account card, and a row in Other settings. Named as the site titles the page.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Link that opens the website’s Terms and Conditions in the app’s language: under the sign-in and create-account card, and a row in Other settings. Named as the site titles the page.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @todayAgenda.
  ///
  /// In en, this message translates to:
  /// **'Today’s agenda'**
  String get todayAgenda;

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
  /// **'Nothing planned for this day.'**
  String get calendarEmpty;

  /// Calendar's empty state while the account has no tasks or notes yet and Add a task opens the mic. The quoted example names two tasks on one day, with one date word and no hour, so both land on the same day and Save as a task (the phone's parser) still dates it without a question.
  ///
  /// In en, this message translates to:
  /// **'Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”'**
  String get calendarTrySaying;

  /// Calendar's empty state while the account has no tasks or notes yet and Add a task opens typing. One task, because typed words are parsed on the phone, which can't split them; one date word and no hour from 1 to 12, so it's added with no question.
  ///
  /// In en, this message translates to:
  /// **'Try it: tap Add a task and type “Tomorrow, call the dentist.”'**
  String get calendarTryTyping;

  /// Calendar's empty state while the account has no tasks or notes yet and the button reads New task: it opens the task form (an account without Pro and no free dictation left). The form doesn't read dates from the words: Tomorrow is the chip under the title.
  ///
  /// In en, this message translates to:
  /// **'Try it: tap New task, type “Call the dentist” and tap Tomorrow.'**
  String get calendarTryForm;

  /// No description provided for @planTask.
  ///
  /// In en, this message translates to:
  /// **'Plan a task'**
  String get planTask;

  /// No description provided for @homeCapture.
  ///
  /// In en, this message translates to:
  /// **'Mic button on your home screen'**
  String get homeCapture;

  /// Settings, Other: how to reach capture from outside the app. Names the home-screen widget by its label (capture_widget_label in android/app/src/main/res/values/strings.xml); keep the two the same.
  ///
  /// In en, this message translates to:
  /// **'On Android, long-press the TaskFlow icon for its shortcuts, or add the Dictate a task widget from your launcher. Share text to TaskFlow from another app.'**
  String get homeCaptureInstructions;

  /// No description provided for @widgetPickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Add the TaskFlow widget from your launcher’s widget picker.'**
  String get widgetPickerHelp;

  /// No description provided for @appearanceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your appearance preference.'**
  String get appearanceError;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get list;

  /// Bar at the bottom of an archived project's page, in place of «Add task», for someone who can restore it. Shows only with the «Restore project» button under it.
  ///
  /// In en, this message translates to:
  /// **'Archived project. Restore it to add tasks.'**
  String get archivedListAddHelp;

  /// Bar at the bottom of an archived project's page, in place of «Add task», for someone who can't restore it (a reader, or a project archived with its group). No button follows.
  ///
  /// In en, this message translates to:
  /// **'Archived project.'**
  String get archivedListNoAdd;

  /// No description provided for @yourTasks.
  ///
  /// In en, this message translates to:
  /// **'Your tasks'**
  String get yourTasks;

  /// No description provided for @findTask.
  ///
  /// In en, this message translates to:
  /// **'Find a task…'**
  String get findTask;

  /// Tooltip and screen-reader label of the ✕ at the end of a search field (tasks, notes, projects, the project picker) while it holds text: one tap empties the search and shows the whole list again.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

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

  /// Empty-state title on a shared project's page when only a person's chip filters it and that person has no open tasks assigned in this project. {name} is the name on the chip.
  ///
  /// In en, this message translates to:
  /// **'{name} has nothing open here'**
  String personNothingOpen(String name);

  /// Empty-state message under personNothingOpen. 'All' names the chip forTeam, which shows every task of the project.
  ///
  /// In en, this message translates to:
  /// **'Tap All to see every task.'**
  String get personNothingOpenHelp;

  /// No description provided for @listEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a task to this project. Its date and reminder are yours to choose.'**
  String get listEmpty;

  /// Empty-state message on a project page the user can only view; there is no add button there.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this project yet.'**
  String get readOnlyListEmpty;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap Add a task to add one. A date is optional.'**
  String get tasksEmpty;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tasks without a date wait here until you choose one.\nStart with Add a task.'**
  String get inboxEmpty;

  /// tasksEmpty while the button reads New task (newTask).
  ///
  /// In en, this message translates to:
  /// **'Tap New task to add one. A date is optional.'**
  String get tasksEmptyForm;

  /// inboxEmpty while the button reads New task (newTask).
  ///
  /// In en, this message translates to:
  /// **'Tasks without a date wait here until you choose one.\nStart with New task.'**
  String get inboxEmptyForm;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your saved tasks are still on your device.'**
  String get savedOnDevice;

  /// No description provided for @checkCaptures.
  ///
  /// In en, this message translates to:
  /// **'See what’s not saved yet'**
  String get checkCaptures;

  /// No description provided for @seriesEdits.
  ///
  /// In en, this message translates to:
  /// **'Edits apply to the whole repeating task.'**
  String get seriesEdits;

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

  /// No description provided for @dateForReminder.
  ///
  /// In en, this message translates to:
  /// **'Add a date to use a reminder'**
  String get dateForReminder;

  /// The capture card's line under the date when a reminder was said for a task with no day; tapping it opens the date.
  ///
  /// In en, this message translates to:
  /// **'To remind you, give it a day.'**
  String get reminderNeedsDay;

  /// No description provided for @chooseAlertTime.
  ///
  /// In en, this message translates to:
  /// **'Choose alert time'**
  String get chooseAlertTime;

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

  /// Tooltip and TalkBack label of the delete button on a note's page. The pair of «Delete task».
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

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

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

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

  /// No description provided for @moveError.
  ///
  /// In en, this message translates to:
  /// **'Could not move this task. Please retry.'**
  String get moveError;

  /// Shown when a note could not be moved to another project from its page. The pair of «Could not move this task. Please retry.».
  ///
  /// In en, this message translates to:
  /// **'Could not move this note. Please retry.'**
  String get moveNoteError;

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

  /// Capture sheet status line for a recording that waits on the phone, in Unfinished captures, to be understood. Words and recordings waiting there are “kept”, never “saved”: saving means adding them as a task.
  ///
  /// In en, this message translates to:
  /// **'Recording kept on this phone'**
  String get recordingKept;

  /// No description provided for @onDeviceTranscript.
  ///
  /// In en, this message translates to:
  /// **'On this phone, as you speak'**
  String get onDeviceTranscript;

  /// No description provided for @onlineAudio.
  ///
  /// In en, this message translates to:
  /// **'Online, after you finish'**
  String get onlineAudio;

  /// Heading on the Voice screen above the two choices for how speech becomes text: on this phone while speaking, or online after finishing.
  ///
  /// In en, this message translates to:
  /// **'How speech becomes text'**
  String get speechMethod;

  /// No description provided for @speechLanguage.
  ///
  /// In en, this message translates to:
  /// **'Speech language'**
  String get speechLanguage;

  /// Row in Other settings, and the title of the screen it opens, where the speech language, how speech becomes text and the privacy note live.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceSettings;

  /// Speech language option, the default: capture listens in the app's language.
  ///
  /// In en, this message translates to:
  /// **'Same as the app'**
  String get sameAsApp;

  /// No description provided for @onDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone can’t do this language by itself, so TaskFlow does it online.'**
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

  /// No description provided for @examplePlan.
  ///
  /// In en, this message translates to:
  /// **'Doctor Friday at 5 p.m. Bring my results. Also buy coffee.'**
  String get examplePlan;

  /// Hint in the empty typing field of the capture sheet when typed words are understood on the phone, as one task: a short task with a day and a time the app reads.
  ///
  /// In en, this message translates to:
  /// **'Doctor Friday at 5 p.m.'**
  String get exampleTask;

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

  /// The full voice privacy note at the end of the Voice screen in Settings: on-device or online transcription, why the words go to Google’s AI (adding, finding or changing tasks, and reminders asked for in «Your way», reminderPlanYourWay), saved audio, and what stays on the phone. capturePrivacyLine is its short form in the capture sheet and the reminder sheet.
  ///
  /// In en, this message translates to:
  /// **'Live transcription uses on-device speech where available; no audio is retained in that mode. To add, find or change tasks, or to ask for reminders your way, your words go over the internet to Google’s AI. Saved audio is transcribed online. Anything not saved yet stays on this phone until you save or discard it.'**
  String get capturePrivacy;

  /// One short line, shown once in each of two places: under the words in the capture sheet, the first time the microphone is used on this phone; and under the field of «Your way» (reminderPlanYourWay, Pro) in the reminder sheet, the first time it is opened on this phone. Says the words go to Google’s AI and names where the full note is (Other settings › Voice, as otherSettings and voiceSettings read; keep them identical).
  ///
  /// In en, this message translates to:
  /// **'Your words go to Google’s AI. More in Other settings › Voice.'**
  String get capturePrivacyLine;

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

  /// The day's count under its heading on Calendar. With nothing completed it is the open count alone; with nothing left, the completed count alone. Keep a no-break space between each number and its words, and inside “to do”, so a count never wraps apart.
  ///
  /// In en, this message translates to:
  /// **'{remaining, plural, =0{{done} completed} other{{done, plural, =0{{remaining} to do} other{{remaining} to do · {done} completed}}}}'**
  String agendaCounts(int remaining, int done);

  /// Date line of an open task whose day has passed, in Tareas and on project pages. {date} is the row's date, such as Sat, 17 Oct.
  ///
  /// In en, this message translates to:
  /// **'{date} · Overdue'**
  String overdueDate(String date);

  /// What TalkBack reads for who a task in a shared project is for, on a task row and on the assignment chip. {name} is a person, Me or Everyone.
  ///
  /// In en, this message translates to:
  /// **'Assignee: {name}'**
  String assigneeLabel(String name);

  /// What TalkBack reads for the project chip on a task's details and in the form. {name} is the project's name.
  ///
  /// In en, this message translates to:
  /// **'Project: {name}'**
  String projectLabel(String name);

  /// Header above unfinished tasks from earlier days, shown first on Today.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Overdue · {count}}}'**
  String overdueCount(int count);

  /// No description provided for @pendingCaptureCount.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet · {count}'**
  String pendingCaptureCount(int count);

  /// No description provided for @listeningSeconds.
  ///
  /// In en, this message translates to:
  /// **'Listening · {time}'**
  String listeningSeconds(String time);

  /// How often a task repeats. frequency is the internal rule: daily, weekly, monthly or yearly.
  ///
  /// In en, this message translates to:
  /// **'{frequency, select, daily{{interval, plural, one{Every day} other{Every {interval} days}}} weekly{{interval, plural, one{Every week} other{Every {interval} weeks}}} monthly{{interval, plural, one{Every month} other{Every {interval} months}}} other{{interval, plural, one{Every year} other{Every {interval} years}}}}'**
  String repeatEvery(int interval, String frequency);

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

  /// A task's priority as a phrase, on its row, the dictation's result card and the form's summary: «Prioridad alta», not the standalone «Alta». level is high, medium or low.
  ///
  /// In en, this message translates to:
  /// **'{level, select, high{High priority} medium{Medium priority} other{Low priority}}'**
  String priorityValue(String level);

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickDate;

  /// No description provided for @editStep.
  ///
  /// In en, this message translates to:
  /// **'Edit step'**
  String get editStep;

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

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get addStep;

  /// Under the Add step field when a task already has 50 steps; the typed text stays in the field.
  ///
  /// In en, this message translates to:
  /// **'A task can have up to 50 steps. Remove a step to add this one.'**
  String get stepLimit;

  /// No description provided for @listUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Project unavailable'**
  String get listUnavailable;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @sharedProject.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sharedProject;

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

  /// On Calendar, the message after a row's tick leaves the shown day with no open task (overdue tasks on today included), with Undo. The website demo's line; keep it short and calm.
  ///
  /// In en, this message translates to:
  /// **'All clear. Take a breath.'**
  String get dayAllClear;

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
  /// **'Date removed'**
  String get movedInbox;

  /// No description provided for @scheduleChangedAgain.
  ///
  /// In en, this message translates to:
  /// **'The date changed again. Open the task to check it.'**
  String get scheduleChangedAgain;

  /// No description provided for @scheduleError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the date. Try again.'**
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
  /// **'Changes the start of the series and resets moved or skipped dates. No date stops the repeat.'**
  String get seriesRescheduleHelp;

  /// No description provided for @occurrenceRescheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Other dates in the series stay the same.'**
  String get occurrenceRescheduleHelp;

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

  /// Text button on the Tasks tab, beside Projects, that opens the completed tasks. Short: it shares a row with Projects.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedButton;

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

  /// Title of the dialog when a repeating task's repeat changes while some of its dates were moved or skipped.
  ///
  /// In en, this message translates to:
  /// **'Change how it repeats?'**
  String get changeSeriesQuestion;

  /// Text of the dialog titled changeSeriesQuestion: moved or skipped dates follow the new repeat; completed ones stay in the history.
  ///
  /// In en, this message translates to:
  /// **'Dates you moved or skipped will follow the new repeat. Completed dates stay in the history.'**
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
  /// **'Added with no date'**
  String get taskSavedInbox;

  /// After saving a new task with a date. The date is a weekday and date such as Fri, Oct 17, never Today or Tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Added to {date}'**
  String taskAddedOn(String date);

  /// After saving one new task that has no day but a deadline; the app lands on the deadline's day. The date is the deadline's weekday and date such as Thu, 12 Nov, never Today or Tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Added · due {date}'**
  String taskAddedDue(String date);

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

  /// No description provided for @titleRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get titleRequiredField;

  /// Under a date read from the person's words, typed or spoken, before the Keep my words button.
  ///
  /// In en, this message translates to:
  /// **'From your words'**
  String get fromYourWords;

  /// Text button: the words become the title again, without the date read from them.
  ///
  /// In en, this message translates to:
  /// **'Keep my words'**
  String get keepAsTyped;

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

  /// No description provided for @labelLimit.
  ///
  /// In en, this message translates to:
  /// **'Use up to 10 labels, each up to 32 characters.'**
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

  /// The value of a task's reminder chip (inside reminderValue: “Reminder: 1 hour before · deadline”) when the reminder counts from the task's deadline rather than its day. {lead} is how long before (1 hour before), or the time on the day for a deadline without a time (9:00).
  ///
  /// In en, this message translates to:
  /// **'{lead} · deadline'**
  String reminderBeforeDeadline(String lead);

  /// The reminder line on a task given to someone else. Their reminders are their own and never reach this phone, so none of this account's reminder values is shown. {name} is the person's name.
  ///
  /// In en, this message translates to:
  /// **'Reminder for {name}'**
  String reminderForPersonOnly(String name);

  /// Reminder chip and form row when the task's project is muted, so this phone gives no reminder. Tapping it opens the project's updates setting.
  ///
  /// In en, this message translates to:
  /// **'No reminder: project muted'**
  String get noReminderProjectMuted;

  /// Reminder chip and form row when the task's project (or its group) is archived, so this phone gives no reminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder: project archived'**
  String get noReminderProjectArchived;

  /// Reminder chip and form row when reminders are on but the task's alert time (its own or the default, such as 9:00 for a task without a time) has already gone by, so nothing will ring. Tapping it opens the reminder choices, where a later time can be picked.
  ///
  /// In en, this message translates to:
  /// **'No reminder: the alert time has passed'**
  String get noReminderTimePassed;

  /// Reminder chip and form row once the task's reminder has rung on this phone (not a reminder saved too late to ring, which reads noReminderTimePassed). {when} is today, tomorrow or other: the day it rang; {date} that day as the plan lines write it (sat 24); {time} the clock time it rang, as the app writes it. Tapping it opens the reminder choices.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}'**
  String reminderSent(String when, String date, String time);

  /// Reminder chip and form row after “Snooze 10 min” on the task's reminder, while the snoozed reminder is still to ring. {when} is today, tomorrow or other: the day it rings again; {date} that day as the plan lines write it (sat 24); {time} the clock time it rings again, as the app writes it. Tapping it opens the reminder choices.
  ///
  /// In en, this message translates to:
  /// **'Reminder snoozed: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}'**
  String reminderSnoozed(String when, String date, String time);

  /// On a task with a plan whose reminders have all gone by, once its last one has rung on this phone: the plan in words (reminderPlanStrengthLine or reminderPlanOwnLine), then when that last reminder rang. {when} is today, tomorrow or other; {date} the day (sat 24); {time} the clock time, as the app writes it.
  ///
  /// In en, this message translates to:
  /// **'{plan} · last: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}'**
  String reminderPlanLast(String plan, String when, String date, String time);

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

  /// Button on a file whose upload failed or is waiting: sends the file again.
  ///
  /// In en, this message translates to:
  /// **'Upload again'**
  String get fileRetry;

  /// No description provided for @fileRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get fileRemove;

  /// Tooltip on the remove button next to an attached file. file is the file name.
  ///
  /// In en, this message translates to:
  /// **'Remove {file}'**
  String removeFileNamed(String file);

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

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account'**
  String get accountSaved;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @accountSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get accountSyncing;

  /// No description provided for @importLocalItems.
  ///
  /// In en, this message translates to:
  /// **'Import local tasks and notes'**
  String get importLocalItems;

  /// No description provided for @accountImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing tasks and notes'**
  String get accountImporting;

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

  /// No description provided for @accountSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out'**
  String get accountSigningOut;

  /// No description provided for @signOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out? Reminders on this phone stop until you sign in again.'**
  String get signOutQuestion;

  /// No description provided for @recoveryHeading.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get recoveryHeading;

  /// No description provided for @registerHeading.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerHeading;

  /// No description provided for @signInHeading.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInHeading;

  /// Heading of sign-in's first screen, where only Continue with Google and Continue with my email show, for new and returning people alike.
  ///
  /// In en, this message translates to:
  /// **'Sign in or sign up'**
  String get signInOrUpHeading;

  /// No description provided for @authPitch.
  ///
  /// In en, this message translates to:
  /// **'Note down what you need to do, and TaskFlow puts it on your calendar.'**
  String get authPitch;

  /// Shown above the sign-in form when the session ended while the app was open.
  ///
  /// In en, this message translates to:
  /// **'You were signed out. Sign in again to pick up where you left off.'**
  String get signInAgainReason;

  /// No description provided for @recoveryHelp.
  ///
  /// In en, this message translates to:
  /// **'Request a recovery email, then use the code to set a new password.'**
  String get recoveryHelp;

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
  /// **'At least 12 characters, not only numbers'**
  String get passwordHelp;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters'**
  String get passwordTooShort;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

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

  /// No description provided for @createAccountWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Create an account with this email'**
  String get createAccountWithEmail;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with this email'**
  String get signInWithEmail;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @sendRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendRecoveryCode;

  /// No description provided for @saveNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get saveNewPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @accountGuestHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your tasks and notes.'**
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

  /// Recovery, shown above the recovery code field after the code was requested. Names the address typed without saying whether it has an account.
  ///
  /// In en, this message translates to:
  /// **'If {email} has an account, an email with a code is on its way. Type it here.'**
  String recoveryEmailRequested(String email);

  /// Recovery, shown above the recovery code field instead of recoveryEmailRequested when the code typed had expired or was locked: the app asked for a new code for that address at once and cleared the field. Names the address without saying whether it has an account.
  ///
  /// In en, this message translates to:
  /// **'That code no longer works. If {email} has an account, a new one is on its way.'**
  String recoveryCodeRenewed(String email);

  /// No description provided for @passwordResetComplete.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Sign in with your new password.'**
  String get passwordResetComplete;

  /// Heading of the screen that asks for the 6-digit code the server emailed: after creating an account, or after signing in to one whose address isn't confirmed yet.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyEmailHeading;

  /// Under that heading. {email} is the address the code went to.
  ///
  /// In en, this message translates to:
  /// **'We’ve sent a 6-digit code to {email}. Type it here.'**
  String verifyEmailHelp(String email);

  /// Label of the field for the emailed code. It confirms by itself once 6 digits are typed or pasted.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get verifyEmailCode;

  /// Under the code field when Confirm is tapped with fewer than 6 digits typed. Also under the recovery code field when Save new password is tapped without 6 digits.
  ///
  /// In en, this message translates to:
  /// **'The code has 6 digits'**
  String get verifyEmailCodeLength;

  /// Sends the typed code. When it is right, the person is signed in.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verifyEmailConfirm;

  /// What TalkBack reads for the spinner inside the Confirm button (verifyEmailConfirm) while the code is being checked.
  ///
  /// In en, this message translates to:
  /// **'Confirming'**
  String get verifyEmailConfirming;

  /// Emails a new code. For 60 seconds after each code is sent it is disabled and reads verifyEmailResendIn. When the server refuses because too many codes were asked for, it stays disabled for the wait it names, reading verifyEmailResendInMinutes while over a minute is left.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyEmailResend;

  /// The resend button while it waits, counting down each second from 60, or through the last minute of a longer wait.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Resend code in 1 second} other{Resend code in {seconds} seconds}}'**
  String verifyEmailResendIn(int seconds);

  /// The resend button while a wait the server set is longer than a minute, in whole minutes rounded up; under a minute the button counts seconds with verifyEmailResendIn.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Resend code in 1 minute} other{Resend code in {minutes} minutes}}'**
  String verifyEmailResendInMinutes(int minutes);

  /// Under the code field when the server refused to send another code because too many were asked for, and the wait is longer than a minute. No new code went out, so the last one still works. The minutes are rounded up, at least 1.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{You’ve asked for a lot of codes. Wait a minute to ask for another.} other{You’ve asked for a lot of codes. Wait {minutes} minutes to ask for another.}}'**
  String verifyEmailResendLimited(int minutes);

  /// Under the code field after a new code was emailed, when the person has shown they didn’t get the first one. Names the mail folders where codes often land, as Gmail names them in the language (Spam and Promotions in English).
  ///
  /// In en, this message translates to:
  /// **'We’ve sent you a new code. If you can’t see it, check Spam or Promotions.'**
  String get verifyEmailResent;

  /// Under the code field when the server says the code is wrong. Only the newest code emailed works. The same digits aren't sent again; changing one clears this line. Also under the recovery code field when the server says the recovery code is wrong; the new password typed stays.
  ///
  /// In en, this message translates to:
  /// **'That code isn’t right. Check the newest email we sent.'**
  String get verifyEmailCodeInvalid;

  /// Under the code field when the code is too old, or was tried too many times, and a minute or more has passed since the last code: a new code has just been emailed. The field is emptied and Resend code counts down again.
  ///
  /// In en, this message translates to:
  /// **'That code no longer works. We’ve sent you a new one.'**
  String get verifyEmailCodeSpentNew;

  /// Under the code field when the code is too old, or was tried too many times, less than a minute after the last code was sent: no new code could be sent yet. Names the button verifyEmailResend, which is still counting down.
  ///
  /// In en, this message translates to:
  /// **'That code no longer works. Tap “Resend code” when the countdown ends.'**
  String get verifyEmailCodeSpentWait;

  /// Goes back to creating an account, with the email kept so it can be corrected.
  ///
  /// In en, this message translates to:
  /// **'Use another email'**
  String get verifyEmailOtherAddress;

  /// Under Create account, back from the confirm screen, when the address was registered again with another password before it was confirmed. The email is kept and the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Someone has created an account with this email again. Create it again to continue.'**
  String get verifyEmailReplaced;

  /// Under the password field of the confirm screen, when it reopened after the app was closed and asks for the password itself: the password typed on this screen isn’t the account’s. Names “Use another email” (verifyEmailOtherAddress), the way out for a forgotten password; the quoted label must match it.
  ///
  /// In en, this message translates to:
  /// **'That isn’t this account’s password. Don’t remember it? Tap “Use another email” and create the account again.'**
  String get verifyEmailWrongPassword;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newList;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get editList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get listName;

  /// No description provided for @listNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home, Work, Shopping…'**
  String get listNameHint;

  /// No description provided for @listNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name your project.'**
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
  /// **'Save project'**
  String get saveList;

  /// Button of the new-project dialog that creates the project. Editing a project says «Save project».
  ///
  /// In en, this message translates to:
  /// **'Create project'**
  String get createList;

  /// No description provided for @listSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this project. Please retry.'**
  String get listSaveError;

  /// No description provided for @listRestored.
  ///
  /// In en, this message translates to:
  /// **'Project restored'**
  String get listRestored;

  /// No description provided for @projectArchivedNoReminders.
  ///
  /// In en, this message translates to:
  /// **'{name} archived — hidden from your calendar, no reminders.'**
  String projectArchivedNoReminders(String name);

  /// No description provided for @listUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this project. Please retry.'**
  String get listUpdateError;

  /// No description provided for @chooseListDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose project details'**
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
  /// **'Could not resolve this project. Please retry.'**
  String get listResolveError;

  /// No description provided for @retryLists.
  ///
  /// In en, this message translates to:
  /// **'Retry projects'**
  String get retryLists;

  /// No description provided for @listsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'A place for each part of life'**
  String get listsEmptyTitle;

  /// No description provided for @listsEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Start with Home, Work or Shopping. Tasks can move whenever you like.'**
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
  /// **'Restore project'**
  String get restoreList;

  /// No description provided for @archiveList.
  ///
  /// In en, this message translates to:
  /// **'Archive project'**
  String get archiveList;

  /// No description provided for @chooseDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose details'**
  String get chooseDetails;

  /// No description provided for @invitationCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get invitationCode;

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

  /// Opens sharing for a project nobody else can see yet, on the project page and in its menu.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareProject;

  /// Project page button once others have access. {count} is everyone with access, the owner included.
  ///
  /// In en, this message translates to:
  /// **'Members · {count}'**
  String projectMembersCount(int count);

  /// No description provided for @shareProjectHelp.
  ///
  /// In en, this message translates to:
  /// **'They’ll see everything in {project}.'**
  String shareProjectHelp(String project);

  /// No description provided for @sendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get sendInvitation;

  /// Title of the email dialog that invites a person to a project or a group. {name} is the project’s or group’s name.
  ///
  /// In en, this message translates to:
  /// **'Who are you inviting to {name}?'**
  String inviteWho(String name);

  /// Shown under the invite dialog’s email field when the person typed their own account’s address; nothing is sent.
  ///
  /// In en, this message translates to:
  /// **'That’s your own email. Type the other person’s.'**
  String get inviteOwnEmail;

  /// The signed-in account’s own row in a project’s or a group’s member list. {name} is their name.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String personYou(String name);

  /// No description provided for @invitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get invitationSent;

  /// No description provided for @invitationCodeFallback.
  ///
  /// In en, this message translates to:
  /// **'If the email doesn’t arrive, send them this code:'**
  String get invitationCodeFallback;

  /// No description provided for @connectToShare.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to share.'**
  String get connectToShare;

  /// No description provided for @sendInvitationAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendInvitationAgain;

  /// No description provided for @cancelInvitation.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get cancelInvitation;

  /// No description provided for @enterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter an email address.'**
  String get enterEmailAddress;

  /// Sharing screen, under “How sharing works”: what editors and the owner can do, and that shared tasks stay in the project.
  ///
  /// In en, this message translates to:
  /// **'Editors can add, change, complete and delete tasks and files. Only the owner manages the project and people. Shared tasks stay in this project.'**
  String get sharingRolesHelp;

  /// No description provided for @listSharing.
  ///
  /// In en, this message translates to:
  /// **'Project sharing'**
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

  /// No description provided for @invitePerson.
  ///
  /// In en, this message translates to:
  /// **'Invite a person'**
  String get invitePerson;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'Members'**
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

  /// Sharing screen, the “Remove access” confirmation: what the person loses. Plain words, no sync jargon: edits they haven’t sent yet are lost.
  ///
  /// In en, this message translates to:
  /// **'This person will lose access to this project and its tasks, notes and files. Changes they haven’t sent yet will be lost.'**
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

  /// No description provided for @howSharingWorks.
  ///
  /// In en, this message translates to:
  /// **'How sharing works'**
  String get howSharingWorks;

  /// Sharing screen, under “How sharing works”: what a shared project shares. Reminders are each person’s own (none of their values reaches anyone else), so the last sentence says they aren’t shared.
  ///
  /// In en, this message translates to:
  /// **'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Reminders aren’t shared: each person has their own.'**
  String get sharedDataHelp;

  /// Sharing screen, under “How sharing works”: what happens to a shared project on this phone after leaving or losing access. Plain words, no sync jargon.
  ///
  /// In en, this message translates to:
  /// **'When you leave or lose access, the project leaves this phone the next time it connects. Copies you exported stay.'**
  String get sharingRemovalHelp;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get deleteList;

  /// No description provided for @deleteListHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete this project and all its tasks, notes and uploaded files for everyone? This cannot be undone.'**
  String get deleteListHelp;

  /// No description provided for @deleteListPrivateHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} with all its tasks, notes and files? This can’t be undone.'**
  String deleteListPrivateHelp(String name);

  /// No description provided for @deleteListForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete project for everyone'**
  String get deleteListForEveryone;

  /// No description provided for @leaveList.
  ///
  /// In en, this message translates to:
  /// **'Leave project'**
  String get leaveList;

  /// No description provided for @leaveListHelp.
  ///
  /// In en, this message translates to:
  /// **'Shared tasks, notes, files and any unsent edits will be removed from this phone. Other members keep the project.'**
  String get leaveListHelp;

  /// No description provided for @youLeft.
  ///
  /// In en, this message translates to:
  /// **'You left {name}'**
  String youLeft(String name);

  /// No description provided for @projectDeleted.
  ///
  /// In en, this message translates to:
  /// **'Project deleted'**
  String get projectDeleted;

  /// No description provided for @groupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get groupDeleted;

  /// No description provided for @invitationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the full invitation code.'**
  String get invitationCodeRequired;

  /// No description provided for @invitationCodeWrong.
  ///
  /// In en, this message translates to:
  /// **'Ask the person who invited you for the current code.'**
  String get invitationCodeWrong;

  /// No description provided for @invitationResponseError.
  ///
  /// In en, this message translates to:
  /// **'Could not respond. Retry when connected.'**
  String get invitationResponseError;

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

  /// A card for a pending invitation, on Calendar, Projects and Groups; tapping it opens the join dialog.
  ///
  /// In en, this message translates to:
  /// **'You’re invited to {name} · View'**
  String invitedTo(String name);

  /// The invitation card when the server says who sent it: sender's name, then the project or group.
  ///
  /// In en, this message translates to:
  /// **'{sender} invited you to “{name}” · View'**
  String invitedByTo(String sender, String name);

  /// How many more invitations wait behind the one shown.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String invitationsMore(int count);

  /// No description provided for @joinInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Join {name}'**
  String joinInvitationTitle(String name);

  /// No description provided for @joinInvitationHelp.
  ///
  /// In en, this message translates to:
  /// **'Open your invitation email and tap its link. Or paste the code from it here.'**
  String get joinInvitationHelp;

  /// No description provided for @joinInvitation.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinInvitation;

  /// No description provided for @declineInvitationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Decline the invitation to {name}? You’d need a new one to join later.'**
  String declineInvitationConfirm(String name);

  /// No description provided for @joinedInvitation.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}'**
  String joinedInvitation(String name);

  /// No description provided for @invitationNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get invitationNotNow;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

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
  /// **'New files upload to your account after saving, up to 6 MB each. Older local files stay on this device until you choose Upload in task details.'**
  String get fileUploadHelp;

  /// No description provided for @fileLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose a non-empty file up to 6 MB. You can attach up to 20 files per task.'**
  String get fileLimit;

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

  /// No description provided for @noReminderTurnOn.
  ///
  /// In en, this message translates to:
  /// **'No reminder · Turn on'**
  String get noReminderTurnOn;

  /// No description provided for @exactAlarmsNeeded.
  ///
  /// In en, this message translates to:
  /// **'To get reminders on time, allow “Alarms & reminders”.'**
  String get exactAlarmsNeeded;

  /// Second line of the sheet that asks for “Alarms & reminders”, under exactAlarmsNeeded: what to do on Android's page the button opens, which has a switch and no Done button.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, turn on the switch, then come back.'**
  String get exactAlarmsNextScreen;

  /// No description provided for @remindersOnConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Done. Reminders are on.'**
  String get remindersOnConfirmation;

  /// Asked once, in a sheet, right after the first task with a date is saved; "it" is that task.
  ///
  /// In en, this message translates to:
  /// **'Want a reminder before it?'**
  String get reminderAskQuestion;

  /// No description provided for @reminderAskYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me'**
  String get reminderAskYes;

  /// No description provided for @reminderAskNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get reminderAskNotNow;

  /// Title of a sheet asked once, right after an account without a name sends its first invitation or joins its first project or group.
  ///
  /// In en, this message translates to:
  /// **'What’s your name?'**
  String get nameAskTitle;

  /// Line under nameAskTitle: why the name is asked.
  ///
  /// In en, this message translates to:
  /// **'It’s how people you share projects with will see you.'**
  String get nameAskBody;

  /// Label of the name field in the name sheet, prefilled from the email; also the title of the name row in the Account screen, over the person's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameAskField;

  /// Account screen: the name row's title when the account has no name yet; opens the name sheet.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get accountAddName;

  /// Closes the name sheet without saving; it isn't asked again.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get nameAskNotNow;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @mobileNotificationsOnly.
  ///
  /// In en, this message translates to:
  /// **'Mobile notifications only'**
  String get mobileNotificationsOnly;

  /// Reminders: the phone does not allow TaskFlow's notifications. Shown on the Reminders screen and as a message after the person refuses Android's prompt.
  ///
  /// In en, this message translates to:
  /// **'Your phone isn’t letting TaskFlow notify you.'**
  String get notificationPermissionOff;

  /// Button under notificationPermissionOff, and that message's action: opens TaskFlow's notifications page in the phone's settings.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

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

  /// No description provided for @allowPreciseAlarms.
  ///
  /// In en, this message translates to:
  /// **'Allow “Alarms & reminders”'**
  String get allowPreciseAlarms;

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

  /// Settings › Reminders, under “Date-only tasks” when it is off and some open task has an “Until the deadline” plan without its own time: those plans still ring at {time}. {time} is the default hour in the app’s clock format (9:00 AM). Follows the sheet’s name for the plan (reminderPlanUntilDay).
  ///
  /// In en, this message translates to:
  /// **'Off · “Until the deadline”: {time}'**
  String dateOnlyOffPlans(String time);

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

  /// Reminders › Details on Android: when the list of upcoming alerts set on the phone is updated.
  ///
  /// In en, this message translates to:
  /// **'Upcoming alerts update when you open the app and, when Android allows it, every hour.'**
  String get androidAlertRefreshHelp;

  /// Reminders › Details on other systems: when the list of upcoming alerts set on the phone is updated.
  ///
  /// In en, this message translates to:
  /// **'Upcoming alerts update when you open the app and when your phone allows it.'**
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

  /// No description provided for @exportImportIntro.
  ///
  /// In en, this message translates to:
  /// **'Save a copy of your tasks to a file, or bring tasks from Todoist.'**
  String get exportImportIntro;

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
  /// **'Choose a TaskFlow file or a project exported from Todoist. You’ll review it before importing.'**
  String get chooseImportFileHelp;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Import preview'**
  String get importPreview;

  /// No description provided for @importCopiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Selected tasks, notes and the file’s projects are added as personal copies. Existing content is kept. Re-importing this same file skips records already imported on this phone; a changed or newly exported file counts as a different import.'**
  String get importCopiesHelp;

  /// No description provided for @listsIncluded.
  ///
  /// In en, this message translates to:
  /// **'Projects included'**
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

  /// Reminders › Details: how many later alerts are not set on the phone yet, because only the nearest ones fit; the next update sets them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 later alert isn’t set yet.} other{{count} later alerts aren’t set yet.}} The next update sets the nearest ones.'**
  String deferredAlerts(int count);

  /// No description provided for @turnOffReminder.
  ///
  /// In en, this message translates to:
  /// **'Turn off {title}'**
  String turnOffReminder(String title);

  /// No description provided for @importResult.
  ///
  /// In en, this message translates to:
  /// **'Added {items, plural, =1{1 item} other{{items} items}} and {lists, plural, =1{1 project} other{{lists} projects}}.'**
  String importResult(int items, int lists);

  /// No description provided for @importSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count, plural, =1{1 already imported item} other{{count} already imported items}}.'**
  String importSkipped(int count);

  /// No description provided for @importCounts.
  ///
  /// In en, this message translates to:
  /// **'{source} · {tasks} tasks · {notes} notes · {lists} projects'**
  String importCounts(String source, int tasks, int notes, int lists);

  /// No description provided for @cannotImport.
  ///
  /// In en, this message translates to:
  /// **'Cannot import: {reason}'**
  String cannotImport(String reason);

  /// No description provided for @importSelected.
  ///
  /// In en, this message translates to:
  /// **'Import {count, plural, =1{1 selected item} other{{count} selected items}} and projects'**
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
  /// **'Invalid project metadata.'**
  String get archiveInvalidList;

  /// No description provided for @archiveDuplicateLists.
  ///
  /// In en, this message translates to:
  /// **'Duplicate project identifiers.'**
  String get archiveDuplicateLists;

  /// No description provided for @archiveInvalidListStyle.
  ///
  /// In en, this message translates to:
  /// **'Invalid project color or archive status.'**
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
  /// **'The task refers to a project missing from this file.'**
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
  /// **'Imports create new personal copies. Account access, files, notification preferences and anything not saved yet are not included.'**
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
  /// **'The original schedule needs review; this task will have no date.'**
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
  /// **'Row {row}: section name is invalid; its tasks will have no project.'**
  String archiveCsvInvalidSection(int row);

  /// No description provided for @archiveCsvListDescription.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: project descriptions are not supported.'**
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
  /// **'{field, select, export_id{export_id} tasks{tasks} lists{projects} list_id{project id} list_name{project name} task_identifier{task identifier} title{title} notes{notes} priority{priority} duration{duration} repeat_interval{repeat interval} repeat_weekdays{repeat weekdays} weekday{weekday} completed_dates{completed dates} individual_date_changes{individual date changes} list_identifier{list identifier} labels{labels} label{label} checklist{checklist} checklist_identifier{checklist identifier} checklist_title{checklist title} checklist_dates{checklist dates} reminder_lead{reminder lead} reminder_time{reminder time} other{field}}'**
  String archiveField(String field);

  /// No description provided for @notificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Task reminders'**
  String get notificationChannel;

  /// No description provided for @notificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get notificationComplete;

  /// No description provided for @notificationSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10 min'**
  String get notificationSnooze;

  /// Reminder body: when the task is due. day is today, tomorrow or other; date is the weekday date; hour is the hour as shown, for the article (Spanish and Catalan say a la 1:00).
  ///
  /// In en, this message translates to:
  /// **'{hour, plural, other{{day, select, today{Today at {time}} tomorrow{Tomorrow at {time}} other{{date} at {time}}}}}'**
  String notificationAt(String day, String date, String time, int hour);

  /// Reminder body for a deadline. Placeholders as in notificationAt.
  ///
  /// In en, this message translates to:
  /// **'{hour, plural, other{{day, select, today{Deadline: today at {time}} tomorrow{Deadline: tomorrow at {time}} other{Deadline: {date} at {time}}}}}'**
  String notificationDeadlineAt(String day, String date, String time, int hour);

  /// No description provided for @notificationDeadlineToday.
  ///
  /// In en, this message translates to:
  /// **'Deadline: today'**
  String get notificationDeadlineToday;

  /// Reminder body: when, from notificationAt, then how far away.
  ///
  /// In en, this message translates to:
  /// **'{when} · in {minutes} min'**
  String notificationInMinutes(String when, int minutes);

  /// Reminder body: when, from notificationAt, then how far away.
  ///
  /// In en, this message translates to:
  /// **'{when} · in {hours} h'**
  String notificationInHours(String when, int hours);

  /// Replaces a reminder for a few seconds after Complete, beside an Undo action. Also the message, with Undo, after a dictation marked exactly one task as done.
  ///
  /// In en, this message translates to:
  /// **'Completed: {title}'**
  String notificationCompleted(String title);

  /// No description provided for @notificationToday.
  ///
  /// In en, this message translates to:
  /// **'On your list for today.'**
  String get notificationToday;

  /// No description provided for @notificationMorning.
  ///
  /// In en, this message translates to:
  /// **'Make room for today'**
  String get notificationMorning;

  /// No description provided for @notificationEvening.
  ///
  /// In en, this message translates to:
  /// **'A moment to check in'**
  String get notificationEvening;

  /// No description provided for @notificationCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Open TaskFlow to see your current tasks and plan your next step.'**
  String get notificationCheckIn;

  /// No description provided for @captureGone.
  ///
  /// In en, this message translates to:
  /// **'Your words are no longer available.'**
  String get captureGone;

  /// No description provided for @captureNoteLength.
  ///
  /// In en, this message translates to:
  /// **'A note needs 1 to 8000 characters.'**
  String get captureNoteLength;

  /// Capture sheet banner, read out once, when the assistant found no task and no command in the words. Gives an example of what to say next; Say again (captureSayAgain) is the button under it.
  ///
  /// In en, this message translates to:
  /// **'I didn’t find a task. Say what and when, for example: “Tomorrow, call the dentist.”'**
  String get captureNoTasks;

  /// Capture sheet banner when there is no internet and there are words to save. Names the Save as a task button under it, which works offline: keep that name identical to captureSaveAsWritten. Words waiting in Unfinished captures are “kept”, never “saved”.
  ///
  /// In en, this message translates to:
  /// **'No internet. Tap Save as a task, or try again when you’re online.'**
  String get captureOffline;

  /// Capture sheet banner when there is no internet and the capture is only a recording, with no words yet, so there is no Save as a task button. The recording waits in Unfinished captures: it is “kept”, never “saved”.
  ///
  /// In en, this message translates to:
  /// **'No internet. Your recording is kept; try again when you’re online.'**
  String get captureOfflineRecording;

  /// Capture sheet banner when the server that understands the words can’t be reached or took too long. Names no assistant, which the app never introduces. The words wait in Unfinished captures: “kept”, never “saved”.
  ///
  /// In en, this message translates to:
  /// **'I can’t turn your words into tasks right now; they’re kept.'**
  String get captureUnavailable;

  /// Shown in the dictation sheet when many dictations came in a row and the per-minute limit refused this one. Names the Try again button under it; waiting a minute is enough.
  ///
  /// In en, this message translates to:
  /// **'You’ve dictated a lot in a row. Wait a minute, then tap Try again.'**
  String get captureTooFast;

  /// No description provided for @captureAllowance.
  ///
  /// In en, this message translates to:
  /// **'You’ve reached today’s dictation limit. Tap Save as a task, or try again tomorrow.'**
  String get captureAllowance;

  /// Capture sheet banner when the daily dictation limit refuses a recording that has no words yet. The only button is Close; the recording stays in Pending captures.
  ///
  /// In en, this message translates to:
  /// **'You’ve reached today’s dictation limit. Your recording is kept; try again tomorrow.'**
  String get captureAllowanceRecording;

  /// No description provided for @captureSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to turn your words into tasks.'**
  String get captureSignIn;

  /// No description provided for @captureForbidden.
  ///
  /// In en, this message translates to:
  /// **'This account can’t turn your words into tasks. Check your access and try again.'**
  String get captureForbidden;

  /// No description provided for @captureTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This recording is too long. Discard it and dictate something shorter.'**
  String get captureTooLarge;

  /// No description provided for @captureTypedFirst.
  ///
  /// In en, this message translates to:
  /// **'Save or discard what you typed before starting a recording.'**
  String get captureTypedFirst;

  /// Capture sheet banner, not an error, after the person refused the microphone and Android can still ask. Names the two buttons shown under it: Start talking (captureStartTalking) and Type instead (captureTypeInstead).
  ///
  /// In en, this message translates to:
  /// **'Without the microphone I can’t hear you. Tap Start talking to allow it, or Type instead.'**
  String get captureMicrophone;

  /// Capture sheet banner, not an error, when Android will no longer ask for the microphone. The steps name Android’s own App info screen: Permissions, then Microphone, then Allow.
  ///
  /// In en, this message translates to:
  /// **'To dictate again, open Settings and tap Permissions › Microphone › Allow.'**
  String get captureMicrophoneBlocked;

  /// Opens the phone’s settings for TaskFlow, to turn the microphone on.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get captureOpenSettings;

  /// One line in the capture sheet, in place of the Done button, while Android’s own microphone question is open the first time. Says why the app asks.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone to dictate your tasks. It only listens while you dictate.'**
  String get captureMicrophoneWhy;

  /// Capture status while the microphone starts, before it is listening.
  ///
  /// In en, this message translates to:
  /// **'One moment…'**
  String get captureStarting;

  /// Capture status after leaving the app or an interruption ended listening; the words are kept.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get capturePaused;

  /// Announced to screen readers when the capture sheet starts listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get captureListening;

  /// With a screen reader on, the capture sheet waits for this button before it listens.
  ///
  /// In en, this message translates to:
  /// **'Start talking'**
  String get captureStartTalking;

  /// Capture sheet: listens again and adds to the words already heard.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get captureContinue;

  /// Keyboard button in the capture sheet: stops listening and lets you edit the words.
  ///
  /// In en, this message translates to:
  /// **'Type instead'**
  String get captureTypeInstead;

  /// Shown under the words after about 5 seconds without new words, once some words were heard.
  ///
  /// In en, this message translates to:
  /// **'Still listening. Tap Done when finished.'**
  String get captureStillListening;

  /// Shown under the microphone after about 5 seconds of listening with no words heard yet, on the phone’s own speech recognition. Names the Type instead button (captureTypeInstead).
  ///
  /// In en, this message translates to:
  /// **'Nothing heard yet. Speak when you’re ready, or tap Type instead.'**
  String get captureNothingHeardYet;

  /// Shown under the microphone from the start of listening when the words are understood online: no words appear while speaking. Names the Done button (done); after Done the sheet shows the result, what was understood, and the words themselves only behind See what I said (reviewOriginal).
  ///
  /// In en, this message translates to:
  /// **'I’m listening. Tap Done to see what I understood.'**
  String get captureListeningOnline;

  /// Shown under the microphone in the last 10 seconds of the 60-second listening limit, counting down each second; read out once, at 10 seconds left.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second left} other{{seconds} seconds left}}'**
  String captureTimeLeft(int seconds);

  /// The question asked when leaving the capture sheet with something said: by Cancel, Back, a tap above the sheet or a swipe down, while listening, or on the result of spoken words. No body text; its buttons are discard and keep.
  ///
  /// In en, this message translates to:
  /// **'Keep what you said for later?'**
  String get captureKeepQuestion;

  /// The question asked when leaving the capture sheet with something typed or shared: by Cancel, Back, a tap above the sheet or a swipe down, while typing, or on the result of written words. No body text; its buttons are discard and keep.
  ///
  /// In en, this message translates to:
  /// **'Keep the text for later?'**
  String get captureKeepTextQuestion;

  /// No description provided for @captureRecordingFirst.
  ///
  /// In en, this message translates to:
  /// **'Retry this recording or discard it before recording another.'**
  String get captureRecordingFirst;

  /// No description provided for @captureEmptyInput.
  ///
  /// In en, this message translates to:
  /// **'Say or type what you need to do first.'**
  String get captureEmptyInput;

  /// No description provided for @captureSpeechStopped.
  ///
  /// In en, this message translates to:
  /// **'Listening stopped. You can talk again, or type.'**
  String get captureSpeechStopped;

  /// No description provided for @captureNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'I didn’t catch that. Try again, or type it.'**
  String get captureNoSpeech;

  /// Capture sheet, when neither the phone’s own speech recognition nor listening online could start. Names the Type instead button (captureTypeInstead).
  ///
  /// In en, this message translates to:
  /// **'I can’t listen on this phone right now. Tap Type instead.'**
  String get captureCantListen;

  /// No description provided for @captureIncompleteAudio.
  ///
  /// In en, this message translates to:
  /// **'This recording can’t be used. Discard it and dictate it again.'**
  String get captureIncompleteAudio;

  /// No description provided for @captureWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t keep this on your phone. Try again before leaving.'**
  String get captureWriteFailed;

  /// No description provided for @captureStopFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn’t finish listening. What you said before is kept.'**
  String get captureStopFailed;

  /// No description provided for @captureDiscardFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not discard your words. They are still kept.'**
  String get captureDiscardFailed;

  /// No description provided for @captureReviewWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not keep these changes. Please try again before leaving.'**
  String get captureReviewWriteFailed;

  /// No description provided for @captureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add it. Your words are still here; try again.'**
  String get captureSaveFailed;

  /// No description provided for @captureSetupRequested.
  ///
  /// In en, this message translates to:
  /// **'Speech setup was requested. Follow any Android prompt, then tap Check again. You can keep typing meanwhile.'**
  String get captureSetupRequested;

  /// Banner on the Voice screen after Android was asked to set up on-device speech for the language. The button name must match checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Follow Android’s steps, then tap Check again.'**
  String get voiceSetupRequested;

  /// Banner on the Voice screen when Android's on-device speech setup for the language cannot be opened. Live transcription then runs online.
  ///
  /// In en, this message translates to:
  /// **'This phone can’t set this up, so TaskFlow does it online.'**
  String get voiceSetupUnavailable;

  /// No description provided for @captureSetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech setup is unavailable here. Use saved audio or type.'**
  String get captureSetupUnavailable;

  /// No description provided for @voiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Voice recording'**
  String get voiceRecording;

  /// No description provided for @capturesCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get capturesCaughtUp;

  /// Empty state of Unfinished captures. What waits there is “kept”, never “saved”: saving means adding it as a task.
  ///
  /// In en, this message translates to:
  /// **'Recordings and tasks you leave unfinished are kept here.'**
  String get capturesEmptyHelp;

  /// In Unfinished captures, under a capture's first task: how many of its tasks are not added yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 not added yet} other{{count} not added yet}}'**
  String captureDraftSummary(int count);

  /// No description provided for @editCaptureItem.
  ///
  /// In en, this message translates to:
  /// **'Edit {title}'**
  String editCaptureItem(String title);

  /// No description provided for @removeCaptureItem.
  ///
  /// In en, this message translates to:
  /// **'Remove {title}'**
  String removeCaptureItem(String title);

  /// No description provided for @captureTasksAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 task added} other{{count} tasks added}}'**
  String captureTasksAdded(int count);

  /// Brief message, with Undo, after several new tasks were saved and every one of them landed on the same day, the day Calendar then shows. {count} is how many were added; {date} is that day as taskAddedOn writes it, weekday first (“Thu, Oct 29”), never Today or Tomorrow. Tasks on several days, or one without a date, use captureTasksAdded instead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task added to {date}} other{{count} tasks added to {date}}}'**
  String captureTasksAddedOn(int count, String date);

  /// No description provided for @captureKeptForReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 kept for review} other{{count} kept for review}}'**
  String captureKeptForReview(int count);

  /// After a save, follows the count of tasks added ("2 tasks added · also on Sat, Oct 17") when one other task is on a day other than the one Calendar shows. The date is a weekday and date such as Sat, Oct 17.
  ///
  /// In en, this message translates to:
  /// **'also on {date}'**
  String captureAlsoOn(String date);

  /// After a save, follows the count of tasks added ("3 tasks added · also on 2 other days") when the tasks fall on several days other than the one Calendar shows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{also on 1 other day} other{also on {count} other days}}'**
  String captureAlsoOnDays(int count);

  /// No description provided for @captureConfirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Use the details shown'**
  String get captureConfirmDetails;

  /// No description provided for @captureNothingToReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to review'**
  String get captureNothingToReview;

  /// No description provided for @captureRemovedDraftsHelp.
  ///
  /// In en, this message translates to:
  /// **'Nothing will change.'**
  String get captureRemovedDraftsHelp;

  /// No description provided for @captureFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get captureFinish;

  /// Screen-reader label of the field in the capture sheet where the person types (or sees) the words for their tasks. Not shown on screen.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get captureYourWords;

  /// No description provided for @captureCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Check the details above'**
  String get captureCheckDetails;

  /// No description provided for @captureUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding…'**
  String get captureUnderstanding;

  /// Capture sheet banner for a rare failure with nothing else to explain it. The words stay in the sheet and in Unfinished captures: “kept” or “still here”, never “saved”.
  ///
  /// In en, this message translates to:
  /// **'That didn’t work. Your words are still here — try again.'**
  String get captureFailed;

  /// No description provided for @captureSlow.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual.'**
  String get captureSlow;

  /// Button on the capture sheet: the fallback that saves the words as one task, read on the phone (its day and time from the words). It shows after 8 s of waiting for the assistant (a text button, as nothing is ready to confirm yet), after a failure (below Try again), and on a command result that found nothing. captureOffline names it: keep the two identical.
  ///
  /// In en, this message translates to:
  /// **'Save as a task'**
  String get captureSaveAsWritten;

  /// No description provided for @captureThingsToAdd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 thing to add} other{{count} things to add}}'**
  String captureThingsToAdd(int count);

  /// No description provided for @captureAddToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get captureAddToCalendar;

  /// No description provided for @captureAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get captureAddTask;

  /// No description provided for @captureAddTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Add 1 task} other{Add {count} tasks}}'**
  String captureAddTasks(int count);

  /// No description provided for @captureSayAgain.
  ///
  /// In en, this message translates to:
  /// **'Say it again'**
  String get captureSayAgain;

  /// No description provided for @labelsExample.
  ///
  /// In en, this message translates to:
  /// **'home, errands, calls'**
  String get labelsExample;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @completedTaskSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 task completed. Tap its check to reopen it.} other {{count} tasks completed. Tap a check to reopen one.}}'**
  String completedTaskSummary(int count);

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Doctor appointment'**
  String get taskTitleHint;

  /// No description provided for @individualDateChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 individual date change} other {{count} individual date changes}}'**
  String individualDateChanges(int count);

  /// No description provided for @movedOccurrenceDate.
  ///
  /// In en, this message translates to:
  /// **'Moved to {date}'**
  String movedOccurrenceDate(String date);

  /// No description provided for @reopenNamedTask.
  ///
  /// In en, this message translates to:
  /// **'Reopen {title}'**
  String reopenNamedTask(String title);

  /// No description provided for @completeNamedTask.
  ///
  /// In en, this message translates to:
  /// **'Complete {title}'**
  String completeNamedTask(String title);

  /// No description provided for @viewOnlyTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'View-only task'**
  String get viewOnlyTaskTitle;

  /// No description provided for @readOnlyList.
  ///
  /// In en, this message translates to:
  /// **'This project is read-only'**
  String get readOnlyList;

  /// Under «This project is read-only», in a shared project the person can only view: who to ask to make changes.
  ///
  /// In en, this message translates to:
  /// **'To make changes, ask the project’s owner.'**
  String get listEditingAccessHelp;

  /// No description provided for @loadTaskError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this task'**
  String get loadTaskError;

  /// No description provided for @deleteSeriesHelp.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and all its occurrences will be removed.'**
  String deleteSeriesHelp(String title);

  /// No description provided for @viewOnlyTask.
  ///
  /// In en, this message translates to:
  /// **'You can only view this task.'**
  String get viewOnlyTask;

  /// Banner on a task in a project the person can only view, when the task rings for them: its reminder chip still opens, for their own reminders only.
  ///
  /// In en, this message translates to:
  /// **'You can only view this task and choose your reminders.'**
  String get viewOnlyTaskReminders;

  /// Added after a task title, with a space, to the personal copy a sync keeps of an unsent edit that conflicted with the shared task. The same copy syncProblem names.
  ///
  /// In en, this message translates to:
  /// **'(offline copy)'**
  String get syncCopySuffix;

  /// No description provided for @stepUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this step. Please retry.'**
  String get stepUpdateError;

  /// No description provided for @diagnosticsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Local counts and timing from the last 1,000 events. No task titles, words, recordings or account identifiers are included. Nothing here is uploaded.'**
  String get diagnosticsPrivacy;

  /// No description provided for @diagnosticsPercentiles.
  ///
  /// In en, this message translates to:
  /// **'Median is the middle observation. P95 is the time that 95% of observations finish within. Failed requests are counted separately.'**
  String get diagnosticsPercentiles;

  /// No description provided for @diagnosticsMeasurementHelp.
  ///
  /// In en, this message translates to:
  /// **'Keeping a capture for later is not a failure. Counts can include several visits to the same draft; they are not a user conversion rate. Correction time covers open editing dialogs, including cancelled ones. Local save timing excludes cloud sync. Audio transcription excludes typed and on-device input.'**
  String get diagnosticsMeasurementHelp;

  /// No description provided for @diagnosticsObservations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 observation} other {{count} observations}}'**
  String diagnosticsObservations(int count);

  /// No description provided for @diagnosticsItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 item} other {{count} items}}'**
  String diagnosticsItems(int count);

  /// No description provided for @diagnosticsTiming.
  ///
  /// In en, this message translates to:
  /// **'Median {median} s · P95 {p95} s · {count, plural, one {1 timed observation} other {{count} timed observations}}'**
  String diagnosticsTiming(String median, String p95, int count);

  /// No description provided for @diagnosticsClearError.
  ///
  /// In en, this message translates to:
  /// **'Could not clear diagnostics. Try again.'**
  String get diagnosticsClearError;

  /// No description provided for @clearDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Clear local diagnostics'**
  String get clearDiagnostics;

  /// No description provided for @diagnosticsEvent.
  ///
  /// In en, this message translates to:
  /// **'{event, select, opened{Capture opened} ready{Capture ready to use} started{New durable captures} typedStarted{Typed input started} permissionDenied{Microphone permission denied} nativeStarted{On-device listening started} firstPartial{First on-device words} nativeListening{On-device listening duration} recordingStopped{Saved audio duration} transcription{Online audio transcription} extraction{Online task extraction} processing{Request and retained drafts} notePrepared{Local note prepared} noteTranscribed{Recorded note ready} failed{Failed requests} retried{Retried requests} edited{Draft changes} reviewOpened{Review opened} reviewTime{Time in review} correction{Correction dialog time} saved{Confirmed to local save} discarded{Explicitly discarded captures} resumed{Resumed captures} leftCapturePending{Capture kept for later} leftReviewPending{Review kept for later} recognizerFinish{Last words after Done} other{Other capture event}}'**
  String diagnosticsEvent(String event);

  /// No description provided for @taskflowPro.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow Pro'**
  String get taskflowPro;

  /// The Pro screen's list of what Pro gives, first line: what Pro adds to the free tier (unlimited dictations and file space). The app bar already says TaskFlow Pro. Only this line promises anything without limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited dictation and file space'**
  String get proBenefitDictation;

  /// The Pro screen's list of what Pro gives, second line: with Pro, a sentence typed in the capture sheet becomes tasks, as a dictation does (without Pro, typing opens the form).
  ///
  /// In en, this message translates to:
  /// **'Sentences you type become tasks'**
  String get proBenefitTyping;

  /// The Pro screen's list of what Pro gives, third line: reminders asked for in your own words («A tu manera»). Left out when the screen opens from that choice, whose heading already names it.
  ///
  /// In en, this message translates to:
  /// **'Ask for reminders in your own words'**
  String get proBenefitReminders;

  /// No description provided for @billingComplimentary.
  ///
  /// In en, this message translates to:
  /// **'Complimentary Pro access. All Pro features are included, with no payment or renewal.'**
  String get billingComplimentary;

  /// No description provided for @billingStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, active{Pro is active} inactive{No active Pro subscription} other{Subscription status unavailable}}'**
  String billingStatus(String status);

  /// No description provided for @billingUntil.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, renews{Renews on {date}} other{Access until {date}}}'**
  String billingUntil(String kind, String date);

  /// No description provided for @billingTestMode.
  ///
  /// In en, this message translates to:
  /// **'Test purchases only. No real payment will be taken. An active test subscription gives unlimited dictation and file space in this development build.'**
  String get billingTestMode;

  /// No description provided for @billingGuestHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in to link purchases to your TaskFlow account and recover Pro on your other devices.'**
  String get billingGuestHelp;

  /// No description provided for @billingSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to TaskFlow'**
  String get billingSignIn;

  /// No description provided for @billingWorking.
  ///
  /// In en, this message translates to:
  /// **'Updating subscription'**
  String get billingWorking;

  /// No description provided for @billingMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String billingMonthlyPrice(String price);

  /// No description provided for @billingRenewalHelp.
  ///
  /// In en, this message translates to:
  /// **'Automatically renews each month until cancelled. Review the final price and any trial terms before confirming.'**
  String get billingRenewalHelp;

  /// No description provided for @billingViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View subscription'**
  String get billingViewPlans;

  /// No description provided for @billingTestMonthly.
  ///
  /// In en, this message translates to:
  /// **'Test monthly purchase'**
  String get billingTestMonthly;

  /// No description provided for @billingRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get billingRestore;

  /// No description provided for @billingManage.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get billingManage;

  /// No description provided for @billingRestoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Already subscribed? Use the same store account, then restore purchases. Cancelling renewal keeps Pro available until your paid access ends.'**
  String get billingRestoreHelp;

  /// No description provided for @billingError.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, unsupportedPlatform{Subscriptions are available in the Android app.} configuration{Subscriptions are not available yet. Please try again later.} accountUnavailable{Could not connect to your TaskFlow account. Check your connection and open this screen again.} network{Could not check your subscription. Check your connection and open this screen again.} notAllowed{Purchases are restricted for this store account or device.} otherAccount{This purchase belongs to another account. Sign in to the original account to restore it.} store{The store didn’t answer. Open this screen again.} other{The store didn’t answer. Open this screen again.}}'**
  String billingError(String reason);

  /// No description provided for @billingResult.
  ///
  /// In en, this message translates to:
  /// **'{result, select, active{TaskFlow Pro is active.} restored{Your Pro subscription was restored.} noPurchases{No active Pro purchase was found for this account.} awaitingEntitlement{Purchase received. Pro will turn on in a few moments; if it doesn’t, tap Restore purchases.} updated{Subscription status updated.} pending{Payment is pending. Pro will activate after the store confirms payment.} busy{Please wait for the current operation to finish.} accountChanged{The account changed. Check the subscription on the purchasing account.} other{The request could not be completed. Please try again.}}'**
  String billingResult(String result);

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Sign-in's first screen, a text button under Continue with Google: shows the email and password form in place.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get continueWithEmail;

  /// Sign-in, above Continue with Google, while an invitation link opened before signing in waits: the invitation only works for the address it was sent to.
  ///
  /// In en, this message translates to:
  /// **'You have an invitation. Sign in with the email address it was sent to.'**
  String get invitationWaitingSignIn;

  /// No description provided for @linkGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Google account'**
  String get linkGoogleAccount;

  /// No description provided for @googleAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Google account linked'**
  String get googleAccountLinked;

  /// No description provided for @googleLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Confirm your TaskFlow password, then choose the Google account with the same email. Your tasks and subscription will stay in this account.'**
  String get googleLinkHelp;

  /// No description provided for @googleSignInSetupPending.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not available in this build yet. You can use email and password.'**
  String get googleSignInSetupPending;

  /// No description provided for @googleSignInError.
  ///
  /// In en, this message translates to:
  /// **'{code, select, google_not_configured{Google sign-in is not available yet. Use email and password for now.} google_link_required{This email already has a TaskFlow account. Sign in with your password, then choose Link Google account.} google_password_required{Enter your current TaskFlow password to link Google.} google_email_mismatch{Choose the Google account with the same email as your TaskFlow account.} google_already_linked{This Google account is already linked. Sign in to the original TaskFlow account.} google_account_changed{Your account changed during sign-in. Please try again.} google_invalid_token{Google could not verify your sign-in. Please try again.} other{Google sign-in could not finish. Check your connection and try again.}}'**
  String googleSignInError(String code);

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authRestoring.
  ///
  /// In en, this message translates to:
  /// **'Opening your space…'**
  String get authRestoring;

  /// No description provided for @authHaveRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'I already have a code'**
  String get authHaveRecoveryCode;

  /// No description provided for @useTestAccount.
  ///
  /// In en, this message translates to:
  /// **'Use test account'**
  String get useTestAccount;

  /// No description provided for @developmentOnly.
  ///
  /// In en, this message translates to:
  /// **'Development only'**
  String get developmentOnly;

  /// No description provided for @projectsAll.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get projectsAll;

  /// No description provided for @projectsPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal projects'**
  String get projectsPersonal;

  /// No description provided for @projectsShared.
  ///
  /// In en, this message translates to:
  /// **'Shared projects'**
  String get projectsShared;

  /// No description provided for @projectsFind.
  ///
  /// In en, this message translates to:
  /// **'Find a project'**
  String get projectsFind;

  /// No description provided for @projectsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage projects'**
  String get projectsManage;

  /// No description provided for @forMe.
  ///
  /// In en, this message translates to:
  /// **'For me'**
  String get forMe;

  /// No description provided for @forTeam.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get forTeam;

  /// No description provided for @responsibility.
  ///
  /// In en, this message translates to:
  /// **'Responsible'**
  String get responsibility;

  /// No description provided for @assignedToMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get assignedToMe;

  /// No description provided for @assignedToGroup.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get assignedToGroup;

  /// No description provided for @assignmentNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needs an assignee'**
  String get assignmentNeeded;

  /// No description provided for @assignmentChoose.
  ///
  /// In en, this message translates to:
  /// **'Who is responsible?'**
  String get assignmentChoose;

  /// No description provided for @assignmentGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'One shared task. A member completes it for everyone.'**
  String get assignmentGroupHelp;

  /// No description provided for @assignmentHeard.
  ///
  /// In en, this message translates to:
  /// **'You mentioned: {names}'**
  String assignmentHeard(Object names);

  /// No description provided for @audiencePersonal.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this.'**
  String get audiencePersonal;

  /// Under the assignee chip of a task in a shared project: who can see the task. The pair of «Only you can see this.».
  ///
  /// In en, this message translates to:
  /// **'All members can see it.'**
  String get audienceShared;

  /// Asked before a personal task moves into a shared project. {name} is the group, or the project when it has no group.
  ///
  /// In en, this message translates to:
  /// **'Share with {name}? Everyone there will see this task. It can’t be made private again.'**
  String shareTaskConfirm(String name);

  /// No description provided for @shareTask.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTask;

  /// No description provided for @sharedTaskStays.
  ///
  /// In en, this message translates to:
  /// **'Shared tasks stay in their project.'**
  String get sharedTaskStays;

  /// Asked before a personal note moves into a shared project. {name} is the group, or the project when it has no group. The pair of shareTaskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Share with {name}? Everyone there will see this note. It can’t be made private again.'**
  String shareNoteConfirm(String name);

  /// Shown when the project chip of a note in a shared project is tapped: it can't be moved out. The pair of «Shared tasks stay in their project.».
  ///
  /// In en, this message translates to:
  /// **'Shared notes stay in their project.'**
  String get sharedNoteStays;

  /// No description provided for @assignmentIsRight.
  ///
  /// In en, this message translates to:
  /// **'Is this right?'**
  String get assignmentIsRight;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @pinProject.
  ///
  /// In en, this message translates to:
  /// **'Pin project'**
  String get pinProject;

  /// No description provided for @unpinProject.
  ///
  /// In en, this message translates to:
  /// **'Unpin project'**
  String get unpinProject;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupHelp.
  ///
  /// In en, this message translates to:
  /// **'Invite people once and share several projects with them.'**
  String get groupHelp;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembers;

  /// No description provided for @groupAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get groupAdmin;

  /// No description provided for @groupProjects.
  ///
  /// In en, this message translates to:
  /// **'Group projects'**
  String get groupProjects;

  /// Help under the group invite dialog’s title, above the email field.
  ///
  /// In en, this message translates to:
  /// **'They’ll see every project in this group. We’ll email them an invitation.'**
  String get groupInviteHelp;

  /// No description provided for @groupLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeave;

  /// No description provided for @groupLeaveHelp.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to this group’s projects and files. Your tasks stay in the group for reassignment.'**
  String get groupLeaveHelp;

  /// No description provided for @groupTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get groupTransfer;

  /// No description provided for @groupTransferHelp.
  ///
  /// In en, this message translates to:
  /// **'The new owner controls this group and its projects. You will remain an administrator.'**
  String get groupTransferHelp;

  /// No description provided for @groupArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive group'**
  String get groupArchive;

  /// No description provided for @groupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore group'**
  String get groupRestore;

  /// No description provided for @groupArchivedForEveryone.
  ///
  /// In en, this message translates to:
  /// **'{name} archived for everyone — hidden from calendars, no reminders.'**
  String groupArchivedForEveryone(String name);

  /// No description provided for @groupDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'Only an empty group can be deleted. Archive a group to keep its projects and content.'**
  String get groupDeleteHelp;

  /// The group page’s delete row and the red button that confirms it.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get groupDeleteAction;

  /// Text of the confirmation before an empty group is deleted. {name} is the group’s name.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Its members will lose it. This can’t be undone.'**
  String groupDeleteConfirm(String name);

  /// Title of the confirmation before the owner gives a group to another member. {group} is the group’s name, {person} the member’s.
  ///
  /// In en, this message translates to:
  /// **'Transfer “{group}” to {person}?'**
  String groupTransferConfirm(String group, String person);

  /// The button that confirms giving the group to {person}, a member’s name.
  ///
  /// In en, this message translates to:
  /// **'Transfer to {person}'**
  String groupTransferAction(String person);

  /// No description provided for @groupActionError.
  ///
  /// In en, this message translates to:
  /// **'This change could not be saved. Check your connection and refresh; permissions may have changed.'**
  String get groupActionError;

  /// No description provided for @groupVoiceName.
  ///
  /// In en, this message translates to:
  /// **'Name for voice assignments'**
  String get groupVoiceName;

  /// No description provided for @groupVoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'An optional name others can use when assigning tasks by voice.'**
  String get groupVoiceHelp;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get enterName;

  /// No description provided for @groupRoleQuestion.
  ///
  /// In en, this message translates to:
  /// **'What can {name} do?'**
  String groupRoleQuestion(String name);

  /// No description provided for @groupInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get groupInvited;

  /// No description provided for @invitationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get invitationPending;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load. Check your connection.'**
  String get loadFailed;

  /// No description provided for @projectDestination.
  ///
  /// In en, this message translates to:
  /// **'Where does this project belong?'**
  String get projectDestination;

  /// No description provided for @projectNotifications.
  ///
  /// In en, this message translates to:
  /// **'Project updates'**
  String get projectNotifications;

  /// No description provided for @updatesAll.
  ///
  /// In en, this message translates to:
  /// **'All changes'**
  String get updatesAll;

  /// A shared project’s update choice: only updates about tasks for this person. Matches the app’s “For me” wording.
  ///
  /// In en, this message translates to:
  /// **'Only what’s for me'**
  String get updatesAssigned;

  /// No description provided for @updatesMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted — no updates or reminders'**
  String get updatesMuted;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'You’re up to date.'**
  String get activityEmpty;

  /// No description provided for @activityHelp.
  ///
  /// In en, this message translates to:
  /// **'Assignments and updates from your shared projects appear here.'**
  String get activityHelp;

  /// No description provided for @activityMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get activityMarkRead;

  /// No description provided for @activityCreated.
  ///
  /// In en, this message translates to:
  /// **'Created a task'**
  String get activityCreated;

  /// A task’s history (task details, Activity section): the entry for an edit to the task other than a move. The person’s name and the date show under it.
  ///
  /// In en, this message translates to:
  /// **'Updated the task'**
  String get activityUpdated;

  /// A task’s history (task details, Activity section): the entry for an edit that changed only the task’s day (its date or due date). The person’s name and the date show under it.
  ///
  /// In en, this message translates to:
  /// **'Moved the task'**
  String get activityMoved;

  /// No description provided for @activityAssigned.
  ///
  /// In en, this message translates to:
  /// **'Changed responsibility'**
  String get activityAssigned;

  /// No description provided for @activityCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed a task'**
  String get activityCompleted;

  /// No description provided for @activityReopened.
  ///
  /// In en, this message translates to:
  /// **'Reopened a task'**
  String get activityReopened;

  /// No description provided for @activityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted a task'**
  String get activityDeleted;

  /// A task’s history (task details, Activity section): the entry for someone taking the task’s assignee off, so it has nobody. The person’s name and the date show under it.
  ///
  /// In en, this message translates to:
  /// **'Removed the assignee'**
  String get activityUnassigned;

  /// No description provided for @activitySystem.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow'**
  String get activitySystem;

  /// Title of the screen that lists what others did in every shared project, and the tooltip of the header button (feed icon) that opens it.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get groupActivity;

  /// Spoken by TalkBack before an unread activity row.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get activityUnread;

  /// Activity: read by TalkBack, and the label of the thin progress bar, on an entry whose task isn’t on the phone yet, while the app fetches it. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Finding the task…'**
  String get activityFindingTask;

  /// One activity row: who did what to which task. action is an internal code (moved: an edit that changed only the task’s day); actor is a person’s name; title is the task title.
  ///
  /// In en, this message translates to:
  /// **'{action, select, created{{actor} created: {title}} assigned{{actor} changed who’s responsible for: {title}} unassigned{{actor} removed the assignee of: {title}} completed{{actor} completed: {title}} reopened{{actor} reopened: {title}} moved{{actor} moved: {title}} deleted{{actor} deleted: {title}} shared{{actor} shared: {title}} other{{actor} updated: {title}}}'**
  String activityEntry(String action, String actor, String title);

  /// An Updates row when someone made the reader responsible for a task. actor is that person’s name; title is the task title.
  ///
  /// In en, this message translates to:
  /// **'{actor} assigned you: {title}'**
  String activityAssignedYou(String actor, String title);

  /// An Updates row when someone made another person responsible for a task; the previous assignee reads it too. actor is who did it; name is the new assignee’s name; title is the task title.
  ///
  /// In en, this message translates to:
  /// **'{actor} assigned {name}: {title}'**
  String activityAssignedTo(String actor, String name, String title);

  /// Atop the capture sheet without Pro, when it was opened to speak (the home-screen widget, the voice shortcut): it types instead.
  ///
  /// In en, this message translates to:
  /// **'Speaking a task is part of TaskFlow Pro. You can type it here.'**
  String get captureSpeakingIsPro;

  /// No description provided for @voiceProAction.
  ///
  /// In en, this message translates to:
  /// **'Explore Pro'**
  String get voiceProAction;

  /// No description provided for @projectsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No matching projects'**
  String get projectsNoneFound;

  /// No description provided for @groupRename.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get groupRename;

  /// No description provided for @groupRemoveHelp.
  ///
  /// In en, this message translates to:
  /// **'Removing this member ends their access to every project in this group. Their tasks stay and will need reassignment.'**
  String get groupRemoveHelp;

  /// No description provided for @projectsPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned projects'**
  String get projectsPinned;

  /// No description provided for @invitationReview.
  ///
  /// In en, this message translates to:
  /// **'Review invitation'**
  String get invitationReview;

  /// First line of the invitation review screen when the server says who sent it.
  ///
  /// In en, this message translates to:
  /// **'{sender} invited you to “{name}”'**
  String invitationFrom(String sender, String name);

  /// No description provided for @invitationReviewHelp.
  ///
  /// In en, this message translates to:
  /// **'You’ll see its tasks, notes and files.'**
  String get invitationReviewHelp;

  /// No description provided for @invitationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This invitation is unavailable for this account. Check that you signed in with the email address that received it, or ask for a new invitation.'**
  String get invitationUnavailable;

  /// On the invitation screen, under the help line, only when the invitation gives view-only access to the project or group
  ///
  /// In en, this message translates to:
  /// **'You’ll be able to see it, not change it.'**
  String get invitationViewerAccess;

  /// On the invitation screen, under the help line, only when the invitation makes the person an administrator of the group
  ///
  /// In en, this message translates to:
  /// **'You’ll be able to manage the group.'**
  String get invitationAdminAccess;

  /// General button that closes the current screen. On the invitation screen, the only button when the invitation is no longer available; it also forgets the invitation link
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @stagingInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'This private test build is for invited testers. Ask the TaskFlow owner for an invitation to this email address.'**
  String get stagingInviteOnly;

  /// Under a spoken capture's result, for an account without Pro, only when 3 or fewer free dictations are left this month; and as the subtitle of the TaskFlow Pro row in Settings, for an account without Pro, at any count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No free dictations left this month} =1{1 free dictation left this month} other{{count} free dictations left this month}}'**
  String freeVoiceLeft(int count);

  /// Atop the capture sheet for an account without Pro once this month's free dictations are used up: it types instead, with the field already focused, and also in Unfinished captures. {date} is the local short date they come back.
  ///
  /// In en, this message translates to:
  /// **'No free dictations until {date}.'**
  String freeVoiceUsedUp(String date);

  /// For a capture that is only a recording, refused because this month's free dictations are used up: in the capture sheet and in Unfinished captures. {date} is the local short date they come back.
  ///
  /// In en, this message translates to:
  /// **'Your recording is kept. It can be understood from {date}, or now with Pro.'**
  String freeVoiceUsedUpRecording(String date);

  /// Closes the capture sheet when only a recording is kept and free dictations are used up
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get captureClose;

  /// On the Pro screen, for an account without Pro. {date} is the local short date this month's free dictations come back.
  ///
  /// In en, this message translates to:
  /// **'Free dictations: {left} of {limit} left this month. More on {date}.'**
  String freeVoiceStatus(int left, int limit, String date);

  /// Replaces Add a task, with a + icon, for an account without Pro once the mic isn't available (this month's free dictations are used up, or the server sends no count). It opens the task form, with no limit. Also the form's title while it creates a task.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// In the task form for a new task, the third day chip after Today and Tomorrow: opens the date sheet. Short, so the three fit on one row.
  ///
  /// In en, this message translates to:
  /// **'Pick a day'**
  String get pickDay;

  /// Tooltip of the small ✕ on a new task's time chip in the task form: the task keeps its day, with no time.
  ///
  /// In en, this message translates to:
  /// **'Remove time'**
  String get removeTime;

  /// On a task's or note's details page in a shared project, under the project and who it's for. {name} is the display name of the account that created it; hidden when that account has left or been deleted.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String createdBy(String name);

  /// On a task's or note's details page in a shared project, in place of “Created by {name}” when the signed-in account created it; the same screen calls that account “Me” in who it's for.
  ///
  /// In en, this message translates to:
  /// **'Created by you'**
  String get createdByYou;

  /// Title of a sheet shown at most once a month: the first time an account without Pro taps New task with this month's free dictations used up. {limit} is the account's monthly free dictations (10).
  ///
  /// In en, this message translates to:
  /// **'{limit, plural, =1{You’ve used your free dictation for this month} other{You’ve used your {limit} free dictations for this month}}'**
  String freeVoiceNoticeTitle(int limit);

  /// Under that title. {limit} is how many free dictations come back, and {date} the local short date they do.
  ///
  /// In en, this message translates to:
  /// **'You can keep creating tasks by hand, with no limit. {limit, plural, =1{On {date} you’ll get 1 more dictation.} other{On {date} you’ll get {limit} more dictations.}}'**
  String freeVoiceNoticeBody(int limit, String date);

  /// That sheet's main button: opens the task form. Its other button is voiceProAction.
  ///
  /// In en, this message translates to:
  /// **'Create a task'**
  String get freeVoiceNoticeCreate;

  /// Atop a task's attachments, for an account without Pro, only once its file space is 80% used or more; and on the Pro screen, for an account without Pro. Whole megabytes. A no-break space keeps {used} with the word after it, and {limit} with MB.
  ///
  /// In en, this message translates to:
  /// **'Files: {used} of {limit} MB used'**
  String storageUsage(int used, int limit);

  /// Under an attachment the server refused because the user's own free file space is full. The card's buttons below it offer Pro and the list of tasks with files. {limit} is the free cap in whole megabytes.
  ///
  /// In en, this message translates to:
  /// **'Your file space is full ({limit} MB).'**
  String storageFull(int limit);

  /// Under an attachment the server refused because the file space of the shared project's owner is full.
  ///
  /// In en, this message translates to:
  /// **'This project’s file space is full. Its owner can remove files to make room.'**
  String get storageFullShared;

  /// Button beside Explore Pro, only while the user's own free file space is full: under a file refused for it, and on the Pro screen under the usage line. Opens the list of tasks with files.
  ///
  /// In en, this message translates to:
  /// **'Show tasks with files'**
  String get storageSeeTasks;

  /// Title of the screen listing the tasks and notes whose files use this account's file space, largest first.
  ///
  /// In en, this message translates to:
  /// **'Tasks with files'**
  String get tasksWithFiles;

  /// One line above the rows of the Tasks with files screen.
  ///
  /// In en, this message translates to:
  /// **'Open a task to remove the files you no longer need.'**
  String get tasksWithFilesHelp;

  /// Under a task's title on the Tasks with files screen: how many files it holds and their total size. {size} is already formatted in the app's locale, to one decimal (12.4).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}} · {size} MB'**
  String tasksWithFilesRow(int count, String size);

  /// The Tasks with files screen when no task holds files in this account's space.
  ///
  /// In en, this message translates to:
  /// **'No tasks have files.'**
  String get tasksWithFilesEmpty;

  /// Spoken label of the pin icon before a pinned project's name in Projects.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get projectPinned;

  /// Subtitle of a project shared directly with people (not through a group) in Projects. {role} is the user's role, such as Editor; for the project's owner, its count of open tasks and notes, such as «5 tasks and notes».
  ///
  /// In en, this message translates to:
  /// **'Shared · {role}'**
  String projectSharedRole(String role);

  /// Under 'Where does this project belong?' in the new-project dialog, once a group is chosen. {group} is the group's name.
  ///
  /// In en, this message translates to:
  /// **'Everyone in {group} will see it.'**
  String projectGroupSees(String group);

  /// The last row of the Account screen, in the destructive colour, and the title of the page it opens.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Heading of the delete-account page.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountQuestion;

  /// First line of the delete-account page, under its heading.
  ///
  /// In en, this message translates to:
  /// **'This deletes your TaskFlow account and your tasks, notes and files on all your devices. It can’t be undone.'**
  String get deleteAccountIntro;

  /// Introduces the list of counts (tasks, notes, files, projects, groups) that deleting the account removes.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted:'**
  String get deleteAccountWhatGoes;

  /// A line in the list under 'What will be deleted:'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String deleteAccountTasks(int count);

  /// A line in the list under 'What will be deleted:'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String deleteAccountNotes(int count);

  /// A line in the list under 'What will be deleted:'. Attached files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String deleteAccountFiles(int count);

  /// A line in the list under 'What will be deleted:'. The person's own unshared projects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 project} other{{count} projects}}'**
  String deleteAccountProjects(int count);

  /// A line in the list under 'What will be deleted:'. Groups with no one else in them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group} other{{count} groups}}'**
  String deleteAccountGroups(int count);

  /// A bullet under 'What stays for the others:' on the delete-account page, when tasks the person added to other people's shared projects stay after the account is deleted. The files they added there have their own bullet, deleteAccountKeptFiles. No final full stop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task you added to shared projects, without your name} other{{count} tasks you added to shared projects, without your name}}'**
  String deleteAccountKeptShared(int count);

  /// A bullet under 'What stays for the others:' on the delete-account page, after deleteAccountKeptShared, when files the person added in shared projects (on their own tasks or on other people's) stay after the account is deleted. Same wording as deleteAccountKeptShared, with files. No final full stop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file you added to shared projects, without your name} other{{count} files you added to shared projects, without your name}}'**
  String deleteAccountKeptFiles(int count);

  /// A bullet under 'What stays for the others:' on the delete-account page, one per project or group the person owns that passes to someone else when the account is deleted; a group's projects go with it. Also a line of the banner after the page reloaded, when this handover is new or changed. {kind} is 'group' or 'project' and is never translated. {name} is the project or group; {person} is who receives it (a name or an email). No final full stop.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, group{The group “{name}” and its projects will go to {person}} other{The project “{name}” will go to {person}}}'**
  String deleteAccountHandover(String kind, String name, String person);

  /// Heading of the second list on the delete-account page: what stays for other people. Shown only when that list has a line.
  ///
  /// In en, this message translates to:
  /// **'What stays for the others:'**
  String get deleteAccountWhatStays;

  /// On the delete-account page when the server says the account has Pro or billing could not be checked, except for complimentary Pro. True for anyone who reads it.
  ///
  /// In en, this message translates to:
  /// **'If you pay for TaskFlow Pro on Google Play, deleting your account doesn’t cancel the subscription.'**
  String get deleteAccountSubscription;

  /// Link on the delete-account page that saves a TaskFlow export file at once, through Android's save screen. Shown only when the person has tasks or notes.
  ///
  /// In en, this message translates to:
  /// **'Save a copy of your tasks first'**
  String get deleteAccountSaveCopy;

  /// Replaces the save-a-copy link on the delete-account page once the file was saved.
  ///
  /// In en, this message translates to:
  /// **'Copy saved'**
  String get deleteAccountCopySaved;

  /// Under the save-a-copy link, or under Copy saved, when the person has attached files: the export keeps only the names of the files.
  ///
  /// In en, this message translates to:
  /// **'The copy doesn’t include files.'**
  String get deleteAccountCopyNoFiles;

  /// Above the password field that confirms deleting the account.
  ///
  /// In en, this message translates to:
  /// **'To confirm, enter your password.'**
  String get deleteAccountPasswordHelp;

  /// Above the Confirm with Google button, for an account that signs in only with Google. {email} is the TaskFlow account's email, which for these accounts is the Google address. Says the Google account itself isn't deleted.
  ///
  /// In en, this message translates to:
  /// **'To confirm, choose {email} when Google asks. Your Google account isn’t deleted.'**
  String deleteAccountGoogleHelp(String email);

  /// Above the Confirm with Google button, under the password field, for an account with a password and Google linked: confirming with Google instead of the password. {email} is the TaskFlow account's email. Says the Google account itself isn't deleted.
  ///
  /// In en, this message translates to:
  /// **'Or confirm with Google and choose {email}. Your Google account isn’t deleted.'**
  String deleteAccountGoogleInstead(String email);

  /// Button that opens Google sign-in to confirm deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Confirm with Google'**
  String get deleteAccountConfirmGoogle;

  /// Shown in place of the Confirm with Google button once Google sign-in succeeded.
  ///
  /// In en, this message translates to:
  /// **'Confirmed with Google'**
  String get deleteAccountGoogleConfirmed;

  /// The destructive button at the bottom of the delete-account page.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButton;

  /// Inside Delete my account, after a spinner, while the request runs (up to a minute). Ends with an ellipsis.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deleteAccountDeleting;

  /// Under the password field on the delete-account page after a wrong password. Says how to recover a forgotten one: sign out, then Forgot password? on sign-in. The quoted words must match forgotPassword, and the verb the signOut button.
  ///
  /// In en, this message translates to:
  /// **'That password isn’t right. If you don’t remember it, sign out and tap “Forgot password?”'**
  String get deleteAccountWrongPassword;

  /// Under the password field on the delete-account page after a wrong password, for an account with Google linked: the Confirm with Google button below confirms instead. The quoted words must match deleteAccountConfirmGoogle.
  ///
  /// In en, this message translates to:
  /// **'That password isn’t right. If you don’t remember it, tap “Confirm with Google”.'**
  String get deleteAccountWrongPasswordGoogle;

  /// On the delete-account page, when the Google account chosen to confirm isn't the one linked to this TaskFlow account. {email} is the TaskFlow account's email, which for these accounts is the Google address.
  ///
  /// In en, this message translates to:
  /// **'Choose {email}, the Google account you use for TaskFlow.'**
  String deleteAccountOtherGoogle(String email);

  /// Under Delete my account when the phone is offline.
  ///
  /// In en, this message translates to:
  /// **'You need a connection to delete your account. Nothing was deleted.'**
  String get deleteAccountOffline;

  /// Under Delete my account when the request timed out; it may or may not have arrived, so it doesn't say nothing was deleted.
  ///
  /// In en, this message translates to:
  /// **'There was no answer. Check your connection and try again.'**
  String get deleteAccountNoAnswer;

  /// Under Delete my account when the server refuses more attempts for now.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again later.'**
  String get deleteAccountThrottled;

  /// When the server refuses more attempts for {minutes} minutes, rounded up, at least 1: under Delete my account, and on sign-in, Create your account and the email-confirmation screen. After five wrong passwords it is 15 minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many tries. Wait a minute and try again.} other{Too many tries. Wait {minutes} minutes and try again.}}'**
  String tooManyTriesWait(int minutes);

  /// Above Delete my account when the server refused because what the page showed changed meanwhile (for example, the person who would receive a project left it). The page has just reloaded; nothing was deleted. Used when no handover is new or changed.
  ///
  /// In en, this message translates to:
  /// **'Something has changed since you opened this screen. Check what will happen and confirm again.'**
  String get deleteAccountPlanChanged;

  /// First line of the banner above Delete my account after the page reloaded because a handover is new or changed; the changed handover lines follow, then deleteAccountChangedCheck.
  ///
  /// In en, this message translates to:
  /// **'Something has changed since you opened this screen:'**
  String get deleteAccountChangedIntro;

  /// Last line of that banner.
  ///
  /// In en, this message translates to:
  /// **'Check it and confirm again.'**
  String get deleteAccountChangedCheck;

  /// On the delete-account page when the server needs the password or Google confirmation again.
  ///
  /// In en, this message translates to:
  /// **'Confirm it’s you again.'**
  String get deleteAccountConfirmAgain;

  /// Under Delete my account for any other failure.
  ///
  /// In en, this message translates to:
  /// **'Your account couldn’t be deleted. Try again later.'**
  String get deleteAccountFailed;

  /// Brief message when nothing on the phone could open a web page: the Privacy Policy, the Terms and Conditions, or Google Play’s subscriptions page.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the page.'**
  String get webPageOpenError;

  /// On the sign-in screen, right after the account was deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// A dictation's result: the card of a project the confirming tap creates, and the row for it in a task's project sheet (the chip uses commandNewProjectChip). {name} is the project's name as said.
  ///
  /// In en, this message translates to:
  /// **'New project: {name}'**
  String commandNewProject(String name);

  /// A dictation's result: the project chip of a task that goes into a project the confirming tap creates, name first so it shows at large text. {name} is the project's name as said, or as corrected.
  ///
  /// In en, this message translates to:
  /// **'{name} (new)'**
  String commandNewProjectChip(String name);

  /// The button of the dialog that corrects the name of a project a dictation creates, opened from the task's project sheet. Nothing is created until the result's confirming tap.
  ///
  /// In en, this message translates to:
  /// **'Use this name'**
  String get commandUseName;

  /// TalkBack name of the pencil on the project sheet's row for a project a dictation creates; a tap on the row opens the dialog that corrects that project's name. Nothing is created until the result's confirming tap.
  ///
  /// In en, this message translates to:
  /// **'Change the name'**
  String get commandRenameProject;

  /// A dictation's result, when the project the person asked to create already exists: nothing is created. {name} is that project's real name.
  ///
  /// In en, this message translates to:
  /// **'You already have “{name}”'**
  String commandExistingProject(String name);

  /// Under commandExistingProject, when tasks in the same dictation name that project. {count} is how many of the dictation's tasks go there.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The task goes there.} other{The tasks go there.}}'**
  String commandExistingProjectTasks(int count);

  /// A dictation's result, for a project the person asked to create that matches several projects, or one with a different name. Chips follow: create it, or pick an existing project. {name} is the name as said.
  ///
  /// In en, this message translates to:
  /// **'Create the project “{name}”?'**
  String commandCreateProjectQuestion(String name);

  /// First chip under commandCreateProjectQuestion and commandWhichProject: creates that project on the confirming tap. {name} is the name as said.
  ///
  /// In en, this message translates to:
  /// **'Create “{name}”'**
  String commandCreateNamed(String name);

  /// A dictation's task named a project that doesn't exist. Chips follow: commandCreateNamed, up to three projects with a similar name, commandOtherProject and No project.
  ///
  /// In en, this message translates to:
  /// **'Which project should it go in?'**
  String get commandWhichProject;

  /// Chip after the similar projects under commandWhichProject or commandCreateProjectQuestion: opens the list of the person's projects, where a pick answers the question. Shown only when they have other projects.
  ///
  /// In en, this message translates to:
  /// **'Another project…'**
  String get commandOtherProject;

  /// A dictation's search, change, deletion or completion named a project that matches two or more of the person's projects. One chip per project follows; a tap works the command out in that project. Not for placing a new task (that is commandWhichProject).
  ///
  /// In en, this message translates to:
  /// **'Which project?'**
  String get commandWhichProjectOfTasks;

  /// The confirming button of a dictation's result that only creates projects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Create project} other{Create {count} projects}}'**
  String commandCreateProjects(int count);

  /// The confirming button of a dictation's result that adds tasks and changes tasks, and deletes none.
  ///
  /// In en, this message translates to:
  /// **'Add and change'**
  String get commandAddAndChange;

  /// The confirming button of a dictation's result that adds tasks and deletes tasks, and changes none.
  ///
  /// In en, this message translates to:
  /// **'Add and delete'**
  String get commandAddAndDelete;

  /// The confirming button of a dictation's result that changes tasks and deletes tasks, and adds none.
  ///
  /// In en, this message translates to:
  /// **'Change and delete'**
  String get commandChangeAndDelete;

  /// The confirming button of a dictation's result that adds, changes and deletes tasks.
  ///
  /// In en, this message translates to:
  /// **'Add, change and delete'**
  String get commandAddChangeAndDelete;

  /// Tooltip and screen-reader label of the ✕ on a deletion's card in a dictation's result: the task is kept. {title} is the task's title, or the words said for it.
  ///
  /// In en, this message translates to:
  /// **'Don’t delete {title}'**
  String commandDontDelete(String title);

  /// Tooltip and screen-reader label of the ✕ on a change's card in a dictation's result: the task stays as it is. {title} is the task's title, or the words said for it.
  ///
  /// In en, this message translates to:
  /// **'Don’t change {title}'**
  String commandDontChange(String title);

  /// Tooltip and screen-reader label of the ✕ on a change's card in a dictation's result while it asks which of several tasks to change (“Which one do you want to change?”): none of them is changed.
  ///
  /// In en, this message translates to:
  /// **'Don’t change any'**
  String get commandDontChangeAny;

  /// Tooltip and screen-reader label of the ✕ on a deletion's card in a dictation's result while it asks which of several tasks to delete (“Which one do you want to delete?”): none of them is deleted.
  ///
  /// In en, this message translates to:
  /// **'Don’t delete any'**
  String get commandDontDeleteAny;

  /// Tooltip and screen-reader label of the ✕ on a new project's card in a dictation's result: the project isn't created. {name} is the project's name.
  ///
  /// In en, this message translates to:
  /// **'Don’t create {name}'**
  String commandDontCreate(String name);

  /// Message, with Undo, after the ✕ on a deletion's card in a dictation's result: the tasks are kept. {count} is how many tasks the card would have deleted: a set's ticked tasks, or 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Won’t be deleted} other{Won’t be deleted}}'**
  String commandWontDelete(int count);

  /// Message, with Undo, after the ✕ on a change's card in a dictation's result: the tasks stay as they are. {count} is how many tasks the card would have changed: a set's ticked tasks, or 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Won’t be changed} other{Won’t be changed}}'**
  String commandWontChange(int count);

  /// Message, with Undo, after the ✕ on a new project's card in a dictation's result: the project isn't created.
  ///
  /// In en, this message translates to:
  /// **'Won’t be created'**
  String get commandWontCreate;

  /// Heading of a dictation's search results. {words} are the words searched for.
  ///
  /// In en, this message translates to:
  /// **'Tasks with “{words}”'**
  String commandFindWords(String words);

  /// Heading of a dictation's search results for all of a project's tasks. {name} is the project.
  ///
  /// In en, this message translates to:
  /// **'Tasks in “{name}”'**
  String commandFindProject(String name);

  /// Heading of a dictation's search results for the tasks assigned to someone. {name} is that person.
  ///
  /// In en, this message translates to:
  /// **'Tasks for {name}'**
  String commandFindPerson(String name);

  /// Heading of a dictation's search results for the person's own tasks.
  ///
  /// In en, this message translates to:
  /// **'Your tasks'**
  String get commandFindMine;

  /// Heading of a dictation's search results for a project's tasks assigned to someone. {project} is the project; {name} is that person.
  ///
  /// In en, this message translates to:
  /// **'Tasks in “{project}” for {name}'**
  String commandFindProjectPerson(String project, String name);

  /// Heading of a dictation's search results for the person's own tasks in a project. {project} is the project.
  ///
  /// In en, this message translates to:
  /// **'Your tasks in “{project}”'**
  String commandFindProjectMine(String project);

  /// Under the heading of a dictation's search results: the period searched, longer than one day. {from} and {to} are its first and last days, weekday first (“Mon, Oct 19”).
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String commandFindPeriod(String from, String to);

  /// Under the heading of a dictation's search results, when it searched only tasks not yet done. Matches agendaCounts.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get commandFindOpen;

  /// Under the heading of a dictation's search results, when it searched only completed tasks. Matches agendaCounts.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get commandFindDone;

  /// On a completed task in a dictation's search results.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get commandCompleted;

  /// A dictation's search found nothing. {words} are the words searched for.
  ///
  /// In en, this message translates to:
  /// **'There’s no task with “{words}”'**
  String commandFindNone(String words);

  /// A dictation's search without words (a project's, a person's tasks) found nothing.
  ///
  /// In en, this message translates to:
  /// **'There are no tasks'**
  String get commandFindNoneAtAll;

  /// Under a dictation's search results, when more tasks match than are shown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{And 1 more} other{And {count} more}}'**
  String commandMore(int count);

  /// Button under a dictation's list of tasks to choose from, when more tasks match than are shown: shows the rest in the list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 more} other{Show {count} more}}'**
  String commandShowMore(int count);

  /// Under a dictation's search results in a project: opens that project's page. {name} is the project.
  ///
  /// In en, this message translates to:
  /// **'Open “{name}”'**
  String commandOpenProject(String name);

  /// A dictation named a project to search or change tasks in, and none matched: nothing is searched. {name} is the name as said.
  ///
  /// In en, this message translates to:
  /// **'Can’t find the project “{name}”'**
  String commandProjectNotFound(String name);

  /// A dictation's search named a person, and nobody matched: nothing is searched. {name} is the name as said.
  ///
  /// In en, this message translates to:
  /// **'Can’t find {name}'**
  String commandPersonNotFound(String name);

  /// A dictation asked to change or delete a task, and no task on the phone matched. {words} are the words looked for.
  ///
  /// In en, this message translates to:
  /// **'Can’t find a task with “{words}”'**
  String commandTaskNotFound(String words);

  /// As commandTaskNotFound, when the task was described only by its day or project.
  ///
  /// In en, this message translates to:
  /// **'Can’t find that task'**
  String get commandTaskNotFoundPlain;

  /// A dictation asked to change or delete a task, and the only tasks that match are in projects the person can only view, so it can't be changed. {title} is the first such task's title.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is in a project you can only view.'**
  String commandViewOnly(String title);

  /// A dictation asked to change a task and several match: a short list to tap one follows.
  ///
  /// In en, this message translates to:
  /// **'Which one do you want to change?'**
  String get commandWhichToChange;

  /// A dictation asked to delete a task and several match: a short list to tap one follows.
  ///
  /// In en, this message translates to:
  /// **'Which one do you want to delete?'**
  String get commandWhichToDelete;

  /// A dictation's result, in a destructive style: the task the confirming tap deletes. {title} is the task's title.
  ///
  /// In en, this message translates to:
  /// **'Will be deleted: {title}'**
  String commandWillDelete(String title);

  /// As commandWillDelete, for a task with a day or a repeat. {date} is its day (Tomorrow, Wed, Oct 21) or its repeat (Weekly).
  ///
  /// In en, this message translates to:
  /// **'Will be deleted: {title} ({date})'**
  String commandWillDeleteOn(String title, String date);

  /// On a dictation's change or deletion card after one of several matching tasks was tapped: shows the list again.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get commandChooseAnother;

  /// A dictation asked to change a task, and the task already is as asked.
  ///
  /// In en, this message translates to:
  /// **'It’s already like that.'**
  String get commandNothingToChange;

  /// A dictation set a time on a task with no day: Today, Tomorrow and Pick a day follow. {time} is the time said, as the app shows times; {hour} is its hour as shown, for the article (Spanish and Catalan say a la 1:00).
  ///
  /// In en, this message translates to:
  /// **'{hour, plural, other{Which day, at {time}?}}'**
  String commandWhichDay(int hour, String time);

  /// A dictation named someone for a task, who can't be its assignee because they aren't in its existing shared project (a new project uses commandMemberNotInNew). The task is left as it is. {name} is the name as said; {project} the project.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t in “{project}”'**
  String commandMemberNotIn(String name, String project);

  /// A dictation named someone for a task going into a project the confirming tap creates, which has nobody yet. The task stays the account's own; the next step is the project page's Share button. {name} is the name as said; {project} the new project.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t in “{project}” yet. Afterwards, share the project with {name}.'**
  String commandMemberNotInNew(String name, String project);

  /// A dictation named someone for a task that isn't in a shared project: the assignee stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Only tasks in shared projects can be assigned.'**
  String get commandAssignNeedsShared;

  /// A dictation named someone for a task, and two or more people match: under it, one chip per person with that name, to tap the one meant. {name} is the name as said.
  ///
  /// In en, this message translates to:
  /// **'More than one person is called {name}.'**
  String commandAmbiguousMember(String name);

  /// Brief message after a dictation's changes were applied, with Undo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task changed} other{{count} tasks changed}}'**
  String commandTasksChanged(int count);

  /// Brief message after a dictation's deletions were applied, with Undo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task deleted} other{{count} tasks deleted}}'**
  String commandTasksDeleted(int count);

  /// Brief message after a dictation deleted one task, with Undo. {title} is the task’s title, as a completion names it (notificationCompleted). Several deleted tasks use commandTasksDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {title}'**
  String commandDeletedTitle(String title);

  /// Brief message after a dictation's new projects were created, with Undo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Project created} other{{count} projects created}}'**
  String commandProjectsCreated(int count);

  /// What TalkBack reads for one line of a dictation's change card, shown as before → after. {label} names the field (Date and time, Deadline…).
  ///
  /// In en, this message translates to:
  /// **'{label}: from {before} to {after}'**
  String commandChangeSemantics(String label, String before, String after);

  /// One line of a dictation's change card, as shown, for the priority and the deadline: the field, then its value before and after the change. {label} is the field's name (Priority, Deadline); {before} and {after} are its values (Medium, High; a day).
  ///
  /// In en, this message translates to:
  /// **'{label}: {before} → {after}'**
  String commandChangeLine(String label, String before, String after);

  /// A dictation's change card, the deadline line when the new deadline is a chip that follows this text: the field, then its value before the change and the arrow. {label} is the field's name (Deadline); {before} is its value before (a day).
  ///
  /// In en, this message translates to:
  /// **'{label}: {before} →'**
  String commandChangeLineFrom(String label, String before);

  /// On a dictation's change card: text the confirming tap adds at the end of the task's notes. {text} is that text.
  ///
  /// In en, this message translates to:
  /// **'Added to the notes: {text}'**
  String commandNotesAdd(String text);

  /// What TalkBack calls the assignee line of a dictation's change card.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get commandAssignee;

  /// The confirming button of a dictation's result whose only command marks one task as done (“I've already done…”). After the tap, commandTasksCompleted shows with Undo.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get commandMarkDone;

  /// A dictation asked to mark a task as done and several match: a short list to tap one follows.
  ///
  /// In en, this message translates to:
  /// **'Which one do you want to mark as done?'**
  String get commandWhichToComplete;

  /// Tooltip and screen-reader label of the ✕ on a card that marks a task as done in a dictation's result: the task stays to do. {title} is the task's title.
  ///
  /// In en, this message translates to:
  /// **'Don’t complete {title}'**
  String commandDontComplete(String title);

  /// Tooltip and screen-reader label of the ✕ on a card that marks tasks as done, while it asks which one (commandWhichToComplete) or lists a set of them: none is marked done.
  ///
  /// In en, this message translates to:
  /// **'Don’t complete any'**
  String get commandDontCompleteAny;

  /// Message, with Undo, after the ✕ on a card that marks tasks as done in a dictation's result: nothing is marked. {count} is how many tasks the card would have marked done: a set's ticked tasks, or 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Won’t be completed} other{Won’t be completed}}'**
  String commandWontComplete(int count);

  /// Brief message after a dictation marked two or more tasks as done, with Undo. For one task, notificationCompleted names it instead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task completed} other{{count} tasks completed}}'**
  String commandTasksCompleted(int count);

  /// Brief message after a dictation moved several tasks to another day or time, with Undo. One task moved by a change of its own says movedOccurrenceDate instead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task moved} other{{count} tasks moved}}'**
  String commandTasksMoved(int count);

  /// Brief message after a dictation moved a set of tasks, with Undo, when every task moved landed on the same day. {count} is how many tasks moved; {date} is that day, weekday first (“Thu, Oct 22”). When they landed on several days, commandTasksMoved says it instead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task moved to {date}} other{{count} tasks moved to {date}}}'**
  String commandTasksMovedTo(int count, String date);

  /// Brief message after a dictation assigned a set of tasks to someone, and changed nothing else, with Undo. {count} is how many tasks were assigned; {name} is that person, as the card's heading (commandBulkAssignTo) names them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task assigned to {name}} other{{count} tasks assigned to {name}}}'**
  String commandTasksAssignedTo(int count, String name);

  /// Heading of a dictation's card that moves a set of tasks to one day (“move all of yesterday's tasks to tomorrow”); each keeps its time. {count} is how many are still ticked, and changes as the person unticks them. {when} is today, tomorrow or other. {day} is, for today and tomorrow, the weekday and the day of the month (“Thu 22”); otherwise the day weekday first, as the app shows days (“Thu, Oct 29”).
  ///
  /// In en, this message translates to:
  /// **'{when, select, today{{count, plural, =1{Move 1 task to today, {day}} other{Move {count} tasks to today, {day}}}} tomorrow{{count, plural, =1{Move 1 task to tomorrow, {day}} other{Move {count} tasks to tomorrow, {day}}}} other{{count, plural, =1{Move 1 task to {day}} other{Move {count} tasks to {day}}}}}'**
  String commandBulkMoveTo(int count, String when, String day);

  /// The start of commandBulkMoveTo, shown before the day's chip (commandMoveDay) on a dictation's card that moves a set of tasks to one day: commandBulkMoveLead, a space and commandMoveDay read as commandBulkMoveTo, word for word. {count} is how many are still ticked, and changes as the person unticks them. {when} is today, tomorrow or other, as in commandBulkMoveTo.
  ///
  /// In en, this message translates to:
  /// **'{when, select, today{{count, plural, =1{Move 1 task to} other{Move {count} tasks to}}} tomorrow{{count, plural, =1{Move 1 task to} other{Move {count} tasks to}}} other{{count, plural, =1{Move 1 task to} other{Move {count} tasks to}}}}'**
  String commandBulkMoveLead(int count, String when);

  /// The day of a move on a dictation's card, as a chip after commandBulkMoveLead; a tap opens “Pick a day” to choose another. It ends commandBulkMoveTo, word for word. {when} is today, tomorrow or other. {day} is, for today and tomorrow, the weekday and the day of the month (“Thu 22”); otherwise the day weekday first, as the app shows days (“Thu, Oct 29”).
  ///
  /// In en, this message translates to:
  /// **'{when, select, today{today, {day}} tomorrow{tomorrow, {day}} other{{day}}}'**
  String commandMoveDay(String when, String day);

  /// Heading of a dictation's card that moves a set of tasks by some days, each keeping its time (“move this week's to next week”). {count} is how many are still ticked. {span} is commandBulkSpan (“a week”, “2 days”). {direction} is earlier or later.
  ///
  /// In en, this message translates to:
  /// **'{direction, select, earlier{{count, plural, =1{Move 1 task {span} earlier} other{Move {count} tasks {span} earlier}}} other{{count, plural, =1{Move 1 task {span} later} other{Move {count} tasks {span} later}}}}'**
  String commandBulkShift(int count, String span, String direction);

  /// How far commandBulkShift moves the tasks: in weeks when it is whole weeks ({unit} weeks), otherwise in days. {amount} is how many.
  ///
  /// In en, this message translates to:
  /// **'{unit, select, weeks{{amount, plural, =1{a week} other{{amount} weeks}}} other{{amount, plural, =1{a day} other{{amount} days}}}}'**
  String commandBulkSpan(int amount, String unit);

  /// The confirming button of a dictation's result that moves a set of tasks (commandBulkMoveTo, commandBulkShift). {count} is how many are still ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move 1 task} other{Move {count} tasks}}'**
  String commandBulkMove(int count);

  /// Heading of a dictation's card that assigns a set of tasks to someone. {count} is how many are still ticked; {name} is that person.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assign 1 task to {name}} other{Assign {count} tasks to {name}}}'**
  String commandBulkAssignTo(int count, String name);

  /// The confirming button of a dictation's result that assigns a set of tasks (commandBulkAssignTo). {count} is how many are still ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assign 1 task} other{Assign {count} tasks}}'**
  String commandBulkAssign(int count);

  /// Heading, and confirming button, of a dictation's card that changes a set of tasks in another way (time, priority, deadline): what it sets is the line under it (commandBulkField). {count} is how many are still ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Change 1 task} other{Change {count} tasks}}'**
  String commandBulkChange(int count);

  /// Heading, and confirming button, of a dictation's card that marks a set of tasks as done. {count} is how many are still ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Mark 1 task as done} other{Mark {count} tasks as done}}'**
  String commandBulkComplete(int count);

  /// Heading, and confirming button in the delete style, of a dictation's card that deletes a set of tasks. {count} is how many are still ticked. Undo brings them all back.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 task} other{Delete {count} tasks}}'**
  String commandBulkDelete(int count);

  /// Under the heading of a dictation's card that changes a set of tasks: one thing it sets on each, as label and value (“Time: 18:00”, “Priority: High”). Several are joined with ·.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String commandBulkField(String label, String value);

  /// On a dictation's card for a set of tasks: repeating tasks that matched are left out. {count} is how many; {action} is delete, complete or other (a change); {title} is the one task's title when only one is left out (a repeating task's series title).
  ///
  /// In en, this message translates to:
  /// **'{action, select, delete{{count, plural, =1{{title} repeats: it won’t be deleted} other{{count} repeating tasks won’t be deleted}}} complete{{count, plural, =1{{title} repeats: it won’t be completed} other{{count} repeating tasks won’t be completed}}} other{{count, plural, =1{{title} repeats: it won’t change} other{{count} repeating tasks won’t change}}}}'**
  String commandBulkLeftRepeating(int count, String action, String title);

  /// On a dictation's card that assigns a set of tasks: tasks outside a shared project, or in one {name} can't edit, keep their assignee. {count} is how many; {title} is the one task's title when only one is left out.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{title} can’t be assigned to {name}} other{{count} tasks can’t be assigned to {name}}}'**
  String commandBulkLeftUnassignable(int count, String name, String title);

  /// On a dictation's card that moves tasks by some days or sets their time: tasks with no date (and no deadline) are left as they are. {count} is how many; {title} is the one task's title when only one is left out.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{title} has no date: it won’t change} other{{count} tasks with no date won’t change}}'**
  String commandBulkLeftNoDay(int count, String title);

  /// A dictation's card for a set of tasks when none matched: what was looked for. {status} is completed, any or other (still to do, the default). {period} is commandBulkPeriod, or empty when no period was said.
  ///
  /// In en, this message translates to:
  /// **'{status, select, completed{There are no completed tasks {period}} any{There are no tasks {period}} other{There are no tasks to do {period}}}'**
  String commandBulkNone(String status, String period);

  /// The period at the end of commandBulkNone. {kind} is today, yesterday, tomorrow, range (two days), until (up to a day), since (from a day on), undated (tasks with no date) or other (one day). {from} and {to} are days, weekday first (“Thu, Oct 22”).
  ///
  /// In en, this message translates to:
  /// **'{kind, select, today{for today} yesterday{from yesterday} tomorrow{for tomorrow} range{from {from} to {to}} until{up to {to}} since{from {from} on} undated{with no date} other{on {from}}}'**
  String commandBulkPeriod(String kind, String from, String to);

  /// A dictation's card for a set of more than 200 tasks: nothing is listed and nothing can be applied; the person says it again for fewer. {count} is how many matched.
  ///
  /// In en, this message translates to:
  /// **'That’s {count} tasks, too many. Say it again with one day or one project.'**
  String commandBulkTooMany(int count);

  /// A dictation asked to change a set of tasks, and every task that matched already is as asked. {count} is how many matched. For one task's change card, commandNothingToChange.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It’s already like that.} other{They’re already like that.}}'**
  String commandBulkNothingToChange(int count);

  /// A dictation asked to change, delete or mark done a set of tasks, and the only tasks that match are in a project the person can only view, so none changes. {project} is that project's name.
  ///
  /// In en, this message translates to:
  /// **'You can only view “{project}”: its tasks stay as they are.'**
  String commandBulkViewOnly(String project);

  /// Under one task's title on a dictation's card that moves it by some days: the task has no date (and no deadline), so it isn't moved.
  ///
  /// In en, this message translates to:
  /// **'It has no date, so it stays.'**
  String get commandNoDayStays;

  /// On a dictation's card that marks one task as done: the task was already done, so nothing changes.
  ///
  /// In en, this message translates to:
  /// **'It was already done.'**
  String get commandAlreadyDone;

  /// In the reminder sheet: the choice of a plan of reminders that come more often as the task's day approaches, counted back from its deadline, or from its own day when it has none. Suave, Normal and Intenso sit under it.
  ///
  /// In en, this message translates to:
  /// **'Until the deadline'**
  String get reminderPlanUntilDay;

  /// One of the three strengths under reminderPlanUntilDay: the fewest reminders (weekly, then daily the last 3 days and the day).
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get reminderPlanGentle;

  /// One of the three strengths under reminderPlanUntilDay, the one chosen first: every 3 days, then daily the last week and the day.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get reminderPlanNormal;

  /// One of the three strengths under reminderPlanUntilDay: the most reminders (every 2 days, then daily the last 2 weeks and the day).
  ///
  /// In en, this message translates to:
  /// **'Intense'**
  String get reminderPlanIntense;

  /// In the reminder sheet, a Pro choice: the person types or says the rhythm they want, and the assistant reads it.
  ///
  /// In en, this message translates to:
  /// **'Your way'**
  String get reminderPlanYourWay;

  /// Under the field of reminderPlanYourWay: what to put in it, as an example of a rhythm the strengths of reminderPlanUntilDay can't give. Keep no-break spaces inside the time phrase (ES «a las 8», CA «a les 8», EN “at 8”), so it never wraps apart.
  ///
  /// In en, this message translates to:
  /// **'For example: “a week before, and the day before at 8”.'**
  String get reminderPlanYourWayHint;

  /// On a task in a shared project, says that every reminder choice there rings only for the person who makes it: shown under the title of the reminder sheet and of the one-tap reminder list, and as the helper of “Remind before”.
  ///
  /// In en, this message translates to:
  /// **'These reminders are only for you.'**
  String get reminderPlanJustYou;

  /// A small badge beside a choice that comes with TaskFlow Pro. Tapping the choice opens the Pro screen.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proBadge;

  /// Button under the field of reminderPlanYourWay: listen with the phone's own speech recognition and write the words in the field. Catalan buttons are imperatives.
  ///
  /// In en, this message translates to:
  /// **'Say it'**
  String get reminderPlanSpeak;

  /// The same button while the phone listens: stop, and read the words heard.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get reminderPlanStopListening;

  /// While the assistant reads the words typed or said in reminderPlanYourWay.
  ///
  /// In en, this message translates to:
  /// **'One moment…'**
  String get reminderPlanReading;

  /// The assistant found no reminders in the words of reminderPlanYourWay: ask for them again. The field's helper, reminderPlanYourWayHint, gives the example; saying it again starts from an empty field.
  ///
  /// In en, this message translates to:
  /// **'I didn’t get that. Try saying it another way.'**
  String get reminderPlanUnclear;

  /// reminderPlanYourWay with no connection: it needs one, and the strengths of reminderPlanUntilDay work without.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection. “Until the deadline” works without one.'**
  String get reminderPlanOffline;

  /// reminderPlanYourWay: the assistant failed, was busy, or today's limit was reached. The strengths of reminderPlanUntilDay still work.
  ///
  /// In en, this message translates to:
  /// **'I couldn’t read that just now. Try again later, or choose “Until the deadline”.'**
  String get reminderPlanFailed;

  /// reminderPlanSpeak tapped, and the microphone isn't allowed.
  ///
  /// In en, this message translates to:
  /// **'Without the microphone I can’t hear you. You can type it.'**
  String get reminderPlanMicOff;

  /// reminderPlanSpeak tapped, and the phone can't recognise speech on its own.
  ///
  /// In en, this message translates to:
  /// **'I can’t listen on this phone right now. You can type it.'**
  String get reminderPlanCantListen;

  /// The plan's preview in the reminder sheet: how many reminders are still to come, and the next one. {when} is today, tomorrow or other; {date} is the day (sat 25); {time} the clock time.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reminder: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}} other{{count} reminders · next: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}}}'**
  String reminderPlanCount(int count, String when, String date, String time);

  /// The plan's preview when none of its reminders is still to come.
  ///
  /// In en, this message translates to:
  /// **'No reminders left'**
  String get reminderPlanNoneLeft;

  /// A strength's plan in words, on the task and under reminderPlanUntilDay. {when} is today, tomorrow or other; {date} is the day the plan counts back from (thu 12).
  ///
  /// In en, this message translates to:
  /// **'More and more often {when, select, today{until today} tomorrow{until tomorrow} other{until {date}}}'**
  String reminderPlanGrowing(String when, String date);

  /// A plan's rhythm, lowercase: part of a sentence such as «Cada 3 días, y a diario la última semana».
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{daily} other{every {days} days}}'**
  String reminderPlanEveryDays(int days);

  /// A plan's rhythm in weeks, lowercase: part of a plan's sentence.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{weekly} other{every {weeks} weeks}}'**
  String reminderPlanEveryWeeks(int weeks);

  /// When a rhythm applies: the last days before the task's day, and the day. Goes after reminderPlanEveryDays: «a diario los últimos 3 días».
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{for the last day} other{for the last {days} days}}'**
  String reminderPlanLastDays(int days);

  /// When a rhythm applies: the last weeks before the task's day, and the day: «a diario la última semana».
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{for the last week} other{for the last {weeks} weeks}}'**
  String reminderPlanLastWeeks(int weeks);

  /// When a rhythm starts, counted back from the task's day: «cada 2 días desde 10 días antes».
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{from the day before} other{from {days} days before}}'**
  String reminderPlanFromDays(int days);

  /// When a rhythm starts, in weeks before the task's day: «cada 2 días desde 2 semanas antes».
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{from a week before} other{from {weeks} weeks before}}'**
  String reminderPlanFromWeeks(int weeks);

  /// When a rhythm stops, before the task's day: «cada 3 días hasta 8 días antes».
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{until the day before} other{until {days} days before}}'**
  String reminderPlanUntilDays(int days);

  /// When a rhythm stops, in weeks before the task's day: «cada 3 días hasta una semana antes».
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{until a week before} other{until {weeks} weeks before}}'**
  String reminderPlanUntilWeeks(int weeks);

  /// A single reminder of a plan, on the task's day itself, lowercase: «El día antes, y el mismo día».
  ///
  /// In en, this message translates to:
  /// **'on the day'**
  String get reminderPlanOnTheDay;

  /// A single reminder of a plan, some days before the task's day, lowercase: «el día antes», «3 días antes».
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{the day before} other{{days} days before}}'**
  String reminderPlanDaysBefore(int days);

  /// A single reminder of a plan, some weeks before the task's day, lowercase: «una semana antes».
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{a week before} other{{weeks} weeks before}}'**
  String reminderPlanWeeksBefore(int weeks);

  /// A rhythm and when it applies: «a diario» + «la última semana». Each is one of the reminderPlan… parts.
  ///
  /// In en, this message translates to:
  /// **'{rhythm} {window}'**
  String reminderPlanPhase(String rhythm, String window);

  /// The last two parts of a plan's sentence: «Cada 3 días, y a diario la última semana».
  ///
  /// In en, this message translates to:
  /// **'{first}, and {last}'**
  String reminderPlanAnd(String first, String last);

  /// A plan's sentence with three or four parts: the first, then the rest (which ends with reminderPlanAnd).
  ///
  /// In en, this message translates to:
  /// **'{first}, {rest}'**
  String reminderPlanList(String first, String rest);

  /// On a task with a plan: the plan in words (reminderPlanStrengthLine or reminderPlanOwnLine), then its next reminder, on or before the task's day. {when} is today, tomorrow or other; {date} the day (sat 24); {time} the clock time, as the app writes it.
  ///
  /// In en, this message translates to:
  /// **'{plan} · next: {when, select, today{today} tomorrow{tomorrow} other{{date}}}, {time}'**
  String reminderPlanLine(String plan, String when, String date, String time);

  /// On a task whose plan is one of the three strengths (reminderPlanGentle, reminderPlanNormal, reminderPlanIntense): the plan in words, naming its strength. {strength} is gentle, normal or other (intense); {when} is today, tomorrow or other; {date} is the day the plan counts back from (thu 12).
  ///
  /// In en, this message translates to:
  /// **'{strength, select, gentle{Gentle} normal{Normal} other{Intense}} reminders {when, select, today{until today} tomorrow{until tomorrow} other{until {date}}}'**
  String reminderPlanStrengthLine(String strength, String when, String date);

  /// On a task with a plan of one's own: the plan in words. {rhythm} is its rhythm, lowercase (every 3 days, and daily for the last week).
  ///
  /// In en, this message translates to:
  /// **'Reminders: {rhythm}'**
  String reminderPlanOwnLine(String rhythm);

  /// A plan's notification text, under the task's title: how many days are left until its day (2 or more), then the day. {date} is the weekday date as notifications write it (Thu, Nov 12), followed by the time when the task has one (Thu, Nov 12, 5:00 PM).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day left · {date}} other{{days} days left · {date}}}'**
  String reminderPlanNoticeDays(int days, String date);

  /// A plan's notification text for a task with a deadline, under the task's title: the deadline, then how many days are left (2 or more). {date} is the weekday date as notifications write it (Thu, Nov 12), followed by the time when the deadline has one (Thu, Nov 12, 5:00 PM).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Deadline: {date} · 1 day left} other{Deadline: {date} · {days} days left}}'**
  String reminderPlanNoticeDeadlineDays(int days, String date);

  /// A plan's notification text, the day before a task with a time. {time} is the task's time as the app's clock writes it; {hour} is the hour as shown, for the article (Spanish and Catalan say a la 1:00).
  ///
  /// In en, this message translates to:
  /// **'{hour, plural, other{It’s tomorrow at {time}}}'**
  String reminderPlanNoticeTomorrowAt(int hour, String time);

  /// A plan's notification text, on the day of a task with a time. Placeholders as in reminderPlanNoticeTomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'{hour, plural, other{It’s today at {time}}}'**
  String reminderPlanNoticeTodayAt(int hour, String time);

  /// A plan's notification text, the day before a deadline that has no time.
  ///
  /// In en, this message translates to:
  /// **'Deadline: tomorrow'**
  String get reminderPlanNoticeDeadlineTomorrow;

  /// A plan's notification text, the day before a task's day that has no time.
  ///
  /// In en, this message translates to:
  /// **'It’s tomorrow'**
  String get reminderPlanNoticeTomorrow;

  /// A plan's notification text, on a task's day that has no time.
  ///
  /// In en, this message translates to:
  /// **'It’s today'**
  String get reminderPlanNoticeToday;

  /// A plan's one last notification, the day after, for a task with only a day that isn't done.
  ///
  /// In en, this message translates to:
  /// **'It was planned for yesterday'**
  String get reminderPlanNoticeWas;

  /// A plan's one last notification, the day after, for a task with a deadline that isn't done.
  ///
  /// In en, this message translates to:
  /// **'It was due yesterday'**
  String get reminderPlanNoticeDue;

  /// Asked once after saving a task whose day is 2 weeks or more away, under the task's title and day: shall the app remind the person with the Normal plan. {rhythm} is Normal's rhythm in lowercase words, as reminderPlanEveryDays and reminderPlanPhase write it (every 3 days, and daily for the last week). Yes, remind me (reminderAskYes) sets Normal.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{1 week to go. Shall I remind you {rhythm}?} other{{weeks} weeks to go. Shall I remind you {rhythm}?}}'**
  String reminderPlanOfferWeeks(int weeks, String rhythm);

  /// reminderPlanOfferWeeks for a day 2 months or more away. {rhythm} is Normal's rhythm in lowercase words.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month to go. Shall I remind you {rhythm}?} other{{months} months to go. Shall I remind you {rhythm}?}}'**
  String reminderPlanOfferMonths(int months, String rhythm);

  /// After yes to the offer: the plan is set. {date} is the day it counts back from (thu 12).
  ///
  /// In en, this message translates to:
  /// **'Done. I’ll remind you until {date}.'**
  String reminderPlanOfferDone(String date);

  /// On the Pro screen, opened from “Your way” in the reminder sheet: what Pro adds there. A heading, followed by billingReasonReminderPlansExample.
  ///
  /// In en, this message translates to:
  /// **'With Pro, ask for reminders in your own words:'**
  String get billingReasonReminderPlans;

  /// On the Pro screen, under billingReasonReminderPlans: an example of a reminder rhythm said in your own words, in quotes and with no final period. Use the same example as reminderPlanYourWayHint: a rhythm that Gentle, Normal and Intense don’t give, so it doesn’t sell a free rhythm as Pro. Keep no-break spaces inside the time phrase (ES «a las 8», CA «a les 8», EN “at 8”), so it never wraps apart.
  ///
  /// In en, this message translates to:
  /// **'“a week before, and the day before at 8”'**
  String get billingReasonReminderPlansExample;

  /// In the Notes tab, under “Add a note”: records a conversation (a meeting with a client, a class) and turns it into notes. Pro only; without Pro it opens the Pro screen.
  ///
  /// In en, this message translates to:
  /// **'Record a meeting'**
  String get meetingRecord;

  /// The title of the screen that records a meeting and then prepares its notes.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingScreenTitle;

  /// On the recording screen, above the elapsed time: says the microphone is listening. Short.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get meetingListening;

  /// On the recording screen, just above the Stop button (meetingStop): leaving the screen or locking the phone doesn’t stop the recording.
  ///
  /// In en, this message translates to:
  /// **'You can leave or lock the phone: it keeps recording until you press Stop.'**
  String get meetingListeningHelp;

  /// The large button that stops recording a meeting; its notes are then prepared. Also the Stop button of the ongoing “recording a meeting” notification.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get meetingStop;

  /// Asked before a meeting recording is discarded, while recording or after it stopped.
  ///
  /// In en, this message translates to:
  /// **'Discard this recording? It’s deleted from your phone and can’t be recovered.'**
  String get meetingDiscardQuestion;

  /// In meetingDiscardQuestion while recording: closes the question and goes on recording. Also on a recording that stopped by itself: records more into the same meeting.
  ///
  /// In en, this message translates to:
  /// **'Keep recording'**
  String get meetingKeepRecording;

  /// After Stop: the meeting’s notes are being made. Also the Notes tab’s line for a meeting waiting for its notes.
  ///
  /// In en, this message translates to:
  /// **'Preparing your notes…'**
  String get meetingPreparing;

  /// Under meetingPreparing on the meeting screen.
  ///
  /// In en, this message translates to:
  /// **'It takes a few seconds. You can leave this screen: we’ll let you know when they’re ready.'**
  String get meetingPreparingHelp;

  /// Under meetingPreparing on the meeting screen, instead of meetingPreparingHelp, when the phone’s notifications are off for TaskFlow: no notice can arrive, so it says where the notes will be (the Notes tab).
  ///
  /// In en, this message translates to:
  /// **'It takes a few seconds. You can leave this screen: the notes will be in Notes.'**
  String get meetingPreparingHelpNoNotice;

  /// A stopped meeting whose recording can’t be sent: the phone has no signal.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection'**
  String get meetingWaitingConnection;

  /// Under meetingWaitingConnection on the meeting screen.
  ///
  /// In en, this message translates to:
  /// **'Your recording is safe on this phone. The notes are made once you’re back online, and we’ll let you know.'**
  String get meetingWaitingConnectionHelp;

  /// Under meetingWaitingConnection on the meeting screen, instead of meetingWaitingConnectionHelp, when the phone’s notifications are off for TaskFlow.
  ///
  /// In en, this message translates to:
  /// **'Your recording is safe on this phone. The notes are made once you’re back online, and they’ll be in Notes.'**
  String get meetingWaitingConnectionHelpNoNotice;

  /// A short message after Stop when the recording was only silence.
  ///
  /// In en, this message translates to:
  /// **'Nothing was heard, so there’s nothing to save.'**
  String get meetingNothingHeard;

  /// A short message on the meeting recording screen when Stop failed after the microphone had stopped: what was recorded is kept, and Stop (meetingStop) can be pressed again to finish.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t finish stopping. What was recorded is safe: press Stop again.'**
  String get meetingStopFailed;

  /// Asked after Stop when a meeting recording of a minute or more was judged nearly all silence. Its buttons are meetingMakeNotes (keeps the recording and makes the notes) and discard (deletes it).
  ///
  /// In en, this message translates to:
  /// **'Almost nothing was heard. Make notes anyway?'**
  String get meetingQuietQuestion;

  /// Which recording a stopped meeting’s line is about, when it started today. time is the time of day it started, as 10:15.
  ///
  /// In en, this message translates to:
  /// **'Recording from today, {time}'**
  String meetingRecordingToday(String time);

  /// As meetingRecordingToday, for a recording that started yesterday.
  ///
  /// In en, this message translates to:
  /// **'Recording from yesterday, {time}'**
  String meetingRecordingYesterday(String time);

  /// As meetingRecordingToday, for a recording that started before yesterday. date is the day with its weekday in full, as Tuesday, Nov 3 (es: martes 3 nov; ca: dimarts 3 de nov.).
  ///
  /// In en, this message translates to:
  /// **'Recording from {date}, {time}'**
  String meetingRecordingOn(String date, String time);

  /// In the Notes tab, for a meeting recording that stopped without Stop (the app closed, the phone switched off). recording is meetingRecordingToday, meetingRecordingYesterday or meetingRecordingOn; length is how much was recorded, in words.
  ///
  /// In en, this message translates to:
  /// **'{recording} · {length}. It stopped before you pressed Stop.'**
  String meetingStoppedCut(String recording, String length);

  /// Instead of meetingStoppedCut, in the Notes tab and on the meeting screen, for a stopped meeting recording judged nearly all silence (as after Stop and meetingQuietQuestion), waiting to be made into notes or discarded. recording is meetingRecordingToday, meetingRecordingYesterday or meetingRecordingOn; length is how much was recorded, in words.
  ///
  /// In en, this message translates to:
  /// **'{recording} · {length}. Almost nothing was heard.'**
  String meetingStoppedQuiet(String recording, String length);

  /// The main button on a recording that stopped by itself: makes the notes from what was recorded.
  ///
  /// In en, this message translates to:
  /// **'Make the notes'**
  String get meetingMakeNotes;

  /// In the Notes tab while a meeting records and its screen was left. time is the recorded length in words (meetingLengthHoursMinutes and the like), as 12 min.
  ///
  /// In en, this message translates to:
  /// **'Recording a meeting · {time}'**
  String meetingRecordingNow(String time);

  /// Instead of meetingRecordingNow, in the Notes tab, when Stop failed after the microphone had stopped (meetingStopFailed): nothing is recording, and Stop (meetingStop) on its screen finishes it. length is the recorded length in words, as 12 min.
  ///
  /// In en, this message translates to:
  /// **'Recording not fully stopped · {length}. Open it and press Stop.'**
  String meetingRecordingUnstopped(String length);

  /// On meetingRecordingNow: opens the recording screen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get meetingOpen;

  /// Read by TalkBack for meetingOpen on the Notes recording line (shown as “Open”).
  ///
  /// In en, this message translates to:
  /// **'Open the recording'**
  String get meetingOpenNamed;

  /// A meeting’s recorded length when it is under a minute, in running text and TalkBack names (“Recording a meeting · under 1 min”).
  ///
  /// In en, this message translates to:
  /// **'under 1 min'**
  String get meetingLengthUnderMinute;

  /// A meeting’s length, or a point in it, in whole hours: “2 h”. Lengths under an hour use durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String meetingLengthHours(int hours);

  /// A meeting’s length, or a point in it, past an hour: “1 h 42 min”. A length, not a time of day.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String meetingLengthHoursMinutes(int hours, int minutes);

  /// Read by TalkBack for the recording screen’s time (shown as 0:07) under a minute.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second recorded} other{{seconds} seconds recorded}}'**
  String meetingRecordedSeconds(int seconds);

  /// Read by TalkBack for the recording screen’s time (shown as 12:03) under an hour.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}} {seconds, plural, =1{1 second} other{{seconds} seconds}} recorded'**
  String meetingRecordedMinutes(int minutes, int seconds);

  /// Read by TalkBack for the recording screen’s time (shown as 1:04:05) from an hour on.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}} {minutes, plural, =1{1 minute} other{{minutes} minutes}} {seconds, plural, =1{1 second} other{{seconds} seconds}} recorded'**
  String meetingRecordedHours(int hours, int minutes, int seconds);

  /// A stopped meeting whose notes the server refused: the account no longer has Pro.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes are part of TaskFlow Pro. Your recording waits on this phone.'**
  String get meetingProRequired;

  /// A stopped meeting held back: this month’s allowance of meeting time is used.
  ///
  /// In en, this message translates to:
  /// **'You’ve used this month’s meeting time. Your recording waits on this phone until next month.'**
  String get meetingAllowanceUsed;

  /// On the recording screen, under the elapsed time, from the start of a recording: another meeting was already refused this month for the month’s meeting time. Recording goes on.
  ///
  /// In en, this message translates to:
  /// **'You’ve used this month’s meeting time: you can record, and the notes come next month.'**
  String get meetingAllowanceUsedStart;

  /// A stopped meeting that can only be discarded: a piece of its audio is lost or refused for good.
  ///
  /// In en, this message translates to:
  /// **'Part of this recording couldn’t be sent, so no notes can be made from it.'**
  String get meetingCantMakeNotes;

  /// The microphone permission was refused and Android no longer asks. Same path as captureMicrophoneBlocked; followed by captureOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'To record a meeting, open Settings and tap Permissions › Microphone › Allow.'**
  String get meetingMicrophoneBlocked;

  /// The microphone permission was refused, and Android still asks: followed by meetingAllowMicrophone.
  ///
  /// In en, this message translates to:
  /// **'To record a meeting, TaskFlow needs the microphone.'**
  String get meetingMicrophoneNeeded;

  /// Button under meetingMicrophoneNeeded: asks Android for the microphone again, and records once it’s allowed.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone'**
  String get meetingAllowMicrophone;

  /// Under about 100 MB free: a meeting can’t start.
  ///
  /// In en, this message translates to:
  /// **'Your phone is almost full. Free up some space to record a meeting.'**
  String get meetingLowSpace;

  /// On the recording screen, under the elapsed time, when the phone has under about 300 MB free: recording goes on, and stops safely by itself near 100 MB.
  ///
  /// In en, this message translates to:
  /// **'Low on space: the recording stops by itself if the phone fills up.'**
  String get meetingSpaceLowWarning;

  /// The microphone failed to start a meeting recording.
  ///
  /// In en, this message translates to:
  /// **'The recording couldn’t start. Try again.'**
  String get meetingStartFailed;

  /// On the meeting screen, above meetingPreparing: the recording stopped itself to keep the phone working.
  ///
  /// In en, this message translates to:
  /// **'Your phone ran out of space, so the recording stopped.'**
  String get meetingStoppedNoSpace;

  /// On the meeting screen, above the stopped recording's question: the microphone failed mid-recording.
  ///
  /// In en, this message translates to:
  /// **'The microphone stopped working, so the recording stopped.'**
  String get meetingMicrophoneFailed;

  /// The title of the ongoing notification while a meeting records.
  ///
  /// In en, this message translates to:
  /// **'Recording a meeting'**
  String get meetingNoticeTitle;

  /// In the capture sheet, above the text field, when it opens for typing because a meeting is recording and holds the microphone.
  ///
  /// In en, this message translates to:
  /// **'A meeting is recording: type here.'**
  String get meetingTypeHere;

  /// The name Android’s notification settings give the ongoing “recording a meeting” notification.
  ///
  /// In en, this message translates to:
  /// **'Meeting recording'**
  String get meetingRecordingChannel;

  /// The name Android’s notification settings give the “your meeting notes are ready” notification.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes'**
  String get meetingNotesChannel;

  /// The text of the notification when a meeting’s notes are saved, under the note’s title; its title when the note has none. Tapping it opens the note.
  ///
  /// In en, this message translates to:
  /// **'Your meeting notes are ready'**
  String get meetingNotesReady;

  /// In a note made from a meeting: the heading over the decisions taken. Written in the meeting’s language.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get meetingNoteDecisions;

  /// In a note made from a meeting: the heading over what was left unanswered.
  ///
  /// In en, this message translates to:
  /// **'Open questions'**
  String get meetingNoteOpenQuestions;

  /// In a note made from a meeting: the heading over one line per part, as “Minutes 30–52 · Pricing”.
  ///
  /// In en, this message translates to:
  /// **'Parts of the meeting'**
  String get meetingNoteChapters;

  /// The first line of a note made from a meeting whose first part was deleted from the server after 30 days without signal.
  ///
  /// In en, this message translates to:
  /// **'The start of this recording expired, so these notes cover only the rest.'**
  String get meetingNoteStartMissing;

  /// The title of a note made from a meeting in which nothing was said.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes'**
  String get meetingNoteUntitled;

  /// The first line of a note made from a meeting, in the meeting’s language: when it started and how long it was, so a relative “Friday” in its to-dos can still be placed. date is the weekday in full, the day and the short month from the language’s date format, then the 24-hour time.
  ///
  /// In en, this message translates to:
  /// **'Meeting on {date} · {length}'**
  String meetingNoteHeader(String date, String length);

  /// In a note made from a meeting: how a part of it within the first hour starts its line, as “Minutes 0–30 · Pricing”. Later parts use lengths, as “1 h 30 min – 2 h · …”.
  ///
  /// In en, this message translates to:
  /// **'Minutes {start}–{end}'**
  String meetingNoteChapterMinutes(int start, int end);

  /// On a note with steps (a meeting’s to-dos): opens the review with a task titled like the note and its steps as the checklist.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get meetingCreateTask;

  /// Heading over the steps in the review «Create task» opens from a note: each ticked step goes into the task, unticked ones are left out.
  ///
  /// In en, this message translates to:
  /// **'Steps to add'**
  String get meetingStepsToAdd;

  /// On a note that already made a task with «Create task»: opens that task.
  ///
  /// In en, this message translates to:
  /// **'View task'**
  String get meetingViewTask;

  /// Title of the question on Sign out when meeting recordings still wait on this phone.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get meetingSignOutTitle;

  /// Body of meetingSignOutTitle when a meeting is recording now; meetingSignOutQuestion follows for any other meetings waiting, then meetingSignOutReminders.
  ///
  /// In en, this message translates to:
  /// **'You’re recording a meeting. It stops, and its notes are made before you sign out.'**
  String get meetingSignOutRecording;

  /// Body of meetingSignOutTitle when meeting recordings still wait on this phone (not counting one recording now): they belong to this account and can’t be sent after signing out. meetingSignOutReminders follows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A meeting’s notes aren’t ready yet, and its recording is only on this phone.} other{The notes of {count} meetings aren’t ready yet, and their recordings are only on this phone.}}'**
  String meetingSignOutQuestion(int count);

  /// Ends the body of meetingSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders on this phone stop until you sign in again.'**
  String get meetingSignOutReminders;

  /// In meetingSignOutTitle: sends the recordings so their notes are made, then signs out.
  ///
  /// In en, this message translates to:
  /// **'Save notes and sign out'**
  String get meetingSendFirst;

  /// In meetingSignOutTitle: deletes the recordings, then signs out.
  ///
  /// In en, this message translates to:
  /// **'Discard and sign out'**
  String get meetingDiscardAndSignOut;

  /// On the account screen while meetingSendFirst sends.
  ///
  /// In en, this message translates to:
  /// **'Sending your recording…'**
  String get meetingSending;

  /// Under Sign out on the account screen, from the tap on meetingSendFirst until sign-in shows or the send fails.
  ///
  /// In en, this message translates to:
  /// **'Saving your meeting’s notes… This can take a few minutes. Then you’ll be signed out.'**
  String get meetingSavingNotes;

  /// After meetingSendFirst, when the phone couldn’t reach the server: you stay signed in.
  ///
  /// In en, this message translates to:
  /// **'No connection, so the notes couldn’t be made. You’re still signed in; tap Sign out again once you’re online.'**
  String get meetingSendFailed;

  /// After meetingSendFirst, when the notes still weren’t made after a few minutes of trying while online: you stay signed in.
  ///
  /// In en, this message translates to:
  /// **'The notes are taking longer than usual. You’re still signed in; try Sign out again in a few minutes.'**
  String get meetingSendSlow;

  /// A stopped meeting that can only be discarded: it waited so long that the server deleted what it had already received.
  ///
  /// In en, this message translates to:
  /// **'This recording was kept too long without being finished, so no notes can be made from it.'**
  String get meetingNotesExpired;

  /// After meetingSendFirst, when the account no longer has Pro: you stay signed in.
  ///
  /// In en, this message translates to:
  /// **'Your recording can’t be sent without TaskFlow Pro. Stay signed in to keep it, or discard it.'**
  String get meetingSendFailedPro;

  /// After meetingSendFirst, when this month’s meeting allowance is used: you stay signed in.
  ///
  /// In en, this message translates to:
  /// **'You’ve used this month’s meeting time, so your recording can’t be sent until next month. Stay signed in to keep it, or discard it.'**
  String get meetingSendFailedAllowance;

  /// After meetingSendFirst, when a recording can only be discarded (meetingCantMakeNotes or meetingNotesExpired): you stay signed in.
  ///
  /// In en, this message translates to:
  /// **'A recording can’t become notes any more. Discard it to sign out.'**
  String get meetingSendFailedLost;

  /// Follows meetingSendFailedLost when more than one recording waits ({count} is 2 or more): meetingDiscardAndSignOut deletes them all, not only the lost one.
  ///
  /// In en, this message translates to:
  /// **'Discard and sign out deletes all {count} waiting recordings.'**
  String meetingDiscardDeletesAll(int count);

  /// Read by TalkBack for Discard on a meeting line in Notes (shown as “Discard”), so several lines’ buttons can be told apart. {time} is the recorded length in words.
  ///
  /// In en, this message translates to:
  /// **'Discard the recording of {time}'**
  String meetingDiscardNamed(String time);

  /// Read by TalkBack for meetingMakeNotes on a stopped meeting’s line. {time} is the recorded length in words.
  ///
  /// In en, this message translates to:
  /// **'Make the notes from the recording of {time}'**
  String meetingFinishNamed(String time);

  /// Read by TalkBack for meetingKeepRecording on a stopped meeting’s line: records more into the same meeting. {time} is the recorded length in words.
  ///
  /// In en, this message translates to:
  /// **'Keep recording, {time} so far'**
  String meetingContinueNamed(String time);

  /// On the Pro screen, opened from “Record a meeting” in Notes or from “Explore Pro” on a recording held back for Pro: what Pro adds there, worded to fit both (it never asks to record a meeting already recorded). A heading, followed by billingReasonMeetingNotesExample.
  ///
  /// In en, this message translates to:
  /// **'With Pro, your meetings become notes:'**
  String get billingReasonMeetingNotes;

  /// On the Pro screen, under billingReasonMeetingNotes: what the notes hold, with no final period. The to-dos become one task’s steps, so it says to-dos, not tasks.
  ///
  /// In en, this message translates to:
  /// **'a summary, the decisions and the to-dos'**
  String get billingReasonMeetingNotesExample;

  /// The Pro screen's list of what Pro gives, last line: notes made from the meetings you record (Notes › Record a meeting), with the monthly meeting time (D4 of 2026-11-04). hours is a whole number, as 20. Left out when the screen opens for a meeting, whose heading already names it.
  ///
  /// In en, this message translates to:
  /// **'Notes from your recorded meetings, up to {hours} hours a month'**
  String proBenefitMeetingNotes(int hours);

  /// On the recording screen, under meetingListeningHelp, quietly: what happens to the recording's audio (the owner's decision D5 of 2026-11-04). It must match the website's privacy page.
  ///
  /// In en, this message translates to:
  /// **'The audio is sent to make the notes, then deleted.'**
  String get meetingAudioDeleted;

  /// Asked once, the first time a meeting records while TaskFlow's notifications are off, before Android's own permission dialog (D3 of 2026-11-04). It refers to the recording.
  ///
  /// In en, this message translates to:
  /// **'So you can stop it from the notification, and so we can tell you when the notes are ready.'**
  String get meetingNotifyAsk;

  /// The only button under meetingNotifyAsk: opens Android's notification permission dialog.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get meetingNotifyAskContinue;

  /// On the Pro screen opened for a meeting, under billingReasonMeetingNotesExample: the monthly meeting time Pro includes (D4 of 2026-11-04). hours is a whole number, as 20.
  ///
  /// In en, this message translates to:
  /// **'Up to {hours} hours of meetings a month.'**
  String billingReasonMeetingNotesLimit(int hours);
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
      <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
