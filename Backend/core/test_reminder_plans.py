"""Reminder plans (docs/REMINDER_PLANS.md): each person's own plan on the task API, plans said while
dictating, and «A tu manera», POST /api/ai/reminder-plan/. The model is always mocked."""
import json
import uuid
from copy import deepcopy
from datetime import date, datetime, timezone
from unittest.mock import patch

from django.core.cache import cache
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import SimpleTestCase, TestCase, TransactionTestCase, override_settings
from google.genai import _transformers, errors
from rest_framework.test import APIClient

from . import views
from .account_deletion import delete_account
from .ai import (_generate_reviewable_once, build_plan_prompt, build_prompt, extract_tasks, validate_draft,
                 vertex_plan_schema, vertex_response_schema)
from .models import FreeDictation, ListMembership, Task, TaskEvent, TaskList, TaskNotification, TaskReminderPlan, User
from .reminder_plans import InvalidPlan, check_plan, read_plan

REFERENCE = datetime(2026, 10, 22, 8, tzinfo=timezone.utc)  # Thursday 22 October 2026, 10:00 in Madrid.
ZONE = "Europe/Madrid"
PASSWORD = "Reminder-plan-fixture-2026!"
WORDS = "cada 3 días las dos primeras semanas y luego cada día"
PHASES = [{"from_days": 21, "to_days": 8, "every_days": 3}, {"from_days": 7, "to_days": 0, "every_days": 1}]
RHYTHM = {"kind": "rhythm", "strength": "normal", "time": None}
CUSTOM = {"kind": "custom", "phases": PHASES, "time": "09:00", "said": WORDS}


def phase(start, end, every):
    return {"from_days": start, "to_days": end, "every_days": every}


def custom(**fields):
    return {**deepcopy(CUSTOM), **fields}


# Shapes the contract refuses, each with why.
INVALID = [
    ("not an object", "rhythm"),
    ("a list", [RHYTHM]),
    ("no kind", {"strength": "normal", "time": None}),
    ("another kind", {"kind": "weekly", "time": None}),
    ("a rhythm without its strength", {"kind": "rhythm", "time": None}),
    ("a strength that isn't one", {"kind": "rhythm", "strength": "strong", "time": None}),
    ("a rhythm with phases", {**RHYTHM, "phases": PHASES}),
    ("a rhythm with words", {**RHYTHM, "said": "suave"}),
    ("a custom plan with a strength", custom(strength="normal")),
    ("a custom plan without phases", {"kind": "custom", "time": None}),
    ("no phases", custom(phases=[])),
    ("five phases", custom(phases=[phase(5, 5, 1)] * 5)),
    ("phases that aren't a list", custom(phases=phase(7, 0, 1))),
    ("from_days below to_days", custom(phases=[phase(8, 21, 3)])),
    ("to_days below 0", custom(phases=[phase(7, -1, 1)])),
    ("from_days above 366", custom(phases=[phase(367, 0, 1)])),
    ("every_days 0", custom(phases=[phase(7, 0, 0)])),
    ("every_days above 30", custom(phases=[phase(366, 0, 31)])),
    ("a number as a string", custom(phases=[phase(7, 0, "1")])),
    ("a fraction", custom(phases=[phase(7.5, 0, 1)])),
    ("a boolean", custom(phases=[phase(7, 0, True)])),
    ("a phase missing a key", custom(phases=[{"from_days": 7, "to_days": 0}])),
    ("a phase with another key", custom(phases=[{**phase(7, 0, 1), "hour": 9}])),
    ("a phase that isn't an object", custom(phases=[[7, 0, 1]])),
    ("another key", {**RHYTHM, "repeat": True}),
    ("a time without its leading zero", {**RHYTHM, "time": "9:00"}),
    ("a time past midnight", {**RHYTHM, "time": "24:00"}),
    ("a time as minutes", {**RHYTHM, "time": 540}),
    ("a time with a newline", {**RHYTHM, "time": "09:00\n"}),
    ("too many words", custom(said="x" * 201)),
    ("words that aren't text", custom(said=["cada", "día"])),
]


class PlanShapeTests(SimpleTestCase):
    def test_the_contracts_shapes_are_kept_unchanged(self):
        valid = [
            *({**RHYTHM, "strength": strength} for strength in ("gentle", "normal", "intense")),
            {**RHYTHM, "time": "07:30"},
            {"kind": "rhythm", "strength": "intense"},  # A missing time is null: the all-day time in Settings.
            CUSTOM,
            custom(time=None, said=None),
            {"kind": "custom", "phases": [phase(1, 1, 1)], "time": "09:00"},  # said is optional.
            custom(phases=[phase(366, 0, 30), phase(0, 0, 1), phase(14, 7, 1), phase(3, 3, 1)], said="x" * 200),
            custom(time="23:59"),
        ]
        for plan in valid:
            with self.subTest(plan=plan):
                self.assertEqual(check_plan(deepcopy(plan)), plan)
        self.assertIsNone(check_plan(None))

    def test_anything_else_is_refused_with_its_reason(self):
        for reason, plan in INVALID:
            with self.subTest(reason), self.assertRaises(InvalidPlan) as refused:
                check_plan(deepcopy(plan))
            self.assertTrue(str(refused.exception))


class ReminderPlanFieldTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("plan-owner@example.invalid", PASSWORD)
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.path = f"/api/tasks/{uuid.uuid4()}/"
        self.task = {"title": "Presentar el proyecto", "scheduled_date": "2026-11-12", "version": 0}

    def put(self, path=None, **fields):
        return self.client.put(path or self.path, {**self.task, **fields}, format="json")

    def test_a_plan_round_trips_through_the_task_api_and_sync(self):
        created = self.put(reminder_plan=CUSTOM)
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(created.data["reminder_plan"], CUSTOM)
        self.assertEqual(self.client.get(self.path).data["reminder_plan"], CUSTOM)
        listed = self.client.get("/api/tasks/").data["results"]
        self.assertEqual([task["reminder_plan"] for task in listed], [CUSTOM])
        # Only the plan changes: the task keeps its version.
        changed = self.put(reminder_plan=RHYTHM, version=1)
        self.assertEqual((changed.status_code, changed.data["reminder_plan"], changed.data["version"]),
                         (200, RHYTHM, 1))
        cleared = self.put(reminder_plan=None, version=1)
        self.assertEqual((cleared.status_code, cleared.data["reminder_plan"]), (200, None))
        self.assertFalse(TaskReminderPlan.objects.exists())

    def test_without_a_plan_a_task_has_null(self):
        created = self.put()
        self.assertEqual(created.status_code, 201, created.data)
        self.assertIsNone(created.data["reminder_plan"])
        self.assertIsNone(self.client.post("/api/tasks/", {"title": "Comprar pan"}, format="json").data["reminder_plan"])

    def test_an_app_that_doesnt_send_the_plan_keeps_it(self):
        self.assertEqual(self.put(reminder_plan=CUSTOM).status_code, 201)
        older = self.put(title="Presentar el proyecto final", version=1)
        self.assertEqual(older.status_code, 200, older.data)
        self.assertEqual((older.data["reminder_plan"], older.data["version"]), (CUSTOM, 2))

    def test_a_stale_version_still_saves_the_plan_and_the_conflict_carries_it(self):
        # Nobody else can have changed the plan, so the app's 409 compares equal on it.
        self.assertEqual(self.put(reminder_plan=CUSTOM).status_code, 201)
        self.assertEqual(self.put(title="Presentar el proyecto final", version=1).status_code, 200)
        conflict = self.put(reminder_plan=RHYTHM, version=1)
        self.assertEqual(conflict.status_code, 409)
        self.assertEqual(conflict.data["current"]["reminder_plan"], RHYTHM)
        self.assertEqual(self.client.get(self.path).data["reminder_plan"], RHYTHM)

    def test_the_single_reminder_is_left_as_it_is_beside_a_plan(self):
        created = self.put(reminder_plan=RHYTHM, reminder_minutes=30, reminder_time=540)
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual((created.data["reminder_minutes"], created.data["reminder_time"],
                          created.data["reminder_plan"]), (30, 540, RHYTHM))

    def test_an_invalid_plan_is_a_400_on_the_field(self):
        for reason, plan in INVALID:
            with self.subTest(reason):
                refused = self.put(path=f"/api/tasks/{uuid.uuid4()}/", reminder_plan=plan)
                self.assertEqual(refused.status_code, 400, refused.data)
                self.assertEqual(list(refused.data), ["reminder_plan"])
        self.assertFalse(Task.objects.exists())

    def test_notes_cannot_have_a_plan(self):
        note = {"kind": "note", "title": "Ideas para la presentación", "version": 0}
        for plan in (RHYTHM, CUSTOM):
            refused = self.client.put(f"/api/tasks/{uuid.uuid4()}/", {**note, "reminder_plan": plan}, format="json")
            self.assertEqual(refused.status_code, 400, refused.data)
            self.assertIn("kind", refused.data)  # The note rule, as for a note's other reminders.
        path = f"/api/tasks/{uuid.uuid4()}/"
        created = self.client.put(path, {**note, "reminder_plan": None}, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        self.assertIsNone(created.data["reminder_plan"])
        later = self.client.put(path, {**note, "version": 1, "reminder_plan": RHYTHM}, format="json")
        self.assertEqual(later.status_code, 400, later.data)
        self.assertFalse(TaskReminderPlan.objects.exists())


class PersonalPlanTests(TestCase):
    """D6: a plan rings only for the person who set it, and each member can have their own. The
    owner's example: a math group's «Terminar la presentación», where Ana asks for reminders."""

    def setUp(self):
        cache.clear()
        self.ana = User.objects.create_user("ana-plans@example.invalid", PASSWORD, first_name="Ana")
        self.marc = User.objects.create_user("marc-plans@example.invalid", PASSWORD, first_name="Marc")
        self.project = TaskList.objects.create(owner=self.ana, name="Grupo de mates", shared=True)
        ListMembership.objects.create(task_list=self.project, user=self.marc, role="editor")
        self.path = f"/api/tasks/{uuid.uuid4()}/"
        self.task = {"title": "Terminar la presentación", "scheduled_date": "2026-10-29",
                     "list_id": str(self.project.pk), "assignment": "group"}

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def put(self, user, version, **fields):
        return self.client_for(user).put(self.path, {**self.task, "version": version, **fields}, format="json")

    def plan_seen_by(self, user):
        return self.client_for(user).get(self.path).data["reminder_plan"]

    def test_each_member_sees_and_sets_only_their_own_plan(self):
        created = self.put(self.ana, 0, reminder_plan=CUSTOM)
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual((self.plan_seen_by(self.ana), self.plan_seen_by(self.marc)), (CUSTOM, None))
        listed = self.client_for(self.marc).get("/api/tasks/").data["results"]
        self.assertEqual([task["reminder_plan"] for task in listed], [None])
        mine = self.put(self.marc, 1, reminder_plan=RHYTHM)
        self.assertEqual((mine.status_code, mine.data["reminder_plan"]), (200, RHYTHM))
        self.assertEqual((self.plan_seen_by(self.ana), self.plan_seen_by(self.marc)), (CUSTOM, RHYTHM))
        # Marc removes his, and Ana's stays; an app that doesn't send the key changes neither.
        self.assertEqual(self.put(self.marc, 1, reminder_plan=None).status_code, 200)
        self.assertEqual(self.put(self.marc, 1, title="Terminar la presentación de mates").status_code, 200)
        self.assertEqual((self.plan_seen_by(self.ana), self.plan_seen_by(self.marc)), (CUSTOM, None))

    def test_a_change_to_a_plan_alone_is_not_a_change_to_the_task(self):
        self.assertEqual(self.put(self.ana, 0).status_code, 201)
        events, told = TaskEvent.objects.count(), TaskNotification.objects.filter(recipient=self.ana).count()
        changed = self.put(self.marc, 1, reminder_plan=RHYTHM)
        self.assertEqual((changed.status_code, changed.data["version"]), (200, 1))
        self.assertEqual(Task.objects.get().version, 1)
        self.assertEqual(TaskEvent.objects.count(), events)
        self.assertEqual(TaskNotification.objects.filter(recipient=self.ana).count(), told)
        # A real change still makes a version and tells the others, and leaves the plans alone.
        renamed = self.put(self.marc, 1, title="Terminar la presentación de mates")
        self.assertEqual(renamed.data["version"], 2)
        self.assertEqual(TaskNotification.objects.filter(recipient=self.ana).count(), told + 1)
        self.assertEqual((self.plan_seen_by(self.marc), self.plan_seen_by(self.ana)), (RHYTHM, None))

    def test_the_whole_task_sent_back_with_a_plan_changes_only_the_plan(self):
        # The app sends every field it has, as the API gave them.
        created = self.put(self.ana, 0, due_date="2026-10-29T17:00:00+01:00", scheduled_date=None,
                           deadline_date="2026-10-30", duration_minutes=45, priority=3, labels=["Mates"],
                           notes="Diapositivas 3 a 7", reminder_minutes=30,
                           checklist=[{"id": str(uuid.uuid4()), "title": "Gráficas", "completed": True,
                                       "completed_dates": []}])
        self.assertEqual(created.status_code, 201, created.data)
        sent = self.client_for(self.ana).put(self.path, {**created.data, "reminder_plan": RHYTHM}, format="json")
        self.assertEqual((sent.status_code, sent.data["version"], sent.data["reminder_plan"]), (200, 1, RHYTHM))

    def test_an_unchanged_task_sent_again_is_not_a_new_version(self):
        created = self.put(self.ana, 0)
        again = self.client_for(self.ana).put(self.path, created.data, format="json")
        self.assertEqual((again.status_code, again.data["version"]), (200, 1))
        self.assertEqual(TaskEvent.objects.count(), 1)

    def test_a_deleted_account_takes_only_its_own_plans(self):
        self.put(self.ana, 0, reminder_plan=CUSTOM)
        self.put(self.marc, 1, reminder_plan=RHYTHM)
        delete_account(self.marc)
        self.assertEqual(list(TaskReminderPlan.objects.values_list("user_id", "plan")), [(self.ana.pk, CUSTOM)])
        self.assertEqual(self.plan_seen_by(self.ana), CUSTOM)


class PersonalPlansMigrationTests(TransactionTestCase):
    """Migration 0024: a plan set on a task before D6 goes to the person whose phone it rang on."""
    before = [("core", "0023_task_reminder_plan")]
    after = [("core", "0024_personal_reminder_plans")]

    def migrate(self, target):
        executor = MigrationExecutor(connection)
        executor.loader.build_graph()
        executor.migrate(target)
        return executor.loader.project_state(target).apps

    def test_each_plan_goes_to_the_person_it_rang_for_and_back(self):
        apps = self.migrate(self.before)
        User, Task, TaskList = (apps.get_model("core", name) for name in ("User", "Task", "TaskList"))
        ana, marc, laia = (User.objects.create(email=f"{name}-migration@example.invalid") for name in ("ana", "marc", "laia"))
        project = TaskList.objects.create(owner=ana, name="Grupo", shared=True)
        tasks = {
            "personal": Task.objects.create(owner=ana, created_by=ana, title="Personal", reminder_plan=RHYTHM),
            "given to Marc": Task.objects.create(owner=ana, created_by=laia, title="Marc's", task_list=project,
                                                 assignment="member", assignee=marc, reminder_plan=CUSTOM),
            "Todos, by Laia": Task.objects.create(owner=ana, created_by=laia, title="Todos", task_list=project,
                                                  assignment="group", reminder_plan=RHYTHM),
            "creator deleted": Task.objects.create(owner=ana, created_by=None, title="Heredada", task_list=project,
                                                   assignment="group", reminder_plan=CUSTOM),
            "no plan": Task.objects.create(owner=ana, created_by=ana, title="Sin plan"),
        }
        apps = self.migrate(self.after)
        rows = {(row.task_id, row.user_id): row.plan for row in apps.get_model("core", "TaskReminderPlan").objects.all()}
        self.assertEqual(rows, {
            (tasks["personal"].pk, ana.pk): RHYTHM,
            (tasks["given to Marc"].pk, marc.pk): CUSTOM,
            (tasks["Todos, by Laia"].pk, laia.pk): RHYTHM,
            (tasks["creator deleted"].pk, ana.pk): CUSTOM,
        })
        apps.get_model("core", "TaskReminderPlan").objects.create(task_id=tasks["given to Marc"].pk, user_id=ana.pk,
                                                                   plan=RHYTHM)
        apps = self.migrate(self.before)  # Back: the plan of the person it rang for wins.
        back = dict(apps.get_model("core", "Task").objects.values_list("title", "reminder_plan"))
        self.assertEqual(back, {"Personal": RHYTHM, "Marc's": CUSTOM, "Todos": RHYTHM, "Heredada": CUSTOM,
                                "Sin plan": None})
        self.migrate(MigrationExecutor(connection).loader.graph.leaf_nodes())


def task(**fields):
    return {"title": "Presentar el proyecto", "date": None, "time": None, "priority": 1, **fields}


class DictatedPlanTests(SimpleTestCase):
    def extract(self, *tasks, commands=True):
        answer = {"tasks": list(tasks), "commands": []} if commands else {"tasks": list(tasks)}
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)):
            result = extract_tasks("Synthetic dictation", ZONE, REFERENCE, None, commands=commands)
        return result["tasks"]

    def test_a_rhythm_said_while_dictating_is_the_drafts_plan(self):
        # «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día».
        draft, = self.extract(task(date="2026-11-12", reminder_plan={"phases": PHASES, "time": None, "said": WORDS}))
        self.assertEqual(draft["reminder_plan"], {"kind": "custom", "phases": PHASES, "time": None, "said": WORDS})
        self.assertIsNone(draft["reminder_minutes"])
        self.assertEqual(draft["scheduled_date"], "2026-11-12")
        self.assertEqual(check_plan(draft["reminder_plan"]), draft["reminder_plan"])  # The task API takes it as is.

    def test_a_single_reminder_the_day_before_and_a_plan_counted_from_the_deadline(self):
        before, deadline = self.extract(
            task(title="Pagar el alquiler", date="2026-10-24",
                 reminder_plan={"phases": [phase(1, 1, 1)], "time": "09:00", "said": "el día antes a las 9"}),
            task(title="Entregar l'informe", deadline_date="2026-11-01",
                 reminder_plan={"phases": [phase(366, 0, 2)], "time": None, "said": "cada dos dies"}))
        self.assertEqual(before["reminder_plan"], {"kind": "custom", "phases": [phase(1, 1, 1)], "time": "09:00",
                                                   "said": "el día antes a las 9"})
        self.assertEqual((deadline["deadline_date"], deadline["date"]), ("2026-11-01", None))
        self.assertEqual(deadline["reminder_plan"]["phases"], [phase(366, 0, 2)])

    def test_minutes_before_count_only_from_a_time(self):
        timed, deadline, day_only, nowhere = self.extract(
            task(title="Ir al dentista", date="2026-10-23", time="17:00", reminder_minutes=60),
            task(title="Enviar la solicitud", deadline_date="2026-10-30", deadline_time="17:00", reminder_minutes=30),
            task(title="Llamar al banco", date="2026-10-23", reminder_minutes=60),
            task(title="Comprar pan", reminder_minutes=15))
        self.assertEqual((timed["reminder_minutes"], timed["reminder_plan"]), (60, None))
        # Without a planned day the app counts from the deadline, so its time is enough.
        self.assertEqual(deadline["reminder_minutes"], 30)
        self.assertIsNone(day_only["reminder_minutes"])
        # With no day at all, it waits for the day and time the task gets (D3).
        self.assertEqual((nowhere["reminder_minutes"], nowhere["reminder_needs_day"]), (15, True))
        self.assertEqual([draft["reminder_needs_day"] for draft in (timed, deadline, day_only)], [False] * 3)

    def test_a_reminder_said_without_a_day_waits_for_one(self):
        # D3: «Renovar el pasaporte, recuérdamelo cada semana» keeps its reminders, and the card asks for a day.
        plan = {"phases": [phase(366, 0, 7)], "time": None, "said": "cada semana"}
        nowhere, timeless, deadline, repeating = self.extract(
            task(title="Renovar el pasaporte", reminder_plan=plan),
            task(time="09:00", reminder_plan=plan),  # A time without a day isn't an anchor either.
            task(deadline_date="2026-11-12", reminder_plan=plan),
            task(title="Regar las plantas", date="2026-10-26", recurrence="weekly", reminder_plan=plan))
        kept = {"kind": "custom", "phases": [phase(366, 0, 7)], "time": None, "said": "cada semana"}
        self.assertEqual([(draft["reminder_plan"], draft["reminder_needs_day"]) for draft in (nowhere, timeless, deadline)],
                         [(kept, True), (kept, True), (kept, False)])
        self.assertEqual(check_plan(nowhere["reminder_plan"]), kept)  # The task API takes it once there's a day.
        # A repeating task still has no plan in this first version, and nothing to ask.
        self.assertEqual((repeating["recurrence"], repeating["reminder_plan"], repeating["reminder_needs_day"]),
                         ("weekly", None, False))

    def test_until_the_day_with_no_rhythm_said_is_normal(self):
        # D4: «Terminar la solicitud el jueves y recuérdamelo hasta la fecha límite»: the task's own day is its deadline.
        day_only, with_time, written_as_rhythm, deadline, nowhere = self.extract(
            task(title="Terminar la solicitud", date="2026-10-29", reminder_plan={"strength": "normal", "time": None}),
            task(date="2026-10-29", reminder_plan={"strength": "normal", "time": "9:00"}),
            task(date="2026-10-29", reminder_plan={"kind": "rhythm", "strength": "normal"}),
            task(deadline_date="2026-11-12", reminder_plan={"strength": "normal"}),
            task(reminder_plan={"strength": "normal"}))
        self.assertEqual(day_only["reminder_plan"], RHYTHM)
        self.assertEqual(check_plan(day_only["reminder_plan"]), RHYTHM)
        self.assertEqual(with_time["reminder_plan"], {**RHYTHM, "time": "09:00"})
        self.assertEqual([draft["reminder_plan"] for draft in (written_as_rhythm, deadline)], [RHYTHM, RHYTHM])
        self.assertEqual((nowhere["reminder_plan"], nowhere["reminder_needs_day"]), (RHYTHM, True))
        # Phases said win over a strength the model added; «A tu manera» never reads a strength.
        mixed, = self.extract(task(date="2026-11-12", reminder_plan={"strength": "normal", "phases": PHASES}))
        self.assertEqual(mixed["reminder_plan"], {"kind": "custom", "phases": PHASES, "time": None, "said": None})
        self.assertIsNone(read_plan({"strength": "normal", "time": None}))

    def test_nothing_said_about_reminders_sets_neither(self):
        for commands in (True, False):
            with self.subTest(commands=commands):
                draft, = self.extract(task(date="2026-11-12"), commands=commands)
                self.assertIn("reminder_plan", draft)
                self.assertEqual((draft["reminder_minutes"], draft["reminder_plan"], draft["reminder_needs_day"]),
                                 (None, None, False))
                nowhere, = self.extract(task(), commands=commands)
                self.assertFalse(nowhere["reminder_needs_day"])

    def test_older_apps_get_the_plan_too(self):
        draft, = self.extract(task(date="2026-11-12", reminder_plan={"phases": PHASES}), commands=False)
        self.assertEqual(draft["reminder_plan"], {"kind": "custom", "phases": PHASES, "time": None, "said": None})

    def test_an_invalid_plan_or_lead_is_dropped_not_the_dictation(self):
        plans = [
            "cada tres días",
            {"kind": "rhythm", "strength": "strong"},
            {"phases": []},
            {"phases": [phase(5, 5, 1)] * 5},
            {"phases": [phase(400, 0, 1)]},
            {"phases": [phase(7, 0, 0)]},
            {"phases": [phase(7, 0, 31)]},
            {"phases": [phase(7, -1, 1)]},
            {"phases": [{"from_days": 7, "to_days": 0}]},
            {"phases": [phase(7, 0, "a diario")]},
            {"phases": ["a diario"]},
            {"phases": [phase(7, 0, 1)], "time": "por la mañana"},
            {"phases": [phase(7, 0, 1)], "time": "25:00"},
            {"time": "09:00"},
        ]
        leads = [-1, 0, 20000, "pronto", True, 1.5, [], {}]
        for plan, lead in zip(plans, leads + [None] * (len(plans) - len(leads))):
            with self.subTest(plan=plan, lead=lead):
                draft, = self.extract(task(title="Ir al médico", date="2026-11-12", time="10:00", priority=3,
                                           reminder_plan=plan, reminder_minutes=lead))
                self.assertEqual((draft["title"], draft["priority"]), ("Ir al médico", 3))
                self.assertTrue(draft["due_date"].startswith("2026-11-12T10:00"))
                self.assertEqual((draft["reminder_plan"], draft["reminder_minutes"]), (None, None))

    def test_the_models_slips_are_tolerated(self):
        cases = [
            ({"kind": "custom", "phases": [{"from_days": "21", "to_days": 8.0, "every_days": "3"}], "time": "9:00"},
             {"kind": "custom", "phases": [phase(21, 8, 3)], "time": "09:00", "said": None}),
            ({"phases": [phase(8, 21, 3), phase(0, 7, 1)], "time": "09:00:00"},  # from and to the wrong way round
             {"kind": "custom", "phases": PHASES, "time": "09:00", "said": None}),
            ({"phases": {**phase(1, 1, 1), "note": "el día antes"}, "time": "", "said": "  el  día antes "},
             {"kind": "custom", "phases": [phase(1, 1, 1)], "time": None, "said": "el día antes"}),
            (json.dumps({"phases": PHASES, "said": WORDS}, ensure_ascii=False),
             {"kind": "custom", "phases": PHASES, "time": None, "said": WORDS}),
            # Words too long to show are left out, never cut, and the plan stays.
            ({"phases": PHASES, "said": "x" * 201}, {"kind": "custom", "phases": PHASES, "time": None, "said": None}),
        ]
        drafts = self.extract(*(task(date="2026-11-12", reminder_plan=plan) for plan, _ in cases))
        for draft, (written, expected) in zip(drafts, cases):
            with self.subTest(written=written):
                self.assertEqual(draft["reminder_plan"], expected)
        self.assertEqual(self.extract(task(date="2026-11-12", time="09:00", reminder_minutes="60"))[0]
                         ["reminder_minutes"], 60)

    def test_the_title_polish_keeps_the_plan(self):
        long_title = ("Presentar el proyecto de la empresa delante de todo el equipo directivo con las cifras del "
                      "trimestre y la propuesta")
        plan = {"phases": PHASES, "time": None, "said": WORDS}
        source = {"tasks": [task(title=long_title, date="2026-11-12", reminder_plan=plan)]}
        repaired = {"tasks": [task(title="Presentar el proyecto", date="2026-11-12")]}
        with patch("core.ai._generate_once", side_effect=[json.dumps(source), json.dumps(repaired)]):
            result = validate_draft(_generate_reviewable_once("Words", 10000))
        self.assertEqual(result.tasks[0].title, "Presentar el proyecto")
        self.assertEqual(result.tasks[0].reminder_plan.contract(), {"kind": "custom", **plan})

    def test_vertex_accepts_the_new_fields(self):
        for commands in (False, True):
            schema = vertex_response_schema(commands)
            fields = schema["$defs"]["ExtractedTask"]["properties"]
            self.assertEqual(fields["reminder_minutes"], {"anyOf": [{"type": "integer"}, {"type": "null"}]})
            self.assertEqual(set(schema["$defs"]["ReadPlan"]["properties"]), {"phases", "time", "said", "strength"})
            converted = _transformers.t_schema(None, deepcopy(schema)).properties["tasks"].items
            plan = converted.properties["reminder_plan"]
            self.assertEqual(plan.properties["phases"].items.properties["every_days"].type.value, "INTEGER")
        self.assertEqual(vertex_response_schema()["properties"].keys(), {"tasks"})  # Older apps: still only tasks.
        answer = _transformers.t_schema(None, deepcopy(vertex_plan_schema()))
        self.assertEqual(answer.properties["reminder_plan"].properties["time"].type.value, "STRING")


class DictationPromptTests(SimpleTestCase):
    def prompt(self, reference=REFERENCE, commands=True):
        return build_prompt({"text": WORDS, "timezone": ZONE, "reference_time": reference,
                             "collaboration_context": None, "commands": commands})

    def test_every_dictation_teaches_reminders(self):
        for commands in (True, False):
            with self.subTest(commands=commands):
                text = self.prompt(commands=commands)
                for rule in ("each task also has reminder_minutes and reminder_plan",
                             "'una hora antes' is 60",
                             "its deadline_date when it has one, else its date",
                             "A rhythm also reminds on the day itself, to_days 0, unless the words exclude it",
                             "a single reminder said is just that one",
                             "a repeating task has no reminder_plan",
                             "A task with neither yet still keeps every reminder asked for",
                             'are reminder_plan {"strength":"normal","time":null} with no phases',
                             "Those words name no deadline of their own",
                             "'una semana antes' is {\"from_days\":7,\"to_days\":7,\"every_days\":1}",
                             "'una hora antes' is 60, also for a task said without a time"):
                    self.assertIn(rule, text)
                self.assertLess(text.index("Reminders:"), text.index("User words (JSON string)"))

    def test_the_examples_are_in_spanish_catalan_and_english_with_the_references_dates(self):
        text = self.prompt()  # Thursday 22 October 2026.
        for example in (
            "'Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día' "
            'has {"title":"Presentar el proyecto","date":"2026-11-12","reminder_plan":{"phases":[{"from_days":21,'
            '"to_days":8,"every_days":3},{"from_days":7,"to_days":0,"every_days":1}],"time":null,'
            '"said":"cada 3 días las dos primeras semanas y luego cada día"}}',
            "'Pagar el alquiler pasado mañana, recuérdamelo el día antes a las 9' has "
            '{"title":"Pagar el alquiler","date":"2026-10-24","reminder_plan":{"phases":[{"from_days":1,'
            '"to_days":1,"every_days":1}],"time":"09:00","said":"el día antes a las 9"}}',
            "'Entregar l’informe com a molt tard d’aquí a deu dies, recorda-m’ho cada dos dies' has "
            '{"title":"Entregar l’informe","date":null,"deadline_date":"2026-11-01","reminder_plan":{"phases":'
            '[{"from_days":366,"to_days":0,"every_days":2}],"time":null,"said":"cada dos dies"}}',
            "'Dentist tomorrow at 5, remind me an hour before' has "
            '{"title":"Go to the dentist","date":"2026-10-23","time":"17:00","reminder_minutes":60,"reminder_plan":null}',
            "'Renew the passport in two weeks, remind me every day the last week but not on the day' has "
            '{"title":"Renew the passport","date":"2026-11-05","reminder_plan":{"phases":[{"from_days":7,'
            '"to_days":1,"every_days":1}],"time":null,"said":"every day the last week but not on the day"}}',
            "'Terminar la solicitud en 10 días y recuérdamelo hasta la fecha límite' has "
            '{"title":"Terminar la solicitud","date":"2026-11-01","deadline_date":null,'
            '"reminder_plan":{"strength":"normal","time":null}}',
            "'Renovar el passaport, recorda-m’ho cada setmana' has "
            '{"title":"Renovar el passaport","date":null,"reminder_plan":{"phases":[{"from_days":366,"to_days":0,'
            '"every_days":7}],"time":null,"said":"cada setmana"}}',
            "'Recorda’m prendre la pastilla cada dia' is a daily repeating task from today, not a reminder plan.",
        ):
            self.assertIn(example, text)

    def test_the_dates_follow_the_reference_in_its_own_time_zone(self):
        sunday = self.prompt(datetime(2026, 10, 18, 9, tzinfo=timezone.utc))
        self.assertIn('"title":"Presentar el proyecto","date":"2026-11-08"', sunday)
        self.assertIn('"deadline_date":"2026-10-28"', sunday)
        # 23:30 UTC on Wednesday 21 October is already Thursday 22 in Madrid.
        late = self.prompt(datetime(2026, 10, 21, 23, 30, tzinfo=timezone.utc))
        self.assertIn('"title":"Presentar el proyecto","date":"2026-11-12"', late)
        self.assertIn('"title":"Go to the dentist","date":"2026-10-23"', late)


class PlanPromptTests(SimpleTestCase):
    def prompt(self, anchor, **fields):
        return build_plan_prompt({"text": "cada 3 días y la última semana a diario", "timezone": ZONE,
                                  "reference_time": REFERENCE, "anchor_date": anchor, **fields})

    def test_it_counts_back_from_the_anchor_with_examples_in_three_languages(self):
        text = self.prompt(date(2026, 11, 12), language="es")
        self.assertIn("the anchor: Thursday 2026-11-12; today is 21 days before it.", text)
        for example in (
            "'cada 3 días y la última semana a diario' is {\"reminder_plan\":{\"phases\":[{\"from_days\":366,"
            "\"to_days\":8,\"every_days\":3},{\"from_days\":7,\"to_days\":0,\"every_days\":1}],\"time\":null}}",
            "'cada dia a les 9' is {\"reminder_plan\":{\"phases\":[{\"from_days\":366,\"to_days\":0,"
            "\"every_days\":1}],\"time\":\"09:00\"}}",
            "'a week before and the day before' is {\"reminder_plan\":{\"phases\":[{\"from_days\":7,\"to_days\":7,"
            "\"every_days\":1},{\"from_days\":1,\"to_days\":1,\"every_days\":1}],\"time\":null}}",
            "'compra pan' is {\"reminder_plan\":null}",
            "The words are most likely in es (BCP-47).",
            "today is Thursday 2026-10-22",
        ):
            self.assertIn(example, text)
        self.assertTrue(text.endswith('User words (JSON string): "cada 3 d\\u00edas y la \\u00faltima semana a diario"'))

    def test_it_says_when_the_anchor_is_near_or_gone(self):
        self.assertIn("2026-10-23; it is tomorrow.", self.prompt(date(2026, 10, 23)))
        self.assertIn("2026-10-22; it is today.", self.prompt(date(2026, 10, 22)))
        self.assertIn("2026-10-20; it has already passed.", self.prompt(date(2026, 10, 20)))
        self.assertNotIn("most likely in", self.prompt(date(2026, 10, 23)))


class FreeDictationPlanTests(TestCase):
    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
    def test_a_free_users_rhythm_is_honored_and_the_dictation_counts_once(self):
        cache.clear()
        user = User.objects.create_user("free-plan@example.invalid", PASSWORD)
        client = APIClient()
        client.force_authenticate(user)
        answer = {"tasks": [task(date="2026-11-12", reminder_plan={"phases": PHASES, "time": None, "said": WORDS})],
                  "commands": []}
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)) as provider:
            response = client.post("/api/ai/drafts/", {"text": f"Presentar el proyecto en 3 semanas, {WORDS}",
                                                       "timezone": ZONE, "commands": True}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        provider.assert_called_once()  # The dictation's own call: nothing more for the plan.
        self.assertEqual(response.data["tasks"][0]["reminder_plan"],
                         {"kind": "custom", "phases": PHASES, "time": None, "said": WORDS})
        self.assertEqual(response.data["free_voice"]["left"], 9)
        self.assertEqual(FreeDictation.objects.filter(user=user, counted=True).count(), 1)


PLAN_REQUEST = {"text": "cada 3 días y la última semana a diario", "timezone": ZONE,
                "reference_time": "2026-10-22T10:00:00Z", "anchor_date": "2026-11-12", "language": "es"}
READ = {"reminder_plan": {"phases": [phase(366, 8, 3), phase(7, 0, 1)], "time": None}}
DRAFT = {"transcript": "Llamar al dentista", "tasks": [{"title": "Llamar al dentista"}]}


class ReminderPlanEndpointTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("plan-pro@example.invalid", PASSWORD)
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.pro = patch("core.views.has_pro", return_value=True)
        self.has_pro = self.pro.start()
        self.addCleanup(self.pro.stop)  # Stopping a stopped patch does nothing.

    def read(self, answer=READ, **fields):
        raw = answer if isinstance(answer, str) else json.dumps(answer, ensure_ascii=False)
        with patch("core.ai.generate", return_value=raw) as provider:
            response = self.client.post("/api/ai/reminder-plan/", {**PLAN_REQUEST, **fields}, format="json")
        self.provider = provider
        return response

    def dictate(self):
        with patch("core.views.ai.make_drafts", return_value=deepcopy(DRAFT)):
            return self.client.post("/api/ai/drafts/", {"text": "Llamar al dentista", "timezone": ZONE}, format="json")

    def without_burst_throttle(self):
        # The 6-a-minute throttle has its own test below; these tests send more.
        for view in (views.ReminderPlanView, views.DraftView):
            throttle = patch.object(view, "throttle_classes", [])
            throttle.start()
            self.addCleanup(throttle.stop)

    def assert_daily_limit(self, response):
        self.assertEqual(response.status_code, 429, response.data)
        # Not the 6-a-minute throttle: the daily limit, with the wait until 00:00 UTC.
        self.assertTrue(str(response.data["detail"]).startswith("Daily AI limit reached."), response.data)
        self.assertGreater(int(response["Retry-After"]), 0)

    def test_pro_gets_the_words_as_a_custom_plan(self):
        response = self.read()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.json(), {"reminder_plan": {
            "kind": "custom", "phases": [phase(366, 8, 3), phase(7, 0, 1)], "time": None,
            "said": "cada 3 días y la última semana a diario"}})
        self.provider.assert_called_once()
        self.assertEqual(self.provider.call_args.kwargs, {"reminder_plan": True})
        prompt = self.provider.call_args.args[0]
        self.assertIn("the anchor: Thursday 2026-11-12; today is 21 days before it.", prompt)
        self.assertIn('User words (JSON string): "cada 3 d\\u00edas y la \\u00faltima semana a diario"', prompt)
        # Not a dictation: nothing is counted, and the answer says nothing about free dictations.
        self.assertFalse(FreeDictation.objects.exists())
        self.assertNotIn("free_voice", response.json())

    def test_the_plan_keeps_the_words_and_a_time_said(self):
        answer = {"reminder_plan": {"phases": [phase(366, 0, 1)], "time": "21:00", "said": "something else"}}
        response = self.read(answer, text="  cada dia a les 9 del vespre  ", language="ca")
        self.assertEqual(response.json()["reminder_plan"], {"kind": "custom", "phases": [phase(366, 0, 1)],
                                                            "time": "21:00", "said": "cada dia a les 9 del vespre"})

    def test_the_models_slips_are_tolerated(self):
        for answer in (f"```json\n{json.dumps(READ)}\n```", READ["reminder_plan"], [READ]):
            with self.subTest(answer=answer):
                response = self.read(answer)
                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(response.json()["reminder_plan"]["phases"], [phase(366, 8, 3), phase(7, 0, 1)])

    def test_words_that_arent_about_reminders_are_unclear(self):
        for answer in ({"reminder_plan": None}, {}, {"issue": "unclear"},
                       {"reminder_plan": {"phases": [phase(7, 0, 0)], "time": None}},
                       {"reminder_plan": {"phases": [], "time": None}},
                       {"reminder_plan": "cada tres días"}):
            with self.subTest(answer=answer):
                response = self.read(answer, text="compra pan")
                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(response.json(), {"reminder_plan": None, "issue": "unclear"})

    def test_free_users_get_402_before_the_ai_or_the_budgets(self):
        self.has_pro.return_value = False
        with patch("core.views.consume_budget") as budget:
            response = self.read()
        self.assertEqual(response.status_code, 402)
        self.assertEqual(response.json(), {"code": "pro_required"})
        self.provider.assert_not_called()
        budget.assert_not_called()

    def test_unknown_billing_asks_to_try_again(self):
        self.has_pro.return_value = None
        response = self.read()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["code"], "billing_unavailable")
        self.provider.assert_not_called()

    def test_without_pro_configured_an_ordinary_account_is_free(self):
        self.pro.stop()  # The real check: no billing key in tests, so only complimentary grants are Pro.
        response = self.read()
        self.assertEqual((response.status_code, response.json()), (402, {"code": "pro_required"}))
        self.provider.assert_not_called()

    def test_the_request_is_checked_first(self):
        self.without_burst_throttle()
        naive = {**PLAN_REQUEST, "reference_time": "2026-10-22T10:00:00"}
        for fields in ({"anchor_date": None}, {"anchor_date": "12/11/2026"}, {"text": "x" * 201}, {"text": "   "},
                       {"timezone": "Madrid"}, naive, {"language": "español!"}):
            with self.subTest(fields=fields):
                response = self.read(**fields)
                self.assertEqual(response.status_code, 400, response.data)
                self.provider.assert_not_called()
        missing = {key: value for key, value in PLAN_REQUEST.items() if key != "anchor_date"}
        with patch("core.ai.generate") as provider:
            self.assertEqual(self.client.post("/api/ai/reminder-plan/", missing, format="json").status_code, 400)
            self.assertEqual(APIClient().post("/api/ai/reminder-plan/", PLAN_REQUEST, format="json").status_code, 401)
        provider.assert_not_called()
        self.assertEqual(self.read(text="x" * 200).status_code, 200)  # 200 characters fit in said.

    @override_settings(AI_REQUESTS_PER_DAY=2)
    def test_it_shares_dictations_daily_budget(self):
        self.assertEqual(self.read().status_code, 200)
        self.assertEqual(self.dictate().status_code, 200)
        self.assert_daily_limit(self.read())
        self.provider.assert_not_called()
        self.assert_daily_limit(self.dictate())

    @override_settings(AI_REQUESTS_PER_DAY=1)
    def test_an_unclear_answer_still_counts_toward_the_daily_limit(self):
        self.assertEqual(self.read({"reminder_plan": None}).status_code, 200)
        self.assert_daily_limit(self.read())

    @override_settings(AI_GLOBAL_REQUESTS_PER_DAY=0)
    def test_everyones_daily_budget_too(self):
        self.assert_daily_limit(self.read())
        self.provider.assert_not_called()
        with override_settings(AI_GLOBAL_REQUESTS_PER_DAY=200, AI_REQUESTS_PER_DAY=1):
            # The account's call was given back when everyone's budget refused it.
            self.assertEqual(self.read().status_code, 200)

    @override_settings(AI_REQUESTS_PER_DAY=1)
    def test_a_failed_read_gives_the_budget_back(self):
        self.without_burst_throttle()
        failures = [(errors.ServerError(503, {"error": {"message": "Unavailable"}}), 503),
                    (errors.ClientError(429, {"error": {"message": "Quota"}}), 429)]
        for failure, status in failures:
            with self.subTest(status=status), patch("core.ai.generate", side_effect=failure):
                response = self.client.post("/api/ai/reminder-plan/", PLAN_REQUEST, format="json")
                self.assertEqual(response.status_code, status, response.data)
                self.assertFalse(response.has_header("Retry-After"))  # Google's quota: no wait to promise.
        for raw in ("not json", '"cada tres días"', ""):
            with self.subTest(raw=raw):
                self.assertEqual(self.read(raw).status_code, 502)
        self.assertEqual(self.read().status_code, 200)
        self.assert_daily_limit(self.read())

    def test_it_shares_dictations_throttle(self):
        self.assertEqual(views.ReminderPlanView.throttle_scope, views.DraftView.throttle_scope)
        for _ in range(6):
            self.assertEqual(self.dictate().status_code, 200)
        refused = self.read()
        self.assertEqual(refused.status_code, 429)
        self.assertTrue(str(refused.data["detail"]).startswith("Request was throttled."), refused.data)
        self.assertTrue(1 <= int(refused["Retry-After"]) <= 60, refused["Retry-After"])
        self.provider.assert_not_called()

    def test_read_plan_ignores_the_models_words_when_the_persons_are_given(self):
        self.assertEqual(read_plan({"phases": [phase(1, 1, 1)], "said": "model"}, said="person")["said"], "person")
