# UX web loop: run 2026-10-21-changes, batch b2: report

**Verdict:** WEB-5 (S1) is fixed. The re-rendered hero images from the app are in place and a test now protects them. One round, no regressions, no escalations. WEB-5 now has status device-check because three checks need a real phone or a deploy.

## Verified
- **WEB-5**: Hero and preview screenshots show rows the app removed (S1, H). WP56 copied in six images re-rendered from the app after the app's last change to `App/lib`, commit 399c0d0 (2026-10-22 01:04:47). The reviewer's checks (`verify-b2-r1-F.md`):
  - **Same files as the app's renders:** each image is byte-identical to `App/build/web-assets/calendar-hero.done.<language>.<theme>.1x-390.png`.
  - **Size:** each is 780 × 1688.
  - **Removed rows are gone in all three languages:** no «· 0 completadas» and no «Sin hora» / «Sense hora» / ‘Any time’.
  - **Rows shown now:** «2 pendientes», «Llamar al dentista» and «Comprar pan», with a single «Añadir tarea» button (the CA and EN images match).
  - **Renders:** the home renders (`home.es.desktop.light.fold`, `home.en.desktop.dark.fold`, `home.es.mobile.light.full`) and `opengraph-image.es.png` show the new rows. Each theme gets its own image.
  - **Alt text:** the alt text in `src/content/site/en.ts:9` is still true.
  - Merged WEB-103.

## Still open
None from this batch. Unrelated to this run, the ledger still lists WEB-801 as open and WEB-701 as waiting on a decision.

## Escalations
None.

## Checks for a real device or a person (WEB-5)
- On a real phone, the task titles in the hero image are legible at arm's length.
- After a deploy, a WhatsApp link preview of /es/ shows the new phone (WEB-302).
- Render the images from the app again right before publishing (WEB-114, WD13).

## Files changed
**Website (TaskFlowWeb):**
- `public/images/hero-calendar-en-light.png`
- `public/images/hero-calendar-en-dark.png`
- `public/images/hero-calendar-es-light.png`
- `public/images/hero-calendar-es-dark.png`
- `public/images/hero-calendar-ca-light.png`
- `public/images/hero-calendar-ca-dark.png`
- `tests/ux-web-home.spec.ts` (+28 lines)

None of these holds another session's uncommitted work: the website tree at `refs/ux-web/base` matches HEAD (6d7d140) for all seven files, and the whole diff is this run's. The main session can commit all seven.

**App repo:**
- `.claude/ux-web/ISSUES.md` (the WEB-5 line, moved from Open to Device check)

## Verified findings protected by a test
- **WEB-5:**
  - `tests/ux-web-home.spec.ts:174`, a file check on the desktop project. All six images must be 780 × 1688 PNGs, and none may match the SHA-256 of the 2026-10-19 render that showed the removed rows. A later re-render (WEB-114) still passes it.
  - The existing hero image test at `tests/ux-web-home.spec.ts:64` (WEB-19/WEB-311) checks the image in each language and theme. The theme and axe tests also pass.

## Rounds
- **Round 1** (`plan.json`):
  - WP56 is done, in one wave.
  - Tests passed. The WEB-5 test proves it, and no part could only be checked on a device.
  - Verification (`verify-b2-r1-F.md`): WEB-5 fixed, no regressions, nothing left unchecked.
  - The reviewer noted two things that aren't regressions:
    - The phone screen has more empty space above «Añadir tarea». That's how the app looks today.
    - The «2 pendientes» line has 3.00:1 contrast, a property of the app's own screen that the old image had too. The site's axe can't measure text inside an image.
