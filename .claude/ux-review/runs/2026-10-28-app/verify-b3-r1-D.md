## UX verify — run 2026-10-28-app, batch b3, round 1, area D — 2026-11-01
**Verdict:** Ship. All eight findings are fixed. One new polish problem: at 2× the Pro screen's new benefit list pushes the plan's status below the fold.
**Evidence:** code (`git diff HEAD`), the renders made 2026-11-01 12:07–12:09 (no file in App/lib or App/assets is newer than them), `App/build/ux/AUDIT.md`, and the testers' results. Widget-test level only: nothing here is from the emulator or a phone.

### Findings
| ID | Result | Evidence |
|---|---|---|
| UX-2603 | fixed | `subscription_screen.dart:115-150`: three rows (check icon + text) from `proBenefitDictation`, `proBenefitTyping`, `proBenefitReminders`, with the third left out when `reason`. Complimentary accounts still see only `billingComplimentary`. The copy is exact in EN, ES and CA, `billingIntro` is gone from every catalog and from the code, and the `@` descriptions are accurate. Renders: `settings/pro.free.es.light.1x`, `.es.light.2x` and `.ca.light.2x` show three whole lines; `reminders/sheet.pro-screen.es.light.1x` shows the heading, the example and only the first two lines. |
| UX-2605 | fixed | `settings_screen.dart:70-77, 139`: Pro or complimentary (`hasProProvider`) → `billingStatus('active')`; free with a count → `freeVoiceLeft`; billing loading or no count → no subtitle. `billingSettingsHelp` is gone from every catalog, and `@freeVoiceLeft` names Ajustes. Renders: `settings-tab.free` («Te quedan 4 dictados gratis este mes»), `settings-tab.free-used-up` («Ya no te quedan dictados gratis este mes»), `settings-tab.normal` («Pro está activo» / «Pro està actiu»). The AUDIT TalkBack line reads «TaskFlow Pro Te quedan 4 dictados gratis este mes». |
| UX-2607 | fixed | `app_es.arb`: `freeVoiceStatus` ends «El {date} tendrás más.» and `billingRenewalHelp` says «las condiciones de cualquier prueba». `storageUsage` has U+00A0 after {used} and after {limit} in ES, EN and CA (checked byte by byte). Render `pro.free.es.light.1x` shows «El 1 dic tendrás más.» and «…cualquier prueba antes de confirmar.». At 2× the storage line is below the crop; the tester's fit test covers «100 MB» and «42 de». |
| UX-2606 | fixed | `login_screen.dart:569-571`: while `folded`, the heading is `signInOrUpHeading`. Sign-in-again never folds (`_canFold`, :145), so it keeps «Inicia sesión», which is right for it. Renders: `auth/sign-in.sign-in` es 1×/2×, ca 2× and en 2× show «Entra o crea tu cuenta» / «Sign in or sign up» on 2 lines. In the AUDIT, TalkBack's 3rd item is heading «Entra o crea tu cuenta» [names route]. |
| UX-2611 | fixed | `login_screen.dart:1024-1026`: an 8 dp `SizedBox` between «Ya tengo un código» and «Volver a iniciar sesión», shown only while «Ya tengo un código» is. In the AUDIT for `auth/sign-in · recovery`, «Volver a iniciar sesión» is 8 dp below «Ya tengo un código»; render `sign-in.recovery.es.light.1x` agrees. |
| UX-2610 | fixed | `device_calendars_screen.dart:118-135`: no help paragraph after «ELEGIR CALENDARIOS»; the account goes through `breakableAddress`, with `semanticsLabel` set to the raw address (the same as `withoutAddressBreaks`). `calendarChooseHelp` is gone from every catalog. The 50 limit is still stated where it matters, in `calendarPreferenceError`. Render `phone-calendars.allowed.es.light.2x` breaks the address as «maria.lopez@ / example.com». The AUDIT's TalkBack reads «Trabajo maria.lopez@example.com». |
| UX-2609 | fixed (needs a device) | `language_selector.dart:61-69`: `Navigator.pop` right after the language is saved, then `AppLanguageBridge.apply` and `TaskReminders.refreshLanguage` start unawaited. Both catch and record their own errors (`app_language.dart:48`, `notification_service.dart:343`), so neither can raise an unhandled error after the sheet is gone. A test covers the sheet closing at once. The reminders being rewritten in the background is not tested: `TaskReminders.supported` is false in tests. Device check: a phone with many reminders, then a language switch. |
| UX-2613 | fixed | `homeCaptureInstructions` in ES reads «…o añade el widget Dictar una tarea desde la pantalla de inicio…». That matches `capture_widget_label` in `values-es/strings.xml:11`, and EN and CA are unchanged. Render `settings/other.widget-help.es.light.1x` shows it. |

### Regressions
**R1D-1 · Severity 1 · At 2×, Pro's benefit list hides your plan's status**
- Where: `App/lib/screens/subscription_screen.dart:123-150` (benefit rows), screen `/subscription`, free account at 2×.
- The moment: «¿Cuántos dictados me quedan? Solo veo lo que da Pro… tengo que bajar.»
- What happens:
  - In `settings/pro.free.es.light.2x` and `.ca.light.2x`, the three benefit lines take 10–11 lines of text.
  - The check icon scales to 40 dp, plus a 10 dp gap, which leaves about 214 dp for text.
  - «No hay una suscripción Pro activa» starts at the bottom edge, cut by the pinned button. The free-dictation count and the file usage now need a scroll.
  - The old single sentence took about 4 lines and left the status in view.
- Why it fails: what the person came for should be visible without scrolling (lens E; Fessenden 2018, direction only). The count is also in Ajustes' Pro row now (UX-2605), which softens this.
- Fix (subtract first): don't scale the check icon. Keep it at 20 dp, level with the first line, or drop the icons and keep three `Text`s with 8 dp between them. Each line gains 20–50 dp. If the status still falls below the fold at ES 2×, owner-free alternative: move the status block (status + `freeVoiceStatus` + `storageUsage`) above the benefit list for free accounts. That's an order change, so the organizer decides.
- Verify: `settings/pro.free.es.light.2x` shows «No hay una suscripción Pro activa» and the «Dictados gratis: …» line above «Ver suscripción».
- Evidence: seen in the current renders (es 2×, ca 2×). The before-state is inferred from the old copy's length.

No other regressions in the changed files:
- The Ajustes Pro row stays a single 82 dp tap target.
- Sign-in-again keeps its heading.
- The recovery spacer hides along with its link.
- Phone calendars keeps the 50 limit in its error message.
- The language sheet's `finally` `setState` is guarded by `mounted`.

### Device checks (main session)
- UX-2609: on a phone or emulator with many reminders, switching the language closes the sheet at once, and the reminders show in the new language shortly after.
