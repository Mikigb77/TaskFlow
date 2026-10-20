"""project_candidates: the projects behind an "ambiguous_project", best first (UX-1315)."""
import json
from datetime import datetime, timezone
from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from rest_framework.test import APIClient

from . import views
from .ai import extract_tasks
from .capture_context import pick_project, ranked, resolve_project
from .models import TaskList, User

REFERENCE = datetime(2026, 10, 20, 9, tzinfo=timezone.utc)


def project(key, name, group=None):
    return {"id": key, "name": name, "group_name": group, "shared": False, "people": []}


def maths():
    return [project("physics", "Física"), project("maths-2", "Matemáticas II"), project("maths", "Matemáticas")]


def candidate(key, name):
    return {"id": key, "name": name}


class CandidateTests(SimpleTestCase):
    def test_mates_offers_matematicas_then_matematicas_ii(self):
        selected, issue, candidates = resolve_project("Mates", None, maths())
        self.assertEqual((selected, issue), (None, "ambiguous_project"))
        self.assertEqual(candidates, [candidate("maths", "Matemáticas"), candidate("maths-2", "Matemáticas II")])
        self.assertEqual(pick_project("Mates", None, maths()), (None, "ambiguous_project"))  # unchanged

    def test_at_most_three_closest_first(self):
        projects = [project(str(number), name) for number, name in enumerate(
            ("Matemáticas avanzadas de segundo", "Matemáticas I", "Matemáticas II", "Matemáticas III", "Mate"))]
        _, issue, candidates = resolve_project("mates", None, projects)
        self.assertEqual(issue, "ambiguous_project")
        self.assertEqual([item["name"] for item in candidates], ["Mate", "Matemáticas I", "Matemáticas II"])

    def test_a_near_spelling_ranks_by_letters_changed(self):
        self.assertEqual(ranked("Histria", ["Histeria", "Historia"], lambda name: name), ["Histeria", "Historia"])
        self.assertEqual(ranked("Histroia", ["Histeria", "Historia"], lambda name: name), ["Historia", "Histeria"])

    def test_one_match_or_none_has_no_candidates(self):
        self.assertEqual(resolve_project("matemáticas ii", None, maths())[1:], (None, []))
        self.assertEqual(resolve_project("Química", None, maths())[1:], ("project_not_available", []))

    def test_a_group_with_several_projects_offers_them(self):
        projects = [project("algebra", "Álgebra", group="Máster"), project("geometry", "Geometría", group="Máster"),
                    project("songs", "Canciones", group="Coro")]
        _, issue, candidates = resolve_project("el grupo master", None, projects)
        self.assertEqual(issue, "ambiguous_project")
        self.assertEqual(candidates, [candidate("algebra", "Álgebra"), candidate("geometry", "Geometría")])
        self.assertEqual(resolve_project(None, "master", projects)[2], candidates)

    def test_two_groups_that_match_offer_the_project_said_in_each(self):
        projects = [project("a1", "Álgebra", group="Máster A"), project("a2", "Geometría", group="Máster A"),
                    project("b1", "Álgebra", group="Máster B"), project("b2", "Estadística", group="Máster B")]
        _, issue, candidates = resolve_project("álgebra", "máster", projects)
        self.assertEqual(issue, "ambiguous_project")
        self.assertEqual(candidates, [candidate("a1", "Álgebra"), candidate("b1", "Álgebra")])

    def test_a_project_created_in_the_same_dictation_has_no_id_to_offer(self):
        created = [{"id": None, "name": "Mates", "group_name": None, "shared": False, "people": []}]
        _, issue, candidates = resolve_project("mate", None, maths(), created)
        self.assertEqual(issue, "ambiguous_project")
        self.assertEqual(candidates, [candidate("maths", "Matemáticas"), candidate("maths-2", "Matemáticas II")])


class DictationCandidateTests(SimpleTestCase):
    def directory(self):
        return {"user_id": 1, "user_name": "Miki", "default_project_id": None, "projects": maths(),
                "view_only_projects": [project("history", "Historia")]}

    def extract(self, answer, commands=True):
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)):
            return extract_tasks("Synthetic dictation", "Europe/Madrid", REFERENCE, self.directory(), commands=commands)

    def test_tasks_and_every_command_kind_carry_them_beside_the_issue(self):
        both = [candidate("maths", "Matemáticas"), candidate("maths-2", "Matemáticas II")]
        result = self.extract({"tasks": [{"title": "Repasar", "date": None, "time": None, "priority": 1,
                                          "project_name": "mates"}],
                               "commands": [{"kind": "project", "name": "Mates"},
                                            {"kind": "find", "words": ["examen"], "project_name": "mates"},
                                            {"kind": "update", "target": {"words": ["examen"], "project_name": "mates"},
                                             "changes": {"priority": 3}},
                                            {"kind": "delete", "target": {"words": ["examen"], "project_name": "mates"}}]})
        draft = result["tasks"][0]
        # The task names the project this dictation creates, «Mates» exactly: nothing to ask.
        self.assertEqual((draft["list_id"], draft["assignment_issues"]), (None, []))
        self.assertEqual(draft["new_project"], "Mates")
        self.assertNotIn("project_candidates", draft)
        project_command, find, update, delete = result["commands"]
        self.assertEqual((project_command["issues"], project_command["project_candidates"]), (["ambiguous_project"], both))
        self.assertEqual((find["issues"], find["project_name"], find["project_candidates"]), (["ambiguous_project"], "mates", both))
        for command in (update, delete):
            self.assertEqual(command["issues"], ["ambiguous_project"])
            self.assertEqual(command["target"]["project_candidates"], both)

    def test_a_task_naming_an_ambiguous_project(self):
        draft = self.extract({"tasks": [{"title": "Repasar", "date": None, "time": None, "priority": 1,
                                         "project_name": "mates"}]})["tasks"][0]
        self.assertEqual(draft["assignment_issues"], ["ambiguous_project"])
        self.assertEqual(draft["project_candidates"],
                         [candidate("maths", "Matemáticas"), candidate("maths-2", "Matemáticas II")])

    def test_resolved_and_unknown_projects_have_none(self):
        result = self.extract({"tasks": [{"title": "Repasar", "date": None, "time": None, "priority": 1,
                                          "project_name": "física"},
                                         {"title": "Leer", "date": None, "time": None, "priority": 1,
                                          "project_name": "Química"}],
                               "commands": [{"kind": "find", "words": ["examen"], "project_name": "historia"}]})
        for item in result["tasks"] + result["commands"]:
            self.assertNotIn("project_candidates", item)

    def test_old_apps_get_exactly_todays_drafts(self):
        draft = self.extract({"tasks": [{"title": "Repasar", "date": None, "time": None, "priority": 1,
                                         "project_name": "mates"}]}, commands=False)["tasks"][0]
        self.assertEqual(draft["assignment_issues"], ["ambiguous_project"])
        self.assertNotIn("project_candidates", draft)


@override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
class CandidateEndpointTests(TestCase):
    def test_the_ids_are_the_persons_own_projects(self):
        cache.clear()
        throttle = patch.object(views.DraftView, "throttle_classes", [])
        throttle.start()
        self.addCleanup(throttle.stop)
        owner = User.objects.create_user("candidates@example.invalid", "Candidate-passphrase!2026")
        first = TaskList.objects.create(owner=owner, name="Matemáticas")
        second = TaskList.objects.create(owner=owner, name="Matemáticas II")
        stranger = User.objects.create_user("stranger@example.invalid", "Candidate-passphrase!2026")
        TaskList.objects.create(owner=stranger, name="Matemáticas III")  # someone else's: never offered
        client = APIClient()
        client.force_authenticate(owner)
        answer = {"tasks": [{"title": "Repasar", "date": None, "time": None, "priority": 1, "project_name": "Mates"}]}
        with patch("core.ai.generate", return_value=json.dumps(answer)):
            response = client.post("/api/ai/drafts/", {"text": "Repasar para mates", "timezone": "Europe/Madrid",
                                                       "commands": True}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.json()["tasks"][0]["project_candidates"],
                         [{"id": str(first.pk), "name": "Matemáticas"}, {"id": str(second.pk), "name": "Matemáticas II"}])
