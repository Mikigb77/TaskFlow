# Verify — run 2026-10-22-changes, round 1, area F — 2026-10-22

Mode: verify. Packages WP58 (WEB-1101) and WP59 (WEB-1102). Read with `ux-web.sh diff`, a grep of `src/` and `docs/`, and the renders re-made at 13:38–13:45. The content files changed at 13:20, so the renders are current.

## WEB-1101 — fixed (S3)
- `src/content/legal/en.ts:55`, `es.ts:55`, `ca.ts:55`: only the last sentence of §4's first paragraph changed, to exactly the brief's copy:
  - EN "Without Pro, the task form never sends anything to the AI."
  - ES «Sin Pro, el formulario de tareas nunca envía nada a la IA.»
  - CA «Sense Pro, el formulari de tasques no envia mai res a la IA.»
- The sentence before it ("With Pro, words you type for the AI are sent the same way.") is unchanged. So are §4's paragraphs 2–4, including "You can use manual task entry instead of AI." and its ES/CA lines.
- `company.json:10` is now `2026-10-22`, and `docs/LEGAL_RELEASE.md:3` says "effective **22 October 2026**". `privacy.ca.mobile.light.fold.png` shows «En vigor des del 22 d’octubre del 2026».
- A grep of `src/` and `docs/` finds no "2026-10-21", "21 October", «21 de octubre» or «21 d’octubre». No sentence begins "The task form", «El formulario de tareas» or «El formulari de tasques».
- Render: in `privacy.ca.mobile.light.full.png`, screens 9–11 (crop `crops/privacy.ca.mobile.light.full.s9-11.png`), the paragraph ends «…Amb Pro, el que escrius per a la IA s’envia igual. Sense Pro, el formulari de tasques no envia mai res a la IA.» It wraps cleanly.
- Still true of the app: without Pro, the reminder sheet's own-words row calls `_openPro` (`App/lib/widgets/reminder_plan_sheet.dart:476`, `:207`, `:252`). The only AI call is `ai/reminder-plan/` (`:219`), behind Pro.
- AUDIT, as the tester reports it: §4 has no violations; §3 shows no sideways scrolling on privacy at 320 px or with doubled text; §2 is lab data.
- Still owed: the owner signs off the 22 October 2026 version and the narrowed sentence (WD3), and a native speaker reads the Catalan sentence.

## WEB-1102 — fixed (S2)
- `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:61`: the clause after the colon is gone, and the colon is now a full stop. The text matches the brief exactly in all three languages. No other copy changed.
- A grep of `src/` finds no "asks you once", «una sola vez» or «una sola vegada».
- Renders:
  - `home.es.mobile.light.full.png`, screens 4–5: the card ends «TaskFlow puede recordarte las tareas con fecha.», with the drawing below as before.
  - `home.en.desktop.light.full.png`, screen 3: the card ends "…TaskFlow can remind you of tasks with a date.", its drawing reaches the card's bottom edge with no mint band, the voice and notes cards sit beside it, and offline runs full width below.
- The hero's "can remind you before it" is untouched, as the brief says.

## Regressions
None. The changes are value-only in copy and the version, and the two sentences each changed by a few words.
- WP58: "Without Pro" could suggest the task form does send words with Pro. It does, for reminder words, so that is a true reading, not a regression.
- WP59: the shorter paragraph didn't open a gap in the card (render and WEB-705/WEB-1004 layout tests).
