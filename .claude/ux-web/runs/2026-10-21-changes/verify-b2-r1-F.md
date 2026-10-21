## UX web verify: run 2026-10-21-changes, round 1, area F (WP56), 2026-10-22

**Verdict:** WEB-5 is fixed. No regressions.

### WEB-5: fixed
- **File check (verified on disk):**
  - All six `public/images/hero-calendar-{en,es,ca}-{light,dark}.png` are byte-identical (`cmp`) to `App/build/web-assets/calendar-hero.done.<language>.<theme>.1x-390.png`.
  - Each is 780 × 1688 (PNG IHDR).
  - The manifest's `renderedAt` values run from 2026-10-22T01:05:06 to 01:05:10. That's after the last `App/lib` commit, 399c0d0 at 2026-10-22 01:04:47 +0200.
  - `git status -- App/lib App/assets` is clean.
- **The images (viewed):**
  - `hero-calendar-es-light.png`: «viernes, 23 de octubre», «2 pendientes», «Llamar al dentista», «Comprar pan». It has no «· 0 completadas» and no «Sin hora», and one «Añadir tarea» button.
  - `hero-calendar-ca-dark.png`: «2 per fer», «Trucar al dentista», «Comprar pa», «Afegeix una tasca», and no «Sense hora».
  - `hero-calendar-en-dark.png`: ‘2 to do’, ‘Call the dentist’, ‘Buy bread’, ‘Add a task’, and no ‘Any time’.
- **Renders (all newer than the images; made at 01:35, images copied at 01:15):**
  - `home.es.desktop.light.fold.png`, `home.en.desktop.dark.fold.png`, `home.es.mobile.light.full.png` (screen 2, cropped) and `opengraph-image.es.png` all show the new rows.
  - Each theme gets its own image: the dark home shows the dark render.
- **Alt text** (`src/content/site/en.ts:9`): «TaskFlow’s calendar … “Call the dentist” and “Buy bread” on tomorrow». It's still true; it doesn't mention the removed lines.
- **Test:** the run's diff of `tests/ux-web-home.spec.ts` adds a file check for size and the stale SHA-256 values. A later WEB-114 re-render still passes it. The tester reports that test and the existing hero, theme and axe tests pass. `AUDIT.md` §1 and §4 are clean for the homes.
- **Device checks, still open:**
  - On a real phone, the task titles are legible at arm's length.
  - After a deploy, a WhatsApp preview of /es/ shows the new phone (WEB-302).
  - The images get rendered again right before publishing (WEB-114, WD13).

### Regressions
None.
- Only the six images and the test changed. Phone.tsx, src/og and the copy weren't touched.
- The rows have no subtitle now, so the screen inside the phone has more empty space above «Añadir tarea». That's how the app looks today, so it's faithful, not a regression.
- The in-image count line («2 pendientes», 3.00:1 in the app's own audit, about 9 px tall in the desktop hero) is a property of the app's screen. The old image had it too, so this run didn't cause it. The site's axe can't see text inside a raster image, so the site's audit has no measurement for it.
