# UX run 2026-10-13-app, batch 1: closing report

**Verdict:** 15 findings are fixed in code, and a test covers each one. 9 are verified. 6 work in code but still need a check on a real phone. UX-401 (reminders are off and nothing asks to turn them on) failed twice, so it goes to you with a recommendation. 4 new problems were caused in round 1 (UX-435 to UX-438), and round 2 fixed all of them.

## Verified
- **UX-104**: Listening no longer stops when something covers the app. It now pauses and shows "En pausa". (P33)
- **UX-107**: A blocked microphone can be fixed from the app. A banner shows "Abrir Ajustes", and listening starts again on return. (P33)
- **UX-108**: The status reads "Un momento…" until the microphone is ready. (P33)
- **UX-210**: Reminder timing is one list, opened from the chip or from the Recordatorio row. Tapping an option applies it and closes the list. (P8)
- **UX-335**: No fixed snackbars are left. The shared helper always uses floating ones. (P1)
- **UX-405**: Notificaciones has one switch. Everything else is folded under "Detalles", and the status line shows only when there is a problem. (P8)
- **UX-416**: The home-screen widget help is a sheet that stays open until it is closed. (P1)
- **UX-435**: The sheet and Notificaciones both use the same name for the permission: «Alarmas y recordatorios». (P50)
- **UX-438**: With tasks already there at launch, the question reads "¿Quieres recordatorios antes de tus tareas?". After a task is saved, it is your D2a question. (P48)

## Fixed in code; needs your phone (device-check)
- **U1**: The microphone stops after a ~3 s pause. (P33)
- **UX-101**: The "Saved" bar never left, and its only button undid the save. (P1)
- **UX-201**: Unfinished tasks from earlier days disappeared from Today. They now show under "Atrasadas · N". (P31)
- **UX-209**: The chip promised a reminder that couldn't fire. It now reads "Sin recordatorio · Activar". (P8)
- **UX-436**: The confirmation now reads "Listo. Recordatorios activados." and only shows when exact alarms are on. (P50)
- **UX-437**: Words heard before a speech restart could disappear. (P49)

## Still open
- Nothing else from this batch. UX-401 is escalated (next section).

## Escalated
- **UX-401** (S4, D): Reminders are off by default, and nothing asks to turn them on.
  - **Round 1 (P32)** put the question in a card in the bottom bar. At 320×568 with 2× text, the agenda was left with 16 px.
  - **Round 2 (P48)** moved the card to the end of the Calendar list, the Tareas list and the empty state. On a 390×844 phone at 1× text, the card sits at y 663–759, under the bottom bar that starts at y 698. At 1.3–2× text, or with several tasks, it is entirely below the fold. Your father would never see the question, and reminders would stay off.
  - **Failing tests:** `reminder_ask_card_test.dart` around lines 150 and 347.
  - **Recommendation:**
    - Ask once, in a bottom sheet, right after the first task with a date is saved and shown. Use the same question and the same two buttons.
    - Delete the card from all three lists.
    - Replace the test at :139-180, which assumes a card in the bottom bar. The new test checks that the task can be tapped at launch and that both answers can be tapped.
    - This adds no setting and no screen, but it does interrupt the user, so it needs your approval.
  - Recorded in `plan-b1-r3.json`, in `plan.md` under "Round 3 (b1)", and in the Escalated section of ISSUES.md.
  - What already works and stays: the one-tap turn-on, 9:00 for tasks without a time, saving the answer, and the D2a copy.

## Checks for your phone
1. **U1 + UX-437:** On Android 13+ and on Android 12, say "comprar pan", pause 5–10 s, then say "y leche".
   - Listening continues, with no red banner.
   - Both phrases stay in the text.
   - The level bar still moves.
2. **UX-101:**
   - Set Android's "Time to take action" to 1 minute: the "Saved" bar stays about a minute, then leaves.
   - Start a second capture: it shows no "Deshacer".
3. **UX-201:** Leave a task undone until the next day. In Spanish at large text, it shows under "Atrasadas" on Today and in the Tareas "Hoy" filter.
4. **UX-209:** On Android 13+, refuse the notification permission from the chip, then allow it. The chip reads correctly each time.
5. **UX-436:** On Android 14, leave the "Alarmas y recordatorios" screen without allowing it.
   - The last message asks again, not "Listo".
   - Allow it, come back, and the message is "Listo. Recordatorios activados.".
6. **UX-401, round 1 checks, still pending:**
   - the Android 13+ permission dialog;
   - the Android 14 exact-alarm screen;
   - a 9:00 reminder actually arriving.

## Files changed
- **Code:**
  - `App/lib/models/task.dart`
  - `App/lib/main.dart`
  - Screens: `calendar_screen.dart`, `home_screen.dart`, `review_tasks_screen.dart`, `voice_task_screen.dart`, `settings_screen.dart`, `data_transfer_screen.dart`, `subscription_screen.dart`, `task_lists_screen.dart`, `activity_screen.dart`, `capture_diagnostics_screen.dart`, `device_calendars_screen.dart`, `groups_screen.dart`, `regional_settings_screen.dart`, `task_detail_screen.dart`, `notification_settings_screen.dart`
  - Widgets: `app_components.dart`, `task_interactions.dart`, `task_editor.dart`, `device_calendar_events.dart`, `language_selector.dart`, `note_text.dart`, `project_preferences.dart`, `reminder_control.dart`, `reminder_ask_card.dart` (new), `task_actions.dart`, `task_list.dart`
  - Services and providers: `notification_service.dart`, `reminder_preferences.dart`, `native_speech.dart`, `reminder_provider.dart`
  - Android: `NativeSpeechBridge.kt`
- **Translations:** `app_en.arb`, `app_es.arb`, `app_ca.arb`, plus `l10n/generated/*` (regenerated by `flutter gen-l10n`, not edited by hand)
- **Tests:** `task_creation_test.dart`, `subscription_screen_test.dart`, `reminder_settings_test.dart`, `reminder_ask_card_test.dart`, `native_speech_test.dart`, `integration_test/native_speech_flow_test.dart`

## Which tests now cover which fixes
- `native_speech_test.dart`:
  - U1 (:420-540)
  - UX-108 (:470)
  - UX-104 (:544)
  - UX-107 (:631, :703)
  - UX-101 (:729)
  - UX-437 (:764-860)
- `review_tasks_test.dart:366-460` and `task_creation_test.dart:300-360`: UX-101.
- `calendar_feedback_test.dart`:
  - UX-201 (:281-440)
  - UX-101 and UX-335 (:440-471). For UX-335 this tests the shared helper, not the Projects screen itself.
- `overdue_test.dart` and `home_screen_test.dart:98`: UX-201.
- `reminder_settings_test.dart`:
  - UX-209 (:200-250)
  - UX-405 (:252, :467, :542, :571)
  - UX-435 (:279, :347, :368)
  - UX-436 (:279, :322, :368)
  - UX-210 (:389, :413)
- `settings_screen_test.dart:94`: UX-416.
- `reminder_ask_card_test.dart:367`, `:398`: UX-438.

## Rounds
| Round | Packages | Tests | Fixed | Not fixed | New problems found |
|---|---|---|---|---|---|
| 1 | P31, P1, P8, P32, P33: all done | Failed. Only the UX-401 card tests failed; the other 11 findings' tests pass | UX-201, 209, 210, 405, 101, 416, 335, U1, 104, 107, 108 | UX-401 (partly fixed) | 4: R1B-1 became UX-435, R1B-2 UX-436, R1A-1 UX-437, R1D-1 UX-438 |
| 2 | P48 partly done, P49 done, P50 done | Failed. Only the UX-401 tests failed (around :150 and :347) | UX-438, 437, 435, 436 | UX-401, escalated | none |

## Why this run was expensive (you asked)
The record suggests these causes. I can't see token counts, only the run's own files.
- **Every round runs the whole pipeline again.** That is implementer, ux-tester, one reviewer per area, then a re-plan. Round 2 existed only to fix 4 regressions from round 1 and to retry UX-401. Three of the four were small: two S1 copy fixes and one S2.
- **UX-401 should have gone to you first.** Where to put a one-time question is a two-way design choice. The round 1 brief asked for a question that "never covers the task" and is also seen at once. Those two goals conflict, and two rounds were spent finding that out.
- **Possible cheaper next time:**
  - Put regressions of severity 1–2 into the next batch instead of opening a new round.
  - Send placement questions that could go either way to you during planning.
  - Let the reviewer check copy-only fixes from the test result, without a full code read.
