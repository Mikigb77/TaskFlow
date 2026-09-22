// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get fileEmpty => 'No attachments. Add a file when editing this task.';

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
}
