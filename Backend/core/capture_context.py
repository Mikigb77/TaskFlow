"""Resolve spoken names against a server-built, permission-scoped directory.

Model output is a suggestion of names, never authority to select arbitrary IDs.
These functions create drafts only; sharing happens in the reviewed task save.
Matching is lenient (docs/VOICE_COMMANDS.md, "Matching"), but it never guesses
between two candidates.
"""
import json
import os
import re
import unicodedata

from django.db.models import Q
from rest_framework.exceptions import ValidationError

from .list_access import display_name, visible_lists, list_role, project_people


def normalized(value):
    return re.sub(r"[^\w]+", " ", "".join(character for character in unicodedata.normalize("NFKD", value.casefold())
                                         if not unicodedata.combining(character))).strip()


# Words that never name a project on their own: articles and linking words, and the
# words for a project itself. «grupo», «proyecto» and «lista» all mean a project.
FILLER_WORDS = frozenset(
    "a al als amb and d de del dels e el els en for i in l la las les lo los mi mis my "
    "of on per para the un una y".split())
PROJECT_WORDS = frozenset(
    "grupo grupos proyecto proyectos lista listas grup grups projecte projectes llista llistes "
    "group groups project projects list lists".split())


def edit_distance(first, second, limit):
    """Optimal string alignment distance (a swap of two letters counts once), or limit + 1 when larger."""
    if abs(len(first) - len(second)) > limit:
        return limit + 1
    before, previous = None, list(range(len(second) + 1))
    for i, letter in enumerate(first, 1):
        current = [i] + [0] * len(second)
        for j, other in enumerate(second, 1):
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (letter != other))
            if i > 1 and j > 1 and letter == second[j - 2] and first[i - 2] == other:
                current[j] = min(current[j], before[j - 2] + 1)
        if min(current) > limit:
            return limit + 1
        before, previous = previous, current
    return previous[-1]


def _trimmed(words, drop):
    # «el proyecto de matemáticas» -> «matematicas»: without the leading and trailing words in drop.
    words = list(words)
    while words and words[0] in drop:
        words.pop(0)
    while words and words[-1] in drop:
        words.pop()
    return " ".join(words)


def _loose_prefix(word, other):
    # «mate» starts «matematicas»; from 5 letters the last one may differ, so «mates» does too.
    if len(word) < 3:
        return False
    common = len(os.path.commonprefix([word, other]))
    return common == len(word) or (len(word) >= 5 and common >= len(word) - 1)


def _same_name(spoken, name):
    return name in spoken


def _prefix_or_word(spoken, name):
    if any(len(variant) >= 3 and name.startswith(variant) for variant in spoken):
        return True
    significant = [word for word in spoken[0].split() if word not in FILLER_WORDS and word not in PROJECT_WORDS]
    name_words = name.split()
    if significant and all(any(_loose_prefix(word, other) for other in name_words) for word in significant):
        return True
    # The whole name inside longer words: «la lista de la compra» -> «Lista de la compra».
    return len(name) >= 3 and f" {name} " in f" {spoken[0]} "


def allowed_distance(name):
    """How many letters a near spelling may differ by, from the project name's own letters:
    none under 5 (an equal name or a prefix only), 1 up to 9, 2 from 10. Two letters apart at
    8 or 9 letters is often another subject (Historia, Victoria; Biología, Geología), and a
    silent wrong guess is worse than asking."""
    letters = len(name.replace(" ", ""))
    return 0 if letters < 5 else 1 if letters < 10 else 2


def _close(spoken, name):
    allowed = allowed_distance(name)
    return allowed > 0 and any(edit_distance(form, name, allowed) <= allowed for form in spoken)


def lenient_matches(spoken, candidates, name_of):
    """The candidates whose name matches the spoken name at the first tier that matches any:
    equal (ignoring case and accents), then a prefix or contained word, then a near spelling
    (allowed_distance). The caller treats two or more as ambiguous, so a near spelling is
    never picked when another candidate is near too."""
    words = normalized(spoken or "").split()
    if not words:
        return []
    # As said; without articles («la lista de la compra»); without the word project too.
    spoken_forms = [form for form in dict.fromkeys((" ".join(words), _trimmed(words, FILLER_WORDS),
                                                    _trimmed(words, FILLER_WORDS | PROJECT_WORDS))) if form]
    named = [(candidate, normalized(name_of(candidate) or "")) for candidate in candidates]
    named = [(candidate, name) for candidate, name in named if name]
    for tier in (_same_name, _prefix_or_word):
        found = [candidate for candidate, name in named if tier(spoken_forms, name)]
        if found:
            return found
    # A near spelling is a guess: never when the words already hold another project's full
    # name. From 3 letters such a name is found above, so this guards the shorter ones.
    if any(f" {name} " in f" {spoken_forms[0]} " for _, name in named):
        return []
    return [candidate for candidate, name in named if _close(spoken_forms, name)]


def match_people(spoken, people):
    """People whose name matches the spoken one: today's rules (full name, first name or
    voice name), then a first-name or voice-name edit distance of at most 1 (Pau, Paul)."""
    target = normalized(spoken or "")
    if not target:
        return []

    def unique(rows):
        seen, result = set(), []
        for person in rows:
            if person["user_id"] not in seen:
                seen.add(person["user_id"])
                result.append(person)
        return result

    def name(person):
        return normalized(person.get("name") or "")

    def voice(person):
        return normalized(person.get("voice_name") or "")

    exact = [person for person in people
             if name(person) == target or name(person).startswith(target + " ") or (voice(person) and voice(person) == target)]
    if exact or len(target) < 3:
        return unique(exact)
    one_word = " " not in target
    close = []
    for person in people:
        forms = {voice(person)}
        if one_word:
            forms.update(form.split()[0] for form in (name(person), voice(person)) if form)
        else:
            forms.add(name(person))
        if any(len(form) >= 3 and edit_distance(target, form, 1) <= 1 for form in forms if form):
            close.append(person)
    return unique(close)


def pick_project(project_name, group_name, projects, new_projects=()):
    """(project, None) for one match, or (None, "ambiguous_project" / "project_not_available").

    new_projects are the projects created in the same dictation: {"id": None, "name": …}.
    A project name that only matches a directory group still finds that group's one project."""
    groups = sorted({project["group_name"] for project in projects if project.get("group_name")})
    if group_name:
        named = lenient_matches(group_name, groups, lambda value: value)
        if len(named) != 1:
            return None, "ambiguous_project" if named else "project_not_available"
        pool = [project for project in projects if project.get("group_name") == named[0]]
        if not project_name:
            return (pool[0], None) if len(pool) == 1 else (None, "ambiguous_project" if pool else "project_not_available")
    else:
        pool = list(projects) + list(new_projects)
    matches = lenient_matches(project_name, pool, lambda project: project["name"])
    if len(matches) == 1:
        return matches[0], None
    if matches:
        return None, "ambiguous_project"
    if not group_name:
        named = lenient_matches(project_name, groups, lambda value: value)
        if len(named) == 1:
            in_group = [project for project in projects if project.get("group_name") == named[0]]
            if len(in_group) == 1:
                return in_group[0], None
            if in_group:
                return None, "ambiguous_project"
        elif named:
            return None, "ambiguous_project"
    return None, "project_not_available"


def _directory_entry(project, people):
    return {"id": str(project.pk), "name": project.name,
            "group_name": project.group.name if project.group_id else None,
            "shared": project.shared,
            "people": [person for person in people if person["role"] != "viewer"]}


def capture_context(user, default_project_id=None, *, commands=False):
    """The projects the person can add tasks to, with the people who can be assigned.

    With commands, also the projects they can only view (view_only_projects, for finding
    tasks; never shown to the model or used for new tasks) and their own name."""
    projects = []
    view_only = []
    group_directories = {}
    rows = visible_lists(user).filter(archived=False).filter(Q(group__isnull=True) | Q(group__archived=False))
    for project in rows:
        viewer = list_role(project, user) == "viewer"
        if viewer and not commands:
            continue
        if project.group_id:
            if project.group_id not in group_directories:
                group_directories[project.group_id] = project_people(project)
            people = group_directories[project.group_id]
        else:
            people = project_people(project)
        (view_only if viewer else projects).append(_directory_entry(project, people))
    default = str(default_project_id) if default_project_id else None
    if default and not any(project["id"] == default for project in projects):
        raise ValidationError({"project_id": "Choose an active project that you can edit."})
    context = {"user_id": user.pk, "default_project_id": default, "projects": projects}
    if commands:
        context.update(view_only_projects=view_only, user_name=display_name(user))
    return context


def prompt_context(context, words):
    if not context:
        return {}
    text = " " + normalized(words) + " "
    def mentioned(name):
        return bool(name and (" " + normalized(name) + " ") in text)
    def rank(project):
        return (project["id"] != context.get("default_project_id"),
                not mentioned(project["name"]), not mentioned(project.get("group_name")), project["name"])
    selected = sorted(context["projects"], key=rank)[:40]
    # Large accounts remain usable: the model may return a name from the words
    # even if it is outside this bounded hint list. Resolution uses all projects.
    result = {"default_project_id": context.get("default_project_id"),
              "directory_is_complete": len(selected) == len(context["projects"]), "projects": []}
    for project in selected:
        hint = {"id": project["id"], "name": project["name"], "group": project.get("group_name"),
                "shared": project["shared"], "people": []}
        result["projects"].append(hint)
        if len(json.dumps(result)) > 12000:
            result["projects"].pop()
            result["directory_is_complete"] = False
            break
        people = sorted(project["people"], key=lambda person: (
            not (mentioned(person["name"]) or mentioned(person.get("voice_name")) or mentioned(person["name"].split()[0])),
            person["user_id"] != context["user_id"]))
        for person in people[:30]:
            hint["people"].append({"name": person["name"], "alias": person.get("voice_name", "")})
            if len(json.dumps(result)) > 12000:
                hint["people"].pop()
                break
        if len(hint["people"]) != len(people):
            result["directory_is_complete"] = False
    return result


def resolve_targets(payload, context, new_projects=None):
    """Turn the spoken project, group and person into ids from the directory.

    new_projects is None for apps without voice commands, so their drafts keep exactly
    today's fields. With commands it is the list of projects created in the same
    dictation, and every draft also gets new_project and project_suggestion."""
    project_name = payload.pop("project_name", None)
    group_name = payload.pop("group_name", None)
    member_name = payload.pop("member_name", None)
    request = payload.pop("assignment_request", None)
    projects = context.get("projects", []) if context else []
    issues = []
    selected = None
    if project_name or group_name:
        selected, issue = pick_project(project_name, group_name, projects, new_projects or ())
        if issue:
            issues.append(issue)
    elif context and context.get("default_project_id"):
        selected = next((project for project in projects if project["id"] == context["default_project_id"]), None)
    # A project created in the same dictation: personal, with nobody else in it yet.
    created = selected is not None and selected["id"] is None

    assignment = "personal"
    assignee_id = None
    assignee_name = None
    if selected and selected["shared"] and payload.get("kind", "task") != "note":
        assignment = "group"
    if request in ("member", "group") or member_name:
        if selected is None:
            if not issues:
                issues.append("choose_project")
        elif created and member_name:
            issues.append("member_not_available")  # Its people are invited after it exists.
        elif not selected["shared"]:
            issues.append("shared_project_required")
        elif request == "group" and not member_name:
            assignment = "group"
        else:
            matches = match_people(member_name, selected["people"])
            if len(matches) == 1:
                assignee_id = matches[0]["user_id"]
                assignee_name = matches[0]["name"]
                assignment = "member"
            else:
                assignment = "unassigned"
                issues.append("ambiguous_member" if matches else "member_not_available")
    elif request == "me" and selected and selected["shared"]:
        person = next((person for person in selected["people"] if person["user_id"] == context["user_id"]), None)
        if person:
            assignment, assignee_id, assignee_name = "member", person["user_id"], person["name"]
        else:
            assignment = "unassigned"
            issues.append("member_not_available")
    payload.update(list_id=selected["id"] if selected else None, assignment=assignment,
                   assignee_id=assignee_id, assignee_name=assignee_name, assignment_issues=issues,
                   assignment_hints={"project": project_name, "group": group_name, "member": member_name})
    if new_projects is not None:
        payload.update(new_project=selected["name"] if created else None,
                       project_suggestion=project_name if "project_not_available" in issues else None)
    return payload
