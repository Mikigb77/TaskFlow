# Voice commands and projects: the list

The owner asked for these on 2026-10-18, with "first create a list of things to include… then implementation… then all the test suites and the UX reviewer." The main session wrote this list, which is waiting for the owner's answers in "Decisions for the owner". Nothing here is built yet.

## Already in the app (verified in the code on 2026-10-18)
- **Naming a project in a dictation.**
  - «… al proyecto de matemáticas» files the task in an existing project.
  - The match is exact, ignoring case and accents (`Backend/core/capture_context.py:resolve_targets`).
  - An unknown name is flagged `project_not_available`; the review asks for a project.
- **Assigning by voice in shared projects.**
  - «Paul tiene que terminar la introducción para el 8 del mes que viene» assigns the task to Paul when he's a member.
  - The match is on the full name, the first name, or the member's spoken name (`voice_name`). «para mí» and «para el grupo» also work.
- **Who sees what.**
  - Everyone in a project sees all of its tasks (`visible_tasks`).
  - Roles: owner, editor and viewer for a project; owner, admin, editor and viewer for a group. Editors create, edit and assign; viewers only read.
  - Project pages have a «Para mí» filter.
- **Inviting** is by email from the project's Compartir. An invitee without an account gets an email with a link and a code. Today that email is plain English text.
- **Several tasks in one dictation** (fixed 2026-10-15).
- **Text search** in Tareas and Proyectos.

## What's new

1. **Create a project by voice.**
   - Example: «Crea un proyecto de matemáticas y añade terminar la presentación para el 12» gives a new project «Matemáticas» plus a task with a deadline on the 12th in it.
   - The model may return a new kind of item, `project`, when the person asks for a project, or when a task names a project that doesn't exist.
   - The result card shows «Nuevo proyecto: Matemáticas». Nothing is created before the person's confirming tap.
   - When the person didn't say «crea», the card offers to create the project, or to pick one of the existing ones, instead of creating it silently.
   - Matching becomes lenient, so «mates», «matemáticas» and «math» all find «Matemáticas». The model already sees the project names, and the server adds a similar-name match.
   - A new project is personal. Sharing stays in the project's Compartir (item 4).
2. **"By the 12th" when the 12th has passed means next month.**
   - This applies to the AI prompt and to the phone's own parser (free typing).
   - A day that doesn't exist next month, such as the 31st, gets a question.
3. **Assigning by voice: make it reliable.** It works today.
   - A spoken name the recognizer spells differently (Pau, Paul, Pol) is matched through the member's spoken name and a lenient match.
   - The result card says «Asignada a Paul», with a one-tap change.
   - Someone who isn't in the project gives «Paul no está en «Matemáticas»» and the task stays unassigned. Inviting stays in Compartir.
   - A project created in the same dictation has no members yet, so an assignment in it waits for the invite.
4. **Adding people, and an attractive invitation email.**
   - Adding people stays on the project screen, by email address, because addresses can't be dictated reliably. Picking from the phone's contacts can come later.
   - The invitation email is redesigned:
     - HTML, in the invitee's language (ES, CA or EN);
     - who invited them, and to which project;
     - one clear button;
     - until the app is on Google Play, a link to the website, with the tester instructions for staging.
   - It's sent from `taskflow.noreply@garbar.tech` with Reply-To support (CLAUDE.md, Email).
   - The website's download page comes with the Play Store launch. The main session has access to the website repo (`../TaskFlowWeb`).
5. **Find tasks by voice, with no chat.**
   - «Busca la tarea de la introducción del proyecto de matemáticas» or «Enséñame todas las tareas de matemáticas».
   - The model returns a `find` item: the words to look for, the project, the person and the status.
   - The phone searches its own copy: it has every task the person can see, completed ones included. No tasks are sent to the AI.
   - The sheet shows the results as a list, completed ones marked and the newest first, with «Abrir «Matemáticas»». No answer is ever written as a reply.
   - Tapping a result opens the task, showing who it's assigned to and, new, «Creada por Ana».
6. **Change a task by voice.**
   - «Cambia la cita del médico de dentro de tres días a dentro de una semana».
   - The model returns an `update` item with two parts: which task (words, plus a date or project if mentioned), and what changes (the new date, time, title, assignee and so on).
   - The phone finds the task, and the card shows «Ir al médico: mié 21 → sáb 25». One tap applies it, followed by «Deshacer».
   - The task is updated, not replaced, so its notes, steps, files, reminders and sharing stay. Several matches mean a choice from a short list.
7. **Delete a task by voice.**
   - «Borra la tarea del médico» returns a `delete` item. The card shows the matched task with «Eliminar», then «Tarea eliminada · Deshacer» (D11).
   - Nothing is ever deleted without that tap.
8. **Who manages a project, and who sees what.**
   - Keep today's model: everyone in a project sees all its tasks; the owner and admins manage people; editors create, edit and assign.
   - Add a filter by person on shared project pages: «Todas · Para mí · Paul…».
   - No separate manager view.
9. **Naming.** Keep «Proyecto» in the app (D6c). In a dictation, «grupo», «proyecto» and «lista» all mean a project. Groups, which hold people, stay as they are: an advanced way to share several projects with the same people.

## How it fits together
- **One mic and one sheet**, and a dictation can mix items. For example: «Crea el proyecto Matemáticas, añade terminar la presentación para el 12 y la introducción para el 8 del mes que viene».
- **One card per item:** «Nuevo proyecto», then each task, each change and each deletion.
  - One tap applies them all, with one «Deshacer».
  - A search shows its list instead.
- **The server** extends the extraction schema. Today `kind` is `task` or `note`; it becomes `task`, `note`, `project`, `find`, `update` or `delete`.
  - `find`, `update` and `delete` carry a target description, and `update` also carries the changes.
  - Matching happens on the phone, so the AI never receives the person's tasks.
- **Free accounts:** a dictation counts once, whatever it holds. Typing without Pro uses the phone's parser, which only creates tasks.

## Decisions for the owner (with recommendations)
1. **Naming:** «Proyecto» in the app, with «grupo», «proyecto» and «lista» understood in dictations. *Recommended.*
2. **A project named in a dictation that doesn't exist:** created only on the confirming tap. When the person didn't say «crea», the card offers it instead. *Recommended.*
3. **Inviting by voice:** no; invite from Compartir, because email addresses can't be dictated. *Recommended.*
4. **Who sees what:** everyone sees all of a project's tasks, plus a filter by person. *Recommended.*
5. **Changing and deleting by voice:** always show the before and after, need the tap, and offer «Deshacer». *Recommended.*
6. **Search results:** include completed tasks; tasks show «Creada por». *Recommended.*
7. **Free typing:** creates tasks only. Commands (find, change, delete) need a dictation, or Pro for typed ones. *Recommended.*

## Order of work
Each step gets tests, a check with the real model, `/ux`, and a commit.
1. **Small fixes:**
   - the day-of-month rule, in the AI and in the phone's parser;
   - lenient matching of project and person names;
   - a real-model check of assignment.
2. Creating a project by voice.
3. Finding by voice.
4. Changing and deleting by voice.
5. The person filter on shared projects, and «Creada por» on tasks.
6. The invitation email.

## Not now
- The website's download page, with the Play Store launch.
- Inviting from the phone's contacts.
- Answering in sentences or a chat. The owner explicitly doesn't want it.
