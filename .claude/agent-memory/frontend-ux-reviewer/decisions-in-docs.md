---
name: decisions-in-docs
description: Owner decisions live in .claude/ux-review/DECISIONS.md; the decisions found in App/docs are already there. Also lists doc lines, code comments and tests that only look like decisions (as of 2026-10-13)
metadata:
  type: reference
---

Owner decisions are kept in `.claude/ux-review/DECISIONS.md`. Read them there, and don't copy them into memory.

The 2026-10-13 whole-app run found decisions in two docs. DECISIONS.md already holds both:
- `App/docs/DESIGN.md` — Calendar is the first screen.
- `App/docs/PROJECTS_IMPLEMENTATION.md` (2026-10-11) — the model for projects, groups and invitations.

Some things look like decisions but aren't recorded as owner decisions. Treat them as open; if one hurts the newcomer, raise it under "Questions for the owner":
- **A stale description.** `App/docs/DESIGN.md` also says "One shared editor handles new tasks, AI draft review, and edits." That's out of date, not a decision (see [[ui-patterns]]).
- **A code comment.** `App/lib/services/quick_schedule_parser.dart` says "Suggestions are never applied until the user accepts one." That's not a recorded owner decision.
- **A test.** `App/test/auth_gate_test.dart` asserts that Google sign-in stays below the email form. That locks in behaviour U14 (still open) may change, so a fix will have to update the test.
