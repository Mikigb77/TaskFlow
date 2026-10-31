## UX verify — 2026-10-13-app, batch b6, round 1, area C — 2026-10-14
**Verdict:** All three findings fixed in code and proved by ux-tester's widget tests; one Catalan wording regression (polish).
**Evidence level:** code + widget tests. No preview covers the invitation card, the review screen or the group page (the 10:27–10:29 renders are calendar, review-tasks and login only), so the visual judgements below are reasoned from widget code.

### P80 · UX-326 — fixed (device check pending)
- `invitationSender()` (`App/lib/providers/invitations_provider.dart`, after `PendingInvitation`) trims `invited_by_name` and returns null for null, missing or blank.
- Calendar card: `App/lib/widgets/invitation_cards.dart:29-33` uses `invitedByTo` when the sender is known, else today's `invitedTo`.
- Review screen: `_headline()` (`App/lib/screens/invitation_review_screen.dart:116-122`) gives `invitationFrom` or the bare name. The headline appears only after the details load, so there is no jump when the name arrives (the details row and the sender come from the same response).
- Copy: EN “{sender} invited you to “{name}” · View” / “{sender} invited you to “{name}””; ES “{sender} te invita a «{name}» · Ver” / “…te invita a «{name}»”; CA “{sender} et convida a «{name}» · Mostra” / “…et convida a «{name}»”. Front-loads the person, reads naturally in all three.
- Tests: `invitation_review_test.dart:754-848` (EN/ES/CA, group card, null/missing/blank).
- Note (not a regression, server-side): `display_name` falls back to the email's local part, so a sender with no full name reads e.g. “mikig te invita a «Casa»”, matching how people are named elsewhere in sharing.
- Device check still needed: a real second account.

### P78 · UX-485 — fixed
- `App/lib/screens/groups_screen.dart:674,687`: the delete row passes `done: groupDeleted`; `_run` pops the page, then shows it through `showFeedback` on the captured messenger (`groups_screen.dart:276-280`), so it lands on the screen underneath. Same pattern as leaving (`youLeft`) and UX-340's `projectDeleted`.
- Tests: `groups_screen_test.dart:111-162` (EN/ES/CA land on the page underneath with the snackbar).

### P78 · UX-487 — fixed (device check pending)
- `App/lib/services/invitation_links.dart`: `postpone()` rewrites the stored record with `postponed: true`; `_restore()` reads it back; `receive()` resets it, so a link tapped again (same or new) opens the review. `_restore` still yields to a link that arrives first (`revision != _revision`, line 80), so a cold start from the email link opens the review.
- `App/lib/main.dart:221-240`: the in-memory `_postponedInvitation` is gone; `_openInvitation` skips `isPostponed`, and a non-accepted close calls `postpone`.
- Calendar's card still pre-fills the code from the stored link (`invitation_cards.dart`, `link.id == invitation.id`).
- Tests: `invitation_review_test.dart:849-955` (control restart reopens; postponed restart stays on Calendar with the card and code; same link again reopens, in-session and after restart).
- Device check still needed: force-stop on a phone.

### Regressions
**R1C-1 · Severity 1 · Catalan says “eliminat” where the app says “suprimit”**
- Where: `App/lib/l10n/app_ca.arb:508` `groupDeleted: "Grup eliminat"`, next to `projectDeleted: "Projecte suprimit"` (507) and the button `delete: "Suprimeix"` that the user just tapped.
- Why: one concept, one name (ISO 24495-1). The user taps “Suprimeix” and is told “eliminat”; deleting a project says “suprimit”. (The brief proposed “Grup eliminat”; the catalog's own term wins.)
- Fix: CA `"groupDeleted": "Grup suprimit"`; update the string check at `App/test/groups_screen_test.dart:158-161`. EN and ES unchanged.

### Checked, no regression
- Card at 2× / Catalan: the title is a wrapping `ListTile` title; a longer “Ana et convida a «…» · Mostra” wraps rather than clips (code reasoning).
- Postponed link and a different account signing in on the same device: it stays quiet, which is the intent; tapping the link again reopens it.
