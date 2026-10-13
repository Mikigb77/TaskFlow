## UX verify — run 2026-10-13-app, round 1, area D (P32) — 2026-10-13
**Verdict:** UX-401 partly fixed. The question, the answers, the one-tap enable and the 9:00 default all work. But on a small phone with 2× text, the card squeezes the agenda off screen.

### UX-401 · partly
- **Fixed:**
  - **The card.** It's built at `App/lib/widgets/reminder_ask_card.dart:48-66`. It shows only when all three hold:
    - the platform supports reminders;
    - reminders are off and the question hasn't been answered (`asked`);
    - the account has an open task with a date or a deadline.
  - **Where it sits.** It's at the top of TaskActions (`task_actions.dart:19`). That covers Calendar (`calendar_screen.dart:532`) and Tareas and project pages (`home_screen.dart:267`).
  - **Copy.** It matches in all three catalogs: `app_es.arb:604-606`, `app_en.arb:854-859`, `app_ca.arb:583-585`.
  - **Order.** The filled `Sí, recuérdamelo` comes last, which puts it on the right. The text button `Ahora no` comes first.
  - **Either answer is stored.** It's saved before acting (`reminder_ask_card.dart:24-46`), and `asked` is persisted in the JSON (`reminder_preferences.dart:14,29,38`). So a refused permission still counts as answered.
  - **"Sí" uses the shared action.** It calls `turnOnReminders` (`reminder_control.dart:37`) in the same tap. That action covers the permission, the exact-alarm sheet, `reconcile` and the confirmation.
  - **The 9:00 default.** It's set as `dateOnlyTime ?? 540` (`reminder_control.dart:63`), so a time already chosen is kept. The settings switch (`notification_settings_screen.dart:200`) and the chip (`reminder_control.dart:237,315`) both run the same action, so the default applies on every path.
- **Tests:** 7 of the 8 ux-tester tests pass, covering all four listed acceptance checks.
- **Not met — the brief's "never covers the task just added":**
  - `reminder_ask_card_test.dart:122` fails at 320×568 with 2× text. Scrolled to the end, the task row isn't hit-testable above TaskActions.
  - Cause: the card is capped at half the screen height (`reminder_ask_card.dart:75-77`, about 284 dp here). That's on top of the creation buttons (stacked at 2×) and the shell's NavigationBar, all inside `bottomNavigationBar`. That leaves the agenda body close to zero height.
  - This is the newcomer's exact setup: large text, often a small phone.
- **Render:** no current preview shows the card. `build/calendar-feedback-light.png` (17:16) has no card, so the visual judgement rests on code plus the failing test.
- **Fix:** subtract height rather than add UI.
  - On short viewports — viewport height under about 640 dp, or text scale above 1.5 — render the card as the first item of the agenda's scroll view instead of in the bottom bar. Elsewhere, keep it in the bottom bar.
  - Alternatively, cap the card at the height of its own content, with no scroll and no half-screen cap. Then make TaskActions keep at least about 120 dp of body for the agenda, by laying out the card question and its two buttons more compactly.
  - Verify: `reminder_ask_card_test.dart:122` passes.
- **Needs a device:**
  - the Android 13+ permission dialog and the Android 14 exact-alarm screen, then the upcoming alerts showing the task as programado;
  - a 9:00 alert actually firing.

### Regressions (changed files and touched flows only)
- **R1D-1 · Severity 2 · "Antes" has no referent when the card appears at cold start.**
  - Where: `reminder_ask_card.dart:48-66`.
  - The moment: an existing account with dated tasks sees `¿Quieres un recordatorio antes?` on launch, with no new task in sight. The person thinks: "Before what?"
  - The condition is "any open dated task", so the card isn't tied to a just-saved task.
  - Why it fails: Nielsen, match with the real world; recognition over recall.
  - Fix: keep the brief's copy right after a save. When no task was saved this session, use EN `Want reminders before your tasks?` / ES `¿Quieres recordatorios antes de tus tareas?` / CA `Vols recordatoris abans de les teves tasques?`.
  - The copy came from the owner's brief (D2a), so the organizer may prefer to log this as a question for the owner.
  - Evidence: verified in code.

No other regressions in `reminder_preferences.dart`, `task_actions.dart`, `reminder_control.dart` or `notification_settings_screen.dart`:
- The settings switch still saves through `asked` (`notification_settings_screen.dart:142`).
- Two mounted cards (Calendar and Tareas) both hide once `asked` is written, because each invalidates `reminderPreferencesProvider`.
