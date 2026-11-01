"""Activity says who an assignment went to: assignee_name and assignee_is_you (UX-1514)."""
import uuid

from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from .account_deletion import delete_account
from .models import ListMembership, Task, TaskEvent, TaskList, TaskNotification, User

PASSWORD = "Activity-test-passphrase!2026"


class AssignmentActivityTests(TestCase):
    def setUp(self):
        cache.clear()
        self.paul = User.objects.create_user("paul@example.invalid", PASSWORD, first_name="Paul")
        self.ana = User.objects.create_user("ana@example.invalid", PASSWORD, first_name="Ana")
        self.miki = User.objects.create_user("miki@example.invalid", PASSWORD, first_name="Miki")
        self.project = TaskList.objects.create(owner=self.paul, name="Excursión", shared=True)
        for person in (self.ana, self.miki):
            ListMembership.objects.create(task_list=self.project, user=person, role="editor")
        self.task = self.save(self.paul, title="Reservar el autobús", assignment="member", assignee_id=self.miki.pk)

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def save(self, user, task=None, **fields):
        body = {**(task or {"title": "Untitled", "version": 0}), "list_id": str(self.project.pk), **fields}
        path = f"/api/tasks/{body.get('id') or uuid.uuid4()}/"
        response = self.client_for(user).put(path, body, format="json")
        self.assertIn(response.status_code, (200, 201), response.data)
        return response.data

    def activity(self, user):
        response = self.client_for(user).get("/api/notifications/")
        self.assertEqual(response.status_code, 200)
        return response.data["results"]

    def assigned(self, user):
        return [item for item in self.activity(user) if item["action"] == "assigned"]

    def test_the_new_assignee_reads_you_and_the_previous_one_reads_who(self):
        self.save(self.paul, self.task, assignee_id=self.ana.pk)
        [to_ana] = self.assigned(self.ana)
        [to_miki] = self.assigned(self.miki)  # the person it was taken off
        self.assertEqual((to_ana["assignee_name"], to_ana["assignee_is_you"]), ("Ana", True))
        self.assertEqual((to_miki["assignee_name"], to_miki["assignee_is_you"]), ("Ana", False))
        self.assertEqual(to_ana["actor_name"], "Paul")
        self.assertEqual(to_ana["task_title"], "Reservar el autobús")
        # The same entry marked read keeps the fields.
        read = self.client_for(self.ana).post(f"/api/notifications/{to_ana['id']}/read/")
        self.assertEqual((read.data["assignee_name"], read.data["assignee_is_you"]), ("Ana", True))

    def test_everyones_or_nobodys_has_no_name(self):
        group = self.save(self.paul, self.task, assignment="group", assignee_id=None)
        for person in (self.ana, self.miki):
            [entry] = self.assigned(person)
            self.assertEqual((entry["assignee_name"], entry["assignee_is_you"]), (None, False))
        self.save(self.ana, group, assignment="unassigned", assignee_id=None)
        entries = self.assigned(self.paul)  # an unassigned task is its project owner's to sort out
        self.assertEqual([(entry["assignee_name"], entry["assignee_is_you"]) for entry in entries], [(None, False)])

    def test_the_event_stores_the_assignees_id_and_the_name_shown_is_todays(self):
        self.save(self.paul, self.task, assignee_id=self.ana.pk)
        event = TaskEvent.objects.get(action="assigned")
        self.assertEqual(event.details["assignee_id"], self.ana.pk)
        self.assertNotIn("Ana", str(event.details))
        self.client_for(self.ana).patch("/api/auth/me/", {"first_name": "Ana María"}, format="json")
        self.assertEqual(self.assigned(self.miki)[0]["assignee_name"], "Ana María")

    def test_older_entries_and_other_actions_have_neither_field(self):
        task = Task.objects.get(pk=self.task["id"])
        older = TaskEvent.objects.create(task=task, version=task.version, action="assigned", actor=self.paul,
                                         details={"fields": ["assignee_id"]})  # recorded before this change
        TaskNotification.objects.create(recipient=self.ana, event=older)
        self.save(self.ana, self.task, is_completed=True)
        items = self.activity(self.miki) + self.activity(self.ana)
        self.assertEqual({item["action"] for item in items}, {"created", "assigned", "completed"})
        for item in items:
            with self.subTest(action=item["action"]):
                self.assertNotIn("assignee_name", item)
                self.assertNotIn("assignee_is_you", item)

    def test_when_the_assignees_account_is_deleted_the_entry_keeps_no_trace_of_them(self):
        self.save(self.paul, self.task, assignee_id=self.ana.pk)
        delete_account(self.ana)
        event = TaskEvent.objects.get(action="assigned")
        self.assertIsNone(event.details["assignee_id"])
        [entry] = self.assigned(self.miki)
        self.assertEqual((entry["assignee_name"], entry["assignee_is_you"]), (None, False))


class UpdatedFieldsActivityTests(AssignmentActivityTests):
    """An update says what it changed (UX-2508), so the app can say «ha movido» for a move."""

    def test_an_update_lists_its_changed_fields_and_other_actions_do_not(self):
        moved = self.save(self.paul, self.task, scheduled_date="2026-11-03")
        self.save(self.paul, moved, title="Reservar el autobús grande")
        updates = [item for item in self.activity(self.miki) if item["action"] == "updated"]  # Its assignee hears.
        self.assertEqual([item["fields"] for item in updates], [["title"], ["scheduled_date"]])
        self.assertTrue(all("fields" not in item for item in self.activity(self.miki) if item["action"] != "updated"))
