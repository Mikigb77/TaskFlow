---
name: site-patterns
description: Settled conventions on the TaskFlow website (CTAs, demo error handling, legal page structure, type sizes, icons, language) to enforce consistency
metadata:
  type: project
---

Settled by run 2026-10-18-site (b1-b4). Enforce these; a deviation in a new change is a finding.

**Calls to action**
- Primary CTA everywhere points to the live demo `#voice`, never to a download (Play not published). Availability line: "Coming soon to Google Play / You can't download it yet".
- Demo button is "Done" / «Listo» / «Fet» (matches the app). No "Create drafts".

**Live voice demo (VoiceDemo.tsx)**
- Never shows a server `error` string or `reason.message`; every code maps through `failureFor` to copy in `src/content/site/*.ts` `voice.errors.*`.
- Opening failure uses `errors.offlineOpening` (no "what you said is kept"); sending failure uses `errors.offline`.
- Recovery is always a filled `.button` "Try again" under the alert; alert takes focus and is announced.
- Waiting: heading "Understanding…" only; at 10 s "Still understanding… up to half a minute" + "Stop waiting"; page timeout 40 s. Stop keeps text and resends with the same request id (doesn't use another try), shows `errors.processing`.
- Stages `off` / `unverified` replace the form with the static example + reason alert + hand-over; badge reads "Live demo", never a tries count.
- Turnstile: interaction-only, compact <300 px, retry never; 2 failures → `unverified`.
- Close demo disabled while recording/loading.

**Type and targets**
- All font sizes in rem (voice.css, legal.css); body text ≥ 1rem incl. legal `dd` values. Targets ≥ 44 px on phones.
- Legal prose `max-width: 52ch` (≈ 75 chars at 1440).

**Legal pages**
- h1 = document name; plain numbered summary first; in-force line only; icons: `arrow` for internal, `arrowUp` only for `http` links, none on mailto.
- Email addresses render split with `<wbr>` before `@` (not hard-coded).
- Catalan uses «suprimir/supressió» for the account (eliminar only for records/exports).
- Per-page openGraph + twitter (summary_large_image) in the page's language.

**Language**: every string in en/es/ca from one shared type; app's words for features; no jargon (draft, allowance, sync, transcript, voice-to-task) on home.

Related: [[site-map]], [[recurring-problems]].
