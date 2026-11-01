"""Completion times (D2, docs/COMPLETION_TIMES.md): when each completion happened."""
import uuid
from datetime import datetime, timedelta, timezone as tz

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from .models import Task, User

PASSWORD = "Completion-times-fixture-2026!"


class CompletionTimesTests(TestCase):
    def setUp(self):
        self.ana = User.objects.create_user("ana-done@example.invalid", PASSWORD, first_name="Ana")
        self.client = APIClient()
        self.client.force_authenticate(self.ana)
        self.path = f"/api/tasks/{uuid.uuid4()}/"

    def put(self, body):
        response = self.client.put(self.path, body, format="json")
        self.assertIn(response.status_code, (200, 201), response.data)
        return response.data

    def test_a_tick_keeps_the_time_the_app_sent_and_reopening_clears_it(self):
        task = self.put({"title": "Comprar pan", "version": 0})
        self.assertIsNone(task["completed_at"])
        ticked = "2026-10-31T08:15:00Z"
        done = self.put({**task, "is_completed": True, "completed_at": ticked})
        self.assertEqual(datetime.fromisoformat(done["completed_at"]), datetime(2026, 10, 31, 8, 15, tzinfo=tz.utc))
        # A later edit that doesn't send it keeps it, and doesn't change it.
        edited = self.put({key: value for key, value in {**done, "title": "Comprar pan integral"}.items()
                           if key != "completed_at"})
        self.assertEqual(edited["completed_at"], done["completed_at"])
        reopened = self.put({**edited, "is_completed": False})
        self.assertIsNone(reopened["completed_at"])

    def test_an_older_app_gets_the_server_time_and_a_future_time_is_clamped(self):
        task = self.put({"title": "Llamar al médico", "version": 0})
        before = timezone.now()
        done = self.put({**{k: v for k, v in task.items() if k != "completed_at"}, "is_completed": True})
        self.assertGreaterEqual(datetime.fromisoformat(done["completed_at"]), before - timedelta(seconds=1))
        later = (timezone.now() + timedelta(days=3)).isoformat()
        again = self.put({**done, "is_completed": False})
        clamped = self.put({**again, "is_completed": True, "completed_at": later})
        self.assertLessEqual(datetime.fromisoformat(clamped["completed_at"]), timezone.now())

    def test_each_repeat_has_its_own_time_and_old_completions_none(self):
        task = self.put({"title": "Regar", "version": 0, "recurrence": "daily", "scheduled_date": "2026-10-20",
                         "completed_dates": ["2026-10-20"]})
        Task.objects.filter(pk=task["id"]).update(completed_times={})  # As if ticked before 2026-10-31.
        task = self.client.get(self.path).data
        self.assertEqual(task["completed_times"], {})
        done = self.put({**task, "completed_dates": ["2026-10-20", "2026-10-30", "2026-10-31"],
                         "completed_times": {"2026-10-31": "2026-10-31T07:00:00Z"}})
        self.assertEqual(set(done["completed_times"]), {"2026-10-30", "2026-10-31"})
        self.assertTrue(done["completed_times"]["2026-10-31"].startswith("2026-10-31T07:00:00"))
        self.assertIsNone(done["completed_at"])
        unticked = self.put({**done, "completed_dates": ["2026-10-20", "2026-10-31"]})
        self.assertEqual(set(unticked["completed_times"]), {"2026-10-31"})
        self.assertEqual(unticked["completed_times"]["2026-10-31"], done["completed_times"]["2026-10-31"])
