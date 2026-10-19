# Verify — run 2026-10-18-site, round 1, area F (WP19) — 2026-10-19

Scope: WP19 (WEB-105, WEB-107, WEB-109, WEB-110, WEB-111). Evidence: the run's diffs (`ux-web.sh diff`), current source, renders made 10:59–11:02 today (newer than `HomePage.tsx` 05:48, `en.ts` 09:45, `global.css` 10:05), `AUDIT.md` (11:19), the tester's passing specs, and the app's ARB files.

## Results

| ID | Result | Evidence |
|---|---|---|
| WEB-111 | fixed | `src/components/HomePage.tsx:136-158`: `#questions` holds only `h2#questions-title` and the list; eyebrow, intro `<p>` and `.faq-doodle` gone, with their `lines()` helper and `Fragment` import. `global.css`: `.faq-intro > p`, `.faq-doodle*` and the 800 px `.faq-doodle` block removed. `types.ts:74-77` has only `title` and `items`. Titles `Questions` / `Preguntas` / `Preguntes` (`en.ts`, `es.ts`, `ca.ts` faq.title) match the header and footer labels. Renders `home-faq.en.desktop.light.view.png`, `home-faq.en.mobile.light.view.png`, crops of `home.ca.mobile-w320.light.full.png` and `home.es.mobile.dark.full.png`. AUDIT §9 landmarks: region “Questions” / “Preguntas” / “Preguntes”; §12 outline h2 in all three. |
| WEB-105 | fixed | Voice question and answer equal the brief in all three languages (faq.items[3]). Uses the app's words: `addTask` “Add a task”/“Añadir tarea”/“Afegeix una tasca”, `captureFinish` “Done”/“Listo”/“Fet”, `undo`. Says several at once, changes by voice with undo, and that words go to Google; no “transcribes”/“AI”/“drafts”. Answer text `.faq-item p` is 1rem (`global.css:753-758`, 580 px block `:1318-1321`), summaries 1rem. Tester: copy, ≥16 px and axe (two open, light and dark) pass. |
| WEB-107 | fixed | Sharing Q/A equal the brief. Project/Share/created-by/one-person filter match `shareProject` (Compartir/Comparteix), `createdBy`, the people filter; no “list”, no code, no “still being tested”. |
| WEB-109 | fixed | Offline Q/A equal the brief; no “sync”, “shared-list”, “attachment transfers”. `tests/website.spec.ts` updated in both the JS and no-JS tests to `/check, add and complete them without internet/`. |
| WEB-110 | fixed | Notes Q/A equal the brief; no “Choose Task or Note”. Matches `notes` tab name, `addNote`, `notesEmptyHelp` (“Write or dictate… links or a checklist”; ES «lista de pasos», CA «llista de passos»), `noteTitleHint` (Wi-Fi password / clave del wifi / contrasenya del wifi). |

Order on all three homes: download, pricing, account, voice, offline, sharing, notes (source and AUDIT §9 disclosure list, rows 870–892).

Word sweep outside `#voice` (home content files, `HomePage.tsx`, Header, Footer, Phone, layout, both page routes), EN/ES/CA: none of voice-to-task, draft/borrador/esborrany, allowance, shared list / lista compartida / llista compartida, share a list, MiB, transcri*, sync/sincroni*, Task or Note. `#voice` still says “voice-to-task” (AUDIT §3 row) — WP26–WP29's, excluded.

## Regressions

None in the changed files' FAQ section on /, /es/, /ca/ (desktop, phone, 320 px, dark checked in renders). AUDIT §4 lists only an axe *incomplete* (bgOverlap) on `.faq-item:nth-child(7) > summary`, en mobile, ratio estimate 11.70:1 / 15.07:1 — not a violation and not visible in the renders.

Notes (not findings):
- `src/styles/global.css:131-135` `.section-eyebrow > span` no longer matches anything: the FAQ's `<span>04 /</span>` was its last user (LegalPage's eyebrow has no span). Not visible to visitors; the conventions ask for no dead CSS, so the implementer may drop it in passing.
- Desktop: the FAQ's left column (0.8fr) now holds only the one-word heading, with white space below it (`home-faq.en.desktop.light.view.png`). It reads fine and was the brief's subtraction; not a regression.
- `h2#questions-title` stays 45/31 px under text-200% (AUDIT §3/§6) — the global `h2` rule, pre-existing, not this run's.
- Catalan copy marked organizer's (notes and offline questions, «La puc fer servir sense connexió?», «Puc desar notes a més de tasques?») reads naturally to me; still worth a native read.
