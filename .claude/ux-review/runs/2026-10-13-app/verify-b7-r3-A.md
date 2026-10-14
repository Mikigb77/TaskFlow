## UX verify — run 2026-10-13-app, b7 round 3, area A — 2026-10-14
**Verdict:** Ship. UX-503 is fixed; no regressions in the changed files.
**Scope:** P98 (UX-503, alias R1A-2). Files: App/lib/l10n/app_ca.arb, generated app_localizations_ca.dart, App/test/capture_free_dictations_test.dart.
**Evidence:** code plus ux-tester's unit and widget tests, which pass. No preview render covers the Catalan used-up state; the re-rendered PNGs in App/build/ (capture-listening-es-2x, review-*, calendar-*) don't show this line, so I read none for this check.

### UX-503 · fixed
- `App/lib/l10n/app_ca.arb:875` `freeVoiceUsedUp` = "Ja has fet servir els dictats gratuïts d’aquest mes. La pots escriure aquí; el dia {date} en tindràs més." This matches the brief exactly. The date sits mid-sentence, so the date's own stop ("1 de nov.") is no longer followed by a second one.
- `App/lib/l10n/app_ca.arb:878` `freeVoiceStatus`: the plural part is unchanged, and the last sentence is now "El dia {date} en tindràs més." This matches the brief.
- `App/lib/l10n/app_ca.arb:876` `freeVoiceUsedUpRecording` is untouched ("a partir del dia {date}, o ara amb Pro."); a comma follows the date, so it's fine.
- The generated file `app_localizations_ca.dart` (freeVoiceUsedUp and freeVoiceStatus near the end) matches the ARB, so it was regenerated rather than hand-edited.
- The tests cover every acceptance line:
  - `capture_free_dictations_test.dart:1069-1090`: November; exact status line; no "..".
  - `:1092-1109`: May, which has no abbreviation dot; both strings end "en tindràs més.".
  - `:1031-1065`: ES and EN unchanged; "et queda 1".
  - `:1111-1151`: the widget test in Catalan at 2× on 320 dp; the words are kept, the line ends correctly, it stays inside 320.5 dp, and nothing overflows. Noon UTC on 1 November is still 1 November in every time zone from UTC−11 to UTC+11, so the test is deterministic.
- Copy check: both Catalan sentences read naturally. "el dia 1 de nov. en tindràs més" puts "dia" before the number, as Catalan does. Months that start with a vowel come out as "1 d’abr." and read correctly too.

### Regressions
None caused by P98. The Catalan ARB diff against HEAD also contains earlier packages' changes from this run (the 6 MB copy, billing, account, storage). Those were verified in earlier rounds and aren't part of this change. The only other Catalan string with a trailing {date}, `billingUntil` (:776), has no final full stop, so it can't double one.
