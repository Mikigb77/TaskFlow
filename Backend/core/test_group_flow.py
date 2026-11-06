"""Groups end to end, the way people use them: fake accounts sign up, one makes a group for a
college project and invites the others by email, they accept with the code from that email, and
then tasks are dictated for the whole group or for one named person ("Max has to finish the
introduction by Thursday at 3"). Each dictation goes through the real draft endpoint, with only
the AI model's answer stubbed, and is then saved the way the app saves a reviewed draft. The
tests check that every task reaches the right group and the right person, and nobody else.
"""
import json
import re
import uuid
from unittest.mock import patch

from django.core import mail
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient


REFERENCE = "2026-11-09T10:00:00+01:00"  # A Monday, so "Thursday" is 2026-11-12.
ZONE = "Europe/Madrid"

# What the app sends back when it saves a reviewed draft (lib/models/task.dart, toJson).
SAVED_FIELDS = ("title", "kind", "list_id", "assignment", "assignee_id", "due_date", "scheduled_date",
                "deadline_at", "deadline_date", "priority", "notes", "checklist")


def model_answer(*tasks):
    """The model's JSON for these tasks; anything not given is what it returns when not said."""
    return json.dumps({"tasks": [{"date": None, "time": None, "priority": 1, **task} for task in tasks]})


@patch("core.views.has_pro", new=lambda user: True)
class GroupTaskFlowTests(TestCase):
    def setUp(self):
        cache.clear()
        self.people = {name: self.sign_up(name) for name in ("Miki", "Max", "Laura", "Sam", "Outsider")}
        self.miki, self.max, self.laura, self.sam, self.outsider = (
            self.people[name] for name in ("Miki", "Max", "Laura", "Sam", "Outsider"))

        # Miki makes the math group and its project, and invites Max and Laura.
        self.math = self.make_group(self.miki, "Math group")
        self.presentation = self.make_project(self.miki, "Presentation", self.math)
        for person in (self.max, self.laura):
            self.invite_and_accept(self.miki, self.math, person)

        # A second group: Max and Sam's physics lab, made by Sam.
        self.physics = self.make_group(self.sam, "Physics lab")
        self.report = self.make_project(self.sam, "Lab report", self.physics)
        self.invite_and_accept(self.sam, self.physics, self.max)

    # Accounts, groups and invitations, through the API.

    def sign_up(self, name):
        response = APIClient().post("/api/auth/register/", {
            "email": f"{name.lower()}@group-flow.example.invalid", "password": "Fixture-only!2026",
            "first_name": name, "timezone": ZONE}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["access"])
        client.user_id = response.data["user"]["id"]
        client.email = response.data["user"]["email"]
        return client

    def make_group(self, client, name):
        response = client.put(f"/api/groups/{uuid.uuid4()}/", {"name": name, "version": 0}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data["id"]

    def make_project(self, client, name, group):
        response = client.put(f"/api/lists/{uuid.uuid4()}/", {"name": name, "group_id": group, "version": 0}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data["shared"])
        return response.data["id"]

    def invite_and_accept(self, inviter, group, person):
        mail.outbox.clear()
        invited = inviter.post(f"/api/groups/{group}/invite/", {"email": person.email, "role": "editor"}, format="json")
        self.assertEqual(invited.status_code, 201, invited.data)
        # The person learns of it in the app, and takes the code from the email.
        pending = person.get("/api/group-invitations/").data["invitations"]
        self.assertEqual([row["id"] for row in pending], [invited.data["id"]])
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, [person.email])
        code = invited.data["code"]
        self.assertIn(code, mail.outbox[0].body)
        accepted = person.post(f"/api/group-invitations/{invited.data['id']}/respond/",
                               {"decision": "accept", "code": code}, format="json")
        self.assertEqual(accepted.status_code, 200, accepted.data)

    # Dictating and saving.

    def dictate(self, client, words, *answer, project=None, commands=False):
        """The drafts for these words, with the model answering `answer`."""
        payload = {"text": words, "timezone": ZONE, "reference_time": REFERENCE, "commands": commands}
        if project:
            payload["project_id"] = project
        with patch("core.ai.generate", return_value=model_answer(*answer)) as model:
            response = client.post("/api/ai/drafts/", payload, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.last_prompt = model.call_args.args[0]
        return response.data["tasks"]

    def save(self, client, draft):
        """Save a draft as the app does once it's confirmed."""
        payload = {key: draft[key] for key in SAVED_FIELDS if key in draft}
        response = client.put(f"/api/tasks/{uuid.uuid4()}/", {**payload, "version": 0}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def titles(self, client):
        return {task["title"] for task in client.get("/api/tasks/").data["results"]}

    def notified(self, client):
        return [(row["task_title"], row["action"]) for row in client.get("/api/notifications/").data["results"]]

    # The flows.

    def test_everyone_sees_the_groups_they_belong_to(self):
        def groups(client):
            return {row["name"]: {person["name"] for person in row["people"]}
                    for row in client.get("/api/groups/").data["results"]}
        self.assertEqual(groups(self.miki), {"Math group": {"Miki", "Max", "Laura"}})
        self.assertEqual(groups(self.laura), {"Math group": {"Miki", "Max", "Laura"}})
        self.assertEqual(groups(self.max), {"Math group": {"Miki", "Max", "Laura"},
                                            "Physics lab": {"Sam", "Max"}})
        self.assertEqual(groups(self.sam), {"Physics lab": {"Sam", "Max"}})
        self.assertEqual(groups(self.outsider), {})

    def test_a_task_said_for_max_is_assigned_to_max_with_its_deadline(self):
        words = "For Max: he has to finish the introduction of the presentation by Thursday at 3"
        [draft] = self.dictate(self.miki, words, {
            "title": "Finish the introduction of the presentation", "deadline_date": "2026-11-12",
            "deadline_time": "15:00", "project_name": "Presentation", "member_name": "Max",
            "assignment_request": "member"})
        self.assertEqual(draft["list_id"], self.presentation)
        self.assertEqual((draft["assignment"], draft["assignee_id"], draft["assignee_name"]),
                         ("member", self.max.user_id, "Max"))
        self.assertEqual(draft["assignment_issues"], [])
        self.assertEqual(draft["deadline_at"], "2026-11-12T15:00:00+01:00")
        # The model was told who is in the group, so it can spell the names.
        self.assertIn('"name": "Max"', self.last_prompt)

        task = self.save(self.miki, draft)
        self.assertEqual((task["assignee_id"], task["assignee_name"], task["created_by"]),
                         (self.max.user_id, "Max", self.miki.user_id))

        # Max has it, and is told. Laura sees it in the group's project, as Max's.
        mine = {row["title"]: row for row in self.max.get("/api/tasks/").data["results"]}
        self.assertEqual(mine[task["title"]]["assignee_id"], self.max.user_id)
        self.assertEqual(mine[task["title"]]["deadline_at"], "2026-11-12T14:00:00Z")
        self.assertEqual(self.notified(self.max), [(task["title"], "created")])
        laura = {row["title"]: row for row in self.laura.get("/api/tasks/").data["results"]}
        self.assertEqual(laura[task["title"]]["assignee_name"], "Max")
        self.assertEqual(self.notified(self.laura), [])  # Not hers, and she didn't ask for everything.
        # Nobody outside the math group sees it.
        for client in (self.sam, self.outsider):
            self.assertNotIn(task["title"], self.titles(client))
            self.assertEqual(client.get(f"/api/tasks/{task['id']}/").status_code, 404)

        # Max finishes it; Miki sees it done, and its history says who did.
        done = self.max.put(f"/api/tasks/{task['id']}/", {**task, "is_completed": True}, format="json")
        self.assertEqual(done.status_code, 200, done.data)
        self.assertTrue(self.miki.get(f"/api/tasks/{task['id']}/").data["is_completed"])
        history = self.miki.get(f"/api/tasks/{task['id']}/history/").data
        self.assertEqual([(row["action"], row["actor_name"]) for row in history],
                         [("created", "Miki"), ("completed", "Max")])
        # Miki gave it to Max, so Miki is told he finished it. Laura isn't: it was never hers.
        self.assertEqual(self.notified(self.miki), [(task["title"], "completed")])
        self.assertEqual(self.notified(self.laura), [])

    def test_whoever_hands_a_task_over_hears_when_it_is_done(self):
        def complete(client, task, **changes):
            current = client.get(f"/api/tasks/{task['id']}/").data
            response = client.put(f"/api/tasks/{task['id']}/", {**current, **changes}, format="json")
            self.assertEqual(response.status_code, 200, response.data)
            return response.data

        def completions(client):
            return [title for title, action in self.notified(client) if action == "completed"]

        def new_task(client, title, **fields):
            response = client.put(f"/api/tasks/{uuid.uuid4()}/", {
                "title": title, "list_id": self.presentation, "version": 0, **fields}, format="json")
            self.assertEqual(response.status_code, 201, response.data)
            return response.data

        # Reassigned by Laura: Laura handed it to Max, so she hears, and Miki doesn't.
        task = new_task(self.miki, "Check the sources", assignment="member", assignee_id=self.laura.user_id)
        complete(self.laura, task, assignee_id=self.max.user_id)
        complete(self.max, task, is_completed=True)
        self.assertEqual(completions(self.laura), ["Check the sources"])
        self.assertEqual(completions(self.miki), [])

        # Taken by Max himself: nobody handed it over.
        task = new_task(self.miki, "Print the poster")
        complete(self.max, task, assignment="member", assignee_id=self.max.user_id)
        complete(self.max, task, is_completed=True)
        # A task that repeats would tell you every time: not those.
        task = new_task(self.miki, "Water the lab plants", assignment="member", assignee_id=self.max.user_id,
                        recurrence="daily", due_date="2026-11-09T09:00:00+01:00")
        complete(self.max, task, completed_dates=["2026-11-09"])
        # Nor in a project you muted.
        self.miki.post(f"/api/lists/{self.presentation}/preferences/", {"notifications": "muted"}, format="json")
        task = new_task(self.miki, "Send the draft", assignment="member", assignee_id=self.max.user_id)
        complete(self.max, task, is_completed=True)
        self.assertEqual(completions(self.miki), [])

    def test_a_task_for_the_whole_group_reaches_everyone_in_it(self):
        [draft] = self.dictate(self.miki, "We all need to rehearse the presentation on Friday", {
            "title": "Rehearse the presentation", "date": "2026-11-13", "project_name": "Presentation",
            "assignment_request": "group"})
        self.assertEqual((draft["list_id"], draft["assignment"], draft["assignee_id"]),
                         (self.presentation, "group", None))
        task = self.save(self.miki, draft)
        for client in (self.max, self.laura):
            self.assertIn(task["title"], self.titles(client))
            self.assertEqual(self.notified(client), [(task["title"], "created")])
        self.assertNotIn(task["title"], self.titles(self.sam))
        # One completion, for everyone.
        done = self.laura.put(f"/api/tasks/{task['id']}/", {**task, "is_completed": True}, format="json")
        self.assertEqual(done.status_code, 200, done.data)
        self.assertTrue(self.max.get(f"/api/tasks/{task['id']}/").data["is_completed"])

    def test_tasks_said_together_go_to_their_own_group_and_person(self):
        words = ("Laura makes the slides for the presentation by Wednesday, "
                 "and for the physics lab Max writes the method section")
        slides, method = self.dictate(self.max, words, {
            "title": "Make the slides", "deadline_date": "2026-11-11", "project_name": "Presentation",
            "member_name": "Laura", "assignment_request": "member"}, {
            "title": "Write the method section", "project_name": "Physics lab",
            "member_name": "Max", "assignment_request": "member"})
        self.assertEqual((slides["list_id"], slides["assignee_id"]), (self.presentation, self.laura.user_id))
        self.assertEqual(slides["deadline_date"], "2026-11-11")
        # "physics lab" names the group, whose one project is the lab report.
        self.assertEqual((method["list_id"], method["assignee_id"]), (self.report, self.max.user_id))
        slides, method = self.save(self.max, slides), self.save(self.max, method)

        self.assertEqual(self.titles(self.laura), {slides["title"]})
        self.assertEqual(self.titles(self.sam), {method["title"]})
        self.assertEqual(self.titles(self.miki), {slides["title"]})
        self.assertEqual(self.titles(self.max), {slides["title"], method["title"]})
        self.assertEqual(self.titles(self.outsider), set())
        self.assertEqual(self.notified(self.laura), [(slides["title"], "created")])

    def test_said_inside_the_groups_project_a_name_is_enough(self):
        [draft] = self.dictate(self.miki, "Laura has to print the handouts", {
            "title": "Print the handouts", "member_name": "Laura", "assignment_request": "member"},
            project=self.presentation)
        self.assertEqual((draft["list_id"], draft["assignee_id"], draft["assignment_issues"]),
                         (self.presentation, self.laura.user_id, []))
        # And with nobody named, a task said there is the group's.
        [draft] = self.dictate(self.miki, "Book a room", {"title": "Book a room"}, project=self.presentation)
        self.assertEqual((draft["list_id"], draft["assignment"]), (self.presentation, "group"))

    def test_a_name_said_without_a_project_finds_the_one_group_with_that_person(self):
        # Laura is only in the math group, so «Laura has to…» said from the calendar goes there.
        [draft] = self.dictate(self.miki, "Laura has to finish the conclusion by Thursday", {
            "title": "Finish the conclusion", "deadline_date": "2026-11-12",
            "member_name": "Laura", "assignment_request": "member"})
        self.assertEqual((draft["list_id"], draft["assignee_id"], draft["assignment_issues"]),
                         (self.presentation, self.laura.user_id, []))
        task = self.save(self.miki, draft)
        self.assertIn(task["title"], self.titles(self.laura))

    def test_a_name_in_two_of_your_groups_asks_which_project(self):
        # Max is in both of his groups: his own dictation can't guess, so the card asks.
        for commands in (False, True):
            [draft] = self.dictate(self.max, "Max has to order the equipment", {
                "title": "Order the equipment", "member_name": "Max", "assignment_request": "member"},
                commands=commands)
            self.assertIsNone(draft["list_id"])
            self.assertIsNone(draft["assignee_id"])
            self.assertEqual(draft["assignment_issues"], ["choose_project"])

    def test_people_outside_the_group_cannot_be_given_its_tasks(self):
        # Sam isn't in the math group: the draft says so, and saving it for him anyway is refused.
        [draft] = self.dictate(self.miki, "Sam has to check the maths", {
            "title": "Check the maths", "project_name": "Presentation", "member_name": "Sam",
            "assignment_request": "member"})
        self.assertEqual((draft["list_id"], draft["assignee_id"]), (self.presentation, None))
        self.assertEqual(draft["assignment_issues"], ["member_not_available"])
        self.assertNotIn('"Sam"', self.last_prompt)
        forced = self.miki.put(f"/api/tasks/{uuid.uuid4()}/", {
            "title": "Check the maths", "list_id": self.presentation, "assignment": "member",
            "assignee_id": self.sam.user_id, "version": 0}, format="json")
        self.assertEqual(forced.status_code, 400)
        # And someone outside a group can't add tasks to it at all.
        refused = self.outsider.put(f"/api/tasks/{uuid.uuid4()}/", {
            "title": "Sneak in", "list_id": self.presentation, "version": 0}, format="json")
        self.assertIn(refused.status_code, (400, 403, 404))
        self.assertEqual(self.titles(self.miki), set())

    def test_leaving_the_group_hands_back_your_tasks(self):
        [draft] = self.dictate(self.miki, "Max does the bibliography", {
            "title": "Do the bibliography", "project_name": "Presentation", "member_name": "Max",
            "assignment_request": "member"})
        task = self.save(self.miki, draft)
        self.assertEqual(self.max.post(f"/api/groups/{self.math}/leave/").status_code, 204)
        self.assertNotIn(task["title"], self.titles(self.max))
        current = self.miki.get(f"/api/tasks/{task['id']}/").data
        self.assertEqual((current["assignment"], current["assignee_id"]), ("unassigned", None))
        # Max still has his physics lab.
        self.assertEqual([row["name"] for row in self.max.get("/api/groups/").data["results"]], ["Physics lab"])
