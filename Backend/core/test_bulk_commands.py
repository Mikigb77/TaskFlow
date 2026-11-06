"""Bulk voice commands and «complete» (docs/VOICE_COMMANDS.md, Bulk commands; decided 2026-10-21).

The model is always mocked: these tests check the schema, its tolerant parsing, the normalization,
the resolution of spoken names and the answer's shape, and what the prompt teaches."""
import json
from copy import deepcopy
from datetime import date, datetime, timezone
from functools import partial
from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from google.genai import _transformers
from pydantic import ValidationError
from rest_framework.test import APIClient

from . import views
from .ai import (_generate_reviewable_once, build_prompt, day_of_month, extract_tasks, validate_draft,
                 vertex_response_schema)
from .models import FreeDictation, ListMembership, Task, TaskList, User
from .voice_commands import CommandChanges, CommandTarget, ExtractedCommand, commands_prompt

REFERENCE = datetime(2026, 10, 18, 9, tzinfo=timezone.utc)  # Sunday 18 October 2026, 11:00 in Madrid.
ZONE = "Europe/Madrid"
ONE_TASK = {"words", "list_id", "project_name", "date"}  # A single task's target: today's exact shape.


def directory():
    return {"user_id": 1, "user_name": "Miki", "default_project_id": None, "projects": [
        {"id": "physics", "name": "Física", "group_name": None, "shared": True,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""},
                    {"user_id": 2, "name": "Ana García", "voice_name": "Anita"},
                    {"user_id": 3, "name": "Paul", "voice_name": ""}]},
        {"id": "maths", "name": "Matemáticas", "group_name": None, "shared": True,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""},
                    {"user_id": 3, "name": "Paul", "voice_name": ""},
                    {"user_id": 5, "name": "Ana López", "voice_name": ""}]},
        {"id": "maths-2", "name": "Matemáticas II", "group_name": None, "shared": False,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""}]},
    ], "view_only_projects": [
        {"id": "history", "name": "Historia", "group_name": None, "shared": True,
         "people": [{"user_id": 4, "name": "Marta", "voice_name": ""}]},
    ]}


def everything(target, **fields):
    """A set's target as the model writes it."""
    return {"all": True, **target, **fields}


def a_set(**fields):
    """A set's target in the answer: every key, in the documented order."""
    return {"all": True, "words": [], "list_id": None, "project_name": None, "person_id": None, "person_name": None,
            "status": "open", "from": None, "to": None, "undated": False, "date": None, **fields}


class Extraction(SimpleTestCase):
    def extract(self, commands, context=None, reference=REFERENCE, commands_flag=True, tasks=()):
        answer = {"tasks": list(tasks), "commands": commands}
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)) as provider:
            result = extract_tasks("Synthetic dictation", ZONE, reference,
                                   directory() if context is None else context, commands=commands_flag)
        self.provider = provider
        return result

    def commands(self, *commands, **options):
        return self.extract(list(commands), **options)["commands"]


class SchemaAndToleranceTests(SimpleTestCase):
    def command(self, item):
        return ExtractedCommand.model_validate(item)

    def test_complete_is_a_kind_with_other_names(self):
        for kind in ("complete", "done", "mark_done", "finish", "complete_task", " Mark_Done ", "FINISH",
                     "completed", "mark_complete", "mark_as_done"):
            with self.subTest(kind=kind):
                command = self.command({"kind": kind, "target": {"words": ["médico"]}})
                self.assertEqual((command.kind, command.target.words), ("complete", ["médico"]))

    def test_a_completion_written_into_tasks_is_moved_to_commands(self):
        result = validate_draft(json.dumps({"tasks": [{"kind": "done", "target": {"words": ["pan"]}},
                                                      {"title": "Comprar leche", "date": None, "time": None,
                                                       "priority": 1}]}), commands=True)
        self.assertEqual([command.kind for command in result.commands], ["complete"])
        self.assertEqual([task.title for task in result.tasks], ["Comprar leche"])

    def test_all_and_undated_as_strings_numbers_or_nulls(self):
        for value, expected in (("true", True), ("True", True), (" yes ", True), (1, True), (True, True),
                                ("false", False), (None, False), ("", False), (0, False), (False, False)):
            with self.subTest(value=value):
                target = CommandTarget.model_validate({"all": value, "undated": value})
                self.assertEqual((target.all, target.undated), (expected, expected))
        with self.assertRaises(ValidationError):
            CommandTarget.model_validate({"all": "todas"})

    def test_shift_days_as_a_number_or_a_numeric_string_else_dropped(self):
        for value, expected in ((7, 7), (-2, -2), ("7", 7), (" -3 ", -3), ("+1", 1), (7.0, 7), ("14.0", 14),
                                (366, 366), (-366, -366), ("366", 366)):
            with self.subTest(value=value):
                self.assertEqual(CommandChanges.model_validate({"shift_days": value}).shift_days, expected)
        for value in (0, "0", 367, -367, "1000", 1.5, "1,5", "una semana", "", None, True, False, [7], {"days": 7}):
            with self.subTest(value=value):
                self.assertIsNone(CommandChanges.model_validate({"shift_days": value}).shift_days)

    def test_a_sets_filters_and_their_other_names(self):
        target = CommandTarget.model_validate({
            "all": "true", "words": "compra", "project_name": {"name": "Física"}, "person": "member",
            "member_name": ["Paul"], "status": "pending", "from": "2026-10-19", "to": "", "undated": None})
        self.assertEqual((target.all, target.words, target.project_name), (True, ["compra"], "Física"))
        self.assertEqual((target.person, target.member_name, target.status), ("member", "Paul", "open"))
        self.assertEqual((target.from_date, target.to_date, target.undated), (date(2026, 10, 19), None, False))
        for said, status in (("done", "completed"), ("finished", "completed"), ("complete", "completed"),
                             ("all", "any"), ("todo", "open"), ("OPEN", "open"), (None, "open"), ("", "open")):
            with self.subTest(status=said):
                self.assertEqual(CommandTarget.model_validate({"all": True, "status": said}).status, status)
        for invalid in ({"all": True, "status": "maybe"}, {"all": True, "person": "Paul"},
                        {"all": True, "from_date": "ayer"}):
            with self.subTest(invalid=invalid), self.assertRaises(ValidationError):
                CommandTarget.model_validate(invalid)

    def test_flat_commands_build_their_target(self):
        complete = self.command({"kind": "complete", "words": ["médico"], "date": "2026-10-21"})
        self.assertEqual((complete.target.words, complete.target.date), (["médico"], date(2026, 10, 21)))
        # In a flat update the date is the new one; the set's period and filters still go to the target.
        update = self.command({"kind": "update", "all": "true", "from": "2026-10-17", "to": "2026-10-17",
                               "date": "2026-10-19", "priority": 3, "shift_days": "2"})
        self.assertEqual((update.target.all, update.target.from_date, update.target.to_date, update.target.date),
                         (True, date(2026, 10, 17), date(2026, 10, 17), None))
        self.assertEqual((update.changes.date, update.changes.priority, update.changes.shift_days),
                         (date(2026, 10, 19), 3, 2))
        # In a flat deletion the date is the set's day, and the status is the set's, not find's default.
        delete = self.command({"kind": "remove", "all": True, "date": "2026-10-17", "status": "done"})
        self.assertEqual((delete.target.from_date, delete.target.to_date, delete.target.date, delete.target.status),
                         (date(2026, 10, 17), date(2026, 10, 17), None, "completed"))
        flat_set = self.command({"kind": "delete", "all": True})
        self.assertEqual((flat_set.target.status, flat_set.target.from_date), ("open", None))

    def test_a_sets_filters_written_beside_its_target_are_moved_into_it(self):
        command = self.command({"kind": "update", "all": True, "status": "completed", "from_date": "2026-10-12",
                                "to_date": "2026-10-18", "undated": False, "person": "me",
                                "target": {"words": []}, "changes": {"date": "2026-10-25"}})
        target = command.target
        self.assertEqual((target.all, target.status, target.person), (True, "completed", "me"))
        self.assertEqual((target.from_date, target.to_date), (date(2026, 10, 12), date(2026, 10, 18)))
        # What the target says wins over what is beside it.
        command = self.command({"kind": "delete", "status": "completed", "target": {"all": True, "status": "any"}})
        self.assertEqual(command.target.status, "any")
        # A person beside the target is the set's; with an assignee beside it, the name is the assignee's.
        command = self.command({"kind": "update", "all": True, "person": "member", "member_name": "Ana",
                                "target": {}, "changes": {"assignee": "member", "member_name": "Paul"}})
        self.assertEqual((command.target.person, command.target.member_name), ("member", "Ana"))
        self.assertEqual(command.changes.member_name, "Paul")
        command = self.command({"kind": "update", "all": True, "assignee": "member", "member_name": "Paul",
                                "from_date": "2026-10-23", "to_date": "2026-10-23"})
        self.assertEqual((command.target.member_name, command.changes.assignee, command.changes.member_name),
                         (None, "member", "Paul"))

    def test_todays_slips_still_work_for_the_new_kind(self):
        self.assertEqual(self.command({"kind": "complete", "target": "dentista"}).target.words, ["dentista"])
        result = validate_draft(json.dumps([{"commands": [{"kind": "complete", "target": {"words": ["pan"]}}]}]),
                                commands=True)
        self.assertEqual(result.commands[0].kind, "complete")
        result = validate_draft(json.dumps({"kind": "done", "words": "pan"}), commands=True)
        self.assertEqual((result.commands[0].kind, result.commands[0].target.words), ("complete", ["pan"]))
        command = self.command({"kind": "find", "target": {"all": True, "words": ["pan"]}, "status": "open"})
        self.assertEqual((command.kind, command.words, command.status), ("find", ["pan"], "open"))

    def test_vertex_accepts_the_new_fields(self):
        schema = vertex_response_schema(True)
        self.assertEqual(schema["$defs"]["ExtractedCommand"]["properties"]["kind"]["enum"],
                         ["project", "find", "update", "delete", "complete", "reopen"])
        target = schema["$defs"]["CommandTarget"]["properties"]
        self.assertTrue({"all", "person", "member_name", "status", "from_date", "to_date", "undated"} <= set(target))
        self.assertEqual(target["all"], {"type": "boolean"})
        self.assertEqual(schema["$defs"]["CommandChanges"]["properties"]["shift_days"],
                         {"anyOf": [{"type": "integer"}, {"type": "null"}]})
        converted = _transformers.t_schema(None, deepcopy(schema)).properties["commands"].items
        self.assertEqual(converted.properties["kind"].enum, ["project", "find", "update", "delete", "complete", "reopen"])
        self.assertEqual(converted.properties["target"].properties["undated"].type.value, "BOOLEAN")
        self.assertEqual(vertex_response_schema()["properties"].keys(), {"tasks"})  # Older apps: unchanged.


class NormalizationTests(Extraction):
    def test_a_day_said_for_a_set_is_its_period(self):
        update, delete, complete, period, half = self.commands(
            {"kind": "update", "target": everything({"date": "2026-10-17"}), "changes": {"date": "2026-10-19"}},
            {"kind": "delete", "target": everything({"date": "2026-10-17"})},
            {"kind": "complete", "target": everything({"date": "2026-10-18"})},
            # With a period said too, the period wins and the day goes.
            {"kind": "delete", "target": everything({"date": "2026-10-19", "from_date": "2026-10-12",
                                                     "to_date": "2026-10-18"})},
            {"kind": "update", "target": everything({"date": "2026-10-18", "to_date": "2026-10-17"}),
             "changes": {"date": "2026-10-18"}})
        self.assertEqual(update["target"], a_set(**{"from": "2026-10-17", "to": "2026-10-17"}))
        self.assertEqual(delete["target"], a_set(**{"from": "2026-10-17", "to": "2026-10-17"}))
        self.assertEqual(complete["target"], a_set(**{"from": "2026-10-18", "to": "2026-10-18"}))
        self.assertEqual(period["target"], a_set(**{"from": "2026-10-12", "to": "2026-10-18"}))
        self.assertEqual(half["target"], a_set(to="2026-10-17"))  # «Lo atrasado»: up to yesterday.

    def test_a_set_never_gets_one_title_or_the_same_notes(self):
        command, = self.commands({"kind": "update", "target": everything({"from_date": "2026-10-19",
                                                                          "to_date": "2026-10-19"}),
                                  "changes": {"title": "Repasar", "notes_append": "Urgente", "priority": 3,
                                              "time": "09:00", "deadline_date": "2026-10-30"}})
        self.assertEqual(command["changes"], {"time": "09:00", "deadline_date": "2026-10-30", "priority": 3})
        single, = self.commands({"kind": "update", "target": {"words": ["informe"]},
                                 "changes": {"title": "Repasar", "notes_append": "Urgente"}})
        self.assertEqual(single["changes"], {"title": "Repasar", "notes_append": "Urgente"})

    def test_a_set_with_nothing_left_to_change_comes_to_nothing(self):
        result = self.extract([
            {"kind": "update", "target": everything({}), "changes": {"title": "Repasar"}},
            {"kind": "update", "target": everything({}), "changes": {"shift_days": 0}},
            {"kind": "update", "target": everything({})},
            {"kind": "update", "target": {"words": ["informe"]}, "changes": {"title": None}},
        ])
        # A single update with no change still opens the task; the sets are dropped.
        self.assertEqual(result["commands"], [
            {"kind": "update", "target": {"words": ["informe"], "list_id": None, "project_name": None, "date": None},
             "changes": {}, "issues": []}])
        self.assertEqual(self.extract([{"kind": "update", "target": everything({}), "changes": {}}])["commands"], [])

    def test_a_date_wins_over_shift_days(self):
        moved, cleared, shifted, timed = self.commands(
            {"kind": "update", "target": everything({}), "changes": {"date": "2026-10-25", "shift_days": 7}},
            {"kind": "update", "target": {"words": ["médico"]}, "changes": {"clear": ["date"], "shift_days": 2}},
            {"kind": "update", "target": {"words": ["médico"]}, "changes": {"shift_days": -2}},
            {"kind": "update", "target": everything({}), "changes": {"shift_days": "1", "time": "09:30"}})
        self.assertEqual(moved["changes"], {"date": "2026-10-25"})
        self.assertEqual(cleared["changes"], {"date": None, "time": None})
        self.assertEqual(shifted["changes"], {"shift_days": -2})
        self.assertEqual(timed["changes"], {"shift_days": 1, "time": "09:30"})

    def test_shift_days_out_of_range_is_dropped(self):
        for value in (0, 367, -400, 2.5, "dos"):
            with self.subTest(value=value):
                command, = self.commands({"kind": "update", "target": {"words": ["médico"]},
                                          "changes": {"shift_days": value, "priority": 3}})
                self.assertEqual(command["changes"], {"priority": 3})

    def test_undated_clears_the_period(self):
        command, = self.commands({"kind": "update", "target": everything({"undated": "true", "date": "2026-10-17",
                                                                          "from_date": "2026-10-12",
                                                                          "to_date": "2026-10-18"}),
                                  "changes": {"date": "2026-10-19"}})
        self.assertEqual(command["target"], a_set(undated=True))

    def test_the_status_of_a_set(self):
        default, done, both, pending, completing = self.commands(
            {"kind": "delete", "target": everything({})},
            {"kind": "delete", "target": everything({"status": "done"})},
            {"kind": "delete", "target": everything({"status": "all"})},
            {"kind": "update", "target": everything({"status": "pending"}), "changes": {"priority": 1}},
            # Only pending tasks can be marked done, whatever «hechas» made the model write.
            {"kind": "complete", "target": everything({"status": "completed"})})
        self.assertEqual([command["target"]["status"] for command in (default, done, both, pending, completing)],
                         ["open", "completed", "any", "open", "open"])

    def test_a_period_said_backwards_is_turned_around(self):
        command, = self.commands({"kind": "complete", "target": everything({"from": "2026-10-25",
                                                                            "to": "2026-10-19"})})
        self.assertEqual((command["target"]["from"], command["target"]["to"]), ("2026-10-19", "2026-10-25"))

    def test_one_task_keeps_todays_target_whatever_else_the_model_wrote(self):
        commands = self.commands(
            {"kind": "update", "target": {"words": ["informe"], "person": "member", "member_name": "Marta",
                                          "status": "completed", "from_date": "2026-10-12", "to_date": "2026-10-18",
                                          "undated": True, "all": False}, "changes": {"priority": 3}},
            {"kind": "delete", "target": {"words": ["médico"], "all": "false"}},
            {"kind": "complete", "target": {"words": ["médico"], "project_name": "Física"}},
            # One task's day written as a period of one day is its day.
            {"kind": "delete", "target": {"words": ["médico"], "from_date": "2026-10-17", "to_date": "2026-10-17"}})
        for command in commands:
            with self.subTest(kind=command["kind"]):
                self.assertEqual(set(command["target"]), ONE_TASK)
        self.assertEqual(commands[0]["issues"], [])  # A person said for one task isn't looked up.
        self.assertEqual(commands[2]["target"]["list_id"], "physics")
        self.assertEqual(commands[3]["target"]["date"], "2026-10-17")


class ResolutionTests(Extraction):
    def test_a_sets_project_and_person_are_resolved_as_find_does(self):
        commands = self.commands(
            {"kind": "update", "target": everything({"project_name": "fisica", "person": "member",
                                                     "member_name": "Pau"}), "changes": {"priority": 3}},
            {"kind": "delete", "target": everything({"project_name": "Historia", "member_name": "Marta"})},
            {"kind": "complete", "target": everything({"person": "me"})},
            {"kind": "complete", "target": everything({"person": "member", "member_name": "Marta"})})
        physics, history, mine, marta = (command["target"] for command in commands)
        self.assertEqual((physics["list_id"], physics["person_id"], physics["person_name"]), ("physics", 3, None))
        # Projects one can only view are found, as for find; their people too.
        self.assertEqual((history["list_id"], history["person_id"]), ("history", 4))
        self.assertEqual((mine["person_id"], mine["list_id"]), (1, None))
        self.assertEqual(marta["person_id"], 4)  # Without a project, everyone in the person's projects.
        self.assertTrue(all(command["issues"] == [] for command in commands))

    def test_what_couldnt_be_resolved_is_said_project_first(self):
        unknown, outsider, ambiguous_member, ambiguous_project = self.commands(
            {"kind": "delete", "target": everything({"project_name": "Geografía", "member_name": "Jordi"})},
            {"kind": "delete", "target": everything({"project_name": "Física", "member_name": "Marta"})},
            {"kind": "update", "target": everything({"member_name": "Ana"}),
             "changes": {"assignee": "member", "member_name": "Jordi"}},
            {"kind": "complete", "target": everything({"project_name": "mates", "person": "member",
                                                       "member_name": "Ana"})})
        self.assertEqual(unknown["target"], a_set(project_name="Geografía", person_name="Jordi"))
        self.assertEqual(unknown["issues"], ["project_not_available", "member_not_available"])
        # Marta isn't in Física: a person is looked for in the project named, as for find.
        self.assertEqual((outsider["target"]["list_id"], outsider["target"]["person_name"]), ("physics", "Marta"))
        self.assertEqual(outsider["issues"], ["member_not_available"])
        # The set's person, then the assignee.
        self.assertEqual((ambiguous_member["target"]["person_id"], ambiguous_member["target"]["person_name"]),
                         (None, "Ana"))
        self.assertEqual(ambiguous_member["issues"], ["ambiguous_member", "member_not_available"])
        self.assertEqual(ambiguous_member["changes"], {"assignee_name": "Jordi"})
        # The candidates sit in the target, beside the issue.
        self.assertEqual(ambiguous_project["issues"], ["ambiguous_project", "ambiguous_member"])
        self.assertEqual(ambiguous_project["target"]["project_candidates"],
                         [{"id": "maths", "name": "Matemáticas"}, {"id": "maths-2", "name": "Matemáticas II"}])
        self.assertNotIn("project_candidates", unknown["target"])

    def test_assigning_a_set_finds_the_person_in_its_project(self):
        maths, everywhere, me = self.commands(
            {"kind": "update", "target": everything({"project_name": "Matemáticas", "from_date": "2026-10-23",
                                                     "to_date": "2026-10-23"}),
             "changes": {"assignee": "member", "member_name": "Ana"}},
            {"kind": "update", "target": everything({}), "changes": {"assignee": "member", "member_name": "Anita"}},
            {"kind": "update", "target": everything({}), "changes": {"assignee": "me"}})
        self.assertEqual((maths["target"]["list_id"], maths["changes"]), ("maths", {"assignee_id": 5,
                                                                                  "assignee_name": "Ana López"}))
        self.assertEqual(everywhere["changes"], {"assignee_id": 2, "assignee_name": "Ana García"})
        self.assertEqual(me["changes"], {"assignee_id": 1, "assignee_name": "Miki"})

    def test_the_model_cannot_choose_ids_for_a_set(self):
        command, = self.commands({"kind": "delete", "target": everything({"list_id": "secret", "person_id": 99})})
        self.assertEqual((command["target"]["list_id"], command["target"]["person_id"]), (None, None))


class AnswerShapeTests(Extraction):
    def test_the_documented_example(self):
        # «Pasa todas las tareas de ayer a mañana», said on Wednesday 21 October 2026.
        command, = self.commands({"kind": "update", "target": {"all": True, "from_date": "2026-10-20",
                                                               "to_date": "2026-10-20"},
                                  "changes": {"date": "2026-10-22"}},
                                 reference=datetime(2026, 10, 21, 9, tzinfo=timezone.utc))
        self.assertEqual(json.dumps(command, ensure_ascii=False), json.dumps(
            {"kind": "update",
             "target": {"all": True, "words": [], "list_id": None, "project_name": None, "person_id": None,
                        "person_name": None, "status": "open", "from": "2026-10-20", "to": "2026-10-20",
                        "undated": False, "date": None},
             "changes": {"date": "2026-10-22"},
             "issues": []}, ensure_ascii=False))  # The keys in the documented order too.

    def test_complete_has_a_target_and_no_changes(self):
        one, many = self.commands(
            {"kind": "complete", "target": {"words": ["dentista"]}, "changes": {"priority": 3}},
            {"kind": "complete", "target": everything({"from_date": "2026-10-18", "to_date": "2026-10-18"})})
        self.assertEqual(one, {"kind": "complete", "target": {"words": ["dentista"], "list_id": None,
                                                              "project_name": None, "date": None}, "issues": []})
        self.assertEqual(many, {"kind": "complete", "target": a_set(**{"from": "2026-10-18", "to": "2026-10-18"}),
                                "issues": []})

    def test_single_commands_keep_todays_exact_shape(self):
        update, delete = self.commands(
            {"kind": "update", "target": {"words": ["médico"], "date": "2026-10-21"},
             "changes": {"date": "2026-10-25", "title": None, "time": None, "shift_days": None, "clear": []}},
            {"kind": "delete", "target": {"words": ["dentista"]}})
        self.assertEqual(update, {"kind": "update", "target": {"words": ["médico"], "list_id": None,
                                                               "project_name": None, "date": "2026-10-21"},
                                  "changes": {"date": "2026-10-25"}, "issues": []})
        self.assertEqual(delete, {"kind": "delete", "target": {"words": ["dentista"], "list_id": None,
                                                               "project_name": None, "date": None}, "issues": []})

    def test_a_set_with_its_filters(self):
        command, = self.commands({"kind": "delete", "target": everything({
            "words": ["examen"], "project_name": "Matemáticas II", "person": "me", "status": "completed",
            "from_date": "2026-10-05", "to_date": "2026-10-11"})})
        self.assertEqual(command, {"kind": "delete", "target": a_set(
            words=["examen"], list_id="maths-2", person_id=1, status="completed",
            **{"from": "2026-10-05", "to": "2026-10-11"}), "issues": []})

    def test_old_apps_never_see_the_new_kind(self):
        result = self.extract([{"kind": "complete", "target": everything({})}], commands_flag=False,
                              tasks=[{"title": "Comprar pan", "date": None, "time": None, "priority": 1}])
        self.assertEqual(set(result), {"tasks", "transcript"})
        prompt = self.provider.call_args.args[0]
        for text in ("kind 'complete'", "shift_days", '"all":true', "Pasa todas las tareas de ayer a mañana"):
            self.assertNotIn(text, prompt)


class TitlePolishTests(SimpleTestCase):
    def test_a_set_survives_the_title_polish_unchanged(self):
        long_title = ("Tener la presentación terminada con todas las diapositivas y que no tenga que utilizar otra cosa "
                      "que no esté ya programada")
        command = {"kind": "update", "all": "true", "date": "2026-10-19", "from": "2026-10-17", "to": "2026-10-17",
                   "status": "done", "shift_days": "7", "title": "x"}
        source = {"tasks": [{"title": long_title, "date": None, "time": None, "priority": 1}], "commands": [command]}
        repaired = {"tasks": [{"title": "Terminar la presentación", "date": None, "time": None, "priority": 1}]}
        with patch("core.ai._generate_once", side_effect=[json.dumps(source), json.dumps(repaired)]):
            polished = validate_draft(_generate_reviewable_once("Words", 10000, commands=True), commands=True)
        direct = validate_draft(json.dumps(source), commands=True)
        self.assertEqual(polished.tasks[0].title, "Terminar la presentación")
        self.assertEqual(polished.commands, direct.commands)
        target, changes = polished.commands[0].target, polished.commands[0].changes
        self.assertEqual((target.all, target.status, str(target.from_date), str(target.to_date)),
                         (True, "completed", "2026-10-17", "2026-10-17"))
        self.assertEqual((str(changes.date), changes.shift_days), ("2026-10-19", 7))


class PromptTests(SimpleTestCase):
    def section(self, today):
        return commands_prompt(today, partial(day_of_month, today=today))

    def prompt(self, commands=True):
        return build_prompt({"text": "Pasa todas las tareas de ayer a mañana", "timezone": ZONE,
                             "reference_time": REFERENCE, "collaboration_context": directory(), "commands": commands})

    def test_complete_shift_days_and_sets_are_taught_only_to_apps_that_ask(self):
        with_commands, without = self.prompt(), self.prompt(False)
        for text in ("kind 'complete'", "shift_days", "Many tasks at once", '"all":true',
                     "A task said in the singular is one task, never all: 'Cambia la cita del médico al viernes' is "
                     "one update."):
            self.assertIn(text, with_commands)
            self.assertNotIn(text, without)

    def test_the_examples_with_a_sundays_dates(self):
        section = self.section(date(2026, 10, 18))  # Sunday: this week is 12 to 18 October.
        for example in (
                "'Retrasa dos días la cita del médico' is "
                '{"kind":"update","target":{"words":["médico"]},"changes":{"shift_days":2}}',
                "'Ya he llamado al dentista' is {\"kind\":\"complete\",\"target\":{\"words\":[\"dentista\"]}}",
                "'Mark the report as done' is {\"kind\":\"complete\",\"target\":{\"words\":[\"report\"]}}",
                "'Pasa todas las tareas de ayer a mañana' is "
                '{"kind":"update","target":{"all":true,"from_date":"2026-10-17","to_date":"2026-10-17"},'
                '"changes":{"date":"2026-10-19"}}',
                "'Pasa lo de esta semana a la semana que viene' is "
                '{"kind":"update","target":{"all":true,"from_date":"2026-10-12","to_date":"2026-10-18"},'
                '"changes":{"shift_days":7}}',
                "'Pasa todo lo atrasado a hoy' is "
                '{"kind":"update","target":{"all":true,"to_date":"2026-10-17"},"changes":{"date":"2026-10-18"}}',
                # «Atrasado» means pending: the real model searched done tasks too (2026-10-22).
                "'¿Qué tengo atrasado?' is "
                '{"kind":"find","words":[],"status":"open","to_date":"2026-10-17"}',
                "'Posa totes les tasques sense data per a dilluns' is "
                '{"kind":"update","target":{"all":true,"undated":true},"changes":{"date":"2026-10-19"}}',
                "'Asigna a Paul todo lo del viernes de Matemáticas' is "
                '{"kind":"update","target":{"all":true,"project_name":"Matemáticas","from_date":"2026-10-23",'
                '"to_date":"2026-10-23"},"changes":{"assignee":"member","member_name":"Paul"}}',
                "'Make everything for tomorrow high priority' is "
                '{"kind":"update","target":{"all":true,"from_date":"2026-10-19","to_date":"2026-10-19"},'
                '"changes":{"priority":3}}',
                "'Marca como hechas todas las de hoy' is "
                '{"kind":"complete","target":{"all":true,"from_date":"2026-10-18","to_date":"2026-10-18"}}',
                "'Borra todas las completadas de la semana pasada' is "
                '{"kind":"delete","target":{"all":true,"status":"completed","from_date":"2026-10-05",'
                '"to_date":"2026-10-11"}}'):
            self.assertIn(example, section)

    def test_the_weeks_and_weekdays_follow_the_reference(self):
        wednesday = self.section(date(2026, 10, 21))
        self.assertIn('"from_date":"2026-10-19","to_date":"2026-10-25"},"changes":{"shift_days":7}', wednesday)
        self.assertIn('"status":"completed","from_date":"2026-10-12","to_date":"2026-10-18"', wednesday)
        self.assertIn('{"all":true,"undated":true},"changes":{"date":"2026-10-26"}', wednesday)
        self.assertIn('"project_name":"Matemáticas","from_date":"2026-10-23","to_date":"2026-10-23"', wednesday)
        # On a Monday, «el lunes» is today; on a Friday, «el viernes» is today.
        self.assertIn('{"all":true,"undated":true},"changes":{"date":"2026-10-19"}', self.section(date(2026, 10, 19)))
        friday = self.section(date(2026, 10, 23))
        self.assertIn('"from_date":"2026-10-23","to_date":"2026-10-23"},"changes":{"assignee"', friday)
        self.assertIn('"from_date":"2026-10-19","to_date":"2026-10-25"},"changes":{"shift_days":7}', friday)

    def test_every_example_is_a_valid_command(self):
        section, decoder, index, kinds = self.section(date(2026, 10, 21)), json.JSONDecoder(), 0, []
        while (start := section.find('{"kind"', index)) >= 0:
            value, index = decoder.raw_decode(section, start)
            kinds.append(ExtractedCommand.model_validate(value).kind)
        self.assertEqual(kinds.count("complete"), 3)
        self.assertEqual(kinds.count("reopen"), 4)
        self.assertEqual(len(kinds), 26)

    def test_overdue_always_means_pending(self):
        section = self.section(date(2026, 10, 21))
        self.assertIn("Overdue ('atrasado', 'vencido'; Catalan 'endarrerit'; English 'overdue', 'late') always means "
                      "pending tasks from before today: status 'open' and to_date yesterday without from_date", section)
        self.assertIn('"status":"open","to_date":"2026-10-20"', section)


@override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
class BulkEndpointTests(TestCase):
    def setUp(self):
        cache.clear()
        throttle = patch.object(views.DraftView, "throttle_classes", [])
        throttle.start()
        self.addCleanup(throttle.stop)
        self.owner = User.objects.create_user("bulk-owner@example.invalid", "Fixture-passphrase!2026", first_name="Miki")
        self.paul = User.objects.create_user("bulk-paul@example.invalid", "Fixture-passphrase!2026", first_name="Paul")
        self.physics = TaskList.objects.create(owner=self.owner, name="Física", shared=True)
        ListMembership.objects.create(task_list=self.physics, user=self.paul, role="editor")
        self.task = Task.objects.create(owner=self.owner, title="Ir al médico", task_list=self.physics,
                                        scheduled_date=date(2026, 10, 17))
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def dictate(self, answer):
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)):
            return self.client.post("/api/ai/drafts/", {"text": "Synthetic dictation", "timezone": ZONE,
                                                        "commands": True}, format="json")

    def test_bulk_commands_resolve_ids_count_once_and_change_nothing(self):
        response = self.dictate({"tasks": [], "commands": [
            {"kind": "update", "target": {"all": True, "project_name": "física", "date": "2026-10-17"},
             "changes": {"assignee": "member", "member_name": "Paul", "shift_days": 1}},
            {"kind": "complete", "target": {"all": True, "person": "me", "from": "2026-10-17", "to": "2026-10-17"}},
            {"kind": "delete", "target": {"all": True, "status": "completed", "undated": True}}]})
        self.assertEqual(response.status_code, 200, response.data)
        update, complete, delete = response.json()["commands"]
        self.assertEqual(update["target"], a_set(list_id=str(self.physics.pk), **{"from": "2026-10-17",
                                                                                  "to": "2026-10-17"}))
        self.assertEqual(update["changes"], {"shift_days": 1, "assignee_id": self.paul.pk, "assignee_name": "Paul"})
        self.assertEqual(complete["target"], a_set(person_id=self.owner.pk, **{"from": "2026-10-17",
                                                                               "to": "2026-10-17"}))
        self.assertEqual(delete["target"], a_set(status="completed", undated=True))
        self.assertEqual(response.data["free_voice"]["left"], 9)
        self.assertEqual(FreeDictation.objects.filter(user=self.owner, counted=True).count(), 1)
        self.task.refresh_from_db()  # The server never changes, completes or deletes a task for a command.
        self.assertEqual((self.task.scheduled_date, self.task.assignee, self.task.is_completed, self.task.is_deleted),
                         (date(2026, 10, 17), None, False, False))

    def test_a_set_with_nothing_to_change_is_an_empty_answer_that_costs_nothing(self):
        response = self.dictate({"tasks": [], "commands": [
            {"kind": "update", "target": {"all": True}, "changes": {"title": "Repasar"}}]})
        self.assertEqual((response.status_code, response.data["commands"]), (200, []))
        self.assertEqual(response.data["free_voice"]["left"], 10)
        self.assertFalse(FreeDictation.objects.exists())
