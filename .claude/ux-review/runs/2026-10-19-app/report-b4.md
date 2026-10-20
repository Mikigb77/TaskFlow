# UX loop report: run 2026-10-19-app, batch b4 (area C), closed 2026-10-20

**Verdict:** All 26 findings this batch took on are fixed. Every test passed in all three rounds.
- 20 are **verified**.
- 6 are **verified in code but still need a device check**: a phone, an emulator with TalkBack, or staging with two accounts.
- Round 3 raised one new regression, **UX-1648** (S2). It stays open and was not re-planned, because the run ended after round 3.
- Nothing was escalated.

## Verified (the reviewer said "fixed", and no test for it failed)

| ID | Title | Round, package |
|---|---|---|
| UX-1503 | «Su correo» reads as «your email» in invites | r1, P181 |
| UX-1513 | Groups invite and manage people differently from projects | r1, P181 |
| UX-1508 | The name question covers «Te has unido a…» | r1, P182 |
| UX-1509 | A dead invitation offers «Reintentar»; «Ahora no» deletes it | r1, P182 |
| UX-1510 | Three taps wait for a full sync, showing nothing | r1, P183 |
| UX-1524 | Copy slips: «Actividad del grupo», «colaborad», Catalan sharing | r1, P183 |
| UX-1504 | Tasks added in an archived project never reach Calendar | r1, P184 |
| UX-1516 | The project sheet can't start a new project | r1, P184 |
| UX-1519 | «Visible para todos» sits right under «Ana ▾» | r1, P184 |
| UX-1522 | Projects: groups first, «Guardar» creates, idle search and retry | r1, P184 |
| UX-1523 | «Miembros» and «Notas» touch on a project page | r1, P184 |
| UX-1320 | A voice note's title stops mid-phrase («…y por la») | r1, P185 |
| UX-1517 | Notes made in the sheet show their first words twice | r1, P185 |
| UX-1518 | At 0 dictations left, every note opens with the limit | r1, P185 |
| UX-1520 | Notas: two help texts, an idle search, unlike rows | r1, P185 |
| UX-1641 | «Restáuralo…» shown to people who can't restore (regression R1C-2) | r2, P211 |
| UX-1642 | Proyectos ⋮ «Compartir» opens a page titled «Miembros» (R1C-3) | r2, P212 |
| UX-1643 | «Miembros» said three times on the owner's page (R1C-4) | r2, P212 |
| UX-1644 | Group members list doesn't mark your row «(tú)» (R1C-5) | r2, P212 |
| UX-1645 | Group invite help worded unlike the project's (R1C-6) | r2, P212 |

## Verified in code, device check still needed

| ID | Title | Round, package | Check |
|---|---|---|---|
| UX-1506 | «Miembros · 3» opens a page that doesn't list them | r1, P181 | Phone, two accounts |
| UX-1514 | «Ha cambiado el responsable» never says who it is now | r1, P183 (app half) | Staging, two accounts |
| UX-1521 | TalkBack hears a note's text as an unnamed field | r1, P185 | TalkBack |
| UX-1640 | Activity says a not-yet-synced task may be deleted (R1C-1) | r2, P210 | Phone, two accounts |
| UX-1646 | TalkBack hears nothing while an Activity row waits (R2C-1) | r3, P213 | Emulator, TalkBack |
| UX-1647 | Waiting spinner narrows the Activity row and re-wraps its text (R2C-2) | r3, P213 | Emulator, largest text |

## Still open

- **UX-1648** · S2 · C · An unread Activity row is likely announced twice while it waits.
  - **Source:** regression R3C-1 from P213 (`verify-b4-r3-C.md`), raised in the last round. It was not re-planned, because the run ended after round 3.
  - **Where:** `App/lib/screens/activity_screen.dart:251`.
  - **What happens:** tapping an unread row marks it read, which reloads the list while the row is still waiting. «No leída» then drops out of the row's spoken label, so TalkBack likely reads the whole row a second time.
  - **Fix (a removal):** `label: unread && !waiting ? activityUnread : null`.
  - **Test to add:** an activity override that returns the item as read after the first fetch. While the row waits, its spoken label must stay the same.
  - **Evidence:** inferred from the code and the Flutter engine source (`AccessibilityBridge.java:2027`). It needs a TalkBack check.

## Escalations

None.

## Checks for the owner's phone

1. **UX-1506**, phone with two accounts. Open «Miembros · N» as the owner and as a member. Both see everyone listed, with your own row marked «(tú)».
2. **UX-1514**, staging with two accounts. Reassign a task, then open Activity on the other phone. It should read like «Paul te ha asignado: …».
   - The server sends `assignee_name` and `assignee_is_you` at `Backend/core/group_views.py:311`. I saw this while closing the run; the reviewer didn't check it in this batch.
3. **UX-1640**, phone with two accounts. Open another person's new entry before the task has reached your phone. The task opens. You never see «Es posible que esta tarea se haya eliminado.».
4. **UX-1646 and UX-1648**, emulator with TalkBack, in Spanish. Double-tap an unread Activity row whose task isn't on the phone yet. You hear «Buscando la tarea…» once.
5. **UX-1647**, emulator at the largest system text. When the waiting bar appears, the row's words don't move.
6. **UX-1521**, TalkBack on a note in a task. It reads «Tu nota», then the note's text, with an edit hint.

Two checks need the owner but not a phone:
- **UX-1524:** a native speaker should read two Catalan strings, «Com funciona compartir» and «ha assignat {name}».
- **UX-1503:** in the §7 test, watch whether «¿A quién invitas…?» and «Correo» are read correctly.

## Seen by the reviewers but not raised as findings (for the next review)

- **Activity:** when the task sync itself fails, a waiting row still ends on the "may have been deleted" message. A possible follow-up is to show `loadFailed` instead (`verify-b4-r2-C`).
- **Projects:** the spinner shown while a project is deleted has no label TalkBack can read (`task_lists_screen.dart:365-374`).
- **Group invite dialog at 2× text:** the title is cut at the top, «0/254» is cut, and «Enviar invitación» wraps to two lines. This was already so before this batch.
- **Read-only notes:** for a viewer, TalkBack still reads the note as an unnamed field.
- **Dead invitation:** the system Back button on the "invitation no longer exists" screen postpones the link instead of clearing it. This was already so.
- **Archived project:** its page still offers «Compartir».

## Files changed

- **Screens:**
  - `App/lib/screens/list_sharing_screen.dart`
  - `App/lib/screens/groups_screen.dart`
  - `App/lib/screens/invitation_review_screen.dart`
  - `App/lib/screens/activity_screen.dart`
  - `App/lib/screens/task_lists_screen.dart`
  - `App/lib/screens/home_screen.dart`
  - `App/lib/screens/notes_screen.dart`
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/task_detail_screen.dart`
- **Widgets:**
  - `App/lib/widgets/invitation_cards.dart`
  - `App/lib/widgets/project_scope_control.dart`
  - `App/lib/widgets/task_assignment_picker.dart`
  - `App/lib/widgets/task_list_picker.dart`
  - `App/lib/widgets/note_text.dart`
- **Services:**
  - `App/lib/services/local_capture.dart`
  - `App/lib/services/capture_processor.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`, `app_es.arb` and `app_ca.arb`
  - `App/lib/l10n/generated/*`, regenerated by `flutter gen-l10n`, not edited by hand
- **Tests:**
  - `App/test/sharing_ui_test.dart`
  - `App/test/groups_screen_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/name_ask_test.dart`
  - `App/test/invitation_review_test.dart`
  - `App/test/activity_screen_test.dart`
  - `App/test/home_screen_test.dart`
  - `App/test/project_people_filter_test.dart`
  - `App/test/review_tasks_test.dart`
  - `App/test/project_ui_test.dart`
  - `App/test/task_lists_widget_test.dart`
  - `App/test/project_scope_control_test.dart`
  - `App/test/notes_test.dart`
  - `App/test/notes_ui_test.dart`
  - `App/test/task_editor_form_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/support/hanging_sync.dart` (new)
- **Previews:**
  - `App/test/ux_previews/sharing_previews.dart`
  - `App/test/ux_previews/tasks_previews.dart`
  - `App/test/ux_previews/notes_previews.dart`
- **Ledger:** `.claude/ux-review/ISSUES.md`

## Verified findings that a test now protects

All 26 fixed findings are covered by a widget or unit test. None was device-only.

- **UX-1503:** `sharing_ui_test.dart:873`, `:938`; `groups_screen_test.dart:602`, `:666`; `localization_catalog_test.dart:1743`
- **UX-1513:** `groups_screen_test.dart:357`, `:727`, `:788`, `:838`; `sharing_ui_test.dart:969`
- **UX-1506:** `sharing_ui_test.dart:423`, `:1004`, `:1058`, `:1131`
- **UX-1508:** `name_ask_test.dart:266`, `:305`
- **UX-1509:** `invitation_review_test.dart:956`, `:976`, `:1018`, `:1066`
- **UX-1510:**
  - `activity_screen_test.dart:485`
  - `task_lists_widget_test.dart:911`, `:956`
  - `sharing_ui_test.dart:1217`
  - `groups_screen_test.dart:893`
- **UX-1514:** `activity_screen_test.dart:387`, `:403`
- **UX-1524:** `activity_screen_test.dart:63`, `:448`; `localization_catalog_test.dart:1720`
- **UX-1504:** `home_screen_test.dart:1924`, `:1975`, `:2040`
- **UX-1516:** `task_lists_widget_test.dart:1153`, `:1185`
- **UX-1519:** `project_ui_test.dart:622`, `:637`
- **UX-1522:** `task_lists_widget_test.dart:912`, `:1000`, `:1053`, `:1107`; `project_scope_control_test.dart:31`, `:262`, `:311`
- **UX-1523:** `home_screen_test.dart:1924`, `:2080`
- **UX-1320:** `notes_test.dart:249`, `:262`
- **UX-1517:** `notes_ui_test.dart:702`, `:730`
- **UX-1518:** `capture_free_dictations_test.dart:3151`
- **UX-1520:** `notes_ui_test.dart:578`, `:770`, `:807`
- **UX-1521:** `notes_ui_test.dart:845`, `:871`
- **UX-1640:** `activity_screen_test.dart:613`, `:690`, `:720`, `:758`, `:785`, `:822`
- **UX-1641:** `home_screen_test.dart:2120`, `:2165`, `:2185`
- **UX-1642:** `task_lists_widget_test.dart:546`, `:588`
- **UX-1643:** `sharing_ui_test.dart:411`, `:1149`, `:1198`
- **UX-1644:** `groups_screen_test.dart:920`, `:979`
- **UX-1645:** `groups_screen_test.dart:1007`, `:1064`
- **UX-1646:** `activity_screen_test.dart:877`, `:937`, `:958`, `:997`
- **UX-1647:** `activity_screen_test.dart:905`, `:1020`

## Rounds

| Round | Plan | Packages | Tests | Result | Regressions |
|---|---|---|---|---|---|
| 1 | `plan.json` | P181–P185, all done | passed | 18 of 18 fixed (`verify-b4-r1-C.md`) | R1C-1 to R1C-6, which became UX-1640 to UX-1645 |
| 2 | `plan-b4-r2.json` | P210–P212, all done | passed | 6 of 6 fixed (`verify-b4-r2-C.md`) | R2C-1 and R2C-2, which became UX-1646 and UX-1647 |
| 3 | `plan-b4-r3.json` | P213, done | passed | 2 of 2 fixed (`verify-b4-r3-C.md`) | R3C-1, which became UX-1648 (open) |
