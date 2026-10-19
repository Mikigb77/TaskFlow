# UX web report: run 2026-10-18-site, batch b2 (2026-10-19)

**Verdict:** 20 findings were checked over two rounds, and the tests passed both times.
- 8 are verified.
- 6 are verified in code and by tests but still need a real device or a person (`device-check`).
- 6 had this batch's part fixed but stay open, because the rest of each is in later packages (WP24–WP31), most of them held.

Round 1 caused three regressions, all Severity 1 (WEB-711, WEB-712, WEB-713). Round 2 fixed all three. Nothing was escalated.

## Verified (reviewer said fixed; no test for it failed)
| ID | Title | Package | Locked by |
|---|---|---|---|
| WEB-111 | Feature headings are mood lines; a scanner learns nothing | WP19 (FAQ heading, no eyebrow, intro or doodle) + WP37 (dead `.section-eyebrow > span`) | `tests/ux-web-features.spec.ts`, `tests/ux-web-global.spec.ts` (WP37 rule scan) |
| WEB-105 | Several tasks in one dictation is never told | WP19 (voice answer, EN/ES/CA, 16 px) | `tests/ux-web-features.spec.ts` |
| WEB-107 | Sharing FAQ says "lists" and describes the old invite | WP19 | `tests/ux-web-features.spec.ts` |
| WEB-3 | Nothing near a button says the app isn't out | WP20 (phone menu: "Coming soon to Android") | `tests/ux-web-global.spec.ts`, `ux-web-home.spec.ts`, `ux-web-features.spec.ts` |
| WEB-306 | The 404 page is an English idiom hiding "not found" | WP21 | `tests/ux-web-global.spec.ts` |
| WEB-311 | First view fetches both theme screenshots and a TTF font | WP22 (`next/font/local` WOFF2, 24 KB). **Held** in `layout.tsx` | `tests/ux-web-frame.spec.ts`, `ux-web-home.spec.ts` |
| WEB-704 | No Android trademark line where the site names Android | WP23. **Held** in `Footer.tsx`; commit only the run's lines | `tests/ux-web-frame.spec.ts` |
| WEB-711 | Language links are 4 px apart (R1G-2) | WP37 (gap 8 px) | `tests/ux-web-global.spec.ts` |

## Verified, still needing a device or a person (`device-check`)
| ID | Title | What's left |
|---|---|---|
| WEB-110 | Notes FAQ describes a Task/Note choice the app removed | A native Catalan read of «Puc desar notes a més de tasques?». Test: `ux-web-features.spec.ts` |
| WEB-304 | Spanish and Catalan pages keep an English frame | TalkBack on `/es/privacy/` (does it read the title with a Spanish voice?), and a native Catalan read of the frame, 404 and metadata strings (list in `verify-b2-r1-G.md`). Without JavaScript `<html lang>` stays `en`, which review G accepted. **Held** in `layout.tsx` and `Footer.tsx`. Tests: `ux-web-frame.spec.ts`, `ux-web-global.spec.ts` |
| WEB-302 | The link preview doesn't say what TaskFlow is | A WhatsApp preview of `/es/` on a Spanish phone, after a deploy. The layout defaults are **held** in `layout.tsx`. Tests: `ux-web-frame.spec.ts`, `ux-web-global.spec.ts` |
| WEB-307 | Phone header: two unlabelled icons; theme outranks the menu | Android at its largest font size: the menu and the switch. Test: `ux-web-global.spec.ts` |
| WEB-712 | At 200% text the desktop header wraps to two rows (R1G-3) | A desktop browser at Very large text. No render shows the menu open at 200% text; that it fits is inferred from the CSS. Test: `ux-web-global.spec.ts` (live `Page.setFontSizes`) |
| WEB-713 | The 404 lost its font preload (R1G-1) | A 404 on a phone on mobile data, after a deploy. Option 2 was used: `preload()` of the built woff2's hashed URL, guarded by a test that it matches the home's preload. **Held** with WP22's `layout.tsx`. Test: `ux-web-frame.spec.ts` |

## Still open (this batch's part is done)
- **WEB-2:** WP20 (the switch in the header, menu and footer) and WP22 (`<html lang>`, held) are fixed. Left: WP24 (the legal pill), and WP26–WP29 (the demo, still in English on /es/ and /ca/). All of these are held.
- **WEB-4:** WP20 (the header's "Explore the app" is gone) and WP23 (footer, held) are fixed. Left: WP26 ("Try the live demo", held).
- **WEB-109:** WP19 (the offline answer, and the word check across the home) is fixed. Left: WP31 (terms and privacy §8, held), and the demo's wording with WEB-9 and WEB-12.
- **WEB-313:** WP22 (two `theme-color` entries, and `apply()` updates them; held) is fixed. Left: WP25 (dark mode without JavaScript).
- **WEB-703:** WP23 (the footer, held) and WP37 (the footer nav's "Què fa", which was 43 px wide) are fixed. Left: WP25 (the header logo, 136.7 × 34.5).
- **WEB-309:** WP23 (the footer's text at 0.875rem, none under 12 px) is fixed. Left: WP25 (body text at 15 px; eyebrows at 10 and 8 px).
- **WEB-707:** nothing in this batch checked its FAQ half (WP19), so its line is unchanged and it stays open.
- Every other open line (the demo, the legal pages, WP24–WP32) wasn't in this batch and is unchanged.

**Seen in passing, outside these packages** (for the next review; no ledger line added):
- At 200% text, the hero's secondary link "What it does" / "Què fa" wraps, and its chevron ends up apart from the words.
- The 404's description and preview on `/es/` and `/ca/` are the English home's. A 404 isn't indexed or shared.
- On the legal pages, `twitter:title` is in English. WP30 owns that.
- The verifier asked the implementer's notes to say what option 1 would have produced for WEB-713.

## Escalations
None.

## Checks for a real device or a person
- Android at its largest font size: the phone menu and the language switch (WEB-307, WEB-2).
- A desktop browser at Very large text: the one-row header with Menu, and the menu opened (WEB-712).
- A dark-mode Android phone on a throttled network: is the toolbar dark from the first paint? (WEB-313, still open for WP25.)
- TalkBack on `/es/privacy/`: is the title read with a Spanish voice? (WEB-304)
- After a deploy:
  - a WhatsApp preview of `/es/` on a Spanish phone (WEB-302);
  - a 404 on a phone on mobile data (WEB-713);
  - the 307's Location (WEB-2).
- A native Catalan read:
  - the frame, the 404 and the metadata strings (WEB-304, WEB-306, WEB-704, WEB-302);
  - the FAQ's «Puc desar notes a més de tasques?» (WEB-110) and «La puc fer servir sense connexió?» (WEB-109).
- Safari on a real iPhone: there were no WebKit renders this batch, so the new header, menu and footer are unchecked in Safari.

## Files changed
**Website (TaskFlowWeb):**
- **Site code:**
  - `src/components/`: `HomePage.tsx`, `Header.tsx`, `ThemeProvider.tsx` (WP21's earlier lines plus WP22's `apply()`; all the run's), `Icon.tsx`
  - `src/components/`, new: `LanguageSwitch.tsx`, `NotFoundPage.tsx`, `SkipLink.tsx` (committable)
  - `src/content/site/`: `en.ts`, `es.ts`, `ca.ts`, `types.ts`, `index.ts`
  - `src/app/`: `page.tsx`, `[language]/page.tsx`, `opengraph-image.tsx`
  - `src/app/`, new: `[language]/opengraph-image.tsx`, `fonts/Manrope-latin.woff2` (committable)
  - `src/og/`, new: `preview.tsx`, `Manrope-Bold.ttf`
  - `src/styles/global.css`
- **Tests:**
  - `tests/website.spec.ts`, `tests/voice.spec.ts`, `tests/ux-renders.spec.ts`
  - `tests/ux-web-home.spec.ts`, `tests/ux-web-features.spec.ts`, `tests/ux-web-global.spec.ts`, `tests/ux-web-frame.spec.ts`
  - `tests/support/ux-web.ts`, `tests/support/ux-web-copy.ts`
- **Held: these hold another session's uncommitted work, so the main session commits only the run's own lines.**
  - `src/app/layout.tsx`: **HELD.** It's the other session's file, and its `legal.css` import (line 11) is theirs and untouched. This batch's edits (WP22: the font, `<html lang>`, the skip link, theme colours, metadata defaults) stay uncommitted for the owner. The 404 preload (WEB-713) is held with it.
  - `src/app/not-found.tsx`: holds the other session's lines. WP21's and WP38's lines (one import, one `preload()` call) are separate from theirs, but WP38's preload goes in only together with `layout.tsx`.
  - `src/components/Footer.tsx`: holds the other session's uncommitted lines, rewritten as WP23's brief asked. Stage only the run's hunks; if `ux-web.sh stage` can't separate them, it stays uncommitted.
  - `src/styles/legal.css`: the other session's untracked file. Only `.footer-legal`, `.footer-legal a`, `.footer-operator` and the 800 px legal-row gap changed. It can't be committed until that session commits it.
  - `tests/legal.spec.ts`: the other session's untracked file. Only the footer label at line 158 changed. It can't be committed until that session commits it.
  - `src/proxy.ts` and the /es/ and /ca/ routes (from b1) commit with WP20's files, as the WEB-2 note says. `src/app/[language]/` is untracked as a folder, so stage only the run's files in it.

**App repo (TaskFlow):**
- `.claude/ux-web/ISSUES.md`: 20 lines updated.
- In `.claude/ux-web/runs/2026-10-18-site/`:
  - `plan.md`, `plan-b2-r2.json`, `plan-b2-r3.json`
  - `verify-b2-r1-F.md`, `verify-b2-r1-G.md`, `verify-b2-r2-G.md`
  - `report-b2.md` (the main session saves it)

## Rounds
| Round | Packages | Tests | Fixed | Not yet | Regressions |
|---|---|---|---|---|---|
| 1 (`plan.json`) | WP19, WP20, WP21, WP22 (held), WP23 (held), all done | passed | WEB-111, 105, 107, 109*, 110, 4*, 3, 2*, 304, 307, 302, 306, 313*, 311, 704, 703*, 309* | none | R1G-1 → WEB-713, R1G-2 → WEB-711, R1G-3 → WEB-712 |
| 2 (`plan-b2-r2.json`) | WP37, WP38 (held with `layout.tsx`), both done | passed | WEB-711, 712, 703 (footer part), 713, and the dead CSS rule | none | none |
| 3 (`plan-b2-r3.json`) | none | none | none | none | none |

\* This batch's part is fixed; the rest of the finding waits on later packages.

**Why round 3 is empty.** After round 2, the workflow listed WEB-711, WEB-712, WEB-703 (footer) and WEB-713 as unchecked, because the G verifier's structured result never reached it. The verifier's notes (`verify-b2-r2-G.md`, written after the 12:42–12:48 renders and after the tester's run) judge all four fixed, with measurements, and find no regressions. The tests passed, so the ledger takes its verdicts from those notes.
