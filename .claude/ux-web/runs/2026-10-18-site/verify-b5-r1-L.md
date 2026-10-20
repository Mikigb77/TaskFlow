## UX web verify — run 2026-10-18-site, batch b5, round 1, area L (WP47) — 2026-10-20

**Verdict:** WEB-109 and WEB-729 are fixed. No regressions found. The changes stay held until the owner signs off WD3 and a native speaker reads the Catalan.

**Evidence used:** this run's own diff (`ux-web.sh diff`) of `src/content/legal/{en,es,ca}.ts`, `company.json`, `docs/LEGAL_RELEASE.md`, `tests/legal.spec.ts` and `tests/ux-web-legal.spec.ts`; a grep of the legal content; `AUDIT.md` §11 (metadata, lines 698-700) and §9 (landmarks, lines 545-546); `Backend/core/ai.py:118-133`. The renders (06:40-06:41) are newer than the edits (04:57). I couldn't crop the renders: WSL failed to start (`Wsl/Service/CreateInstance/E_UNEXPECTED`), so the visible-text claims rest on code, on AUDIT.md and on the tester's passing specs, not on my own reading of the pixels.

### WEB-109 — fixed
- Privacy §3 (`#purposes`): EN `the suggested tasks you ask for`, ES «las tareas sugeridas que pides», CA «les tasques suggerides que demanes» (en/es/ca.ts:42).
- Privacy §8 (EN only): `for the demo’s limits` (en.ts:140).
- Terms description (en.ts:191-192, es.ts:185-186, ca.ts:185-186): matches the brief exactly. AUDIT.md §11:698-700 shows the same text as the description and the og:description.
- Terms §2, §3 and §6 (EN): `get around a limit`, `storage or AI limits`, `included features and limits` (en.ts:213, :221, :247).
- Terms §5: the headings are `5. AI suggestions` / «5. Sugerencias de la IA» / «5. Suggeriments de la IA» (en.ts:237, es/ca.ts:231). AUDIT.md §9:545-546 lists the region “5. AI suggestions”. The id `ai` is kept. In the second paragraph, ‘reviewed suggestions’ / «las sugerencias revisadas» / «dels suggeriments revisats».
- A grep of en/es/ca.ts for draft|allowance|transcri|AI Studio|borrador|esborrany finds nothing. The only matches are the mail box's own words in `index.ts:53/98/142`, which the brief keeps.
- `company.json:10` `version` is `2026-10-20`, and `docs/LEGAL_RELEASE.md:3` says ‘effective **20 October 2026**’. Both tests' pinned dates moved with it.

### WEB-729 — fixed
- Privacy §2 (`#data`, :33 in each language) matches the brief exactly, including ‘to apply usage limits’.
- Privacy §4, first paragraph: the three sentences match the brief in each language. Second paragraph: ‘The app can use Google’s Gemini API, with Google Cloud’s Vertex AI as a fallback; the website demonstration uses Vertex AI.’ and the ES and CA versions match. ‘Google can process it outside the EU’ is kept. The third paragraph (en.ts:57) has no diff lines.
- The claim is true: `Backend/core/ai.py:118-133` uses the Gemini API key client, with a Vertex AI client as the fallback.

### Regressions (changed files only)
None. Checks:
- No link or label in `src/` still points at the old §5 heading.
- `#ai` is unchanged.
- No sentence lost a fact.
- The descriptions are 103-113 characters.

Still to check on a device or with a person: a native Catalan read of privacy §2, §3 and §4, the terms description and terms §5; and the owner's WD3 sign-off of the effective date, 20 October 2026.

Seen but out of scope, not a regression: terms §5's first paragraph (EN) still says ‘AI capture is optional’, which is older text that no reviewer flagged.
