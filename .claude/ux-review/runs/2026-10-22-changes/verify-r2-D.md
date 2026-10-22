## UX verify — run 2026-10-22-changes, round 2, area D — 2026-10-22

**Package:** P249 (UX-2017). Evidence: code (ARB and generated catalogs), widget tests (pass), current renders (15:15 today; no file under App/lib or App/assets is newer).

### UX-2017 · fixed
- `billingReasonReminderPlansExample` now carries the helper's own example in all three languages:
  ES «una semana antes y el día antes a las 8» (App/lib/l10n/app_es.arb:1409), EN “a week before, and the day before at 8” (app_en.arb:3781), CA «una setmana abans i el dia abans a les 8» (app_ca.arb:1113). Each matches the quoted part of `reminderPlanYourWayHint` (es:1366, en:3430, ca:1070), with quotes and no final period; none says «cada 3 días» / “every 3 days” / «cada 3 dies».
- The @description in app_en.arb:3782 carries the requested extra sentence. Generated catalogs are regenerated (app_localizations_es.dart:4996, _en:4890, _ca:4974). Shown by subscription_screen.dart:109, unchanged.
- Renders: `reminders/sheet.pro-screen.es.light.1x.png` — heading «Con Pro, pide los avisos con tus palabras:», example, then «Dictados sin límite…». `es.light.2x` and `ca.light.2x` — heading, example and the pinned «Ver suscripción» / «Mostra la subscripció» all in view, nothing clipped inside them (the status heading below is cut by the scroll edge, as intended for a scrolling card above a pinned button).
- Preview description updated (reminders_previews.dart, 'pro-screen'), and INDEX.md shows it.
- Tests: reminder_plan_sheet_test.dart:1855, :1888, :1926 (es and ca) pass.

### Regressions
**R2D-1 · Severity 1 · The example's «8» wraps alone onto its own line (es)**
- Where: App/lib/l10n/app_es.arb:1409 (and the helper at :1366), the Pro screen card; render `sheet.pro-screen.es.light.1x.png` shows «…a las» / «8»», and `es.light.2x` the same.
- The moment: "«a las»… and then a lone 8 — eight what?" The time splits from its preposition, the one bit that makes the example concrete.
- Why: front-load and keep meaning units together on scan lines (E; Nielsen 1997). Cosmetic, no task blocked.
- Fix: a no-break space (U+00A0) between «las» and «8» in ES (`a las 8`), and between «les» and «8» in CA, in both `billingReasonReminderPlansExample` and `reminderPlanYourWayHint`; EN “at 8” likewise. No copy change.
- Verify: re-render reminders/sheet.pro-screen es 1× and 2×; «a las 8»» stays on one line.
- Evidence: seen in current renders.

No other regressions in the changed files: the reminder-sheet helper uses the same example (P245) and still reads as a rhythm no free strength gives; the offer's copy is untouched.
