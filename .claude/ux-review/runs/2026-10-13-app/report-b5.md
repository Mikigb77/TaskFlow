# UX loop 2026-10-13-app — batch b5 report (closed 2026-10-14)

**Verdict:** batch b5 is closed. It handled 29 findings: the 21 planned for round 1 and 8 regressions from rounds 1 and 2. 16 are verified, 12 are fixed in code and wait for a phone check, and 1 is still open because the rest needs a server change. Every handled finding is named in a test, all three rounds passed their tests, nothing was escalated, and round 3 caused no regressions. Three issues the reviewers spotted along the way were added to the ledger as UX-484 to UX-486.

Evidence: code reading by the reviewers, ux-tester's widget tests, and re-rendered sign-in previews (`App/artifacts/auth/login-light.png` / `login-dark.png`). No preview covers sharing, invitations, Ajustes, Idioma or Hora y región, so those screens were judged from code. No emulator or physical-device run was part of this batch.

## Verified (16)
| ID | Title | Round · package | Test |
|---|---|---|---|
| UX-318 | Tapping a pending invitation silently re-sends it | r1 · P13 | `sharing_ui_test.dart` |
| UX-316 | Five different words for "the other people" | r1 · P13 | `sharing_ui_test.dart`, `project_scope_control_test.dart` |
| UX-339 | Owners see noise lines and empty section headings | r1 · P13 | `sharing_ui_test.dart` |
| UX-307 | After joining, nothing shows what you joined | r1 · P14 | `invitation_review_test.dart` |
| UX-317 | Personal-project delete is hidden; destructive controls look normal | r1 · P15 | `task_lists_widget_test.dart`, `sharing_ui_test.dart`, `groups_screen_test.dart` |
| UX-340 | Leaving or deleting closes the screen without a word | r1 · P15 | `sharing_ui_test.dart`, `groups_screen_test.dart` |
| UX-403 | Sign-up errors land below the fold at large text | r1 · P17 | `auth_gate_test.dart` |
| UX-415 | Sign-in modes: Back exits; recovery labels repeat | r1 · P17 | `auth_gate_test.dart` |
| UX-404 | Settings has 14 entries; Reminders is the 10th | r1 · P18 | `settings_screen_test.dart` |
| UX-418 | Theme tiles break mid-word at 2×; "Sistema" is jargon | r1 · P18 | `settings_screen_test.dart`, `auth_gate_test.dart` |
| UX-431 | Time-zone search ignores accents | r1 · P18 | `regional_ui_test.dart` |
| UX-422 | Time & region: wrong title, second language picker, raw zones | r2 · P75 (partly fixed in r1 by P18) | `regional_ui_test.dart` |
| UX-477 | Unshared project delete still warns "para todas las personas" | r2 · P73 (regression R1C-2) | `task_lists_widget_test.dart`, `sharing_ui_test.dart` |
| UX-479 | Projects ⋮ says "Compartir" where the user can't share | r2 · P73 (R1C-4) | `task_lists_widget_test.dart` |
| UX-480 | Decline confirm not red; "revoca" vs "Anular invitación" | r2 · P74 (R1C-5) | `invitation_review_test.dart`, `sharing_ui_test.dart` |
| UX-482 | Idioma and Apariencia sheets use two selection styles | r2 · P75 (R1D-2) | `language_selector_test.dart`, `settings_screen_test.dart` |

## Fixed in code, waiting for a phone check (12)
Each is in the ledger as `device-check`. The phone checks are listed below.
- UX-475 — Calendar's lit no-date row sits under the save message (r1 · P72) — `capture_landing_test.dart:506-599`
- UX-305 — Sharing is hidden behind ⋮ and missing from the project (r1 · P13) — `sharing_ui_test.dart`, `task_lists_widget_test.dart`
- UX-306 — Invitees can't find invitations, then hit an unexplained code (r1 · P14) — `invitation_review_test.dart`
- UX-301 — Archive and Mute silently switch off a project's reminders (r1 · P15) — `task_lists_widget_test.dart`, `groups_screen_test.dart`, `sharing_ui_test.dart`
- UX-402 — Signing in without an account is a dead end (r1 · P17) — `auth_gate_test.dart`
- U14 (option 1) — Google sign-in first (r1 · P17; D8) — `auth_gate_test.dart` and the `login-light.png` render. Option 2, using the app before signing in, stays rejected for now (DECISIONS.md: the login stays a hard wall) and comes back after the §7 test.
- UX-120 — Capture diagnostics is a Settings row every user sees (r1 · P18; D13) — `settings_screen_test.dart`
- UX-406 — The theme toggle is on 23 surfaces (r1 · P18; D5) — `settings_screen_test.dart`
- UX-476 — Delete or leave lands on a ghost project page (r2 · P73; R1C-1) — `sharing_ui_test.dart`
- UX-478 — Unirme shows no progress; a wrong code is lost (r2 · P74; R1C-3) — `invitation_review_test.dart`
- UX-481 — Recordatorios says Activados when the phone blocks alerts (r2 · P75; R1D-1) — `settings_screen_test.dart`
- UX-483 — Tapping the current language or theme doesn't close the sheet (r3 · P76; R2D-1) — `settings_screen_test.dart:745-930`

## Still open
- **UX-326** · S2 · C — Invitation review copy; "Cancel" reads like reject. The reviewer marked it partly fixed (round 1, P14), and it was not re-planned.
  - Done in the app: the help text, "Sesión iniciada como", and "Ahora no", which keeps the link (`main.dart:233-239`). The Calendar card prefills the code. Tested in `invitation_review_test.dart`.
  - Missing: who sent the invitation. The cause is server-side: there's no `invited_by_name` in `Backend/core/list_views.py:33-35` or `group_views.py:52-54`. It needs a backend change before an app package can show the name.
- **New ledger lines.** The reviewers saw these in passing; none is a regression from this batch, and none is planned yet:
  - **UX-484** · S2 · D — Sign-in still requires 12 characters (`login_screen.dart:491-494`). A newcomer with a short everyday password sees "Usa al menos 12 caracteres" and never reaches UX-402's create-account button. Reviewer's fix: in sign-in mode, only check that the password isn't empty.
  - **UX-485** · S1 · C — Deleting an empty group closes its page without a message (`groups_screen.dart`, no line given). It existed before this run and was outside UX-340's scope. The copy still has to be written.
  - **UX-486** · S1 · D — Time-zone city names are English tz names, so "Londres" or "Nueva York" find nothing (`regional_settings_screen.dart:164`).
- **Not added to the ledger**, minor or for the next review to judge:
  - In create mode, the email-in-use error tells people to sign in but offers no button (the reviewer: "if it shows up in testing").
  - The legacy `US/*` and `Canada/*` zones show "Pacific", "Eastern" and others twice. Their offsets match, so the harm is minimal.
  - The `regionalSettingsHelp` key is unused and still says "zona de captura" (housekeeping).
  - Idioma lists "Como el teléfono" first, while Apariencia lists it last. Moving it to the top of Apariencia would make the two sheets match, if the owner wants that.
  - `sharingProblem` in Spanish and Catalan still uses feminine pronouns left over from "lista". This falls under UX-225's scope (P22).
  - After "Ahora no", the stored invitation link reopens the review screen on every cold start until the user answers it.

## Escalations
None.

## Checks for the owner's phone
1. UX-475: from Calendar at about 390×844, save a task with no date, with animations on and then off. The lit "Bandeja" row shows whole, above the save message.
2. UX-305: "Share this list with your wife", starting inside a project: Compartir → invite → Hecho.
3. UX-306: with a second account, the invitation card is on Calendar. Paste the code, and you land on the project.
4. UX-301: archive a project that has a dated task and tap Deshacer. The reminder still fires.
5. UX-402 (inferred): against the real server, sign in with an email that has no account. The error offers "create an account with this email", and the email is kept.
6. U14: "Continuar con Google" is the first button and sign-in completes from it.
7. UX-120: on a staging build, long-press the version in Otros ajustes to open the diagnostics sheet. On a release build, nothing happens.
8. UX-406: at 320 dp and 2× text, the app bars fit their titles with no theme toggle.
9. UX-476: delete an owned project from its own page. You land on Projects with "Proyecto eliminado", and Back doesn't return to an empty "Proyecto" page.
10. UX-478: with a second account on a slow connection, the spinner stays in the Unirme dialog until the project opens. A wrong code keeps the dialog, the code, and "Pide a quien te invitó el código actual."
11. UX-481: on Android 13+, revoke notifications and return to Ajustes. Recordatorios reads "Bloqueados por el teléfono".
12. UX-483: with TalkBack on, the current language is announced as selected, and double-tapping it closes the sheet.

## Files changed
App code:
- Screens: `App/lib/screens/calendar_screen.dart`, `home_screen.dart`, `task_lists_screen.dart`, `list_sharing_screen.dart`, `groups_screen.dart`, `invitation_review_screen.dart`, `login_screen.dart`, `settings_screen.dart`, `other_settings_screen.dart` (new), `notification_settings_screen.dart`, `regional_settings_screen.dart`.
- Widgets:
  - `App/lib/widgets/invitation_cards.dart` (new);
  - `language_selector.dart`;
  - `custom_app_bar.dart`;
  - `app_components.dart` (outside the package list);
  - `task_editor.dart`: outside the package list; only its `showAppearance: false` argument was removed.
- Providers: `App/lib/providers/invitations_provider.dart` (new), `groups_provider.dart`.
- `App/lib/main.dart`.
- Localisation: `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb` and `request_locale.dart`; `lib/l10n/generated/*` was regenerated by `flutter gen-l10n`, not hand-edited.

Tests:
- Unit and widget tests: `App/test/capture_landing_test.dart`, `sharing_ui_test.dart`, `invitation_review_test.dart`, `task_lists_widget_test.dart`, `groups_screen_test.dart` (new, untracked), `project_scope_control_test.dart`, `auth_gate_test.dart`, `settings_screen_test.dart`, `language_selector_test.dart`, `regional_ui_test.dart`, `appearance_test.dart`.
- `App/test/account_regional_ui_test.dart`, outside the package list: the renamed recovery button broke it.
- Integration tests: `App/integration_test/sharing_flow_test.dart`, `projects_flow_test.dart`, `regional_flow_test.dart`, `reminder_language_test.dart`.

Not reported by any implementer, but changed in the working tree:
- `App/test/support/design_fixtures.dart`: a test-only `api` parameter for a stand-in server, most likely from ux-tester.
- `App/config/`: untracked and dated 2026-10-11, older than this run, so it's not this batch's work. Leave it out of the b5 commit.

## Findings a test now protects
All 16 verified findings and all 12 device-check findings are named in a passing test. The test files are listed per finding above. UX-326's app-side part is covered by `invitation_review_test.dart`. No finding in this batch is device-only.

## Rounds
| Round | Packages | Tests | Fixed | Not yet | Regressions |
|---|---|---|---|---|---|
| 1 | P72, P13, P14, P15, P17, P18 | passed | 19 | UX-326 (partly fixed; server-side), UX-422 (partly fixed) | R1C-1…5 → UX-476…480; R1D-1, R1D-2 → UX-481, UX-482 |
| 2 | P73, P74, P75 | passed | UX-476, 477, 478, 479, 480, 481, 482, UX-422 | none | R2D-1 → UX-483 |
| 3 | P76 | passed | UX-483 | none | none |

Verify notes: `.claude/ux-review/runs/2026-10-13-app/verify-b5-r1-B.md`, `verify-b5-r1-C.md`, `verify-b5-r1-D.md`, `verify-b5-r2-C.md`, `verify-b5-r2-D.md`, `verify-b5-r3-D.md`.
