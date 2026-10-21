# Voice commands

One dictation can create a project, add tasks, find tasks, change a task and delete a task. The owner approved this on 2026-10-18 (`.claude/ux-review/voice-commands-plan.md`, `.claude/ux-review/DECISIONS.md`).

This is the contract between the server and the app.
- **The server** asks the model what was said, validates the answer and turns spoken names into ids from the person's own projects.
- **The server never searches, changes or deletes a task for a command.** The model never sees the person's tasks either.
- **The app** finds the tasks on the phone, shows what will happen, and does it after the person's tap, with «Deshacer».

Code: `core/voice_commands.py` (commands), `core/ai.py` (prompt and validation), `core/capture_context.py` (matching), `core/views.py` (counting and limits). Tests: `core/test_voice_commands.py`, `core/test_bulk_commands.py`, `core/test_lenient_matching.py`, `core/test_day_of_month.py`, `core/test_project_candidates.py`, `core/test_empty_dictations.py`, `core/test_daily_limit_wait.py`.

## The request

`POST /api/ai/drafts/`, as today, plus one field:

| Field | Type | Meaning |
|---|---|---|
| `commands` | boolean, optional, default `false` | `true`: the answer adds `commands`, and every draft in `tasks` gets `new_project` and `project_suggestion`. |

- JSON: `"commands": true`.
- Multipart, with a WAV recording: the form field `commands` with the value `true`.
- Every other field is unchanged: `text` or `audio`, `timezone`, `reference_time`, `project_id`, `capture_type`, `capture_id`, `language`.
- `POST /api/ai/draft/`, the single-task endpoint, ignores `commands`.

**Without the flag, the answer is exactly today's.** It has no `commands`, the drafts have no new fields, and the prompt doesn't mention commands, so an older app never receives a kind it doesn't know. Three improvements reach older apps too, without changing a field: the day-of-month rule, «grupo», «proyecto» and «lista» meaning a project, and lenient matching.

## The answer

`200` with:

| Key | What it holds |
|---|---|
| `transcript` | The words, as today. |
| `tasks` | Tasks and notes to create, as today, plus two fields per draft. It may be empty when the dictation holds only commands. |
| `commands` | The commands, in the order they were said. It may be empty. |
| `timings`, `free_voice` | As today. |

Nothing is created, changed or deleted when the answer comes back.

### Tasks and notes

Each draft has every field it has today: `title`, `date`, `time`, `due_date`, `scheduled_date`, `deadline_date`, `deadline_at`, `list_id`, `assignment`, `assignee_id`, `assignee_name`, `assignment_issues`, `assignment_hints`, and the rest. With the flag, it always also has:

| Field | Type | Meaning |
|---|---|---|
| `new_project` | string or null | The task goes in a project that a `project` command of this answer creates. `list_id` is then null. |
| `project_suggestion` | string or null | The project name as said, when no project matched it and no `project` command creates it. `assignment_issues` then holds `project_not_available`, as today. |
| `project_candidates` | list, only with `ambiguous_project` | The projects that matched the name said, best first, at most 3 (see [Project candidates](#project-candidates)). |

- **`new_project`.** On the confirming tap, create the project first, then create the task in it. Show the card as «Nuevo proyecto: Matemáticas», then the task.
  - A new project is personal, so `assignment` is `"personal"`.
  - A person named for a task in a new project gets the issue `member_not_available`, with the name in `assignment_hints.member`. Nobody can be assigned before they're invited («Paul no está en «Matemáticas»»).
- **`project_suggestion`.** The person named a project that doesn't exist and didn't say «crea». The card offers to create it («¿Crear el proyecto «Química»?») or to pick an existing project. Never create it without that tap.

A note dictation (`"capture_type": "note"`) with the flag gets `"commands": []`, and its draft has both fields set to null.

### Commands

Every command has `kind` and `issues`. The kinds are `project`, `find`, `update`, `delete` and `complete`. `update`, `delete` and `complete` act on one task, or on many with `"all": true` (see [Bulk commands](#bulk-commands), decided 2026-10-21).

**`project`**: create a project, group or list (all three are a project).

```json
{"kind": "project", "name": "Matemáticas", "existing_list_id": null, "issues": []}
```

| Field | Type | Meaning |
|---|---|---|
| `name` | string, 1–80 | The name as said. A name said all in lowercase gets a capital first letter. |
| `existing_list_id` | uuid string or null | A project the person can edit that already matches the name (see Matching). Nothing needs creating, and the tasks that name it already have its `list_id`. |
| `issues` | list | `["ambiguous_project"]` when two or more existing projects match. Nothing was picked: offer to create the project or to choose one. |
| `project_candidates` | list, only with `ambiguous_project` | The existing projects that matched, best first, at most 3. |

- The same project said twice appears once.
- With `existing_list_id`, nothing is created: say so on the card, with that project's real name, for example «Ya tienes «Matemáticas»».
- Only create the project on the confirming tap.

**`find`**: «busca», «enséñame», «¿quién tenía…?». The answer is a search, never a sentence.

```json
{"kind": "find", "words": ["introducción"], "list_id": "7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11",
 "project_name": null, "person_id": null, "person_name": null, "status": "any", "from": null, "to": null,
 "issues": []}
```

| Field | Type | Meaning |
|---|---|---|
| `words` | list of strings, 0–8, each 1–60 | The distinctive words of the task, in the person's language. Filler («tarea»), the project and the person are left out. It may be empty: «enséñame todas las tareas de matemáticas». |
| `list_id` | uuid string or null | The project named, resolved among the projects the person can edit or only view. |
| `project_name` | string or null | The project name as said, only when it couldn't be resolved. Otherwise null. |
| `person_id` | integer or null | The person named, resolved. «Mis tareas» gives the person's own id. |
| `person_name` | string or null | The name as said, only when it couldn't be resolved. Otherwise null. |
| `status` | `"any"`, `"open"` or `"completed"` | `"any"` unless the person said pending or done. Completed tasks are included by default. |
| `from`, `to` | `"YYYY-MM-DD"` or null | An inclusive period, only when one was said. `from` is never after `to`. |
| `issues` | list | See Issues. |
| `project_candidates` | list, only with `ambiguous_project` | The projects that matched `project_name`, best first, at most 3. |

How the app should search its own copy:
- **Tasks:** every task the person can see, completed ones included, and not deleted.
- **Words:** match each word against the title and notes, ignoring case and accents. A word may match the start of a longer one. Keep the tasks that match every word; when none do, the ones that match the most words.
- **Filters:** `list_id` limits the search to that project. `person_id` means tasks assigned to that person. `from` and `to` compare with the task's planned day, or its deadline day when it has none.
- **`project_name` or `person_name` set:** say so («No encuentro el proyecto «Geografía»»), and don't silently search everything.
- **Showing the results:** a list, newest first, with completed tasks marked, and «Abrir «Matemáticas»» when `list_id` is set.

**`update`**: «cambia», «mueve», «pasa la tarea del médico a…».

```json
{"kind": "update",
 "target": {"words": ["médico"], "list_id": null, "project_name": null, "date": "2026-10-21"},
 "changes": {"date": "2026-10-25"},
 "issues": []}
```

`target` says which existing task:

| Field | Type | Meaning |
|---|---|---|
| `words` | list of strings, 0–8 | As for `find`. |
| `list_id` | uuid string or null | The project named, resolved among the projects the person can edit or only view. |
| `project_name` | string or null | The project name as said, only when it couldn't be resolved. |
| `project_candidates` | list, only with `ambiguous_project` | The projects that matched `project_name`, best first, at most 3. The issue itself is in the command's `issues`. |
| `date` | `"YYYY-MM-DD"` or null | The task's current day, only when it was said: «la cita del médico de dentro de tres días». |

`changes` holds only what the person asked to change. A key that is absent means "unchanged".

| Key | Value | Meaning |
|---|---|---|
| `title` | string, 1–160 | The new title. |
| `date` | `"YYYY-MM-DD"` | Move the task to that day. Keep its time unless `time` is present too. |
| `date` | `null` | Remove the day: the task goes to the Inbox. `time` is then `null` too. |
| `shift_days` | integer, −366 to 366, never 0 | Move the task by that many days instead («retrasa dos días la cita del médico»). Never together with `date`. See [Bulk commands](#bulk-commands). |
| `time` | `"HH:MM"` (24-hour) | Set the time and keep the day. On a task with no day, ask for one. |
| `time` | `null` | Remove the time and keep the day. |
| `deadline_date` | `"YYYY-MM-DD"` | Set the deadline's day. Keep its time unless `deadline_time` is present too. |
| `deadline_date` | `null` | Remove the deadline. `deadline_time` is then `null` too. |
| `deadline_time` | `"HH:MM"` or `null` | Set or remove the deadline's time. |
| `priority` | `1`, `2` or `3` | Low, medium or high. |
| `notes_append` | string, 1–2000 | Text to add at the end of the notes, on a new line. The notes are never replaced, and stay within their 8000 characters. |
| `assignee_id` and `assignee_name` | integer and string | Assign the task to that person, resolved. «Asígnamela» gives the person's own id. |
| `assignee_id` and `assignee_name` | both `null` | Assign it to nobody. |
| `assignee_name` alone | string | The name as said, which couldn't be resolved. `issues` says why. Leave the assignee unchanged. |

- Dates and times are wall-clock values in the request's `timezone`, like a draft's `date` and `time`. Relative words («dentro de una semana», «demà») are already resolved against `reference_time`.
- `changes` may be `{}` when the person didn't say what to change. Open the matched task for editing.
- Find the task as for `find`, among the tasks the person can edit, preferring open ones over completed ones. With `target.date`, keep the tasks whose planned day, or deadline day, is that date.
  - **One match:** show it with the before and after («Ir al médico: mié 21 → dom 25»). One tap applies it, followed by «Deshacer».
  - **Several matches:** a short list to choose from.
  - **None:** say so.
- Update the task, never replace it, so its notes, steps, files, reminders and sharing stay.
- Only a task in a shared project has an assignee, and only someone who can edit that project can be it. Otherwise show «Paul no está en «Matemáticas»» and leave the assignee as it is.

**`delete`**: «borra», «elimina».

```json
{"kind": "delete", "target": {"words": ["dentista"], "list_id": null, "project_name": null, "date": null}, "issues": []}
```

- `target` is as for `update`, and the task is found the same way.
- Show the matched task with «Eliminar», and nothing is deleted without that tap. Then «Tarea eliminada · Deshacer» (D11).

**`complete`**: «marca como hecha», «ya he hecho», «completa».

```json
{"kind": "complete", "target": {"words": ["médico"], "list_id": null, "project_name": null, "date": null}, "issues": []}
```

- `target` is as for `update`, and the task is found the same way, among the person's open tasks.
- Show the matched task with «Marcar como hecha». Then «Tarea completada · Deshacer».
- A repeating task completes the occurrence of the day said, or of today when no day was said, as ticking it on that day does.

### Bulk commands

Decided by the owner on 2026-10-21: «pasa todas las tareas de ayer a mañana», «pasa lo de esta semana a la semana que viene», «asigna a Paul todo lo del viernes de Matemáticas», «marca como hechas todas las de hoy», «borra todas las completadas de la semana pasada».

`update`, `delete` and `complete` act on many tasks when `target` has `"all": true`. The target then describes a set, with the same filters as `find`:

```json
{"kind": "update",
 "target": {"all": true, "words": [], "list_id": null, "project_name": null, "person_id": null, "person_name": null,
            "status": "open", "from": "2026-10-20", "to": "2026-10-20", "undated": false, "date": null},
 "changes": {"date": "2026-10-22"},
 "issues": []}
```

| Field | Type | Meaning |
|---|---|---|
| `all` | boolean | `true`: every task that matches. Absent or `false`: one task, as before. |
| `words` | list of strings, 0–8 | As for `find`. Usually empty: «todas las tareas de ayer». |
| `list_id`, `project_name`, `project_candidates` | as for `find` | The project named. |
| `person_id`, `person_name` | as for `find` | «Todas las de Paul». «Las mías» gives the person's own id. |
| `status` | `"open"`, `"completed"` or `"any"` | `"open"` unless the person said completed («las completadas») or all of them. A `complete` set is always `"open"`: only pending tasks can be marked done. |
| `from`, `to` | `"YYYY-MM-DD"` or null | An inclusive period on the task's planned day, or its deadline day when it has none. «Ayer» gives the same day twice. «Lo atrasado» gives `"to"` = yesterday and `"from"` = null. `from` is never after `to`. |
| `undated` | boolean | `true`: only tasks with no day («las tareas sin fecha»). `from` and `to` are then null. |
| `date` | always `null` with `all` | A day said for the set goes in `from` and `to`. When a period was said too, the period stays and the day is dropped. |

The person, the project and their issues are resolved as for `find`: the person among the people of the project named, or of all the person's projects. Without `all`, the target keeps exactly the shape it had before, without these keys.

`changes` for a bulk `update`:
- `date`, `time`, `deadline_date`, `deadline_time`, `priority`, `assignee_id` and `assignee_name` are as for one task, and apply to every task in the set.
- `title` and `notes_append` are never set with `all`. The server drops them.
- **`shift_days`**, an integer from −366 to 366 and never 0, moves each task by that many days and keeps its time. A task with only a deadline moves its deadline. «Pasa lo de esta semana a la semana que viene» gives 7, and «retrásalo todo un día» gives 1. It can also go on a single task: «retrasa dos días la cita del médico». Any other value is dropped. It's never sent together with `date`; if the model sends both, `date` wins, even a `date` of `null`.
- **Nothing left to change** (the person only gave the tasks a new title, say): the bulk `update` comes to nothing and is dropped, as in [Free dictations](#free-dictations). A single `update` with `{}` still opens the task.

**Which tasks the set holds** (the owner's choice, 2026-10-21):
- The person's own tasks, and the tasks assigned to them in shared projects. Other people's tasks are included only when the person names their project (`list_id`) or names them (`person_id`).
- Only tasks the person can edit, never deleted ones.
- `status` as above: pending ones by default.
- **Repeating tasks** are never moved, changed or deleted in bulk; the card says how many were left out. A bulk `complete` whose period is one day (`from` = `to`) completes each repeating task's occurrence that day. With a longer period, it leaves them out too.
- **Assigning** reaches only tasks in shared projects where the person named can edit. The others are left as they are and counted.

**The card** (app):
- **The heading:** the action, with the count and the target: «Mover 5 tareas a mañana, jue 22», «Mover 3 tareas una semana después», «Asignar 4 tareas a Paul», «Marcar 4 tareas como hechas», «Eliminar 6 tareas».
- **The list:** the matched tasks, each with its current day and ticked; untick one to leave it out. A long list scrolls inside the card.
- **What was left out:** one line, for example «2 tareas que se repiten no cambian».
- **One filled button with the live count:** «Mover 5 tareas». Deleting uses the delete style: «Eliminar 6 tareas». Nothing changes before that tap.
- **After the tap:** «5 tareas movidas · Deshacer». «Deshacer» puts every task back as it was, deleted ones included.
- **No match:** say what was looked for: «No hay tareas pendientes de ayer».
- **More than 200 matches:** no list. Instead: «Son 230 tareas. Dilo con menos, por ejemplo un día o un proyecto.»
- **Counting:** a bulk command is part of its dictation, which counts once, as any dictation does.

### Issues

Commands use the same codes as a task's `assignment_issues`. An issue never stops the rest of the answer.

| Code | Meaning |
|---|---|
| `project_not_available` | No project matches the name said. |
| `ambiguous_project` | Two or more projects match it. None was picked. `project_candidates` lists them. |
| `member_not_available` | Nobody matches the name said. For a task in a new project: nobody can be assigned there yet. |
| `ambiguous_member` | Two or more people match it. Nobody was picked. |

Tasks keep two more codes from today: `choose_project` and `shared_project_required`.

### Project candidates

Wherever `ambiguous_project` is reported, `project_candidates` sits beside it: on a task draft, on a `project` or `find` command, and in the `target` of an `update`, `delete` or `complete`, for one task or a set. The card can then offer exactly those projects, «¿Matemáticas o Matemáticas II?», instead of guessing from names (UX-1315, decided 2026-10-20).

```json
"project_candidates": [{"id": "7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11", "name": "Matemáticas"},
                       {"id": "0b8e4a1f-6c2d-4e57-9a3b-5f1d2c7e8a90", "name": "Matemáticas II"}]
```

- **Which projects:** the ones that matched the name said, at the tier that decided (see Matching), among the candidates of that place: projects the person can edit for tasks and `project` commands, or edit or only view for `find`, `update`, `delete` and `complete`. A group name that matched several projects gives those projects.
- **Best first:** the fewest letters to change from what was said, then the shorter name, then the directory's order (by name). So «Mates» gives «Matemáticas» before «Matemáticas II».
- **At most 3.** Each is `{"id": <uuid string>, "name": <the project's name>}`. Two projects in different groups can share a name: their ids tell them apart, and the app knows each one's group.
- **Projects created in the same answer** have no id yet, so they're never listed. If only such projects matched, the list is empty.
- **Absent otherwise:** the key appears only with `ambiguous_project`. Without the `commands` flag, drafts never have it.

### A whole example

«Crea el proyecto Matemáticas, añade terminar la presentación para el 12 y que Paul haga la introducción para el 8 del mes que viene», said on Sunday 18 October 2026 in Europe/Madrid, with `"commands": true`:

```json
{
  "transcript": "Crea el proyecto Matemáticas, añade terminar la presentación para el 12 y que Paul haga la introducción para el 8 del mes que viene",
  "tasks": [
    {"title": "Terminar la presentación", "date": null, "time": null, "due_date": null, "scheduled_date": null,
     "deadline_date": "2026-11-12", "deadline_at": null, "priority": 2, "notes": "", "checklist": [],
     "questions": [], "clarifications": [], "recurrence": "none", "repeat_interval": 1, "repeat_weekdays": [],
     "repeat_until": null, "duration_minutes": null, "timezone": "Europe/Madrid", "transcript": "…",
     "list_id": null, "assignment": "personal", "assignee_id": null, "assignee_name": null,
     "assignment_issues": [], "assignment_hints": {"project": "Matemáticas", "group": null, "member": null},
     "new_project": "Matemáticas", "project_suggestion": null},
    {"title": "Hacer la introducción", "date": null, "time": null, "due_date": null, "scheduled_date": null,
     "deadline_date": "2026-11-08", "deadline_at": null, "priority": 2, "notes": "", "checklist": [],
     "questions": [], "clarifications": [], "recurrence": "none", "repeat_interval": 1, "repeat_weekdays": [],
     "repeat_until": null, "duration_minutes": null, "timezone": "Europe/Madrid", "transcript": "…",
     "list_id": null, "assignment": "personal", "assignee_id": null, "assignee_name": null,
     "assignment_issues": ["member_not_available"],
     "assignment_hints": {"project": "Matemáticas", "group": null, "member": "Paul"},
     "new_project": "Matemáticas", "project_suggestion": null}
  ],
  "commands": [
    {"kind": "project", "name": "Matemáticas", "existing_list_id": null, "issues": []}
  ],
  "timings": {"transcription_ms": 0, "extraction_ms": 2310},
  "free_voice": {"limit": 10, "left": 9, "resets_at": "2026-11-01T00:00:00Z"}
}
```

The 12th has passed on 18 October, so «para el 12» is 12 November.

«Busca la tarea de la introducción de física, cambia la cita del médico de dentro de tres días a dentro de una semana, pásale el informe a Pol y borra la tarea del dentista», where Paul's spoken name is «Pol»:

```json
{
  "transcript": "…",
  "tasks": [],
  "commands": [
    {"kind": "find", "words": ["introducción"], "list_id": "7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11",
     "project_name": null, "person_id": null, "person_name": null, "status": "any", "from": null, "to": null,
     "issues": []},
    {"kind": "update", "target": {"words": ["médico"], "list_id": null, "project_name": null, "date": "2026-10-21"},
     "changes": {"date": "2026-10-25"}, "issues": []},
    {"kind": "update", "target": {"words": ["informe"], "list_id": null, "project_name": null, "date": null},
     "changes": {"assignee_id": 3, "assignee_name": "Paul"}, "issues": []},
    {"kind": "delete", "target": {"words": ["dentista"], "list_id": null, "project_name": null, "date": null},
     "issues": []}
  ],
  "timings": {"transcription_ms": 0, "extraction_ms": 1980},
  "free_voice": {"limit": 10, "left": 8, "resets_at": "2026-11-01T00:00:00Z"}
}
```

«Añade repasar el tema 3 al proyecto de química», with no project like it: one draft with `"list_id": null`, `"assignment_issues": ["project_not_available"]`, `"new_project": null` and `"project_suggestion": "química"`, and `"commands": []`.

## Matching

Spoken names are resolved against the person's own directory: the projects they can edit, with the people who can be assigned. The model sees that directory (`prompt_context`) and returns names, never ids. The server then matches leniently, and **never guesses between two candidates**.

### Projects and groups

The name said and every project name are compared without case, accents or punctuation. The name said is tried in three forms:
1. as said;
2. without leading or trailing articles and linking words («la», «el», «de», «del», «d'», «l'», «the», «of»…);
3. without the words for a project too: «grupo», «proyecto», «lista», «grup», «projecte», «llista», «group», «project», «list» and their plurals.

So «el proyecto de matemáticas» and «la lista de la compra» are matched as «matemáticas» and «lista de la compra».

The first of these tiers that matches anything decides:

| Tier | Matches when | Example |
|---|---|---|
| 1. Equal | A form equals the project's name. | «Matematicas», «MATEMÁTICAS» → «Matemáticas» |
| 2. Prefix or contained word | The project's name starts with a form of 3 letters or more; or every meaningful word said starts a word of the name, where from 5 letters the last letter may differ; or the whole name appears as words in what was said. | «mate», «mates» → «Matemáticas»; «química» → «Física y Química» |
| 3. Near spelling | Letters added, removed or changed, or two letters swapped, within the limit for the project name's own length (below). | «Quimca» → «Química»; «Matemátcas» → «Matemáticas» |

The limit for a near spelling counts the letters of the project's name, not of what was said:

| Project name | Letters that may differ |
|---|---|
| under 5 letters | none: an equal name or a prefix only |
| 5 to 9 letters | 1 |
| 10 letters or more | 2 |

- **A near spelling is a guess, so it's only taken when it's the only one.** It's never taken when another project is near too, or when the words already hold another project's full name.
- Two letters apart at 8 or 9 letters is often a different subject: «Historia» and «Victoria», «Biología» and «Geología», «Economía» and «Ecología». So those names allow one letter.
- «Física» and «Música» are two letters apart (F and M, í and ú), so they never match. The person is asked instead.

What a match gives:
- **One match:** resolved.
- **Two or more:** `ambiguous_project`.
- **None:** a directory group with that name selects its project when it holds exactly one. «grupo», «proyecto» and «lista» all mean a project, but a group still points to its only project. A group with several projects gives `ambiguous_project`. Otherwise the answer is `project_not_available`.

The same rules and limits apply everywhere a project is named: a task's project, a `project` command's `existing_list_id`, and the `list_id` of `find` and of the target of `update`, `delete` and `complete`.

Which projects are candidates:

| Where | Candidates |
|---|---|
| A task's project | The projects the person can edit, and the projects created in the same dictation. |
| A `project` command | The projects the person can edit. |
| `find`, and the target of `update`, `delete` and `complete` | The projects the person can edit or only view. |

Cross-language names («math» for «Matemáticas») come from the model, which sees the project names.

### People

1. **As before:** the full name, the first name (a full name that starts with the words said), or the spoken name a group member set (`voice_name`), compared without case or accents. So «Pol» finds a member who set «Pol» as their spoken name.
2. **Otherwise,** for 3 letters or more, one letter away (added, removed, changed, or two letters swapped):
   - with one word said: from the first name, the spoken name, or the spoken name's first word. So «Pau» finds «Paul»;
   - with several words said: from the full name or the spoken name. So «Ana Garsia» finds «Ana García».

An exact match wins over a near one: with both «Pau» and «Paul» in a project, «Pau» is Pau. Two or more matches give `ambiguous_member`.

Whose people are candidates:

| Where | Candidates |
|---|---|
| A task | The people who can edit the task's project. |
| `find`, and a set's person (`target.person_id`) | The people of the project named, or everyone in the person's projects. |
| `update` (the assignee) | The people of the target's project, or everyone in the projects the person can edit. |

«Para mí», «mis tareas» and «asígnamela» are the person themselves.

## Dates

- **Relative dates** («mañana», «dentro de una semana», «el viernes») are resolved against `reference_time` in the request's `timezone`, as for tasks.
- **Weekdays and weeks come from a calendar in the prompt** (`calendar_line` in `core/ai.py`, every dictation, 2026-10-21):
  - It lists the past 7 days and the next 14 days, each with its weekday name, and last, this and next week from Monday to Sunday.
  - Without it, the model read weekdays from another year's calendar. On Wednesday 21 October 2026 it gave «el viernes» as the 24th and «esta semana» as Tuesday to Monday, as in 2025.
  - With it, the real model got all 16 bulk and single phrases right in ES, CA and EN.
- **A day of the month said alone** («para el 12», "by the 12th", «el dia 12») means this month if that day hasn't passed yet in that time zone, otherwise next month. Today counts as not passed.
  - The prompt spells the rule out with the reference's own dates, for example "days 18 to 31 are 2026-10-18 to 2026-10-31; days 1 to 17 are 2026-11-01 to 2026-11-17".
  - A day the month doesn't have («el 31» in November) gets no date and a clarification instead, as an ambiguous time does today. The draft keeps it in `clarifications` and `questions`.
  - The phone's own parser should follow the same rule for typed text (plan item 2).

## Free dictations

A dictation counts once, whatever it holds: tasks, notes, commands or a mix. It counts when the answer arrives, as before.

An answer that holds no task and no command doesn't count (D4, decided 2026-10-20). A newcomer's «Hola, ¿me oyes?» costs nothing.
- It's a `200` with `"tasks": []` and `"commands": []`. Its `free_voice` already shows the dictation given back.
- The app says nothing was found and offers to say it again.
- A command that comes to nothing is dropped, such as a project named only with quotes, or a bulk `update` with nothing left to change, so an answer can end up empty that way too.
- It still counts toward the account's daily AI limit (50 a day): the assistant did the work, and that limit bounds dictations that keep finding nothing.

A failed or invalid answer never counts, nor does a cancelled dictation. Neither do budget refusals.

The server counts every request from an account without Pro the same way, typed or spoken. The app sends typed words here only for Pro: a free account types into the form (DECISIONS, 2026-10-18). So typed commands need Pro.

## Errors

The same codes as today.
- An answer from the model that can't be validated is `502`. Nothing is counted.
- With the flag, an answer with only commands is valid, and so is one with nothing in it: `200` with empty `tasks` and `commands` (see Free dictations). Before 2026-10-20 that was a `502`.
- Without the flag, an answer must still hold at least one task, as before. An empty one is a `502`.

### 429: how long to wait

A `429` here is one of three refusals, and `Retry-After`, in seconds, tells them apart (UX-1307). The app reads it:
- 120 or less: "wait a minute, then try again";
- more: today's limit is reached;
- none: the assistant is unavailable.

| Refusal | `Retry-After` |
|---|---|
| 6 requests a minute per account (the `ai` rate limit) | The seconds until the next one is allowed: 60 at most. |
| The account's daily limit (`AI_REQUESTS_PER_DAY`, 50) or everyone's (`AI_GLOBAL_REQUESTS_PER_DAY`, 200) | The seconds until 00:00 UTC, when both start again: they're counted per UTC day. At least 1. Until 2026-10-20 it was always 3600. |
| Google's quota | None. The body says the quota is exhausted. |

Near midnight the daily refusal's wait is short: 30 seconds before 00:00 UTC it says 30, which is true, so the app's "wait a minute" is right then too.

## Other API changes in this branch

### A task's creator: «Creada por»

`GET` and `PUT /api/tasks/…` now return:

| Field | Type | Meaning |
|---|---|---|
| `created_by` | integer or null | Who created the task. Same name and type as before, but it was the owner's id; now it is the creator's, which doesn't change. |
| `created_by_name` | string or null | That person's display name. |

- Both are read-only.
- Both are null once the creator's account is deleted. The task is then handed to the project's owner, and the project's owner must never appear as its creator.
- Every task created through the API records its creator, including dictated and imported ones.

### Activity: who an assignment went to

`GET /api/notifications/` lists a person's activity, newest first and paginated; `POST /api/notifications/{id}/read/` returns one entry. Each entry has `id`, `task_id`, `task_title`, `project_id`, `project_name`, `action`, `actor_name`, `read_at` and `created_at`. An entry whose `action` is `"assigned"` now also says who the task went to (UX-1514, decided 2026-10-20):

| Field | Type | Meaning |
|---|---|---|
| `assignee_name` | string or null | The new assignee's name, as people see it in projects (`display_name`). Null when the task became everyone's (`group`) or nobody's (`unassigned`), or the assignee's account was deleted since. |
| `assignee_is_you` | boolean | True when the person reading the activity is the new assignee. |

- The app then says «Paul te ha asignado: …» to the new assignee, and «Paul ha asignado a Ana: …» to everyone else, the previous assignee included.
- **Older entries** were recorded before the server kept the assignee: they have neither field, and the app keeps today's sentence for them. Other actions never have them.
- The server records the new assignee's id in the event's `details` as `assignee_id` when the assignment happens (`core/collaboration.py`), never the name. So the name shown is today's, like `actor_name`, and deleting that account clears the id with the rest of its activity (`docs/ACCOUNT_DELETION.md`).
- Someone who assigns a task to themselves is both `actor_name` and `assignee_name`.

Code: `NotificationSerializer` in `core/group_views.py`. Tests: `core/test_assignment_activity.py`.

### The invitation email's language

`POST /api/lists/{id}/invite/` and `POST /api/groups/{id}/invite/` accept an optional `language`:
- `"es"`, `"ca"` or `"en"`; a tag such as `"ca-ES"` works too;
- without one, or with another language, the request's `Accept-Language` decides, then English;
- the app should send its own language.

The email is now a designed HTML email in that language. It says:
- who invited the person, and to which project or group;
- one button, with the same review link;
- the code;
- for someone without an account, a line that the app is coming soon to Google Play, with a link to https://taskflow.garbar.tech/. On staging, the tester line stays.

Code: `core/invitation_email.py`. Tests: `core/test_invitation_email.py`.

## For maintainers: what the model returns

The model fills `ExtractedCapture`: the `tasks` array of today, plus a `commands` array of flat `ExtractedCommand` items. The prompt section is `commands_prompt` in `core/voice_commands.py`, with examples in Spanish, Catalan and English.

| Kind | Fields the model fills |
|---|---|
| `project` | `name` |
| `find` | `words`, `project_name`, `person` (`"me"` or `"member"`), `member_name`, `status`, `from_date`, `to_date` |
| `update`, `delete`, `complete` | `target` (`words`, `project_name`, `date`; for a set also `all`, `person` as `"me"` or `"member"`, `member_name`, `status`, `from_date`, `to_date`, `undated`) |
| `update` | `changes` (`title`, `date`, `shift_days`, `time`, `deadline_date`, `deadline_time`, `priority`, `notes_append`, `assignee` as `"me"`, `"member"` or `"nobody"`, `member_name`, and `clear`, a list of `"date"`, `"time"`, `"deadline"` and `"deadline_time"`) |

Nulls mean "unchanged", so a model that fills every key with null changes nothing.

Format slips that are tolerated, as for tasks:
- an envelope inside an array, a bare list, or a single item;
- a command in `tasks`, or a task in `commands`;
- `{"name": …}` objects or one-item lists where a string belongs;
- `words` given as a string;
- other names for a kind (`search`, `remove`, `create_project`, `done`, `mark_done`, `finish`…) or a status (`pending`, `done`, `all`);
- `all` given as `"true"`, or `shift_days` as a numeric string;
- `from` and `to` for `from_date` and `to_date`;
- a flat update, delete or complete, without `target`;
- a set's `all`, `person`, `member_name`, `status`, `from_date`, `to_date` or `undated` written beside `target` instead of in it. What the target says wins;
- one task's day written as `from_date` and `to_date` of the same day: it becomes the target's `date`;
- empty strings for dates.

Anything else that doesn't fit the schema makes the answer invalid, as for tasks. Ids written by the model are ignored.
