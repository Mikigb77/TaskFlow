# frontend-ux-reviewer — memory index

Updated 2026-10-13 from the whole-app run (`.claude/ux-review/runs/2026-10-13-app/`) and 2026-10-14 from the capture-speed run (`runs/2026-10-14-speed/`, b1 r1–r3); b10 (reminder copy, notification undo, first-run line) merged 2026-10-14. Check a line against the code before relying on it.

**Issues and owner decisions aren't kept here:** issues and statuses → `.claude/ux-review/ISSUES.md`; owner decisions → `.claude/ux-review/DECISIONS.md`.

## How the app works
- [UI patterns](ui-patterns.md) — standards for undo bars, date sheets, task forms, capture save/leave, errors, scope, search, tabs/icons, notification body/undo, first-run teaching; corrects "one shared sheet/editor".
- [Recurring problems](recurring-problems.md) — 23 problem types (incl. awaited work in taps, stale scheduled copy, show-once flags); check them first.
- [Review techniques](review-techniques.md) — Manrope width model, render cropping, prefix tracing, Flutter 3.44.5 NavigationBar/tooltip facts.
- [Decisions in docs](decisions-in-docs.md) — already in DECISIONS.md; plus doc lines, code comments and tests that only look like decisions.

## Screen maps, one per UX-loop area
- [A · Voice capture](screens-a-voice-capture.md) — ways in (bar, widget, shortcuts, share), Pro gate, capture, result card, save, landing, parser; the 2026-10-14 section wins.
- [B · Calendar, home, tasks](screens-b-calendar-tasks.md) — Calendario layout, Tareas tab, tile gestures, task detail, TaskEditor, timeline.
- [C · Lists, notes, groups, sharing](screens-c-lists-notes-sharing.md) — Projects, project page and picker, sharing, groups, invitations, Notes.
- [D · First run, settings, native](screens-d-first-run-settings.md) — login, Settings, Account, Notificaciones, reminders, native, theme.
