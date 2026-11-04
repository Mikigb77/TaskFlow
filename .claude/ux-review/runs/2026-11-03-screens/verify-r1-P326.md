## UX verify — P326 (area D) — run 2026-11-03-screens, round 1 — 2026-11-03

**Verdict:** Ship. Both findings are fixed in code, in the tester's widget tests and in current renders; one evidence-only regression (stale preview descriptions).
**Evidence level:** code in the worktree `.claude/worktrees/wf_fe15d9eb-d17-18`, the package diff (`waves.py diff`), widget tests (read, not run) and preview renders dated 2026-11-04 00:10, newer than every file under `App/lib` (`find lib -newer <png>` is empty). Nothing here is emulator or phone evidence.

### Findings

**UX-2807 · fixed**
- Copy: `App/lib/l10n/app_es.arb:1486-1487` «Con Pro, tus reuniones se convierten en notas:» / «un resumen, las decisiones y las cosas por hacer»; `app_ca.arb:1190-1191` «Amb Pro, les teves reunions es converteixen en notes:» / «un resum, les decisions i les coses per fer»; `app_en.arb:4338` “With Pro, your meetings become notes:” with the example unchanged. The exact copy from the brief. Generated catalogs carry it (`lib/l10n/generated/app_localizations_es.dart:5373-5381`).
- Both ways in still pass the one reason, so one heading now serves both: `lib/screens/meeting_screen.dart:51` (Grabar una reunión) and `lib/widgets/meeting_banners.dart:320` / `meeting_screen.dart:676` (Ver Pro on a held-back recording). No new reason value.
- Renders: `meetings/pro.reason.es.light.1x` and the new `meetings/pro.held-back.es.light.1x` show the heading, the example, «No hay una suscripción Pro activa», three benefits (meeting line hidden), «€4.99 / mes» and the pinned «Ver suscripción»; no store-error text. `meetings/pro.reason.ca.light.2x` shows the CA heading (4 lines) and example (3 lines) whole above the pinned «Mostra la subscripció».
- Tests: `subscription_screen_test.dart` group «P326 · …» (copy in 3 languages, never «graba»/«record a»/«enregistra», no «tareas»/«tasques»; ES 1× priced, header semantics, order heading → example → status; CA 2× whole and above the offer) and `meeting_screens_test.dart` group «P326 · the Pro screen from a held-back recording».

**UX-2809 · fixed**
- `App/lib/screens/subscription_screen.dart:179-180`: `if (widget.reason != ProReason.meetingNotes) l10n.proBenefitMeetingNotes`, last in the list, same check row as the others; reminders still hidden for `reminderPlans` (`:177-178`). Order unchanged: reason, plan, benefits, file space, price, pinned «Ver suscripción» (UX-2603, UX-2640).
- Copy: ES «Notas de las reuniones que grabas», EN “Notes from your recorded meetings”, CA «Notes de les reunions que enregistres» (new key, all three ARBs).
- Renders: `settings/pro.free.es.light.1x` lists it as the fourth benefit, one line, above «Archivos: 42 de 100 MB usados». `settings/pro.free.ca.light.2x`: the first benefit «Dictats i espai per a fitxers sense límit» is still whole above the pinned «Mostra la subscripció» (UX-2640 holds).
- Tests: ES 1× and CA 2× from Ajustes (first benefit above the offer, the meeting line last and whole, file space after it); reason meetingNotes hides it, reminderPlans hides reminders and shows it.

### Regressions (only in the changed files and their flows)

**R1-P326-1 · Severity 1 · Two preview descriptions now misdescribe the benefit list**
- Where: `App/test/ux_previews/settings_previews.dart:303` (`settings/pro.free.*`: "what Pro gives, in three lines … reminders in your own words") and `App/test/ux_previews/reminders_previews.dart:298` (`reminders/sheet.pro-screen.*`: "what else Pro gives: dictation and file space without limit, and typed sentences turned into tasks"). INDEX.md carries both.
- What happens: the Pro screen now shows four benefits from Ajustes and three (with the meeting line) from the reminders badge, but the descriptions a reviewer reads first still say three and two. The `reminders/sheet.pro-screen.*` PNGs were not re-rendered by this package, so they are also older than the screen they show. Not user-facing; the conventions ask each preview's description to stay true.
- Fix: in `settings_previews.dart:303` say "in four lines … reminders in your own words, notes from your recorded meetings"; in `reminders_previews.dart:298` add ", and notes from your recorded meetings"; re-render `settings/pro.` and `reminders/sheet.`.

Nothing else: the `_open` helper change in `meeting_previews.dart` (free account + priced store) applies only to the two `pro: false` previews (`:453`, `:477`), both the Pro screen. Layout, billing code and other reasons' copy are untouched.

### Observations (not regressions)
- At CA 2× with a reason (`meetings/pro.reason.ca.light.2x`), no benefit and no price shows above the pinned button: heading, example and plan fill the view. UX-2640's rule is for the no-reason screen, and the old heading was about as long, so this is not caused by P326; the reason itself is the benefit shown first.

### Memory notes
- The Pro screen's benefit list is now four lines: dictation + file space, typing, reminders (hidden for `reminderPlans`), meeting notes (hidden for `meetingNotes`); one heading `billingReasonMeetingNotes` serves Grabar una reunión and a held-back recording's Ver Pro.
- Meeting Pro previews now use `account(freeLeft: 4)` and the priced `FakeRevenueCat` in `_open` (meeting_previews.dart); `meetings/pro.held-back.es.light.1x` exists.
- Recurring: a change to a shared list (benefits) leaves other areas' preview descriptions stale; grep every `*_previews.dart` for the old wording.
