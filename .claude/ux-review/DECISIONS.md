# Owner decisions

Every agent in the UX loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

## 2026-10-13 — How the UX loop runs
- Fix everything the reviewer finds **except product decisions**, at every severity, 1 to 4.
- Stop for the owner's approval only on whole-app runs (`/ux app`). Scoped runs fix straight away.
- The reviewer and organizer run at max effort, implementers at high. All use Opus.
- Commit each verified round on `dev`, plus a starting-point commit before a round when needed. Never push, and never touch `main`.

## Standing decisions
- Calendar is the first screen (`App/docs/DESIGN.md`).
- The light/dark sun–moon switch stays. Where it lives is still open (see below).
- Projects (2026-10-11, `App/docs/PROJECTS_IMPLEMENTATION.md`):
  - the interface calls lists "projects";
  - groups hold people;
  - a project belongs to one group or is personal;
  - existing direct shares are kept;
  - an invitation is bound to an email address and needs a separately shared code;
  - archived groups drop out of the daily view, capture and reminders.

## Open — not decided; anything that depends on these is a decision, not a fix
- **The capture direction in UX_REVIEW §3**: listening ends only on Done; no transcript step; the result shows in the same sheet; the calendar shows the saved task.
  - Proposed 2026-10-12; not approved yet.
- **U13**: two tabs (Calendar + Lists), or Notes keeps its own tab.
- **U14**: Google sign-in first, or local use before sign-in.
- **Where the sun–moon switch lives** (UX_REVIEW §5.1).
- The questions raised by the whole-app review of 2026-10-13 are listed in `runs/2026-10-13-app/plan.md`.
