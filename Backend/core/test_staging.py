from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from types import SimpleNamespace
from unittest.mock import patch

from django.contrib.auth.models import AnonymousUser
from django.core import mail
from django.core.cache import cache
from django.db import close_old_connections, connections
from django.test import TestCase, TransactionTestCase, override_settings, skipUnlessDBFeature
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, Throttled
from rest_framework.test import APIClient, APIRequestFactory
from rest_framework.settings import api_settings

from .email_delivery import deliver_email, email_html, reserve_email
from .models import EmailDelivery, GroupInvitation, RuntimeState, TaskGroup, User
from .runtime_state import AtomicScopedThrottle, PostgresCache
from .staging import ensure_registration_allowed


class StagingTests(TestCase):
    def setUp(self):
        cache.clear()

    @override_settings(DEPLOYMENT_ENVIRONMENT="staging")
    def test_liveness_and_invitation_pages_do_not_wake_database(self):
        with self.assertNumQueries(0):
            self.assertEqual(self.client.get('/api/live/').json()['environment'], 'staging')
            page = self.client.get('/invite/')
            self.assertEqual(page.status_code, 200)
            self.assertEqual(page['Referrer-Policy'], 'no-referrer')
            self.assertIn("default-src 'none'", page['Content-Security-Policy'])
            self.assertContains(page, 'taskflow-staging://invite')
            self.assertContains(self.client.get('/download/'), 'no public download')
            self.assertEqual(self.client.get('/').status_code, 404)

    @override_settings(DEPLOYMENT_ENVIRONMENT='staging', STAGING_ALLOWED_EMAILS={'owner@example.invalid'})
    def test_staging_registration_requires_allowlist_or_live_invitation(self):
        ensure_registration_allowed('OWNER@example.invalid')
        with self.assertRaises(PermissionDenied):
            ensure_registration_allowed('outsider@example.invalid')
        owner = User.objects.create_user('owner@example.invalid', 'Fixture-password!2026')
        group = TaskGroup.objects.create(owner=owner, name='Staging group')
        invitation = GroupInvitation.objects.create(group=group, email='invited@example.invalid',
            role='editor', code_digest='fixture', expires_at=timezone.now()+timedelta(days=1))
        ensure_registration_allowed(invitation.email)
        invitation.state = 'revoked'
        invitation.save()
        with self.assertRaises(PermissionDenied):
            ensure_registration_allowed(invitation.email)
        response = APIClient().post('/api/auth/register/', {
            'email':'outsider@example.invalid', 'password':'Fixture-password!2026'}, format='json')
        self.assertEqual(response.status_code, 403)
        self.assertFalse(User.objects.filter(email='outsider@example.invalid').exists())

    def message(self):
        return EmailDelivery.objects.create(recipient='tester@example.invalid', subject='Test invitation',
            body='Private code and link', expires_at=timezone.now()+timedelta(hours=1))

    def test_delivery_is_idempotent_and_scrubs_sent_codes(self):
        row = self.message()
        self.assertEqual(deliver_email(row.pk), 'sent')
        self.assertEqual(deliver_email(row.pk), 'sent')
        self.assertEqual(len(mail.outbox), 1)
        row.refresh_from_db()
        self.assertEqual(row.body, '')
        self.assertEqual(row.attempts, 1)

    @override_settings(EMAIL_BACKEND='core.email_delivery.ResendBackend', RESEND_API_KEY='fixture-only')
    @patch('core.email_delivery.httpx.Client')
    def test_failed_provider_request_retries_with_same_idempotency_key(self, provider):
        provider.return_value.__enter__.return_value.post.side_effect = RuntimeError('network failed')
        row = self.message()
        self.assertEqual(deliver_email(row.pk), 'pending')
        row.refresh_from_db()
        self.assertTrue(row.body)
        # The lease prevents another request worker immediately retrying it.
        self.assertEqual(deliver_email(row.pk), 'pending')
        self.assertEqual(provider.return_value.__enter__.return_value.post.call_count, 1)
        EmailDelivery.objects.filter(pk=row.pk).update(next_attempt_at=timezone.now()-timedelta(seconds=1))
        provider.return_value.__enter__.return_value.post.side_effect = None
        self.assertEqual(deliver_email(row.pk), 'sent')
        calls = provider.return_value.__enter__.return_value.post.call_args_list
        self.assertEqual(calls[0].kwargs['headers']['Idempotency-Key'], calls[1].kwargs['headers']['Idempotency-Key'])

    def test_expired_or_revoked_mail_never_sends(self):
        row = self.message()
        row.expires_at = timezone.now()-timedelta(seconds=1)
        row.save()
        self.assertEqual(deliver_email(row.pk), 'expired')
        row.refresh_from_db()
        self.assertEqual(row.body, '')
        self.assertFalse(mail.outbox)
        row.delete()
        self.assertEqual(deliver_email(row.pk), 'cancelled')

    def test_email_html_escapes_names_and_links_only_https(self):
        markup = email_html('<script>bad()</script>\n\nhttps://example.invalid/#secret\n\njavascript:bad()')
        self.assertNotIn('<script>', markup)
        self.assertIn('href="https://example.invalid/#secret"', markup)
        self.assertNotIn('href="javascript:', markup)

    def test_email_recipient_quota_and_recovery_do_not_disclose_account(self):
        for _ in range(8):
            reserve_email('tester@example.invalid')
        with self.assertRaises(Throttled):
            reserve_email('tester@example.invalid')
        User.objects.create_user('tester@example.invalid', 'Fixture-password!2026')
        client = APIClient()
        existing = client.post('/api/auth/password-reset/', {'email':'tester@example.invalid'})
        unknown = client.post('/api/auth/password-reset/', {'email':'unknown@example.invalid'})
        self.assertEqual(existing.status_code, unknown.status_code)
        self.assertEqual(existing.data, unknown.data)

    def test_shared_cache_expiry_and_missing_increment(self):
        shared = PostgresCache('staging', {})
        self.assertTrue(shared.add('budget', 1, 60))
        self.assertFalse(shared.add('budget', 9, 60))
        self.assertEqual(shared.incr('budget'), 2)
        RuntimeState.objects.update(expires_at=timezone.now()-timedelta(seconds=1))
        self.assertIsNone(shared.get('budget'))
        with self.assertRaises(ValueError):
            shared.incr('budget')
        self.assertTrue(shared.add('budget', 1, 60))


@skipUnlessDBFeature('has_select_for_update')
class StagingConcurrencyTests(TransactionTestCase):
    def race(self, operation, count=10):
        barrier = Barrier(count)
        def worker(index):
            close_old_connections()
            try:
                barrier.wait(timeout=15)
                return operation(index)
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=count) as pool:
            return list(pool.map(worker, range(count)))

    def test_shared_counter_has_one_initializer_and_no_lost_increments(self):
        shared = PostgresCache('staging', {})
        results = self.race(lambda _: shared.add('one', 0, 60))
        self.assertEqual(sum(results), 1)
        results = self.race(lambda _: shared.incr('one'))
        self.assertEqual(sorted(results), list(range(1, 11)))

    @patch.object(api_settings, 'NUM_PROXIES', 1)
    def test_rate_limit_is_atomic_across_workers_and_ignores_forwarded_prefix(self):
        def request(index):
            throttle = AtomicScopedThrottle()
            throttle.THROTTLE_RATES = {'fixture':'3/min'}
            req = APIRequestFactory().get('/', HTTP_X_FORWARDED_FOR=f'forged-{index}, verified-client')
            req.user = AnonymousUser()
            return throttle.allow_request(req, SimpleNamespace(throttle_scope='fixture'))
        self.assertEqual(sum(self.race(request)), 3)
