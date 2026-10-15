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

  /// No description provided for @reviewInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Check this value'**
  String get reviewInvalidTime;

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

  /// No description provided for @reviewRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get reviewRemove;

  /// No description provided for @reviewRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get reviewRemoved;

  /// No description provided for @reviewUndoSaved.
  ///
  /// In en, this message translates to:
  /// **'They’re back here, not saved yet.'**
  String get reviewUndoSaved;

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
  /// **'{reason, select, signOutFirst{Sign out before changing servers.} https{Use an HTTPS server address for this build.} serverAddress{Enter a valid server address, such as https://your-server.example.} emailUsed{An account with this email already exists. Sign in or recover your password.} email{Enter a valid email address.} credentials{We couldn’t find that account, or the password is wrong.} session{Please sign in again to continue. Your local tasks are kept.} accountChanged{The account changed. Reopen this screen and try again.} password{Choose a password of 12–128 characters that is not common, entirely numeric or similar to your email.} recoveryCode{The recovery code is invalid or expired. Request a new one.} forbidden{This account cannot perform that action. Check your access.} rateLimit{Too many requests. Please wait a little before trying again.} fileLimit{Choose a non-empty file up to 6 MB.} fileChanged{The file has changed or could not be verified. Choose it again or retry the download.} network{No connection. Check Wi-Fi or mobile data and try again.} networkKept{No connection. Check Wi-Fi or mobile data and try again. Your tasks are still saved on this phone.} unavailable{The service is unavailable. Please try again later.} validation{Some details were not accepted. Review the information and try again.} other{Could not complete the request. Please try again.} otherKept{Could not complete the request. Please try again. Your tasks are still saved on this phone.}}'**
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

  /// Option of the Notes project filter that shows the notes of every project.
  ///
  /// In en, this message translates to:
  /// **'All notes'**
  String get allNotes;

  /// No description provided for @viewOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'View-only note. The project owner manages editing access.'**
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

  /// Calendar agenda line under the day’s tasks, followed by up to three start times.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 event} other{{count} events}}'**
  String calendarEventCount(int count);

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

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

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

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

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
  /// **'Nothing planned for this day.'**
  String get calendarEmpty;

  /// Calendar's empty state while the account has no tasks or notes yet and Add a task opens the mic. The quoted example names two tasks on one day, with one date word and no hour, so both land on the same day and Save as written (the phone's parser) still dates it without a question.
  ///
  /// In en, this message translates to:
  /// **'Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”'**
  String get calendarTrySaying;

  /// Calendar's empty state while the account has no tasks or notes yet and Add a task opens typing. One task, because typed words are parsed on the phone, which can't split them; one date word and no hour from 1 to 12, so it's added with no question.
  ///
  /// In en, this message translates to:
  /// **'Try it: tap Add a task and type “Tomorrow, call the dentist.”'**
  String get calendarTryTyping;

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

  /// No description provided for @homeCaptureInstructions.
  ///
  /// In en, this message translates to:
  /// **'On Android, long-press the TaskFlow icon for its shortcuts, or add the Say a task widget from your launcher. Share text to TaskFlow from another app.'**
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

  /// No description provided for @archivedList.
  ///
  /// In en, this message translates to:
  /// **'Archived project'**
  String get archivedList;

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

  /// No description provided for @recordingKept.
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

  /// No description provided for @capturePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Live transcription uses on-device speech where available; no audio is retained in that mode. AI task extraction still needs the internet and sends your words to Google. Saved audio is transcribed online. Anything not saved yet stays on this phone until you save or discard it.'**
  String get capturePrivacy;

  /// One short line under the words in the capture sheet, shown only the first time the microphone is used on this device. The full note is on the Voice screen in Settings.
  ///
  /// In en, this message translates to:
  /// **'Your words go online. More in Settings.'**
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

  /// No description provided for @agendaCounts.
  ///
  /// In en, this message translates to:
  /// **'{remaining} to do · {done} completed'**
  String agendaCounts(int remaining, int done);

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
  /// **'Added with no date'**
  String get taskSavedInbox;

  /// After saving a new task with a date. The date is a weekday and date such as Fri, Oct 17, never Today or Tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Added to {date}'**
  String taskAddedOn(String date);

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

  /// Under a date read from typed words, before the Keep as typed button.
  ///
  /// In en, this message translates to:
  /// **'From your words'**
  String get fromYourWords;

  /// Text button: the typed words become the title again, without the date read from them.
  ///
  /// In en, this message translates to:
  /// **'Keep as typed'**
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

  /// No description provided for @accountHeading.
  ///
  /// In en, this message translates to:
  /// **'Your own little space.'**
  String get accountHeading;

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

  /// No description provided for @invitationCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'This code and the invited TaskFlow account are both needed to join. Share it only with the intended person. Replacing an invitation invalidates its previous code.'**
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

  /// No description provided for @shareProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Share {project}'**
  String shareProjectTitle(String project);

  /// No description provided for @theirEmail.
  ///
  /// In en, this message translates to:
  /// **'Their email'**
  String get theirEmail;

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
  /// **'Editors can add, change, complete and delete tasks and files. Only the owner manages the project and people. Shared tasks stay in this project; exporting creates a personal copy.'**
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

  /// No description provided for @removeAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'This person will lose access to this project and its tasks, notes and files. Their unsent shared edits will be removed on the next successful sync.'**
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

  /// No description provided for @retryInvitations.
  ///
  /// In en, this message translates to:
  /// **'Retry invitations'**
  String get retryInvitations;

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

  /// No description provided for @fileLocalHelp.
  ///
  /// In en, this message translates to:
  /// **'Files stay on this device until you sign in and choose Upload in task details. Up to 6 MB per file.'**
  String get fileLocalHelp;

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
  /// **'Allow “Alarms & reminders”'**
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

  /// Replaces a reminder for a few seconds after Complete, beside an Undo action.
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

  /// No description provided for @captureNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks were found. Your words are kept.'**
  String get captureNoTasks;

  /// No description provided for @captureUnsupportedKind.
  ///
  /// In en, this message translates to:
  /// **'This server does not support this way of adding tasks. Your words are kept.'**
  String get captureUnsupportedKind;

  /// No description provided for @captureOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet. Your words are saved — try again when you’re online.'**
  String get captureOffline;

  /// No description provided for @captureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the assistant — your words are kept.'**
  String get captureUnavailable;

  /// No description provided for @captureAllowance.
  ///
  /// In en, this message translates to:
  /// **'You’ve reached today’s limit. Type the task, or try again tomorrow.'**
  String get captureAllowance;

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
  /// **'This recording exceeds the service limit. Keep it for later or use a shorter typed description.'**
  String get captureTooLarge;

  /// No description provided for @captureTypedFirst.
  ///
  /// In en, this message translates to:
  /// **'Save or discard what you typed before starting a recording.'**
  String get captureTypedFirst;

  /// No description provided for @captureMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record, or type below.'**
  String get captureMicrophone;

  /// Shown by the microphone when Android will no longer ask for microphone access.
  ///
  /// In en, this message translates to:
  /// **'Microphone is off for TaskFlow. Turn it on in Settings, or type instead.'**
  String get captureMicrophoneBlocked;

  /// Opens the phone’s settings for TaskFlow, to turn the microphone on.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get captureOpenSettings;

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

  /// Shown under the words after about 5 seconds without new words.
  ///
  /// In en, this message translates to:
  /// **'Still listening. Tap Done when finished.'**
  String get captureStillListening;

  /// Shown 10 seconds before the 60-second listening limit.
  ///
  /// In en, this message translates to:
  /// **'10 seconds left'**
  String get captureTimeLeft;

  /// The one question asked when leaving the capture sheet with something said or written: by Cancel, Back, a tap above the sheet or a swipe down, while listening, while typing and on a result. No body text; its buttons are discard and keep.
  ///
  /// In en, this message translates to:
  /// **'Keep it for later?'**
  String get captureKeepQuestion;

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

  /// No description provided for @captureSpeechLanguage.
  ///
  /// In en, this message translates to:
  /// **'On-device speech is not installed for this language. Choose another language, record audio, or type.'**
  String get captureSpeechLanguage;

  /// No description provided for @captureSpeechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'On-device speech is unavailable. Record audio or type instead.'**
  String get captureSpeechUnavailable;

  /// No description provided for @captureSpeechBusy.
  ///
  /// In en, this message translates to:
  /// **'A microphone request is already open. Finish it before trying again.'**
  String get captureSpeechBusy;

  /// No description provided for @captureIncompleteAudio.
  ///
  /// In en, this message translates to:
  /// **'The retained audio is incomplete and cannot be processed. It is still kept on this phone.'**
  String get captureIncompleteAudio;

  /// No description provided for @captureWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t keep this on your phone. Try again before leaving.'**
  String get captureWriteFailed;

  /// No description provided for @captureStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish recording. Previously retained input is kept.'**
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
  /// **'Could not finish saving. Your words are kept; retry will not duplicate saved tasks.'**
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

  /// No description provided for @capturesEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Recordings and tasks you leave unfinished are kept here.'**
  String get capturesEmptyHelp;

  /// No description provided for @captureResumeHelp.
  ///
  /// In en, this message translates to:
  /// **'Kept on this phone · Tap to resume'**
  String get captureResumeHelp;

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
  /// **'Nothing will be added.'**
  String get captureRemovedDraftsHelp;

  /// No description provided for @captureFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get captureFinish;

  /// No description provided for @captureYourWords.
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

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn’t work. Your words are saved here — try again.'**
  String get captureFailed;

  /// No description provided for @captureSlow.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual.'**
  String get captureSlow;

  /// No description provided for @captureSaveAsWritten.
  ///
  /// In en, this message translates to:
  /// **'Save as written'**
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

  /// No description provided for @listEditingAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'The project owner manages editing access.'**
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
  /// **'View-only shared task. The project owner manages editing access.'**
  String get viewOnlyTask;

  /// No description provided for @stepUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this step. Please retry.'**
  String get stepUpdateError;

  /// No description provided for @checklistCompletionHelp.
  ///
  /// In en, this message translates to:
  /// **'Completing the checklist does not complete the task. Use Complete when you are finished.'**
  String get checklistCompletionHelp;

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

  /// No description provided for @billingSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Subscription, purchases and billing'**
  String get billingSettingsHelp;

  /// No description provided for @billingIntro.
  ///
  /// In en, this message translates to:
  /// **'Your subscription, in one place.'**
  String get billingIntro;

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
  /// **'{reason, select, unsupportedPlatform{Subscriptions are available in the Android and iOS app.} configuration{Subscriptions are not available yet. Please try again later.} accountUnavailable{Could not connect to your TaskFlow account. Check your connection and open this screen again.} network{Could not check your subscription. Check your connection and open this screen again.} notAllowed{Purchases are restricted for this store account or device.} otherAccount{This purchase belongs to another account. Sign in to the original account to restore it.} store{The store could not complete the request. Please try again.} other{Could not update your subscription. Please try again.}}'**
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

  /// No description provided for @authEnterRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your recovery email.'**
  String get authEnterRecoveryCode;

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

  /// No description provided for @audienceShared.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone in {name}'**
  String audienceShared(Object name);

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
  /// **'Invite people once, work together across projects.'**
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

  /// No description provided for @groupInviteHelp.
  ///
  /// In en, this message translates to:
  /// **'They will see every project in this group, including tasks, notes and files. We will send an email inviting them to review and join.'**
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

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

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

  /// No description provided for @updatesAssigned.
  ///
  /// In en, this message translates to:
  /// **'My assignments'**
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

  /// No description provided for @activityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated a task'**
  String get activityUpdated;

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

  /// No description provided for @activitySystem.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow'**
  String get activitySystem;

  /// Tooltip of the header button (people icon) that opens activity from shared projects and groups.
  ///
  /// In en, this message translates to:
  /// **'Group activity'**
  String get groupActivity;

  /// Spoken by TalkBack before an unread activity row.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get activityUnread;

  /// One activity row: who did what to which task. action is an internal code; actor is a person’s name; title is the task title.
  ///
  /// In en, this message translates to:
  /// **'{action, select, created{{actor} created: {title}} assigned{{actor} changed who’s responsible for: {title}} unassigned{{actor} removed the assignee of: {title}} completed{{actor} completed: {title}} reopened{{actor} reopened: {title}} deleted{{actor} deleted: {title}} shared{{actor} shared: {title}} other{{actor} updated: {title}}}'**
  String activityEntry(String action, String actor, String title);

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

  /// No description provided for @invitationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent by email. You can also share the code below.'**
  String get invitationEmailSent;

  /// No description provided for @invitationEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Your invitation is ready. Email delivery is pending and will retry automatically. You can share this code now.'**
  String get invitationEmailPending;

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

  /// No description provided for @stagingInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'This private test build is for invited testers. Ask the TaskFlow owner for an invitation to this email address.'**
  String get stagingInviteOnly;

  /// Under a spoken capture's result, for an account without Pro, only when 3 or fewer free dictations are left this month.
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

  /// Atop a task's attachments, for an account without Pro, only once its file space is 80% used or more; and on the Pro screen, for an account without Pro. Whole megabytes.
  ///
  /// In en, this message translates to:
  /// **'Files: {used} of {limit} MB used'**
  String storageUsage(int used, int limit);

  /// Under an attachment the server refused because the user's own free file space is full. Followed by the Explore Pro button. {limit} is the free cap in whole megabytes.
  ///
  /// In en, this message translates to:
  /// **'Your file space is full ({limit} MB). Remove files from other tasks to make room, or get Pro for unlimited space.'**
  String storageFull(int limit);

  /// Under an attachment the server refused because the file space of the shared project's owner is full.
  ///
  /// In en, this message translates to:
  /// **'This project’s file space is full. Its owner can remove files to make room.'**
  String get storageFullShared;

  /// Spoken label of the pin icon before a pinned project's name in Projects.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get projectPinned;

  /// Subtitle of a project shared directly with people (not through a group) in Projects. {role} is the user's role, such as Editor.
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

  /// A bullet under 'What stays for the others:' on the delete-account page, when tasks the person added to other people's shared projects stay after the account is deleted; the files they added there stay too. No final full stop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task and the files you added to shared projects, without your name} other{{count} tasks and the files you added to shared projects, without your name}}'**
  String deleteAccountKeptShared(int count);

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

  /// Under Delete my account when the server refuses more attempts for {minutes} minutes, rounded up, at least 1. After five wrong passwords it is 15 minutes, and signing in waits too.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many tries. Wait a minute and try again.} other{Too many tries. Wait {minutes} minutes and try again.}}'**
  String deleteAccountThrottledWait(int minutes);

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

  /// Brief message when the Google Play subscriptions page could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the page.'**
  String get deleteAccountLinkError;

  /// On the sign-in screen, right after the account was deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;
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
