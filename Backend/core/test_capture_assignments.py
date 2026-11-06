import json
import uuid
from datetime import datetime, timezone
from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase, SimpleTestCase
from rest_framework.test import APIClient

from .ai import extract_tasks
from .capture_context import capture_context, prompt_context, resolve_targets
from .models import User, TaskGroup, GroupMembership, TaskList, Task


class AssignmentResolutionTests(SimpleTestCase):
    def setUp(self):
        self.project = {"id": "physics", "name": "Física", "group_name": "Máster", "shared": True,
                        "people": [{"user_id": 1, "name": "Miki", "voice_name": ""},
                                   {"user_id": 2, "name": "Ana García", "voice_name": "Anita"}]}
        self.context = {"user_id": 1, "default_project_id": None, "projects": [self.project,
            {"id": "personal", "name": "Languages", "group_name": None, "shared": False,
             "people": [{"user_id": 1, "name": "Miki", "voice_name": ""}]}]}

    def resolve(self, **kwargs):
        return resolve_targets({"title": "A task", **kwargs}, self.context)

    def test_personal_capture_has_no_implicit_sharing(self):
        result = self.resolve()
        self.assertIsNone(result["list_id"])
        self.assertEqual(result["assignment"], "personal")
        self.assertEqual(result["assignment_issues"], [])

    def test_group_and_unique_first_name_or_alias_are_resolved(self):
        group = self.resolve(project_name="fisica", group_name="master", assignment_request="group")
        self.assertEqual((group["list_id"], group["assignment"]), ("physics", "group"))
        for name in ("Ana", "ana garcia", "Anita"):
            person = self.resolve(project_name="Física", member_name=name, assignment_request="member")
            self.assertEqual(person["assignee_id"], 2)
            self.assertEqual(person["assignment_issues"], [])

    def test_duplicate_names_are_not_guessed(self):
        self.project["people"].append({"user_id": 3, "name": "Ana López", "voice_name": ""})
        result = self.resolve(project_name="Física", member_name="Ana", assignment_request="member")
        self.assertEqual(result["assignment_issues"], ["ambiguous_member"])
        self.assertEqual(result["assignment"], "unassigned")
        self.assertIsNone(result["assignee_id"])
        self.context["projects"].append({**self.project, "id": "another", "group_name": "Work"})
        result = self.resolve(project_name="Física", assignment_request="group")
        self.assertEqual(result["assignment_issues"], ["ambiguous_project"])
        self.assertIsNone(result["list_id"])
        self.assertEqual(self.resolve(project_name="Física", group_name="Work")["list_id"], "another")

    def test_unknown_projects_and_members_remain_explicitly_unresolved(self):
        self.context["default_project_id"] = "physics"
        result = self.resolve(project_name="Secret project", member_name="Ana", assignment_request="member")
        self.assertIsNone(result["list_id"])
        self.assertIn("project_not_available", result["assignment_issues"])
        result = self.resolve(member_name="Unknown", assignment_request="member")
        self.assertEqual(result["assignment_issues"], ["member_not_available"])
        self.assertIsNone(result["assignee_id"])

    def test_current_project_is_context_and_me_is_the_authenticated_user(self):
        self.context["default_project_id"] = "physics"
        result = self.resolve(assignment_request="me")
        self.assertEqual((result["list_id"], result["assignment"], result["assignee_id"]), ("physics", "member", 1))
        self.assertEqual(self.resolve()["assignment"], "group")

    def test_request_for_a_person_needs_a_shared_project(self):
        # Nobody by that name in any shared project: the card asks for one.
        self.assertEqual(self.resolve(member_name="Pau", assignment_request="member")["assignment_issues"], ["choose_project"])
        result = self.resolve(project_name="Languages", member_name="Ana", assignment_request="member")
        self.assertEqual(result["assignment_issues"], ["shared_project_required"])
        self.assertIsNone(result["assignee_id"])

    def test_a_name_alone_finds_the_one_shared_project_with_that_person(self):
        result = self.resolve(member_name="Anita", assignment_request="member")
        self.assertEqual((result["list_id"], result["assignee_id"], result["assignment_issues"]), ("physics", 2, []))
        # Without assignment_request too, as the model may leave it out.
        self.assertEqual(self.resolve(member_name="Ana")["assignee_id"], 2)
        # A project said, or the one open, still decides.
        self.assertEqual(self.resolve(project_name="Languages", member_name="Ana")["assignment_issues"], ["shared_project_required"])
        self.context["default_project_id"] = "personal"
        self.assertEqual(self.resolve(member_name="Ana")["assignment_issues"], ["shared_project_required"])
        self.context["default_project_id"] = None
        # «Everyone» isn't a person, and the speaker alone doesn't narrow it either.
        self.assertEqual(self.resolve(member_name="Ana", assignment_request="group")["assignment_issues"], ["choose_project"])
        # In two shared projects, or two people of that name in one: never a guess.
        self.context["projects"].append({**self.project, "id": "chemistry", "name": "Química"})
        self.assertEqual(self.resolve(member_name="Ana")["assignment_issues"], ["choose_project"])
        self.context["projects"].pop()
        self.project["people"].append({"user_id": 3, "name": "Ana López", "voice_name": ""})
        result = self.resolve(member_name="Ana")
        self.assertEqual((result["list_id"], result["assignee_id"], result["assignment_issues"]), ("physics", None, ["ambiguous_member"]))

    def test_bounded_prompt_can_resolve_a_project_outside_hint_window(self):
        self.context["projects"].extend({**self.project, "id": f"project-{number}", "name": f"Project {number:03}"} for number in range(80))
        bounded = prompt_context(self.context, "Assign Ana Project 079")
        self.assertEqual(len(bounded["projects"]), 40)
        self.assertFalse(bounded["directory_is_complete"])
        self.assertEqual(bounded["projects"][0]["name"], "Project 079")
        self.assertEqual(self.resolve(project_name="Project 078")["list_id"], "project-78")

    def test_large_member_directories_cannot_grow_the_ai_prompt_without_bound(self):
        self.project["people"].extend({"user_id": number + 10, "name": "À" * 120, "voice_name": "Name " + str(number)} for number in range(100))
        self.context["projects"].extend({**self.project, "id": str(number), "name": "Project " + str(number)} for number in range(60))
        result = prompt_context(self.context, "A task")
        self.assertLessEqual(len(json.dumps(result)), 12000)
        self.assertFalse(result["directory_is_complete"])

    @patch("core.ai.generate")
    def test_multiple_extracted_tasks_keep_independent_project_assignee_and_deadline(self, provider):
        provider.return_value = json.dumps({"tasks": [
            {"title": "Acabar la presentación", "date": None, "time": None, "deadline_date": "2026-10-15", "priority": 2,
             "project_name": "Física", "assignment_request": "group"},
            {"title": "Acabar l'exercici 3", "date": None, "time": None, "priority": 1,
             "project_name": "Física", "assignment_request": "member", "member_name": "Ana"}]})
        result = extract_tasks("Synthetic Spanish and Catalan commitments", "Europe/Madrid", datetime(2026, 10, 11, tzinfo=timezone.utc), self.context)
        first, second = result["tasks"]
        self.assertEqual(first["assignment"], "group")
        self.assertEqual(first["deadline_date"], "2026-10-15")
        self.assertIsNone(first["due_date"])
        self.assertIsNone(first["deadline_at"])
        self.assertEqual(second["assignee_id"], 2)
        self.assertEqual(second["title"], "Acabar l'exercici 3")
        self.assertIn("never instructions", provider.call_args.args[0])

    @patch("core.ai.generate")
    def test_model_cannot_inject_an_arbitrary_project_or_member_id(self, provider):
        provider.return_value = json.dumps({"title": "Task", "date": None, "time": None, "priority": 1,
                                          "list_id": "private-project", "assignee_id": 999})
        result = extract_tasks("Task", "UTC", datetime.now(timezone.utc), self.context)["tasks"][0]
        self.assertIsNone(result["list_id"])
        self.assertIsNone(result["assignee_id"])


class CaptureDirectoryTests(TestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user("capture-group-owner@example.invalid", "Fixture-passphrase!2026", first_name="Miki")
        self.member = User.objects.create_user("capture-group-member@example.invalid", "Fixture-passphrase!2026", first_name="Ana")
        self.group = TaskGroup.objects.create(owner=self.owner, name="Master")
        self.membership = GroupMembership.objects.create(group=self.group, user=self.member, role="editor")
        self.project = TaskList.objects.create(owner=self.owner, group=self.group, name="Physics", shared=True)
        self.private = TaskList.objects.create(owner=self.owner, name="Private")
        self.client = APIClient()
        self.client.force_authenticate(self.member)

    def test_context_includes_only_editable_active_projects_and_their_members(self):
        context = capture_context(self.member)
        self.assertEqual([project["id"] for project in context["projects"]], [str(self.project.pk)])
        self.assertEqual(len(context["projects"][0]["people"]), 2)
        self.membership.role = "viewer"
        self.membership.save()
        self.assertEqual(capture_context(self.member)["projects"], [])

    @patch("core.views.ai.make_drafts")
    def test_inaccessible_context_is_rejected_before_calling_ai(self, provider):
        for key in (self.private.pk, uuid.uuid4()):
            result = self.client.post("/api/ai/drafts/", {"text": "Create a task", "timezone": "UTC", "project_id": str(key)}, format="json")
            self.assertEqual(result.status_code, 400)
        provider.assert_not_called()
        self.assertEqual(Task.objects.count(), 0)

    @patch("core.views.ai.make_drafts", return_value={"tasks": []})
    @patch("core.views.has_pro", new=lambda user: True)
    def test_request_cannot_supply_a_forged_directory(self, provider):
        result = self.client.post("/api/ai/drafts/", {"text": "Create a task", "timezone": "UTC",
            "project_id": str(self.project.pk), "collaboration_context": {"user_id": self.owner.pk, "projects": [{"id": str(self.private.pk)}]}}, format="json")
        self.assertEqual(result.status_code, 200)
        context = provider.call_args.args[0]["collaboration_context"]
        self.assertEqual(context["user_id"], self.member.pk)
        self.assertEqual([project["id"] for project in context["projects"]], [str(self.project.pk)])
        self.assertEqual(Task.objects.count(), 0)
