# UX loop report: 2026-10-13-app, batch b8 (2026-10-14)

**Verdict:** All 17 findings are handled. 9 are verified. 8 pass in code and widget tests but still need a phone check. Nothing is open or escalated. Round 1 caused 3 regressions (R1B-1 became UX-621, R1B-2 became UX-622, R1D-1 became UX-623), and all three were fixed in rounds 2 and 3. Tests passed in every round.

**Evidence:** code reading (`git diff HEAD`) and ux-tester widget tests. For UX-433, UX-225 and UX-227 there are also the 18:33 calendar renders in `App/build/`. Nothing in this batch was run on an emulator or a physical phone. No preview renders TaskEditor, the timeline or the sign-in-again route, so those results rest on the code and the widget tests.

## Verified (in code, and the reviewer said fixed)
| ID | Title | Package | Locked by test |
|---|---|---|---|
| UX-122 | Catalan buttons mix infinitives and imperatives | P22 | `localization_catalog_test.dart:296`, `:363` |
| UX-123 | Missing plural in "kept for review" (English, Catalan) | P22 | `localization_catalog_test.dart:296`, `:383` |
| UX-215 | The typed task form asks questions before the title | P21 | `task_editor_form_test.dart:86-157` |
| UX-216 | "Más detalles" opens eight things at once | P21 | `task_editor_form_test.dart:176-318` |
| UX-222 | Each checklist step needs its own dialog | P21 | `task_editor_form_test.dart:335` |
| UX-224 | Timeline: wrong arrow labels, developer copy, extra create button | P23 | `day_timeline_test.dart:109`, `:117` |
| UX-227 | Polish: casing, labels, Catalan wording, reduced motion | P21 | `task_editor_form_test.dart:590-614`, `calendar_feedback_test.dart:1840` |
| UX-433 | The tab bar's top hairline never shows | P23 | `main_shell_test.dart:335` (pixels decoded in light and dark) |
| UX-514 | The billing message says "Conéctate al servidor de TaskFlow" | P100 | `subscription_screen_test.dart:417` |

Highlights:
- **UX-216:** the "Más detalles" section has gone from about 100 words to about 30 when the task has a date. The help lines, the section labels and "MiB" are gone. Without a date, Repetir is a disabled row.
- **UX-222:** steps are now added in an inline "Añadir paso" field, and the dialog is gone.
- **UX-514:** the new text is ES "No se pudo conectar con tu cuenta de TaskFlow. Revisa tu conexión y vuelve a abrir esta pantalla.", with English and Catalan to match.

## Verified in code, still needs a phone
| ID | Title | Package | Locked by test |
|---|---|---|---|
| UX-223 | Back on a secondary tab closes the app | P23 | `main_shell_test.dart:267-318`, `reminder_open_test.dart` |
| UX-225 | Translation slips: "Proyecto de pasos", feminine forms, plurals | P22 | `localization_catalog_test.dart:275-353`, `task_editor_form_test.dart:626-633` |
| UX-419 | Session expiry wipes in-progress typing | P30 | `session_resume_test.dart:119-196` |
| UX-424 | Startup waits for reminder setup | P30 | `session_resume_test.dart:94-97` |
| UX-513 | The sign-out, Sincronizar and Importar spinners have no TalkBack label | P100 | `account_regional_ui_test.dart:291-400` |
| UX-621 | Capture result card drops a step typed without Enter (R1B-1) | P110 | `review_tasks_test.dart:1867-1912`, `checklist_test.dart:86` |
| UX-622 | Toggling Más detalles erases a half-typed step (R1B-2) | P110, then P112 | `task_editor_form_test.dart:389`, `:464-590` |
| UX-623 | Sign-in-again doesn't say why; Back erases the reason (R1D-1) | P111 | `session_resume_test.dart:251-383` |

All 17 findings handled in this batch are now locked by at least one widget or unit test.

## Still open
None from this batch.

Things reviewers noticed but nobody has planned (not regressions, no new IDs):
- **Different account on sign-in-again:** if someone signs in there with a different account, the kept screens are dropped without a warning. This is noted on the UX-623 line. It is a candidate question for the owner, because a warning would add a step.
- **Typed step lost, two older cases:** text typed in "Añadir paso" is still lost in two cases that existed before this batch, and are noted on the UX-622 line. One is collapsing the form when the task already has 50 steps. The other is removing the last step through ⋮ in the short form.
- **Back on sign-in-again:** system Back does nothing on that screen and gives no feedback. This is on purpose, from P30, and the new line at the top now explains the screen.

## Escalations
None.

## Checks for the owner's phone
1. **UX-223:** on Tareas, press Back and you land on Calendario. A second Back leaves the app. Then tap a reminder whose task was deleted: only the "taskRemoved" message shows, and no second home screen opens.
2. **UX-225:** with TalkBack on, the steps of a task are read as "Lista de pasos".
3. **UX-419:** let the real server end the session while you are typing a task. After you sign in again, the task you were typing is still there.
4. **UX-424:** time a cold start until the calendar shows. Do it from the home-screen widget and the shortcuts too, which also covers the start-up part of UX-611. Then open the app from a reminder, and it still opens the task.
5. **UX-513:** with TalkBack on, tap Sincronizar, Importar and Cerrar sesión. Each spinner should say what it is doing ("Sincronizando", "Importando tareas y notas", "Cerrando sesión").
6. **UX-621:** in the capture result, type a step and tap "Añadir al calendario" without pressing Enter. Open the task, and the step is there.
7. **UX-622:** open a task with no steps and tap Más detalles. Type a step, tap Menos detalles, save and reopen. The step is there.
8. **UX-623:** let the server end the session while a task is being typed. The sign-in-again screen shows "Tu sesión se ha cerrado. Vuelve a entrar y seguirás donde lo dejaste.", the email is already filled in, and Back doesn't hide the line.

## Files changed
- **Screens:**
  - `App/lib/screens/account_screen.dart`
  - `calendar_screen.dart`
  - `day_timeline_screen.dart`
  - `login_screen.dart`
  - `main_shell.dart`
  - `voice_task_screen.dart`
- **Widgets:**
  - `App/lib/widgets/task_editor.dart`
  - `task_planning_control.dart`
  - `checklist_editor.dart`
  - `capture_review_editor.dart`
  - `repeat_rule_control.dart`
- **App start and state:** `App/lib/main.dart`, `App/lib/providers/auth_provider.dart`
- **Text:** `App/lib/l10n/region.dart` and `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`. The files in `App/lib/l10n/generated/` were regenerated by `flutter gen-l10n`, not edited by hand.
- **Tests:**
  - `App/test/subscription_screen_test.dart`
  - `account_regional_ui_test.dart`
  - `task_editor_form_test.dart`
  - `checklist_test.dart`
  - `task_creation_test.dart`
  - `attachment_panel_test.dart`
  - `review_tasks_test.dart`
  - `localization_catalog_test.dart`
  - `recurrence_controls_test.dart`
  - `main_shell_test.dart`
  - `day_timeline_test.dart`
  - `reminder_open_test.dart`
  - `calendar_feedback_test.dart`
  - `session_resume_test.dart`

## Rounds
- **Round 1** (`plan.json`):
  - Packages: P100 (account spinners and billing text), P21 (task form and steps), P22 (translations), P23 (Back, timeline, tab bar) and P30 (start-up and session expiry). All done.
  - Tests passed.
  - Verified 14: UX-513, UX-514, UX-424, UX-419, UX-215, UX-216, UX-222, UX-227, UX-225, UX-122, UX-123, UX-223, UX-224, UX-433.
  - Regressions: R1B-1 (UX-621, severity 3), R1B-2 (UX-622, severity 2) and R1D-1 (UX-623, severity 2).
- **Round 2** (`plan-b8-r2.json`):
  - Packages: P110 (steps typed without Enter) and P111 (sign-in-again reason and email). Both done.
  - Tests passed.
  - Fixed: UX-621 and UX-623.
  - UX-622 was only partly fixed: on a task with no steps, the first step typed under Más detalles was still lost on Menos detalles.
  - No regressions.
- **Round 3** (`plan-b8-r3.json`):
  - Package: P112, which unfocuses the step field before the form collapses. Done.
  - Tests passed.
  - Fixed: UX-622.
  - No regressions.

## Ledger
`.claude/ux-review/ISSUES.md`: 17 lines changed status.
- 9 moved from Open to Verified: UX-122, UX-123, UX-215, UX-216, UX-222, UX-224, UX-227, UX-433, UX-514.
- 8 moved from Open to Device check: UX-223, UX-225, UX-419, UX-424, UX-513, UX-621, UX-622, UX-623.

No other lines were edited. The UX-611 line still says its start-up wait "remains UX-424 (P30, open)". UX-424 is now in Device check, and its phone check covers UX-611.
