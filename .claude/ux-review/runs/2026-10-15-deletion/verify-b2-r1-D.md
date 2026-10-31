## UX verify — run 2026-10-15-deletion, round 1, area D (P126) — 2026-10-16

**Evidence level:** code (git diff HEAD) plus ux-tester's widget and unit tests. No delete-page preview PNG exists in App/build/ or App/artifacts/, so nothing was judged from a render.

### UX-804 · fixed
- `account_deletion.dart:66-68, 107-109` reads `kept_files_in_shared`, and uses 0 when the key is missing.
- `delete_account_screen.dart:504-505` adds a files bullet under «Lo que se queda para los demás:», after the tasks bullet and before the handovers. The heading shows only when `stays` is non-empty (:518), so it appears for files alone, and with nothing kept there is no files line and no heading.
- Copy, plural =1/other, no final full stop, same wording as the tasks line:
  - EN “1 file / {n} files you added to shared projects, without your name”
  - ES «1 archivo / {n} archivos que añadiste a proyectos compartidos, sin tu nombre»
  - CA «1 fitxer / {n} fitxers que vas afegir a projectes compartits, sense el teu nom»
- The tasks line no longer says «y los archivos» (all three catalogs). That claim was false when someone added tasks but no files, so the copy is now accurate.
- Server check (read only): `Backend/core/account_deletion.py:108-110` excludes files on deleted tasks, so the same file can't appear in both «Lo que se eliminará: N archivos» and the files that stay.
- Tests: delete_account_test.dart:3073-3230 (EN, ES and CA, singular and plural, files only, nothing kept, missing key, order, Catalan at 2× on 320 dp).
- Note, not a regression: an older server that doesn't send the key now shows no mention of files at all. The server in this repo sends it.

### UX-809 · fixed
- `api_client.dart:470-480` puts a whole-seconds `Retry-After` header on every `ApiException` it builds from an HTTP error. A missing header, a negative value or an HTTP date all give null.
- `delete_account_screen.dart:182-191` takes the wait from the header first, then from the English detail text, then falls back to the generic line. It rounds up to whole minutes, with a minimum of 1.
- The server's lock raises `Throttled(wait=900)` (`account_deletion.py:314`), and DRF sends `Retry-After: 900` with it. A Spanish detail text therefore still gives «Espera 15 minutos».
- Tests: delete_account_test.dart:3235-3370, including a real ApiClient over a MockClient that keeps the typed password. The header takes precedence over the English text, and with no header the page shows the generic line.

### Regressions (changed files and the flows they touch)
None found.
- Adding a fourth optional argument to `ApiException` leaves every other place that creates one unchanged.
- Only the delete page reads `retryAfter`, so sign-in and other error paths behave as before.
- The «2 archivos» under the first heading and the «2 archivos que añadiste…» under the second open with the same words, but different headings and the qualifier keep them apart. This is the two-list layout the review asked for, so it isn't reported.
