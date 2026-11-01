## UX verify — run 2026-10-28-app, round 2, area D (P312) — 2026-11-01

**Verdict:** Ship. UX-2640 is fixed; no regressions in the changed files or the flows they touch.

Evidence level: code (`git diff HEAD`), current preview renders (settings/pro.*, reminders/sheet.pro-screen.*, all rendered 2026-11-01 13:25–13:26, newer than `subscription_screen.dart` at 12:58), AUDIT.md, and the tester's widget tests. No device.

### UX-2640 · fixed

- **Icon no longer scales.** `App/lib/screens/subscription_screen.dart:79-85` computes the first line's height (`textScaler.scale(bodyMedium.fontSize) × height`; the theme sets bodyMedium height 1.5, `lib/theme/*.dart:51`); `:180-191` puts a fixed 20 dp `Icons.check_rounded` centred in a box that tall, so it sits level with the first line at any scale. Renders: `pro.free.es.light.2x.png` and `.ca.light.2x.png` show small checks level with the first line of each benefit; at 1× (`pro.free.es.light.1x.png`) unchanged.
- **Plan first.** `:121-153` status, renewal date and «Dictados gratis: …» now come right after the reason (if any), then 20 dp, then the benefits or `billingComplimentary` (`:156-197`).
  - ES 2× and CA 2× free (`pro.free.*.light.2x.png`): «No hay una suscripción Pro activa» / «No hi ha cap subscripció Pro activa», the whole dictations line, and the whole first benefit are above the pinned «Ver suscripción» / «Mostra la subscripció». Before: the status was cut at the bottom edge and the dictations line needed a scroll.
  - Reason (`sheet.pro-screen.es.light.1x.png`): heading, example, status, dictations, then only two benefits. At CA 2× the status is now in view under the example.
  - Active (`pro.active.es.light.1x.png`): «Pro está activo» and «Se renueva el jue, 29 de oct» before the three benefits. Complimentary: status then the complimentary line.
- **Storage line after the benefits (the brief's fallback, free accounts only).** `:198-216`. Literal acceptance 3 (Archivos before the benefits at ES 1×) is replaced by that sanctioned fallback; the tester's test shows that at CA 2× on 360×800 the storage line placed first would push the first benefit under the pinned button. Accepted.
- Tests (tester, pass): `App/test/subscription_screen_test.dart` group `P312 · plan first` (line 1012) plus UX-1613's 2× fold test still passing.
- AUDIT.md: settings/pro (free, free-used-up, file-space-full, active, complimentary, store-error) and reminders/sheet · pro-screen: 0 problems in every render.

### Regressions

None.

Checked and not counted:
- **File space full, 2×:** «Archivos: 100 de 100 MB usados» and «Ver tareas con archivos» are now below the benefits and need a scroll (`pro.file-space-full.es.light.2x.png`). The brief allows it, and the main way in for a full space, the attachment's error (`App/lib/widgets/attachment_panel.dart:414-428`), offers its own «Ver tareas con archivos» next to the Pro link. At 1× both are in view.
- **TalkBack, free card without a reason:** still one merged text node for status, dictations, benefits and storage (AUDIT). Same as before this change; not caused by it.
- **Pinned button with no scroll cue at 2×:** existing pattern, not new.
- Preview descriptions in `settings_previews.dart` and `reminders_previews.dart` match what the renders show. `billingIntro` has no remaining uses and is gone from all three ARB files.
