"""Voice commands in POST /api/ai/drafts/ (docs/VOICE_COMMANDS.md). The model is always mocked."""
import json
from copy import deepcopy
from datetime import datetime, timezone
from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from google.genai import _transformers
from pydantic import ValidationError
from rest_framework.test import APIClient

from . import views
from .ai import (AIUnavailable, _generate_reviewable_once, build_prompt, extract_tasks, make_drafts,
                 validate_draft, vertex_response_schema)
from .models import FreeDictation, GroupMembership, ListMembership, Task, TaskGroup, TaskList, User

REFERENCE = datetime(2026, 10, 18, 9, tzinfo=timezone.utc)  # A Sunday; 11:00 in Madrid.
ZONE = "Europe/Madrid"


def task(**fields):
    return {"title": "Terminar la presentación", "date": None, "time": None, "priority": 1, **fields}


def directory():
    return {"user_id": 1, "user_name": "Miki", "default_project_id": None, "projects": [
        {"id": "physics", "name": "Física", "group_name": None, "shared": True,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""},
                    {"user_id": 2, "name": "Ana García", "voice_name": "Anita"},
                    {"user_id": 3, "name": "Paul", "voice_name": ""}]},
        {"id": "languages", "name": "Languages", "group_name": None, "shared": False,
         "people": [{"user_id": 1, "name": "Miki", "voice_name": ""}]},
    ], "view_only_projects": [
        {"id": "history", "name": "Historia", "group_name": None, "shared": True,
         "people": [{"user_id": 4, "name": "Marta", "voice_name": ""}]},
    ]}


class CommandExtractionTests(SimpleTestCase):
    def extract(self, answer, context=None, commands=True):
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)) as provider:
            result = extract_tasks("Synthetic dictation", ZONE, REFERENCE,
                                   directory() if context is None else context, commands=commands)
        self.provider = provider
        return result

    def test_a_new_project_and_the_tasks_that_name_it(self):
        # «Crea un proyecto de matemáticas, añade terminar la presentación para el 12 y que Paul haga la introducción».
        result = self.extract({"commands": [{"kind": "project", "name": "matemáticas"}], "tasks": [
            task(deadline_date="2026-11-12", priority=2, project_name="Matemáticas"),
            task(title="Escribir la introducción", project_name="Matemáticas",
                 assignment_request="member", member_name="Paul")]})
        self.assertEqual(result["commands"], [
            {"kind": "project", "name": "Matemáticas", "existing_list_id": None, "issues": []}])
        presentation, introduction = result["tasks"]
        self.assertEqual((presentation["list_id"], presentation["new_project"], presentation["project_suggestion"]),
                         (None, "Matemáticas", None))
        self.assertEqual((presentation["assignment"], presentation["assignment_issues"]), ("personal", []))
        self.assertEqual(presentation["deadline_date"], "2026-11-12")
        # A project created now has nobody to assign yet: the assignment waits for the invite.
        self.assertEqual(introduction["new_project"], "Matemáticas")
        self.assertEqual((introduction["assignment"], introduction["assignee_id"]), ("personal", None))
        self.assertEqual(introduction["assignment_issues"], ["member_not_available"])
        self.assertEqual(introduction["assignment_hints"]["member"], "Paul")

    def test_a_project_that_already_exists_is_used_not_created_twice(self):
        result = self.extract({"commands": [{"kind": "project", "name": "Física"},
                                            {"kind": "project", "name": "física"}],
                               "tasks": [task(project_name="fisica")]})
        self.assertEqual(result["commands"], [
            {"kind": "project", "name": "Física", "existing_list_id": "physics", "issues": []}])
        self.assertEqual((result["tasks"][0]["list_id"], result["tasks"][0]["new_project"]), ("physics", None))
        self.assertEqual(result["tasks"][0]["assignment"], "group")

    def test_a_project_like_two_existing_ones_is_reported_not_guessed(self):
        context = directory()
        context["projects"] += [{"id": "maths", "name": "Matemáticas", "group_name": None, "shared": False, "people": []},
                                {"id": "materials", "name": "Materiales", "group_name": None, "shared": False, "people": []}]
        result = self.extract({"commands": [{"kind": "project", "name": "Mates"}], "tasks": []}, context)
        # The matched projects come too, closest first: «Materiales» is fewer letters from «Mates».
        self.assertEqual(result["commands"], [
            {"kind": "project", "name": "Mates", "existing_list_id": None, "issues": ["ambiguous_project"],
             "project_candidates": [{"id": "materials", "name": "Materiales"}, {"id": "maths", "name": "Matemáticas"}]}])

    def test_an_unknown_project_without_create_keeps_todays_issue_and_suggests_its_name(self):
        result = self.extract({"tasks": [task(project_name="Química orgánica")]})
        self.assertEqual(result["commands"], [])
        draft = result["tasks"][0]
        self.assertEqual(draft["assignment_issues"], ["project_not_available"])
        self.assertEqual((draft["list_id"], draft["new_project"], draft["project_suggestion"]),
                         (None, None, "Química orgánica"))

    def test_find_update_and_delete_in_spoken_order(self):
        result = self.extract({"tasks": [], "commands": [
            {"kind": "find", "words": ["introducción"], "project_name": "fisica", "status": "any"},
            {"kind": "update", "target": {"words": ["médico"], "date": "2026-10-21"},
             "changes": {"date": "2026-10-25", "title": None, "time": None, "priority": None, "clear": []}},
            {"kind": "delete", "target": {"words": ["médico"], "project_name": None, "date": None}}]})
        self.assertEqual(result["tasks"], [])
        self.assertEqual(result["commands"], [
            {"kind": "find", "words": ["introducción"], "list_id": "physics", "project_name": None,
             "person_id": None, "person_name": None, "status": "any", "from": None, "to": None, "issues": []},
            {"kind": "update", "target": {"words": ["médico"], "list_id": None, "project_name": None, "date": "2026-10-21"},
             "changes": {"date": "2026-10-25"}, "issues": []},
            {"kind": "delete", "target": {"words": ["médico"], "list_id": None, "project_name": None, "date": None},
             "issues": []},
        ])

    def test_find_resolves_people_projects_one_can_only_view_and_says_what_it_could_not(self):
        commands = self.extract({"commands": [
            {"kind": "find", "words": [], "person": "member", "member_name": "Pau", "status": "pending"},
            {"kind": "find", "words": [], "person": "me", "status": "done", "from": "2026-10-19", "to": "2026-10-25"},
            {"kind": "find", "words": ["examen"], "project_name": "historia"},
            {"kind": "find", "words": [], "project_name": "Geografía", "member_name": "Jordi"},
        ]})["commands"]
        self.assertEqual((commands[0]["person_id"], commands[0]["person_name"], commands[0]["status"]), (3, None, "open"))
        self.assertEqual((commands[1]["person_id"], commands[1]["status"]), (1, "completed"))
        self.assertEqual((commands[1]["from"], commands[1]["to"]), ("2026-10-19", "2026-10-25"))
        self.assertEqual((commands[2]["list_id"], commands[2]["status"]), ("history", "any"))
        self.assertEqual((commands[3]["list_id"], commands[3]["project_name"]), (None, "Geografía"))
        self.assertEqual((commands[3]["person_id"], commands[3]["person_name"]), (None, "Jordi"))
        self.assertEqual(commands[3]["issues"], ["project_not_available", "member_not_available"])

    def test_update_returns_only_what_was_asked_with_resolved_people(self):
        commands = self.extract({"commands": [
            {"kind": "update", "target": {"words": ["informe"], "project_name": "Física"},
             "changes": {"assignee": "member", "member_name": "Anita", "priority": 3, "time": "18:00",
                         "notes_append": "Añadir las gráficas."}},
            {"kind": "update", "target": {"words": ["reunión"]},
             "changes": {"title": "Reunión con el tutor", "deadline_date": "2026-11-02", "deadline_time": "17:00:00"}},
            {"kind": "update", "target": {"words": ["dentista"]}, "changes": {"clear": ["time", "deadline"]}},
            {"kind": "update", "target": {"words": ["dentista"]}, "changes": {"clear": ["date"], "time": "10:00"}},
            {"kind": "update", "target": {"words": ["compra"]}, "changes": {"assignee": "me"}},
            {"kind": "update", "target": {"words": ["compra"]}, "changes": {"assignee": "nobody"}},
            {"kind": "update", "target": {"words": ["compra"]}, "changes": {"assignee": "member", "member_name": "Jordi"}},
            {"kind": "update", "target": {"words": ["compra"]}},
        ]})["commands"]
        self.assertEqual(commands[0]["target"], {"words": ["informe"], "list_id": "physics", "project_name": None, "date": None})
        self.assertEqual(commands[0]["changes"], {"time": "18:00", "priority": 3, "notes_append": "Añadir las gráficas.",
                                                  "assignee_id": 2, "assignee_name": "Ana García"})
        self.assertEqual(commands[1]["changes"], {"title": "Reunión con el tutor", "deadline_date": "2026-11-02",
                                                  "deadline_time": "17:00"})
        self.assertEqual(commands[2]["changes"], {"time": None, "deadline_date": None, "deadline_time": None})
        # Without a day there is no time: the contradictory time is dropped.
        self.assertEqual(commands[3]["changes"], {"date": None, "time": None})
        self.assertEqual(commands[4]["changes"], {"assignee_id": 1, "assignee_name": "Miki"})
        self.assertEqual(commands[5]["changes"], {"assignee_id": None, "assignee_name": None})
        self.assertEqual((commands[6]["changes"], commands[6]["issues"]), ({"assignee_name": "Jordi"}, ["member_not_available"]))
        self.assertEqual((commands[7]["changes"], commands[7]["issues"]), ({}, []))

    def test_old_apps_get_exactly_todays_answer(self):
        answer = {"tasks": [task(project_name="Química")], "commands": [{"kind": "find", "words": ["médico"]}]}
        result = self.extract(answer, commands=False)
        self.assertEqual(set(result), {"tasks", "transcript"})
        self.assertNotIn("new_project", result["tasks"][0])
        self.assertNotIn("project_suggestion", result["tasks"][0])
        self.assertEqual(self.provider.call_args.kwargs, {})  # Today's call: the prompt alone.
        self.assertNotIn("commands array", self.provider.call_args.args[0])
        # A commands-only answer is no answer for an old app, as before.
        with self.assertRaises(ValidationError):
            self.extract({"tasks": [], "commands": [{"kind": "delete", "target": {"words": ["médico"]}}]}, commands=False)

    def test_targets_and_tasks_follow_the_same_near_spelling_limits(self):
        context = {"user_id": 1, "user_name": "Miki", "default_project_id": None, "projects": [
            {"id": "music", "name": "Música", "group_name": None, "shared": False, "people": []},
            {"id": "maths", "name": "Matemáticas", "group_name": None, "shared": False, "people": []}],
            "view_only_projects": [{"id": "history", "name": "Historia", "group_name": None, "shared": True, "people": []}]}
        result = self.extract({"tasks": [task(project_name="Física")], "commands": [
            {"kind": "find", "words": ["examen"], "project_name": "Física"},
            {"kind": "update", "target": {"words": ["examen"], "project_name": "Matemátcas"}, "changes": {"priority": 3}},
            {"kind": "delete", "target": {"words": ["examen"], "project_name": "Fisica"}},
            {"kind": "find", "words": ["examen"], "project_name": "Histroia"},
            {"kind": "delete", "target": {"words": ["examen"], "project_name": "Victoria"}}]}, context)
        find, update, delete, history, victoria = result["commands"]
        self.assertEqual((find["list_id"], find["project_name"], find["issues"]), (None, "Física", ["project_not_available"]))
        self.assertEqual((update["target"]["list_id"], update["issues"]), ("maths", []))
        self.assertEqual((delete["target"]["list_id"], delete["target"]["project_name"]), (None, "Fisica"))
        self.assertEqual(delete["issues"], ["project_not_available"])
        self.assertEqual(history["list_id"], "history")
        self.assertEqual((victoria["target"]["list_id"], victoria["issues"]), (None, ["project_not_available"]))
        draft = result["tasks"][0]
        self.assertEqual((draft["list_id"], draft["assignment_issues"], draft["project_suggestion"]),
                         (None, ["project_not_available"], "Física"))

    def test_the_model_cannot_choose_ids(self):
        commands = self.extract({"commands": [
            {"kind": "find", "words": ["x"], "list_id": "secret", "person_id": 99, "project_name": "Nope"},
            {"kind": "delete", "target": {"words": ["x"], "list_id": "secret"}},
            {"kind": "project", "name": "Nuevo", "existing_list_id": "secret"}]})["commands"]
        self.assertEqual((commands[0]["list_id"], commands[0]["person_id"]), (None, None))
        self.assertIsNone(commands[1]["target"]["list_id"])
        self.assertIsNone(commands[2]["existing_list_id"])


class CommandFormatSlipTests(SimpleTestCase):
    def validate(self, answer):
        return validate_draft(json.dumps(answer, ensure_ascii=False), commands=True)

    def test_commands_written_as_tasks_or_tasks_written_as_commands_are_moved(self):
        result = self.validate({"tasks": [{"kind": "delete", "target": {"words": ["médico"]}}, task()],
                                "commands": [task(title="Comprar pan"), {"kind": "find", "words": ["pan"]}]})
        self.assertEqual([item.title for item in result.tasks], ["Terminar la presentación", "Comprar pan"])
        self.assertEqual([item.kind for item in result.commands], ["delete", "find"])

    def test_envelopes_in_arrays_bare_lists_and_single_items(self):
        self.assertEqual(self.validate([{"commands": [{"kind": "find", "words": ["pan"]}]}]).commands[0].words, ["pan"])
        self.assertEqual(len(self.validate([task(), {"kind": "find", "words": "pan"}]).commands), 1)
        self.assertEqual(self.validate({"kind": "project", "name": "Música"}).commands[0].name, "Música")
        self.assertEqual(self.validate({"commands": [{"kind": "project", "name": "Música"}]}).tasks, [])
        self.assertEqual(self.validate(task()).tasks[0].title, "Terminar la presentación")

    def test_objects_where_strings_belong_and_other_names_for_the_same_thing(self):
        result = self.validate({"commands": [
            {"kind": "create_project", "name": {"name": "Música"}},
            {"kind": "Search", "words": [{"word": "pan"}, "  ", "pan", "leche"], "project_name": ["Física"],
             "status": "all", "from_date": "", "to_date": None},
            {"kind": "remove", "words": ["médico"], "date": "2026-10-21"},
            {"kind": "update", "words": ["médico"], "date": "2026-10-25", "time": "09:30"},
            {"kind": "project", "project_name": "Arte"},
            {"kind": "update", "target": "dentista", "changes": {"clear": "time", "title": ""}},
        ]})
        project, find, delete, update, art, flat = result.commands
        self.assertEqual((project.kind, project.name), ("project", "Música"))
        self.assertEqual((find.kind, find.words, find.project_name, find.status, find.from_date),
                         ("find", ["pan", "leche"], "Física", "any", None))
        self.assertEqual((delete.kind, delete.target.words, str(delete.target.date)), ("delete", ["médico"], "2026-10-21"))
        # In a flat update the date is the new one, not the task's current day.
        self.assertIsNone(update.target.date)
        self.assertEqual((str(update.changes.date), str(update.changes.time)), ("2026-10-25", "09:30:00"))
        self.assertEqual(art.name, "Arte")
        self.assertEqual((flat.target.words, flat.changes.clear, flat.changes.title), (["dentista"], ["time"], None))

    def test_a_search_written_like_an_update(self):
        command = self.validate({"commands": [{"kind": "find", "target": {"words": ["pan"], "project_name": "Física"},
                                               "status": "open"}]}).commands[0]
        self.assertEqual((command.words, command.project_name, command.status), (["pan"], "Física", "open"))
        self.assertIsNone(command.target)

    def test_a_period_said_backwards_is_turned_around(self):
        command = self.validate({"commands": [{"kind": "find", "from": "2026-10-25", "to": "2026-10-19"}]}).commands[0]
        self.assertEqual((str(command.from_date), str(command.to_date)), ("2026-10-19", "2026-10-25"))

    def test_what_stays_invalid(self):
        # An answer with nothing in it is valid since D4: core/test_empty_dictations.py.
        for answer in ({"commands": [{"kind": "project"}]},
                       {"commands": [{"kind": "answer", "text": "Tienes 3 tareas"}]},
                       {"commands": [{"kind": "find", "status": "maybe"}]},
                       {"commands": [{"kind": "update", "target": {"words": ["x"]}, "changes": {"priority": 7}}]},
                       {"commands": [{"kind": "find", "words": ["x"]}] * 13},
                       {"tasks": [task()] * 13}):
            with self.subTest(answer=answer), self.assertRaises(ValidationError):
                self.validate(answer)

    def test_title_polish_keeps_commands_unchanged(self):
        long_title = ("Tener la presentación terminada con todas las diapositivas y que no tenga que utilizar otra cosa "
                      "que no esté ya programada")
        source = {"tasks": [task(title=long_title)], "commands": [{"kind": "find", "words": ["pan"], "status": "open"}]}
        repaired = {"tasks": [task(title="Terminar la presentación")]}
        with patch("core.ai._generate_once", side_effect=[json.dumps(source), json.dumps(repaired)]) as provider:
            result = validate_draft(_generate_reviewable_once("Words", 10000, commands=True), commands=True)
        self.assertEqual(provider.call_count, 2)
        self.assertTrue(provider.call_args_list[0].kwargs["commands"])
        self.assertNotIn("commands", provider.call_args_list[1].kwargs)
        self.assertNotIn('"commands"', provider.call_args_list[1].args[0])
        self.assertEqual(result.tasks[0].title, "Terminar la presentación")
        self.assertEqual((result.commands[0].words, result.commands[0].status), (["pan"], "open"))


class CommandPromptAndSchemaTests(SimpleTestCase):
    def prompt(self, commands):
        return build_prompt({"text": "Borra la tarea del médico", "timezone": ZONE, "reference_time": REFERENCE,
                             "collaboration_context": directory(), "commands": commands})

    def test_the_commands_section_is_only_for_apps_that_ask(self):
        with_commands, without = self.prompt(True), self.prompt(False)
        self.assertIn("Return only a JSON object with a tasks array and a commands array.", with_commands)
        self.assertIn("Return only a JSON object with a tasks array. Each task has title", without)
        for text in ("kind 'project'", "kind 'find'", "kind 'update'", "kind 'delete'", "Never answer",
                     "When the words hold only commands, return an empty tasks array."):
            self.assertIn(text, with_commands)
            self.assertNotIn(text, without)

    def test_examples_in_spanish_catalan_and_english_with_this_references_dates(self):
        prompt = self.prompt(True)
        for example in ("Crea un proyecto de matemáticas y añade terminar la presentación para el 12",
                        "Busca la tarea de la introducción del proyecto de matemáticas",
                        "Ensenya'm les tasques pendents de la Marta", "Who had the report task?",
                        "Cambia la cita del médico de dentro de tres días a dentro de una semana",
                        "Mou la reunió de demà a les sis de la tarda", "Give the report task to Paul",
                        "Borra la tarea del médico", "Elimina la tasca de comprar el pa", "Delete the dentist task"):
            self.assertIn(example, prompt)
        # The 12th has passed on 18 October, so «para el 12» is 12 November.
        self.assertIn('"deadline_date":"2026-11-12"', prompt)
        self.assertIn('"date":"2026-10-21"},"changes":{"date":"2026-10-25"}', prompt)
        self.assertIn('{"words":["reunió"],"date":"2026-10-19"}', prompt)

    def test_group_project_and_list_mean_a_project_in_every_dictation(self):
        for prompt in (self.prompt(True), self.prompt(False)):
            self.assertIn("'grupo', 'proyecto' and 'lista' (Catalan 'grup', 'projecte', 'llista'; English 'group', "
                          "'project', 'list') all mean a project", prompt)

    def test_vertex_schemas_are_todays_without_commands_and_accepted_by_the_sdk_with_them(self):
        old, new = vertex_response_schema(), vertex_response_schema(True)
        self.assertEqual(set(old["properties"]), {"tasks"})
        self.assertEqual(set(new["properties"]), {"tasks", "commands"})
        command = new["$defs"]["ExtractedCommand"]["properties"]
        self.assertEqual(command["kind"]["enum"], ["project", "find", "update", "delete", "complete", "reopen"])
        self.assertIn("from_date", command)
        self.assertNotIn("enum", new["$defs"]["CommandChanges"]["properties"]["priority"]["anyOf"][0])
        for schema in (old, new):
            converted = _transformers.t_schema(None, deepcopy(schema))
            self.assertEqual(converted.type.value, "OBJECT")
        commands = _transformers.t_schema(None, deepcopy(new)).properties["commands"]
        self.assertEqual(commands.items.properties["kind"].enum, ["project", "find", "update", "delete", "complete", "reopen"])


@override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
class CommandEndpointTests(TestCase):
    def setUp(self):
        cache.clear()
        throttle = patch.object(views.DraftView, "throttle_classes", [])
        throttle.start()
        self.addCleanup(throttle.stop)
        self.owner = User.objects.create_user("commands-owner@example.invalid", "Fixture-passphrase!2026", first_name="Miki")
        self.paul = User.objects.create_user("commands-paul@example.invalid", "Fixture-passphrase!2026", first_name="Paul")
        self.physics = TaskList.objects.create(owner=self.owner, name="Física", shared=True)
        ListMembership.objects.create(task_list=self.physics, user=self.paul, role="editor")
        teacher = User.objects.create_user("commands-teacher@example.invalid", "Fixture-passphrase!2026", first_name="Marta")
        self.history = TaskList.objects.create(owner=teacher, name="Historia", shared=True)
        ListMembership.objects.create(task_list=self.history, user=self.owner, role="viewer")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def dictate(self, answer, path="/api/ai/drafts/", **fields):
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)) as provider:
            response = self.client.post(path, {"text": "Synthetic dictation", "timezone": ZONE, **fields}, format="json")
        self.provider = provider
        return response

    def mixed(self):
        return {"commands": [{"kind": "project", "name": "Matemáticas"},
                             {"kind": "find", "words": ["examen"], "project_name": "Historia"},
                             {"kind": "update", "target": {"words": ["informe"], "project_name": "Física"},
                              "changes": {"assignee": "member", "member_name": "Pau"}}],
                "tasks": [task(project_name="Matemáticas"), task(title="Repasar", project_name="mates")]}

    def test_the_new_app_gets_commands_and_one_dictation_counts_once(self):
        response = self.dictate(self.mixed(), commands=True)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual([command["kind"] for command in response.data["commands"]], ["project", "find", "update"])
        self.assertEqual(response.data["commands"][1]["list_id"], str(self.history.pk))  # Viewers can still find.
        self.assertEqual(response.data["commands"][2]["target"]["list_id"], str(self.physics.pk))
        self.assertEqual(response.data["commands"][2]["changes"], {"assignee_id": self.paul.pk, "assignee_name": "Paul"})
        self.assertEqual([draft["new_project"] for draft in response.data["tasks"]], ["Matemáticas", "Matemáticas"])
        self.assertEqual(response.data["free_voice"]["left"], 9)
        self.assertEqual(FreeDictation.objects.filter(user=self.owner, counted=True).count(), 1)
        self.assertEqual(Task.objects.count(), 0)  # Nothing is created, changed or deleted by a draft.
        self.assertFalse(TaskList.objects.filter(name="Matemáticas").exists())
        prompt = self.provider.call_args.args[0]
        self.assertIn("commands array", prompt)
        self.assertNotIn("Historia", prompt)  # View-only projects are never shown to the model.

    def test_a_dictation_of_only_a_search_counts_once_too(self):
        response = self.dictate({"tasks": [], "commands": [{"kind": "find", "words": ["examen"]}]}, commands=True)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["tasks"], [])
        self.assertEqual(response.data["free_voice"]["left"], 9)

    def test_without_the_flag_the_answer_is_exactly_todays(self):
        for fields in ({}, {"commands": False}):
            response = self.dictate(self.mixed(), **fields)
            self.assertEqual(response.status_code, 200, response.data)
            self.assertNotIn("commands", response.data)
            self.assertEqual(set(response.data), {"tasks", "transcript", "timings", "free_voice"})
            self.assertTrue(all("new_project" not in draft for draft in response.data["tasks"]))
            self.assertNotIn("commands array", self.provider.call_args.args[0])
        self.assertEqual(FreeDictation.objects.filter(user=self.owner, counted=True).count(), 2)

    def test_a_single_draft_ignores_the_flag(self):
        response = self.dictate({"tasks": [task()]}, path="/api/ai/draft/", commands=True)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertNotIn("commands", response.data)
        self.assertEqual(response.data["title"], "Terminar la presentación")

    def test_a_note_capture_has_an_empty_commands_list(self):
        response = self.client.post("/api/ai/drafts/", {"text": "Código de la puerta 1234", "timezone": ZONE,
                                                        "capture_type": "note", "commands": True}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["commands"], [])
        self.assertEqual(response.data["tasks"][0]["kind"], "note")
        self.assertIsNone(response.data["tasks"][0]["new_project"])

    def test_an_invalid_answer_never_counts(self):
        # A kind that doesn't exist: the model answered instead of returning a command.
        response = self.dictate({"commands": [{"kind": "answer", "text": "Tienes 3 tareas"}]}, commands=True)
        self.assertEqual(response.status_code, 502)
        self.assertFalse(FreeDictation.objects.exists())

    def test_a_multipart_recording_can_ask_for_commands(self):
        data = {"text": "Synthetic dictation", "timezone": ZONE, "commands": "true"}
        with patch("core.ai.generate", return_value=json.dumps({"commands": [{"kind": "find", "words": ["pan"]}]})):
            response = self.client.post("/api/ai/drafts/", data, format="multipart")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["commands"][0]["words"], ["pan"])

    def test_a_group_project_is_found_by_its_groups_name(self):
        group = TaskGroup.objects.create(owner=self.owner, name="Coro")
        GroupMembership.objects.create(group=group, user=self.paul, role="editor")
        songs = TaskList.objects.create(owner=self.owner, group=group, name="Canciones", shared=True)
        response = self.dictate({"tasks": [task(project_name="el grupo Coro")]}, commands=True)
        self.assertEqual(response.data["tasks"][0]["list_id"], str(songs.pk))

    @patch("core.ai.transcribe", return_value="Busca el examen")
    def test_make_drafts_passes_the_flag_only_for_batches(self, transcription):
        context = {"user_id": self.owner.pk, "default_project_id": None, "projects": []}
        data = {"audio": object(), "timezone": ZONE, "reference_time": REFERENCE, "collaboration_context": context,
                "commands": True}
        with patch("core.ai.generate", return_value=json.dumps({"commands": [{"kind": "find", "words": ["examen"]}]})):
            self.assertEqual(make_drafts(data)["commands"][0]["kind"], "find")
        with patch("core.ai.generate", return_value=json.dumps({"commands": [{"kind": "find", "words": ["examen"]}]})):
            with self.assertRaises(AIUnavailable):
                make_drafts({**data, "commands": False})  # An old app's answer must hold a task.
