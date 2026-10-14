## UX loop report: 2026-10-13-app, batch b4 (2026-10-14)

**Verdict:** Ship. 28 findings are fixed in code across 3 rounds, and the tests passed in every round. 14 are verified and 14 still need a check on a real phone. None were escalated. One new issue is open: **UX-475**. When a task with no date is saved, Calendar lights its row, but the row sits under the save message. The round 2 reviewer measured this, but no package covered it. It means U5's earlier claim that "Calendar lands" isn't fully true.

### Verified (all fixed, each locked by a test)
- **UX-464**: "Volver a decirlo" after Cancel waited silently on the server. P66. `capture_result_exits_test.dart`
- **UX-204**: Typed dates were ignored unless a small chip was tapped. P38, D10. `capture_sheet_test.dart`, `quick_schedule_parser_test.dart`
- **UX-112**: Spoken tasks ignored the day selected in the calendar. P38, D9. `capture_sheet_test.dart`, `quick_schedule_parser_test.dart`
- **UX-118**: Notes flipped which of voice and typing was the main button. P38. `notes_ui_test.dart`
- **UX-213**: A plain task's detail was mostly empty or default sections; it went from about 45 words to about 15. P10. `task_detail_test.dart`
- **UX-214**: The detail's date rows looked tappable but weren't. P10. `task_detail_test.dart`
- **UX-309**: A note could only be edited from a corner pencil. P10. `notes_ui_test.dart`
- **UX-211**: Back in the task form dropped what was typed. P42, D12. `task_detail_test.dart`
- **UX-465** (R1A-1): The time chips on a result built by the phone had no question; they now ask "¿A qué hora?". P68. `capture_sheet_test.dart`, `review_tasks_test.dart`
- **UX-468** (R1A-4): Without Pro, the typing hint showed an example the phone can't split; it now shows a one-task example. P67. `capture_sheet_test.dart`, `quick_schedule_parser_test.dart`
- **UX-470** (R1A-6): The pronoun in the Pro line had nothing to refer to, in Spanish and Catalan. P67. `capture_sheet_test.dart`
- **UX-471** (R1B-1): Some detail rows answered a tap and rows that look the same didn't. P70. `task_detail_test.dart`
- **UX-473** (R1B-3): "Cambios guardados" offered Deshacer after Back but not after Guardar. P70. `task_detail_test.dart`
- **UX-474** (R2B-1): Saving an untouched form offered an Undo that did nothing. P71. `task_detail_test.dart:487-542`

### Fixed in code, waiting for a phone check (each one is also covered by a test)
- **U5** and **UX-460** (merged): After saving, the user wasn't shown the task; with animations off, the new row sat under the message. P65. `capture_landing_test.dart`: the animations-off test now runs unskipped and unchanged. The Calendar gap is UX-475.
- **U7**: There was no "Guardar tal cual" (save as written) when the AI was slow or failed. P40. `capture_sheet_test.dart`
- **U8**: There were several creation buttons; there is now one "Añadir tarea" everywhere. P38. `capture_sheet_test.dart`. Also seen in a render.
- **UX-102**: Leaving capture created empty pending captures. P39. `capture_sheet_test.dart`, `capture_recovery_test.dart`
- **UX-103**: Capture errors showed raw English and jargon, out of view. Round 1 (P40) only partly fixed it, so it failed once; P67 fixed it in round 2. `capture_sheet_test.dart`
- **UX-106**: Without Pro, every way into capture was a dead end. P39, D4a. `capture_sheet_test.dart`
- **UX-114**: Typing entries opened a screen built around the microphone. P39. `capture_sheet_test.dart`
- **UX-451**: TalkBack didn't read recognizer errors. P40. `capture_sheet_test.dart`
- **UX-208**: Delete couldn't be undone, and Delete was the main button. P42, D11. `task_detail_test.dart`, `sync_test.dart:428`
- **UX-466** (R1A-2): A task saved from the timeline landed out of sight. P69. `capture_sheet_test.dart`
- **UX-467** (R1A-3): TalkBack wasn't told when saving as written became possible. P67. `capture_sheet_test.dart`
- **UX-469** (R1A-5): The "Reintentar" and "Guardar tal cual" labels wrapped at normal text size on a 360 dp screen. P67. `capture_sheet_test.dart`
- **UX-472** (R1B-2): The new tap targets on the detail had no spoken action. P70. `task_detail_test.dart`

### Still open
- **UX-475** · S2 · A: When a task with no date is saved, Calendar lights its "Bandeja · 1" row (y 541–589), but the row sits almost entirely under the save message (top 551) at 390×844. Calendar's content is too short to scroll the row clear. P69 didn't cause this: saving from the pending list does the same. The reviewer's fix: while a landing is active, give Calendar's scroll content a bottom inset of at least the message's height + 8 dp, as P65 did for Tareas. It is a fix, not a decision, and it should go in the next batch.

### Escalations
None.

### Checks for the owner's phone
1. U5 / UX-460: UX_REVIEW §7 task 2. Then turn on Android's "Remove animations" and save from Tareas: the new row sits fully above the message.
2. U7: In airplane mode, dictate "médico el viernes" and tap "Guardar tal cual". The task is dated Friday.
3. U8: On a non-Pro account in Spanish, each screen has one "Añadir tarea" button. Also check whether the father's account has Pro.
4. UX-102: Tap the home-screen widget, then press Back. No pending line appears.
5. UX-103: Record silence. "No te he entendido…" appears, then "Empezar a hablar", and nothing new shows in Pendientes.
6. UX-106: On a non-Pro account, the widget, both shortcuts and Share each open typing.
7. UX-114: The launcher's typing shortcut brings up the keyboard.
8. UX-451: TalkBack reads a recognizer error aloud.
9. UX-208: On a signed-in account, delete a task and tap Deshacer. The task survives the next sync and shows on a second device.
10. UX-466: From a timeline, add a task for another day. Calendar opens on that day with the task lit.
11. UX-467: With TalkBack on, it says "Está tardando más de lo normal." at about 8 s.
12. UX-469: In Catalan at 360 dp, "Torna-ho a provar" and "Desa-ho tal com està" each fit on one line.
13. UX-472: TalkBack reads the detail's date row as a button with "Cambiar fecha".

### Files changed
- **Screens:** `App/lib/screens/home_screen.dart`, `calendar_screen.dart`, `notes_screen.dart`, `day_timeline_screen.dart`, `voice_task_screen.dart` and `task_detail_screen.dart`. `create_task_screen.dart` was deleted.
- **Widgets:** `App/lib/widgets/task_list.dart`, `task_actions.dart`, `task_editor.dart`, `capture_review_editor.dart`, `attachment_panel.dart`, `note_text.dart` and `app_components.dart`.
- **Services:**
  - new: `App/lib/services/local_capture.dart`;
  - changed: `capture_processor.dart`, `capture_store.dart`, `quick_schedule_parser.dart`, `capture_problem.dart`, `api_client.dart` and `task_database.dart`.
- **App and data:** `App/lib/main.dart`, `App/lib/models/capture_session.dart`, `App/lib/providers/subscription_provider.dart`, `task_provider.dart`, and `App/lib/repositories/task_repository.dart`, `cloud_task_repository.dart`.
- **Copy:** `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb` and `capture_messages.dart`. `generated/*` was regenerated by `flutter gen-l10n`.
- **Android strings:** `App/android/app/src/main/res/values{,-es,-ca}/strings.xml`.
- **Unit and widget tests:** `App/test/capture_landing_test.dart`, `capture_sheet_test.dart`, `capture_result_exits_test.dart`, `capture_recovery_test.dart`, `task_detail_test.dart`, `notes_ui_test.dart`, `quick_schedule_parser_test.dart`, `review_tasks_test.dart`, `sync_test.dart`, `task_creation_test.dart`, `calendar_feedback_test.dart`, `reminder_ask_sheet_test.dart`, `reminder_settings_test.dart`, `task_lists_widget_test.dart`, `auth_gate_test.dart`, `appearance_test.dart`, `native_speech_test.dart`, `project_ui_test.dart`, `support/capture_fixtures.dart` and `support/design_fixtures.dart`.
- **Integration tests:** `App/integration_test/appearance_test.dart`, `attachment_flow_test.dart` and `notes_flow_test.dart`.

### Rounds
- **Round 1:** P65, P66, P38, P39, P40, P10 and P42. Tests passed. The reviewer rated 17 findings fixed; UX-103 was only partly fixed (two messages named a "Seguir" button that isn't on screen). It found 9 regressions, R1A-1 to 6 and R1B-1 to 3, which became UX-465 to UX-473.
- **Round 2:** P67, P68, P69 and P70. Tests passed. All 10 findings were fixed: UX-103 and UX-465 to UX-473. One regression, R2B-1, became UX-474. The reviewer also measured the Calendar gap now logged as UX-475.
- **Round 3:** P71. Tests passed, UX-474 was fixed, and there were no regressions.

### Ledger
I updated `.claude/ux-review/ISSUES.md`. 14 lines moved to Verified and 14 to Device check. I added UX-475 under Open, with the severity set by the organizer, and noted the Calendar gap on U5 and UX-466.
