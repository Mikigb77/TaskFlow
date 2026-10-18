"""«Para el 12» when the 12th has passed means next month (voice-commands plan, item 2)."""
import json
from datetime import date, datetime, timezone
from unittest.mock import patch

from django.test import SimpleTestCase

from .ai import build_prompt, day_of_month, day_of_month_rule, extract_tasks


class DayOfMonthTests(SimpleTestCase):
    def test_this_month_until_the_day_has_passed_then_next_month(self):
        today = date(2026, 10, 18)
        self.assertEqual(day_of_month(12, today), date(2026, 11, 12))
        self.assertEqual(day_of_month(17, today), date(2026, 11, 17))
        self.assertEqual(day_of_month(18, today), date(2026, 10, 18))  # Today hasn't passed yet.
        self.assertEqual(day_of_month(31, today), date(2026, 10, 31))
        self.assertEqual(day_of_month(5, date(2026, 12, 20)), date(2027, 1, 5))  # Into next year.

    def test_a_day_the_month_doesnt_have_is_a_question_not_a_guess(self):
        self.assertIsNone(day_of_month(31, date(2026, 11, 18)))
        self.assertIsNone(day_of_month(30, date(2027, 1, 31)))
        self.assertEqual(day_of_month(29, date(2028, 1, 31)), date(2028, 2, 29))  # A leap year.
        self.assertIsNone(day_of_month(0, date(2026, 10, 18)))
        self.assertIsNone(day_of_month(32, date(2026, 10, 1)))

    def test_the_rule_is_spelled_out_with_the_references_own_dates(self):
        self.assertIn("days 18 to 31 are 2026-10-18 to 2026-10-31; days 1 to 17 are 2026-11-01 to 2026-11-17.",
                      day_of_month_rule(date(2026, 10, 18)))
        self.assertIn("days 18 to 30 are 2026-11-18 to 2026-11-30; day 31 doesn't exist in November 2026; "
                      "days 1 to 17 are 2026-12-01 to 2026-12-17.", day_of_month_rule(date(2026, 11, 18)))
        self.assertIn("day 31 is 2027-01-31; days 1 to 28 are 2027-02-01 to 2027-02-28; "
                      "days 29 to 30 don't exist in February 2027.", day_of_month_rule(date(2027, 1, 31)))
        self.assertIn("With this reference, days 1 to 30 are 2026-09-01 to 2026-09-30; day 31 doesn't exist in "
                      "September 2026.", day_of_month_rule(date(2026, 9, 1)))

    def test_the_prompt_has_the_rule_in_the_persons_time_zone(self):
        # 23:30 on the 17th in UTC is already the 18th in Madrid, so the 17th has passed there.
        prompt = build_prompt({"text": "Terminar la presentación para el 17", "timezone": "Europe/Madrid",
                               "reference_time": datetime(2026, 10, 17, 23, 30, tzinfo=timezone.utc)})
        self.assertIn("A day of the month said alone, without a month ('para el 12', 'by the 12th', 'el dia 12'), "
                      "means this month if that day hasn't passed yet in the reference time zone, otherwise next month.",
                      prompt)
        self.assertIn("days 1 to 17 are 2026-11-01 to 2026-11-17", prompt)
        self.assertIn("For a day that doesn't exist in its month, set no date and ask a clarification", prompt)
        prompt = build_prompt({"text": "Terminar la presentación para el 17", "timezone": "America/New_York",
                               "reference_time": datetime(2026, 10, 17, 23, 30, tzinfo=timezone.utc)})
        self.assertIn("days 17 to 31 are 2026-10-17 to 2026-10-31", prompt)

    @patch("core.ai.generate")
    def test_the_models_answers_are_kept_as_dates_and_questions(self, provider):
        reference = datetime(2026, 11, 18, 10, tzinfo=timezone.utc)
        provider.return_value = json.dumps({"tasks": [
            {"title": "Terminar la presentación", "date": None, "time": None, "deadline_date": "2026-12-12",
             "priority": 2},
            {"title": "Pagar el alquiler", "date": None, "time": None, "priority": 1, "questions": [],
             "clarifications": [{"field": "schedule", "question": "Noviembre no tiene día 31. ¿El 30 o el 1 de diciembre?",
                                 "times": []}]},
        ]}, ensure_ascii=False)
        presentation, rent = extract_tasks("Terminar la presentación para el 12 y pagar el alquiler el 31",
                                           "Europe/Madrid", reference)["tasks"]
        self.assertIn("days 1 to 17 are 2026-12-01 to 2026-12-17", provider.call_args.args[0])
        self.assertEqual((presentation["deadline_date"], presentation["due_date"]), ("2026-12-12", None))
        self.assertIsNone(rent["scheduled_date"])
        self.assertEqual(rent["questions"], ["Noviembre no tiene día 31. ¿El 30 o el 1 de diciembre?"])
        self.assertEqual(rent["clarifications"][0]["field"], "schedule")
