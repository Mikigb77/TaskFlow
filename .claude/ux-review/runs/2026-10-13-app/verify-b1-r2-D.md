## UX verify — 2026-10-13-app, round 2, area D (P48) — 2026-10-13
**Verdict:** UX-438 is fixed. UX-401 is partly fixed: the card no longer takes room from the agenda, but it is now below the fold, so the person D2a asks may never see the question. No new regressions.
**Evidence level:** code plus ux-tester's measured widget tests (real Manrope). No preview shows the card. `build/calendar-feedback-light.png` (17:42) has no card, but it confirms the layout: at 390×844 the agenda starts about halfway down the screen.

### UX-401 · partly
- **Fixed:**
  - The card is out of the bottom bar. `App/lib/widgets/task_actions.dart` no longer references it.
  - The half-screen cap and the inner scroll are gone (`App/lib/widgets/reminder_ask_card.dart:78-112`).
  - It is now the last item in three places:
    - Calendar's CustomScrollView (`App/lib/screens/calendar_screen.dart:529-532`). It uses 20 px padding, which lines up with the task tiles.
    - Tareas and project pages, through `TaskList.footer` (`App/lib/widgets/task_list.dart:6-22`, `App/lib/screens/home_screen.dart:259`).
    - After the empty state (`home_screen.dart:247-251`).
  - It is hidden while a search is typed.
  - Keep-alive while "Sí" runs (`reminder_ask_card.dart:19-25,57-62`). Tareas' list opens the exact-alarm sheet, and reminders end up on (tester: pass).
  - At 320×568 with 2× text, the task is tappable at launch, and both answers are tappable at the end of the list (tester: pass).
- **Not met:**
  - **Acceptance 2.** At 390×844 with 1× text, the card spans y 663–759, but the bottom bar starts at y 698. Only the first line of the question peeks out. Both buttons sit under `Dictar una tarea`.
  - The newcomer's 1.3–2× text pushes the whole card below the fold. On a day with several tasks, it's further down still. On Tareas, it comes after every task.
  - The newcomer doesn't scroll to look for things (Pernice & Budiu 2016; Fessenden 2018, attention at the top). So the one-time ask that D2a ties to "the first saved task with a date" is easy to miss, and reminders stay off. That is the original blocker, for exactly this person.
  - **Acceptance 1, literal test.** `App/test/reminder_ask_card_test.dart:139-180` (formerly :122) fails. Its premise, a card in the bottom bar, no longer exists:
    - its first line finds no card at launch;
    - after a jump to the end, card plus spacer (332 px) is taller than the 298 px viewport.
  - The UX intent behind the test, that the task is never squeezed off screen, does hold.
- **Fix (needs the planner, because the brief contradicts itself):** ask at the moment D2a names, outside any layout.
  - Right after the first dated task lands and is shown in place, open a one-time modal bottom sheet with the same copy and buttons:
    - question: `¿Quieres un recordatorio antes?` / `Want a reminder before it?` / `Vols un recordatori abans?`
    - buttons: `Ahora no` / `Sí, recuérdamelo`
  - Then delete the in-list card. That subtracts the card from three lists and the footer parameter.
  - A sheet is fully visible at any size and text scale, sits in the thumb zone, and never takes room from the agenda. A once-per-account permission decision is worth that interruption (Android permission guidance: ask in context, at the moment of value).
  - Replace the :139 test with the tester's version: the task is tappable, and both answers are tappable.
  - Weaker alternative: keep the card and lower acceptance 2 to "its top edge shows without scrolling". This leaves 2× users without the question.
- **Needs a device:** the round-1 checks are still pending: the Android 13+ permission dialog, the Android 14 exact-alarm screen, and the 9:00 reminder.

### UX-438 · fixed
- `datedTasksProvider` (`App/lib/providers/reminder_provider.dart:17-39`) records, per ownerKey, the dated open task ids from the first data delivery. The record lives in memory only.
- The card watches it before any early return (`reminder_ask_card.dart:68-69`), so the record is taken even while the card is hidden.
- Copy:
  - `reminderAskQuestion` when a task was saved this session (`reminder_ask_card.dart:86-89`);
  - `reminderAskQuestionTasks` otherwise: `Want reminders before your tasks?` / `¿Quieres recordatorios antes de tus tareas?` / `Vols recordatoris abans de les teves tasques?`. All three catalogs match the brief exactly.
- Tests pass: tasks present at launch get the general question; a task added this session gets the owner's question; a fresh account gets no card, then the owner's question.
- The known edge cases (sync arrivals, swapped offline ids) were accepted in the brief.

### Regressions
None. Checked:
- the duplicate card instances in Calendar and Tareas (the answer is shared through `asked`);
- the separator before the footer when the card is empty (a harmless 10 px);
- reading order: the card is last, after the tasks;
- the snackbar position (it no longer gets pushed up by the bar);
- how "Sí, recuérdamelo" pairs with the new plural question (the neuter "lo" reads naturally; Catalan "ho" also reads naturally).
