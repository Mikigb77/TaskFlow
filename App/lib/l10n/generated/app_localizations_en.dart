// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get reviewSchedule => 'Date and time';

  @override
  String get reviewChooseDate => 'Choose a date before adding a time.';

  @override
  String get chooseAmPm => 'Choose AM or PM.';

  @override
  String get reviewInvalidTime => 'Check this value';

  @override
  String get reviewOptions => 'More options';

  @override
  String get reviewOriginal => 'See what I said';

  @override
  String get reviewOriginalText => 'Original text';

  @override
  String get reviewRemove => 'Remove from this capture';

  @override
  String get reviewRemoved => 'Draft removed';

  @override
  String get reviewUndoSaved => 'Tasks returned to your drafts.';

  @override
  String get reviewUndoChanged =>
      'This task has changed. Your saved tasks were kept.';

  @override
  String get reviewRepair => 'Repair text';

  @override
  String get reviewRepairHelp =>
      'This text may have been saved with damaged accents. Review the correction before saving.';

  @override
  String get reviewConfirmDetail => 'That’s right';

  @override
  String get reviewNoTime => 'No time';

  @override
  String get captureWhatTime => 'What time?';

  @override
  String get reviewEditDetail => 'Change this detail';

  @override
  String get reviewResolved => 'Reviewed';

  @override
  String get reviewResolve => 'Check this detail';

  @override
  String get languageNativeName => 'English';

  @override
  String sharingProblem(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'alreadyMember':
          'This person already has access. Manage their role in Members.',
      'memberLimit':
          'This project supports up to 20 members and 20 pending invitations. Remove someone or cancel an invitation first.',
      'accepted':
          'This invitation was already accepted. Manage the person’s access in Members.',
      'owner':
          'The owner cannot leave. You can delete the project if it is no longer needed.',
      'expired':
          'This invitation is no longer available. Ask the owner for a new one.',
      'code': 'Ask the project owner for the current invitation code.',
      'refresh': 'This project changed. Refresh before deleting it.',
      'ownerOnly':
          'Only the project owner can manage sharing and project details.',
      'other':
          'This project is read-only for your account. Ask the owner for editing access.',
    });
    return '$_temp0';
  }

  @override
  String syncProblem(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'assignmentChanged':
          'The responsible person changed. Your unsent edit was kept as a personal copy.',
      'listConflict':
          'A project changed on another device. Choose which version to keep in Projects.',
      'readOnly':
          'This project is now read-only. Your unsent edit was kept as a personal copy.',
      'accessChanged':
          'Shared-project access changed. Refresh to finish syncing permitted edits.',
      'taskConflict':
          'A task changed on another device. Your edit was kept as an offline copy; a conflicting deletion was cancelled.',
      'serverUpdate':
          'Update this server before syncing notes. Your notes are kept on this phone.',
      'other':
          'The server did not preserve this content type. Your local copy is kept.',
    });
    return '$_temp0';
  }

  @override
  String requestError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'signOutFirst': 'Sign out before changing servers.',
      'https': 'Use an HTTPS server address for this build.',
      'serverAddress':
          'Enter a valid server address, such as https://your-server.example.',
      'emailUsed':
          'An account with this email already exists. Sign in or recover your password.',
      'email': 'Enter a valid email address.',
      'credentials': 'We couldn’t find that account, or the password is wrong.',
      'session': 'Please sign in again to continue. Your local tasks are kept.',
      'accountChanged':
          'The account changed. Reopen this screen and try again.',
      'password':
          'Choose a password of 12–128 characters that is not common, entirely numeric or similar to your email.',
      'recoveryCode':
          'The recovery code is invalid or expired. Request a new one.',
      'forbidden':
          'This account cannot perform that action. Check your access.',
      'rateLimit':
          'Too many requests. Please wait a little before trying again.',
      'fileLimit': 'Choose a non-empty file up to 6 MiB.',
      'fileChanged':
          'The file has changed or could not be verified. Choose it again or retry the download.',
      'network': 'No connection. Check Wi-Fi or mobile data and try again.',
      'networkKept':
          'No connection. Check Wi-Fi or mobile data and try again. Your tasks are still saved on this phone.',
      'unavailable': 'The service is unavailable. Please try again later.',
      'validation':
          'Some details were not accepted. Review the information and try again.',
      'other': 'Could not complete the request. Please try again.',
      'otherKept':
          'Could not complete the request. Please try again. Your tasks are still saved on this phone.',
    });
    return '$_temp0';
  }

  @override
  String get languageAutomatic => 'Same as phone';

  @override
  String languageFollowing(String language) {
    return 'Same as phone · $language';
  }

  @override
  String get regionalFormats => 'Time & region';

  @override
  String get sharedCaptureRetained =>
      'Your shared capture is retained. Reopen TaskFlow to try again.';

  @override
  String get note => 'Note';

  @override
  String get editNote => 'Edit note';

  @override
  String get noteTitle => 'Note title';

  @override
  String get noteBody => 'Your note';

  @override
  String get notesHelp =>
      'Keep information, ideas and reference material. Use a task for something you need to do.';

  @override
  String get notesEmpty => 'A place for your thoughts';

  @override
  String get notesEmptyHelp =>
      'Write or dictate a note. Add links or a checklist when useful.';

  @override
  String get findNote => 'Search notes';

  @override
  String get saveNote => 'Save note';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get addNote => 'Add a note';

  @override
  String get noteHint => 'Ideas, meeting details, useful links…';

  @override
  String get noteTitleHint => 'e.g. Wi-Fi password';

  @override
  String get noteTitleRequired => 'Give your note a title';

  @override
  String get noteNoMatches => 'No matching notes';

  @override
  String get notesSavedOnDevice => 'Your notes are still on this phone.';

  @override
  String get allNotes => 'All notes';

  @override
  String get viewOnlyNote =>
      'View-only note. The project owner manages editing access.';

  @override
  String get linkOpenError =>
      'Could not open this link. You can copy it from the note.';

  @override
  String get noteLinks => 'Links';

  @override
  String get plannedFor => 'Planned for';

  @override
  String get plannedForHelp =>
      'When you intend to do this task. A deadline can be set separately in More details.';

  @override
  String get planning => 'Duration & deadline';

  @override
  String get duration => 'Duration';

  @override
  String get durationUnset => 'No duration set';

  @override
  String get durationEstimateHelp =>
      'An estimate until you choose a planned start time.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get durationInput => 'Minutes (1–1440)';

  @override
  String get durationInvalid => 'Enter a whole number from 1 to 1440.';

  @override
  String get removeDuration => 'Remove duration';

  @override
  String get deadline => 'Deadline';

  @override
  String get deadlineUnset => 'No deadline';

  @override
  String get deadlineHelp =>
      'Must be finished by this date. Moving the planned start keeps this deadline.';

  @override
  String get deadlineTime => 'Deadline time';

  @override
  String get deadlineEndDay => 'By the end of the day';

  @override
  String get removeDeadline => 'Remove deadline';

  @override
  String get deadlineRecurringHelp =>
      'This deadline repeats with each original occurrence. Moving one planned occurrence keeps its deadline; changing the series start keeps the first deadline and changes the gap for later ones.';

  @override
  String get deadlineLatePlan =>
      'This plan finishes after the deadline. Check the start or duration.';

  @override
  String get deadlineOverdue => 'Deadline passed';

  @override
  String deadlineLabel(String date) {
    return 'Due $date';
  }

  @override
  String get reminderAnchor => 'Remind me relative to';

  @override
  String get reminderAnchorHelp =>
      'One reminder per occurrence, using the date selected here.';

  @override
  String get dayTimeline => 'Day timeline';

  @override
  String get timelineFirstPlan => 'Jump to first timed item';

  @override
  String get timelineLimit =>
      'Showing the first 200 timed items. Use the agenda to see every task.';

  @override
  String get timelineHelp =>
      'Planned work and phone events. Deadlines mark when something must be finished.';

  @override
  String get timelineUnblocked => 'Without a time block';

  @override
  String get timelineNoBlocks =>
      'No timed plans for this day. Add a start time and duration to reserve a block.';

  @override
  String get timelinePoint => 'No duration · time only';

  @override
  String get timelineShortBlocks =>
      'Short events have larger tap targets; the accent bar shows their actual duration.';

  @override
  String timelineHours(int hours) {
    return '$hours hours in this day';
  }

  @override
  String get deviceCalendars => 'Phone calendars';

  @override
  String get deviceCalendarHelp =>
      'See events from calendars connected to this phone beside your tasks.';

  @override
  String get deviceCalendarPrivacy =>
      'Choose which calendars to display. Events are read-only in TaskFlow and stay on this device; they are not uploaded or sent to AI. Manage their reminders in your calendar app.';

  @override
  String get calendarEnable => 'Connect phone calendars';

  @override
  String get calendarDisable => 'Hide calendar events';

  @override
  String get calendarChoose => 'Choose calendars';

  @override
  String get calendarChooseHelp =>
      'Select up to 50 calendars. Calendar times follow your device; all-day dates stay on their original days.';

  @override
  String get calendarDenied =>
      'Allow calendar access to display your events. Your tasks still work without it.';

  @override
  String get calendarBlocked =>
      'Calendar access is off. You can enable it in the phone’s app settings.';

  @override
  String get calendarUnsupported =>
      'Phone calendar display is currently available on Android.';

  @override
  String get calendarSettings => 'Open app settings';

  @override
  String get calendarEmptySources =>
      'No visible calendars are synced to this phone. Connect an account in your calendar app, then refresh here.';

  @override
  String get calendarRefresh => 'Refresh calendars';

  @override
  String get calendarClear => 'Clear selection';

  @override
  String get calendarReadError =>
      'Calendar events could not be read. Refresh to try again; this view may be missing commitments.';

  @override
  String get calendarReadRetry =>
      'Couldn’t read your events. Tap to try again.';

  @override
  String get changeView => 'Change view';

  @override
  String get calendarPreferenceError =>
      'Could not save that calendar choice. Try again. You can select up to 50 calendars.';

  @override
  String get calendarTruncated =>
      'This calendar result is too large to show in full. Select fewer calendars to see the remaining events.';

  @override
  String get calendarEvents => 'Calendar events';

  @override
  String get calendarReadOnly => 'Calendar event · view only';

  @override
  String get calendarNoSelection =>
      'Choose calendars to show your existing commitments.';

  @override
  String get calendarAllDay => 'All day';

  @override
  String calendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get calendarOffline => 'Offline — your tasks are saved on this phone.';

  @override
  String get calendarUntitled => 'Untitled event';

  @override
  String get calendarOpenEvent => 'Open in calendar app';

  @override
  String get calendarOpenError => 'The calendar app could not open this event.';

  @override
  String get calendarEventGone =>
      'This event is no longer available in the selected calendars.';

  @override
  String get noScheduledTasks => 'No TaskFlow tasks scheduled';

  @override
  String get calendar => 'Calendar';

  @override
  String get tasks => 'Tasks';

  @override
  String get settings => 'Settings';

  @override
  String get inbox => 'Inbox';

  @override
  String inboxCount(int count) {
    return 'Inbox · $count';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get all => 'All';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get noDate => 'No date';

  @override
  String get anyTime => 'Any time';

  @override
  String get addTime => 'Add time';

  @override
  String get removeDate => 'Remove date';

  @override
  String get editTask => 'Edit task';

  @override
  String get taskDetails => 'Task details';

  @override
  String get addTask => 'Add a task';

  @override
  String get typeTasks => 'Type tasks';

  @override
  String get unfinishedCaptures => 'Unfinished captures';

  @override
  String get captureDiagnostics => 'Capture diagnostics';

  @override
  String get lists => 'Projects';

  @override
  String get labels => 'Labels';

  @override
  String get noList => 'Personal inbox';

  @override
  String get priority => 'Priority';

  @override
  String get low => 'Low';

  @override
  String get medium => 'Medium';

  @override
  String get high => 'High';

  @override
  String get schedule => 'Schedule';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get repeat => 'Repeat';

  @override
  String get neverRepeat => 'Does not repeat';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get noEndDate => 'No end date';

  @override
  String get notes => 'Notes';

  @override
  String get addNotes => 'Add notes';

  @override
  String get attachments => 'Attachments';

  @override
  String get checklist => 'Checklist';

  @override
  String get complete => 'Complete';

  @override
  String get reopen => 'Reopen';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get undo => 'Undo';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get keepChanges => 'Keep changes';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get taskTitle => 'Task title';

  @override
  String get additionalNotes => 'Additional Notes';

  @override
  String get moreDetails => 'More details';

  @override
  String get fewerDetails => 'Fewer details';

  @override
  String get appearance => 'Appearance';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get reminders => 'Reminders';

  @override
  String remindersOnLead(String lead) {
    return 'On · $lead';
  }

  @override
  String get remindersOff => 'Off';

  @override
  String get remindersBlocked => 'Blocked by your phone';

  @override
  String get otherSettings => 'Other settings';

  @override
  String appVersion(String version) {
    return 'TaskFlow $version';
  }

  @override
  String get completedTasks => 'Completed tasks';

  @override
  String get exportImport => 'Export & import';

  @override
  String get language => 'Language';

  @override
  String get deviceDefault => 'Same as phone';

  @override
  String get clockFormat => 'Time format';

  @override
  String get clock12 => '12-hour clock';

  @override
  String get clock24 => '24-hour clock';

  @override
  String get weekStart => 'First day of the week';

  @override
  String get monday => 'Monday';

  @override
  String get sunday => 'Sunday';

  @override
  String get saturday => 'Saturday';

  @override
  String get timeZone => 'Time zone';

  @override
  String get timezoneHelp => 'New tasks use this time zone to read dates.';

  @override
  String get searchTimezone => 'Find a timezone';

  @override
  String get regionHelp =>
      'These preferences stay on this device. Changing them does not change stored task dates or times.';

  @override
  String get preferenceError =>
      'Could not save this preference. Please try again.';

  @override
  String timezoneFallback(String zone) {
    return 'The device timezone is unavailable. New tasks will use $zone.';
  }

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get day => 'Day';

  @override
  String get previousPeriod => 'Previous month or week';

  @override
  String get nextPeriod => 'Next month or week';

  @override
  String get licenses => 'Open-source licences';

  @override
  String get todayAgenda => 'Today’s agenda';

  @override
  String get breathingRoom => 'A little breathing room.';

  @override
  String get loadTasksError => 'Couldn’t load your tasks';

  @override
  String get refreshCalendar => 'Try refreshing your calendar.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get rememberPrompt => 'What would you like to remember?';

  @override
  String get calendarEmpty => 'Nothing planned for this day.';

  @override
  String get planTask => 'Plan a task';

  @override
  String get homeCapture => 'Mic button on your home screen';

  @override
  String get homeCaptureInstructions =>
      'On Android, long-press the TaskFlow icon for capture shortcuts, or add the Say a task widget from your launcher. Share text to TaskFlow from another app.';

  @override
  String get widgetPickerHelp =>
      'Add the TaskFlow widget from your launcher’s widget picker.';

  @override
  String get appearanceError => 'Could not save your appearance preference.';

  @override
  String get list => 'Project';

  @override
  String get archivedList => 'Archived project';

  @override
  String get yourList => 'Your project';

  @override
  String get yourTasks => 'Your tasks';

  @override
  String get everythingToDo => 'Everything you want to do';

  @override
  String get noDateNeeded => 'No date needed';

  @override
  String get findTask => 'Find a task…';

  @override
  String get allTasks => 'All tasks';

  @override
  String get highPriority => 'High priority';

  @override
  String get filterLabel => 'Filter by label';

  @override
  String get allLabels => 'All labels';

  @override
  String get noMatches => 'No matching tasks';

  @override
  String get freshStart => 'A fresh start';

  @override
  String get differentFilter => 'Try a different word or filter.';

  @override
  String get listEmpty =>
      'Add a task to this project. Its date and reminder are yours to choose.';

  @override
  String get tasksEmpty => 'Tap Add a task to add one. A date is optional.';

  @override
  String get inboxEmpty =>
      'Keep ideas and to-dos here until you choose a date.\nStart with Add a task.';

  @override
  String get savedOnDevice => 'Your saved tasks are still on your device.';

  @override
  String get checkCaptures => 'Check unfinished captures';

  @override
  String get fineTunePlan => 'Fine-tune your plan.';

  @override
  String get seriesEdits => 'Edits apply to the whole repeating task.';

  @override
  String get giveName => 'Give it a name. Add a date whenever you’re ready.';

  @override
  String get checkBeforeAdd =>
      'Check the details before adding it to your calendar.';

  @override
  String get titleRequired => 'Please enter a task title.';

  @override
  String get nameTask => 'What would you like to do?';

  @override
  String get reminder => 'Reminder';

  @override
  String get off => 'Off';

  @override
  String get dateForReminder => 'Add a date to use a reminder';

  @override
  String get chooseAlertTime => 'Choose alert time';

  @override
  String get reminderDefaultsError =>
      'Reminder defaults could not load. Check notification settings.';

  @override
  String get loadingReminders => 'Loading reminder settings…';

  @override
  String get repeatInterval => 'Repeat interval';

  @override
  String get repeatOn => 'Repeat on';

  @override
  String get repeatUsesStart => 'Uses the weekday of the start date.';

  @override
  String get intervalRange => 'Choose a number from 1 to 99.';

  @override
  String get removeEndDate => 'Remove end date';

  @override
  String get days => 'days';

  @override
  String get weeks => 'weeks';

  @override
  String get months => 'months';

  @override
  String get years => 'years';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get keepTask => 'Keep task';

  @override
  String get deleteTaskError => 'Could not delete this task. Please try again.';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get attachmentUnavailable =>
      'This attachment is not available on this device.';

  @override
  String get attachmentOpenError => 'Could not open this attachment.';

  @override
  String get taskUnavailable => 'Task unavailable';

  @override
  String get occurrenceChanged => 'Occurrence changed';

  @override
  String get taskRemoved => 'This task may have been removed.';

  @override
  String get occurrenceSkipped =>
      'This date is skipped or no longer part of the repeating schedule.';

  @override
  String get editRepeating => 'Edit repeating task';

  @override
  String get moveError => 'Could not move this task. Please retry.';

  @override
  String get occurrence => 'Occurrence';

  @override
  String get starts => 'Starts';

  @override
  String get inboxDate => 'No date · Inbox';

  @override
  String get updateReminderError =>
      'Could not update the reminder. Please retry.';

  @override
  String get thisOccurrence => 'This occurrence';

  @override
  String get wholeSeries => 'Whole series';

  @override
  String get skipOccurrence => 'Skip this occurrence';

  @override
  String get resetOccurrence => 'Reset this occurrence';

  @override
  String get reset => 'Reset';

  @override
  String get recordingKept => 'Recording kept on this phone';

  @override
  String get onDeviceTranscript => 'On this phone, as you speak';

  @override
  String get onlineAudio => 'Online, after you finish';

  @override
  String get speechMethod => 'How speech becomes text';

  @override
  String get speechLanguage => 'Speech language';

  @override
  String get voiceSettings => 'Voice';

  @override
  String get sameAsApp => 'Same as the app';

  @override
  String get onDeviceUnavailable =>
      'This phone can’t do this language by itself, so TaskFlow does it online.';

  @override
  String get setUpSpeech => 'Set up on-device speech';

  @override
  String get checkAgain => 'Check again';

  @override
  String get examplePlan =>
      'Doctor Friday at 5 p.m. Bring my results. Also buy coffee.';

  @override
  String get exampleTask => 'Doctor Friday at 5 p.m.';

  @override
  String get discard => 'Discard';

  @override
  String get keep => 'Keep';

  @override
  String get capturePrivacy =>
      'Live transcription uses on-device speech where available; no audio is retained in that mode. AI task extraction still needs the internet and sends your words to Google. Saved audio is transcribed online. Unfinished input stays on this phone until you save or discard it.';

  @override
  String get capturePrivacyLine => 'Your words go online. More in Settings.';

  @override
  String get lookRight => 'Look right?';

  @override
  String get finalSay => 'Tap a detail to change it. You have the final say.';

  @override
  String get changePriority => 'Change priority';

  @override
  String get changeRepeat => 'Change repeat';

  @override
  String get confirmedDetails => 'I’ve checked this task';

  @override
  String agendaCounts(int remaining, int done) {
    return '$remaining to do · $done completed';
  }

  @override
  String overdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue · $count',
    );
    return '$_temp0';
  }

  @override
  String pendingCaptureCount(int count) {
    return 'Unfinished captures · $count';
  }

  @override
  String listeningSeconds(String time) {
    return 'Listening · $time';
  }

  @override
  String repeatEvery(int interval, String unit) {
    return 'Every $interval $unit';
  }

  @override
  String repeatEveryPrompt(String unit) {
    return 'Repeat every… $unit';
  }

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String priorityValue(String priority) {
    return '$priority priority';
  }

  @override
  String get pickDate => 'Pick a date';

  @override
  String get addStepDialog => 'Add a step';

  @override
  String get editStep => 'Edit step';

  @override
  String get step => 'Step';

  @override
  String get shortStep => 'Add a short step.';

  @override
  String get keepStep => 'Keep step';

  @override
  String get repeatingSteps =>
      'These steps repeat with the task. Check them off from an occurrence’s details.';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get removeStep => 'Remove step';

  @override
  String get addChecklist => 'Add checklist';

  @override
  String get addStep => 'Add step';

  @override
  String get listUnavailable => 'Project unavailable';

  @override
  String get archived => 'Archived';

  @override
  String get sharedProject => 'Shared';

  @override
  String get taskReopened => 'Task reopened';

  @override
  String get taskCompleted => 'Task completed';

  @override
  String get undoError => 'Could not undo. Please try again.';

  @override
  String get taskUpdateError => 'Could not update this task. Please try again.';

  @override
  String get occurrenceSkippedNotice => 'Occurrence skipped';

  @override
  String get originalRestored => 'Original date restored';

  @override
  String get movedInbox => 'Moved to Inbox';

  @override
  String get scheduleChangedAgain =>
      'The schedule changed again. Open the task to review it.';

  @override
  String get scheduleError =>
      'Could not change the schedule. Please try again.';

  @override
  String get rescheduleRepeating => 'Reschedule repeating task';

  @override
  String get rescheduleTask => 'Reschedule task';

  @override
  String get seriesRescheduleHelp =>
      'Changes the start of the series and resets moved or skipped dates. No date stops the repeat.';

  @override
  String get occurrenceRescheduleHelp =>
      'Other dates in the series stay the same.';

  @override
  String get restoreOriginal => 'Restore original date';

  @override
  String get progressSmall => 'Progress starts small';

  @override
  String get completedEmpty => 'Every task you finish will find a home here.';

  @override
  String get progressHeading => 'Look how far you’ve come.';

  @override
  String get completedLoadError => 'Couldn’t load completed tasks';

  @override
  String get tryLater => 'Please try again in a moment.';

  @override
  String get changeSeriesQuestion => 'Change the repeating schedule?';

  @override
  String get changeSeriesHelp =>
      'This resets individual moved or skipped dates to the new schedule. Your completed dates remain in history.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get resetSave => 'Reset and save';

  @override
  String get taskSavedInbox => 'Task saved to Inbox';

  @override
  String taskAddedOn(String date) {
    return 'Added to $date';
  }

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get taskSaveError => 'Could not save your task. Please try again.';

  @override
  String get localAttachmentHelp =>
      'Attachments currently stay on this phone. Signing in restores your tasks, but these files will not appear on another device.';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get attachFile => 'Attach a file';

  @override
  String get attachError => 'Could not attach that file. Please try again.';

  @override
  String get titleRequiredField => 'Please enter a task title';

  @override
  String get fromYourWords => 'From your words';

  @override
  String get keepAsTyped => 'Keep as typed';

  @override
  String get clearDate => 'Clear date';

  @override
  String get optionalTime => 'Time (optional)';

  @override
  String get resetDateHelp => 'Reset a date, then save your changes.';

  @override
  String get skipped => 'Skipped';

  @override
  String get theDetails => 'The details';

  @override
  String get labelLimit => 'Use up to 10 labels, each under 33 characters.';

  @override
  String get notesHint => 'Anything you’d like to remember…';

  @override
  String get addAttachment => 'Add attachment';

  @override
  String get localAttachments => 'Attachments stay on this device.';

  @override
  String get saving => 'Saving…';

  @override
  String get saveChangesSentence => 'Save changes';

  @override
  String checklistCount(int done, int total) {
    return 'Checklist · $done/$total';
  }

  @override
  String checklistSemantics(int done, int total) {
    return 'Checklist, $done of $total steps completed';
  }

  @override
  String get useDefault => 'Use default';

  @override
  String get atScheduledTime => 'At the scheduled time';

  @override
  String get hourBefore => '1 hour before';

  @override
  String get dayBefore => '1 day before';

  @override
  String get defaultChoice => 'default';

  @override
  String minutesBefore(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String reminderValue(String value) {
    return 'Reminder: $value';
  }

  @override
  String get fileLocal => 'Only on this device';

  @override
  String get fileQueued => 'Upload queued';

  @override
  String get fileBackedUp => 'Backed up to your account';

  @override
  String get fileDownloadAvailable => 'Available to download';

  @override
  String get fileMissing => 'File unavailable on this device';

  @override
  String get fileRemovalPending => 'Removal pending';

  @override
  String get fileUpload => 'Upload';

  @override
  String get fileDownload => 'Download';

  @override
  String get fileOpen => 'Open';

  @override
  String get fileRetry => 'Retry transfer';

  @override
  String get fileRemove => 'Remove attachment';

  @override
  String get fileRemoveQuestion => 'Remove this attachment?';

  @override
  String get fileRemoveHelp =>
      'This removes it from the task and, if uploaded, your other devices when they sync. Your original file is not deleted.';

  @override
  String get yourAccount => 'Your account';

  @override
  String get accountHeading => 'Your own little space.';

  @override
  String get backupHeading => 'Your plans, kept close.';

  @override
  String get accountBackupHelp =>
      'Tasks and notes are saved on this phone and backed up when connected. New attachments upload after saving; check their status in item details. Older device-only files need an explicit Upload.';

  @override
  String get accountUpToDate => 'Your tasks and notes are up to date.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get importLocalItems => 'Import local tasks and notes';

  @override
  String get importLocalItemsQuestion => 'Import local tasks and notes?';

  @override
  String importLocalItemsHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count items from this phone into your account',
      one: 'Move 1 item from this phone into your account',
    );
    return '$_temp0 to back up your tasks and notes. Attachments stay on this phone until you choose Upload in item details.';
  }

  @override
  String get importItems => 'Import';

  @override
  String get noLocalItems => 'There are no local tasks or notes to import.';

  @override
  String itemsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items imported.',
      one: '1 item imported.',
    );
    return '$_temp0';
  }

  @override
  String get connectionDetails => 'Connection details';

  @override
  String get signOut => 'Sign out';

  @override
  String get recoveryHeading => 'Reset your password';

  @override
  String get registerHeading => 'Create your account';

  @override
  String get signInHeading => 'Sign in';

  @override
  String get authPitch =>
      'Note down what you need to do, and TaskFlow puts it on your calendar.';

  @override
  String get recoveryHelp =>
      'Request a recovery email, then use the code to set a new password.';

  @override
  String get email => 'Email';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get recoveryCode => 'Recovery code';

  @override
  String get recoveryCodeHelp => 'Leave empty to request an email.';

  @override
  String get newPassword => 'New password';

  @override
  String get password => 'Password';

  @override
  String get passwordHelp => 'At least 12 characters, not only numbers';

  @override
  String get passwordTooShort => 'Use at least 12 characters';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get createAccount => 'Create account';

  @override
  String get signIn => 'Sign in';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get createAccountWithEmail => 'Create an account with this email';

  @override
  String get signInWithEmail => 'Sign in with this email';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get sendRecoveryCode => 'Send code';

  @override
  String get saveNewPassword => 'Save new password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get accountGuestHelp => 'Sign in to access your tasks and notes.';

  @override
  String get connectionSettings => 'Connection settings';

  @override
  String get backendAddress => 'Backend address';

  @override
  String get backendAddressHelp =>
      'Emulator: http://10.0.2.2:8088\nPhone: your computer’s LAN IP on the same Wi-Fi.';

  @override
  String get recoveryEmailRequested =>
      'If that account exists, a recovery email has been sent.';

  @override
  String get passwordResetComplete =>
      'Password updated. Sign in with your new password.';

  @override
  String get newList => 'New project';

  @override
  String get editList => 'Edit project';

  @override
  String get listName => 'Name';

  @override
  String get listNameHint => 'Work, Personal, Shopping…';

  @override
  String get listNameRequired => 'Name your project.';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorRose => 'Rose';

  @override
  String get saveList => 'Save project';

  @override
  String get listSaveError => 'Could not save this project. Please retry.';

  @override
  String get listRestored => 'Project restored';

  @override
  String projectArchivedNoReminders(String name) {
    return '$name archived — hidden from your calendar, no reminders.';
  }

  @override
  String get listUpdateError => 'Could not update this project. Please retry.';

  @override
  String get chooseListDetails => 'Choose project details';

  @override
  String listConflictHelp(String local, String remote) {
    return 'This phone: $local\n\nOther device: $remote\n\nTask and note contents will stay the same.';
  }

  @override
  String get later => 'Later';

  @override
  String get useOtherDevice => 'Use other device';

  @override
  String get useThisPhone => 'Use this phone';

  @override
  String get listResolveError =>
      'Could not resolve this project. Please retry.';

  @override
  String get retryLists => 'Retry projects';

  @override
  String get refreshLists => 'Refresh projects and invitations';

  @override
  String get listsHelp =>
      'A clear place for every part of life. Keep projects personal or share them with a group.';

  @override
  String get listsEmptyTitle => 'A place for each part of life';

  @override
  String get listsEmptyHelp =>
      'Start with Work, Personal or Shopping. Tasks can move whenever you like.';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Viewer';

  @override
  String sharedListRole(String role) {
    return '$role · shared';
  }

  @override
  String get listConflict => 'Changed on another device · choose details';

  @override
  String get archivedListHelp => 'Archived · tasks and notes still available';

  @override
  String listItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks and notes',
      one: '1 task or note',
      zero: 'No tasks or notes',
    );
    return '$_temp0';
  }

  @override
  String manageItem(String name) {
    return 'Manage $name';
  }

  @override
  String get restoreList => 'Restore project';

  @override
  String get archiveList => 'Archive project';

  @override
  String get chooseDetails => 'Choose details';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get invitationCodeHelp =>
      'This code and the invited TaskFlow account are both needed to join. Share it only with the intended person. Replacing an invitation invalidates its previous code.';

  @override
  String get accountChanged => 'The account changed.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get done => 'Done';

  @override
  String get sharingUpdateError =>
      'Could not update sharing. Check the connection and retry.';

  @override
  String get shareProject => 'Share';

  @override
  String projectMembersCount(int count) {
    return 'Members · $count';
  }

  @override
  String shareProjectTitle(String project) {
    return 'Share $project';
  }

  @override
  String get theirEmail => 'Their email';

  @override
  String shareProjectHelp(String project) {
    return 'They’ll see everything in $project.';
  }

  @override
  String get sendInvitation => 'Send invitation';

  @override
  String get invitationSent => 'Invitation sent';

  @override
  String get invitationCodeFallback =>
      'If the email doesn’t arrive, send them this code:';

  @override
  String get connectToShare => 'Connect to the internet to share.';

  @override
  String get sendInvitationAgain => 'Send again';

  @override
  String get cancelInvitation => 'Cancel invitation';

  @override
  String get inviteeEmail => 'Their account email';

  @override
  String get enterEmailAddress => 'Enter an email address.';

  @override
  String get access => 'Access';

  @override
  String get sharingRolesHelp =>
      'Editors can add, change, complete and delete tasks and files. Only the owner manages the project and people. Shared tasks stay in this project; exporting creates a personal copy.';

  @override
  String get listSharing => 'Project sharing';

  @override
  String get sharingLoadError => 'Could not load sharing.';

  @override
  String get retry => 'Retry';

  @override
  String yourRole(String role) {
    return 'Your role: $role';
  }

  @override
  String get sharingHelp =>
      'Share shopping and chores. Changes sync when the app connects or you refresh.';

  @override
  String get invitePerson => 'Invite a person';

  @override
  String get people => 'Members';

  @override
  String get noOtherMembers => 'Only you have accepted access so far.';

  @override
  String get makeEditor => 'Make editor';

  @override
  String get makeViewer => 'Make viewer';

  @override
  String get removeAccess => 'Remove access';

  @override
  String get removeAccessHelp =>
      'This person will lose access to this project and its tasks, notes and files. Their unsent shared edits will be removed on the next successful sync.';

  @override
  String get pendingInvitations => 'Pending invitations';

  @override
  String pendingRole(String role) {
    return '$role · pending';
  }

  @override
  String get revokeInvitation => 'Revoke invitation';

  @override
  String get howSharingWorks => 'How sharing works';

  @override
  String get sharedDataHelp =>
      'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Task reminder choices are shared, but each phone must enable its own notifications.';

  @override
  String get sharingRemovalHelp =>
      'Leaving or losing access removes this phone’s shared tasks, notes, pending edits and downloaded copies at the next successful sync. Offline devices and copies already exported cannot be remotely erased.';

  @override
  String get deleteList => 'Delete project';

  @override
  String get deleteListHelp =>
      'Delete this project and all its tasks, notes and uploaded files for everyone? This cannot be undone.';

  @override
  String deleteListPrivateHelp(String name) {
    return 'Delete $name with all its tasks, notes and files? This can’t be undone.';
  }

  @override
  String get deleteListForEveryone => 'Delete project for everyone';

  @override
  String get leaveList => 'Leave project';

  @override
  String get leaveListHelp =>
      'Shared tasks, notes, files and any unsent edits will be removed from this phone. Other members keep the project.';

  @override
  String youLeft(String name) {
    return 'You left $name';
  }

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get invitationCodeRequired => 'Paste the full invitation code.';

  @override
  String get invitationCodeWrong =>
      'Ask the person who invited you for the current code.';

  @override
  String get invitationResponseError =>
      'Could not respond. Retry when connected.';

  @override
  String get retryInvitations => 'Retry invitations';

  @override
  String get acceptInvitation => 'Accept invitation';

  @override
  String get decline => 'Decline';

  @override
  String invitedTo(String name) {
    return 'You’re invited to $name · View';
  }

  @override
  String invitedByTo(String sender, String name) {
    return '$sender invited you to “$name” · View';
  }

  @override
  String invitationsMore(int count) {
    return '+$count';
  }

  @override
  String joinInvitationTitle(String name) {
    return 'Join $name';
  }

  @override
  String get joinInvitationHelp =>
      'Open your invitation email and tap its link. Or paste the code from it here.';

  @override
  String get joinInvitation => 'Join';

  @override
  String declineInvitationConfirm(String name) {
    return 'Decline the invitation to $name? You’d need a new one to join later.';
  }

  @override
  String joinedInvitation(String name) {
    return 'You joined $name';
  }

  @override
  String get invitationNotNow => 'Not now';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get fileLoadError => 'Could not load attachment status. Please retry.';

  @override
  String get fileActionError =>
      'Could not complete this action. Your task is saved; please retry.';

  @override
  String get fileSignInHelp =>
      'Sign in to upload your files and restore them on another device.';

  @override
  String get fileUploadHelp =>
      'New files upload to your account after saving: up to 6 MiB each, 64 MiB per account. Older local files stay on this device until you choose Upload in task details.';

  @override
  String get fileLocalHelp =>
      'Files stay on this device until you sign in and choose Upload in task details. Up to 6 MiB per file.';

  @override
  String get fileLimit =>
      'Choose a non-empty file up to 6 MiB. You can attach up to 20 files per task.';

  @override
  String get fileManageHelp =>
      'Open task details to download, upload, or remove account attachments.';

  @override
  String get notificationLoadError =>
      'Could not load notification settings. Please retry.';

  @override
  String get notificationSaveError =>
      'Could not save reminder settings. Please retry.';

  @override
  String get enableReminders => 'Enable reminders';

  @override
  String get noReminderTurnOn => 'No reminder · Turn on';

  @override
  String get exactAlarmsNeeded =>
      'To get reminders on time, allow “Alarms & reminders”.';

  @override
  String get remindersOnConfirmation => 'Done. Reminders are on.';

  @override
  String get reminderAskQuestion => 'Want a reminder before it?';

  @override
  String get reminderAskYes => 'Yes, remind me';

  @override
  String get reminderAskNotNow => 'Not now';

  @override
  String get details => 'Details';

  @override
  String get mobileNotificationsOnly => 'Mobile notifications only';

  @override
  String get notificationPermissionOff => 'System permission is off';

  @override
  String get preciseAlarmsAvailable => 'Precise alarm access available';

  @override
  String get approximateAlarmsHelp =>
      'Alerts are approximate until precise alarm access is enabled';

  @override
  String get openSystemSettings => 'Open system settings';

  @override
  String get allowPreciseAlarms => 'Allow “Alarms & reminders”';

  @override
  String get taskDefaults => 'Task defaults';

  @override
  String get timedTasks => 'Timed tasks';

  @override
  String get dateOnlyTasks => 'Date-only tasks';

  @override
  String get dailyCheckIns => 'Daily check-ins';

  @override
  String get dailyCheckInsHelp =>
      'A gentle prompt to review your current tasks.';

  @override
  String get morningCheckIn => 'Morning';

  @override
  String get eveningCheckIn => 'Evening';

  @override
  String get upcomingAlerts => 'Upcoming alerts';

  @override
  String get scheduledAlertHelp =>
      'Scheduled means your phone accepted the alert. Battery restrictions, system settings and force-stop can delay or prevent delivery.';

  @override
  String get androidAlertRefreshHelp =>
      'The window refreshes on app use and through an hourly background job when Android permits.';

  @override
  String get backgroundAlertRefreshHelp =>
      'The window refreshes on app use and when the system allows background refresh.';

  @override
  String get noUpcomingAlerts =>
      'No upcoming alerts. Choose a reminder on a scheduled task.';

  @override
  String get repeatsDaily => 'repeats daily';

  @override
  String get retryScheduling => 'Refresh and retry scheduling';

  @override
  String get alertPending => 'pending';

  @override
  String get alertScheduled => 'scheduled';

  @override
  String get alertApproximate => 'approximate';

  @override
  String get alertBlocked => 'blocked';

  @override
  String get alertFailed => 'failed';

  @override
  String get alertInactive => 'inactive';

  @override
  String get alertElapsed => 'elapsed';

  @override
  String get reminderPermissionError =>
      'Notifications are disabled in system settings.';

  @override
  String get reminderScheduleError =>
      'The phone could not schedule this alert. Retry from Settings.';

  @override
  String get reminderBackgroundError =>
      'Background refresh could not finish. Open TaskFlow to retry.';

  @override
  String get reminderBackgroundUnavailable =>
      'Automatic background refresh is unavailable. Alerts refresh when you open TaskFlow.';

  @override
  String get reminderActionError =>
      'A notification action could not finish. Open the task to retry.';

  @override
  String get reminderSetupError =>
      'Notification setup could not finish. Retry from Settings.';

  @override
  String get reminderAccountError =>
      'Account reminders could not refresh. Open notification settings to retry.';

  @override
  String get reminderRefreshError =>
      'Reminders could not refresh. Your tasks are saved; retry from notification settings.';

  @override
  String get transferError =>
      'Could not finish. Your existing tasks and notes are unchanged. Please retry.';

  @override
  String get exportSaved => 'Export saved. Keep the file somewhere private.';

  @override
  String get keepYourTasks => 'Keep your tasks with you.';

  @override
  String get archiveContentsHelp =>
      'TaskFlow exports include tasks, notes, schedules, recurring date changes, completion, checklists, labels and personal projects. Attachment names are listed; file contents, account credentials, device preferences and unfinished captures are excluded.';

  @override
  String get exportTaskFlowFile => 'Export TaskFlow file';

  @override
  String get chooseImportFile => 'Choose import file';

  @override
  String get chooseImportFileHelp =>
      'Choose a TaskFlow JSON export or Todoist project CSV (up to 32 MB / 5,000 tasks and notes). You will review it before importing.';

  @override
  String get importPreview => 'Import preview';

  @override
  String get importCopiesHelp =>
      'Selected tasks, notes and the file’s projects are added as personal copies. Existing content is kept. Re-importing this same file skips records already imported on this phone; a changed or newly exported file counts as a different import.';

  @override
  String get listsIncluded => 'Projects included';

  @override
  String get archivedPersonalCopy => 'Archived personal copy';

  @override
  String get personalCopy => 'Personal copy';

  @override
  String get alreadyImported => 'Already imported on this phone';

  @override
  String get taskFlowExportSource => 'TaskFlow export';

  @override
  String get todoistCsvSource => 'Todoist project CSV';

  @override
  String deferredAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count later alerts are',
      one: '1 later alert is',
    );
    return '$_temp0 outside the current window. The next refresh adds the earliest ones that fit.';
  }

  @override
  String turnOffReminder(String title) {
    return 'Turn off $title';
  }

  @override
  String importResult(int items, int lists) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items items',
      one: '1 item',
    );
    String _temp1 = intl.Intl.pluralLogic(
      lists,
      locale: localeName,
      other: '$lists projects',
      one: '1 project',
    );
    return 'Added $_temp0 and $_temp1.';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already imported items',
      one: '1 already imported item',
    );
    return 'Skipped $_temp0.';
  }

  @override
  String importCounts(String source, int tasks, int notes, int lists) {
    return '$source · $tasks tasks · $notes notes · $lists projects';
  }

  @override
  String cannotImport(String reason) {
    return 'Cannot import: $reason';
  }

  @override
  String importSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected items',
      one: '1 selected item',
    );
    return 'Import $_temp0 and projects';
  }

  @override
  String importRow(int row) {
    return 'Record $row';
  }

  @override
  String get archiveFileTooLarge => 'Choose a file smaller than 32 MB.';

  @override
  String get archiveUnsupportedArchive =>
      'This is not a supported TaskFlow export (versions 1 and 2).';

  @override
  String get archiveInvalidList => 'Invalid project metadata.';

  @override
  String get archiveDuplicateLists => 'Duplicate project identifiers.';

  @override
  String get archiveInvalidListStyle =>
      'Invalid project color or archive status.';

  @override
  String get archiveInvalidTask => 'Invalid task record.';

  @override
  String get archiveDuplicateTask => 'Duplicate task identifier.';

  @override
  String get archiveInvalidAttachments => 'Invalid attachment information.';

  @override
  String get archiveMissingList =>
      'The task refers to a project missing from this file.';

  @override
  String get archiveInvalidTaskFields => 'Invalid task fields.';

  @override
  String get archiveUnsupportedKind => 'Unsupported task or note type.';

  @override
  String get archiveInvalidCompletion => 'Invalid completion status.';

  @override
  String get archiveTwoSchedules => 'A task cannot have two schedules.';

  @override
  String get archiveTwoDeadlines => 'Choose a timed or date-only deadline.';

  @override
  String get archiveInvalidReminderDate => 'Choose an available reminder date.';

  @override
  String get archiveUnsupportedRepeat => 'Unsupported repeat rule.';

  @override
  String get archiveWeekdaysNeedWeekly => 'Weekdays require a weekly repeat.';

  @override
  String get archiveRepeatNeedsStart => 'A repeating task needs a start date.';

  @override
  String get archiveInvalidOccurrence => 'Invalid occurrence change.';

  @override
  String get archiveDuplicateOccurrence => 'Duplicate occurrence changes.';

  @override
  String get archiveInvalidSkipped => 'Invalid skipped date.';

  @override
  String get archiveInvalidOccurrenceSchedule => 'Invalid occurrence schedule.';

  @override
  String get archiveRepeatSettingsNeedRepeat =>
      'Repeat settings need a repeating task.';

  @override
  String get archiveRepeatUsesCompletedDates =>
      'Repeating tasks use individual completed dates.';

  @override
  String get archiveInvalidChecklist => 'Invalid checklist item.';

  @override
  String get archiveDuplicateChecklist => 'Duplicate checklist identifiers.';

  @override
  String get archiveInvalidChecklistProgress => 'Invalid checklist progress.';

  @override
  String get archiveRepeatEndBeforeStart => 'Repeat end precedes the start.';

  @override
  String get archiveOccurrenceOutsideRepeat =>
      'An occurrence change is outside this repeat rule.';

  @override
  String get archiveExportTooLarge =>
      'This export exceeds the supported 32 MB or 5,000-task limit.';

  @override
  String get archiveInvalidDateFormat => 'Dates must use YYYY-MM-DD.';

  @override
  String get archiveInvalidDate => 'Invalid calendar date.';

  @override
  String get archiveMissingTimezone =>
      'Timed dates need an ISO time and timezone offset.';

  @override
  String get archiveInvalidClock => 'Invalid clock time.';

  @override
  String get archiveInvalidOffset => 'Invalid timezone offset.';

  @override
  String get archiveInvalidTimedDate => 'Invalid timed date.';

  @override
  String get archiveFileUnreadable =>
      'This file could not be read. Choose a local copy.';

  @override
  String get archiveEmptyCsv => 'This CSV is empty.';

  @override
  String get archiveCsvHeader =>
      'Choose a Todoist project CSV with TYPE and CONTENT columns.';

  @override
  String get archiveCsvTaskLimit => 'Choose a CSV with at most 5,000 tasks.';

  @override
  String get archiveCsvPriority => 'Priority must be 1–4.';

  @override
  String get archiveCsvIndent => 'Indent must be 1–4.';

  @override
  String get archiveCsvRecordLimit => 'This CSV has too many records.';

  @override
  String get archiveCsvQuoting => 'Malformed CSV quoting.';

  @override
  String get archiveCsvUnclosedQuote =>
      'An unfinished quoted CSV field was found.';

  @override
  String get archiveNotesTooLong =>
      'Task and comments exceed 8,000 note characters.';

  @override
  String get archiveInvalidFile => 'The file is not valid JSON or UTF-8 text.';

  @override
  String get archiveUnknownFields =>
      'Unrecognized task fields will be omitted.';

  @override
  String get archivePersonalCopies =>
      'Imports create new personal copies. Account access, files, notification preferences and unfinished captures are not included.';

  @override
  String get archiveCsvPriorities =>
      'Todoist priorities 3 and 4 both become Low. Subtasks become separate tasks.';

  @override
  String get archiveCsvDates =>
      'Only ISO calendar dates and times with explicit timezone offsets are scheduled. Other date expressions are kept in notes for you to review.';

  @override
  String get archiveCsvPersonalCopies =>
      'This creates personal copies. Assignments, files and sharing access are not transferred. Todoist project CSV exports may omit completed tasks.';

  @override
  String get archiveReviewSchedule =>
      'The original schedule needs review; this task will go to Inbox.';

  @override
  String get archiveFlattenedSubtasks => 'Subtask nesting will be flattened.';

  @override
  String get archiveInlineLabels => 'Inline @labels remain in the title.';

  @override
  String archiveAttachmentsOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachment files are',
      one: '1 attachment file is',
    );
    return '$_temp0 not included.';
  }

  @override
  String archiveInvalidCollection(String field, int max) {
    return 'Invalid $field (maximum $max).';
  }

  @override
  String archiveInvalidText(String field, int max) {
    return 'Invalid $field (maximum $max characters).';
  }

  @override
  String archiveInvalidInteger(String field, int min, int max) {
    return 'Invalid $field ($min–$max).';
  }

  @override
  String archiveInvalidIdentifier(String field) {
    return 'Invalid $field.';
  }

  @override
  String archiveCsvExtraFields(int row) {
    return 'Row $row has more fields than the header.';
  }

  @override
  String archiveCsvInvalidSection(int row) {
    return 'Row $row: section name is invalid; its tasks will have no project.';
  }

  @override
  String archiveCsvListDescription(int row) {
    return 'Row $row: project descriptions are not supported.';
  }

  @override
  String archiveCsvOrphanComment(int row) {
    return 'Row $row: comment has no valid preceding task; it will be skipped.';
  }

  @override
  String archiveCsvUnsupportedRow(int row) {
    return 'Row $row: unsupported record type; it will be skipped.';
  }

  @override
  String archiveCsvFieldInNotes(String field) {
    return '$field will be kept as text in notes.';
  }

  @override
  String archiveField(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'export_id': 'export_id',
      'tasks': 'tasks',
      'lists': 'projects',
      'list_id': 'project id',
      'list_name': 'project name',
      'task_identifier': 'task identifier',
      'title': 'title',
      'notes': 'notes',
      'priority': 'priority',
      'duration': 'duration',
      'repeat_interval': 'repeat interval',
      'repeat_weekdays': 'repeat weekdays',
      'weekday': 'weekday',
      'completed_dates': 'completed dates',
      'individual_date_changes': 'individual date changes',
      'list_identifier': 'list identifier',
      'labels': 'labels',
      'label': 'label',
      'checklist': 'checklist',
      'checklist_identifier': 'checklist identifier',
      'checklist_title': 'checklist title',
      'checklist_dates': 'checklist dates',
      'reminder_lead': 'reminder lead',
      'reminder_time': 'reminder time',
      'other': 'field',
    });
    return '$_temp0';
  }

  @override
  String get notificationChannel => 'Task reminders';

  @override
  String get notificationComplete => 'Complete';

  @override
  String get notificationSnooze => 'Snooze 10 min';

  @override
  String get notificationDeadline => 'Your task deadline is approaching.';

  @override
  String get notificationDue => 'It’s time for your task.';

  @override
  String notificationInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Scheduled in $minutes minutes.',
      one: 'Scheduled in 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String get notificationToday => 'On your list for today.';

  @override
  String get notificationMorning => 'Make room for today';

  @override
  String get notificationEvening => 'A moment to check in';

  @override
  String get notificationCheckIn =>
      'Open TaskFlow to see your current tasks and plan your next step.';

  @override
  String get notificationSnoozed => 'Your snoozed task.';

  @override
  String get captureGone => 'This capture is no longer available.';

  @override
  String get captureNoteLength => 'A note needs 1 to 8000 characters.';

  @override
  String get captureNoTasks => 'No tasks were found. Your capture is kept.';

  @override
  String get captureUnsupportedKind =>
      'This server does not support the selected capture type. Your input is kept.';

  @override
  String get captureOffline =>
      'No internet. Your words are saved — try again when you’re online.';

  @override
  String get captureUnavailable =>
      'Couldn’t reach the assistant — your words are kept.';

  @override
  String get captureAllowance =>
      'You’ve reached today’s limit. Type the task, or try again tomorrow.';

  @override
  String get captureSignIn =>
      'Sign in again to process this account’s capture.';

  @override
  String get captureForbidden =>
      'This account cannot process the capture. Check your access and try again.';

  @override
  String get captureTooLarge =>
      'This recording exceeds the service limit. Keep it for later or use a shorter typed description.';

  @override
  String get captureTypedFirst =>
      'Save or discard this typed capture before starting a recording.';

  @override
  String get captureMicrophone =>
      'Allow microphone access to record, or type below.';

  @override
  String get captureMicrophoneBlocked =>
      'Microphone is off for TaskFlow. Turn it on in Settings, or type instead.';

  @override
  String get captureOpenSettings => 'Open Settings';

  @override
  String get captureStarting => 'One moment…';

  @override
  String get capturePaused => 'Paused';

  @override
  String get captureListening => 'Listening';

  @override
  String get captureStartTalking => 'Start talking';

  @override
  String get captureContinue => 'Continue';

  @override
  String get captureTypeInstead => 'Type instead';

  @override
  String get captureStillListening =>
      'Still listening. Tap Done when finished.';

  @override
  String get captureTimeLeft => '10 seconds left';

  @override
  String get captureKeepQuestion => 'Keep what you said?';

  @override
  String get captureKeepHelp => 'You can finish it later.';

  @override
  String get captureRecordingFirst =>
      'Retry this recording or discard it before recording another.';

  @override
  String get captureEmptyInput => 'Say or type what you need to do first.';

  @override
  String get captureSpeechStopped =>
      'Listening stopped. You can talk again, or type.';

  @override
  String get captureNoSpeech => 'I didn’t catch that. Try again, or type it.';

  @override
  String get captureSpeechLanguage =>
      'On-device speech is not installed for this language. Choose another language, record audio, or type.';

  @override
  String get captureSpeechUnavailable =>
      'On-device speech is unavailable. Record audio or type instead.';

  @override
  String get captureSpeechBusy =>
      'A microphone request is already open. Finish it before trying again.';

  @override
  String get captureIncompleteAudio =>
      'The retained audio is incomplete and cannot be processed. It is still kept on this phone.';

  @override
  String get captureWriteFailed =>
      'Could not keep this draft on your phone. Try again before leaving.';

  @override
  String get captureStopFailed =>
      'Could not finish recording. Previously retained input is kept.';

  @override
  String get captureDiscardFailed =>
      'Could not discard this capture. It is still kept.';

  @override
  String get captureReviewWriteFailed =>
      'Could not keep these changes. Please try again before leaving.';

  @override
  String get captureSaveFailed =>
      'Could not finish saving. Your capture is kept; retry will not duplicate saved tasks.';

  @override
  String get captureSetupRequested =>
      'Speech setup was requested. Follow any Android prompt, then tap Check again. You can keep typing meanwhile.';

  @override
  String get voiceSetupRequested =>
      'Follow Android’s steps, then tap Check again.';

  @override
  String get voiceSetupUnavailable =>
      'This phone can’t set this up, so TaskFlow does it online.';

  @override
  String get captureSetupUnavailable =>
      'Speech setup is unavailable here. Use saved audio or type.';

  @override
  String get voiceRecording => 'Voice recording';

  @override
  String get retryCaptures => 'Retry loading captures';

  @override
  String get capturesCaughtUp => 'All caught up';

  @override
  String get capturesEmptyHelp =>
      'Recordings and drafts you leave unfinished will be kept here.';

  @override
  String get captureResumeHelp => 'Kept on this phone · Tap to resume';

  @override
  String captureDraftSummary(int count, int ready) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts',
      one: '1 draft',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ready,
      locale: localeName,
      other: '$ready ready',
      one: '1 ready',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String editCaptureItem(String title) {
    return 'Edit $title';
  }

  @override
  String removeCaptureItem(String title) {
    return 'Remove $title';
  }

  @override
  String captureTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added',
      one: '1 task added',
    );
    return '$_temp0';
  }

  @override
  String captureKeptForReview(int count) {
    return '$count kept for review';
  }

  @override
  String get captureConfirmDetails => 'Use the details shown';

  @override
  String get captureNothingToReview => 'Nothing left to review';

  @override
  String get captureRemovedDraftsHelp =>
      'Removed drafts will not become tasks.';

  @override
  String get captureFinish => 'Done';

  @override
  String get captureYourWords => 'Your words';

  @override
  String get captureReviewRetainedHelp =>
      'Unfinished drafts are kept on this phone. You can return from Unfinished captures.';

  @override
  String get captureCheckDetails => 'Check the details above';

  @override
  String get captureUnderstanding => 'Understanding…';

  @override
  String get captureFailed =>
      'That didn’t work. Your words are saved here — try again.';

  @override
  String get captureSlow => 'Taking longer than usual.';

  @override
  String get captureSaveAsWritten => 'Save as written';

  @override
  String captureThingsToAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things to add',
      one: '1 thing to add',
    );
    return '$_temp0';
  }

  @override
  String get captureAddToCalendar => 'Add to calendar';

  @override
  String get captureAddTask => 'Add task';

  @override
  String captureAddTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count tasks',
      one: 'Add 1 task',
    );
    return '$_temp0';
  }

  @override
  String get captureSayAgain => 'Say it again';

  @override
  String get labelsExample => 'home, errands, calls';

  @override
  String get account => 'Account';

  @override
  String completedTaskSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks completed. Tap a check to reopen one.',
      one: '1 task completed. Tap its check to reopen it.',
    );
    return '$_temp0';
  }

  @override
  String get taskTitleHint => 'e.g. Doctor appointment';

  @override
  String individualDateChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count individual date changes',
      one: '1 individual date change',
    );
    return '$_temp0';
  }

  @override
  String movedOccurrenceDate(String date) {
    return 'Moved to $date';
  }

  @override
  String reopenNamedTask(String title) {
    return 'Reopen $title';
  }

  @override
  String completeNamedTask(String title) {
    return 'Complete $title';
  }

  @override
  String get viewOnlyTaskTitle => 'View-only task';

  @override
  String get readOnlyList => 'This project is read-only';

  @override
  String get listEditingAccessHelp =>
      'The project owner manages editing access.';

  @override
  String get loadTaskError => 'Couldn’t load this task';

  @override
  String deleteSeriesHelp(String title) {
    return '“$title” and all its occurrences will be removed.';
  }

  @override
  String get viewOnlyTask =>
      'View-only shared task. The project owner manages editing access.';

  @override
  String get stepUpdateError => 'Could not update this step. Please retry.';

  @override
  String get checklistCompletionHelp =>
      'Completing the checklist does not complete the task. Use Complete when you are finished.';

  @override
  String get diagnosticsPrivacy =>
      'Local counts and timing from the last 1,000 events. No task titles, words, recordings or account identifiers are included. Nothing here is uploaded.';

  @override
  String get diagnosticsPercentiles =>
      'Median is the middle observation. P95 is the time that 95% of observations finish within. Failed requests are counted separately.';

  @override
  String get diagnosticsMeasurementHelp =>
      'Keeping a capture for later is not a failure. Counts can include several visits to the same draft; they are not a user conversion rate. Correction time covers open editing dialogs, including cancelled ones. Local save timing excludes cloud sync. Audio transcription excludes typed and on-device input.';

  @override
  String diagnosticsObservations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations',
      one: '1 observation',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsTiming(String median, String p95, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timed observations',
      one: '1 timed observation',
    );
    return 'Median $median s · P95 $p95 s · $_temp0';
  }

  @override
  String get diagnosticsClearError => 'Could not clear diagnostics. Try again.';

  @override
  String get clearDiagnostics => 'Clear local diagnostics';

  @override
  String diagnosticsEvent(String event) {
    String _temp0 = intl.Intl.selectLogic(event, {
      'opened': 'Capture opened',
      'ready': 'Capture ready to use',
      'started': 'New durable captures',
      'typedStarted': 'Typed input started',
      'permissionDenied': 'Microphone permission denied',
      'nativeStarted': 'On-device listening started',
      'firstPartial': 'First on-device words',
      'nativeListening': 'On-device listening duration',
      'recordingStopped': 'Saved audio duration',
      'transcription': 'Online audio transcription',
      'extraction': 'Online task extraction',
      'processing': 'Request and retained drafts',
      'notePrepared': 'Local note prepared',
      'noteTranscribed': 'Recorded note ready',
      'failed': 'Failed requests',
      'retried': 'Retried requests',
      'edited': 'Draft changes',
      'reviewOpened': 'Review opened',
      'reviewTime': 'Time in review',
      'correction': 'Correction dialog time',
      'saved': 'Confirmed to local save',
      'discarded': 'Explicitly discarded captures',
      'resumed': 'Resumed captures',
      'leftCapturePending': 'Capture kept for later',
      'leftReviewPending': 'Review kept for later',
      'other': 'Other capture event',
    });
    return '$_temp0';
  }

  @override
  String get taskflowPro => 'TaskFlow Pro';

  @override
  String get billingSettingsHelp => 'Subscription, purchases and billing';

  @override
  String get billingIntro => 'Your subscription, in one place.';

  @override
  String get billingComplimentary =>
      'Complimentary Pro access. All Pro features are included, with no payment or renewal.';

  @override
  String billingStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'active': 'Pro is active',
      'inactive': 'No active Pro subscription',
      'other': 'Subscription status unavailable',
    });
    return '$_temp0';
  }

  @override
  String billingUntil(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'renews': 'Renews on $date',
      'other': 'Access until $date',
    });
    return '$_temp0';
  }

  @override
  String get billingTestMode =>
      'Test purchases only. No real payment will be taken. An active test subscription unlocks voice and AI capture in this development build.';

  @override
  String get billingGuestHelp =>
      'Sign in to link purchases to your TaskFlow account and recover Pro on your other devices.';

  @override
  String get billingSignIn => 'Sign in to TaskFlow';

  @override
  String get billingWorking => 'Updating subscription';

  @override
  String billingMonthlyPrice(String price) {
    return '$price / month';
  }

  @override
  String get billingRenewalHelp =>
      'Automatically renews each month until cancelled. Review the final price and any trial terms before confirming.';

  @override
  String get billingViewPlans => 'View subscription';

  @override
  String get billingTestMonthly => 'Test monthly purchase';

  @override
  String get billingRestore => 'Restore purchases';

  @override
  String get billingManage => 'Manage subscription';

  @override
  String get billingOpenStore => 'Open store subscription settings';

  @override
  String get billingRefresh => 'Refresh status';

  @override
  String get billingRestoreHelp =>
      'Already subscribed? Use the same store account, then restore purchases. Cancelling renewal keeps Pro available until your paid access ends.';

  @override
  String get billingStoreOpenError =>
      'Could not open the store. Try again or open your store’s subscription settings.';

  @override
  String billingError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'unsupportedPlatform':
          'Subscriptions are available in the Android and iOS app.',
      'configuration':
          'Subscriptions are not available yet. Please try again later.',
      'accountUnavailable':
          'Connect to the TaskFlow server to link your subscription, then refresh.',
      'network': 'Could not update billing. Check your connection and refresh.',
      'notAllowed':
          'Purchases are restricted for this store account or device.',
      'otherAccount':
          'This purchase belongs to another account. Sign in to the original account to restore it.',
      'store': 'The store could not complete the request. Please try again.',
      'other': 'Could not update your subscription. Please try again.',
    });
    return '$_temp0';
  }

  @override
  String billingResult(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'active': 'TaskFlow Pro is active.',
      'restored': 'Your Pro subscription was restored.',
      'noPurchases': 'No active Pro purchase was found for this account.',
      'awaitingEntitlement':
          'Purchase received. Pro is not active yet; refresh or restore purchases shortly.',
      'updated': 'Subscription status updated.',
      'pending':
          'Payment is pending. Pro will activate after the store confirms payment.',
      'busy': 'Please wait for the current operation to finish.',
      'accountChanged':
          'The account changed. Check the subscription on the purchasing account.',
      'other': 'The request could not be completed. Please try again.',
    });
    return '$_temp0';
  }

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get linkGoogleAccount => 'Link Google account';

  @override
  String get googleAccountLinked => 'Google account linked';

  @override
  String get googleLinkHelp =>
      'Confirm your TaskFlow password, then choose the Google account with the same email. Your tasks and subscription will stay in this account.';

  @override
  String get googleSignInSetupPending =>
      'Google sign-in is not available in this build yet. You can use email and password.';

  @override
  String googleSignInError(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'google_not_configured':
          'Google sign-in is not available yet. Use email and password for now.',
      'google_link_required':
          'This email already has a TaskFlow account. Sign in with your password, then choose Link Google account.',
      'google_password_required':
          'Enter your current TaskFlow password to link Google.',
      'google_email_mismatch':
          'Choose the Google account with the same email as your TaskFlow account.',
      'google_already_linked':
          'This Google account is already linked. Sign in to the original TaskFlow account.',
      'google_account_changed':
          'Your account changed during sign-in. Please try again.',
      'google_invalid_token':
          'Google could not verify your sign-in. Please try again.',
      'other':
          'Google sign-in could not finish. Check your connection and try again.',
    });
    return '$_temp0';
  }

  @override
  String get authOr => 'or';

  @override
  String get authRestoring => 'Opening your space…';

  @override
  String get authHaveRecoveryCode => 'I already have a code';

  @override
  String get authEnterRecoveryCode =>
      'Enter the code from your recovery email.';

  @override
  String get useTestAccount => 'Use test account';

  @override
  String get developmentOnly => 'Development only';

  @override
  String get projectsAll => 'All projects';

  @override
  String get projectsPersonal => 'Personal projects';

  @override
  String get projectsShared => 'Shared projects';

  @override
  String get projectsFind => 'Find a project';

  @override
  String get projectsManage => 'Manage projects';

  @override
  String get forMe => 'For me';

  @override
  String get forTeam => 'All';

  @override
  String get responsibility => 'Responsible';

  @override
  String get assignedToMe => 'Me';

  @override
  String get assignedToGroup => 'Everyone';

  @override
  String get assignmentNeeded => 'Needs an assignee';

  @override
  String get assignmentChoose => 'Who is responsible?';

  @override
  String get assignmentGroupHelp =>
      'One shared task. A member completes it for everyone.';

  @override
  String assignmentHeard(Object names) {
    return 'You mentioned: $names';
  }

  @override
  String get audiencePersonal => 'Only you can see this.';

  @override
  String audienceShared(Object name) {
    return 'Visible to everyone in $name';
  }

  @override
  String shareTaskConfirm(String name) {
    return 'Share with $name? Everyone there will see this task. It can’t be made private again.';
  }

  @override
  String get shareTask => 'Share';

  @override
  String get sharedTaskStays => 'Shared tasks stay in their project.';

  @override
  String get assignmentIsRight => 'Is this right?';

  @override
  String get yes => 'Yes';

  @override
  String get pinProject => 'Pin project';

  @override
  String get unpinProject => 'Unpin project';

  @override
  String get groups => 'Groups';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupHelp => 'Invite people once, work together across projects.';

  @override
  String get groupMembers => 'Members';

  @override
  String get groupAdmin => 'Administrator';

  @override
  String get groupProjects => 'Group projects';

  @override
  String get groupInviteHelp =>
      'They will see every project in this group, including tasks, notes and files. We will send an email inviting them to review and join.';

  @override
  String get groupLeave => 'Leave group';

  @override
  String get groupLeaveHelp =>
      'You will lose access to this group’s projects and files. Your tasks stay in the group for reassignment.';

  @override
  String get groupTransfer => 'Transfer ownership';

  @override
  String get groupTransferHelp =>
      'The new owner controls this group and its projects. You will remain an administrator.';

  @override
  String get groupArchive => 'Archive group';

  @override
  String get groupRestore => 'Restore group';

  @override
  String groupArchivedForEveryone(String name) {
    return '$name archived for everyone — hidden from calendars, no reminders.';
  }

  @override
  String get groupDeleteHelp =>
      'Only an empty group can be deleted. Archive a group to keep its projects and content.';

  @override
  String get groupActionError =>
      'This change could not be saved. Check your connection and refresh; permissions may have changed.';

  @override
  String get groupVoiceName => 'Your spoken name';

  @override
  String get groupVoiceHelp =>
      'An optional name others can use when assigning tasks by voice.';

  @override
  String get groupOnline => 'Connect to manage group members and invitations.';

  @override
  String get projectDestination => 'Where does this project belong?';

  @override
  String get projectNotifications => 'Project updates';

  @override
  String get updatesAll => 'All changes';

  @override
  String get updatesAssigned => 'My assignments';

  @override
  String get updatesMuted => 'Muted — no updates or reminders';

  @override
  String get activity => 'Activity';

  @override
  String get activityEmpty => 'You’re up to date.';

  @override
  String get activityHelp =>
      'Assignments and updates from your shared projects appear here.';

  @override
  String get activityMarkRead => 'Mark all as read';

  @override
  String get activityCreated => 'Created a task';

  @override
  String get activityUpdated => 'Updated a task';

  @override
  String get activityAssigned => 'Changed responsibility';

  @override
  String get activityCompleted => 'Completed a task';

  @override
  String get activityReopened => 'Reopened a task';

  @override
  String get activityDeleted => 'Deleted a task';

  @override
  String get activitySystem => 'TaskFlow';

  @override
  String get voiceProRequired => 'Voice capture is included with TaskFlow Pro.';

  @override
  String get captureSpeakingIsPro =>
      'Speaking a task is part of TaskFlow Pro. You can type it here.';

  @override
  String get voiceProAction => 'Explore Pro';

  @override
  String get voiceAccessUnavailable =>
      'We could not verify voice access. Your capture is safe; reconnect and try again.';

  @override
  String get projectsNoneFound => 'No matching projects';

  @override
  String get groupRename => 'Rename group';

  @override
  String get groupRemoveHelp =>
      'Removing this member ends their access to every project in this group. Their tasks stay and will need reassignment.';

  @override
  String get projectsPinned => 'Pinned projects';

  @override
  String get invitationEmailSent =>
      'Invitation sent by email. You can also share the code below.';

  @override
  String get invitationEmailPending =>
      'Your invitation is ready. Email delivery is pending and will retry automatically. You can share this code now.';

  @override
  String get invitationReview => 'Review invitation';

  @override
  String invitationFrom(String sender, String name) {
    return '$sender invited you to “$name”';
  }

  @override
  String get invitationReviewHelp => 'You’ll see its tasks, notes and files.';

  @override
  String get invitationUnavailable =>
      'This invitation is unavailable for this account. Check that you signed in with the email address that received it, or ask for a new invitation.';

  @override
  String get stagingInviteOnly =>
      'This private test build is for invited testers. Ask the TaskFlow owner for an invitation to this email address.';
}
