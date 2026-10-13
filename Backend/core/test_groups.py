import uuid
from datetime import timedelta
from tempfile import TemporaryDirectory

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .models import (User, Task, TaskList, TaskGroup, GroupMembership, GroupInvitation,
                     ListMembership, TaskEvent, TaskNotification, ProjectPreference)


class GroupTests(TestCase):
    def setUp(self):
        cache.clear()
        self.files = TemporaryDirectory(prefix="taskflow-group-tests-")
        self.addCleanup(self.files.cleanup)
        settings = override_settings(MEDIA_ROOT=self.files.name)
        settings.enable()
        self.addCleanup(settings.disable)
        self.users = [User.objects.create_user(f"groups-{name}@example.invalid", "Fixture-only!2026", first_name=name.title())
                      for name in ("owner", "admin", "ana", "viewer", "stranger")]
        self.owner, self.admin, self.ana, self.viewer, self.stranger = self.users
        self.clients = []
        for user in self.users:
            client = APIClient()
            client.force_authenticate(user)
            self.clients.append(client)
        self.a, self.b, self.c, self.d, self.e = self.clients
        self.group = TaskGroup.objects.create(owner=self.owner, name="Master's group")
        for user, role in ((self.admin, "admin"), (self.ana, "editor"), (self.viewer, "viewer")):
            GroupMembership.objects.create(group=self.group, user=user, role=role)
        self.project = TaskList.objects.create(owner=self.owner, group=self.group, name="Physics", shared=True)
        self.second = TaskList.objects.create(owner=self.owner, group=self.group, name="Languages", shared=True)
        self.path = f"/api/groups/{self.group.pk}/"
        self.project_path = f"/api/lists/{self.project.pk}/"

    def task(self, client=None, **kwargs):
        key = uuid.uuid4()
        response = (client or self.a).put(f"/api/tasks/{key}/", {
            "title": "Finish exercise 3", "list_id": str(self.project.pk), "version": 0, **kwargs}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def upload(self, task_id, client=None):
        response = (client or self.a).put(f"/api/attachments/{uuid.uuid4()}/", {
            "task_id": task_id, "name": "notes.txt", "file": SimpleUploadedFile("file", b"lecture notes")}, format="multipart")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data["id"]

    def test_one_membership_covers_projects_and_member_directory_is_scoped(self):
        for client in (self.a, self.b, self.c, self.d):
            projects = client.get("/api/lists/access/").data["lists"]
            self.assertEqual({item["id"] for item in projects}, {str(self.project.pk), str(self.second.pk)})
            self.assertEqual(projects[0]["group_name"], "Master's group")
            people = projects[0]["people"]
            self.assertEqual({person["user_id"] for person in people}, {user.pk for user in self.users[:4]})
            self.assertTrue(all("email" not in person for person in people))
        self.assertEqual(self.e.get(self.path).status_code, 404)
        self.assertEqual(self.e.get("/api/lists/access/").data["lists"], [])

    def test_group_creation_idempotent_versioning_and_private_identifiers(self):
        key = uuid.uuid4()
        url = f"/api/groups/{key}/"
        created = self.a.put(url, {"name": "Housemates", "version": 0}, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(self.a.put(url, {"name": "Again", "version": 0}, format="json").status_code, 409)
        self.assertEqual(self.e.put(url, {"name": "Steal", "version": 0}, format="json").status_code, 404)
        changed = self.a.put(url, {"name": "Home", "version": 1, "archived": True}, format="json")
        self.assertEqual(changed.status_code, 200, changed.data)
        self.assertTrue(changed.data["archived"])
        self.assertEqual(changed.data["owner_id"], self.owner.pk)

    def test_project_admin_can_create_and_edit_but_cannot_take_ownership(self):
        created = self.b.put(f"/api/lists/{uuid.uuid4()}/", {
            "name": "Presentation", "group_id": str(self.group.pk), "version": 0}, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(created.data["owner_id"], self.owner.pk)
        self.assertTrue(created.data["shared"])
        changed = self.b.put(self.project_path, {"name": "Physics II", "version": 1}, format="json")
        self.assertEqual(changed.status_code, 200, changed.data)
        self.assertEqual(changed.data["owner_id"], self.owner.pk)
        for client in (self.c, self.d):
            denied = client.put(f"/api/lists/{uuid.uuid4()}/", {
                "name": "No", "group_id": str(self.group.pk), "version": 0}, format="json")
            self.assertEqual(denied.status_code, 403)
        self.assertEqual(self.b.post(self.project_path + "invite/", {"email": self.stranger.email, "role": "editor"}, format="json").status_code, 400)

    def test_archiving_group_preserves_tasks_and_exposes_effective_project_state(self):
        task = self.task()
        response = self.a.put(self.path, {"name": self.group.name, "archived": True, "version": 1}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        project = self.c.get(self.project_path).data
        self.assertTrue(project["group_archived"])
        self.assertFalse(project["archived"])
        self.assertEqual(self.c.get(f"/api/tasks/{task['id']}/").status_code, 200)
        response = self.a.put(self.path, {"name": self.group.name, "archived": False, "version": response.data["version"]}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(self.c.get(self.project_path).data["group_archived"])

    def test_projects_have_no_1000_project_cap(self):
        TaskList.objects.bulk_create([TaskList(owner=self.stranger, name=f"Project {number}") for number in range(1000)])
        response = self.e.put(f"/api/lists/{uuid.uuid4()}/", {"name": "Next project", "version": 0}, format="json")
        self.assertEqual(response.status_code, 201, response.data)

    def test_invites_require_email_and_code_expire_and_cannot_escalate_admin(self):
        self.assertEqual(self.b.post(self.path + "invite/", {"email": self.stranger.email, "role": "admin"}, format="json").status_code, 403)
        invited = self.b.post(self.path + "invite/", {"email": self.stranger.email.upper(), "role": "editor"}, format="json")
        self.assertEqual(invited.status_code, 201, invited.data)
        url = f"/api/group-invitations/{invited.data['id']}/respond/"
        pending = self.e.get("/api/group-invitations/").data["invitations"]
        self.assertEqual(pending[0]["group_name"], self.group.name)
        self.assertNotIn("code", pending[0])
        self.assertEqual(self.c.post(url, {"decision": "accept", "code": invited.data["code"]}, format="json").status_code, 404)
        self.assertEqual(self.e.post(url, {"decision": "accept", "code": "wrong"}, format="json").status_code, 400)
        for _ in range(2):
            self.assertEqual(self.e.post(url, {"decision": "accept", "code": invited.data["code"]}, format="json").status_code, 200)
        self.assertEqual(GroupMembership.objects.filter(group=self.group, user=self.stranger).count(), 1)
        self.assertEqual(len(self.e.get("/api/lists/access/").data["lists"]), 2)
        self.a.post(self.path + "member/", {"user_id": self.stranger.pk, "role": "remove"}, format="json")
        self.assertEqual(self.e.post(url, {"decision": "accept", "code": invited.data["code"]}, format="json").status_code, 400)
        fresh = self.a.post(self.path + "invite/", {"email": self.stranger.email, "role": "viewer"}, format="json")
        GroupInvitation.objects.filter(pk=fresh.data["id"]).update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.e.post(f"/api/group-invitations/{fresh.data['id']}/respond/", {"decision": "accept", "code": fresh.data["code"]}, format="json").status_code, 400)

    def test_admin_cannot_manage_other_admins_or_transfer_or_delete_group(self):
        for payload in ({"user_id": self.admin.pk, "role": "viewer"}, {"user_id": self.ana.pk, "role": "admin"}):
            self.assertEqual(self.b.post(self.path + "member/", payload, format="json").status_code, 403)
        self.assertEqual(self.b.post(self.path + "transfer/", {"user_id": self.ana.pk, "version": 1}, format="json").status_code, 403)
        self.assertEqual(self.b.delete(self.path, {"version": 1}, format="json").status_code, 403)
        self.assertEqual(self.c.post(self.path + "member/", {"user_id": self.viewer.pk, "role": "remove"}, format="json").status_code, 403)

    def test_assignment_keeps_visibility_creator_and_date_only_deadline(self):
        data = self.task(assignment="member", assignee_id=self.ana.pk, deadline_date="2026-10-15")
        for client in (self.a, self.b, self.c, self.d):
            response = client.get(f"/api/tasks/{data['id']}/")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data["assignee_name"], "Ana")
            self.assertEqual(response.data["created_by"], self.owner.pk)
            self.assertEqual(response.data["deadline_date"], "2026-10-15")
            self.assertIsNone(response.data["due_date"])
        self.assertEqual(self.e.get(f"/api/tasks/{data['id']}/").status_code, 404)
        history = self.c.get(f"/api/tasks/{data['id']}/history/").data
        self.assertEqual(history[0]["actor_name"], "Owner")

    def test_group_task_has_one_completion_and_stale_edits_conflict(self):
        data = self.task()
        self.assertEqual(data["assignment"], "group")
        path = f"/api/tasks/{data['id']}/"
        completed = self.c.put(path, {**data, "is_completed": True}, format="json")
        self.assertEqual(completed.status_code, 200, completed.data)
        self.assertTrue(self.a.get(path).data["is_completed"])
        self.assertEqual(self.b.put(path, {**data, "title": "Stale edit"}, format="json").status_code, 409)
        self.assertEqual(TaskEvent.objects.filter(task_id=data["id"]).count(), 2)
        self.assertEqual(self.a.get(path + "history/").data[-1]["action"], "completed")

    def test_invalid_assignment_and_viewer_writes_are_rejected(self):
        for assignee_id in (self.viewer.pk, self.stranger.pk, 99999):
            response = self.a.put(f"/api/tasks/{uuid.uuid4()}/", {"title": "No", "list_id": str(self.project.pk), "assignment": "member", "assignee_id": assignee_id}, format="json")
            self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(self.a.put(f"/api/tasks/{uuid.uuid4()}/", {"title": "Private", "assignment": "member", "assignee_id": self.ana.pk}, format="json").status_code, 400)
        data = self.task()
        self.assertEqual(self.d.put(f"/api/tasks/{data['id']}/", {**data, "is_completed": True}, format="json").status_code, 403)

    def test_removing_member_clears_assignments_revokes_files_and_preserves_tasks(self):
        data = self.task(self.c, assignment="member", assignee_id=self.ana.pk)
        attachment_id = self.upload(data["id"], self.c)
        self.task(assignment="member", assignee_id=self.ana.pk, list_id=str(self.second.pk))
        self.assertEqual(self.b.post(self.path + "member/", {"user_id": self.ana.pk, "role": "remove"}, format="json").status_code, 200)
        self.assertEqual(Task.objects.filter(assignment="unassigned", assignee__isnull=True).count(), 2)
        for suffix in ("", "history/"):
            self.assertEqual(self.c.get(f"/api/tasks/{data['id']}/{suffix}").status_code, 404)
        self.assertEqual(self.c.get(f"/api/attachments/{attachment_id}/content/").status_code, 404)
        self.assertEqual(self.a.get(f"/api/attachments/{attachment_id}/content/").status_code, 200)
        self.assertEqual(self.c.get("/api/notifications/").data["results"], [])
        self.assertEqual(self.c.put(f"/api/tasks/{data['id']}/", data, format="json").status_code, 404)
        self.assertEqual(Task.objects.get(pk=data["id"]).owner_id, self.ana.pk)
        self.assertEqual(self.a.get("/api/notifications/unread/").data["count"], 2)

    def test_downgrading_assignee_preserves_read_access_and_flags_reassignment(self):
        data = self.task(assignment="member", assignee_id=self.ana.pk)
        response = self.a.post(self.path + "member/", {"user_id": self.ana.pk, "role": "viewer"}, format="json")
        self.assertEqual(response.status_code, 200)
        current = self.c.get(f"/api/tasks/{data['id']}/")
        self.assertEqual(current.data["assignment"], "unassigned")
        self.assertEqual(self.c.put(f"/api/tasks/{data['id']}/", current.data, format="json").status_code, 403)

    def test_transfer_owner_preserves_projects_and_former_owner_can_leave(self):
        data = self.task()
        response = self.a.post(self.path + "transfer/", {"user_id": self.ana.pk, "version": 1}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["owner_id"], self.ana.pk)
        self.assertEqual(TaskList.objects.filter(group=self.group, owner=self.ana).count(), 2)
        self.assertEqual(GroupMembership.objects.get(group=self.group, user=self.owner).role, "admin")
        self.assertEqual(self.c.post(self.path + "leave/").status_code, 400)
        self.assertEqual(self.a.post(self.path + "leave/").status_code, 204)
        self.assertEqual(self.c.get(f"/api/tasks/{data['id']}/").status_code, 200)
        self.assertEqual(self.a.get(self.project_path).status_code, 404)

    @override_settings(FREE_ATTACHMENT_BYTES=20)
    def test_transfer_cannot_overfill_new_owners_storage(self):
        group_task = self.task()
        self.upload(group_task["id"])
        private = self.c.put(f"/api/tasks/{uuid.uuid4()}/", {"title": "Private"}, format="json")
        self.upload(private.data["id"], self.c)
        response = self.a.post(self.path + "transfer/", {"user_id": self.ana.pk, "version": 1}, format="json")
        self.assertEqual(response.status_code, 400, response.data)
        self.group.refresh_from_db()
        self.assertEqual(self.group.owner_id, self.owner.pk)

    def test_shared_project_cannot_be_moved_and_private_share_requires_confirmation(self):
        response = self.a.put(self.project_path, {"name": "Physics", "group_id": None, "version": 1}, format="json")
        self.assertEqual(response.status_code, 400)
        private = TaskList.objects.create(owner=self.owner, name="Private notes")
        task = Task.objects.create(owner=self.owner, task_list=private, title="Initially private")
        payload = {"name": private.name, "group_id": str(self.group.pk), "version": 1}
        path = f"/api/lists/{private.pk}/"
        self.assertEqual(self.a.put(path, payload, format="json").status_code, 400)
        self.assertEqual(self.c.get(f"/api/tasks/{task.pk}/").status_code, 404)
        self.assertEqual(self.a.put(path, {**payload, "confirm_share": True}, format="json").status_code, 200)
        shared = self.c.get(f"/api/tasks/{task.pk}/")
        self.assertEqual(shared.status_code, 200)
        self.assertEqual(shared.data["assignment"], "group")

    def test_notifications_preferences_read_state_deduplication_and_privacy(self):
        response = self.c.post(self.project_path + "preferences/", {"pinned": True, "notifications": "muted"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["pinned"])
        self.assertFalse(self.a.get(self.project_path).data["pinned"])
        data = self.task(assignment="member", assignee_id=self.ana.pk)
        self.assertEqual(self.c.get("/api/notifications/unread/").data["count"], 0)
        self.c.post(self.project_path + "preferences/", {"notifications": "assigned"}, format="json")
        path = f"/api/tasks/{data['id']}/"
        updated = self.a.put(path, {**data, "deadline_date": "2026-10-15"}, format="json")
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(self.a.put(path, {**data, "deadline_date": "2026-10-15"}, format="json").status_code, 409)
        notifications = self.c.get("/api/notifications/").data["results"]
        self.assertEqual(len(notifications), 1)
        key = notifications[0]["id"]
        self.assertEqual(notifications[0]["actor_name"], "Owner")
        self.assertEqual(self.e.post(f"/api/notifications/{key}/read/").status_code, 404)
        self.assertEqual(self.c.post(f"/api/notifications/{key}/read/").status_code, 200)
        self.assertEqual(self.c.get("/api/notifications/unread/").data["count"], 0)
        self.assertEqual(TaskNotification.objects.filter(recipient=self.ana).count(), 1)

    def test_group_access_ignores_stale_direct_memberships(self):
        ListMembership.objects.create(task_list=self.project, user=self.stranger, role="editor")
        self.assertEqual(self.e.get(self.project_path).status_code, 404)
        self.assertEqual(self.e.get("/api/lists/access/").data["lists"], [])

    def test_deleting_group_requires_empty_projects_and_current_version(self):
        self.assertEqual(self.a.delete(self.path, {"version": 0}, format="json").status_code, 409)
        self.assertEqual(self.a.delete(self.path, {"version": 1}, format="json").status_code, 400)
        TaskList.objects.filter(group=self.group).update(is_deleted=True)
        self.assertEqual(self.a.delete(self.path, {"version": 1}, format="json").status_code, 204)
        self.assertEqual(self.a.get(self.path).status_code, 404)
        self.assertEqual(self.c.get(self.path).status_code, 404)
