"""«Reopen»: a task marked done by mistake, made pending again by voice (docs/VOICE_COMMANDS.md).

The model is always mocked: these tests check the kind and its other names, the set's status, the
answer's shape, and what the prompt teaches."""
import json
from datetime import date, datetime, timezone
from functools import partial
from unittest.mock import patch

from django.test import SimpleTestCase

from .ai import build_prompt, day_of_month, extract_tasks, validate_draft
from .voice_commands import ExtractedCommand, commands_prompt

REFERENCE = datetime(2026, 10, 18, 9, tzinfo=timezone.utc)  # Sunday 18 October 2026, 11:00 in Madrid.
ZONE = "Europe/Madrid"


def directory():
    return {"user_id": 1, "user_name": "Miki", "default_project_id": None, "projects": [
        {"id": "physics", "name": "Física", "group_name": None, "shared": True,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""},
                    {"user_id": 3, "name": "Paul", "voice_name": ""}]},
    ], "view_only_projects": []}


class ReopenSchemaTests(SimpleTestCase):
    def test_reopen_is_a_kind_with_other_names(self):
        for kind in ("reopen", "uncomplete", "Uncheck", " untick ", "mark_undone", "not_done", "undone",
                     "mark_incomplete", "incomplete", "undo_complete", "mark_pending", "REOPEN_TASK"):
            with self.subTest(kind=kind):
                command = ExtractedCommand.model_validate({"kind": kind, "target": {"words": ["médico"]}})
                self.assertEqual((command.kind, command.target.words), ("reopen", ["médico"]))

    def test_a_flat_reopen_takes_its_date_as_the_tasks_day(self):
        command = ExtractedCommand.model_validate({"kind": "reopen", "words": ["médico"], "date": "2026-10-21"})
        self.assertEqual((command.target.words, command.target.date), (["médico"], date(2026, 10, 21)))

    def test_a_reopen_written_into_tasks_is_moved_to_commands(self):
        result = validate_draft(json.dumps({"tasks": [{"kind": "uncheck", "target": {"words": ["médico"]}},
                                                      {"title": "Comprar leche", "date": None, "time": None,
                                                       "priority": 1}]}), commands=True)
        self.assertEqual([command.kind for command in result.commands], ["reopen"])
        self.assertEqual([task.title for task in result.tasks], ["Comprar leche"])


class ReopenExtractionTests(SimpleTestCase):
    def commands(self, *commands):
        answer = {"tasks": [], "commands": list(commands)}
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)):
            return extract_tasks("Synthetic dictation", ZONE, REFERENCE, directory(), commands=True)["commands"]

    def test_one_task_keeps_the_single_target_shape(self):
        command, = self.commands({"kind": "reopen", "target": {"words": ["médico"], "project_name": "Física"}})
        self.assertEqual(command, {"kind": "reopen", "target": {"words": ["médico"], "list_id": "physics",
                                                                "project_name": None, "date": None}, "issues": []})

    def test_a_set_always_holds_done_tasks(self):
        # «Desmarca todas las de hoy»: whatever status the model wrote, only done tasks can be reopened.
        for status in (None, "open", "any", "completed"):
            with self.subTest(status=status):
                target = {"all": True, "from_date": "2026-10-18", "to_date": "2026-10-18"}
                if status:
                    target["status"] = status
                command, = self.commands({"kind": "reopen", "target": target})
                self.assertEqual((command["target"]["all"], command["target"]["status"]), (True, "completed"))
                self.assertEqual((command["target"]["from"], command["target"]["to"]), ("2026-10-18", "2026-10-18"))

    def test_an_unknown_project_is_reported(self):
        command, = self.commands({"kind": "reopen", "target": {"words": ["médico"], "project_name": "Química"}})
        self.assertEqual((command["target"]["list_id"], command["target"]["project_name"], command["issues"]),
                         (None, "Química", ["project_not_available"]))


class ReopenPromptTests(SimpleTestCase):
    def test_reopen_is_taught_only_to_apps_that_ask(self):
        def prompt(commands):
            return build_prompt({"text": "La tarea del médico no está hecha", "timezone": ZONE,
                                 "reference_time": REFERENCE, "collaboration_context": directory(),
                                 "commands": commands})
        self.assertIn("kind 'reopen'", prompt(True))
        self.assertNotIn("kind 'reopen'", prompt(False))

    def test_the_examples(self):
        section = commands_prompt(date(2026, 10, 18), partial(day_of_month, today=date(2026, 10, 18)))
        for example in (
                "'La tarea del médico no está hecha, desmárcala' is "
                '{"kind":"reopen","target":{"words":["médico"]}}',
                "'Desmarca la tasca de comprar el pa' is {\"kind\":\"reopen\",\"target\":{\"words\":[\"pa\"]}}",
                "'Oh wait, the doctor one isn't done yet, uncheck it' is "
                '{"kind":"reopen","target":{"words":["doctor"]}}',
                "'Desmarca todas las de hoy' is "
                '{"kind":"reopen","target":{"all":true,"from_date":"2026-10-18","to_date":"2026-10-18"}}',
                "update, delete, complete and reopen act on a set"):
            self.assertIn(example, section)
