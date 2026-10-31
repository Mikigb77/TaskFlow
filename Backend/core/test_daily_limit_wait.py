"""Retry-After on the dictation endpoints' 429s says how long the wait really is (UX-1307).

The app reads it: 120 seconds or less is "wait a minute", longer is today's limit, and none
is the assistant being unavailable (docs/VOICE_COMMANDS.md, "Errors")."""
from datetime import datetime, timezone as utc_zone
from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from rest_framework.test import APIClient

from .ai import AIUnavailable
from .models import User
from .views import seconds_until_next_day

PAYLOAD = {"text": "Llamar al dentista mañana", "timezone": "Europe/Madrid"}


def at(*moment):
    """Every clock in the request reads this UTC time."""
    return patch("core.views.timezone.now", return_value=datetime(*moment, tzinfo=utc_zone.utc))


class SecondsUntilNextDayTests(SimpleTestCase):
    def test_until_the_next_utc_midnight_and_never_zero(self):
        for moment, seconds in (((2026, 10, 20, 21, 30), 9000), ((2026, 10, 20, 0, 0), 86400),
                                ((2026, 10, 20, 23, 59, 59, 250000), 1), ((2026, 12, 31, 23, 0), 3600)):
            with self.subTest(moment=moment):
                self.assertEqual(seconds_until_next_day(datetime(*moment, tzinfo=utc_zone.utc)), seconds)


@patch("core.views.has_pro", new=lambda user: True)
@patch("core.views.ai.make_drafts", return_value={"tasks": [{"title": "Llamar al dentista"}]})
class DailyLimitWaitTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.client.force_authenticate(User.objects.create_user("daily@example.invalid", "Daily-limit-passphrase!2026"))

    def dictate(self):
        return self.client.post("/api/ai/drafts/", PAYLOAD, format="json")

    @override_settings(AI_REQUESTS_PER_DAY=1)
    def test_the_accounts_daily_limit_says_the_seconds_until_utc_midnight(self, ai):
        with at(2026, 10, 20, 21, 30):
            self.assertEqual(self.dictate().status_code, 200)
            refused = self.dictate()
        self.assertEqual(refused.status_code, 429)
        self.assertEqual(refused["Retry-After"], "9000")  # 2 h 30 min, not «an hour»
        self.assertEqual(ai.call_count, 1)

    @override_settings(AI_GLOBAL_REQUESTS_PER_DAY=0)
    def test_the_global_daily_limit_says_it_too(self, ai):
        with at(2026, 10, 20, 8, 0, 0, 500000):
            refused = self.dictate()
        self.assertEqual((refused.status_code, refused["Retry-After"]), (429, "57600"))
        ai.assert_not_called()

    @override_settings(AI_REQUESTS_PER_DAY=1)
    def test_the_limit_starts_again_when_the_wait_is_over(self, ai):
        with at(2026, 10, 20, 23, 59, 30):
            self.assertEqual(self.dictate().status_code, 200)
            refused = self.dictate()
        # 30 seconds before midnight the honest answer is under a minute.
        self.assertEqual((refused.status_code, refused["Retry-After"]), (429, "30"))
        with at(2026, 10, 21, 0, 0, 1):
            self.assertEqual(self.dictate().status_code, 200)

    def test_six_a_minute_still_says_under_a_minute(self, ai):
        for _ in range(6):
            self.assertEqual(self.dictate().status_code, 200)
        refused = self.dictate()
        self.assertEqual(refused.status_code, 429)
        self.assertTrue(1 <= int(refused["Retry-After"]) <= 60, refused["Retry-After"])

    def test_googles_quota_refusal_still_says_no_wait(self, ai):
        ai.side_effect = AIUnavailable("Google's quota is temporarily exhausted. Try later or create the task manually.", 429)
        refused = self.dictate()
        self.assertEqual(refused.status_code, 429)
        self.assertFalse(refused.has_header("Retry-After"))
