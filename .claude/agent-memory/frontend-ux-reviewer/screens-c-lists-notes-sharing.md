---
name: screens-c-lists-notes-sharing
description: Screen and flow map for UX-loop area C (projects/lists, the project picker, sharing, groups, invitations, activity, notes) as of 2026-10-13, with baseline counts
metadata:
  type: project
---

Current as of 2026-10-13 (whole-app run, slice C). Paths are under `App/lib/`.

**Why:** reviews start faster from a current map, and the baselines supply the "before" numbers.
**How to apply:** start area-C reviews here, and refresh this file whenever these screens change.

## Projects
- **The two doors to Projects:**
  - the unlabelled folder icon on the Tareas tab → `/lists`;
  - "Manage projects", the last row of the "Todos los proyectos" sheet. That sheet (`widgets/project_scope_control.dart`) is a fixed 70% of screen height with a search field and no keyboard inset: at 2× text on 320×568 the first match is below the fold.
- **`/lists`** (`screens/task_lists_screen.dart`, titled "Projects", plus a repeated headline and a help line):
  - a Groups button; search, shown even with 0 projects (a query matching nothing shows blank space, no message); pending invitations; a refresh button;
  - project rows: ★ marks a pinned one, and each row has a ⋮ menu with
    - pin;
    - updates (shared projects only);
    - edit;
    - archive — one tap, no undo;
    - "Sharing and people" (synced projects only);
    - choose details (conflicts only);
  - "New project": a name dialog, a "where does it belong" choice and 5 colour chips. Afterwards the user stays on the list.
- **Project page** = HomeScreen(listId):
  - the eyebrow "YOUR PROJECT";
  - For me / Team (shared projects only; inherits the global filter), plus one chip per member who can edit; a person's chip makes new tasks theirs (b5, see [[ui-patterns]] › Person chips);
  - Members, and a bell for project updates (shared projects only);
  - Notes; ✓ (completed tasks from every project); search;
  - Dictar una tarea / Nueva tarea — still shown on view-only projects.
  - There's no Share button until the project is already shared.
- **Project picker** (`widgets/task_list_picker.dart`), opened from the project chip on the task detail, the editor and the review:
  - personal and shared projects are mixed together;
  - one tap moves the task, with no message. Moved into a shared project, the task becomes "Everyone" and is locked there;
  - with 0 projects it's a dead end: "Create a project from the project selector.";
  - under the chip: "Only you can see this" / "Visible to everyone in {group}".

## Sharing and groups
- **ListSharingScreen** ("Sharing and people", `screens/list_sharing_screen.dart`):
  - for the owner:
    - invite — a dialog with an email field, a role dropdown and two paragraphs, then a code dialog;
    - members, shown as raw emails;
    - pending invitations — a tap re-sends and replaces the code; X revokes;
    - "How sharing works", folded away (its data paragraph `sharedDataHelp` ends «Los recordatorios no se comparten: cada persona tiene los suyos.», 2026-10-23; render `sharing/project-sharing.how-it-works.*`);
    - "Delete project for everyone", the only way to delete a project;
  - for a member: leave.
- **GroupsScreen → GroupScreen** (`screens/groups_screen.dart`; the group page is titled "Groups"):
  - members, then pending invitations with no heading;
  - invite → role sheet → code;
  - "Your spoken name" (members only);
  - projects; "New project" → TaskListsScreen(groupId, createOnOpen);
  - the owner can rename, archive (one tap), transfer or delete (disabled, with the reason shown); a member can leave;
  - every step's dialog is `groupTextDialog`.
- **Invitations:**
  - the `taskflow://invite` link opens InvitationReviewScreen:
    - the link is kept for 7 days, and while signed out it waits silently;
    - Accept closes the screen with no message;
    - "Cancel" discards the link;
  - inside the app, invitation cards appear only on Projects and Groups:
    - Accept asks for a code of 16+ characters;
    - Decline acts at once.
- **ActivityScreen**, opened by the header bell on every root tab:
  - rows lead with the task title;
  - unread shows only as a 16 px icon.

## Notes
- **Notes tab** = NotesScreen (`screens/notes_screen.dart`):
  - a permanent paragraph explaining notes vs tasks;
  - an unlabelled project dropdown, where "Notes" means all;
  - search over notes only;
  - the list, in no particular order;
  - "Capturas pendientes", counting note captures only;
  - "Nueva nota" (filled) and "Dictar una nota" (outlined).
- **A project's notes** = NotesScreen(listId). "Dictar una nota" there ignores the project.
- **Note detail** = the note version of TaskDetailScreen:
  - ✏ and 🗑 in the app bar;
  - a read-only body, with links as buttons;
  - no bottom bar.
- **Note editor** = TaskEditor(kind: note).
- **Search everywhere** ignores case and accents since P11/P46 (see [[ui-patterns]] › Search), but still never crosses between tasks and notes.
- **Note icon** is `description_outlined` on rows and the empty state (matches the Notas tab).

## Baselines (2026-10-13)
- **Tareas tab, new account:** 18 tap targets, ~17 concepts, 56 words in Spanish.
- **Notes tab:** 10 targets, 44 words.
- **Projects screen:** 6 targets.
- **Share a project from Calendar:** 8 taps plus typing. The invite dialog has 73 words; the code dialog adds 42.
- **Accept an invitation inside the app:** 5 taps, plus a code from outside the app.
- **Other flows:** write a note, 5 taps; edit a note, 5; leave a group, 6.

## Run 2026-10-28-app (closed in code 2026-11-01)
- **Notes get their own words:** `shareNoteConfirm`, `sharedNoteStays`, `moveNoteError`, `deleteNote` («Eliminar nota»), passed via `TaskListPicker(note: task.isNote)`.
- **Project sheet:** picker shape and ✓ selection (see [[ui-patterns]]); person/project chips wrap with `runSpacing: 8`.
- **«Novedades del proyecto»** (`showProjectPreferences`, opened from `list_sharing_screen.dart`, `task_lists_screen.dart` and the muted reminder line in `reminder_control.dart`): heading + project name line, 70%-cap picker shape (2026-11-01).

Related: [[ui-patterns]], [[screens-b-calendar-tasks]].
