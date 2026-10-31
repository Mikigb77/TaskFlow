## UX verify — run 2026-10-15-deletion, round 2, area D (P125) — 2026-10-15

Evidence: code read (git diff HEAD) plus ux-tester's widget tests. No preview covers the delete page, so there is no render to read, and Flutter wasn't run.

### UX-816 · fixed
- `App/lib/widgets/custom_app_bar.dart:22-23`: `automaticallyImplyLeading: !isRoot && canGoBack` is kept, and `leading: !isRoot && !canGoBack ? const SizedBox.shrink() : null` is added. With the default `canGoBack: true`, leading stays null, so the other 31 CustomAppBar call sites are unchanged.
- The doc comment at :16-17 matches the brief.
- The only caller is `delete_account_screen.dart:389` (`canGoBack: !_deleting`). PopScope at :383-385 is unchanged.
- An empty SizedBox has no semantics. TalkBack can't focus or tap a hidden back button, and the tester's semantics test confirms there is no «Atrás» tooltip and no tap action while the deletion is held.
- Tests: the title's x holds within 0.5 dp before the tap, while held and after an offline error, at 1× and at 2× on 320 dp.
- Still needs a phone: the airplane-mode check.

### UX-817 · fixed
- `delete_account_screen.dart:551-578` `_changedBanner`: the lines are built once. While reloading, or when nothing new is handed over, that's the general line. Otherwise it's the intro, the handover lines and the check line.
- The visible text adds '• ' only to the middle lines. The spoken label is the same lines without the bullet.
- `Semantics(container, liveRegion: !_reloading, label)` wraps `ExcludeSemantics(MessageBanner(key: _changed))`. The key stays, so `_reveal(_changed)` still works.
- MessageBanner (`app_components.dart:159`) has no actions and, with `isError: false`, isn't a live region itself, so excluding it hides nothing a person can act on.
- `_load` sets `_reloading = true` synchronously (:103-104), and both setStates (:119-123 and :250-256) land before the next frame, so the banner turns live once, with its final text. The tester proved the label in ES, EN and CA, that it isn't live during the reload, and the general line when nothing new is handed over.
- Still needs a phone: TalkBack speaks it once, without «viñeta».

### Regressions
None found in custom_app_bar.dart, the delete page's app bar, or the changed-plan banner. The other screens using CustomAppBar get `leading: null` as before. The banner's visible text and colours are unchanged.
