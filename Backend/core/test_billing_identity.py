import uuid

from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase
from rest_framework.test import APIClient

from .models import User
from .serializers import UserSerializer


class BillingIdentityTests(TestCase):
    def test_registration_login_and_me_return_the_same_opaque_identity(self):
        credentials = {"email": "billing@example.invalid", "password": "Unique-test-password-184!"}
        client = APIClient()
        registered = client.post("/api/auth/register/", credentials, format="json")
        self.assertEqual(registered.status_code, 201)
        billing_id = registered.data["user"]["billing_id"]
        self.assertEqual(uuid.UUID(billing_id).version, 4)
        logged_in = client.post("/api/auth/login/", credentials, format="json")
        self.assertEqual(logged_in.data["user"]["billing_id"], billing_id)
        client.credentials(HTTP_AUTHORIZATION="Bearer " + logged_in.data["access"])
        self.assertEqual(client.get("/api/auth/me/").data["billing_id"], billing_id)

    def test_different_accounts_have_distinct_ids_which_clients_cannot_change(self):
        first = User.objects.create_user("first@example.invalid")
        second = User.objects.create_user("second@example.invalid")
        self.assertNotEqual(first.billing_id, second.billing_id)
        serializer = UserSerializer(first, data={"billing_id": str(second.billing_id)}, partial=True)
        self.assertTrue(serializer.is_valid(), serializer.errors)
        serializer.save()
        original = first.billing_id
        first.refresh_from_db()
        self.assertEqual(first.billing_id, original)
        self.assertNotEqual(first.billing_id, second.billing_id)


class BillingIdentityMigrationTests(TransactionTestCase):
    def test_existing_accounts_get_distinct_ids_without_losing_profiles(self):
        before = [("core", "0012_standalone_notes")]
        after = [("core", "0013_user_billing_id")]
        executor = MigrationExecutor(connection)
        latest = executor.loader.graph.leaf_nodes()
        self.addCleanup(lambda: MigrationExecutor(connection).migrate(latest))
        executor.migrate(before)
        try:
            OldUser = executor.loader.project_state(before).apps.get_model("core", "User")
            ids = [OldUser.objects.create(email=f"migration-{i}@example.invalid", timezone="Europe/Madrid").pk for i in range(2)]
        finally:
            executor = MigrationExecutor(connection)
            executor.migrate(after)
        users = list(User.objects.filter(pk__in=ids).order_by("pk"))
        self.assertEqual(len({user.billing_id for user in users}), 2)
        self.assertTrue(all(user.billing_id.version == 4 for user in users))
        self.assertTrue(all(user.timezone == "Europe/Madrid" for user in users))
