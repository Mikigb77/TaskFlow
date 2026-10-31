from django.test import TestCase
from rest_framework.test import APIClient

from .models import ListMembership, TaskList, User

PASSWORD = "Profile-test-passphrase!2026"


class FirstNameTests(TestCase):
    """PATCH /api/auth/me/ sets the name people see in shared projects (D8, 2026-10-18)."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user("paul.smith84@example.invalid", PASSWORD)
        self.client.force_authenticate(self.user)

    def name(self, value):
        return self.client.patch("/api/auth/me/", {"first_name": value}, format="json")

    def test_the_name_is_set_tidied_and_returned(self):
        response = self.name("  Paul   Smith ")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["first_name"], "Paul Smith")
        self.assertEqual(User.objects.get(pk=self.user.pk).first_name, "Paul Smith")

    def test_people_in_a_shared_project_see_the_name_instead_of_the_email(self):
        owner = User.objects.create_user("ana@example.invalid", PASSWORD, first_name="Ana")
        project = TaskList.objects.create(owner=owner, name="Matemáticas", shared=True)
        ListMembership.objects.create(task_list=project, user=self.user, role="editor")
        viewer = APIClient()
        viewer.force_authenticate(owner)

        def names():
            lists = viewer.get("/api/lists/").data
            rows = lists["results"] if isinstance(lists, dict) else lists
            people = next(row for row in rows if row["id"] == str(project.id))["people"]
            return {person["name"] for person in people}

        self.assertEqual(names(), {"Ana", "paul.smith84"})
        self.name("Paul")
        self.assertEqual(names(), {"Ana", "Paul"})

    def test_blank_clears_the_name(self):
        self.name("Paul")
        response = self.name("   ")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(User.objects.get(pk=self.user.pk).first_name, "")

    def test_only_the_name_can_change_here(self):
        before = User.objects.get(pk=self.user.pk)
        for data in ({"email": "other@example.invalid"}, {"first_name": "Paul", "timezone": "Europe/Madrid"},
                     {"billing_id": "00000000-0000-0000-0000-000000000000"}, {}):
            with self.subTest(data=data):
                response = self.client.patch("/api/auth/me/", data, format="json")
                self.assertEqual(response.status_code, 400)
        after = User.objects.get(pk=self.user.pk)
        self.assertEqual((after.email, after.first_name, after.timezone, after.billing_id),
                         (before.email, before.first_name, before.timezone, before.billing_id))

    def test_a_name_longer_than_the_field_is_refused(self):
        self.assertEqual(self.name("x" * 151).status_code, 400)
        self.assertEqual(self.name("x" * 150).status_code, 200)

    def test_it_needs_a_session(self):
        anonymous = APIClient()
        response = anonymous.patch("/api/auth/me/", {"first_name": "Paul"}, format="json")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(User.objects.get(pk=self.user.pk).first_name, "")
