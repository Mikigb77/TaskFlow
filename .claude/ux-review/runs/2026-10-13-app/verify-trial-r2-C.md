## UX verify — run 2026-10-13-app · round 2 · area C · P46 (UX-425, UX-426) — 2026-10-13

**Verdict:** Both findings are fixed, and P46 caused no regressions.
- Typing `col·`, `col.` or `coŀ` now keeps the note on screen at every keystroke.
- A search with nothing typed returns before it folds any text.
- Compared with P11, no search that used to find something now misses it.
- One device check is still to do: frame time while typing in the Notas search.

**Walked:**
- **Personas:**
  - a Catalan daily user who types `col·legi` one key at a time and stops on the symbols keyboard to find `·`;
  - the newcomer, in Spanish at 2× text, who types `medico` without the accent. It still finds "Médico".
  - the daily user who completes a task on Calendar while Tareas and Notas stay built behind it;
  - TalkBack: nothing changed for it.
- **Flows:**
  - Notas → tap "Cerca notes" → type `c` `o` `l` `·` `l` `e` `g` `i`. "Reunió al col·legi" stays listed after every key, and "No hi ha tasques que coincideixin" never appears. That's 1 tap plus typing.
  - The same typing in Tareas and project pages, Proyectos, and the "Todos los proyectos" sheet gives the same result, because all four use the same helper. Checked in code.
  - Calendar → complete a task. Tareas and Notas rebuild behind it with an empty search, and `matchesSearch` returns at `text_search.dart:5` without folding anything.

**Numbers:**
- **"Nothing matches" while typing a Catalan l·l word:** one keystroke per spelling (`col·`, `col.`, `coŀ`) → none.
- **My trace:** I ran an equivalent of the new helper as a script in the scratchpad. I typed every prefix of 10 Catalan l·l words, in all 3 spellings, in lowercase and capitalised, and checked each against 9 stored forms. Missed matches: 0. The words were col·legi, paral·lel, intel·ligent, il·lusió, novel·la, cel·la, Marcel·lí, instal·lar, sol·licitud and "Col·legi Sant Josep".
- **Compared with P11, across 522 query and text pairs:**
  - matches lost: 0;
  - new matches: 24, and every one is broader, never narrower:
    - `·` typed alone now lists everything, as an empty box does;
    - `l.` typed alone lists anything that contains an l;
    - `wifi` now finds `Wi·Fi`.
- **Text folded on each rebuild with nothing typed:** every open task and every note body → none.
- **On screen:** strings, tap targets and steps are unchanged.

**What the evidence rests on:**
- **Code:**
  - `App/lib/services/text_search.dart` is untracked, so `git diff HEAD` shows nothing. I read it in full and compared it with the round-1 description of P11's version.
  - I also read the four places that call it, and ux-tester's tests.
- **Trace:** the script described under Numbers. I didn't run Flutter.
- **Renders:**
  - The six previews re-rendered at 14:53–14:54 show Calendar and the capture review. None of them shows a search.
  - `App/artifacts/design/notes-list-*.png` dates from 2026-09-22, older than the code, so it isn't evidence.
  - P46 changes nothing visible, so no render is needed.
  - I read `App/build/calendar-feedback-light.png`. It shows the moment UX-426 is about: a task has just been completed and "Tarea completada · Deshacer" is on screen. A render can't show frame time.

### Results

**UX-425 · fixed · Typing "col·" briefly shows "nothing matches"**
- **The fold now works one character at a time:**
  - `text_search.dart:55-56`: `·` folds to nothing, and `ŀ` folds to `l`.
  - `:30`: the pair rule now covers only the full-stop spelling, `l\.l` → `ll`.
  - `:7-8`: when a folded query ends in `l.`, the dot is dropped, so `col.` searches as `col`.
  - `:14`: the text is lowercased before the map, so a capital `Ŀ` becomes `ŀ` and folds too (test at `App/test/text_search_test.dart:75-78`).
- **Acceptance checks:**
  - **The three cases are true: pass** (`App/test/text_search_test.dart:56-60`).
  - **Every prefix of `col·legi`, `col.legi` and `coŀlegi` finds all three spellings: pass** (`:62-73`).
  - **All 11 UX-303 cases still pass, unchanged** (`:5-51`). They include the empty query matching everything, and `cafes` and `ano nuevo` finding nothing.
  - **On Notas, `col·` lists "Reunió al col·legi" and no `noMatches` title appears: pass.**
    - The test runs at 320 × 568 and 2× text, in es, ca and en, in both themes.
    - Where: `App/test/notes_ui_test.dart:156-221`. The `col·` step is at `:200-209`, and the 2× text is set at `:32`.
- **The fix reaches all four searches.** None of the four calling files changed, and each still passes the trimmed query to the helper:
  - Tareas and project pages: `App/lib/screens/home_screen.dart:144` and `:213`;
  - Notas: `App/lib/screens/notes_screen.dart:66` and `:98`;
  - Proyectos: `App/lib/screens/task_lists_screen.dart:342` and `:366`;
  - the "Todos los proyectos" sheet: `App/lib/widgets/project_scope_control.dart:63` and `:137`.
- **A full stop that doesn't follow an `l` is still matched as typed:** `demà.` finds "Ho farem demà. Llavors sí", but not the same sentence without the full stop (`text_search_test.dart:80-84`).
- **No device check is needed.** The fix is pure text matching, and the tests cover it.

**UX-426 · fixed; the typing cost still needs its device check · Empty search still folds every text on each rebuild**
- **The early return:** `text_search.dart:5` (`if (query.isEmpty) return true;`) runs before the first `foldForSearch`, at `:6`. All four fields trim what's typed (lines listed above), so a query of spaces arrives empty.
- **What a task change still costs:**
  - Tareas and Notas are still built behind the other tabs (the IndexedStack at `App/lib/screens/main_shell.dart:53-63`), and both watch the task list.
  - A task change now costs them one joined string per item (`home_screen.dart:214`, `notes_screen.dart:99`). That's the same work as before P11, minus the lowercase pass.
- **`foldForSearch` (`:13-26`) no longer creates a String per character:**
  - It loops once over the code units.
  - ASCII and unmapped characters go straight into the buffer with `writeCharCode` (`:20`). Mapped ones write a constant string from the map (`:22`). No `String.fromCharCode` is left.
  - Emoji and other scripts come through intact (`text_search_test.dart:101-103`).
- **Acceptance checks:**
  - **An empty query matches everything: pass** (`text_search_test.dart:41-44` and `:88-92`).
  - **Code check: met**, read from the source. As ux-tester says, a test can't observe that folding was skipped.
- **Still to do, on a device:**
  - The check: a profile build on a low-end Android phone with about 300 notes of about 1,500 characters each. Complete a task on Calendar, then type in the Notas search. No frame should take over 16 ms.
  - The first half can't now be slower than before P11.
  - The second half still folds every note on each keystroke. That's P11's design, and it's cheaper now; the device has to confirm it's fast enough.

### Regressions caused by P46
None.
- No search that found something under P11 misses now (see the trace under Numbers).
- Every behaviour change shows more results, never fewer, and each comes from a query of one symbol. None of them shows "nothing matches".
- Nothing on screen changed: no copy, layout or control.

### Seen in passing — older than P11, so not regressions, and not in ISSUES.md
**Straight and curly apostrophes don't match each other** (`App/lib/services/text_search.dart:32-57`)
- **What happens:** to the search, "l'escola" and "l’escola" are different words.
- **Why it happens:**
  - On iPhone, Flutter text fields turn `'` into `’` by default. Smart quotes are on unless the field hides its text: Flutter SDK `packages/flutter/lib/src/material/text_field.dart:334-335`.
  - Android keyboards type `'`.
  - Shared projects mix text from both.
- **The app already handles this elsewhere:** its date parser treats the two apostrophes as one (`App/lib/services/quick_schedule_parser.dart:35`).
- **Who meets it:** Catalan uses elision all the time (l', d', s'). Someone who types "l'escola", or just "l'", can get "No hi ha tasques que coincideixin" for a note that exists. Typing "escola" alone works.
- **Fix:** add `'’': "'"` to `_plain`, so both fold to the straight apostrophe.
- **Verify:** `matchesSearch("Portar l'Anna a l'escola", 'l’escola')` and the reverse are both true.
- **Evidence:** traced; P11 and P46 both miss these. Which apostrophe stored text actually carries needs a check on an iPhone, or in a project shared from Android. Suggested severity: 1.

### Keep
- One helper still serves all four searches, and the four calling files didn't change.
- Folding one letter at a time means a half-typed word always matches, however Catalan l·l is typed.
- The fix is invisible: no new control, word or string.
- The tests type every prefix of all three spellings, and run Notas at 2× text and 320 dp, in both themes, in es, ca and en.

### Progress against UX_REVIEW.md (U1–U14)
- UX-425 and UX-426 aren't U items.
- UX-331 (search never crosses tasks and notes) still waits on U13.

### Questions for the owner
None.

### Memory notes
- **Search standard (ui-patterns):**
  - Every search over tasks, notes and projects calls `matchesSearch` in `App/lib/services/text_search.dart`.
  - It ignores case and accents on both sides, and folds one letter at a time: `·` → nothing, `ŀ` → l, `l.l` → ll, and a trailing `l.` searches as `l`.
  - An empty query returns at once.
  - Only the time-zone list still uses plain lowercase (UX-431, P18).
- **Recurring problem, now confirmed and fixed:** a rule that rewrites a pair of letters (`l·l` → `ll`) breaks search-as-you-type. Fold one character at a time, and test every prefix.
- **Not yet folded:** `’` and `'`. iOS turns on smart quotes by default, and the app's date parser already treats the two as one.
- **Tareas and Notas rebuild behind the other tabs** on every task change (the IndexedStack). Any per-item work in their filters runs on every save made elsewhere.
