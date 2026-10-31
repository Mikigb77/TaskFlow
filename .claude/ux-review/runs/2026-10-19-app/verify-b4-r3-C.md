# Verify — run 2026-10-19-app, round 3 (b4), area C — 2026-10-20

Scope: P213 (UX-1646, UX-1647). Files: `App/lib/screens/activity_screen.dart` (`_ActivityRow`, :229-283), the three ARB files (`activityFindingTask`), `App/test/activity_screen_test.dart`, `App/test/ux_previews/sharing_previews.dart`.
Renders read: `App/build/ux/sharing/activity.waiting.es.light.1x.png`, `.2x.png` (21:12 today; `find App/lib App/assets -newer` lists nothing, so they're current). AUDIT.md `sharing/activity · waiting` (:5502-5524).

## Results

**UX-1646 — fixed (widget-test level; TalkBack itself is a device check).**
- `activity_screen.dart:265-276`: while `waiting`, a `Positioned` bar wrapped in `Semantics(liveRegion: true, label: activityFindingTask)` over `ExcludeSemantics(LinearProgressIndicator(minHeight: 2))`, inside the existing `MergeSemantics`. No `sendAnnouncement` call. `onTap: waiting ? null : onTap` kept (:262).
- Copy matches the brief in all three catalogs: EN “Finding the task…”, ES «Buscando la tarea…», CA «S’està cercant la tasca…» (U+2026, ’), @description as written. No reuse of «Sincronizando».
- AUDIT (:5515): the waiting row reads as one item, `text «No leída Paul te ha asignado: Llamar al fontanero por lo de la cocina Casa · 20 oct Buscando la tarea…» [live region]`. The other rows stay buttons.
- `_open` (:105-160) unchanged from round 2.
- Tests at `activity_screen_test.dart:877-1010` cover ES/EN/CA, opening when the task arrives, the deletion message when it doesn't, and the label going away in both cases. The tester reports they pass.
- Caveat: see R3C-1. On unread rows, the live region is likely to speak twice on a device.

**UX-1647 — fixed (render and widget test).**
- `trailing` is gone in every state. The bar is `Positioned(left: 0, right: 0, bottom: 0)` in a `Stack` that takes the ListTile's size, so the row height is unchanged.
- 1× render: the bar sits below «Casa · 20 oct», clear of its glyphs, and spans the full 312 dp. The two-line title keeps its wrap.
- 2× render: the four-line bold title and «Casa · 20 oct» sit where the list render has them. The bar sits about 10 dp under the subtitle. The next row starts right below.
- The 2× Manrope test (:1020) pins title size, row height and next-row top before and during the wait.
- Device check: non-linear 2.0 scaling on the emulator lane.

## Regressions

**R3C-1 · Severity 2 · An unread row's live region likely speaks twice**
- Where: `App/lib/screens/activity_screen.dart:251` (`label: unread ? activityUnread : null`) together with :268 (`liveRegion: true` merged into the row), and `_markRead` (:84-97), which invalidates `collaborationActivityProvider` while the row waits.
- What happens:
  - Tapping an unread row starts `_markRead` in the background and the sync. The row turns into a live region whose merged label is «No leída · entry · project · date · Buscando la tarea…». That label is new, so it's announced once.
  - When the POST answers, the activity list is fetched again. On a slow network, the case this wait exists for, that answer usually lands before the slow sync. The entry comes back with `read_at` set, so «No leída» drops out of the merged label while the row is still waiting.
  - In this Flutter SDK, `AccessibilityBridge.java:2027` sends a content-change event whenever a live-region node's label changes (`didChangeLabel`, :2735). So TalkBack is likely to read the whole row a second time: «Lucía ha creado: Comprar pan, Casa, 20 oct, Buscando la tarea…».
  - P213's own device check expects «Buscando la tarea…» once. Activity is mostly opened for unread rows, so this is the common path.
  - The widget tests miss it: their activity override returns the same unread item after the invalidate (`activity_screen_test.dart:546-548`).
- Why it fails: GUIDELINES L (assistive technology): announce a status change once. A repeated, long announcement buries the status at the end of the row.
- Fix (subtract): while `waiting`, drop the unread label from the row: `label: unread && !waiting ? context.l10n.activityUnread : null`. The label then changes once, when the bar appears, and stays put when the list comes back read. As a bonus, the announcement is shorter. `_open` and the copy stay as they are.
- Verify:
  - Widget test: with an activity override that returns the item read after the first fetch, tap the unread row under a hanging sync, then let the fetch come back. While the row waits, its merged label must stay identical: no «No leída», and still «Buscando la tarea…».
  - Emulator lane with TalkBack: «Buscando la tarea…» is heard once.
- Evidence: inferred from code and from the Flutter engine source. Needs an emulator/TalkBack check.

## Not raised
- A visible “Finding the task…” line was considered and not raised: the brief asked for a bar only, and the spinner it replaced had no words either.
- Projects delete spinner (`task_lists_screen.dart:365-374`): the brief puts it out of scope.

## Device-only checks still open
- TalkBack, ES, emulator lane: double-tap a row whose task isn't synced yet, and hear «Buscando la tarea…» once (also confirms R3C-1).
- At the largest system text (non-linear scaling), the words don't move when the bar appears.
