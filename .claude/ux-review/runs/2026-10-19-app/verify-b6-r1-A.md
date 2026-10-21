## UX verify — 2026-10-19-app, batch b6, round 1, area A — 2026-10-21

Scope: P192 (UX-1623). Files: App/lib/screens/voice_task_screen.dart, App/lib/screens/edit_task_screen.dart, App/lib/widgets/task_form_entry.dart, App/test/capture_free_dictations_test.dart, App/test/capture_sheet_test.dart (`git diff HEAD`).

### UX-1623 · fixed
- `App/lib/screens/voice_task_screen.dart:111-114`: the free account's typed-words branch of `showCaptureSheet` now passes `readsDates: typed.source == 'shared'` and `heardAt: typed.capturedAt.toLocal()` to `openTaskForm`; Pro still goes to the typing sheet (the branch only runs under `typesInFormProvider`).
- `App/lib/screens/edit_task_screen.dart:126-135`: `readsDates` (renamed from `spoken`) runs `QuickScheduleParser.parse(words, heardAt ?? now, day: later, keepAmbiguousHour: true)` — the same parser and rules as dictated words (D2), with the D9 day. Docs updated at `edit_task_screen.dart:88-94` and `task_form_entry.dart:16-19`. The rename is complete: no `spoken:` left on `openTaskForm`/`NewTaskArguments` (the two left in voice_task_screen.dart are `_askToKeep`'s own parameter, unrelated).
- Words typed in the sheet (source 'typed') keep `readsDates: false` — as written.
- Tests (ux-tester, all pass): `capture_free_dictations_test.dart` group «UX-1623: shared text opened in the form» (:2892-3100) covers all six acceptance checks; UX-918's test (:2831) now expects the shared half read; `capture_sheet_test.dart:621` now expects «Comprar pilas» for a share. UX-911 (source 'typed') still passes.
- Visual: no preview renders a share opened in the form; it is the same form state as `form/new-task.from-dictation.es.light.1x.png` (rendered 2026-10-21 03:17, after the code's 02:13): title «Médico», day chip «vie, 23 de oct» selected, time chip, «Añadir al calendario» — the day read is visible on the first screen, in the chip row.
- Device: `App/build/ux/device/share.landing.*` and `share.after-back.*` were captured from an APK built at commit 6ea4ab0, before this change — not evidence for it. Re-capture on the emulator lane (needs device).

### Regressions
**R1A-1 · Severity 2 · A shared capture resumed days later opens on a past day**
- Where: `App/lib/screens/voice_task_screen.dart:111-114` → `App/lib/screens/edit_task_screen.dart:128-145`; flow: Sin guardar (`captures_screen.dart:92`) → a shared capture with no result → the form.
- What happens: `heardAt` is the share's time, and a date read from it isn't checked against today. A share «Llamar a Marta mañana» left in Sin guardar on Monday (app killed with the form open, or a share that arrived while the form couldn't open) and resumed on Thursday opens the form on Tuesday — a day already gone — and one Back saves it there (D12) without the person choosing it. Before this change it opened with no day. The form's own rule for a passed-in day is «Today, or a day gone by, adds nothing» (`edit_task_screen.dart:120-121`); the read day doesn't follow it. Rare (the normal share opens the form at once, where the acceptance checks hold), but the cost is a task the person may not find.
- Why: error prevention and visibility of status (Nielsen 1994); change blindness — the chip changes outside the title the person reads (Rensink et al. 1997).
- Fix: in `_start`, when the parsed date (or deadline) is before today at the form's clock, drop the read result: open with no day (or the D9 day) and the words as written, as before this change. No new copy.
- Verify: widget test — clock Thursday 22 Oct, a 'shared' capture «Llamar a Marta mañana» captured Monday 19 Oct 10:00, opened from Sin guardar: the form has no day selected and the title «Llamar a Marta mañana»; the overnight check (Mon 23:50 → Tue 00:10 lands on Tuesday 20) still passes.
- Evidence: verified in code; inferred behaviour, not covered by a test or render.
