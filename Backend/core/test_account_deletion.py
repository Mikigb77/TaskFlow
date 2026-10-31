import json
import uuid
from datetime import timedelta
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

from .account_deletion import DeleteAccountView
from .list_access import display_name
from .models import (Attachment, EmailDelivery, FreeDictation, GoogleIdentity, GroupInvitation, GroupMembership,
                     ListInvitation, ListMembership, LoginSession, ProjectPreference, Task, TaskEvent, TaskGroup,
                     TaskList, TaskNotification, User)

PASSWORD = "Leaving-fixture-2026!"
PATH = "/api/auth/delete-account/"


class AccountDeletionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        def person(name, email=None):
            return User.objects.create_user(email or f"deletion-{name.lower()}@example.invalid", PASSWORD, first_name=name)
        cls.leaver = person("Lena", "leaver@example.invalid")
        cls.ed, cls.eve, cls.vic, cls.ada, cls.otto = (person(name) for name in ("Ed", "Eve", "Vic", "Ada", "Otto"))

    def setUp(self):
        cache.clear()
        self.files = TemporaryDirectory(prefix="taskflow-deletion-tests-", ignore_cleanup_errors=True)
        self.addCleanup(self.files.cleanup)
        media = override_settings(MEDIA_ROOT=self.files.name)
        media.enable()
        self.addCleanup(media.disable)
        self.me = self.client_for(self.leaver)

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def task(self, client, project=None, **fields):
        body = {"title": "Synthetic task", "version": 0, **fields}
        if project is not None:
            body["list_id"] = str(project.pk)
        response = client.put(f"/api/tasks/{uuid.uuid4()}/", body, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def upload(self, client, task, content=b"synthetic file"):
        response = client.put(f"/api/attachments/{uuid.uuid4()}/", {
            "task_id": task["id"], "name": "notes.txt", "file": SimpleUploadedFile("file", content)}, format="multipart")
        self.assertEqual(response.status_code, 201, response.data)
        return Attachment.objects.get(pk=response.data["id"])

    def delete(self, client=None, **body):
        with self.captureOnCommitCallbacks(execute=True):
            return (client or self.me).post(PATH, body, format="json")

    def confirm(self, client=None, **credentials):
        # As the app does: show the preview, then confirm with its plan.
        client = client or self.me
        return self.delete(client, plan=client.get(PATH).data["plan"], **credentials)

    def read(self, client, attachment):
        response = client.get(f"/api/attachments/{attachment.pk}/content/")
        content = b"".join(response.streaming_content) if response.status_code == 200 else None
        response.close()  # Windows can't remove the temporary folder while a file is open.
        return response.status_code, content

    def stored(self, attachment):
        return Path(self.files.name, attachment.file.name).exists()

    def test_personal_data_files_and_sessions_go_and_the_address_can_sign_up_again(self):
        phone, tablet = APIClient(), APIClient()
        sessions = []
        for device in (phone, tablet):
            signed_in = device.post("/api/auth/login/", {"email": self.leaver.email, "password": PASSWORD}, format="json")
            self.assertEqual(signed_in.status_code, 200, signed_in.data)
            device.credentials(HTTP_AUTHORIZATION="Bearer " + signed_in.data["access"])
            sessions.append(signed_in.data)
        GoogleIdentity.objects.create(user=self.leaver, subject="leaver-google-subject")
        dentist = self.task(phone, title="Dentist")
        gate = self.task(phone, title="Gate code", kind="note")
        scan = self.upload(phone, dentist)
        home = TaskList.objects.create(owner=self.leaver, name="Home")
        door = self.task(phone, home, title="Paint the door")
        # A former member's task goes with the project instead of becoming their personal task.
        left_behind = Task.objects.create(owner=self.ed, task_list=home, title="Left behind")
        tombstone = Task.objects.create(owner=self.leaver, title="Deleted earlier", is_deleted=True)
        FreeDictation.objects.create(user=self.leaver, period="2026-10", digest="synthetic", counted=True,
                                     created_at=timezone.now())
        EmailDelivery.objects.create(recipient=self.leaver.email, subject="Reset", body="Synthetic code",
                                     expires_at=timezone.now() + timedelta(minutes=30))
        theirs = TaskList.objects.create(owner=self.ed, name="Ed's project", shared=True)
        ListMembership.objects.create(task_list=theirs, user=self.leaver, role="editor")
        ProjectPreference.objects.create(task_list=theirs, user=self.leaver, pinned=True)
        band = TaskGroup.objects.create(owner=self.ed, name="Ed's band")
        GroupMembership.objects.create(group=band, user=self.leaver, role="editor")
        leaver_id = self.leaver.pk

        self.assertEqual(self.confirm(phone, password=PASSWORD).status_code, 204)

        self.assertFalse(User.objects.filter(pk=leaver_id).exists())
        self.assertFalse(Task.objects.filter(pk__in=[dentist["id"], gate["id"], door["id"], left_behind.pk, tombstone.pk]).exists())
        self.assertFalse(TaskList.objects.filter(pk=home.pk).exists())
        self.assertFalse(Attachment.objects.exists())
        self.assertFalse(self.stored(scan))
        for model in (LoginSession, GoogleIdentity, FreeDictation, ProjectPreference, ListMembership, GroupMembership):
            self.assertFalse(model.objects.filter(user_id=leaver_id).exists(), model.__name__)
        self.assertFalse(OutstandingToken.objects.exists())
        self.assertFalse(EmailDelivery.objects.exists())
        # The other people's apps sync the membership change.
        for row in (theirs, band):
            row.refresh_from_db()
            self.assertEqual(row.version, 2)
        # Another device is signed out on its next request.
        self.assertEqual(tablet.get("/api/auth/me/").status_code, 401)
        refresh = APIClient().post("/api/auth/refresh/", {"refresh": sessions[1]["refresh"]}, format="json")
        self.assertEqual(refresh.status_code, 401)
        # The same code as the other endpoints, so a phone that was idle also erases its copy.
        self.assertEqual(refresh.data["code"], "user_not_found")
        self.assertEqual(tablet.get("/api/auth/me/").data["code"], "user_not_found")
        again = APIClient().post("/api/auth/register/", {"email": "leaver@example.invalid", "password": PASSWORD}, format="json")
        self.assertEqual(again.status_code, 201, again.data)
        self.assertNotEqual(again.data["user"]["id"], leaver_id)

    def test_a_task_in_someone_elses_project_stays_for_the_group_with_its_files(self):
        maths = TaskList.objects.create(owner=self.ed, name="Maths", shared=True)
        ListMembership.objects.create(task_list=maths, user=self.leaver, role="editor")
        ListMembership.objects.create(task_list=maths, user=self.vic, role="viewer")
        exercise = self.task(self.me, maths, title="Exercise 3")
        solution = self.upload(self.me, exercise, b"worked solution")
        # A file the person added to someone else's task stays with that task too.
        revision = self.task(self.client_for(self.ed), maths, title="Revision")
        summary = self.upload(self.me, revision, b"summary sheet")
        preview = self.me.get(PATH).data
        self.assertEqual(preview["kept_in_shared"], 1)
        self.assertEqual(preview["kept_files_in_shared"], 2)  # the solution and the summary sheet

        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        kept = Task.objects.get(pk=exercise["id"])
        self.assertEqual((kept.owner_id, kept.version), (self.ed.pk, exercise["version"] + 1))
        for user in (self.ed, self.vic):
            seen = self.client_for(user).get(f"/api/tasks/{exercise['id']}/")
            self.assertEqual((seen.status_code, seen.data["title"]), (200, "Exercise 3"))
        for attachment, content in ((solution, b"worked solution"), (summary, b"summary sheet")):
            attachment.refresh_from_db()
            self.assertEqual(attachment.owner_id, self.ed.pk)  # Storage is charged to the project's owner.
            self.assertTrue(self.stored(attachment))
            for user in (self.ed, self.vic):
                self.assertEqual(self.read(self.client_for(user), attachment), (200, content))

    def test_a_shared_project_goes_to_its_earliest_editor(self):
        trip = TaskList.objects.create(owner=self.leaver, name="Trip", shared=True)
        ListMembership.objects.create(task_list=trip, user=self.vic, role="viewer")  # The earliest member, but a viewer.
        ListMembership.objects.create(task_list=trip, user=self.ed, role="editor")
        ListMembership.objects.create(task_list=trip, user=self.eve, role="editor")
        recipes = TaskList.objects.create(owner=self.leaver, name="Recipes", shared=True)
        ListMembership.objects.create(task_list=recipes, user=self.vic, role="viewer")
        train = self.task(self.me, trip, title="Book the train")
        packing = self.task(self.client_for(self.eve), trip, title="Pack")

        preview = self.me.get(PATH).data
        self.assertEqual(preview["handovers"], [
            {"kind": "project", "id": str(recipes.pk), "name": "Recipes", "to": "Vic"},
            {"kind": "project", "id": str(trip.pk), "name": "Trip", "to": "Ed"}])
        self.assertEqual((preview["personal"]["projects"], preview["kept_in_shared"]), (0, 1))

        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        trip.refresh_from_db()
        self.assertEqual((trip.owner_id, trip.is_deleted, trip.version), (self.ed.pk, False, 2))
        # Owners aren't members, so the heir's membership row is gone.
        self.assertEqual(set(trip.memberships.values_list("user_id", "role")), {(self.vic.pk, "viewer"), (self.eve.pk, "editor")})
        self.assertEqual(Task.objects.get(pk=train["id"]).owner_id, self.ed.pk)
        self.assertEqual(Task.objects.get(pk=packing["id"]).owner_id, self.eve.pk)
        self.assertEqual(self.client_for(self.ed).get(f"/api/lists/{trip.pk}/").data["role"], "owner")
        recipes.refresh_from_db()
        self.assertEqual((recipes.owner_id, recipes.memberships.count()), (self.vic.pk, 0))

    def test_a_group_goes_to_its_earliest_admin_and_its_projects_stay(self):
        group = TaskGroup.objects.create(owner=self.leaver, name="Maths group")
        GroupMembership.objects.create(group=group, user=self.ed, role="editor")  # The earliest member, not an admin.
        GroupMembership.objects.create(group=group, user=self.ada, role="admin")
        GroupMembership.objects.create(group=group, user=self.eve, role="admin")
        algebra = TaskList.objects.create(owner=self.leaver, group=group, name="Algebra", shared=True)
        geometry = TaskList.objects.create(owner=self.leaver, group=group, name="Geometry", shared=True)
        homework = self.task(self.me, algebra, title="Homework")
        file = self.upload(self.me, homework)

        preview = self.me.get(PATH).data
        self.assertEqual(preview["handovers"], [{"kind": "group", "id": str(group.pk), "name": "Maths group", "to": "Ada"}])
        self.assertEqual(preview["personal"], {"tasks": 0, "notes": 0, "files": 0, "projects": 0, "groups": 0})

        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        group.refresh_from_db()
        self.assertEqual((group.owner_id, group.version), (self.ada.pk, 2))
        self.assertEqual(set(group.memberships.values_list("user_id", "role")), {(self.ed.pk, "editor"), (self.eve.pk, "admin")})
        for project in (algebra, geometry):
            project.refresh_from_db()
            self.assertEqual((project.owner_id, project.is_deleted, project.version), (self.ada.pk, False, 2))
        self.assertEqual(Task.objects.get(pk=homework["id"]).owner_id, self.ada.pk)
        file.refresh_from_db()
        self.assertEqual(file.owner_id, self.ada.pk)
        self.assertTrue(self.stored(file))
        projects = self.client_for(self.ed).get("/api/lists/access/").data["lists"]
        self.assertEqual({row["id"] for row in projects}, {str(algebra.pk), str(geometry.pk)})
        self.assertEqual(self.client_for(self.ada).get(f"/api/groups/{group.pk}/").data["role"], "owner")

    def test_a_group_with_nobody_else_is_deleted_with_its_projects(self):
        solo = TaskGroup.objects.create(owner=self.leaver, name="Just me")
        plans = TaskList.objects.create(owner=self.leaver, group=solo, name="Plans", shared=True)
        plan = self.task(self.me, plans, title="Plan the week")
        file = self.upload(self.me, plan)
        # An already deleted group is removed, not handed over, even with a member left on it.
        old = TaskGroup.objects.create(owner=self.leaver, name="Old group", is_deleted=True)
        GroupMembership.objects.create(group=old, user=self.ed, role="admin")
        old_project = TaskList.objects.create(owner=self.leaver, group=old, name="Old project", shared=True, is_deleted=True)

        preview = self.me.get(PATH).data
        self.assertEqual(preview["personal"], {"tasks": 1, "notes": 0, "files": 1, "projects": 1, "groups": 1})
        self.assertEqual(preview["handovers"], [])

        # TaskGroup.owner and TaskList.group are PROTECT; neither may stop the deletion.
        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        self.assertFalse(TaskGroup.objects.filter(pk__in=[solo.pk, old.pk]).exists())
        self.assertFalse(TaskList.objects.filter(pk__in=[plans.pk, old_project.pk]).exists())
        self.assertFalse(Task.objects.filter(pk=plan["id"]).exists())
        self.assertFalse(self.stored(file))
        self.assertFalse(GroupMembership.objects.filter(user=self.ed).exists())

    def test_a_project_in_someone_elses_group_goes_to_that_groups_owner(self):
        group = TaskGroup.objects.create(owner=self.otto, name="Otto's class")
        GroupMembership.objects.create(group=group, user=self.leaver, role="admin")
        GroupMembership.objects.create(group=group, user=self.ed, role="editor")
        # A group's projects normally belong to its owner; an older row can still name the person.
        chemistry = TaskList.objects.create(owner=self.leaver, group=group, name="Chemistry", shared=True)
        experiment = self.task(self.client_for(self.ed), chemistry, title="Experiment")

        preview = self.me.get(PATH).data
        self.assertEqual(preview["handovers"], [{"kind": "project", "id": str(chemistry.pk), "name": "Chemistry", "to": "Otto"}])

        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        chemistry.refresh_from_db()
        self.assertEqual((chemistry.owner_id, chemistry.is_deleted, chemistry.version), (self.otto.pk, False, 2))
        group.refresh_from_db()
        self.assertEqual(group.version, 2)
        self.assertEqual(list(group.memberships.values_list("user_id", flat=True)), [self.ed.pk])
        self.assertEqual(self.client_for(self.ed).get(f"/api/tasks/{experiment['id']}/").status_code, 200)

    def test_assigned_tasks_become_unassigned_and_activity_forgets_the_person(self):
        chores = TaskList.objects.create(owner=self.ed, name="Chores", shared=True)
        ListMembership.objects.create(task_list=chores, user=self.leaver, role="editor")
        ed = self.client_for(self.ed)
        dishes = self.task(ed, chores, title="Dishes", assignment="member", assignee_id=self.leaver.pk)
        edited = self.me.put(f"/api/tasks/{dishes['id']}/", {**dishes, "notes": "Eco mode"}, format="json")
        self.assertEqual(edited.status_code, 200, edited.data)
        task = Task.objects.get(pk=dishes["id"])
        # Details from an older or future client that name the person.
        TaskEvent.objects.create(task=task, version=task.version, action="updated", actor=self.ed, details={
            "fields": ["notes"], "note": "Asked Lena (LEAVER@example.invalid)", "by": {"user_id": self.leaver.pk}})

        self.assertEqual(self.confirm(password=PASSWORD).status_code, 204)

        task.refresh_from_db()
        self.assertEqual((task.assignment, task.assignee_id), ("unassigned", None))
        self.assertEqual(task.version, edited.data["version"] + 1)
        events = list(TaskEvent.objects.filter(task=task).order_by("id"))
        self.assertEqual([(event.action, event.actor_id) for event in events], [
            ("created", self.ed.pk), ("updated", None), ("updated", self.ed.pk), ("unassigned", None)])
        self.assertEqual(events[1].details, {"fields": ["notes"]})
        self.assertEqual(events[2].details, {"fields": ["notes"], "note": None, "by": {"user_id": None}})
        self.assertEqual(events[3].details, {"previous_assignee_id": None})
        text = json.dumps([event.details for event in events]).casefold()
        for trace in ("leaver@example.invalid", "lena"):
            self.assertNotIn(trace, text)
        history = ed.get(f"/api/tasks/{task.pk}/history/").data
        self.assertEqual(sorted(str(row["actor_name"]) for row in history), ["Ed", "Ed", "None", "None"])
        # The project's owner is told the task needs someone.
        self.assertTrue(TaskNotification.objects.filter(recipient=self.ed, event=events[3]).exists())

    def test_invitations_to_the_person_go_and_the_ones_they_sent_stay_valid(self):
        ed = self.client_for(self.ed)
        band = TaskGroup.objects.create(owner=self.ed, name="Ed's band")
        shopping = TaskList.objects.create(owner=self.ed, name="Shopping")
        for path, role in ((f"/api/groups/{band.pk}/invite/", "editor"), (f"/api/lists/{shopping.pk}/invite/", "viewer")):
            invited = ed.post(path, {"email": self.leaver.email, "role": role}, format="json")
            self.assertEqual(invited.status_code, 201, invited.data)
        choir = TaskGroup.objects.create(owner=self.leaver, name="Choir")
        GroupMembership.objects.create(group=choir, user=self.ada, role="admin")
        garden = TaskList.objects.create(owner=self.leaver, name="Garden", shared=True)
        ListMembership.objects.create(task_list=garden, user=self.ed, role="editor")
        # Emails that couldn't go out yet, which still name their sender.
        with patch("core.group_views.deliver_email", return_value="pending"), \
                patch("core.email_delivery.deliver_email", return_value="pending"):
            to_choir = self.me.post(f"/api/groups/{choir.pk}/invite/", {"email": self.otto.email, "role": "viewer"}, format="json")
            to_garden = self.me.post(f"/api/lists/{garden.pk}/invite/", {"email": self.otto.email, "role": "editor"}, format="json")
        self.assertEqual((to_choir.status_code, to_garden.status_code), (201, 201))
        queued = EmailDelivery.objects.filter(recipient=self.otto.email)
        self.assertEqual(sorted(row.body.split(" invited")[0] for row in queued), ["Lena", self.leaver.email])

        self.assertEqual(self.confirm(password=PASSWORD).status_code, 204)

        self.assertFalse(GroupInvitation.objects.filter(email=self.leaver.email).exists())
        self.assertFalse(ListInvitation.objects.filter(email=self.leaver.email).exists())
        self.assertFalse(EmailDelivery.objects.filter(recipient=self.leaver.email).exists())
        self.assertIsNone(GroupInvitation.objects.get(pk=to_choir.data["id"]).invited_by_id)
        bodies = list(queued.values_list("body", flat=True))
        self.assertEqual(len(bodies), 2)
        for body in bodies:
            self.assertTrue(body.startswith("Someone invited you to join "), body)
            self.assertNotIn("Lena", body)
            self.assertNotIn(self.leaver.email, body)
        otto = self.client_for(self.otto)
        for path, invitation in (("/api/group-invitations/", to_choir.data), ("/api/invitations/", to_garden.data)):
            accepted = otto.post(f"{path}{invitation['id']}/respond/", {"decision": "accept", "code": invitation["code"]}, format="json")
            self.assertEqual(accepted.status_code, 200, accepted.data)
        self.assertTrue(GroupMembership.objects.filter(group=choir, user=self.otto, role="viewer").exists())
        self.assertTrue(ListMembership.objects.filter(task_list=garden, user=self.otto, role="editor").exists())

    def test_a_wrong_password_or_no_confirmation_deletes_nothing(self):
        kept = self.task(self.me, title="Keep me")
        refused = self.delete(password="Not-my-password-2026")
        self.assertEqual((refused.status_code, refused.data["code"]), (400, "wrong_password"))
        for body in ({}, {"password": ""}):
            refused = self.delete(**body)
            self.assertEqual((refused.status_code, refused.data["code"]), (400, "reauth_required"))
        # No Google account is linked, so a Google token can't confirm.
        with patch("core.account_deletion.verify_google_identity") as verify:
            refused = self.delete(google_id_token="synthetic-token")
        self.assertEqual((refused.status_code, refused.data["code"]), (400, "google_reauth_failed"))
        verify.assert_not_called()
        self.assertTrue(Task.objects.filter(pk=kept["id"]).exists())
        # Like sign-in, five wrong passwords lock it for 15 minutes, even for the right one.
        for _ in range(4):
            self.assertEqual(self.delete(password="Still-not-it-2026").data["code"], "wrong_password")
        locked = self.delete(password=PASSWORD)
        self.assertEqual((locked.status_code, locked["Retry-After"]), (429, "900"))
        self.assertEqual(DeleteAccountView.throttle_scope, "auth")  # And sign-in's burst throttle.
        self.assertTrue(User.objects.filter(pk=self.leaver.pk).exists())
        self.assertEqual(self.me.get("/api/tasks/").data["count"], 1)

    def test_the_password_comes_first_and_the_plan_is_required(self):
        kept = self.task(self.me, title="Keep me")
        refused = self.delete(password="Not-my-password-2026", plan="0" * 64)  # A stale plan, too.
        self.assertEqual((refused.status_code, refused.data["code"]), (400, "wrong_password"))
        for body in ({}, {"plan": ""}, {"plan": 7}):
            refused = self.delete(password=PASSWORD, **body)
            self.assertEqual((refused.status_code, refused.data["code"]), (400, "plan_required"), body)
        self.assertTrue(User.objects.filter(pk=self.leaver.pk).exists())
        self.assertTrue(Task.objects.filter(pk=kept["id"]).exists())

    def test_a_handover_that_changed_after_the_preview_needs_a_new_confirmation(self):
        trip = TaskList.objects.create(owner=self.leaver, name="Trip", shared=True)
        ListMembership.objects.create(task_list=trip, user=self.ed, role="editor")
        ListMembership.objects.create(task_list=trip, user=self.vic, role="viewer")
        train = self.task(self.me, trip, title="Book the train")
        shown = self.me.get(PATH).data
        self.assertEqual(shown["handovers"][0]["to"], "Ed")
        # The heir leaves before the person confirms.
        self.assertEqual(self.client_for(self.ed).post(f"/api/lists/{trip.pk}/leave/").status_code, 204)

        stale = self.delete(password=PASSWORD, plan=shown["plan"])

        self.assertEqual((stale.status_code, stale.data["code"]), (409, "plan_changed"))
        self.assertTrue(User.objects.filter(pk=self.leaver.pk).exists())
        trip.refresh_from_db()
        self.assertEqual(trip.owner_id, self.leaver.pk)
        self.assertTrue(trip.memberships.filter(user=self.vic).exists())
        self.assertEqual(Task.objects.get(pk=train["id"]).owner_id, self.leaver.pk)
        # The new preview names the new heir, and confirming what it shows deletes.
        shown = self.me.get(PATH).data
        self.assertEqual(shown["handovers"], [{"kind": "project", "id": str(trip.pk), "name": "Trip", "to": "Vic"}])
        self.assertEqual(self.delete(password=PASSWORD, plan=shown["plan"]).status_code, 204)
        trip.refresh_from_db()
        self.assertEqual(trip.owner_id, self.vic.pk)

    def test_the_plan_is_who_receives_what_not_their_names(self):
        trip = TaskList.objects.create(owner=self.leaver, name="Trip", shared=True)
        ListMembership.objects.create(task_list=trip, user=self.ed, role="editor")
        shown = self.me.get(PATH).data
        self.assertRegex(shown["plan"], r"^[0-9a-f]{64}$")
        User.objects.filter(pk=self.ed.pk).update(first_name="Edward")
        TaskList.objects.filter(pk=trip.pk).update(name="Summer trip")
        renamed = self.me.get(PATH).data
        self.assertEqual(renamed["handovers"][0]["to"], "Edward")
        self.assertEqual(renamed["plan"], shown["plan"])
        self.assertEqual(self.delete(password=PASSWORD, plan=shown["plan"]).status_code, 204)
        self.assertEqual(TaskList.objects.get(pk=trip.pk).owner_id, self.ed.pk)

    def test_a_google_account_confirms_with_its_own_google_identity(self):
        person = User.objects.create_user("google-leaver@example.invalid", first_name="Gina")
        GoogleIdentity.objects.create(user=person, subject="google-subject-gina")
        client = self.client_for(person)
        self.assertEqual(client.get(PATH).data["reauth"], "google")
        self.assertEqual(self.me.get(PATH).data["reauth"], "password")
        verifier = "core.account_deletion.verify_google_identity"
        with patch(verifier, return_value=("google-subject-someone-else", "someone@example.invalid")) as verify:
            refused = self.delete(client, google_id_token="fresh-token")
        self.assertEqual((refused.status_code, refused.data["code"]), (400, "google_reauth_failed"))
        verify.assert_called_once_with("fresh-token")
        invalid = AuthenticationFailed({"detail": "Google identity could not be verified.", "code": "google_invalid_token"})
        with patch(verifier, side_effect=invalid):
            refused = self.delete(client, google_id_token="expired-token")
        self.assertEqual((refused.status_code, refused.data["code"]), (400, "google_reauth_failed"))
        self.assertEqual(self.delete(client, password="Any-password-2026").data["code"], "wrong_password")
        self.assertTrue(User.objects.filter(pk=person.pk).exists())
        with patch(verifier, return_value=("google-subject-gina", person.email)):
            self.assertEqual(self.confirm(client, google_id_token="fresh-token").status_code, 204)
        self.assertFalse(User.objects.filter(pk=person.pk).exists())
        self.assertFalse(GoogleIdentity.objects.exists())

    def test_the_preview_matches_what_the_deletion_does(self):
        ed = self.client_for(self.ed)
        # Personal, plus a task deleted earlier, which goes but isn't counted.
        dentist = self.task(self.me, title="Dentist")
        self.upload(self.me, dentist)
        self.task(self.me, title="Gate code", kind="note")
        Task.objects.create(owner=self.leaver, title="Deleted earlier", is_deleted=True)
        home = TaskList.objects.create(owner=self.leaver, name="Home")
        self.task(self.me, home, title="Paint the door")
        solo = TaskGroup.objects.create(owner=self.leaver, name="Just me")
        plans = TaskList.objects.create(owner=self.leaver, group=solo, name="Plans", shared=True)
        self.upload(self.me, self.task(self.me, plans, title="Plan", kind="note"))
        # Shared: a project and a group that are handed over, and someone else's project.
        trip = TaskList.objects.create(owner=self.leaver, name="Trip", shared=True)
        ListMembership.objects.create(task_list=trip, user=self.ed, role="editor")
        self.task(self.me, trip, title="Book the train")
        self.task(ed, trip, title="Pack")
        choir = TaskGroup.objects.create(owner=self.leaver, name="Choir")
        GroupMembership.objects.create(group=choir, user=self.eve, role="viewer")
        songs = TaskList.objects.create(owner=self.leaver, group=choir, name="Songs", shared=True)
        self.task(self.me, songs, title="Lyrics", kind="note")
        maths = TaskList.objects.create(owner=self.ed, name="Maths", shared=True)
        ListMembership.objects.create(task_list=maths, user=self.leaver, role="editor")
        self.upload(self.me, self.task(self.me, maths, title="Exercise"))
        Task.objects.create(owner=self.leaver, task_list=maths, title="Removed earlier", is_deleted=True)
        live_tasks = dict(Task.objects.filter(is_deleted=False).values_list("pk", "kind"))
        live_files = set(Attachment.objects.filter(is_deleted=False).values_list("pk", flat=True))
        live_projects = set(TaskList.objects.filter(is_deleted=False).values_list("pk", flat=True))
        live_groups = set(TaskGroup.objects.filter(is_deleted=False).values_list("pk", flat=True))
        mine_in_projects = set(Task.objects.filter(owner=self.leaver, is_deleted=False, task_list__isnull=False)
                               .values_list("pk", flat=True))

        preview = self.me.get(PATH).data
        self.assertEqual(preview["personal"], {"tasks": 2, "notes": 2, "files": 2, "projects": 2, "groups": 1})
        self.assertEqual(preview["kept_in_shared"], 3)
        self.assertEqual([(row["kind"], row["name"], row["to"]) for row in preview["handovers"]],
                         [("group", "Choir", "Eve"), ("project", "Trip", "Ed")])
        self.assertEqual((preview["pro"], preview["reauth"]), (False, "password"))

        self.assertEqual(self.delete(password=PASSWORD, plan=preview["plan"]).status_code, 204)

        gone = [kind for pk, kind in live_tasks.items() if not Task.objects.filter(pk=pk).exists()]
        self.assertEqual((gone.count("task"), gone.count("note")), (preview["personal"]["tasks"], preview["personal"]["notes"]))
        self.assertEqual(len(live_files - set(Attachment.objects.values_list("pk", flat=True))), preview["personal"]["files"])
        self.assertEqual(len(live_projects - set(TaskList.objects.values_list("pk", flat=True))), preview["personal"]["projects"])
        self.assertEqual(len(live_groups - set(TaskGroup.objects.values_list("pk", flat=True))), preview["personal"]["groups"])
        kept = Task.objects.filter(pk__in=mine_in_projects)
        self.assertEqual(kept.count(), preview["kept_in_shared"])
        self.assertEqual(set(kept.values_list("owner_id", flat=True)), {self.ed.pk, self.eve.pk})
        for row in preview["handovers"]:
            model = TaskGroup if row["kind"] == "group" else TaskList
            self.assertEqual(display_name(model.objects.get(pk=row["id"]).owner), row["to"])
        self.assertEqual(TaskList.objects.get(pk=songs.pk).owner_id, self.eve.pk)  # It went with its group.

    def test_the_preview_shows_pro_unless_the_account_surely_has_none(self):
        self.assertEqual(APIClient().get(PATH).status_code, 401)
        # None: the store can't be reached. The subscription note is harmless without Pro.
        for answer, shown in ((True, True), (False, False), (None, True)):
            with patch("core.account_deletion.has_pro", return_value=answer):
                preview = self.me.get(PATH)
            self.assertEqual((preview.status_code, preview.data["pro"]), (200, shown), answer)
        with patch("core.account_deletion.has_pro", side_effect=ValueError("synthetic billing failure")):
            preview = self.me.get(PATH)
        self.assertEqual((preview.status_code, preview.data["pro"]), (200, True))
        self.assertEqual(set(preview.data), {"personal", "kept_in_shared", "kept_files_in_shared", "handovers", "plan", "pro", "reauth"})

    def test_a_storage_error_still_deletes_the_account(self):
        scan = self.upload(self.me, self.task(self.me, title="Scan"))
        # Not an OSError: object storage clients raise their own errors.
        outage = RuntimeError("synthetic storage outage")
        with patch("django.core.files.storage.FileSystemStorage.delete", side_effect=outage), \
                self.assertLogs("core.account_deletion", level="ERROR") as logs:
            response = self.confirm(password=PASSWORD)
        self.assertEqual(response.status_code, 204)
        self.assertFalse(User.objects.filter(email=self.leaver.email).exists())
        self.assertEqual([record.levelname for record in logs.records], ["ERROR"])
        message = logs.records[0].getMessage()
        self.assertIn(scan.file.name, message)
        for private in (self.leaver.email, "Lena", "leaver"):
            self.assertNotIn(private, message)
        self.assertTrue(self.stored(scan))  # Left in storage; the log names it for cleanup.
