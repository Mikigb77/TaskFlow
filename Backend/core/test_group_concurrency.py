from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import uuid

from django.core.cache import cache
from django.db import close_old_connections, connections
from django.test import TransactionTestCase, skipUnlessDBFeature
from rest_framework.test import APIClient

from .list_access import visible_lists
from .models import User, TaskGroup, GroupMembership, TaskList, Task


@skipUnlessDBFeature("has_select_for_update")
class GroupConcurrencyTests(TransactionTestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user("group-race-owner@example.invalid", "Fixture-passphrase!2026")
        self.member = User.objects.create_user("group-race-member@example.invalid", "Fixture-passphrase!2026")
        self.group = TaskGroup.objects.create(owner=self.owner, name="Team")
        GroupMembership.objects.create(group=self.group, user=self.member, role="admin")
        self.projects = [TaskList.objects.create(owner=self.owner, group=self.group, shared=True, name=f"Project {n}") for n in range(2)]

    def race(self, operations):
        barrier = Barrier(len(operations))
        def run(operation):
            close_old_connections()
            try:
                client = APIClient()
                user, method, path, data = operation
                client.force_authenticate(user)
                barrier.wait(timeout=10)
                response = getattr(client, method)(path, data, format="json")
                return response.status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=len(operations)) as pool:
            return list(pool.map(run, operations))

    def test_removal_and_assignments_in_two_projects_never_leave_removed_assignee(self):
        operations = [(self.owner, "put", f"/api/tasks/{uuid.uuid4()}/", {
            "title": "Concurrent task", "list_id": str(project.pk), "assignment": "member", "assignee_id": self.member.pk}) for project in self.projects]
        operations.append((self.owner, "post", f"/api/groups/{self.group.pk}/member/", {"user_id": self.member.pk, "role": "remove"}))
        results = self.race(operations)
        self.assertEqual(results[-1], 200)
        self.assertTrue(all(status in (201, 400) for status in results[:2]), results)
        self.assertFalse(Task.objects.filter(assignee=self.member).exists())
        self.assertFalse(visible_lists(self.member).exists())
        self.assertFalse(GroupMembership.objects.filter(group=self.group, user=self.member).exists())

    def test_project_creation_and_admin_removal_cannot_grant_lingering_access(self):
        results = self.race([
            (self.member, "put", f"/api/lists/{uuid.uuid4()}/", {"name": "Concurrent project", "group_id": str(self.group.pk)}),
            (self.owner, "post", f"/api/groups/{self.group.pk}/member/", {"user_id": self.member.pk, "role": "remove"}),
        ])
        self.assertIn(results[0], (201, 400, 403, 404))
        self.assertEqual(results[1], 200)
        self.assertFalse(visible_lists(self.member).exists())
        self.assertFalse(TaskList.objects.filter(group=self.group).exclude(owner=self.owner).exists())
