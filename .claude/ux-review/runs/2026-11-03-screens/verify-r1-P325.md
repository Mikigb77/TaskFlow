## UX verify — P325 (meeting notifications) — round 1 — 2026-11-03
**Verdict:** Ship after fixes. UX-2810 and UX-2812 are fixed in code. UX-2811 is partly fixed: opening a note's page can't remove its notification on Android, because it looks for the note in a field Android never returns.
**Read:** the package diff (`waves.py diff --worktree .claude/worktrees/wf_b7a20ea0-e5f-3`), the worktree's source at the lines below, the new tests' fake plugin, and flutter_local_notifications 17.2.4's Android `getActiveNotifications` (in the pub cache). No preview covers either notification, because Android draws them. The evidence is code and unit tests only. Nothing here comes from an emulator or a phone.

### Findings
**UX-2810 · fixed (code + unit test; how the shade shows it is a device check)**
- `App/lib/services/notification_service.dart:224-228`: `showWhen` and `usesChronometer` are true and `when = since` (ms) whenever the notice has a `since`. The channel, silent and low importance, public visibility, category and the Parar/Descartar actions are unchanged.
- `App/lib/services/meeting_recorder.dart:305`: at start and at «Seguir grabando», `since = now − meeting.recorded`. `:420`: at each cut, `since = now − offset`, where offset is the time recorded so far. The clock therefore counts recorded time, not wall time, through a cut and after a crash.
- `App/lib/services/meeting_audio.dart:174-180`: an Opus cut reposts the notice with its new `since`. With AAC the stream keeps running, so the first `since` stays correct.
- Owed: a phone check that the counter keeps running past the recorder service's own repost (an existing behaviour, retried at 0/400/1500/4000 ms).

**UX-2812 · fixed (code + unit test)**
- `notification_service.dart:158-170` (`postMeetingNotesReady`): the title is the note's title and the text is `meetingNotesReady`. A blank title falls back to the generic line as the title, with no text. Each meeting posts under `meetingNotesNotificationId` with `tag: saved.meetingId` (:165), so every meeting keeps its own notification. The payload is unchanged.
- ES `meetingNotesReady` is now «Las notas de la reunión están listas» (`app_es.arb:1457`, and the generated catalog matches). EN and CA are unchanged, as the brief says.
- On iOS a tag isn't honoured, so a second meeting still replaces the first there. Android is the target, so this isn't counted.

**UX-2811 · partly fixed**
- Works: `markSeen` → `MeetingHooks.notesSeen` → `cancel(id, tag: meetingId)` (`meeting_controller.dart:288`, `notification_service.dart:606`). Sign-out → `activate` with a changed owner → `cancelMeetingNotesReady(plugin)` (:643-647), which matches only by id and tag. Android returns both, so this works.
- Doesn't work on Android: opening the note's page (`task_detail_screen.dart:73` → `clearMeetingNoteReady` → `cancelMeetingNotesReady(plugin, noteId:)`). That code reads `shown.payload` (`notification_service.dart:183`). flutter_local_notifications 17.2.4 documents `ActiveNotification.payload` as "Returned only on iOS and macOS", and its Android `getActiveNotifications` never puts a payload in the map. On Android the payload is null, the `jsonDecode` throws, `note` stays null and the notification is skipped. Opening the note from Notas therefore leaves the notification up, which is the finding's own moment ("I already read those notes in the app. Why is it still there?").
- The test passed only because its fake plugin (`App/test/reminder_notification_id_test.dart:217-227`) returns the payload on active notifications. Android doesn't do that.
- Fix: find the notification without the payload. Either (a) in `noteOpened`, look up the meeting whose `noteId` equals the page's id (the controller's state or the store's `note_id`, `meeting_store.dart:98`) and cancel by that meeting's tag, or (b) give the tag both ids, for example `'<meetingId>#<noteId>'`, and match tags from `getActiveNotifications`, for the meeting in `notesSeen` and for the note in `noteOpened`. Make the fake plugin's `ActiveNotification` return no `payload`, as Android does, so the test proves this.

### Regressions
The UX-2811 gap above is the finding still partly open, so it isn't listed again as a regression.

**R1-P325-1 · Severity 1 · Files outside the package in the staged diff.** `App/analysis_options.yaml` gains an analyzer `exclude` block. `App/pubspec.lock` bumps test-framework packages: test_api 0.7.11→0.7.12, matcher 0.12.19→0.12.20, and others. This looks like the container's `flutter pub get`. Neither file is in P325's list, and pubspec and dependency changes are out of scope this run. Fix: drop both from the package before it merges.

No other regressions in the changed flows:
- The note page's `initState` hook (`task_detail_screen.dart:63-75`) draws nothing, swallows errors and doesn't run for a task.
- `markSeen` still refreshes after the hook, which catches its own errors.
- Reminders' cancellations in `activate` are unchanged, and the new cancel sits in its own try.
- The notes-ready tap path (`main.dart:383-410`) is unchanged.

### Device checks still owed
- Phone: record for 6 minutes (one cut at about 5 min) and lock the phone. The shade's counter keeps time through the cut and after «Seguir grabando».
- Phone: notes ready › open the note from Notas › the notification is gone. This will fail until UX-2811's note-page cancel is fixed.
- Phone: two meetings ready leave two notifications, each titled with its meeting. Sign out, and none remain.

### Memory notes
- flutter_local_notifications 17.2.4: `getActiveNotifications()` on Android returns id, channelId, tag, groupKey, title, body and bigText, but **not payload** (iOS/macOS only). Any "find the notification by its payload" logic is dead on Android. A fake plugin that echoes the payload hides this. Add it to recurring problems as "fake plugin richer than the platform".
- Meeting notifications now: recording = id 1 with a chronometer from `MeetingNotice.since` (recorded time, not wall time); notes-ready = `0x7ffffffe`, tagged by meeting id, with the note title first and «Las notas de la reunión están listas» as the text.
