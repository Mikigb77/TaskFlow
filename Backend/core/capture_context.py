"""Resolve spoken names against a server-built, permission-scoped directory.

Model output is a suggestion of names, never authority to select arbitrary IDs.
These functions create drafts only; sharing happens in the reviewed task save.
"""
import json
import re
import unicodedata

from django.db.models import Q
from rest_framework.exceptions import ValidationError

from .list_access import visible_lists, list_role, project_people


def normalized(value):
    return re.sub(r"[^\w]+", " ", "".join(character for character in unicodedata.normalize("NFKD", value.casefold())
                                         if not unicodedata.combining(character))).strip()


def capture_context(user, default_project_id=None):
    projects = []
    group_directories = {}
    rows = visible_lists(user).filter(archived=False).filter(Q(group__isnull=True) | Q(group__archived=False))
    for project in rows:
        if list_role(project, user) == "viewer":
            continue
        if project.group_id:
            if project.group_id not in group_directories:
                group_directories[project.group_id] = project_people(project)
            people = group_directories[project.group_id]
        else:
            people = project_people(project)
        projects.append({"id": str(project.pk), "name": project.name,
                         "group_name": project.group.name if project.group_id else None,
                         "shared": project.shared,
                         "people": [person for person in people if person["role"] != "viewer"]})
    default = str(default_project_id) if default_project_id else None
    if default and not any(project["id"] == default for project in projects):
        raise ValidationError({"project_id": "Choose an active project that you can edit."})
    return {"user_id": user.pk, "default_project_id": default, "projects": projects}


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


def resolve_targets(payload, context):
    project_name = payload.pop("project_name", None)
    group_name = payload.pop("group_name", None)
    member_name = payload.pop("member_name", None)
    request = payload.pop("assignment_request", None)
    projects = context.get("projects", []) if context else []
    issues = []
    selected = None
    if project_name or group_name:
        matches = [project for project in projects
                   if (not project_name or normalized(project["name"]) == normalized(project_name))
                   and (not group_name or normalized(project.get("group_name") or "") == normalized(group_name))]
        if len(matches) == 1:
            selected = matches[0]
        else:
            issues.append("ambiguous_project" if matches else "project_not_available")
    elif context and context.get("default_project_id"):
        selected = next((project for project in projects if project["id"] == context["default_project_id"]), None)

    assignment = "personal"
    assignee_id = None
    assignee_name = None
    if selected and selected["shared"] and payload.get("kind", "task") != "note":
        assignment = "group"
    if request in ("member", "group") or member_name:
        if selected is None:
            if not issues:
                issues.append("choose_project")
        elif not selected["shared"]:
            issues.append("shared_project_required")
        elif request == "group" and not member_name:
            assignment = "group"
        else:
            matches = [person for person in selected["people"] if member_name and (
                normalized(person["name"]) == normalized(member_name) or
                normalized(person["name"]).startswith(normalized(member_name) + " ") or
                (person.get("voice_name") and normalized(person["voice_name"]) == normalized(member_name)))]
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
    return payload
