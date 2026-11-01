# frontend-ux-reviewer — memory index

Updated 2026-10-13 from the whole-app run (`.claude/ux-review/runs/2026-10-13-app/`) and 2026-10-14 from the capture-speed run (`runs/2026-10-14-speed/`, b1 r1–r3); b10 (reminder copy, notification undo, first-run line) merged 2026-10-14; 2026-10-18-commands b5 (person chips, site links, delete account) merged 2026-10-19. Check a line against the code before relying on it.
Run 2026-10-19-app closed 2026-10-21 (b7: launcher icon, tab-label fit, widget/shortcut labels).
Run 2026-10-28-app (whole app, b1–b3) closed in code 2026-11-01: entry absorption/close-first rules, picker sheet shape, completion times, Pro screen order; UX-2643/2644 open. Run 2026-10-21-changes (bulk voice commands) closed 2026-10-22: UX-1722/1724 fixed (DropDownMark); batch e 2026-10-22 (UX-1715/1702/1716/1720/1721/1723/1725: deadline-only voice moves, overdue landing, row «Sin fecha» rule, capture privacy copy). Run 2026-10-22-changes (reminder plans: line, sheet, card, offer, Pro screen, notices) closed 2026-10-22; its plan 2 (D1 own-day notice, D3 needs-day line, D6 personal plans, 28-day strengths, offer decline cap) closed 2026-10-23; plan 3 (D8 said time wins, every reminder personal, no-tap lines, fixed sheet header) closed 2026-10-23.

**Issues and owner decisions aren't kept here:** issues and statuses → `.claude/ux-review/ISSUES.md`; owner decisions → `.claude/ux-review/DECISIONS.md`.

## How the app works
- [UI patterns](ui-patterns.md) — standards for undo bars, date sheets, task forms, capture save/leave, errors, scope, search, tabs/icons, notification body/undo, local-first undo, command/set cards, reminder plans (line, sheet, card, offer, notices), first-run teaching, person chips, site links, 2026-10-28 run standards (entry absorption, picker sheets, completion times, buttons); corrects "one shared sheet/editor".
- [Recurring problems](recurring-problems.md) — 44 problem types (37–44 from run 2026-10-28-app: one-field "empty" tests, stack checked once, reuse ignoring context, 9/16 sheet cap, screen leaving under the finger, scaled list icons) (incl. awaited work in taps, stale scheduled copy, show-once flags, help copy outliving state); check them first.
- [Review techniques](review-techniques.md) — verify: confirm fixes landed; Manrope width model, render cropping, prefix tracing, Flutter 3.44.5 NavigationBar/tooltip facts.
- [Decisions in docs](decisions-in-docs.md) — already in DECISIONS.md; plus doc lines, code comments and tests that only look like decisions.

## Screen maps, one per UX-loop area
- [A · Voice capture](screens-a-voice-capture.md) — ways in (bar, widget, shortcuts, share), Pro gate, capture, result card, save, landing, parser, voice command and set cards; the dated sections win.
- [B · Calendar, home, tasks](screens-b-calendar-tasks.md) — Calendario layout, Tareas tab, tile gestures, task detail, TaskEditor, timeline.
- [C · Lists, notes, groups, sharing](screens-c-lists-notes-sharing.md) — Projects, project page and picker, sharing, groups, invitations, Notes.
- [D · First run, settings, native](screens-d-first-run-settings.md) — login, Settings, Account, delete account, Otros ajustes, Notificaciones, reminders, native (icon, widget, shortcuts), theme.
