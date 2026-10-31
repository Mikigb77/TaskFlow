from unittest.mock import patch

from django.test import TestCase, override_settings

from .account_deletion import PlanChanged, delete_account
from .models import User

PASSWORD = "Billing-deletion-passphrase!2026"
KEY = "sk_synthetic_test_key"


class FakeResponse:
    def __init__(self, status):
        self.status = status

    def read(self, limit):
        return b"{}"


@override_settings(REVENUECAT_API_KEY=KEY)
class RevenueCatCustomerDeletionTests(TestCase):
    """Deleting an account deletes its RevenueCat customer too, best effort (2026-10-18)."""

    def setUp(self):
        self.user = User.objects.create_user("leaving@example.invalid", PASSWORD)
        self.connection = self.enterContext(patch("core.billing.http.client.HTTPSConnection"))

    def answer(self, status):
        self.connection.return_value.getresponse.return_value = FakeResponse(status)

    def test_the_customer_is_deleted_after_the_account_commits(self):
        self.answer(200)
        billing_id = self.user.billing_id
        with self.captureOnCommitCallbacks(execute=False) as callbacks:
            self.assertTrue(delete_account(self.user))
        self.connection.assert_not_called()  # nothing before the commit
        for callback in callbacks:
            callback()
        self.connection.assert_called_once_with("api.revenuecat.com", timeout=6)
        method, path = self.connection.return_value.request.call_args.args
        headers = self.connection.return_value.request.call_args.kwargs["headers"]
        self.assertEqual((method, path), ("DELETE", f"/v1/subscribers/{billing_id}"))
        self.assertEqual(headers["Authorization"], f"Bearer {KEY}")
        self.assertFalse(User.objects.filter(pk=self.user.pk).exists())

    def test_a_customer_revenuecat_never_had_is_fine(self):
        self.answer(404)
        with self.assertNoLogs("core.account_deletion", level="WARNING"):
            with self.captureOnCommitCallbacks(execute=True):
                delete_account(self.user)

    def test_a_provider_failure_never_undoes_the_deletion_and_logs_no_id(self):
        for failure in (FakeResponse(500), OSError("unreachable")):
            with self.subTest(failure=type(failure).__name__):
                user = User.objects.create_user(f"{type(failure).__name__}@example.invalid", PASSWORD)
                if isinstance(failure, OSError):
                    self.connection.return_value.request.side_effect = failure
                else:
                    self.connection.return_value.request.side_effect = None
                    self.connection.return_value.getresponse.return_value = failure
                with self.assertLogs("core.account_deletion", level="WARNING") as logs:
                    with self.captureOnCommitCallbacks(execute=True):
                        self.assertTrue(delete_account(user))
                self.assertFalse(User.objects.filter(pk=user.pk).exists())
                self.assertNotIn(str(user.billing_id), "\n".join(logs.output))

    def test_a_refused_deletion_never_reaches_revenuecat(self):
        with self.captureOnCommitCallbacks(execute=True):
            with self.assertRaises(PlanChanged):
                delete_account(self.user, expected_plan="a plan that no longer matches")
        self.connection.assert_not_called()
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    @override_settings(REVENUECAT_API_KEY="")
    def test_without_billing_configured_nothing_is_called_or_logged(self):
        with self.assertNoLogs("core.account_deletion", level="WARNING"):
            with self.captureOnCommitCallbacks(execute=True):
                delete_account(self.user)
        self.connection.assert_not_called()
