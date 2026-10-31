from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from .billing import complimentary_pro, subscription_access
from .models import FreeDictation, GoogleIdentity, User
from .serializers import UserSerializer


@override_settings(COMPLIMENTARY_PRO_EMAILS={"owner@example.invalid"},
                   COMPLIMENTARY_PRO_BILLING_IDS=set(), REVENUECAT_API_KEY="")
class ComplimentaryAccessTests(TestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user("owner@example.invalid", "Owner-test-password!42")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def test_email_match_alone_does_not_grant_access(self):
        self.assertFalse(complimentary_pro(self.owner))
        self.assertFalse(UserSerializer(self.owner).data["complimentary_pro"])

    @patch("core.billing._customer")
    def test_explicit_existing_account_grant_needs_both_email_and_id(self, customer):
        with override_settings(COMPLIMENTARY_PRO_BILLING_IDS={str(self.owner.billing_id)}):
            self.assertTrue(complimentary_pro(self.owner))
            response = self.client.get("/api/billing/access/")
            self.assertEqual(response.status_code, 200)
            self.assertTrue(response.data["active"])
            self.assertTrue(response.data["complimentary"])
            self.assertIsNone(response.data["expires_at"])
            self.owner.email = "someone-else@example.invalid"
            self.assertFalse(complimentary_pro(self.owner))
        customer.assert_not_called()

    @patch("core.billing._customer")
    @patch("core.views.ai.make_drafts", return_value={"tasks": []})
    def test_google_verified_owner_has_pro_without_store_or_receipt(self, ai, customer):
        GoogleIdentity.objects.create(user=self.owner, subject="verified-owner-subject")
        self.assertTrue(self.client.get("/api/auth/me/").data["complimentary_pro"])
        result = self.client.post("/api/ai/drafts/", {"text": "Prepare a presentation", "timezone": "UTC"}, format="json")
        self.assertEqual(result.status_code, 200)
        ai.assert_called_once()
        customer.assert_not_called()
        other = User.objects.create_user("other@example.invalid")
        GoogleIdentity.objects.create(user=other, subject="other-subject")
        self.assertFalse(complimentary_pro(other))

    @patch("core.billing._customer", return_value={"entitlements": {}})
    def test_revoking_allowlist_takes_effect_without_waiting_for_billing_cache(self, customer):
        GoogleIdentity.objects.create(user=self.owner, subject="verified-owner-subject")
        self.assertTrue(subscription_access(self.owner)["active"])
        with override_settings(COMPLIMENTARY_PRO_EMAILS=set(), REVENUECAT_API_KEY="goog_fixture"):
            self.assertFalse(subscription_access(self.owner)["active"])
        self.owner.is_active = False
        self.assertFalse(complimentary_pro(self.owner))

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer", return_value={"entitlements": {}})
    @patch("core.views.ai.make_drafts", return_value={"tasks": [{"title": "Task"}]})
    def test_clients_cannot_forge_grant_or_owner_identity(self, ai, customer):
        response = self.client.post("/api/ai/drafts/", {
            "text": "Task", "timezone": "UTC", "complimentary_pro": True,
            "billing_id": str(self.owner.billing_id), "email": "owner@example.invalid"}, format="json")
        # A forged grant spends a free dictation instead of getting Pro.
        self.assertEqual(response.status_code, 200)
        ai.assert_called_once()
        self.assertEqual(FreeDictation.objects.filter(user=self.owner, counted=True).count(), 1)
        self.assertEqual(response.data["free_voice"]["left"], response.data["free_voice"]["limit"] - 1)
        serializer = UserSerializer(self.owner, data={"complimentary_pro": True}, partial=True)
        self.assertTrue(serializer.is_valid())
        self.assertNotIn("complimentary_pro", serializer.validated_data)
        self.assertFalse(serializer.data["complimentary_pro"])

    @override_settings(DEPLOYMENT_ENVIRONMENT="staging", STAGING_ALLOWED_EMAILS={"owner@example.invalid"})
    def test_password_registration_cannot_claim_owner_pro(self):
        self.owner.delete()
        response = APIClient().post("/api/auth/register/", {
            "email": "owner@example.invalid", "password": "Unique-password-7492!",
            "complimentary_pro": True}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertFalse(response.data["user"]["complimentary_pro"])
