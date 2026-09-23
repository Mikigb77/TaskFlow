// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get note => 'Note';

  @override
  String get noteEmptyBody => 'No text added.';

  @override
  String get fileNone => 'No attachments.';

  @override
  String get newNote => 'New note';

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
  String get reviewNote => 'Review note';

  @override
  String get saveNote => 'Save note';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get recordNote => 'Dictate a note';

  @override
  String get noteCaptureHelp =>
      'Keep your words as one note. Typed notes stay on your phone until sync; saved recordings need online transcription.';

  @override
  String get noteHint => 'Ideas, meeting details, useful links…';

  @override
  String get deleteNoteQuestion => 'Delete this note?';

  @override
  String get keepNote => 'Keep note';

  @override
  String get viewOnlyNote =>
      'View-only note. The list owner manages editing access.';

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
  String get calendarNoEvents =>
      'No events from your selected calendars on this day.';

  @override
  String get calendarNoSelection =>
      'Choose calendars to show your existing commitments.';

  @override
  String get calendarAllDay => 'All day';

  @override
  String get calendarUntitled => 'Untitled event';

  @override
  String get calendarShowAll => 'See all calendar events';

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
  String get yourCalendar => 'Your calendar';

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
  String get completed => 'Completed';

  @override
  String get noDate => 'No date';

  @override
  String get anyTime => 'Any time';

  @override
  String get addTime => 'Add time';

  @override
  String get chooseDate => 'Choose date';

  @override
  String get chooseTime => 'Choose time';

  @override
  String get removeDate => 'Remove date';

  @override
  String get removeTime => 'Remove time';

  @override
  String get newTask => 'New task';

  @override
  String get editTask => 'Edit task';

  @override
  String get taskDetails => 'Task details';

  @override
  String get sayTask => 'Say a task';

  @override
  String get typeTasks => 'Type tasks';

  @override
  String get unfinishedCaptures => 'Unfinished captures';

  @override
  String get captureDiagnostics => 'Capture diagnostics';

  @override
  String get lists => 'Lists';

  @override
  String get labels => 'Labels';

  @override
  String get noList => 'No list';

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
  String get createTask => 'Create Task';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get taskTitle => 'Task Title';

  @override
  String get additionalNotes => 'Additional Notes';

  @override
  String get moreDetails => 'More details';

  @override
  String get fewerDetails => 'Fewer details';

  @override
  String get appearance => 'Appearance';

  @override
  String get chooseAppearance => 'Choose your appearance';

  @override
  String get appearanceHelp => 'Choose your look, or follow your device.';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get yourSpace => 'Your space';

  @override
  String get welcomeSettings => 'Make yourself at home';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsHelp => 'Reminder choices and upcoming alerts';

  @override
  String get accountBackup => 'Account & backup';

  @override
  String get completedTasks => 'Completed tasks';

  @override
  String get progressHelp => 'A little record of your progress';

  @override
  String get exportImport => 'Export & import';

  @override
  String get exportImportHelp => 'TaskFlow backups and Todoist CSV migration';

  @override
  String get regionalSettings => 'Language & region';

  @override
  String get regionalSettingsHelp =>
      'Language, clock, week start and capture timezone';

  @override
  String get language => 'Language';

  @override
  String get deviceDefault => 'Follow device';

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
  String get captureTimezone => 'Capture timezone';

  @override
  String get timezoneHelp =>
      'Used to interpret dates in new captures. Existing tasks and unfinished captures keep their schedules. Task times are displayed in your device timezone.';

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
    return 'The device timezone is unavailable. New captures will use $zone.';
  }

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get syncTasks => 'Sync tasks';

  @override
  String get previousPeriod => 'Previous month or week';

  @override
  String get nextPeriod => 'Next month or week';

  @override
  String get moreClarity => 'More clarity. More room for life.';

  @override
  String get licenses => 'Open-source licences';

  @override
  String get weekView => 'Week view';

  @override
  String get monthView => 'Month view';

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
  String get calendarEmpty =>
      'Tap Say a task and speak naturally, or New task to type. Dates are optional; unscheduled tasks go to Inbox.';

  @override
  String get planTask => 'Plan a task';

  @override
  String get homeCapture => 'Capture from your home screen';

  @override
  String get homeCaptureHelp =>
      'Android mic widget, app shortcuts and text sharing';

  @override
  String get homeCaptureInstructions =>
      'On Android, long-press the TaskFlow icon for capture shortcuts, or add the Say a task widget from your launcher. Share text to TaskFlow from another app.';

  @override
  String get widgetPickerHelp =>
      'Add the TaskFlow widget from your launcher’s widget picker.';

  @override
  String get signInHelp => 'Sign in to keep your tasks with you';

  @override
  String get diagnosticsHelp => 'Local timing and counters, without your words';

  @override
  String get appearanceError => 'Could not save your appearance preference.';

  @override
  String get appearanceChangedError =>
      'Appearance changed. Could not save the preference on this device.';

  @override
  String get switchLight => 'Switch to light mode';

  @override
  String get switchDark => 'Switch to dark mode';

  @override
  String get list => 'List';

  @override
  String get archivedList => 'Archived list';

  @override
  String get yourList => 'Your list';

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
      'Add a task to this list. Its date and reminder are yours to choose.';

  @override
  String get tasksEmpty =>
      'Use Say a task to speak, or New task to type.\nAdd a date now or leave it for later.';

  @override
  String get inboxEmpty =>
      'Keep ideas and to-dos here until you choose a date.\nUse Say a task or New task to begin.';

  @override
  String get savedOnDevice => 'Your saved tasks are still on your device.';

  @override
  String get checkCaptures => 'Check unfinished captures';

  @override
  String get createVoiceTask => 'Create task with voice';

  @override
  String get createTaskTooltip => 'Create task';

  @override
  String get reviewTask => 'Review task';

  @override
  String get fineTunePlan => 'Fine-tune your plan.';

  @override
  String get onYourMind => 'What’s on your mind?';

  @override
  String get wordsPlan => 'Your words, a clear plan.';

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
  String get chooseReminder => 'Choose reminder';

  @override
  String get reminder => 'Reminder';

  @override
  String get off => 'Off';

  @override
  String get useReminder => 'Use reminder';

  @override
  String get dateForReminder => 'Add a date to use a reminder';

  @override
  String get chooseAlertTime => 'Choose alert time';

  @override
  String get defaultTime => 'Use default time';

  @override
  String get reminderDefaultsError =>
      'Reminder defaults could not load. Check notification settings.';

  @override
  String get loadingReminders => 'Loading reminder settings…';

  @override
  String get remindersDisabled => 'Reminders are off on this device';

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
  String get keepRepeat => 'Keep repeat';

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
  String get deleteTaskQuestion => 'Delete task?';

  @override
  String get keepTask => 'Keep task';

  @override
  String get deleteTaskError => 'Could not delete this task. Please try again.';

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
  String get nextStep => 'Your next step';

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
  String get captureThought => 'Capture a thought';

  @override
  String get captureIntro =>
      'One task or several. Say it naturally, or type your plan.';

  @override
  String get stopDraft => 'Stop and create draft';

  @override
  String get recordTasks => 'Record tasks';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get puttingPlanTogether => 'Putting your plan together…';

  @override
  String get recordingKept => 'Recording kept on this phone';

  @override
  String get tapSpeak => 'Tap to speak';

  @override
  String get inputLevel => 'Microphone input level';

  @override
  String get tapStopHelp => 'Tap stop when you’re finished. Up to 60 seconds.';

  @override
  String get returnCaptureHelp =>
      'You can leave and return. Unfinished recordings are kept.';

  @override
  String get speechOptions => 'Speech options';

  @override
  String get onDeviceTranscript => 'On-device live transcript';

  @override
  String get onlineAudio => 'Saved audio · online transcription';

  @override
  String get liveTranscript => 'Live transcript';

  @override
  String get savedAudio => 'Saved audio';

  @override
  String get speechLanguage => 'Speech language';

  @override
  String get deviceLanguage => 'Device language';

  @override
  String get onDeviceUnavailable =>
      'On-device speech is unavailable for this language on this device. Record audio for online processing, or type.';

  @override
  String get setUpSpeech => 'Set up on-device speech';

  @override
  String get checkAgain => 'Check again';

  @override
  String get holdTalk => 'Hold to talk';

  @override
  String get holdTalkHelp => 'Hold the mic, then release. Tapping still works.';

  @override
  String get typePlan => 'Or type your plan';

  @override
  String get examplePlan =>
      'Doctor Friday at 5 p.m. Bring my results. Also buy coffee.';

  @override
  String get tryRecording => 'Try this recording';

  @override
  String get reviewText => 'Review tasks from text';

  @override
  String get discardCapture => 'Discard capture';

  @override
  String get discardCaptureQuestion => 'Discard this capture?';

  @override
  String get discard => 'Discard';

  @override
  String get keep => 'Keep';

  @override
  String get guestTrialHelp =>
      'Try voice without an account. A small daily allowance is shared by devices on this connection.';

  @override
  String get capturePrivacy =>
      'Live transcription uses on-device speech where available; no audio is retained in that mode. AI task extraction still needs the internet and sends your words to Google. Saved audio is transcribed online. Unfinished input stays on this phone until you save or discard it.';

  @override
  String get checkTasks => 'Check your tasks';

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
  String completionCount(int done, int total) {
    return '$done of $total tasks completed';
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
  String nativeSpeechHelp(String language) {
    return 'On-device speech · $language. Words appear below and are kept as you speak.';
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
  String readyCount(int count) {
    return '$count ready to save';
  }

  @override
  String needsCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks need',
      one: '1 task needs',
    );
    return '$_temp0 a quick check. Save the ready ones whenever you like.';
  }

  @override
  String priorityValue(String priority) {
    return '$priority priority';
  }

  @override
  String get pickDate => 'Pick a date';

  @override
  String get typeTask => 'Type a task';

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
  String get listUnavailable => 'List unavailable';

  @override
  String get moveToList => 'Move to a list';

  @override
  String get moveToListHelp =>
      'Your date, reminder and task details stay the same.';

  @override
  String get archived => 'Archived';

  @override
  String get createListHelp => 'Create your first list from Tasks → Lists.';

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
  String get scheduleUpdated => 'Schedule updated';

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
      'Changes the start of the series and resets individual moves or skips. Inbox stops the repeat.';

  @override
  String get occurrenceRescheduleHelp =>
      'Other dates in the series stay the same.';

  @override
  String get saveSchedule => 'Save schedule';

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
  String get suggestionApplied => 'Schedule suggestion applied';

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
  String get taskAddedCalendar => 'Task added to your calendar';

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
  String get capturedWords => 'Captured from your words';

  @override
  String get titleRequiredField => 'Please enter a task title';

  @override
  String get keepAsTitle => 'Keep as title';

  @override
  String get ambiguousTimeHelp =>
      'Choose AM/PM or add the time yourself. No hour has been inferred.';

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
  String useSchedule(String schedule) {
    return 'Use $schedule';
  }

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
  String get deviceOff => 'device off';

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
  String get recoveryHeading => 'Let’s get you back in.';

  @override
  String get registerHeading => 'A space for your plans.';

  @override
  String get signInHeading => 'Welcome back.';

  @override
  String get recoveryHelp =>
      'Request a recovery email, then use the code to set a new password.';

  @override
  String get accountSignInHelp =>
      'Sign in to back up your tasks and notes and get a larger voice allowance.';

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
  String get passwordHelp => 'At least 12 characters';

  @override
  String get passwordTooShort => 'Use at least 12 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get continueRecovery => 'Continue recovery';

  @override
  String get createAccount => 'Create account';

  @override
  String get signIn => 'Sign in';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get accountGuestHelp =>
      'You can also use TaskFlow without an account. Your local tasks and notes stay on this phone.';

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
  String get newList => 'New list';

  @override
  String get editList => 'Edit list';

  @override
  String get listName => 'Name';

  @override
  String get listNameHint => 'Work, Personal, Shopping…';

  @override
  String get listNameRequired => 'Name your list.';

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
  String get saveList => 'Save list';

  @override
  String get listSaveError => 'Could not save this list. Please retry.';

  @override
  String get listRestored => 'List restored';

  @override
  String get listArchivedHelp => 'List archived. Contents kept.';

  @override
  String get listUpdateError => 'Could not update this list. Please retry.';

  @override
  String get chooseListDetails => 'Choose list details';

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
  String get listResolveError => 'Could not resolve this list. Please retry.';

  @override
  String get retryLists => 'Retry lists';

  @override
  String get refreshLists => 'Refresh lists and invitations';

  @override
  String get listsHelp =>
      'Keep work, life and everything else in their own lists. Inbox still collects tasks without a date.';

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
  String get restoreList => 'Restore list';

  @override
  String get archiveList => 'Archive list';

  @override
  String get sharingAndPeople => 'Sharing and people';

  @override
  String get chooseDetails => 'Choose details';

  @override
  String get sharedListVisibility =>
      'Shared · everyone in this list can see tasks, notes and uploaded files';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get invitationCodeHelp =>
      'Give this code to the intended person through a channel you trust. They need it and the invited TaskFlow account to accept. The code is shown only now; replacing an invitation invalidates its previous code.';

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
  String get inviteToList => 'Invite to this list';

  @override
  String get inviteHelp =>
      'All tasks, notes and uploaded files in this list will be visible after they accept. The invitation appears in their TaskFlow account; no email is sent. Give them the code shown next. It expires in 7 days.';

  @override
  String get inviteeEmail => 'Their account email';

  @override
  String get enterEmailAddress => 'Enter an email address.';

  @override
  String get access => 'Access';

  @override
  String get sharingRolesHelp =>
      'Editors can add, change, complete and delete tasks and files. Only the owner manages the list and people. Shared tasks stay in this list; exporting creates a personal copy.';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get listSharing => 'List sharing';

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
  String get people => 'People';

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
      'This person will lose access to this list and its tasks, notes and files. Their unsent shared edits will be removed on the next successful sync.';

  @override
  String get pendingInvitations => 'Pending invitations';

  @override
  String pendingRole(String role) {
    return '$role · pending';
  }

  @override
  String get revokeInvitation => 'Revoke invitation';

  @override
  String get replaceInvitationHelp =>
      'Tap a pending invitation to replace its code.';

  @override
  String get howSharingWorks => 'How sharing works';

  @override
  String get sharedDataHelp =>
      'Tasks, notes and uploaded files are shared. Editors can change or remove them; viewers can read them. Task reminder choices are shared, but each phone must enable its own notifications.';

  @override
  String get sharingRemovalHelp =>
      'Leaving or losing access removes this phone’s shared tasks, notes, pending edits and downloaded copies at the next successful sync. Offline devices and copies already exported cannot be remotely erased.';

  @override
  String get deleteList => 'Delete list';

  @override
  String get deleteListHelp =>
      'Delete this list and all its tasks, notes and uploaded files for everyone? This cannot be undone.';

  @override
  String get deleteListForEveryone => 'Delete list for everyone';

  @override
  String get leaveList => 'Leave list';

  @override
  String get leaveListHelp =>
      'Shared tasks, notes, files and any unsent edits will be removed from this phone. Other members keep the list.';

  @override
  String get enterInvitationCode => 'Enter invitation code';

  @override
  String get requestInvitationCodeHelp =>
      'Ask the list owner for the code they received when inviting you.';

  @override
  String get invitationCodeRequired => 'Paste the full invitation code.';

  @override
  String get joinList => 'Join list';

  @override
  String get invitationResponseError =>
      'Could not respond. Retry when connected.';

  @override
  String get retryInvitations => 'Retry invitations';

  @override
  String get invitations => 'Invitations';

  @override
  String joinListHelp(String role) {
    return 'Join as $role. Shared tasks, notes and uploaded files will sync to your account.';
  }

  @override
  String get acceptInvitation => 'Accept invitation';

  @override
  String get decline => 'Decline';

  @override
  String get fileEmpty => 'No attachments. Add a file when editing.';

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
  String get deviceReminderScope =>
      'For this account on this device. Task choices sync; device preferences stay here.';

  @override
  String get mobileNotificationsOnly => 'Mobile notifications only';

  @override
  String get notificationPermissionOn => 'System permission is on';

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
  String get allowPreciseAlarms => 'Allow precise alarms';

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
      'TaskFlow exports include tasks, notes, schedules, recurring date changes, completion, checklists, labels and personal lists. Attachment names are listed; file contents, account credentials, device preferences and unfinished captures are excluded.';

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
      'Selected tasks, notes and the file’s lists are added as personal copies. Existing content is kept. Re-importing this same file skips records already imported on this phone; a changed or newly exported file counts as a different import.';

  @override
  String get listsIncluded => 'Lists included';

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
      other: '$lists lists',
      one: '1 list',
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
    return '$source · $tasks tasks · $notes notes · $lists lists';
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
    return 'Import $_temp0 and lists';
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
  String get archiveInvalidList => 'Invalid list metadata.';

  @override
  String get archiveDuplicateLists => 'Duplicate list identifiers.';

  @override
  String get archiveInvalidListStyle => 'Invalid list color or archive status.';

  @override
  String get archiveInvalidTask => 'Invalid task record.';

  @override
  String get archiveDuplicateTask => 'Duplicate task identifier.';

  @override
  String get archiveInvalidAttachments => 'Invalid attachment information.';

  @override
  String get archiveMissingList =>
      'The task refers to a list missing from this file.';

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
    return 'Row $row: section name is invalid; its tasks will have no list.';
  }

  @override
  String archiveCsvListDescription(int row) {
    return 'Row $row: list descriptions are not supported.';
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
      'lists': 'lists',
      'list_id': 'list id',
      'list_name': 'list name',
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
      'Cannot reach the server. Check your connection and server address, then retry.';

  @override
  String get captureTimeout =>
      'The server took too long to respond. You can retry this capture.';

  @override
  String get captureUnavailable =>
      'The processing service is unavailable. Retry this capture later.';

  @override
  String get captureAllowance =>
      'The service request limit was reached. Retry later.';

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
  String get captureRecordingFirst =>
      'Retry this recording or discard it before recording another.';

  @override
  String get captureEmptyInput => 'Say or type what you need to do first.';

  @override
  String get captureSpeechStopped =>
      'Speech stopped. Your retained words are safe; record audio or type to continue.';

  @override
  String get captureNoSpeech =>
      'No clear speech was detected. Retained words are still available.';

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
  String get captureSetupUnavailable =>
      'Speech setup is unavailable here. Use saved audio or type.';

  @override
  String get captureKept => 'Your capture is kept on this phone.';

  @override
  String get captureDiscardHelp =>
      'The recording and unsaved drafts will be removed. Tasks already saved will stay.';

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
  String captureTasksSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks saved',
      one: '1 task saved',
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
  String get captureFinish => 'Finish';

  @override
  String get captureYourWords => 'Your words';

  @override
  String get captureReviewRetainedHelp =>
      'Unfinished drafts are kept on this phone. You can return from Unfinished captures.';

  @override
  String get captureCheckDetails => 'Check the details above';

  @override
  String captureSaveTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count tasks',
      one: 'Save 1 task',
    );
    return '$_temp0';
  }

  @override
  String get labelsExample => 'home, errands, calls';
}
