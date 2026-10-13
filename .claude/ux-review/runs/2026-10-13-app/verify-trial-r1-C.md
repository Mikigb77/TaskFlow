## UX verify — run 2026-10-13-app · round 1 · area C · P11 (UX-303) — 2026-10-13

**Verdict:** UX-303 is fixed. All four searches now ignore accents and case, and nothing changed on screen. The new helper caused two severity-1 regressions; neither blocks the round.

**Walked:**
- **Personas:**
  - the newcomer, in Spanish at 2× text, leaving accents out;
  - the daily user, typing fast;
  - a Catalan speaker;
  - TalkBack: nothing changed for it.
- **Flows:**
  - Notas → tap "Buscar notas" → type `medico` → "Médico" is listed. That's 2 actions.
  - Tareas, and any project page (the same screen) → type `reunion con jose` → "Reunión con José".
  - Proyectos → type `collegi` → "Col·legi".
  - The "Todos los proyectos" chip → its sheet → type `medico` → tap "Médico" → the chip now reads "Médico".
  - Each search again, typed one letter at a time, to check that every partly typed word still matches. That is where R1C-1 shows up.

**Numbers:**
- Searches that ignore accents: 0 of 4 → 4 of 4.
- Finding a dictated "Médico" by typing `medico`: a dead end ("No hay tareas que coincidan") → 2 actions.
- Tap targets, words and strings on the four screens are unchanged. No new strings.

**What the evidence rests on:**
- The code (`git diff HEAD`) and ux-tester's tests.
- No preview covers these screens:
  - the renders in `App/build/` (14:07 today) show only Calendar and the review screens;
  - `App/artifacts/design/notes-list-*.png` (2026-09-22) is older than the code.
- The change has no visual part, so no render is needed.

### Results

**UX-303 · fixed · Search fails when Spanish or Catalan users skip accents**
- **The helper** is `App/lib/services/text_search.dart`:
  - `:4-5` folds both the query and the text, so matching works both ways: typing `Médico` also finds a plain "medico".
  - `:9` lowercases, and turns `l·l`, `l.l` and `ŀl` into `ll` (the pattern is at `:19`).
  - `:21-44` maps exactly the plan's letters: á à â ä, é è ê ë, í ì î ï, ó ò ô ö, ú ù û ü, ñ, ç.
- **All four searches call it:**
  - Tareas and project pages: `App/lib/screens/home_screen.dart:213-216`;
  - Notas: `App/lib/screens/notes_screen.dart:98-100`;
  - Proyectos: `App/lib/screens/task_lists_screen.dart:366`;
  - the "Todos los proyectos" sheet: `App/lib/widgets/project_scope_control.dart:137`.
- **The four fields now only trim** what's typed (`home_screen.dart:144`, `notes_screen.dart:66`, `task_lists_screen.dart:342`, `project_scope_control.dart:63`).
- **The no-match messages are untouched** (`notes_screen.dart:102-112`, `home_screen.dart:219-236`, `project_scope_control.dart:140-142`).
- **No search over tasks, notes or projects is left on plain lowercase.** A grep of `App/lib/` finds `toLowerCase().contains` only in the time-zone list (`App/lib/screens/regional_settings_screen.dart:156`), which is outside P11 (see "Seen in passing").
- **Acceptance checks:**
  - **The five unit pairs pass:** `medico`/`Médico`, `collegi`/`col·legi`, `cafe`/`Café`, `jose`/`José`, `reunion`/`reunión` (`App/test/text_search_test.dart:6-16`). The same file also covers whole sentences, accented queries, every folded letter, `l.l`, the empty query, and no false matches.
  - **`medico` lists the note "Médico": pass** (`App/test/notes_ui_test.dart:155`), in es, ca and en, at 2× text and 320 × 568, in light and dark.
  - **All four searches use the helper:** verified in the code above, and by one passing widget test per search:
    - `App/test/appearance_test.dart:340` (Tareas);
    - `notes_ui_test.dart:155` (Notas);
    - `App/test/task_lists_widget_test.dart:186` (Proyectos);
    - `App/test/project_scope_control_test.dart:12` (the sheet; picking the match also sets the chip).
- **No device check needed:** the change is pure text matching, and the tests cover all of it.

### Regressions caused by P11

**R1C-1 · Severity 1 · Typing "col·" briefly shows "nothing matches"**
- **Where:** `App/lib/services/text_search.dart:9` and `:19`. It shows in all four searches whenever a query is typed one letter at a time.
- **The moment** (a Catalan user switching to the symbols keyboard for the dot): "He escrit «col·» i em diu que no hi ha res. Potser no ho vaig desar?"
- **What happens:**
  - The `l·l` rule only folds the pair when both l's are present.
  - The stored "col·legi" becomes "collegi", but the half-typed query "col·" keeps its dot. So for that one keystroke, nothing matches:

    | Stored text | Typed so far | Before P11 | Now |
    |---|---|---|---|
    | Reunió al col·legi | `col·` | found | no match |
    | Reunió al col·legi | `col·l` | found | found |
    | col.legi | `col.` | found | no match |
    | Coŀlegi | `coŀ` | found | no match |

  - What the user sees at that moment:
    - Notas and Tareas show "No hi ha tasques que coincideixin · Prova una altra paraula o un altre filtre.";
    - the sheet shows "No s’han trobat projectes";
    - on Proyectos, the rows simply disappear.
  - One key later, everything is back. But this happens exactly while the user pauses to find the "·" key — briefly, it's the same "it doesn't exist" moment UX-303 fixed.
- **Why it fails:** Nielsen #1, visibility of system status. Search-as-you-type must never say "nothing" for text that is there; anything that is the start of a stored word must keep matching.
- **Fix:** fold one letter at a time, so a partly typed word still matches:
  - drop the middle dot (`·` → nothing) and turn `ŀ` into `l`;
  - for the full-stop spelling, keep `l.l` → `ll`, and treat a query that ends in `l.` as ending in `l`.
  - Nothing changes on screen.
- **Verify:** add to `App/test/text_search_test.dart`: `matchesSearch('Reunió al col·legi', 'col·')`, `matchesSearch('col.legi', 'col.')` and `matchesSearch('Coŀlegi', 'coŀ')` are all true. The existing UX-303 tests still pass.
- **Evidence:** verified in code; I traced the fold with an equivalent script, which produced the table above. How often people type the dot as a separate key depends on their keyboard, so the frequency is inferred.

**R1C-2 · Severity 1 · An empty search still folds every text on every rebuild**
- **Where:** `App/lib/services/text_search.dart:4-16`, called from `App/lib/screens/home_screen.dart:213` and `App/lib/screens/notes_screen.dart:98` on every rebuild.
- **What happens:**
  - Tareas and Notas stay loaded behind the other tabs (the IndexedStack in `App/lib/screens/main_shell.dart:26-35`), and both watch the task list.
  - So every task change re-folds the text of every open task and every note body, one character at a time, even when no search was typed. A change is completing a task on Calendar, a save, or a sync. Folding is a regex pass, then one new string and one map lookup per character.
  - Before P11, the same rebuild did a single lowercase pass.
  - Voice notes keep the whole transcript, up to 8,000 characters (`App/lib/services/capture_processor.dart:42,57`).
- **Who feels it:** probably nobody with a few dozen items. Someone with hundreds of long voice notes on a low-end phone might see completing a task, or typing in search, stutter.
- **Why it fails:** response-time limits (Miller 1968; Nielsen 1993) — every tap should answer within 0.1 s.
- **Fix:** when the query is empty, report a match straight away (`text_search.dart:4-5`). Rebuilds with nothing typed then do less work than before P11.
- **Verify:**
  - Unit test: `matchesSearch` with an empty query returns true without folding (or check this in code review).
  - Device check: a profile build with about 300 notes of about 1,500 characters each. Complete a task on Calendar, then type in the Notas search: the search causes no frame over 16 ms.
- **Evidence:** inferred from the code; needs a device check.

### Seen in passing — older than P11, so not regressions, and not in ISSUES.md
- **The "Todos los proyectos" sheet at large text** (`App/lib/widgets/project_scope_control.dart:45-52`):
  - The sheet is a fixed 70% of the screen height and leaves no room for the keyboard.
  - At 2× text on 320 × 568, ux-tester had to scroll to reach the first match.
  - With the keyboard up, the results probably sit under it (inferred, needs a device check).
  - A possible fix: pad the sheet by the keyboard's height, so the matches stay above the keyboard.
- **A Proyectos search that matches nothing shows nothing** (`App/lib/screens/task_lists_screen.dart:358-367`):
  - Only the zero-projects case has an empty state. A query that matches nothing just leaves blank space, unlike the other three searches.
  - Reuse `projectsNoneFound` ("No se han encontrado proyectos").
  - After P26, the search box only appears from 8 projects, so this matters there.
- **The time-zone search** (`App/lib/screens/regional_settings_screen.dart:156,169`) still uses plain lowercase.
  - P18 turns the zone IDs into city names ("Bogota", "Mexico City"), so someone typing "Bogotá" or "México" will find nothing.
  - P18 should use `matchesSearch`, which also folds the accents in the query.

### Keep
- One helper serves every search and folds both sides, so accented and plain spellings find each other.
- No new control, word or string: the fix is invisible, as it should be.
- The tests run in Spanish and Catalan at 2× text, at 320 dp, in both themes.

### Progress against UX_REVIEW.md (U1–U14)
- UX-303 isn't one of the U items.
- UX-331 (search never crosses tasks and notes) is still a decision, tied to U13 (D7a).

### Questions for the owner
None.

### Memory notes
- **Search standard** (for ui-patterns): every search over tasks, notes and projects goes through `matchesSearch` in `App/lib/services/text_search.dart`, which ignores case and accents on both sides. Only the time-zone list still uses plain lowercase.
- **The area C screen map:** replace "Search everywhere lowercases but doesn't ignore accents" with "Searches fold accents since P11, but still never cross between tasks and notes (UX-331)".
- **A possible recurring problem:** normalising pairs of letters (`l·l` → `ll`) breaks search-as-you-type. Fold one letter at a time.
- **The scope sheet** is 70% of the screen height and leaves no room for the keyboard. At 2× text on 320 × 568, the first match is below the fold.
- **The Proyectos search** has no message when nothing matches.
