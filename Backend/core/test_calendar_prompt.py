from datetime import date, datetime
from zoneinfo import ZoneInfo

from django.test import SimpleTestCase

from .ai import build_prompt, calendar_line


def prompt(reference, commands=False):
    return build_prompt({"text": "Cambia la cita del médico al viernes", "timezone": "Europe/Madrid",
                         "reference_time": reference, "commands": commands, "collaboration_context": None})


class CalendarPromptTests(SimpleTestCase):
    """The model read weekdays from another year's calendar: on Wednesday 21 October 2026,
    «el viernes» came back as the 24th and «esta semana» as Tuesday to Monday. The prompt
    now spells the days and weeks out."""

    def test_names_the_days_around_the_reference_with_their_weekdays(self):
        line = calendar_line(date(2026, 10, 21))
        self.assertIn("today is Wednesday 2026-10-21", line)
        self.assertIn("Tuesday 2026-10-20", line)
        self.assertIn("Wednesday 2026-10-14", line)
        self.assertIn("Friday 2026-10-23", line)
        self.assertIn("Monday 2026-10-26", line)
        self.assertIn("Tuesday 2026-11-03", line)
        self.assertNotIn("2026-11-05", line)

    def test_weeks_run_monday_to_sunday(self):
        line = calendar_line(date(2026, 10, 21))
        self.assertIn("last week is 2026-10-12 to 2026-10-18", line)
        self.assertIn("this week is 2026-10-19 to 2026-10-25", line)
        self.assertIn("next week is 2026-10-26 to 2026-11-01", line)

    def test_a_sunday_is_the_last_day_of_its_week(self):
        line = calendar_line(date(2026, 10, 25))
        self.assertIn("today is Sunday 2026-10-25", line)
        self.assertIn("this week is 2026-10-19 to 2026-10-25", line)
        self.assertIn("next week is 2026-10-26 to 2026-11-01", line)

    def test_crosses_month_and_year_ends(self):
        line = calendar_line(date(2026, 12, 30))
        self.assertIn("today is Wednesday 2026-12-30", line)
        self.assertIn("Friday 2027-01-01", line)
        self.assertIn("next week is 2027-01-04 to 2027-01-10", line)

    def test_the_prompt_carries_it_with_and_without_commands(self):
        reference = datetime(2026, 10, 21, 10, 0, tzinfo=ZoneInfo("Europe/Madrid"))
        for commands in (False, True):
            text = prompt(reference, commands)
            self.assertIn("Calendar (use it for every weekday and week", text)
            self.assertIn("Friday 2026-10-23", text)
            self.assertLess(text.index("Calendar ("), text.index("User words (JSON string)"))

    def test_uses_the_reference_in_its_own_time_zone(self):
        # 23:30 UTC on Tuesday 20 October is already Wednesday 21 in Madrid.
        reference = datetime(2026, 10, 20, 23, 30, tzinfo=ZoneInfo("UTC"))
        self.assertIn("today is Wednesday 2026-10-21", prompt(reference))
