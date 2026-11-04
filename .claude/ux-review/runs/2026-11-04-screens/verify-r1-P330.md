## UX verify — P330 (Pro screen: meeting hours set apart, hours as a plural) — round 1 — 2026-11-04
**Verdict:** Ship. Both findings are fixed as briefed, the text at 20 hasn't changed, and I found no regressions.
**Read:** the worktree `.claude/worktrees/wf_a74c231d-d1a-12`, its diff (`waves.py diff --worktree`), the generated l10n in the worktree, and the renders `App/build/ux/meetings/pro.reason.{es.light.1x, es.light.2x, ca.light.2x}.png` (22:31, newer than every file under `lib/`). Evidence: code, widget tests (the tester's) and preview renders. No device.

### Findings
**UX-3001 · fixed**
- `App/lib/screens/subscription_screen.dart:133`: the gap is now `SizedBox(height: 8)` between `subscription-reason-example` and `subscription-meeting-limit`. The heading → example gap is still `SizedBox(height: 4)` (:123), and the hours → status gap is still 12 (:142).
- Renders (360 dp at DPR 2): in ES 1×, the gap above «Hasta 20 horas de reuniones al mes.» is about 16 px (8 dp), against about 8 px above the example. ES 2× and CA 2× show the same: «Fins a 20 hores de reunions al mes.» now reads as its own line, not as the end of «…les coses per fer». The hours line isn't clipped, and it still groups with the reason, because 8 dp is less than the 12 dp above the status.
- The tester's tests (es 1×, es 2×, ca 2×) check: a gap of at least 8, larger than the heading gap; a heading gap of 4 ± 0.5; the exact text; and that the line isn't clipped inside 360 dp.

**UX-3002 · fixed**
- Both keys are whole-sentence ICU plurals with `=1` and `other` in all three ARB files: `app_en.arb:4469` and `:4490`, `app_es.arb:1507` and `:1511`, `app_ca.arb:1211` and `:1215`. The copy matches the brief exactly, and the `int` placeholder metadata is kept.
- The generated files are regenerated after the ARBs (22:27 vs 22:26): `app_localizations_{en,es,ca}.dart` call `Intl.pluralLogic`, with `one:` for the singular and `other:` holding text identical to the old string at 20.
- The tests check 1 and 20 in EN, ES and CA, and that 2 takes the plural.
- INDEX prose (the third acceptance check): `meetings/pro · reason` (INDEX:172-174), `settings/pro · free` (:219-221) and `reminders/sheet · pro-screen` (:107-111) all mention the hours. The `es2` variant was added and rendered. The other 'free' entry (`settings_previews.dart:169`) is the Settings row, not the Pro screen, so it was rightly left alone.

### Regressions
None found. Checked:
- the Pro screen opened for reminders and from Settings (the benefit string at 20 is unchanged, so the renders don't change);
- the callers of both keys (`subscription_screen.dart:135` and `:193` only);
- the other keys in the ARB diff (none touched);
- the order of the test file (a new group appended at the end).

### Keep
- The hours line stays in the reason's group: 4 dp, then 8, then 12 above the status, so the spacing follows how the lines belong together.

### Memory notes
- Pro screen reason block spacing (meeting reason): heading → example 4 dp, example → hours 8 dp, hours → status 12 dp (`subscription_screen.dart:123-142`).
- `proBenefitMeetingNotes` and `billingReasonMeetingNotesLimit` are now ICU plurals (=1 and other). gen-l10n emits `=1` as `one:`.
