from copy import deepcopy
from datetime import timedelta
from unittest.mock import patch, MagicMock

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .billing import subscription_access, BillingUnavailable, _customer
from .models import User, Task


@override_settings(REVENUECAT_API_KEY="goog_fixture", DEPLOYMENT_ENVIRONMENT="production", REVENUECAT_ALLOW_SANDBOX=False)
class BillingAccessTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(email="billing@example.invalid", password="Synthetic-test-password-42!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.now = timezone.now()
        self.expires = self.now + timedelta(hours=1)
        self.customer = {
            "entitlements": {"taskflow_pro": {"product_identifier": "monthly", "expires_date": self.expires.isoformat(), "grace_period_expires_date": None}},
            "subscriptions": {"monthly": {"is_sandbox": False, "expires_date": self.expires.isoformat(), "refunded_at": None}},
        }

    @patch("core.billing._customer")
    @patch("core.views.ai.make_drafts")
    @patch("core.views.consume_budget")
    def test_unpaid_cannot_forge_access_or_spend_budget(self, budget, ai, customer):
        customer.return_value = {"entitlements": {}}
        for path in ("/api/ai/draft/", "/api/ai/drafts/"):
            result = self.client.post(path, {"text": "Finish physics Thursday", "timezone": "UTC",
                "billing_id": "another-paying-customer", "has_pro": True, "entitlements": {"taskflow_pro": True}}, format="json")
            self.assertEqual(result.status_code, 402)
        budget.assert_not_called()
        ai.assert_not_called()
        customer.assert_called_once_with(self.user.billing_id)
        self.assertEqual(Task.objects.count(), 0)

    @patch("core.billing._customer")
    @patch("core.views.ai.make_drafts", return_value={"tasks": []})
    def test_active_subscription_allows_drafts_without_saving(self, ai, customer):
        customer.return_value = self.customer
        result = self.client.post("/api/ai/drafts/", {"text": "Finish physics Thursday", "timezone": "UTC"}, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        ai.assert_called_once()
        self.assertEqual(Task.objects.count(), 0)

    @patch("core.billing._customer")
    def test_current_entitlement_and_grace_control_access(self, customer):
        for expires, grace, expected in [
            (self.now - timedelta(seconds=1), None, False),
            (self.now - timedelta(days=1), self.expires, True),
            (self.expires, None, True),
        ]:
            data = deepcopy(self.customer)
            data["entitlements"]["taskflow_pro"].update(expires_date=expires.isoformat(), grace_period_expires_date=grace.isoformat() if grace else None)
            customer.return_value = data
            self.assertEqual(subscription_access(self.user, refresh=True)["active"], expected)

    @patch("core.billing._customer")
    def test_refund_revokes_even_an_unexpired_entitlement(self, customer):
        self.customer["subscriptions"]["monthly"]["refunded_at"] = self.now.isoformat()
        customer.return_value = self.customer
        self.assertFalse(subscription_access(self.user)["active"])

    @patch("core.billing._customer")
    def test_sandbox_requires_explicit_development_configuration(self, customer):
        self.customer["subscriptions"]["monthly"]["is_sandbox"] = True
        customer.return_value = self.customer
        self.assertFalse(subscription_access(self.user)["active"])
        with override_settings(REVENUECAT_ALLOW_SANDBOX=True):
            self.assertFalse(subscription_access(self.user, refresh=True)["active"])
            with override_settings(DEPLOYMENT_ENVIRONMENT="development"):
                result = subscription_access(self.user)
                self.assertTrue(result["active"])
                self.assertTrue(result["sandbox"])

    @override_settings(REVENUECAT_API_KEY="test_fixture", REVENUECAT_ALLOW_SANDBOX=True)
    @patch("core.billing._customer")
    def test_production_rejects_test_keys_before_contacting_provider(self, customer):
        with self.assertRaises(BillingUnavailable):
            subscription_access(self.user)
        customer.assert_not_called()

    @patch("core.billing._customer")
    def test_malformed_provider_data_fails_closed(self, customer):
        for value in ("yesterday", "2026-10-11T00:00:00", {}, 123):
            data = deepcopy(self.customer)
            data["entitlements"]["taskflow_pro"]["expires_date"] = value
            customer.return_value = data
            with self.assertRaises(BillingUnavailable):
                subscription_access(self.user, refresh=True)

    @patch("core.billing._customer")
    def test_cached_grant_is_never_used_after_its_expiration(self, customer):
        self.customer["entitlements"]["taskflow_pro"]["expires_date"] = (self.now + timedelta(seconds=15)).isoformat()
        customer.return_value = self.customer
        with patch("core.billing.timezone.now", return_value=self.now):
            self.assertTrue(subscription_access(self.user)["active"])
        with patch("core.billing.timezone.now", return_value=self.now + timedelta(seconds=16)):
            self.assertFalse(subscription_access(self.user)["active"])
        self.assertEqual(customer.call_count, 2)

    @patch("core.billing._customer")
    def test_refresh_observes_purchase_and_refund_and_ignores_body_identity(self, customer):
        customer.return_value = {"entitlements": {}}
        self.assertFalse(self.client.get("/api/billing/access/").data["active"])
        customer.return_value = self.customer
        response = self.client.post("/api/billing/access/", {"billing_id": "someone-else"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["active"])
        self.customer["subscriptions"]["monthly"]["refunded_at"] = self.now.isoformat()
        self.assertFalse(self.client.post("/api/billing/access/", {}, format="json").data["active"])
        self.assertTrue(all(call.args == (self.user.billing_id,) for call in customer.call_args_list))

    @patch("core.billing._customer", side_effect=BillingUnavailable())
    @patch("core.views.ai.make_drafts")
    def test_outage_does_not_process_voice_or_expose_provider_details(self, ai, customer):
        response = self.client.post("/api/ai/drafts/", {"text": "Test task", "timezone": "UTC"}, format="json")
        self.assertEqual(response.status_code, 503)
        ai.assert_not_called()
        self.assertNotIn("goog_fixture", str(response.data))

    def test_billing_status_requires_authentication(self):
        self.assertEqual(APIClient().get("/api/billing/access/").status_code, 401)

    @patch("core.billing.http.client.HTTPSConnection")
    def test_http_destination_is_fixed_and_redirects_are_rejected(self, connect):
        response = MagicMock(status=302)
        response.read.return_value = b'{}'
        connect.return_value.getresponse.return_value = response
        with self.assertRaises(BillingUnavailable):
            _customer(self.user.billing_id)
        connect.assert_called_once_with("api.revenuecat.com", timeout=6)
        connect.return_value.close.assert_called_once()
