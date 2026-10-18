## UX verify — run 2026-10-18-commands, round 1, area A (P127, P128, P129) — 2026-10-18

**Verdict:** All six findings fixed in code, and the tester's acceptance tests pass. One edge-case regression at severity 1. The real-model and TalkBack checks still need a phone or staging.

**Evidence used:** `git diff HEAD` of the changed files, read in code; the ux-tester's widget and unit results; the render `App/build/review-batch-light.png` (18:59, newer than the code at 17:48–18:18). It shows the plain two-task result unchanged: «Añadir 2 tareas», Cancelar / Volver a decirlo, «Ver lo que dije». No preview covers the command cards or the project page, so those rest on code and widget tests.

### Results

**UX-901 · fixed**
- `voice_task_screen.dart:3353-3364`: `asWritten` holds when the result is read-only and every card is either a change or deletion that found nothing, or a search with no results. It also needs words, from the transcript or the text.
- `:3551-3558`: a filled, full-width «Guardar tal cual» (in the stretch column) sits above «Cerrar». The gap is restored at `:3571`.
- `_saveResultAsWritten` (`:1375-1388`) uses `CaptureProcessor.asWritten(text:)`, with the transcript before the text. That path drops the commands (`capture_processor.dart:154`) and won't parse empty text (`:71-74`). It sends nothing to the server. Then `saveAtOnce` saves the task and lands it on Calendar as usual.
- «Completada» shows:
  - as a `_Note` under the header on change and deletion cards (`capture_command_cards.dart:800`, `:1001`);
  - after « · » in pick-list rows (`:645-650`), using the same rule as `_FoundRow` (`_completed`, `:603-608`).
- Tester: every acceptance check passes. As the tester notes, a pick list can't hold a completed and an open match at once.
- Device/staging: count how many of the five sentences the real model reads as commands.

**UX-904 · fixed**
- `capture_store.dart:130`: shares are stored with source `shared`.
- `capture_processor.dart:216-242`: a share is sent as `typed`, with no `commands` key. Typed and spoken captures still send `commands: true`.
- Editing a share keeps `shared` (`voice_task_screen.dart:757`, `_session!.source ?? source`).
- Every check in the screen is `== 'speech'` / `!= 'speech'`, so `shared` behaves like typed (grep of `lib/`).
- Device check: share «Busca el informe de ventas» with Pro.

**UX-903 · fixed**
- The ✕ tooltips use `commandDontCreate` / `commandDontChange` / `commandDontDelete` (`capture_command_cards.dart:408`, `:434`, `:732`, `:797`, `:973`, `:998`). Task cards keep «Quitar».
- The message after ✕ depends on the card's kind (`voice_task_screen.dart:2687-2692`).
- The empty state now says «No se hará ningún cambio.».
- `_askToKeep(spoken:)` (`:254-281`):
  - while listening, the question is spoken unless the person is typing words with no audio (`:1584-1590`);
  - on a result, it follows `source` or audio (`:3201-3204`).
- Copy matches the plan in EN/ES/CA.
- Device check: TalkBack speaks «No eliminar …».

**UX-905 · fixed**
- The label chain is at `voice_task_screen.dart:3385-3416`: add+change+delete, add+change, add+delete, then the add labels, then change+delete. A single change that only moves the task reads `reschedule`; any other change reads `saveChangesSentence`. Delete-only reads «Eliminar»; projects only read `commandCreateProjects`.
- `deleteOnly` no longer excludes projects (`:3351`), so the red style and icon come with it.
- `_onlyMoved` (`:283-291`) is shared with `_apply`.
- `commandApply` and `saveChanges` are gone from all three ARBs. The CA 2× test passes.

**UX-902 · fixed**
- On the collapsed card, a deadline-only task shows `taskDeadlineLabel` with a flag (`capture_review_editor.dart:375-397`). The opened card keeps «Sin fecha».
- Found and pick-list rows use `taskDeadlineLabel` (`capture_command_cards.dart:540`, `:645-648`).
- `_save` and `_apply` count the deadline's day among the landing days, and count the task as undated only when it has neither a day nor a deadline (`:2491`, `:2538-2541`, `:2942-2943`, `:3013-3016`).
- `taskAddedDue` reads «Añadida · vence el …» (`:2504-2505`, `:2963-2964`).

**UX-906 · fixed**
- A project page opens when the tap made exactly one project, made no changes, and every task it added went into that project (`voice_task_screen.dart:2980-3007`). It uses `HomeScreen(landing:)` (`home_screen.dart:29-37`, `:57`), which lights the rows through the existing `_landingIds` path (`:541-546`).
- Deshacer pops the page, or removes it if it isn't on top (`:3066-3073`), then reopens the result.
- Every other result lands on Calendar as before.

### Regressions (changed files only)

**R1A-1 · Severity 1 · Deshacer after opening a task from the new project page**
- Where: `voice_task_screen.dart:3066-3073`.
- The moment: the person taps the lit task on the Física page, then taps «Deshacer» on the snackbar while it's still showing.
- What happens:
  - `removeRoute(page)` removes the project page from underneath;
  - the task's detail screen, for a task that undo has just deleted, stays on top;
  - the result sheet reopens over it.
- Fix: on undo, `popUntil` the route under the project page (pop everything above and including it) before reopening the result.
- Evidence: inferred from code; rare (needs a tap inside the snackbar's window).

### Notes (not regressions)
- TalkBack reads the collapsed deadline line as «Fecha y hora: Vence jue, 12 nov», and tapping it opens the day sheet. The plan asked for this (P129 brief).
- «Proyecto creado · Añadida · vence el …» joins three parts with « · ». The «vence» part reads like a separate item, but this is the plan's copy.
- «Guardar tal cual» names the method, not the result. Its rename waits on D3 (UX-919).
