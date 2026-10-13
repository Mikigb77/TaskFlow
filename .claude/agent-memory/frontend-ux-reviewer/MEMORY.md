# frontend-ux-reviewer — memory index

Updated 2026-10-13 from the whole-app run (`.claude/ux-review/runs/2026-10-13-app/`, slices A–D). Check a line against the code before relying on it.

**Issues and owner decisions aren't kept here:** issues and statuses → `.claude/ux-review/ISSUES.md`; owner decisions → `.claude/ux-review/DECISIONS.md`.

## How the app works
- [UI patterns](ui-patterns.md) — the standard for undo bars, date sheets, task forms, errors, scope, header; corrects "one shared sheet/editor".
- [Recurring problems](recurring-problems.md) — 15 problem types found across areas; check them first on every screen.
- [Decisions in docs](decisions-in-docs.md) — already in DECISIONS.md; plus doc lines, code comments and tests that only look like decisions.

## Screen maps, one per UX-loop area
- [A · Voice capture](screens-a-voice-capture.md) — ways in (bar, widget, shortcuts, share), Pro gate, capture screen, review, save, recovery.
- [B · Calendar, home, tasks](screens-b-calendar-tasks.md) — Calendario layout, Tareas tab, tile gestures, task detail, TaskEditor, timeline.
- [C · Lists, notes, groups, sharing](screens-c-lists-notes-sharing.md) — Projects, project page and picker, sharing, groups, invitations, Notes.
- [D · First run, settings, native](screens-d-first-run-settings.md) — login, Settings, Account, Notificaciones, reminders, native, theme.
