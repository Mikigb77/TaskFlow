## UX loop 2026-10-19-app: batch b1 report (close, 2026-10-20)

**Verdict:** batch b1 is closed. All 21 findings were fixed, and their tests pass after round 2. 5 are fully verified. 15 are verified in code but still need a phone or emulator check. UX-1602 stays open on purpose: the app half is fixed, and P191 plus the server half are still to come. Nothing failed twice, so nothing was escalated. Evidence comes from code, widget and unit tests, preview renders and AUDIT.md. Nothing was checked on a device or emulator.

### Verified (reviewer said fixed; no failing test)
- **UX-1312** · S2 · A: every card in a batch now shows its chevron, so the day line looks tappable, and no target is under 48 dp (P168).
- **UX-1322** · S1 · A: while «Entendiendo…» shows, only the spinner shows; the microphone is gone (P167).
- **UX-1404** · S2 · B: an empty day now says it once, in one line (`calendarEmpty`, or `noScheduledTasks` when phone calendars are on), and `breathingRoom` is gone (P169).
- **UX-1617** · S1 · D: sign-in at 2×: «Correo» / «Correu» sit on the border, «Este correo ya tiene una cuenta.», 8 dp around «¿Has olvidado tu contraseña?», and only one create button shows at a time (P170).
- **UX-1626** · S1 · A (regression R1A-1): «Ver lo que dije» is now smaller and grey, 16 dp below the cards, and no longer looks like a second «Más opciones» (P198).

### Verified in code; a phone or emulator check is still owed (`device-check`)
- **UX-107** · S3 · A: a blocked microphone now leads to Settings on the online path too (P166).
- **UX-1301** · S3 · A: when nothing is understood, the main button is «Volver a decirlo», «Guardar como tarea» is a plain text button, and «Reintentar» is gone (P167).
- **UX-1302** · S3 · A: at 2×, an open question's answers scroll above the footer (P168).
- **UX-1303** · S2 · A: with the microphone blocked, the only action is a focused «Abrir Ajustes» button, under a neutral banner (P166).
- **UX-1304** · S2 · A: the listening hints are fixed, and a countdown is spoken once from 50 s (P167).
- **UX-1305** · S2 · A: the first microphone request now says why; a refusal gets a neutral banner, and «escribe abajo» is gone (P166).
- **UX-1306** · S2 · A: when on-device speech can't start, the app switches to online without a message; if that fails too, it shows one line (`captureCantListen`) (P166).
- **UX-1308** · S2 · A: TalkBack now speaks every kind of result once (P168, then P198; failed once in round 1).
- **UX-1309** · S3 · A: the save message no longer covers the lit tasks. The preview fixture lost its duplicate «Recoger…» task (P169, then P197; failed once in round 1).
- **UX-1405** · S2 · B: after 30 minutes or more away, or on a new day, Calendar opens on today (P169).
- **UX-1507** · C: an invitation opened while signed out now shows a line above Google (P170).
- **UX-1604** · S2 · D: TalkBack reading order on sign-in is fixed, «o» is no longer read, and the error banner is its own live region (P170).
- **UX-1627** · S1 · A (regression R1A-2): the microphone reason line waits 300 ms before showing, so a blocked answer never flashes it (P198).
- **UX-1628** · S2 · B (regression R1B-1): coming back to today scrolls the list to the top (P197).
- **UX-1629** · S1 · D (regression R1D-1): the recovery code field's label now sits on the border like the other fields (P199).

### Still open
- **UX-1602** · S3 · D, password recovery: the app half was verified in round 1 (P170). The request now sends the app's `language`, and a line above «Código de recuperación» names the address the email went to. Still open:
  - P191 (batch b6): the number pad, autofill, sending the address with the code, and plain error messages. P191 waits until the server half (a 6-digit code in the app's language, `Backend/core/auth_views.py:263`) is committed.
  - Part of the cause is server-side; that half is the main session's.

### Owner question raised in this batch (not blocking)
- **D11 (UX-1309):** should a lit row below the fold get a cue? That would mean a new element with new copy. My recommendation is no. UX-1309 is verified without it.

### Escalations
None.

### Checks for the owner's phone (or the emulator, where marked)
- **Emulator** `permission-mic.blocked`, in ES and CA, on both the on-device and online paths:
  - no frame shows «Permite el micrófono…» before the blocked banner (UX-1627);
  - re-capture `permission-mic.blocked.ca` (UX-107).
- **Emulator** `permission-mic.dialog.es` at 1.0 and 2.0, and `permission-mic.denied.es`: the reason line shows under Android's real dialog (UX-1305).
- On Android 13–15, «Permisos › Micrófono › Permitir» matches App info (UX-1303).
- TalkBack:
  - first focus lands on «Abrir Ajustes» (UX-1303);
  - the countdown is spoken once (UX-1304);
  - a deletion-only dictation and a mixed one are each spoken once (UX-1308);
  - the sign-in screen reads in the right order (UX-1604).
- An Android 12 phone with the app in Catalan switches to online speech (UX-1306; inferred from code).
- The real model with «Hola, ¿me oyes?» gives the nothing-found state (UX-1301).
- The largest font on a 360 dp phone:
  - capture's question answers (UX-1302);
  - the Calendar landing (UX-1309);
  - recovery labels sit whole on their borders (UX-1629).
- Overnight return:
  - reopening the next day lands on today (UX-1405);
  - at the largest font, reopening the morning after saving a task for Friday shows the week strip and «Agenda de hoy» at the top (UX-1628).
- Tapping a real invitation link while signed out (UX-1507).
- On staging, recovery sends a Spanish email (UX-1602).

### Files changed
- App code:
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/calendar_screen.dart`
  - `App/lib/screens/login_screen.dart`
  - `App/lib/screens/delete_account_screen.dart`
  - `App/lib/widgets/capture_review_editor.dart`
  - `App/lib/widgets/capture_command_cards.dart`
  - `App/lib/widgets/app_components.dart`
- Strings:
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/capture_messages.dart`
  - `App/lib/l10n/generated/` (regenerated by `flutter gen-l10n`, not edited by hand)
- Tests:
  - `App/test/native_speech_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_landing_test.dart`
  - `App/test/review_tasks_test.dart`
  - `App/test/voice_command_cards_test.dart`
  - `App/test/calendar_feedback_test.dart`
  - `App/test/auth_gate_test.dart`
  - `App/test/account_regional_ui_test.dart`
  - `App/test/delete_account_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/native_resources_test.dart`
  - `App/test/support/reading_order.dart`
- Preview tests:
  - `App/test/ux_previews/capture_previews.dart`
  - `App/test/ux_previews/calendar_previews.dart`
  - `App/test/ux_previews/auth_previews.dart`
  - `App/test/ux_previews/support/fakes.dart`
- Loop records:
  - `.claude/ux-review/KNOWN_FAILURES.md`
  - `.claude/ux-review/ISSUES.md` (this close)

### Verified findings a test now protects
All 20, plus UX-1602's app half:
- UX-107: `native_speech_test.dart:2023`, `:2155`, `:2225`
- UX-1301: `capture_sheet_test.dart:2036-2166`, `capture_free_dictations_test.dart:2890`
- UX-1302: `review_tasks_test.dart:1933-2204`, `voice_command_cards_test.dart:1345`
- UX-1303: `native_speech_test.dart:2155-2199`
- UX-1304: `native_speech_test.dart:2590-2712`
- UX-1305: `native_speech_test.dart:2283`, `:2319`, `:2438`
- UX-1306: `native_speech_test.dart:2489-2562`
- UX-1308: `review_tasks_test.dart:2267-2344`, `voice_command_cards_test.dart:1592-1777`
- UX-1309: `capture_landing_test.dart:1130-1196`, `voice_command_cards_test.dart:1433-1559`
- UX-1312: `review_tasks_test.dart:2231`
- UX-1322: `capture_sheet_test.dart:2193`
- UX-1404: `calendar_feedback_test.dart:2926-3101`
- UX-1405: `capture_landing_test.dart:1240-1372`
- UX-1507: `auth_gate_test.dart:1584`
- UX-1602 (app half): `auth_gate_test.dart:1235`, `:1267`
- UX-1604: `auth_gate_test.dart:1405`, `:1433`, `delete_account_test.dart:3872`
- UX-1617: `auth_gate_test.dart:1466-1539`
- UX-1626: `review_tasks_test.dart:2360-2490`
- UX-1627: `native_speech_test.dart:2295-2400`
- UX-1628: `capture_landing_test.dart:1392-1540`
- UX-1629: `auth_gate_test.dart:1288-1362`

### Rounds
- **Round 1** (`plan.json`):
  - Packages: P166, P167, P168 and P170 done; P169 partial.
  - Tests failed, but only UX-1309's two 1× landing checks: the preview day held a duplicate task, so the check couldn't pass.
  - Fixed: 15. Partly fixed: UX-1308 and UX-1309.
  - Regressions: R1A-1 became UX-1626, R1A-2 became UX-1627, R1B-1 became UX-1628, R1D-1 became UX-1629.
  - Verify notes: `verify-b1-r1-A.md`, `-B.md`, `-D.md`.
- **Round 2** (`plan-b1-r2.json`):
  - Packages: P197, P198 and P199 done.
  - Tests passed.
  - Fixed: UX-1308, UX-1309, UX-1626, UX-1627, UX-1628, UX-1629. No regressions.
  - Verify notes: `verify-b1-r2-A.md`, `-B.md`, `-D.md`.

### Noted by the reviewers, not filed (for the next capture review)
- A task going into an existing project is spoken as just «Añadir tarea», with no title or date.
- In a mixed result whose task has its question open, the spoken label leaves the task out.
- The «nothing found» banner still uses the red error style.
- At 2×, the result's scroll cuts the title's first line under the drag handle. Review A judged this acceptable.
- Pro accounts see an unlabelled keyboard icon while three lines of copy name «Escribir». P171 / UX-1310 covers this.
- At 2×, the recovery code label is drawn about a fifth smaller than «Nueva contraseña». It is whole and legible.