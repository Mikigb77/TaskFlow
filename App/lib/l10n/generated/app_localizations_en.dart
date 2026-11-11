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
  String get scheduleHourRange24 => 'Hour from 0 to 23';

  @override
  String get scheduleHourRange12 => 'Hour from 1 to 12';

  @override
  String get scheduleMinuteRange => 'Minutes from 0 to 59';

  @override
  String get reviewOptions => 'More options';

  @override
  String get reviewOriginal => 'See what I said';

  @override
  String get reviewOriginalText => 'Original text';

  @override
  String get reviewRemoved => 'Removed';

  @override
  String reviewUndoSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They’re back here, not saved yet.',
      one: 'It’s back here, not saved yet.',
    );
    return '$_temp0';
  }

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
      'memberLimit': 'This project supports up to 20 members and 20 pending invitations. Remove someone or cancel an invitation first.',
      'accepted': 'This invitation was already accepted. Manage the person’s access in Members.',
      'owner': 'The owner cannot leave. You can delete the project if it is no longer needed.',
      'expired': 'This invitation is no longer available. Ask the owner for a new one.',
      'code': 'Ask the project owner for the current invitation code.',
      'refresh': 'This project changed. Refresh before deleting it.',
      'ownerOnly':
          'Only the project owner can manage sharing and project details.',
      'other': 'This project is read-only for your account. Ask the owner for editing access.',
    });
    return '$_temp0';
  }

  @override
  String syncProblem(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'assignmentChanged': 'The responsible person changed. Your unsent edit was kept as a personal copy.',
      'listConflict': 'A project changed on another device. Choose which version to keep in Projects.',
      'readOnly': 'This project is now read-only. Your unsent edit was kept as a personal copy.',
      'accessChanged': 'Shared-project access changed. Refresh to finish syncing permitted edits.',
      'taskConflict': 'A task changed on another device. Your edit was kept as an offline copy; a conflicting deletion was cancelled.',
      'serverUpdate': 'Update this server before syncing notes. Your notes are kept on this phone.',
      'other': 'The server did not preserve this content type. Your local copy is kept.',
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
      'emailUsed': 'This email already has an account.',
      'email': 'Enter a valid email address.',
      'credentials': 'We couldn’t find that account, or the password is wrong.',
      'session': 'Please sign in again to continue. Your local tasks are kept.',
      'accountChanged':
          'The account changed. Reopen this screen and try again.',
      'password': 'Choose a password of 12–128 characters that is not common, entirely numeric or similar to your email.',
      'recoveryCode':
          'The recovery code is invalid or expired. Request a new one.',
      'forbidden':
          'This account cannot perform that action. Check your access.',
      'rateLimit':
          'Too many requests. Please wait a little before trying again.',
      'fileLimit': 'Choose a non-empty file up to 6 MB.',
      'fileChanged': 'The file has changed or could not be verified. Choose it again or retry the download.',
      'network': 'No connection. Check Wi-Fi or mobile data and try again.',
      'networkKept': 'No connection. Check Wi-Fi or mobile data and try again. Your tasks are still saved on this phone.',
      'unavailable': 'The service is unavailable. Please try again later.',
      'validation': 'Some details were not accepted. Review the information and try again.',
      'other': 'Could not complete the request. Please try again.',
      'otherKept': 'Could not complete the request. Please try again. Your tasks are still saved on this phone.',
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
      'What you shared is kept. Open TaskFlow again to try again.';

  @override
  String get note => 'Note';

  @override
  String get editNote => 'Edit note';

  @override
  String get noteTitle => 'Note title';

  @override
  String get noteBody => 'Your note';

  @override
  String get notesEmpty => 'A place for your thoughts';

  @override
  String get notesEmptyHelp =>
      'Keep ideas and things to remember. For something to do, use a task.';

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
  String get viewOnlyNote =>
      'View-only note. To make changes, ask the project’s owner.';

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
  String get duration => 'Duration';

  @override
  String get durationUnset => 'No duration set';

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
  String get deadlineTime => 'Deadline time';

  @override
  String get removeDeadline => 'Remove deadline';

  @override
  String get deadlineRecurringHelp => 'Each repeat has its own deadline.';

  @override
  String get deadlineLatePlan =>
      'This plan finishes after the deadline. Check the start or duration.';

  @override
  String deadlineLabel(String date) {
    return 'Due $date';
  }

  @override
  String deadlinePassedOn(String date) {
    return 'Was due $date';
  }

  @override
  String get reminderAnchor => 'Remind before';

  @override
  String get dayTimeline => 'Day timeline';

  @override
  String get timelineLimit =>
      'Showing the first 200 timed items. Use the agenda to see every task.';

  @override
  String get timelineUnblocked => 'No time';

  @override
  String get timelineNoBlocks => 'Nothing with a time on this day.';

  @override
  String timelineHours(int hours) {
    return '$hours hours in this day';
  }

  @override
  String get deviceCalendars => 'Phone calendars';

  @override
  String get deviceCalendarIntro =>
      'You’ll see your phone’s events in Calendar. They’re only read here, never uploaded.';

  @override
  String get calendarEnable => 'Connect phone calendars';

  @override
  String get calendarDisable => 'Hide calendar events';

  @override
  String get calendarConnected => 'Connected. Events show in Calendar.';

  @override
  String get calendarChoose => 'Choose calendars';

  @override
  String get calendarDenied =>
      'Allow calendar access to display your events. Your tasks still work without it.';

  @override
  String get calendarRefused =>
      'Without permission, TaskFlow can’t see your events.';

  @override
  String get calendarBlocked =>
      'Calendar access is off. You can enable it in the phone’s app settings.';

  @override
  String get calendarUnsupported =>
      'Phone calendars are available on Android and iPhone.';

  @override
  String get calendarSettings => 'Open app settings';

  @override
  String get calendarEmptySources =>
      'No visible calendars are synced to this phone. Connect an account in your calendar app, then refresh here.';

  @override
  String get calendarRefresh => 'Refresh calendars';

  @override
  String calendarAccountCalendars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calendars',
      one: '1 calendar',
    );
    return '$_temp0';
  }

  @override
  String get calendarOnPhone => 'On this phone';

  @override
  String get calendarMoreOptions => 'More options';

  @override
  String get calendarFewerOptions => 'Fewer options';

  @override
  String get calendarExtras => 'Holidays, birthdays and more';

  @override
  String calendarFromAccount(String account) {
    return 'From $account';
  }

  @override
  String get calendarHolidays => 'Holidays';

  @override
  String get calendarBirthdays => 'Birthdays';

  @override
  String get calendarWeekNumbers => 'Week numbers';

  @override
  String get calendarOther => 'Other calendar';

  @override
  String get calendarExport => 'Add my tasks to my calendar';

  @override
  String calendarExportTo(String calendar) {
    return 'Tasks with a day also go to $calendar.';
  }

  @override
  String get calendarExportTarget => 'Add tasks to';

  @override
  String get calendarExportRefused =>
      'Without permission, TaskFlow can’t add tasks to your calendar.';

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
  String calendarSeeAllEvents(int count) {
    return 'See all $count events';
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
  String get noScheduledTasks => 'No tasks for this day.';

  @override
  String get calendar => 'Calendar';

  @override
  String get tasks => 'Tasks';

  @override
  String get settings => 'Settings';

  @override
  String get inbox => 'No date';

  @override
  String inboxCount(int count) {
    return 'No date · $count';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

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
  String get taskScreenTitle => 'Task';

  @override
  String get addTask => 'Add a task';

  @override
  String get typeTasks => 'Type tasks';

  @override
  String get unfinishedCaptures => 'Not saved yet';

  @override
  String get captureDiagnostics => 'Capture diagnostics';

  @override
  String get lists => 'Projects';

  @override
  String get labels => 'Labels';

  @override
  String get noList => 'No project';

  @override
  String get priority => 'Priority';

  @override
  String get low => 'Low';

  @override
  String get medium => 'Medium';

  @override
  String get high => 'High';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatNeedsDate => 'Add a date to repeat';

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
  String get attachments => 'Files';

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
  String get remindersOnLate => 'On · may arrive late';

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
  String timeZoneSameAsPhone(String city) {
    return 'Same as phone ($city)';
  }

  @override
  String get timezoneHelp => 'New tasks use this time zone to read dates.';

  @override
  String get searchTimezone => 'Find a timezone';

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
  String get previousWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String dayTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get licenses => 'Open-source licences';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get todayAgenda => 'Today’s agenda';

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
  String get calendarTrySaying =>
      'Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”';

  @override
  String get calendarTryTyping =>
      'Try it: tap Add a task and type “Tomorrow, call the dentist.”';

  @override
  String get calendarTryForm =>
      'Try it: tap New task, type “Call the dentist” and tap Tomorrow.';

  @override
  String get planTask => 'Plan a task';

  @override
  String get homeCapture => 'Mic button on your home screen';

  @override
  String get homeCaptureInstructions =>
      'On Android, long-press the TaskFlow icon for its shortcuts, or add the Dictate a task widget from your launcher. Share text to TaskFlow from another app.';

  @override
  String get widgetPickerHelp =>
      'Add the TaskFlow widget from your launcher’s widget picker.';

  @override
  String get appearanceError => 'Could not save your appearance preference.';

  @override
  String get list => 'Project';

  @override
  String get archivedListAddHelp =>
      'Archived project. Restore it to add tasks.';

  @override
  String get archivedListNoAdd => 'Archived project.';

  @override
  String get yourTasks => 'Your tasks';

  @override
  String get findTask => 'Find a task…';

  @override
  String get clearSearch => 'Clear search';

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
  String personNothingOpen(String name) {
    return '$name has nothing open here';
  }

  @override
  String get personNothingOpenHelp => 'Tap All to see every task.';

  @override
  String get listEmpty =>
      'Add a task to this project. Its date and reminder are yours to choose.';

  @override
  String get readOnlyListEmpty => 'No tasks in this project yet.';

  @override
  String get tasksEmpty => 'Tap Add a task to add one. A date is optional.';

  @override
  String get inboxEmpty =>
      'Tasks without a date wait here until you choose one.\nStart with Add a task.';

  @override
  String get tasksEmptyForm => 'Tap New task to add one. A date is optional.';

  @override
  String get inboxEmptyForm =>
      'Tasks without a date wait here until you choose one.\nStart with New task.';

  @override
  String get savedOnDevice => 'Your saved tasks are still on your device.';

  @override
  String get checkCaptures => 'See what’s not saved yet';

  @override
  String get seriesEdits => 'Edits apply to the whole repeating task.';

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
  String get reminderNeedsDay => 'To remind you, give it a day.';

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
  String get deleteNote => 'Delete note';

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
  String get moveNoteError => 'Could not move this note. Please retry.';

  @override
  String get occurrence => 'Occurrence';

  @override
  String get starts => 'Starts';

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
      'Live transcription uses on-device speech where available; no audio is retained in that mode. To add, find or change tasks, or to ask for reminders your way, your words go over the internet to Google’s AI. Saved audio is transcribed online. Anything not saved yet stays on this phone until you save or discard it.';

  @override
  String get capturePrivacyLine =>
      'Your words go to Google’s AI. More in Other settings › Voice.';

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
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '$remaining to do · $done completed',
      zero: '$remaining to do',
    );
    String _temp1 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$_temp0',
      zero: '$done completed',
    );
    return '$_temp1';
  }

  @override
  String overdueDate(String date) {
    return '$date · Overdue';
  }

  @override
  String assigneeLabel(String name) {
    return 'Assignee: $name';
  }

  @override
  String projectLabel(String name) {
    return 'Project: $name';
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
    return 'Not saved yet · $count';
  }

  @override
  String listeningSeconds(String time) {
    return 'Listening · $time';
  }

  @override
  String repeatEvery(int interval, String frequency) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval days',
      one: 'Every day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval weeks',
      one: 'Every week',
    );
    String _temp2 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval months',
      one: 'Every month',
    );
    String _temp3 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval years',
      one: 'Every year',
    );
    String _temp4 = intl.Intl.selectLogic(frequency, {
      'daily': '$_temp0',
      'weekly': '$_temp1',
      'monthly': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
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
  String priorityValue(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'high': 'High priority',
      'medium': 'Medium priority',
      'other': 'Low priority',
    });
    return '$_temp0';
  }

  @override
  String get pickDate => 'Pick a date';

  @override
  String get editStep => 'Edit step';

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
  String get addStep => 'Add step';

  @override
  String get stepLimit =>
      'A task can have up to 50 steps. Remove a step to add this one.';

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
  String get dayAllClear => 'All clear. Take a breath.';

  @override
  String get undoError => 'Could not undo. Please try again.';

  @override
  String get taskUpdateError => 'Could not update this task. Please try again.';

  @override
  String get occurrenceSkippedNotice => 'Occurrence skipped';

  @override
  String get originalRestored => 'Original date restored';

  @override
  String get movedInbox => 'Date removed';

  @override
  String get scheduleChangedAgain =>
      'The date changed again. Open the task to check it.';

  @override
  String get scheduleError => 'Couldn’t change the date. Try again.';

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
  String get completedButton => 'Completed';

  @override
  String get completedLoadError => 'Couldn’t load completed tasks';

  @override
  String get tryLater => 'Please try again in a moment.';

  @override
  String get changeSeriesQuestion => 'Change how it repeats?';

  @override
  String get changeSeriesHelp =>
      'Dates you moved or skipped will follow the new repeat. Completed dates stay in the history.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get resetSave => 'Reset and save';

  @override
  String get taskSavedInbox => 'Added with no date';

  @override
  String taskAddedOn(String date) {
    return 'Added to $date';
  }

  @override
  String taskAddedDue(String date) {
    return 'Added · due $date';
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
  String get keepAsTyped => 'Keep my words';

  @override
  String get optionalTime => 'Time (optional)';

  @override
  String get resetDateHelp => 'Reset a date, then save your changes.';

  @override
  String get skipped => 'Skipped';

  @override
  String get labelLimit => 'Use up to 10 labels, each up to 32 characters.';

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
  String reminderBeforeDeadline(String lead) {
    return '$lead · deadline';
  }

  @override
  String reminderForPersonOnly(String name) {
    return 'Reminder for $name';
  }

  @override
  String get noReminderProjectMuted => 'No reminder: project muted';

  @override
  String get noReminderProjectArchived => 'No reminder: project archived';

  @override
  String get noReminderTimePassed => 'No reminder: the alert time has passed';

  @override
  String reminderSent(String when, String date, String time) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    return 'Reminder sent: $_temp0, $time';
  }

  @override
  String reminderSnoozed(String when, String date, String time) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    return 'Reminder snoozed: $_temp0, $time';
  }

  @override
  String reminderPlanLast(String plan, String when, String date, String time) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    return '$plan · last: $_temp0, $time';
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
  String get fileRetry => 'Upload again';

  @override
  String get fileRemove => 'Remove attachment';

  @override
  String removeFileNamed(String file) {
    return 'Remove $file';
  }

  @override
  String get fileRemoveQuestion => 'Remove this attachment?';

  @override
  String get fileRemoveHelp =>
      'This removes it from the task and, if uploaded, your other devices when they sync. Your original file is not deleted.';

  @override
  String get yourAccount => 'Your account';

  @override
  String get accountSaved => 'Saved to your account';

  @override
  String get syncNow => 'Sync now';

  @override
  String get accountSyncing => 'Syncing';

  @override
  String get importLocalItems => 'Import local tasks and notes';

  @override
  String get accountImporting => 'Importing tasks and notes';

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
  String get accountSigningOut => 'Signing out';

  @override
  String get signOutQuestion =>
      'Sign out? Reminders on this phone stop until you sign in again.';

  @override
  String get recoveryHeading => 'Reset your password';

  @override
  String get registerHeading => 'Create your account';

  @override
  String get signInHeading => 'Sign in';

  @override
  String get signInOrUpHeading => 'Sign in or sign up';

  @override
  String get authPitch =>
      'Note down what you need to do, and TaskFlow puts it on your calendar.';

  @override
  String get signInAgainReason =>
      'You were signed out. Sign in again to pick up where you left off.';

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
  String recoveryEmailRequested(String email) {
    return 'If $email has an account, an email with a code is on its way. Type it here.';
  }

  @override
  String recoveryCodeRenewed(String email) {
    return 'That code no longer works. If $email has an account, a new one is on its way.';
  }

  @override
  String get passwordResetComplete =>
      'Password updated. Sign in with your new password.';

  @override
  String get verifyEmailHeading => 'Confirm your email';

  @override
  String verifyEmailHelp(String email) {
    return 'We’ve sent a 6-digit code to $email. Type it here.';
  }

  @override
  String get verifyEmailCode => 'Code';

  @override
  String get verifyEmailCodeLength => 'The code has 6 digits';

  @override
  String get verifyEmailConfirm => 'Confirm';

  @override
  String get verifyEmailConfirming => 'Confirming';

  @override
  String get verifyEmailResend => 'Resend code';

  @override
  String verifyEmailResendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Resend code in $seconds seconds',
      one: 'Resend code in 1 second',
    );
    return '$_temp0';
  }

  @override
  String verifyEmailResendInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Resend code in $minutes minutes',
      one: 'Resend code in 1 minute',
    );
    return '$_temp0';
  }

  @override
  String verifyEmailResendLimited(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          'You’ve asked for a lot of codes. Wait $minutes minutes to ask for another.',
      one: 'You’ve asked for a lot of codes. Wait a minute to ask for another.',
    );
    return '$_temp0';
  }

  @override
  String get verifyEmailResent =>
      'We’ve sent you a new code. If you can’t see it, check Spam or Promotions.';

  @override
  String get verifyEmailCodeInvalid =>
      'That code isn’t right. Check the newest email we sent.';

  @override
  String get verifyEmailCodeSpentNew =>
      'That code no longer works. We’ve sent you a new one.';

  @override
  String get verifyEmailCodeSpentWait =>
      'That code no longer works. Tap “Resend code” when the countdown ends.';

  @override
  String get verifyEmailOtherAddress => 'Use another email';

  @override
  String get verifyEmailReplaced =>
      'Someone has created an account with this email again. Create it again to continue.';

  @override
  String get verifyEmailWrongPassword =>
      'That isn’t this account’s password. Don’t remember it? Tap “Use another email” and create the account again.';

  @override
  String get newList => 'New project';

  @override
  String get editList => 'Edit project';

  @override
  String get listName => 'Name';

  @override
  String get listNameHint => 'Home, Work, Shopping…';

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
  String get createList => 'Create project';

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
  String get appUpdateTitle => 'Update available';

  @override
  String appUpdateBody(String version) {
    return 'TaskFlow Staging $version is ready. The app closes to install it; open it again afterwards.';
  }

  @override
  String get appUpdateInstall => 'Update';

  @override
  String get appUpdateDownloading => 'Downloading…';

  @override
  String get appUpdateAllow =>
      'Allow TaskFlow Staging to install updates, then tap Update again.';

  @override
  String get appUpdateFailed =>
      'The update couldn\'t be installed. Try again later.';

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
  String get listsEmptyTitle => 'A place for each part of life';

  @override
  String get listsEmptyHelp =>
      'Start with Home, Work or Shopping. Tasks can move whenever you like.';

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
  String shareProjectHelp(String project) {
    return 'They’ll see everything in $project.';
  }

  @override
  String get sendInvitation => 'Send invitation';

  @override
  String inviteWho(String name) {
    return 'Who are you inviting to $name?';
  }

  @override
  String get inviteOwnEmail =>
      'That’s your own email. Type the other person’s.';

  @override
  String personYou(String name) {
    return '$name (you)';
  }

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
  String get enterEmailAddress => 'Enter an email address.';

  @override
  String get sharingRolesHelp =>
      'Editors can add, change, complete and delete tasks and files. Only the owner manages the project and people. Shared tasks stay in this project.';

  @override
  String get listSharing => 'Project sharing';

  @override
  String get sharingLoadError => 'Could not load sharing.';

  @override
  String get retry => 'Retry';

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
      'This person will lose access to this project and its tasks, notes and files. Changes they haven’t sent yet will be lost.';

  @override
  String get pendingInvitations => 'Pending invitations';

  @override
  String pendingRole(String role) {
    return '$role · pending';
  }

  @override
  String get howSharingWorks => 'How sharing works';

  @override
  String get sharedDataHelp =>
      'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Reminders aren’t shared: each person has their own.';

  @override
  String get sharingRemovalHelp =>
      'When you leave or lose access, the project leaves this phone the next time it connects. Copies you exported stay.';

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
      'New files upload to your account after saving, up to 6 MB each. Older local files stay on this device until you choose Upload in task details.';

  @override
  String get fileLimit =>
      'Choose a non-empty file up to 6 MB. You can attach up to 20 files per task.';

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
  String get exactAlarmsNextScreen =>
      'On the next screen, turn on the switch, then come back.';

  @override
  String get remindersOnConfirmation => 'Done. Reminders are on.';

  @override
  String get reminderAskQuestion => 'Want a reminder before it?';

  @override
  String get reminderAskYes => 'Yes, remind me';

  @override
  String get reminderAskNotNow => 'Not now';

  @override
  String get nameAskTitle => 'What’s your name?';

  @override
  String get nameAskBody =>
      'It’s how people you share projects with will see you.';

  @override
  String get nameAskField => 'Name';

  @override
  String get accountAddName => 'Add your name';

  @override
  String get nameAskNotNow => 'Not now';

  @override
  String get details => 'Details';

  @override
  String get mobileNotificationsOnly => 'Mobile notifications only';

  @override
  String get notificationPermissionOff =>
      'Your phone isn’t letting TaskFlow notify you.';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get preciseAlarmsAvailable => 'Precise alarm access available';

  @override
  String get approximateAlarmsHelp =>
      'Alerts are approximate until precise alarm access is enabled';

  @override
  String get allowPreciseAlarms => 'Allow “Alarms & reminders”';

  @override
  String get timedTasks => 'Timed tasks';

  @override
  String get dateOnlyTasks => 'Date-only tasks';

  @override
  String dateOnlyOffPlans(String time) {
    return 'Off · “Until the deadline”: $time';
  }

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
      'Upcoming alerts update when you open the app and, when Android allows it, every hour.';

  @override
  String get backgroundAlertRefreshHelp =>
      'Upcoming alerts update when you open the app and when your phone allows it.';

  @override
  String get noUpcomingAlerts =>
      'No upcoming alerts. Choose a reminder on a scheduled task.';

  @override
  String get repeatsDaily => 'repeats daily';

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
  String get exportImportIntro =>
      'Save a copy of your tasks to a file, or bring tasks from Todoist.';

  @override
  String get exportTaskFlowFile => 'Export TaskFlow file';

  @override
  String get chooseImportFile => 'Choose import file';

  @override
  String get chooseImportFileHelp =>
      'Choose a TaskFlow file or a project exported from Todoist. You’ll review it before importing.';

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
      other: '$count later alerts aren’t set yet.',
      one: '1 later alert isn’t set yet.',
    );
    return '$_temp0 The next update sets the nearest ones.';
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
      'Imports create new personal copies. Account access, files, notification preferences and anything not saved yet are not included.';

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
      'The original schedule needs review; this task will have no date.';

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
  String notificationAt(String day, String date, String time, int hour) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'today': 'Today at $time',
      'tomorrow': 'Tomorrow at $time',
      'other': '$date at $time',
    });
    String _temp1 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: '$_temp0',
    );
    return '$_temp1';
  }

  @override
  String notificationDeadlineAt(
    String day,
    String date,
    String time,
    int hour,
  ) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'today': 'Deadline: today at $time',
      'tomorrow': 'Deadline: tomorrow at $time',
      'other': 'Deadline: $date at $time',
    });
    String _temp1 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: '$_temp0',
    );
    return '$_temp1';
  }

  @override
  String get notificationDeadlineToday => 'Deadline: today';

  @override
  String notificationInMinutes(String when, int minutes) {
    return '$when · in $minutes min';
  }

  @override
  String notificationInHours(String when, int hours) {
    return '$when · in $hours h';
  }

  @override
  String notificationCompleted(String title) {
    return 'Completed: $title';
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
  String get captureGone => 'Your words are no longer available.';

  @override
  String get captureNoteLength => 'A note needs 1 to 8000 characters.';

  @override
  String get captureNoTasks =>
      'I didn’t find a task. Say what and when, for example: “Tomorrow, call the dentist.”';

  @override
  String get captureOffline =>
      'No internet. Tap Save as a task, or try again when you’re online.';

  @override
  String get captureOfflineRecording =>
      'No internet. Your recording is kept; try again when you’re online.';

  @override
  String get captureUnavailable =>
      'I can’t turn your words into tasks right now; they’re kept.';

  @override
  String get captureTooFast =>
      'You’ve dictated a lot in a row. Wait a minute, then tap Try again.';

  @override
  String get captureAllowance =>
      'You’ve reached today’s dictation limit. Tap Save as a task, or try again tomorrow.';

  @override
  String get captureAllowanceRecording =>
      'You’ve reached today’s dictation limit. Your recording is kept; try again tomorrow.';

  @override
  String get captureSignIn => 'Sign in again to turn your words into tasks.';

  @override
  String get captureForbidden =>
      'This account can’t turn your words into tasks. Check your access and try again.';

  @override
  String get captureTooLarge =>
      'This recording is too long. Discard it and dictate something shorter.';

  @override
  String get captureTypedFirst =>
      'Save or discard what you typed before starting a recording.';

  @override
  String get captureMicrophone =>
      'Without the microphone I can’t hear you. Tap Start talking to allow it, or Type instead.';

  @override
  String get captureMicrophoneBlocked =>
      'To dictate again, open Settings and tap Permissions › Microphone › Allow.';

  @override
  String get captureOpenSettings => 'Open Settings';

  @override
  String get captureMicrophoneWhy =>
      'Allow the microphone to dictate your tasks. It only listens while you dictate.';

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
  String get captureNothingHeardYet =>
      'Nothing heard yet. Speak when you’re ready, or tap Type instead.';

  @override
  String get captureListeningOnline =>
      'I’m listening. Tap Done to see what I understood.';

  @override
  String captureTimeLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds left',
      one: '1 second left',
    );
    return '$_temp0';
  }

  @override
  String get captureKeepQuestion => 'Keep what you said for later?';

  @override
  String get captureKeepTextQuestion => 'Keep the text for later?';

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
  String get captureCantListen =>
      'I can’t listen on this phone right now. Tap Type instead.';

  @override
  String get captureIncompleteAudio =>
      'This recording can’t be used. Discard it and dictate it again.';

  @override
  String get captureWriteFailed =>
      'Couldn’t keep this on your phone. Try again before leaving.';

  @override
  String get captureStopFailed =>
      'I couldn’t finish listening. What you said before is kept.';

  @override
  String get captureDiscardFailed =>
      'Could not discard your words. They are still kept.';

  @override
  String get captureReviewWriteFailed =>
      'Could not keep these changes. Please try again before leaving.';

  @override
  String get captureSaveFailed =>
      'Couldn’t add it. Your words are still here; try again.';

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
  String get capturesCaughtUp => 'All caught up';

  @override
  String get capturesEmptyHelp =>
      'Recordings and tasks you leave unfinished are kept here.';

  @override
  String captureDraftSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not added yet',
      one: '1 not added yet',
    );
    return '$_temp0';
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
  String captureTasksAddedOn(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added to $date',
      one: '1 task added to $date',
    );
    return '$_temp0';
  }

  @override
  String captureKeptForReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kept for review',
      one: '1 kept for review',
    );
    return '$_temp0';
  }

  @override
  String captureAlsoOn(String date) {
    return 'also on $date';
  }

  @override
  String captureAlsoOnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'also on $count other days',
      one: 'also on 1 other day',
    );
    return '$_temp0';
  }

  @override
  String get captureConfirmDetails => 'Use the details shown';

  @override
  String get captureNothingToReview => 'Nothing left to review';

  @override
  String get captureRemovedDraftsHelp => 'Nothing will change.';

  @override
  String get captureFinish => 'Done';

  @override
  String get captureYourWords => 'Your words';

  @override
  String get captureCheckDetails => 'Check the details above';

  @override
  String get captureUnderstanding => 'Understanding…';

  @override
  String get captureFailed =>
      'That didn’t work. Your words are still here — try again.';

  @override
  String get captureSlow => 'Taking longer than usual.';

  @override
  String get captureSaveAsWritten => 'Save as a task';

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
      'To make changes, ask the project’s owner.';

  @override
  String get loadTaskError => 'Couldn’t load this task';

  @override
  String deleteSeriesHelp(String title) {
    return '“$title” and all its occurrences will be removed.';
  }

  @override
  String get viewOnlyTask => 'You can only view this task.';

  @override
  String get viewOnlyTaskReminders =>
      'You can only view this task and choose your reminders.';

  @override
  String get syncCopySuffix => '(offline copy)';

  @override
  String get stepUpdateError => 'Could not update this step. Please retry.';

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
      'recognizerFinish': 'Last words after Done',
      'other': 'Other capture event',
    });
    return '$_temp0';
  }

  @override
  String get taskflowPro => 'TaskFlow Pro';

  @override
  String get proBenefitDictation =>
      'Unlimited dictation, and 500 MB of files a month';

  @override
  String get proBenefitTyping => 'Sentences you type become tasks';

  @override
  String get proBenefitReminders => 'Ask for reminders in your own words';

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
      'Test purchases only. No real payment will be taken. An active test subscription gives what Pro gives in this development build.';

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
  String get billingRestoreHelp =>
      'Already subscribed? Use the same store account, then restore purchases. Cancelling renewal keeps Pro available until your paid access ends.';

  @override
  String billingError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'unsupportedPlatform': 'Subscriptions are available in the Android app.',
      'configuration':
          'Subscriptions are not available yet. Please try again later.',
      'accountUnavailable': 'Could not connect to your TaskFlow account. Check your connection and open this screen again.',
      'network': 'Could not check your subscription. Check your connection and open this screen again.',
      'notAllowed':
          'Purchases are restricted for this store account or device.',
      'otherAccount': 'This purchase belongs to another account. Sign in to the original account to restore it.',
      'store': 'The store didn’t answer. Open this screen again.',
      'other': 'The store didn’t answer. Open this screen again.',
    });
    return '$_temp0';
  }

  @override
  String billingResult(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'active': 'TaskFlow Pro is active.',
      'restored': 'Your Pro subscription was restored.',
      'noPurchases': 'No active Pro purchase was found for this account.',
      'awaitingEntitlement': 'Purchase received. Pro will turn on in a few moments; if it doesn’t, tap Restore purchases.',
      'updated': 'Subscription status updated.',
      'pending': 'Payment is pending. Pro will activate after the store confirms payment.',
      'busy': 'Please wait for the current operation to finish.',
      'accountChanged': 'The account changed. Check the subscription on the purchasing account.',
      'other': 'The request could not be completed. Please try again.',
    });
    return '$_temp0';
  }

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithEmail => 'Continue with email';

  @override
  String get invitationWaitingSignIn =>
      'You have an invitation. Sign in with the email address it was sent to.';

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
      'google_not_configured': 'Google sign-in is not available yet. Use email and password for now.',
      'google_link_required': 'This email already has a TaskFlow account. Sign in with your password, then choose Link Google account.',
      'google_password_required':
          'Enter your current TaskFlow password to link Google.',
      'google_email_mismatch': 'Choose the Google account with the same email as your TaskFlow account.',
      'google_already_linked': 'This Google account is already linked. Sign in to the original TaskFlow account.',
      'google_account_changed':
          'Your account changed during sign-in. Please try again.',
      'google_invalid_token':
          'Google could not verify your sign-in. Please try again.',
      'other': 'Google sign-in could not finish. Check your connection and try again.',
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
  String get audienceShared => 'All members can see it.';

  @override
  String shareTaskConfirm(String name) {
    return 'Share with $name? Everyone there will see this task. It can’t be made private again.';
  }

  @override
  String get shareTask => 'Share';

  @override
  String get sharedTaskStays => 'Shared tasks stay in their project.';

  @override
  String shareNoteConfirm(String name) {
    return 'Share with $name? Everyone there will see this note. It can’t be made private again.';
  }

  @override
  String get sharedNoteStays => 'Shared notes stay in their project.';

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
  String get groupHelp =>
      'Invite people once and share several projects with them.';

  @override
  String get groupMembers => 'Members';

  @override
  String get groupAdmin => 'Administrator';

  @override
  String get groupProjects => 'Group projects';

  @override
  String get groupInviteHelp =>
      'They’ll see every project in this group. We’ll email them an invitation.';

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
  String get groupDeleteAction => 'Delete group';

  @override
  String groupDeleteConfirm(String name) {
    return 'Delete “$name”? Its members will lose it. This can’t be undone.';
  }

  @override
  String groupTransferConfirm(String group, String person) {
    return 'Transfer “$group” to $person?';
  }

  @override
  String groupTransferAction(String person) {
    return 'Transfer to $person';
  }

  @override
  String get groupActionError =>
      'This change could not be saved. Check your connection and refresh; permissions may have changed.';

  @override
  String get groupVoiceName => 'Name for voice assignments';

  @override
  String get groupVoiceHelp =>
      'An optional name others can use when assigning tasks by voice.';

  @override
  String get createGroup => 'Create group';

  @override
  String get enterName => 'Enter a name.';

  @override
  String groupRoleQuestion(String name) {
    return 'What can $name do?';
  }

  @override
  String get groupInvited => 'Invited';

  @override
  String get invitationPending => 'Pending';

  @override
  String get loadFailed => 'Couldn’t load. Check your connection.';

  @override
  String get projectDestination => 'Where does this project belong?';

  @override
  String get projectNotifications => 'Project updates';

  @override
  String get updatesAll => 'All changes';

  @override
  String get updatesAssigned => 'Only what’s for me';

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
  String get activityUpdated => 'Updated the task';

  @override
  String get activityMoved => 'Moved the task';

  @override
  String get activityAssigned => 'Changed responsibility';

  @override
  String get activityCompleted => 'Completed a task';

  @override
  String get activityReopened => 'Reopened a task';

  @override
  String get activityDeleted => 'Deleted a task';

  @override
  String get activityUnassigned => 'Removed the assignee';

  @override
  String get activitySystem => 'TaskFlow';

  @override
  String get groupActivity => 'Updates';

  @override
  String get activityUnread => 'Unread';

  @override
  String get activityFindingTask => 'Finding the task…';

  @override
  String activityEntry(String action, String actor, String title) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'created': '$actor created: $title',
      'assigned': '$actor changed who’s responsible for: $title',
      'unassigned': '$actor removed the assignee of: $title',
      'completed': '$actor completed: $title',
      'reopened': '$actor reopened: $title',
      'moved': '$actor moved: $title',
      'deleted': '$actor deleted: $title',
      'shared': '$actor shared: $title',
      'other': '$actor updated: $title',
    });
    return '$_temp0';
  }

  @override
  String activityAssignedYou(String actor, String title) {
    return '$actor assigned you: $title';
  }

  @override
  String activityAssignedTo(String actor, String name, String title) {
    return '$actor assigned $name: $title';
  }

  @override
  String get captureSpeakingIsPro =>
      'Speaking a task is part of TaskFlow Pro. You can type it here.';

  @override
  String get voiceProAction => 'Explore Pro';

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
  String get invitationViewerAccess =>
      'You’ll be able to see it, not change it.';

  @override
  String get invitationAdminAccess => 'You’ll be able to manage the group.';

  @override
  String get close => 'Close';

  @override
  String get stagingInviteOnly =>
      'This private test build is for invited testers. Ask the TaskFlow owner for an invitation to this email address.';

  @override
  String freeVoiceLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free dictations left this month',
      one: '1 free dictation left this month',
      zero: 'No free dictations left this month',
    );
    return '$_temp0';
  }

  @override
  String freeVoiceUsedUp(String date) {
    return 'No free dictations until $date.';
  }

  @override
  String freeVoiceUsedUpRecording(String date) {
    return 'Your recording is kept. It can be understood from $date, or now with Pro.';
  }

  @override
  String get captureClose => 'Close';

  @override
  String freeVoiceStatus(int left, int limit, String date) {
    return 'Free dictations: $left of $limit left this month. More on $date.';
  }

  @override
  String get newTask => 'New task';

  @override
  String get pickDay => 'Pick a day';

  @override
  String get removeTime => 'Remove time';

  @override
  String createdBy(String name) {
    return 'Created by $name';
  }

  @override
  String get createdByYou => 'Created by you';

  @override
  String freeVoiceNoticeTitle(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'You’ve used your $limit free dictations for this month',
      one: 'You’ve used your free dictation for this month',
    );
    return '$_temp0';
  }

  @override
  String freeVoiceNoticeBody(int limit, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'On $date you’ll get $limit more dictations.',
      one: 'On $date you’ll get 1 more dictation.',
    );
    return 'You can keep creating tasks by hand, with no limit. $_temp0';
  }

  @override
  String get freeVoiceNoticeCreate => 'Create a task';

  @override
  String storageUsage(int used, int limit) {
    return 'Files uploaded: $used of $limit MB';
  }

  @override
  String storageFull(int limit) {
    return 'You’ve used the $limit MB of files included for free.';
  }

  @override
  String get storageFullShared =>
      'This project’s owner can’t upload more files right now.';

  @override
  String storageUsageMonth(int used, int limit) {
    return 'Files uploaded this month: $used of $limit MB';
  }

  @override
  String storageMonthFull(int limit, String date) {
    return 'You’ve used this month’s $limit MB of files. You can add more from $date.';
  }

  @override
  String filesDeletedOn(String date) {
    return 'These files will be deleted on $date, 15 days after the task was completed.';
  }

  @override
  String get filesDeletedAfterDone =>
      'Files on a completed task are deleted 15 days after it was completed.';

  @override
  String get projectPinned => 'Pinned';

  @override
  String projectSharedRole(String role) {
    return 'Shared · $role';
  }

  @override
  String projectGroupSees(String group) {
    return 'Everyone in $group will see it.';
  }

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountIntro =>
      'This deletes your TaskFlow account and your tasks, notes and files on all your devices. It can’t be undone.';

  @override
  String get deleteAccountWhatGoes => 'What will be deleted:';

  @override
  String deleteAccountTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects',
      one: '1 project',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptShared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks you added to shared projects, without your name',
      one: '1 task you added to shared projects, without your name',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files you added to shared projects, without your name',
      one: '1 file you added to shared projects, without your name',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountHandover(String kind, String name, String person) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'group': 'The group “$name” and its projects will go to $person',
      'other': 'The project “$name” will go to $person',
    });
    return '$_temp0';
  }

  @override
  String get deleteAccountWhatStays => 'What stays for the others:';

  @override
  String get deleteAccountSubscription =>
      'If you pay for TaskFlow Pro on Google Play, deleting your account doesn’t cancel the subscription.';

  @override
  String get deleteAccountSaveCopy => 'Save a copy of your tasks first';

  @override
  String get deleteAccountCopySaved => 'Copy saved';

  @override
  String get deleteAccountCopyNoFiles => 'The copy doesn’t include files.';

  @override
  String get deleteAccountPasswordHelp => 'To confirm, enter your password.';

  @override
  String deleteAccountGoogleHelp(String email) {
    return 'To confirm, choose $email when Google asks. Your Google account isn’t deleted.';
  }

  @override
  String deleteAccountGoogleInstead(String email) {
    return 'Or confirm with Google and choose $email. Your Google account isn’t deleted.';
  }

  @override
  String get deleteAccountConfirmGoogle => 'Confirm with Google';

  @override
  String get deleteAccountGoogleConfirmed => 'Confirmed with Google';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountDeleting => 'Deleting your account…';

  @override
  String get deleteAccountWrongPassword =>
      'That password isn’t right. If you don’t remember it, sign out and tap “Forgot password?”';

  @override
  String get deleteAccountWrongPasswordGoogle =>
      'That password isn’t right. If you don’t remember it, tap “Confirm with Google”.';

  @override
  String deleteAccountOtherGoogle(String email) {
    return 'Choose $email, the Google account you use for TaskFlow.';
  }

  @override
  String get deleteAccountOffline =>
      'You need a connection to delete your account. Nothing was deleted.';

  @override
  String get deleteAccountNoAnswer =>
      'There was no answer. Check your connection and try again.';

  @override
  String get deleteAccountThrottled => 'Too many tries. Try again later.';

  @override
  String tooManyTriesWait(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Too many tries. Wait $minutes minutes and try again.',
      one: 'Too many tries. Wait a minute and try again.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountPlanChanged =>
      'Something has changed since you opened this screen. Check what will happen and confirm again.';

  @override
  String get deleteAccountChangedIntro =>
      'Something has changed since you opened this screen:';

  @override
  String get deleteAccountChangedCheck => 'Check it and confirm again.';

  @override
  String get deleteAccountConfirmAgain => 'Confirm it’s you again.';

  @override
  String get deleteAccountFailed =>
      'Your account couldn’t be deleted. Try again later.';

  @override
  String get webPageOpenError => 'Couldn’t open the page.';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String commandNewProject(String name) {
    return 'New project: $name';
  }

  @override
  String commandNewProjectChip(String name) {
    return '$name (new)';
  }

  @override
  String get commandUseName => 'Use this name';

  @override
  String get commandRenameProject => 'Change the name';

  @override
  String commandExistingProject(String name) {
    return 'You already have “$name”';
  }

  @override
  String commandExistingProjectTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The tasks go there.',
      one: 'The task goes there.',
    );
    return '$_temp0';
  }

  @override
  String commandCreateProjectQuestion(String name) {
    return 'Create the project “$name”?';
  }

  @override
  String commandCreateNamed(String name) {
    return 'Create “$name”';
  }

  @override
  String get commandWhichProject => 'Which project should it go in?';

  @override
  String get commandOtherProject => 'Another project…';

  @override
  String get commandWhichProjectOfTasks => 'Which project?';

  @override
  String commandCreateProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count projects',
      one: 'Create project',
    );
    return '$_temp0';
  }

  @override
  String get commandAddAndChange => 'Add and change';

  @override
  String get commandAddAndDelete => 'Add and delete';

  @override
  String get commandChangeAndDelete => 'Change and delete';

  @override
  String get commandAddChangeAndDelete => 'Add, change and delete';

  @override
  String commandDontDelete(String title) {
    return 'Don’t delete $title';
  }

  @override
  String commandDontChange(String title) {
    return 'Don’t change $title';
  }

  @override
  String get commandDontChangeAny => 'Don’t change any';

  @override
  String get commandDontDeleteAny => 'Don’t delete any';

  @override
  String commandDontCreate(String name) {
    return 'Don’t create $name';
  }

  @override
  String commandWontDelete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Won’t be deleted',
      one: 'Won’t be deleted',
    );
    return '$_temp0';
  }

  @override
  String commandWontChange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Won’t be changed',
      one: 'Won’t be changed',
    );
    return '$_temp0';
  }

  @override
  String get commandWontCreate => 'Won’t be created';

  @override
  String commandFindWords(String words) {
    return 'Tasks with “$words”';
  }

  @override
  String commandFindProject(String name) {
    return 'Tasks in “$name”';
  }

  @override
  String commandFindPerson(String name) {
    return 'Tasks for $name';
  }

  @override
  String get commandFindMine => 'Your tasks';

  @override
  String commandFindProjectPerson(String project, String name) {
    return 'Tasks in “$project” for $name';
  }

  @override
  String commandFindProjectMine(String project) {
    return 'Your tasks in “$project”';
  }

  @override
  String commandFindPeriod(String from, String to) {
    return '$from to $to';
  }

  @override
  String get commandFindOpen => 'To do';

  @override
  String get commandFindDone => 'Completed';

  @override
  String get commandCompleted => 'Completed';

  @override
  String commandFindNone(String words) {
    return 'There’s no task with “$words”';
  }

  @override
  String get commandFindNoneAtAll => 'There are no tasks';

  @override
  String commandMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'And $count more',
      one: 'And 1 more',
    );
    return '$_temp0';
  }

  @override
  String commandShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more',
      one: 'Show 1 more',
    );
    return '$_temp0';
  }

  @override
  String commandOpenProject(String name) {
    return 'Open “$name”';
  }

  @override
  String commandProjectNotFound(String name) {
    return 'Can’t find the project “$name”';
  }

  @override
  String commandPersonNotFound(String name) {
    return 'Can’t find $name';
  }

  @override
  String commandTaskNotFound(String words) {
    return 'Can’t find a task with “$words”';
  }

  @override
  String get commandTaskNotFoundPlain => 'Can’t find that task';

  @override
  String commandViewOnly(String title) {
    return '“$title” is in a project you can only view.';
  }

  @override
  String get commandWhichToChange => 'Which one do you want to change?';

  @override
  String get commandWhichToDelete => 'Which one do you want to delete?';

  @override
  String commandWillDelete(String title) {
    return 'Will be deleted: $title';
  }

  @override
  String commandWillDeleteOn(String title, String date) {
    return 'Will be deleted: $title ($date)';
  }

  @override
  String get commandChooseAnother => 'Choose another';

  @override
  String get commandNothingToChange => 'It’s already like that.';

  @override
  String commandWhichDay(int hour, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: 'Which day, at $time?',
    );
    return '$_temp0';
  }

  @override
  String commandMemberNotIn(String name, String project) {
    return '$name isn’t in “$project”';
  }

  @override
  String commandMemberNotInNew(String name, String project) {
    return '$name isn’t in “$project” yet. Afterwards, share the project with $name.';
  }

  @override
  String get commandAssignNeedsShared =>
      'Only tasks in shared projects can be assigned.';

  @override
  String commandAmbiguousMember(String name) {
    return 'More than one person is called $name.';
  }

  @override
  String commandTasksChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks changed',
      one: 'Task changed',
    );
    return '$_temp0';
  }

  @override
  String commandTasksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks deleted',
      one: 'Task deleted',
    );
    return '$_temp0';
  }

  @override
  String commandDeletedTitle(String title) {
    return 'Deleted: $title';
  }

  @override
  String commandProjectsCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects created',
      one: 'Project created',
    );
    return '$_temp0';
  }

  @override
  String commandChangeSemantics(String label, String before, String after) {
    return '$label: from $before to $after';
  }

  @override
  String commandChangeLine(String label, String before, String after) {
    return '$label: $before → $after';
  }

  @override
  String commandChangeLineFrom(String label, String before) {
    return '$label: $before →';
  }

  @override
  String commandNotesAdd(String text) {
    return 'Added to the notes: $text';
  }

  @override
  String get commandAssignee => 'Assignee';

  @override
  String get commandMarkDone => 'Mark as done';

  @override
  String get commandWhichToComplete => 'Which one do you want to mark as done?';

  @override
  String commandDontComplete(String title) {
    return 'Don’t complete $title';
  }

  @override
  String get commandDontCompleteAny => 'Don’t complete any';

  @override
  String commandWontComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Won’t be completed',
      one: 'Won’t be completed',
    );
    return '$_temp0';
  }

  @override
  String commandTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks completed',
      one: 'Task completed',
    );
    return '$_temp0';
  }

  @override
  String commandTasksMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks moved',
      one: 'Task moved',
    );
    return '$_temp0';
  }

  @override
  String commandTasksMovedTo(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks moved to $date',
      one: 'Task moved to $date',
    );
    return '$_temp0';
  }

  @override
  String commandTasksAssignedTo(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks assigned to $name',
      one: 'Task assigned to $name',
    );
    return '$_temp0';
  }

  @override
  String commandBulkMoveTo(int count, String when, String day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to today, $day',
      one: 'Move 1 task to today, $day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to tomorrow, $day',
      one: 'Move 1 task to tomorrow, $day',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to $day',
      one: 'Move 1 task to $day',
    );
    String _temp3 = intl.Intl.selectLogic(when, {
      'today': '$_temp0',
      'tomorrow': '$_temp1',
      'other': '$_temp2',
    });
    return '$_temp3';
  }

  @override
  String commandBulkMoveLead(int count, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to',
      one: 'Move 1 task to',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to',
      one: 'Move 1 task to',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks to',
      one: 'Move 1 task to',
    );
    String _temp3 = intl.Intl.selectLogic(when, {
      'today': '$_temp0',
      'tomorrow': '$_temp1',
      'other': '$_temp2',
    });
    return '$_temp3';
  }

  @override
  String commandMoveDay(String when, String day) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today, $day',
      'tomorrow': 'tomorrow, $day',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String commandBulkShift(int count, String span, String direction) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks $span earlier',
      one: 'Move 1 task $span earlier',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks $span later',
      one: 'Move 1 task $span later',
    );
    String _temp2 = intl.Intl.selectLogic(direction, {
      'earlier': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String commandBulkSpan(int amount, String unit) {
    String _temp0 = intl.Intl.pluralLogic(
      amount,
      locale: localeName,
      other: '$amount weeks',
      one: 'a week',
    );
    String _temp1 = intl.Intl.pluralLogic(
      amount,
      locale: localeName,
      other: '$amount days',
      one: 'a day',
    );
    String _temp2 = intl.Intl.selectLogic(unit, {
      'weeks': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String commandBulkMove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count tasks',
      one: 'Move 1 task',
    );
    return '$_temp0';
  }

  @override
  String commandBulkAssignTo(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assign $count tasks to $name',
      one: 'Assign 1 task to $name',
    );
    return '$_temp0';
  }

  @override
  String commandBulkAssign(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assign $count tasks',
      one: 'Assign 1 task',
    );
    return '$_temp0';
  }

  @override
  String commandBulkChange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Change $count tasks',
      one: 'Change 1 task',
    );
    return '$_temp0';
  }

  @override
  String commandBulkComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mark $count tasks as done',
      one: 'Mark 1 task as done',
    );
    return '$_temp0';
  }

  @override
  String commandBulkDelete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count tasks',
      one: 'Delete 1 task',
    );
    return '$_temp0';
  }

  @override
  String commandBulkField(String label, String value) {
    return '$label: $value';
  }

  @override
  String commandBulkLeftRepeating(int count, String action, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeating tasks won’t be deleted',
      one: '$title repeats: it won’t be deleted',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeating tasks won’t be completed',
      one: '$title repeats: it won’t be completed',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeating tasks won’t be reopened',
      one: '$title repeats: it won’t be reopened',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeating tasks won’t change',
      one: '$title repeats: it won’t change',
    );
    String _temp4 = intl.Intl.selectLogic(action, {
      'delete': '$_temp0',
      'complete': '$_temp1',
      'reopen': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
  }

  @override
  String commandBulkLeftUnassignable(int count, String name, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks can’t be assigned to $name',
      one: '$title can’t be assigned to $name',
    );
    return '$_temp0';
  }

  @override
  String commandBulkLeftNoDay(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks with no date won’t change',
      one: '$title has no date: it won’t change',
    );
    return '$_temp0';
  }

  @override
  String commandBulkNone(String status, String period) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'completed': 'There are no completed tasks $period',
      'any': 'There are no tasks $period',
      'other': 'There are no tasks to do $period',
    });
    return '$_temp0';
  }

  @override
  String commandBulkPeriod(String kind, String from, String to) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'today': 'for today',
      'yesterday': 'from yesterday',
      'tomorrow': 'for tomorrow',
      'range': 'from $from to $to',
      'until': 'up to $to',
      'since': 'from $from on',
      'undated': 'with no date',
      'other': 'on $from',
    });
    return '$_temp0';
  }

  @override
  String commandBulkTooMany(int count) {
    return 'That’s $count tasks, too many. Say it again with one day or one project.';
  }

  @override
  String commandBulkNothingToChange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They’re already like that.',
      one: 'It’s already like that.',
    );
    return '$_temp0';
  }

  @override
  String commandBulkViewOnly(String project) {
    return 'You can only view “$project”: its tasks stay as they are.';
  }

  @override
  String get commandNoDayStays => 'It has no date, so it stays.';

  @override
  String get commandAlreadyDone => 'It was already done.';

  @override
  String get commandMarkNotDone => 'Mark as not done';

  @override
  String get commandWhichToReopen =>
      'Which one do you want to mark as not done?';

  @override
  String commandDontReopen(String title) {
    return 'Don’t reopen $title';
  }

  @override
  String get commandDontReopenAny => 'Don’t reopen any';

  @override
  String commandWontReopen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Won’t be reopened',
      one: 'Won’t be reopened',
    );
    return '$_temp0';
  }

  @override
  String get commandNotDoneYet => 'It wasn’t done.';

  @override
  String commandBulkReopen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mark $count tasks as not done',
      one: 'Mark 1 task as not done',
    );
    return '$_temp0';
  }

  @override
  String commandReopenedTitle(String title) {
    return 'Not done: $title';
  }

  @override
  String commandTasksReopened(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks reopened',
      one: 'Task reopened',
    );
    return '$_temp0';
  }

  @override
  String get reminderPlanUntilDay => 'Until the deadline';

  @override
  String get reminderPlanGentle => 'Gentle';

  @override
  String get reminderPlanNormal => 'Normal';

  @override
  String get reminderPlanIntense => 'Intense';

  @override
  String get reminderPlanYourWay => 'Your way';

  @override
  String get reminderPlanYourWayHint =>
      'For example: “a week before, and the day before at 8”.';

  @override
  String get reminderPlanJustYou => 'These reminders are only for you.';

  @override
  String get proBadge => 'Pro';

  @override
  String get reminderPlanSpeak => 'Say it';

  @override
  String get reminderPlanStopListening => 'Stop listening';

  @override
  String get reminderPlanReading => 'One moment…';

  @override
  String get reminderPlanUnclear =>
      'I didn’t get that. Try saying it another way.';

  @override
  String get reminderPlanOffline =>
      'This needs a connection. “Until the deadline” works without one.';

  @override
  String get reminderPlanFailed =>
      'I couldn’t read that just now. Try again later, or choose “Until the deadline”.';

  @override
  String get reminderPlanMicOff =>
      'Without the microphone I can’t hear you. You can type it.';

  @override
  String get reminderPlanCantListen =>
      'I can’t listen on this phone right now. You can type it.';

  @override
  String reminderPlanCount(int count, String when, String date, String time) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    String _temp1 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders · next: $_temp0, $time',
      one: '1 reminder: $_temp1, $time',
    );
    return '$_temp2';
  }

  @override
  String get reminderPlanNoneLeft => 'No reminders left';

  @override
  String reminderPlanGrowing(String when, String date) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'until today',
      'tomorrow': 'until tomorrow',
      'other': 'until $date',
    });
    return 'More and more often $_temp0';
  }

  @override
  String reminderPlanEveryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'every $days days',
      one: 'daily',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanEveryWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'every $weeks weeks',
      one: 'weekly',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'for the last $days days',
      one: 'for the last day',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanLastWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'for the last $weeks weeks',
      one: 'for the last week',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanFromDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'from $days days before',
      one: 'from the day before',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanFromWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'from $weeks weeks before',
      one: 'from a week before',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanUntilDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'until $days days before',
      one: 'until the day before',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanUntilWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'until $weeks weeks before',
      one: 'until a week before',
    );
    return '$_temp0';
  }

  @override
  String get reminderPlanOnTheDay => 'on the day';

  @override
  String reminderPlanDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: 'the day before',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanWeeksBefore(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks before',
      one: 'a week before',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanPhase(String rhythm, String window) {
    return '$rhythm $window';
  }

  @override
  String reminderPlanAnd(String first, String last) {
    return '$first, and $last';
  }

  @override
  String reminderPlanList(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String reminderPlanLine(String plan, String when, String date, String time) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'today',
      'tomorrow': 'tomorrow',
      'other': '$date',
    });
    return '$plan · next: $_temp0, $time';
  }

  @override
  String reminderPlanStrengthLine(String strength, String when, String date) {
    String _temp0 = intl.Intl.selectLogic(strength, {
      'gentle': 'Gentle',
      'normal': 'Normal',
      'other': 'Intense',
    });
    String _temp1 = intl.Intl.selectLogic(when, {
      'today': 'until today',
      'tomorrow': 'until tomorrow',
      'other': 'until $date',
    });
    return '$_temp0 reminders $_temp1';
  }

  @override
  String reminderPlanOwnLine(String rhythm) {
    return 'Reminders: $rhythm';
  }

  @override
  String reminderPlanNoticeDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left · $date',
      one: '1 day left · $date',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanNoticeDeadlineDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Deadline: $date · $days days left',
      one: 'Deadline: $date · 1 day left',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanNoticeTomorrowAt(int hour, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: 'It’s tomorrow at $time',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanNoticeTodayAt(int hour, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: 'It’s today at $time',
    );
    return '$_temp0';
  }

  @override
  String get reminderPlanNoticeDeadlineTomorrow => 'Deadline: tomorrow';

  @override
  String get reminderPlanNoticeTomorrow => 'It’s tomorrow';

  @override
  String get reminderPlanNoticeToday => 'It’s today';

  @override
  String get reminderPlanNoticeWas => 'It was planned for yesterday';

  @override
  String get reminderPlanNoticeDue => 'It was due yesterday';

  @override
  String reminderPlanOfferWeeks(int weeks, String rhythm) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks to go. Shall I remind you $rhythm?',
      one: '1 week to go. Shall I remind you $rhythm?',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanOfferMonths(int months, String rhythm) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months to go. Shall I remind you $rhythm?',
      one: '1 month to go. Shall I remind you $rhythm?',
    );
    return '$_temp0';
  }

  @override
  String reminderPlanOfferDone(String date) {
    return 'Done. I’ll remind you until $date.';
  }

  @override
  String get billingReasonReminderPlans =>
      'With Pro, ask for reminders in your own words:';

  @override
  String get billingReasonReminderPlansExample =>
      '“a week before, and the day before at 8”';

  @override
  String get meetingRecord => 'Record a meeting';

  @override
  String get meetingButton => 'Meeting';

  @override
  String get meetingScreenTitle => 'Meeting';

  @override
  String get meetingListening => 'Recording';

  @override
  String get meetingListeningHelp =>
      'You can leave or lock the phone: it keeps recording until you press Stop.';

  @override
  String get meetingStop => 'Stop';

  @override
  String get meetingDiscardQuestion =>
      'Discard this recording? It’s deleted from your phone and can’t be recovered.';

  @override
  String get meetingKeepRecording => 'Keep recording';

  @override
  String get meetingPreparing => 'Preparing your notes…';

  @override
  String get meetingPreparingHelp =>
      'It takes a few seconds. You can leave this screen: we’ll let you know when they’re ready.';

  @override
  String get meetingPreparingHelpNoNotice =>
      'It takes a few seconds. You can leave this screen: the notes will be in Notes.';

  @override
  String get meetingWaitingConnection => 'Waiting for connection';

  @override
  String get meetingWaitingConnectionHelp =>
      'Your recording is safe on this phone. The notes are made once you’re back online, and we’ll let you know.';

  @override
  String get meetingWaitingConnectionHelpNoNotice =>
      'Your recording is safe on this phone. The notes are made once you’re back online, and they’ll be in Notes.';

  @override
  String get meetingNothingHeard =>
      'Nothing was heard, so there’s nothing to save.';

  @override
  String get meetingStopFailed =>
      'Couldn’t finish stopping. What was recorded is safe: press Stop again.';

  @override
  String get meetingQuietQuestion =>
      'Almost nothing was heard. Make notes anyway?';

  @override
  String meetingRecordingToday(String time) {
    return 'Recording from today, $time';
  }

  @override
  String meetingRecordingYesterday(String time) {
    return 'Recording from yesterday, $time';
  }

  @override
  String meetingRecordingOn(String date, String time) {
    return 'Recording from $date, $time';
  }

  @override
  String meetingStoppedCut(String recording, String length) {
    return '$recording · $length. It stopped before you pressed Stop.';
  }

  @override
  String meetingStoppedQuiet(String recording, String length) {
    return '$recording · $length. Almost nothing was heard.';
  }

  @override
  String get meetingMakeNotes => 'Make the notes';

  @override
  String meetingRecordingNow(String time) {
    return 'Recording a meeting · $time';
  }

  @override
  String meetingRecordingUnstopped(String length) {
    return 'Recording not fully stopped · $length. Open it and press Stop.';
  }

  @override
  String get meetingOpen => 'Open';

  @override
  String get meetingOpenNamed => 'Open the recording';

  @override
  String get meetingLengthUnderMinute => 'under 1 min';

  @override
  String meetingLengthHours(int hours) {
    return '$hours h';
  }

  @override
  String meetingLengthHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String meetingRecordedSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds recorded',
      one: '1 second recorded',
    );
    return '$_temp0';
  }

  @override
  String meetingRecordedMinutes(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0 $_temp1 recorded';
  }

  @override
  String meetingRecordedHours(int hours, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    String _temp2 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0 $_temp1 $_temp2 recorded';
  }

  @override
  String get meetingProRequired =>
      'Meeting notes are part of TaskFlow Pro. Your recording waits on this phone.';

  @override
  String get meetingAllowanceUsed =>
      'You’ve used this month’s meeting time. Your recording waits on this phone until next month.';

  @override
  String get meetingAllowanceUsedStart =>
      'You’ve used this month’s meeting time: you can record, and the notes come next month.';

  @override
  String get meetingCantMakeNotes =>
      'Part of this recording couldn’t be sent, so no notes can be made from it.';

  @override
  String get meetingMicrophoneBlocked =>
      'To record a meeting, open Settings and tap Permissions › Microphone › Allow.';

  @override
  String get meetingMicrophoneNeeded =>
      'To record a meeting, TaskFlow needs the microphone.';

  @override
  String get meetingAllowMicrophone => 'Allow the microphone';

  @override
  String get meetingLowSpace =>
      'Your phone is almost full. Free up some space to record a meeting.';

  @override
  String get meetingSpaceLowWarning =>
      'Low on space: the recording stops by itself if the phone fills up.';

  @override
  String get meetingStartFailed => 'The recording couldn’t start. Try again.';

  @override
  String get meetingStoppedNoSpace =>
      'Your phone ran out of space, so the recording stopped.';

  @override
  String get meetingMicrophoneFailed =>
      'The microphone stopped working, so the recording stopped.';

  @override
  String get meetingNoticeTitle => 'Recording a meeting';

  @override
  String get meetingTypeHere => 'A meeting is recording: type here.';

  @override
  String get meetingRecordingChannel => 'Meeting recording';

  @override
  String get meetingNotesChannel => 'Meeting notes';

  @override
  String get meetingNotesReady => 'Your meeting notes are ready';

  @override
  String get meetingNoteDecisions => 'Decisions';

  @override
  String get meetingNoteOpenQuestions => 'Open questions';

  @override
  String get meetingNoteChapters => 'Parts of the meeting';

  @override
  String get meetingNoteSteps => 'Steps of each task';

  @override
  String meetingNoteTaskCount(int done, int total) {
    return 'Tasks · $done/$total';
  }

  @override
  String meetingNoteTaskSemantics(int done, int total) {
    return 'Tasks: $done of $total done';
  }

  @override
  String reviewStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get meetingNoteStartMissing =>
      'The start of this recording expired, so these notes cover only the rest.';

  @override
  String get meetingNoteUntitled => 'Meeting notes';

  @override
  String meetingNoteHeader(String date, String length) {
    return 'Meeting on $date · $length';
  }

  @override
  String meetingNoteChapterMinutes(int start, int end) {
    return 'Minutes $start–$end';
  }

  @override
  String meetingCreateTask(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create tasks',
      one: 'Create task',
    );
    return '$_temp0';
  }

  @override
  String get meetingStepsToAdd => 'Steps to add';

  @override
  String meetingViewTask(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View tasks',
      one: 'View task',
    );
    return '$_temp0';
  }

  @override
  String get meetingSuggestedTitle => 'Suggested tasks';

  @override
  String get meetingSuggestedHelp => 'From this meeting. Tick the ones to add.';

  @override
  String meetingSuggestedAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count tasks',
      one: 'Add 1 task',
      zero: 'Add tasks',
    );
    return '$_temp0';
  }

  @override
  String meetingSuggestedAddAll(int count) {
    return 'Add all $count';
  }

  @override
  String get meetingSuggestedMaybe => 'Maybe';

  @override
  String get meetingSuggestedReview => 'Review before adding';

  @override
  String get meetingSuggestedFailed => 'Couldn’t add the tasks. Try again.';

  @override
  String get meetingSignOutTitle => 'Sign out?';

  @override
  String get meetingSignOutRecording =>
      'You’re recording a meeting. It stops, and its notes are made before you sign out.';

  @override
  String meetingSignOutQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The notes of $count meetings aren’t ready yet, and their recordings are only on this phone.',
      one: 'A meeting’s notes aren’t ready yet, and its recording is only on this phone.',
    );
    return '$_temp0';
  }

  @override
  String get meetingSignOutReminders =>
      'Reminders on this phone stop until you sign in again.';

  @override
  String get meetingSendFirst => 'Save notes and sign out';

  @override
  String get meetingDiscardAndSignOut => 'Discard and sign out';

  @override
  String get meetingSending => 'Sending your recording…';

  @override
  String get meetingSavingNotes =>
      'Saving your meeting’s notes… This can take a few minutes. Then you’ll be signed out.';

  @override
  String get meetingSendFailed =>
      'No connection, so the notes couldn’t be made. You’re still signed in; tap Sign out again once you’re online.';

  @override
  String get meetingSendSlow =>
      'The notes are taking longer than usual. You’re still signed in; try Sign out again in a few minutes.';

  @override
  String get meetingNotesExpired =>
      'This recording was kept too long without being finished, so no notes can be made from it.';

  @override
  String get meetingSendFailedPro =>
      'Your recording can’t be sent without TaskFlow Pro. Stay signed in to keep it, or discard it.';

  @override
  String get meetingSendFailedAllowance =>
      'You’ve used this month’s meeting time, so your recording can’t be sent until next month. Stay signed in to keep it, or discard it.';

  @override
  String get meetingSendFailedLost =>
      'A recording can’t become notes any more. Discard it to sign out.';

  @override
  String meetingDiscardDeletesAll(int count) {
    return 'Discard and sign out deletes all $count waiting recordings.';
  }

  @override
  String meetingDiscardNamed(String time) {
    return 'Discard the recording of $time';
  }

  @override
  String meetingFinishNamed(String time) {
    return 'Make the notes from the recording of $time';
  }

  @override
  String meetingContinueNamed(String time) {
    return 'Keep recording, $time so far';
  }

  @override
  String get billingReasonMeetingNotes =>
      'With Pro, your meetings become notes:';

  @override
  String get billingReasonMeetingNotesExample =>
      'a summary, the decisions and the to-dos';

  @override
  String proBenefitMeetingNotes(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Notes from your recorded meetings, up to $hours hours a month',
      one: 'Notes from your recorded meetings, up to 1 hour a month',
    );
    return '$_temp0';
  }

  @override
  String get meetingAudioDeleted =>
      'The audio is sent to make the notes, then deleted.';

  @override
  String get meetingNotifyAsk =>
      'Turn on notifications to stop the recording from there and to know when the notes are ready.';

  @override
  String get meetingNotifyAskContinue => 'Continue';

  @override
  String billingReasonMeetingNotesLimit(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Up to $hours hours of meetings a month.',
      one: 'Up to 1 hour of meetings a month.',
    );
    return '$_temp0';
  }
}
