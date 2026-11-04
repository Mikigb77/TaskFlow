## UX verify — P325 (meeting notifications) — round 1, check 2 — 2026-11-03
**Verdict:** Ship. All three findings are fixed in code, and check 1's regression R1-P325-1 no longer holds. What's left is the owed device checks.
**Read:** the package diff (`waves.py diff --worktree .claude/worktrees/wf_b7a20ea0-e5f-3`), `git status` in the worktree, the worktree's `notification_service.dart`, `meeting_recorder.dart` and `reminder_engine.dart` at the lines below, and the new tests with their fake plugin. No preview covers either notification, because Android draws them. The evidence is code and unit or widget tests in a Linux container. Nothing comes from an emulator or a phone.

### Findings
**UX-2810 · fixed (code + unit test; how the shade shows it is a device check).** Unchanged since check 1.
- `notification_service.dart:233-237`: `showWhen` and `usesChronometer` are true, and `when = since` in ms, whenever the notice has a `since`.
- `meeting_recorder.dart:299-306`: at start and at Continue, `since = now − recorded`.
- `:420`: at each cut, `since = now − offset`.
- `_notice` is set only in `_begin`, which is also the only place `_session` is set, so the `_notice!` at a cut can't be null.
- Tests: `reminder_notification_id_test.dart` (5 min ago, and 42 min); `meeting_core_test.dart` (through a cut, and Continue).

**UX-2812 · fixed (code + unit test).**
- `postMeetingNotesReady` (`notification_service.dart:165-180`): the title is the note's title, and the text is «Las notas de la reunión están listas». A blank title falls back to the generic line as the title, with no text.
- Each meeting posts under `meetingNotesNotificationId`, tagged `meetingNotesTag(meetingId, noteId)` = `'<meetingId>#<noteId>'` (:142). Each meeting still has its own tag, so two meetings keep two notifications. The fake plugin keeps one per id and tag, as Android does, and both stay shown.
- The payload is unchanged.
- The tag now holds both ids rather than the meeting's id alone. That is the option (b) check 1 offered, and it meets the acceptance's intent: a different tag per meeting.

**UX-2811 · fixed (code + unit and widget tests; the plugin cancel on Android is a device check).** This was check 1's gap, and it is closed.
- `cancelMeetingNotesReady` (`notification_service.dart:186-198`) no longer reads the payload. It matches showing notifications by id, then splits the tag at its last `#`: the meeting id before it, the note id after it. Android's `getActiveNotifications` returns both id and tag, so opening a note now finds its notification there.
- The fake `ActiveNotification` (`reminder_notification_id_test.dart`, `_Plugin.show`) now carries no payload, as on Android. The note-only test therefore proves the tag path:
  - `noteId: 90` cancels only `meeting-1#90`;
  - the other meeting's notification, a reminder and the recording all stay;
  - `noteId: 404` cancels nothing.
- `markSeen` → `notesSeen` → `cancelMeetingNotesReady(meetingId:)` (`meeting_controller.dart:288`).
- The note page's `initState` (`task_detail_screen.dart:63-75`) calls `noteOpened` for a note, and doesn't for a task (`meeting_screens_test.dart`). The notes-ready tap reaches it too (`meeting_open_note_test.dart`).
- Sign-out: `activate` cancels every notes-ready when the owner changes (`notification_service.dart:646-656`), inside its own try. Reminders' cancellations in `engine.activate` are unchanged.
- Not counted, because Android is the target: on iOS `ActiveNotification` has no tag, so opening a note there doesn't remove its notification.

### Regressions
**R1-P325-1 · resolved.** `git status` in the worktree no longer lists `App/analysis_options.yaml` or `App/pubspec.lock`, and the package diff doesn't contain them either.
- The other files outside the brief's list:
  - `meeting_note.dart`: the two hooks the brief needs;
  - `meeting_screens_test.dart` and `support/meeting_fakes.dart`: tests;
  - `ux_previews_test.dart`'s `_notCovered`: copy, updated to the new ES line.

  All of these follow from the package, and none of them is a product file.

No new regressions in the changed flows:
- The note page's hook draws nothing and swallows its errors. When the task list isn't loaded yet, it calls a harmless no-op cancel.
- `activate` adds one `activeOwner()` read, on the same table `engine.activate` writes. If that read failed, the write would fail as well.
- The new cancel sits in its own try, so the reminders reconcile still runs.
- The notes-ready tap path is unchanged.

### Device checks still owed
- Phone: record for 6 minutes (one cut at about 5 min) and lock the phone. The shade's counter keeps time through the cut, past the recorder service's own repost, and after «Seguir grabando».
- Phone: notes ready with the app in the background › open the note from Notas › the notification is gone.
- Phone: two meetings ready leave two notifications, each titled with its meeting. Sign out, and none remain.

### Memory notes
- Meeting notes-ready is tagged `'<meetingId>#<noteId>'` (`meetingNotesTag`), so it can be found from either id without a payload, which Android doesn't return. The test fake now omits the payload, as Android does. Check 1's lesson was "a fake plugin richer than the platform hides dead code". Here it was caught and fixed in one round.
