## UX verify — run 2026-10-22-changes, round 3, area D — 2026-10-22
**Verdict:** Ship after fixes — UX-2019 is fixed (the «8» never sits alone); one polish regression: in Spanish the lone «a» now ends the line before «las 8».
**Scope:** P251 (UX-2019). Files: App/lib/l10n/app_{es,en,ca}.arb, App/test/reminder_plan_sheet_test.dart.

### UX-2019 · fixed
- ARB values (read as JSON): ES `reminderPlanYourWayHint` «Por ejemplo: «una semana antes y el día antes a las 8».» and `billingReasonReminderPlansExample` «…a las 8»»; CA «…a les 8»» in both; EN “…at 8”” in both. Exactly one U+00A0 in each value; no plain «las 8» / «les 8» / “at 8”. The example is still exactly the quoted part of the helper in all three languages. Generated getters carry the same character (app_localizations_{es,ca,en}.dart).
- app_en.arb: both @descriptions end with “Keep a no-break space between the preposition and the hour, so the hour never wraps alone onto its own line.”
- Tests: UX-1908's helper literals now hold ` ` (reminder_plan_sheet_test.dart:3866, 3868, 3872). New UX-2019 tests at :2226 (character check), :2281 (es 1×/2× Pro screen), :2304 (ca 2× with heading, example and «Mostra la subscripció» unclipped), :2351 (en 1×), :3993 (empty helper es 1×/2×), via `_expectHourKeptWithPreposition` (:4201) which reads line boxes of the laid-out paragraph.
- Renders (15:35, newer than the ARB edit at 15:31 and gen-l10n at 15:32; `find -newer` lists nothing): `reminders/sheet.pro-screen.es.light.1x.png` «…el día antes a» / «las 8»»; `es.light.2x` «y el día antes a» / «las 8»»; `ca.light.2x` «a les 8»» on one line, heading, example and pinned «Mostra la subscripció» visible. No EN pro-screen render and no render of the empty helper exists; those two acceptance checks rest on the widget tests above.

### Regressions
**R3D-1 · Severity 1 · Spanish «a» now dangles at line end**
- Where: App/lib/l10n/app_es.arb `billingReasonReminderPlansExample` and `reminderPlanYourWayHint`; renders `reminders/sheet.pro-screen.es.light.1x.png` and `es.light.2x.png`.
- The moment: "«…el día antes a» — a what?" The eye stops on a one-letter word at the end of the line before finding «las 8» below.
- What happens: binding only «las 8» pushed the break one word left; the time phrase «a las 8» is still split, now as «a» / «las 8»». Catalan already keeps «a les 8»» together at 2×.
- Why: keep a meaning unit on one scan line (lens E; people read the first words of each line, Nielsen 1997); Spanish typesetting avoids ending a line on a one-letter word.
- Fix: also a U+00A0 between «a» and «las» in both ES values («a las 8»), and between «a» and «les» in both CA values. Wording unchanged; EN “at 8” needs nothing. Update the UX-1908 literals (:3866, :3872) and pass «a las» / «a les» as the preposition to `_expectHourKeptWithPreposition` in the es/ca checks.
- Verify: re-render reminders/sheet.pro-screen es 1× and 2×: «a las 8»» on one line.
- Evidence: seen in current renders.

No other regressions: no other key, screen file or preview script changed; the CA 2× Pro screen still shows the pinned button unclipped.
