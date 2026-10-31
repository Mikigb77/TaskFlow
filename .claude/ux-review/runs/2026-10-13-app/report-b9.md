# UX loop 2026-10-13-app, batch b9: close report (2026-10-14)

**Verdict:** 28 findings handled in 3 rounds. 24 are verified and 4 are verified in code but still need a phone check. Nothing is open and nothing was escalated. Tests passed in all three rounds, and each of the 28 has at least one widget or unit test.

This batch covered:
- **P113:** steps text that was still being lost.
- **P24–P27:** project pages, Activity, the Proyectos screen, groups and sharing.
- **P43:** the naming of Inbox, captures and "Personal".
- **P114–P116:** fixes for 5 regressions and 1 reviewer note found along the way.

**Evidence:** code reading by reviewers B and C, plus ux-tester's widget tests. None of the preview renders shows a project page, a group page or the Activity screen, so no finding here is backed by a render. Nothing was run on an emulator or a phone.

## Verified (24)

Each finding was marked fixed in the last round that checked it, no test for it failed, and a test now protects it.

| ID | Title | Round, package | Test that protects it |
|---|---|---|---|
| UX-624 | A typed step is still lost in two older cases | r1, P113 | `task_editor_form_test.dart:593`, `:651`; `checklist_test.dart:139` |
| U11 | Naming: Inbox vs Personal inbox, "captures", "Lista para…" | r1, P43 | `localization_catalog_test.dart:394-438`; `home_screen_test.dart:558`; `project_ui_test.dart:511`; `calendar_feedback_test.dart:2330` |
| UX-219 | An empty filter looks like all tasks are gone | r1, P24 | `home_screen_test.dart:476`, `:503` |
| UX-311 | "Personal" collides: list examples, the no-project bucket, sections | r1, P43 | `project_ui_test.dart:511`, `:564` |
| UX-314 | A view-only project page keeps its create buttons | r1, P24 | `home_screen_test.dart:361` |
| UX-315 | Project pages inherit the global "For me" filter | r1, P24 | `home_screen_test.dart:413` |
| UX-319 | Group dialogs: "Save" on every step, wrong error text | r1, P27 | `groups_screen_test.dart:212-393` |
| UX-320 | Load failures say "could not be saved" | r1, P27 | `activity_screen_test.dart:211`; `groups_screen_test.dart:513` |
| UX-322 | The bell means Activity and project updates | r1, P25 | `sharing_ui_test.dart:225`, `:769` |
| UX-327 | No landing after creating a project | r1, P26 | `task_lists_widget_test.dart:585`, `:605` |
| UX-328 | Failed group and invite dialogs lose typed input | r1, P27 | `groups_screen_test.dart:311` (the sharing screen's invite dialog was checked in code only, with no test) |
| UX-329 | Projects screen repeats itself and shows idle controls | r1, P26 | `task_lists_widget_test.dart:654`, `:686`, `:797` |
| UX-330 | Group page: unlabelled invitations, spoken-name button; sharing shows emails | r1, P27 | `groups_screen_test.dart:435`, `:489`; `sharing_ui_test.dart:818` |
| UX-332 | Choosing a colour is required to start a project | r1, P26 | `task_lists_widget_test.dart:726` |
| UX-333 | Eyebrow labels and repeated headlines on project pages | r1, P24 | `home_screen_test.dart:516`, `:543` |
| UX-334 | Project rows: "black star", wrong subtitle, count includes done | r1, P26 | `task_lists_widget_test.dart:757` |
| UX-336 | A single group's page is titled "Groups" | r1, P27 | `groups_screen_test.dart:435` |
| UX-338 | No hint that a chosen group will see the project | r1, P26 | `task_lists_widget_test.dart:817` |
| UX-407 | The bell means Activity in the header, reminders elsewhere | r1, P25 | `activity_screen_test.dart:39-67` |
| UX-430 | A Proyectos search with no match shows nothing | r1, P26 | `task_lists_widget_test.dart:701` |
| UX-625 | A view-only project's empty page says "Añade una tarea" (R1C-1) | r2, P114; re-checked r3 | `home_screen_test.dart:668-718`, `:827` |
| UX-627 | A lone role word heads the group page (R1C-3) | r2, P115; re-checked r3 | `groups_screen_test.dart:547` |
| UX-628 | Activity button and screen have different names (R1C-4) | r2, P115; re-checked r3 | `activity_screen_test.dart:240`, `:280` (Catalan, 2× text, 320×568) |
| UX-629 | "Para mí" on a project shows "Un nuevo comienzo" (a reviewer note from before this run) | r2, P114; re-checked r3 | `home_screen_test.dart:777` |

How the screens changed, by reviewer C's counts:
- **Proyectos screen, new account:** 6 tap targets, down to 4.
- **Create-project dialog:** 7 controls, down to 2 plus Cancel/Save.
- **Tareas filter chips:** 5, down to 4.

## Verified in code, still need a phone (4)

| ID | Title | Round, package | Test |
|---|---|---|---|
| UX-429 | The project sheet leaves no room for the keyboard | r1, P24 | `project_scope_control_test.dart:180` |
| UX-321 | Activity rows put who did what last | r1, P25 | `activity_screen_test.dart:99-204` |
| UX-626 | A new project's page can flash "solo lectura" (R1C-2) | r3, P116 (r2's P114 fixed it but caused UX-630) | `home_screen_test.dart:733` |
| UX-630 | A gone project's page offers adding, task lands elsewhere (R2C-1) | r3, P116 | `home_screen_test.dart:875`, `:905`, `:941` |

## Still open from this batch

None.

## Escalations

None.

## Checks for the owner's phone

1. **UX-429:** Open the project picker on a project page and type a search with the keyboard up. The search field and the results stay visible above the keyboard.
2. **UX-321:** Turn TalkBack on and open Actividad del grupo. An unread row says who did what, in which project, and that it is unread.
3. **UX-626:** In Proyectos, tap Nuevo proyecto and save. While the new page opens, its bottom bar should show Añadir tarea the whole time and never "Este proyecto es de solo lectura". This one was inferred from code.
4. **UX-630 (needs two accounts):** While a member has a shared project's page open, remove them from the project. Their page should show the read-only line and "Este proyecto aún no tiene tareas.", with no Añadir tarea. On the same two-account setup, accept an invitation while the refresh fails: the joined project shows read-only until the next sync, which is expected.

## Files changed

- **Screens:**
  - `App/lib/screens/home_screen.dart`
  - `App/lib/screens/activity_screen.dart`
  - `App/lib/screens/groups_screen.dart`
  - `App/lib/screens/task_lists_screen.dart`
  - `App/lib/screens/list_sharing_screen.dart`
  - `App/lib/screens/captures_screen.dart`
  - `App/lib/screens/task_detail_screen.dart`
- **Widgets:**
  - `App/lib/widgets/checklist_editor.dart`
  - `App/lib/widgets/project_scope_control.dart`
  - `App/lib/widgets/task_schedule_label.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`
  - `App/lib/l10n/app_es.arb`
  - `App/lib/l10n/app_ca.arb`
  - `App/lib/l10n/generated/*` (regenerated by `flutter gen-l10n`, not edited by hand)
- **Tests:**
  - `App/test/activity_screen_test.dart` (new)
  - `App/test/home_screen_test.dart`
  - `App/test/groups_screen_test.dart`
  - `App/test/task_lists_widget_test.dart`
  - `App/test/sharing_ui_test.dart`
  - `App/test/project_scope_control_test.dart`
  - `App/test/project_ui_test.dart`
  - `App/test/checklist_test.dart`
  - `App/test/task_editor_form_test.dart`
  - `App/test/task_schedule_label_test.dart`
  - `App/test/calendar_feedback_test.dart`
  - `App/test/appearance_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/support/design_fixtures.dart`
- **Ledger:** `.claude/ux-review/ISSUES.md`

`git status` also lists two untracked folders, `App/config/` and `build/`. No implementer reported changing them, so check them before committing.

## Rounds

| Round | Packages | Tests | Result |
|---|---|---|---|
| 1 | P113, P24, P25, P26, P27, P43 | passed | All 22 findings fixed (B: UX-624; C: the other 21). Reviewer C found 4 regressions: R1C-1, R1C-2, R1C-3 and R1C-4, which became UX-625 to UX-628. UX-629 came from a reviewer note about an older problem |
| 2 | P114, P115 | passed | UX-625 to UX-629 fixed. The UX-626 fix caused regression R2C-1, which became UX-630: a project that had disappeared offered Añadir tarea, and the task was saved outside the project |
| 3 | P116 | passed | UX-630 fixed, and UX-625 to UX-629 re-checked as fixed. No new regressions |

## Notes, not planned (from the verify notes)

These are candidates for a later plan. None of them has an ID yet.
- **Wording mismatch (UX-330):** the sharing screen still heads its pending invitations with the uppercase `pendingInvitations` label, while the group page now says Invitados / Pendiente.
- **Steps text at the limit (UX-624):** at 50 steps, Save throws away text still in Añadir paso after showing `stepLimit`. The loss isn't silent, and it is older than this run.
- **Steps text and the ⋮ menu:** opening ⋮ adds the text typed in Añadir paso as a step before the person picks anything. This comes from P112's rule that leaving the field keeps what was typed.
- **Accepted limit (UX-630):** on a gone project's page, a local task change can make the bar show Añadir tarea for one read.
- **Ledger:** UX-622's note still calls the 50-step and ⋮ cases "still dropped". UX-624 now covers them and is verified. That line was left unedited because this close only touches its own findings.
