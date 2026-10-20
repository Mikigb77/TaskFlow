# UX web report: run 2026-10-18-site, batch b4 (2026-10-19)

**Verdict:** All 29 findings this batch checked are fixed. That is the 21 planned findings in WP29–WP32, plus the 8 regressions those packages caused, which became WEB-721 to WEB-728. 16 are now **verified** and 13 are **device-check**: fixed in code and by tests, with a real device or a person still to confirm them. Nothing was escalated. Two findings failed once, in round 1: WEB-205 and WEB-204. Both were fixed in round 2 and checked again in round 3. Every file this batch changed is held by the other session's uncommitted work, except `tests/website.spec.ts`.

## Verified (status `verified`)

| ID | Title | Package |
|---|---|---|
| WEB-401 | Connection failures show raw developer text | WP29 |
| WEB-12 | Demo copy uses jargon a newcomer can't parse (last part) | WP29 |
| WEB-721 | Opening the demo offline promises a kept recording | WP43 (regression R1H-1) |
| WEB-722 | Tries badge counts tries when the demo can't run | WP43 (R1H-2) |
| WEB-203 | The privacy page's first screen has no privacy facts | WP30 |
| WEB-212 | Internal links carry the "leaves the site" arrow | WP30 |
| WEB-312 | Legal pages share without an image; X tags in English | WP30 |
| WEB-113 | Privacy policy is behind the app on six points | WP31 |
| WEB-501 | Privacy and delete pages say RevenueCat's record stays | WP31, WP32 |
| WEB-207 | The demo's privacy link lands on the app's section (last part) | WP31 |
| WEB-602 | Privacy §8 describes a site this run removed | WP31 |
| WEB-209 | Privacy, terms and legal notice use engineering words | WP31 |
| WEB-210 | Apple subscriptions mentioned on an Android-only product | WP31, WP32 |
| WEB-725 | Delete page: missing space between two sentences | WP44 (R1L-1) |
| WEB-726 | Legal version line wraps on phones, dot dangling | WP44 (R1L-2) |
| WEB-727 | Privacy promises no surname; the server may keep it | WP44 (R1L-3) |

## Fixed, but a device or person check is left (status `device-check`)

| ID | Title | What's left |
|---|---|---|
| WEB-13 | Waiting for a result: no update, no way out | Real wait times on a slow phone connection |
| WEB-403 | Security check: a disabled button, no reason, no retry | The deployed site with a content blocker; how Cloudflare's real interaction-only and compact widget looks (the tests use a stand-in) |
| WEB-8 | Text in hero, demos and closing card is tiny (last part) | A real phone at arm's length |
| WEB-2 | Home and demos only in English (last part) | The 307's Location after a deploy; Android at its largest font; a native Catalan read of the demo's strings (`verify-b3-r1-H.md`, `verify-b4-r1-H.md`) |
| WEB-723 | Security check gives up: form vanishes with no reason | A native Catalan read of «La comprovació de seguretat no s'ha carregat…»; TalkBack in Spanish |
| WEB-724 | Stop waiting gives no message that Try again is free | TalkBack in Spanish |
| WEB-202 | Delete page explains what goes in jargon | Read the delete summary aloud to someone over 60; a native Catalan read |
| WEB-204 | Delete page: the quicker in-app route looks like small print | A real 320 px phone on /es/delete-account/; TalkBack or VoiceOver announcing the hidden heading |
| WEB-205 | Legal text: 14 px grey, ≈140-character lines, doesn't grow | Android Chrome's largest text size |
| WEB-206 | Catalan pages use three verbs; the app says «Suprimeix» | A native Catalan read |
| WEB-211 | Legal notice: placeholder line, mislabelled button, Catalan-only registry | The owner confirms the English and Spanish registry lines at sign-off |
| WEB-213 | "Versión 2026-10-16" doesn't read as "in force since" | A native Catalan read of «En vigor des del 19 d'octubre del 2026» (the date format comes from Intl) |
| WEB-728 | Support address breaks inside the domain on 320 px phones | Copy the address with a long press on a real 320 px phone |

## Still open

This batch didn't plan or check any of these:
- **WEB-6** (the sample walkthrough) and **WEB-9** (the live demo's taps and words). Their ledger lines said "Left: WP29", and WP29's verified work looks like it covers those parts: the static example when the live demo can't run, and Turnstile `interaction-only`. But no reviewer ruled on WEB-6 or WEB-9 by ID, so they stay open until a later check confirms them.
- **WEB-109** (the site names features differently from the app). The terms and privacy §8 parts and the demo's words are left. One related note from this batch: the English terms description still says "AI drafts" (`src/content/legal/en.ts:144`), and that text now also goes out as `twitter:description`.
- **WEB-707** (English FAQ marked as Spanish or Catalan). The FAQ half is left (WP19).
- **WEB-720** (S1, from b3): the held Try again button's focus ring fades to 2.4:1. It wasn't re-planned; the fix is in its ledger line.
- **WEB-701** is a decision: WD15, Safari on the owner's iPhone.

Notes from the reviewers that aren't findings, for the next pass:
- Privacy §2 and §4 still use "drafts", "allowances", "transcript" and "AI Studio/Gemini API route". They were outside WEB-209's brief.
- The demo's hand-over says "Coming soon to Google Play", while the conventions say "Coming soon to Android". The demo's privacy line says "Google's AI".
- On desktop, the 52ch legal column leaves a wide empty band next to the full-width company card, and the delete page shows two language switches in its first screen. Both were prescribed by the briefs; at most a polish item.
- The company card's registry value runs about 95 characters on one line at 1440 px. It's a data value, outside WEB-205's acceptance.

## Escalations

None.

## Checks for a real device or a person

- A native Catalan read of all new Catalan from this batch: the demo strings (WP29, WP43; list in `verify-b4-r1-H.md`) and the legal copy (WP30–WP32, WP44), including «del 2026».
- TalkBack in Spanish: the security check's give-up alert and the Stop waiting alert (WEB-723, WEB-724).
- TalkBack or VoiceOver announcing the delete page's visually hidden heading (WEB-204).
- A real 320 px phone on /es/delete-account/: the email button in the first screen, and copying the support address with a long press (WEB-204, WEB-728).
- Android Chrome at its largest text size on a legal page (WEB-205).
- The deployed site with Cloudflare's script blocked by a content blocker, and Turnstile's real interaction-only and compact look (WEB-403).
- Real wait times for the voice demo on a slow phone connection (WEB-13).
- A real phone at arm's length: the demo's text size (WEB-8).
- Read the delete summary aloud to someone over 60 (WEB-202).
- The owner confirms the English and Spanish registry lines (WEB-211).

## Files changed

**Website (TaskFlowWeb)**

Held, because these tracked files also contain another session's uncommitted lines. Commit only this run's lines (`ux-web.sh stage`):
- `src/components/VoiceDemo.tsx`
- `src/styles/voice.css`
- `src/content/site/types.ts`, `src/content/site/en.ts`, `src/content/site/es.ts`, `src/content/site/ca.ts` (b3's uncommitted voice strings are in these too; this batch only added new keys)
- `tests/voice.spec.ts`, `tests/support/ux-voice.ts`, `tests/ux-web-voice.spec.ts`
- `tests/ux-web-legal.spec.ts`

Held, because these are the other session's untracked files. They can't be committed until that session commits them:
- `src/components/LegalPage.tsx`
- `src/styles/legal.css`
- `src/content/legal/index.ts`, `src/content/legal/en.ts`, `src/content/legal/es.ts`, `src/content/legal/ca.ts`, `src/content/legal/company.json`
- `docs/LEGAL_RELEASE.md` (this run changed lines 3, 28 and 36)
- `tests/legal.spec.ts`

Not held. It had no uncommitted changes at the fix-run base, so it can be committed:
- `tests/website.spec.ts`

**App repo (TaskFlow)**
- `.claude/ux-web/ISSUES.md`
- `.claude/ux-web/runs/2026-10-18-site/plan-b4-r2.json`, `plan-b4-r3.json`, `plan.md`
- `.claude/ux-web/runs/2026-10-18-site/verify-b4-r1-H.md`, `verify-b4-r1-L.md`, `verify-b4-r2-H.md`, `verify-b4-r2-L.md`, `verify-b4-r3-L.md`
- `.claude/ux-web/runs/2026-10-18-site/report-b4.md` (the main session saves this report)

## Which tests protect the verified findings

A test protects every finding verified or moved to device-check in this batch:
- `tests/ux-web-voice.spec.ts`: WEB-13, WEB-401, WEB-403, WEB-12, WEB-721, WEB-722, WEB-723, WEB-724.
  - WEB-8 also in `tests/ux-web-global.spec.ts` and `tests/ux-web-legal.spec.ts`.
  - WEB-2 also in `tests/ux-web-frame.spec.ts`, `tests/ux-web-global.spec.ts` and `tests/ux-web-legal.spec.ts`.
- `tests/ux-web-legal.spec.ts`: WEB-203, WEB-205, WEB-212, WEB-213, WEB-211, WEB-312, WEB-113, WEB-501, WEB-602, WEB-209, WEB-210, WEB-202, WEB-204, WEB-206, WEB-725, WEB-726, WEB-727, WEB-728.
  - WEB-207 also in `tests/ux-web-voice.spec.ts`.
  - WEB-726 also in `tests/legal.spec.ts:28`.
  - The WEB-728 test fails without the `<wbr>`.

## Rounds

| Round | Packages | Tests | Review result |
|---|---|---|---|
| 1 (`plan.json`) | WP29, WP30, WP31 done; WP32 partly done | **Failed** (WEB-205's 80-character line limit at 1440 px and WEB-204's 320 × 568 first screen) | 19 fixed. WEB-205 and WEB-204 partly fixed (first failure). 7 regressions: R1H-1 to R1H-4 became WEB-721 to WEB-724; R1L-1 to R1L-3 became WEB-725 to WEB-727 |
| 2 (`plan-b4-r2.json`) | WP43, WP44 done | Passed | 9 fixed (WEB-721 to WEB-727, WEB-205, WEB-204). 1 regression: R2L-1 became WEB-728 |
| 3 (`plan-b4-r3.json`) | WP45 done | Passed | WEB-728 fixed. WEB-205 and WEB-204 checked again, still fixed. No regressions |
