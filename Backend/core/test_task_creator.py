"""A task's creator («Creada por»): Task.created_by, the API's created_by and created_by_name."""
import importlib
import uuid
from types import SimpleNamespace

from django.apps import apps
from django.core.cache import cache
from django.db import connection
from django.test import TestCase
from rest_framework.test import APIClient

from .models import ListMembership, Task, TaskEvent, TaskList, User

PASSWORD = "Creator-fixture-2026!"
DELETE = "/api/auth/delete-account/"


class TaskCreatorTests(TestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user("creator-owner@example.invalid", PASSWORD, first_name="Olga")
        self.ana = User.objects.create_user("creator-ana@example.invalid", PASSWORD, first_name="Ana")
        self.ed = User.objects.create_user("creator-ed@example.invalid", PASSWORD, first_name="Ed")
        self.maths = TaskList.objects.create(owner=self.owner, name="Matemáticas", shared=True)
        for person in (self.ana, self.ed):
            ListMembership.objects.create(task_list=self.maths, user=person, role="editor")

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def create(self, user, project=None, **fields):
        body = {"title": "Synthetic task", "version": 0, **fields}
        if project is not None:
            body["list_id"] = str(project.pk)
        response = self.client_for(user).put(f"/api/tasks/{uuid.uuid4()}/", body, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def seen_by(self, user, task_id):
        response = self.client_for(user).get(f"/api/tasks/{task_id}/")
        self.assertEqual(response.status_code, 200, response.data)
        return response.data

    def delete_account(self, user):
        client = self.client_for(user)
        with self.captureOnCommitCallbacks(execute=True):
            response = client.post(DELETE, {"password": PASSWORD, "plan": client.get(DELETE).data["plan"]}, format="json")
        self.assertEqual(response.status_code, 204, getattr(response, "data", None))

    def test_the_creator_is_whoever_created_it_and_never_changes(self):
        created = self.create(self.ana, self.maths, notes="Ejercicios 1 a 5")
        self.assertEqual((created["created_by"], created["created_by_name"]), (self.ana.pk, "Ana"))
        for person in (self.owner, self.ed):
            seen = self.seen_by(person, created["id"])
            self.assertEqual((seen["created_by"], seen["created_by_name"]), (self.ana.pk, "Ana"))
        edited = self.client_for(self.owner).put(f"/api/tasks/{created['id']}/", {**created, "title": "Repasar"},
                                                 format="json")
        self.assertEqual(edited.status_code, 200, edited.data)
        self.assertEqual((edited.data["created_by"], edited.data["created_by_name"]), (self.ana.pk, "Ana"))
        # The app can't set it.
        forged = self.client_for(self.ed).put(f"/api/tasks/{created['id']}/",
                                              {**edited.data, "created_by": self.ed.pk, "created_by_name": "Ed"},
                                              format="json")
        self.assertEqual((forged.data["created_by"], forged.data["created_by_name"]), (self.ana.pk, "Ana"))
        self.assertEqual(Task.objects.get(pk=created["id"]).owner_id, self.ana.pk)
        personal = self.create(self.ed)
        self.assertEqual((personal["created_by"], personal["created_by_name"]), (self.ed.pk, "Ed"))

    def test_a_kept_task_never_shows_the_projects_owner_as_its_creator(self):
        mine = self.create(self.ana, self.maths, title="Ejercicio 3")
        theirs = self.create(self.ed, self.maths, title="Ejercicio 4")
        owners = self.create(self.owner, self.maths, title="Corregir")

        self.delete_account(self.ana)

        kept = Task.objects.get(pk=mine["id"])
        self.assertEqual((kept.owner_id, kept.created_by_id, kept.version), (self.owner.pk, None, mine["version"] + 1))
        for person in (self.owner, self.ed):
            seen = self.seen_by(person, mine["id"])
            self.assertEqual((seen["created_by"], seen["created_by_name"]), (None, None))
        self.assertEqual(self.seen_by(self.owner, theirs["id"])["created_by_name"], "Ed")
        self.assertEqual(self.seen_by(self.ed, owners["id"])["created_by"], self.owner.pk)

    def test_a_handed_over_project_keeps_its_other_creators(self):
        trip = TaskList.objects.create(owner=self.ana, name="Viaje", shared=True)
        ListMembership.objects.create(task_list=trip, user=self.ed, role="editor")
        tickets = self.create(self.ana, trip, title="Comprar los billetes")
        packing = self.create(self.ed, trip, title="Hacer la maleta")

        self.delete_account(self.ana)

        trip.refresh_from_db()
        self.assertEqual(trip.owner_id, self.ed.pk)
        seen = self.seen_by(self.ed, tickets["id"])
        self.assertEqual((seen["created_by"], seen["created_by_name"]), (None, None))  # Not Ed, the new owner.
        self.assertEqual(Task.objects.get(pk=tickets["id"]).owner_id, self.ed.pk)
        self.assertEqual(self.seen_by(self.ed, packing["id"])["created_by"], self.ed.pk)

    def test_any_other_task_naming_the_person_as_creator_loses_it_and_syncs(self):
        # Not possible through the API today, where whoever creates a task owns it.
        odd = Task.objects.create(owner=self.owner, created_by=self.ana, task_list=self.maths, title="Imported")
        self.delete_account(self.ana)
        odd.refresh_from_db()
        self.assertEqual((odd.created_by_id, odd.version, odd.owner_id), (None, 2, self.owner.pk))

    def test_every_creation_path_records_a_creator(self):
        direct = Task.objects.create(owner=self.ed, title="Created directly")
        self.assertEqual(direct.created_by_id, self.ed.pk)
        explicit = Task.objects.create(owner=self.owner, created_by=self.ana, title="Kept as given")
        self.assertEqual(explicit.created_by_id, self.ana.pk)

    def test_the_migration_gives_existing_tasks_their_owner_unless_the_creator_was_deleted(self):
        migration = importlib.import_module("core.migrations.0021_task_created_by")
        ordinary = Task.objects.create(owner=self.ana, task_list=self.maths, title="Ordinary")
        TaskEvent.objects.create(task=ordinary, version=1, action="created", actor=self.ana)
        handed_over = Task.objects.create(owner=self.owner, task_list=self.maths, title="Created by a deleted account")
        TaskEvent.objects.create(task=handed_over, version=2, action="created", actor=None)
        older = Task.objects.create(owner=self.ed, title="From before activity existed")
        Task.objects.update(created_by=None)

        migration.creators_of_existing_tasks(apps, SimpleNamespace(connection=connection))

        self.assertEqual(Task.objects.get(pk=ordinary.pk).created_by_id, self.ana.pk)
        self.assertIsNone(Task.objects.get(pk=handed_over.pk).created_by_id)
        self.assertEqual(Task.objects.get(pk=older.pk).created_by_id, self.ed.pk)
