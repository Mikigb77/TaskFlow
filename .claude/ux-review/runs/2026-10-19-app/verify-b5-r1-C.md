## UX verify — run 2026-10-19-app, b5 round 1, area C — 2026-10-20
**Scope:** P214 (UX-1648). Changed file: `App/lib/screens/activity_screen.dart` (one line, :251-253), plus the tests in `App/test/activity_screen_test.dart`.
**Verdict:** UX-1648 fixed (widget test, render and AUDIT). No regressions. The TalkBack announcement still needs the emulator lane.

### UX-1648 — fixed (code, widget test, render; device check open)
- Code: `activity_screen.dart:253` is now `label: unread && !waiting ? context.l10n.activityUnread : null`. That is exactly the one-line removal the brief asked for. There are no new strings. The bold title (:260-262), the layout, the bar (:267-279) and `_markRead` (:84-97) are untouched.
- Why the label now holds still: `_waiting` is keyed by the item id (:129-130, :201), so the reload keeps the row waiting. Before the tap, the label is «No leída · entry · subtitle». When the wait starts it becomes «entry · subtitle · Buscando la tarea…», one change that lands with the live region appearing. The read reload flips `unread` to false while `waiting` is true, and the label expression gives null either way. When the wait ends, the row is read, so it has no «No leída». If marking it read failed, the row comes back as «No leída», which is correct.
- Acceptance 1, test `activity_screen_test.dart:1135-1199`. A gated read API releases the mark-read call mid-wait. The test checks that the list reloaded (`fetches >= 2`), that the bar is still there, that the title lost its bold, and that the set of heard labels is exactly `{label}` from the tap until the "taskRemoved" end. The label leaves out «No leída» and holds «Buscando la tarea…». It's a strong test: it samples every frame, both inside and outside `runAsync`.
- Acceptance 2, test `:1201-1220`: an unread row that isn't waiting reads «No leída» in bold; a read row has neither.
- Acceptance 3: bold until read. Both tests check it (`:1142`, `:1176`, `:1213`).
- Render `App/build/ux/sharing/activity.waiting.es.light.1x.png` (23:25, newer than the code at 22:54): Paul's row is still bold with the bar under it. AUDIT `sharing/activity · waiting` gives TalkBack: «Paul te ha asignado: … Casa · 20 oct Buscando la tarea…» [live region], with no «No leída». The list render's unread rows still start «No leída …».
- Device-only, still open: emulator lane, TalkBack, ES. Double-tap an unread row whose task isn't on the phone yet, and hear «Buscando la tarea…» once, with no second reading of the row after the read reload.

### Regressions
None. Checked:
- The row in normal, waiting, read-after-wait and failed-read states (above).
- The «Marcar todo como leído» button disappears when the last unread item comes back read mid-wait, which shifts the rows up. That happened before this change (since P213), and this change has no effect on it, so it isn't raised.
- Low-vision TalkBack users see the row in bold while it no longer says «No leída». That lasts only during the wait, and the row really is being marked read, so it isn't raised.

### Memory notes
- Activity: a waiting row's merged label drops «No leída». For live-region rows, keep the merged label stable through provider reloads, and gate state-word labels on `!waiting`.
