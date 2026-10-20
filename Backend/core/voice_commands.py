"""Voice commands: create a project, find tasks, change or delete a task.

The contract with the app is docs/VOICE_COMMANDS.md. The model says what the person
asked; the server validates it and resolves spoken names to ids from the person's own
directory. The server never searches, changes or deletes tasks for a command: the app
does that on the phone, after the person's tap, so the model never sees their tasks.
"""
from datetime import date as Date, time as Time, timedelta
from typing import Annotated, Literal

from pydantic import BaseModel, Field, model_validator

from .capture_context import lenient_matches, match_people, normalized, project_candidates, ranked, resolve_project

COMMAND_KINDS = ("project", "find", "update", "delete")
# Other names the model may give the same kinds. Anything else stays invalid.
KIND_ALIASES = {
    "create_project": "project", "new_project": "project", "group": "project", "list": "project",
    "search": "find", "show": "find", "lookup": "find",
    "change": "update", "edit": "update", "move": "update", "rename": "update",
    "remove": "delete", "erase": "delete",
}
STATUS_ALIASES = {"all": "any", "pending": "open", "todo": "open", "done": "completed", "finished": "completed"}
CHANGE_KEYS = ("title", "date", "time", "deadline_date", "deadline_time", "priority", "notes_append", "assignee", "clear")

Name = Annotated[str, Field(min_length=1, max_length=80)]
Person = Annotated[str, Field(min_length=1, max_length=120)]
Word = Annotated[str, Field(min_length=1, max_length=60)]


def _text(value):
    """A string, where the model sometimes writes an object or a one-item list instead."""
    if isinstance(value, dict):
        value = next((value[key] for key in ("name", "text", "title", "value", "word")
                      if isinstance(value.get(key), str)), value)
    elif isinstance(value, list) and len(value) == 1 and isinstance(value[0], str):
        value = value[0]
    if isinstance(value, str):
        return " ".join(value.split()) or None
    return value  # Anything else still fails validation.


def _words(value):
    """The search words: a list of short strings, without blanks or repeats, at most 8."""
    if value is None:
        return []
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        return value
    words, seen = [], set()
    for item in value:
        item = _text(item)
        key = normalized(item) if isinstance(item, str) else ""
        if key and len(item) <= 60 and key not in seen:
            seen.add(key)
            words.append(item)
    return words[:8]


def _blank_dates(data, keys):
    for key in keys:
        if data.get(key) == "":
            data[key] = None


def is_command(item):
    kind = item.get("kind") if isinstance(item, dict) else None
    return isinstance(kind, str) and KIND_ALIASES.get(kind.strip().lower(), kind.strip().lower()) in COMMAND_KINDS


class CommandTarget(BaseModel):
    """Which existing task an update or a deletion is about."""
    words: list[Word] = Field(default_factory=list, max_length=8)
    project_name: Name | None = None
    date: Date | None = None

    @model_validator(mode="before")
    @classmethod
    def tolerate(cls, data):
        if isinstance(data, str):
            data = {"words": [data]}
        if isinstance(data, dict):
            data = {**data, "words": _words(data.get("words")), "project_name": _text(data.get("project_name"))}
            _blank_dates(data, ("date",))
        return data


class CommandChanges(BaseModel):
    """Only what the person asked to change. clear removes a date, a time or the deadline."""
    title: Annotated[str, Field(min_length=1, max_length=160)] | None = None
    date: Date | None = None
    time: Time | None = None
    deadline_date: Date | None = None
    deadline_time: Time | None = None
    priority: Literal[1, 2, 3] | None = None
    notes_append: Annotated[str, Field(min_length=1, max_length=2000)] | None = None
    assignee: Literal["me", "member", "nobody"] | None = None
    member_name: Person | None = None
    clear: list[Literal["date", "time", "deadline", "deadline_time"]] = Field(default_factory=list, max_length=4)

    @model_validator(mode="before")
    @classmethod
    def tolerate(cls, data):
        if isinstance(data, dict):
            data = dict(data)
            for key in ("title", "notes_append", "member_name"):
                data[key] = _text(data.get(key))
            _blank_dates(data, ("date", "time", "deadline_date", "deadline_time"))
            if data.get("clear") is None:
                data["clear"] = []
            elif isinstance(data["clear"], str):
                data["clear"] = [data["clear"]]
        return data


class ExtractedCommand(BaseModel):
    """One command as the model returns it. Each kind uses only its own fields."""
    kind: Literal["project", "find", "update", "delete"]
    name: Name | None = None  # project
    words: list[Word] = Field(default_factory=list, max_length=8)  # find
    project_name: Name | None = None  # find
    person: Literal["me", "member"] | None = None  # find
    member_name: Person | None = None  # find
    status: Literal["any", "open", "completed"] = "any"  # find
    from_date: Date | None = None  # find
    to_date: Date | None = None  # find
    target: CommandTarget | None = None  # update, delete
    changes: CommandChanges | None = None  # update

    @model_validator(mode="before")
    @classmethod
    def tolerate(cls, data):
        if not isinstance(data, dict):
            return data
        data = dict(data)
        if isinstance(data.get("kind"), str):
            kind = data["kind"].strip().lower()
            data["kind"] = KIND_ALIASES.get(kind, kind)
        kind = data.get("kind")
        if kind == "find" and isinstance(data.get("target"), dict):
            # A search written like an update: {"kind": "find", "target": {"words": ["pan"]}}.
            data = {**data.pop("target"), **{key: value for key, value in data.items() if value not in (None, [], "")}}
        for key in ("name", "project_name", "member_name"):
            data[key] = _text(data.get(key))
        if kind == "project" and not data["name"]:
            data["name"] = data["project_name"]
        data["words"] = _words(data.get("words"))
        for said, key in (("from", "from_date"), ("to", "to_date")):
            if data.get(key) is None and said in data:
                data[key] = data[said]
        _blank_dates(data, ("from_date", "to_date"))
        status = data.get("status")
        if status in (None, ""):
            data["status"] = "any"
        elif isinstance(status, str):
            data["status"] = STATUS_ALIASES.get(status.strip().lower(), status.strip().lower())
        # A flat command, such as {"kind": "delete", "words": ["médico"]}. In a flat update a
        # date is the new one, so only a deletion takes its date as the task's current day.
        if kind == "update" and data.get("changes") is None:
            moved = CHANGE_KEYS + (("member_name",) if "assignee" in data else ())
            data["changes"] = {key: data[key] for key in moved if data.get(key) is not None}
        if kind in ("update", "delete") and not data.get("target"):
            data["target"] = {"words": data["words"], "project_name": data["project_name"],
                              "date": data.get("date") if kind == "delete" else None}
        return data

    @model_validator(mode="after")
    def complete(self):
        if self.kind == "project" and not self.name:
            raise ValueError("A new project needs a name.")
        if self.from_date and self.to_date and self.from_date > self.to_date:
            self.from_date, self.to_date = self.to_date, self.from_date
        return self


def _iso(value):
    return value.isoformat() if value else None


def _clock(value):
    return value.strftime("%H:%M")


def _project_name(name):
    # «matemáticas» is shown as «Matemáticas»; a name with capitals stays as said («iPhone app»).
    name = name.strip(" \"'«»“”‘’")
    return name[:1].upper() + name[1:] if name and name == name.lower() else name


def _people(projects):
    seen, people = set(), []
    for project in projects:
        for person in project["people"]:
            if person["user_id"] not in seen:
                seen.add(person["user_id"])
                people.append(person)
    return people


def _project_ref(name, projects):
    """(list_id, the name when it couldn't be resolved, issues, project_candidates)."""
    if not name:
        return None, None, [], []
    selected, issue, candidates = resolve_project(name, None, projects)
    return (selected["id"], None, [], []) if selected else (None, name, [issue], candidates)


def _with_candidates(item, issues, candidates):
    # Only beside "ambiguous_project": the projects that matched, so the app can offer them.
    if "ambiguous_project" in issues:
        item["project_candidates"] = candidates
    return item


def _person_ref(request, name, people, user_id):
    """(person_id, the name when it couldn't be resolved, issues)."""
    if request == "me" and not name:
        return user_id, None, []
    if not name:
        return None, None, []
    matches = match_people(name, people)
    if len(matches) == 1:
        return matches[0]["user_id"], None, []
    return None, name, ["ambiguous_member" if matches else "member_not_available"]


def _target(target, projects):
    list_id, project_name, issues, candidates = _project_ref(target.project_name, projects)
    item = {"words": target.words, "list_id": list_id, "project_name": project_name, "date": _iso(target.date)}
    return _with_candidates(item, issues, candidates), issues


def _changes(changes, people, user_id, user_name):
    result, issues = {}, []
    if changes.title:
        result["title"] = changes.title
    if changes.date:
        result["date"] = changes.date.isoformat()
    elif "date" in changes.clear:
        result.update(date=None, time=None)  # Back to the Inbox: without a day it has no time either.
    if "date" not in result or result["date"] is not None:
        if changes.time:
            result["time"] = _clock(changes.time)
        elif "time" in changes.clear:
            result["time"] = None
    if changes.deadline_date:
        result["deadline_date"] = changes.deadline_date.isoformat()
    elif "deadline" in changes.clear:
        result.update(deadline_date=None, deadline_time=None)
    if "deadline_date" not in result or result["deadline_date"] is not None:
        if changes.deadline_time:
            result["deadline_time"] = _clock(changes.deadline_time)
        elif "deadline_time" in changes.clear:
            result["deadline_time"] = None
    if changes.priority:
        result["priority"] = changes.priority
    if changes.notes_append:
        result["notes_append"] = changes.notes_append
    if changes.assignee == "nobody":
        result.update(assignee_id=None, assignee_name=None)
    elif changes.assignee == "me" and not changes.member_name:
        result.update(assignee_id=user_id, assignee_name=user_name)
    elif changes.member_name:
        matches = match_people(changes.member_name, people)
        if len(matches) == 1:
            result.update(assignee_id=matches[0]["user_id"], assignee_name=matches[0]["name"])
        else:
            # No assignee_id: the app says who couldn't be found and changes nobody.
            result["assignee_name"] = changes.member_name
            issues.append("ambiguous_member" if matches else "member_not_available")
    return result, issues


def resolve_commands(commands, context):
    """The commands in spoken order, in the shapes of docs/VOICE_COMMANDS.md."""
    context = context or {}
    editable = context.get("projects", [])
    visible = editable + context.get("view_only_projects", [])
    user_id, user_name = context.get("user_id"), context.get("user_name")
    resolved, created = [], set()
    for command in commands:
        if command.kind == "project":
            name = _project_name(command.name)
            if not normalized(name) or normalized(name) in created:
                continue  # The same project said twice is created once.
            created.add(normalized(name))
            matches = lenient_matches(name, editable, lambda project: project["name"])
            issues = ["ambiguous_project"] if len(matches) > 1 else []
            resolved.append(_with_candidates(
                {"kind": "project", "name": name, "existing_list_id": matches[0]["id"] if len(matches) == 1 else None,
                 "issues": issues},
                issues, project_candidates(ranked(name, matches, lambda project: project["name"]))))
        elif command.kind == "find":
            list_id, project_name, issues, candidates = _project_ref(command.project_name, visible)
            scope = [project for project in visible if project["id"] == list_id] if list_id else visible
            person_id, person_name, more = _person_ref(command.person, command.member_name, _people(scope), user_id)
            resolved.append(_with_candidates(
                {"kind": "find", "words": command.words, "list_id": list_id, "project_name": project_name,
                 "person_id": person_id, "person_name": person_name, "status": command.status,
                 "from": _iso(command.from_date), "to": _iso(command.to_date), "issues": issues + more},
                issues, candidates))
        else:
            target, issues = _target(command.target or CommandTarget(), visible)
            item = {"kind": command.kind, "target": target}
            if command.kind == "update":
                scope = [project for project in visible if project["id"] == target["list_id"]] if target["list_id"] else editable
                item["changes"], more = _changes(command.changes or CommandChanges(), _people(scope), user_id, user_name)
                issues = issues + more
            item["issues"] = issues
            resolved.append(item)
    return resolved


def new_projects(resolved):
    """Directory entries for the projects a dictation creates, for its tasks to name.

    One that already exists is in the directory already, under its own id."""
    return [{"id": None, "name": command["name"], "group_name": None, "shared": False, "people": []}
            for command in resolved if command["kind"] == "project" and command["existing_list_id"] is None]


def commands_prompt(today, day_of_month):
    """The prompt's section on commands, with examples in Spanish, Catalan and English.

    today is the reference date in the person's time zone; day_of_month(12) is how the
    prompt's day-of-month rule reads «para el 12»."""
    def day(offset):
        return (today + timedelta(days=offset)).isoformat()
    twelfth = day_of_month(12)
    deadline = f'"deadline_date":"{twelfth.isoformat()}"' if twelfth else '"deadline_date":null'
    return (
        "Commands: the words may also ask to create a project, find tasks, change a task or delete a task. "
        "Return each of these as one item of the commands array, in the order said, and never also as a task. "
        "In the user's words 'grupo', 'proyecto' and 'lista' (Catalan 'grup', 'projecte', 'llista'; English 'group', "
        "'project', 'list') all mean a project. "
        "kind 'project' creates a project when the user asks for one: name is its name as said, starting with a capital, "
        "without the word project, group or list. A task added to it in the same words has that name as project_name. "
        "Example: 'Crea un proyecto de matemáticas y añade terminar la presentación para el 12' has commands "
        '[{"kind":"project","name":"Matemáticas"}] and one task {"title":"Terminar la presentación","project_name":'
        f'"Matemáticas",{deadline},"date":null,"time":null,"priority":2}}. '
        "kind 'find' looks tasks up when the user asks to find, show or look for them, or who had one. Never answer: "
        "return only the search. words are the one or two distinctive words of the task, in the user's language: never "
        "filler such as 'tarea', 'tasca' or 'task', and never the project or the person. project_name, person ('me', or "
        "'member' with member_name), status ('open', 'completed' or 'any'; 'any' unless the user says pending or done), "
        "and from_date and to_date (YYYY-MM-DD, inclusive) only when stated. "
        "Example: 'Busca la tarea de la introducción del proyecto de matemáticas' is "
        '{"kind":"find","words":["introducción"],"project_name":"Matemáticas","status":"any"}; '
        "'Ensenya'm les tasques pendents de la Marta' is "
        '{"kind":"find","words":[],"person":"member","member_name":"Marta","status":"open"}; '
        "'Who had the report task?' is "
        '{"kind":"find","words":["report"],"status":"any"}. '
        "kind 'update' changes one existing task when the user asks to change, move, rename or pass it on: target says "
        "how to find it (words, project_name, and date: its current day, only if said); changes holds only what the user "
        "asked to change: title, date, time, deadline_date, deadline_time, priority, notes_append (text to add to its "
        "notes), assignee ('me', 'member' with member_name, or 'nobody'), and clear (any of 'date', 'time', 'deadline', "
        "'deadline_time', to remove them). Leave every other change null. "
        "Example: 'Cambia la cita del médico de dentro de tres días a dentro de una semana' is "
        f'{{"kind":"update","target":{{"words":["médico"],"date":"{day(3)}"}},"changes":{{"date":"{day(7)}"}}}}; '
        "'Mou la reunió de demà a les sis de la tarda' is "
        f'{{"kind":"update","target":{{"words":["reunió"],"date":"{day(1)}"}},"changes":{{"time":"18:00"}}}}; '
        "'Give the report task to Paul' is "
        '{"kind":"update","target":{"words":["report"]},"changes":{"assignee":"member","member_name":"Paul"}}. '
        "kind 'delete' deletes one existing task when the user asks to delete or remove it: target as for update. "
        "Example: 'Borra la tarea del médico' is "
        '{"kind":"delete","target":{"words":["médico"]}}; '
        "'Elimina la tasca de comprar el pa' is "
        '{"kind":"delete","target":{"words":["pa"]}}; '
        "'Delete the dentist task' is "
        '{"kind":"delete","target":{"words":["dentist"]}}. '
        "Resolve relative dates in commands against the reference, as for tasks. Use the directory for project and "
        "people names. When the words hold only commands, return an empty tasks array.\n"
    )
