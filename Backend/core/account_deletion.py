"""Account deletion, as designed in docs/ACCOUNT_DELETION.md.

The person's own data goes. What they put in shared projects and groups stays
there, and every handover is named in the preview first. One plan drives both
the preview and the deletion, so what the person confirms is what happens.
"""
from functools import partial
import hashlib
import json
import logging
import re

from django.core.cache import cache
from django.db import transaction
from django.db.models import F, Q
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed, Throttled
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

from .billing import has_pro
from .collaboration import clear_assignments
from .google_auth import verify_google_identity
from .list_access import display_name
from .models import (Attachment, EmailDelivery, GoogleIdentity, GroupInvitation, GroupMembership,
                     ListInvitation, ListMembership, Task, TaskEvent, TaskGroup, TaskList, User)

logger = logging.getLogger(__name__)

# Heirs: the highest role first, then the earliest membership (ascending id).
GROUP_HEIR_ORDER = {"admin": 0, "editor": 1, "viewer": 2}
PROJECT_HEIR_ORDER = {"editor": 0, "viewer": 1}


def _heir(memberships, order):
    # Active accounts first: a disabled one couldn't sign in to manage what it receives.
    rows = sorted(memberships.select_related("user"),
                  key=lambda row: (not row.user.is_active, order.get(row.role, len(order)), row.pk))
    return rows[0].user if rows else None


class _Plan:
    """What deleting this account does, read from the current rows."""

    def __init__(self, user):
        self.user = user
        self.group_heirs = {}       # group id -> (group, heir)
        self.deleted_groups = {}    # group id -> group: already deleted, or nobody else in it
        for group in TaskGroup.objects.filter(owner=user).order_by("id"):
            heir = None if group.is_deleted else _heir(group.memberships.exclude(user=user), GROUP_HEIR_ORDER)
            if heir is None:
                self.deleted_groups[group.pk] = group
            else:
                self.group_heirs[group.pk] = (group, heir)
        self.new_owners = {}        # project id -> (project, who receives it)
        self.deleted_projects = {}  # project id -> project
        projects = TaskList.objects.filter(Q(owner=user) | Q(group_id__in=list(self.deleted_groups)))
        for project in projects.select_related("group__owner").order_by("id"):
            if project.is_deleted or project.group_id in self.deleted_groups:
                self.deleted_projects[project.pk] = project
            elif project.group_id in self.group_heirs:
                self.new_owners[project.pk] = (project, self.group_heirs[project.group_id][1])
            elif project.group_id:
                # Inside a group someone else owns: it goes to that group's owner.
                self.new_owners[project.pk] = (project, project.group.owner)
            else:
                heir = _heir(project.memberships.exclude(user=user), PROJECT_HEIR_ORDER)
                if heir is None:
                    self.deleted_projects[project.pk] = project
                else:
                    self.new_owners[project.pk] = (project, heir)
        deleted = list(self.deleted_projects)
        # A deleted project takes all its tasks, whoever created them. Task.task_list is
        # SET_NULL, so a task left behind would become its creator's personal task.
        self.deleted_tasks = Task.objects.filter(Q(owner=user, task_list__isnull=True) | Q(task_list_id__in=deleted))
        self.kept_tasks = Task.objects.filter(owner=user, task_list__isnull=False).exclude(task_list_id__in=deleted)

    def _handed_over(self):
        # A group's projects go with the group, so its line covers them.
        rows = [("group", group, heir) for group, heir in self.group_heirs.values()]
        return rows + [("project", project, owner) for project, owner in self.new_owners.values()
                       if project.group_id not in self.group_heirs]

    def handovers(self):
        rows = [{"kind": kind, "id": str(item.pk), "name": item.name, "to": display_name(heir)}
                for kind, item, heir in self._handed_over()]
        return sorted(rows, key=lambda row: (row["kind"] != "group", row["name"].casefold(), row["id"]))

    def fingerprint(self):
        """Who receives what, by id. Names can change without changing that."""
        rows = sorted([kind, str(item.pk), heir.pk] for kind, item, heir in self._handed_over())
        return hashlib.sha256(json.dumps(rows, separators=(",", ":")).encode()).hexdigest()

    def summary(self):
        # Counts are of what the person can see: tombstones go too, but aren't counted.
        tasks = self.deleted_tasks.filter(is_deleted=False)
        return {
            "personal": {
                "tasks": tasks.filter(kind="task").count(),
                "notes": tasks.filter(kind="note").count(),
                "files": Attachment.objects.filter(task__in=tasks, is_deleted=False).count(),
                "projects": sum(not project.is_deleted for project in self.deleted_projects.values()),
                "groups": sum(not group.is_deleted for group in self.deleted_groups.values()),
            },
            "kept_in_shared": self.kept_tasks.filter(is_deleted=False, task_list__is_deleted=False).count(),
            # Files the person added that stay, on their own tasks or on other people's.
            "kept_files_in_shared": Attachment.objects.filter(
                owner=self.user, is_deleted=False, task__is_deleted=False, task__task_list__isnull=False,
                task__task_list__is_deleted=False).exclude(task__in=self.deleted_tasks).count(),
            "handovers": self.handovers(),
            # The app sends this back to confirm, so nothing is handed over unseen.
            "plan": self.fingerprint(),
        }


def deletion_preview(user):
    """What deleting this account would do, for the app to show before the person confirms."""
    try:
        pro = has_pro(user)
    except Exception:
        pro = None  # Billing never blocks the preview.
    # Unknown counts as Pro: the note that deleting doesn't cancel a store subscription
    # is harmless to someone without one, and hiding it from a subscriber isn't.
    pro = True if pro is None else bool(pro)
    google_only = not user.has_usable_password() and GoogleIdentity.objects.filter(user=user).exists()
    return {**_Plan(user).summary(), "pro": pro, "reauth": "google" if google_only else "password"}


def _lock(user):
    """Lock what the deletion changes in the order the rest of the API uses: groups,
    projects, tasks, then the account (see lock_task and the group transfer), so a
    concurrent upload or transfer waits instead of deadlocking."""
    projects = set(TaskList.objects.filter(owner=user).values_list("pk", flat=True))
    projects.update(ListMembership.objects.filter(user=user).values_list("task_list_id", flat=True))
    projects.update(ListInvitation.objects.filter(email__iexact=user.email).values_list("task_list_id", flat=True))
    projects.update(Task.objects.filter(Q(owner=user) | Q(assignee=user), task_list__isnull=False)
                    .values_list("task_list_id", flat=True))
    projects.update(Attachment.objects.filter(owner=user, task__task_list__isnull=False)
                    .values_list("task__task_list_id", flat=True))
    groups = set(TaskGroup.objects.filter(owner=user).values_list("pk", flat=True))
    groups.update(GroupMembership.objects.filter(user=user).values_list("group_id", flat=True))
    groups.update(GroupInvitation.objects.filter(email__iexact=user.email).values_list("group_id", flat=True))
    groups.update(TaskList.objects.filter(pk__in=projects, group__isnull=False).values_list("group_id", flat=True))
    projects.update(TaskList.objects.filter(group_id__in=groups).values_list("pk", flat=True))
    list(TaskGroup.objects.select_for_update().filter(pk__in=groups).order_by("id"))
    list(TaskList.objects.select_for_update().filter(pk__in=projects).order_by("id"))
    list(Task.objects.select_for_update().filter(owner=user, task_list__isnull=True).order_by("id").only("id"))


def _move_kept_contributions(user, plan, now):
    """Tasks and notes the person created in projects that stay go to the project's
    (new) owner, and so do the files they added to tasks that stay: storage is
    charged to the project's owner."""
    by_owner = {}
    project_ids = set(plan.kept_tasks.values_list("task_list_id", flat=True))
    for project_id, owner_id in TaskList.objects.filter(pk__in=project_ids).values_list("pk", "owner_id"):
        by_owner.setdefault(owner_id, []).append(project_id)
    for owner_id, ids in by_owner.items():
        Task.objects.filter(owner=user, task_list_id__in=ids).update(
            owner_id=owner_id, version=F("version") + 1, updated_at=now)
    files = {}
    for row in Attachment.objects.filter(owner=user).exclude(task__in=plan.deleted_tasks).select_related("task__task_list"):
        task = row.task
        files.setdefault(task.task_list.owner_id if task.task_list_id else task.owner_id, []).append(row.pk)
    for owner_id, ids in files.items():
        Attachment.objects.filter(pk__in=ids).update(owner_id=owner_id, updated_at=now)


def _unsign_invitation_emails(user, plan):
    """An unsent invitation email starts with its sender's email or name. The
    invitation stays valid, so the email can still go, without naming the person."""
    marker = " invited you to join "
    pending = EmailDelivery.objects.filter(state="pending").filter(
        Q(group_invitation__invited_by=user) | Q(list_invitation__task_list_id__in=list(plan.new_owners)))
    for row in pending:
        for sender in (user.email, display_name(user)):
            if row.body.startswith(sender + marker):
                EmailDelivery.objects.filter(pk=row.pk).update(body="Someone" + row.body[len(sender):])
                break


def _scrubbed(value, person_id, pattern):
    # The changed-fields list holds model field names only, so it stays as it is.
    if isinstance(value, dict):
        return {key: item if key == "fields"
                else None if key.endswith("_id") and type(item) is int and item == person_id
                else _scrubbed(item, person_id, pattern)
                for key, item in value.items()}
    if isinstance(value, list):
        return [_scrubbed(item, person_id, pattern) for item in value]
    if isinstance(value, str) and pattern.search(value):
        return None
    return value


def _scrub_activity(user):
    """Activity stays for the group with no actor and no id, email or name of the person."""
    names = sorted({name for name in (display_name(user), user.get_full_name().strip()) if len(name) >= 3})
    pattern = re.compile("|".join([re.escape(user.email)] + [rf"(?<!\w){re.escape(name)}(?!\w)" for name in names]),
                         re.IGNORECASE)
    needles = [user.email, *names]
    # SQLite stores non-ASCII characters in JSON as \u escapes, so search both spellings.
    needles = {*needles, *(json.dumps(needle)[1:-1] for needle in needles)}
    query = Q(actor=user) | Q(details__previous_assignee_id=user.pk)
    for needle in needles:
        query |= Q(details__icontains=needle)
    for event in TaskEvent.objects.filter(query).only("pk", "details"):
        details = _scrubbed(event.details, user.pk, pattern)
        if details != event.details:
            TaskEvent.objects.filter(pk=event.pk).update(details=details)
    TaskEvent.objects.filter(actor=user).update(actor=None)


def _remove_files(storage, names):
    # Runs after the commit: the account is already gone, whatever happens here.
    for name in names:
        try:
            storage.delete(name)
        except Exception:
            logger.error("Account deletion could not remove stored file %s", name)


class PlanChanged(Exception):
    """The handovers differ from the preview the person confirmed. Nothing was changed."""


def delete_account(user, expected_plan=None):
    """Delete the account in one transaction, as the preview described it.

    With expected_plan, the preview's fingerprint, raises PlanChanged before any
    change if the handovers are no longer the ones shown. Returns False when the
    account was already gone, deleted from another device."""
    with transaction.atomic():
        _lock(user)
        user = User.objects.select_for_update().filter(pk=user.pk).first()
        if user is None:
            return False
        plan = _Plan(user)
        if expected_plan is not None and plan.fingerprint() != expected_plan:
            raise PlanChanged()
        now = timezone.now()
        stored = set(Attachment.objects.filter(task__in=plan.deleted_tasks).values_list("file", flat=True))
        _unsign_invitation_emails(user, plan)

        # The person's memberships go first, so people lists and notifications leave them out.
        touched_groups = set(GroupMembership.objects.filter(user=user).values_list("group_id", flat=True))
        touched_projects = set(ListMembership.objects.filter(user=user).values_list("task_list_id", flat=True))
        GroupMembership.objects.filter(user=user).delete()
        ListMembership.objects.filter(user=user).delete()

        # Handovers. Owners aren't members, so the heir's membership row goes.
        for group, heir in plan.group_heirs.values():
            TaskGroup.objects.filter(pk=group.pk).update(owner=heir)
            GroupMembership.objects.filter(group=group, user=heir).delete()
            touched_groups.add(group.pk)
        for project, owner in plan.new_owners.values():
            TaskList.objects.filter(pk=project.pk).update(owner=owner)
            ListMembership.objects.filter(task_list=project, user=owner).delete()
            touched_projects.add(project.pk)

        _move_kept_contributions(user, plan, now)
        # Assigned tasks stay, unassigned, as when someone leaves a project.
        assigned = Task.objects.filter(assignee=user, is_deleted=False, task_list__isnull=False).exclude(
            task_list_id__in=list(plan.deleted_projects))
        clear_assignments(sorted(set(assigned.values_list("task_list_id", flat=True))), user.pk, None)

        plan.deleted_tasks.delete()
        TaskList.objects.filter(pk__in=list(plan.deleted_projects)).delete()
        TaskGroup.objects.filter(pk__in=list(plan.deleted_groups)).delete()

        # Invitations to the person's address go with their emails; the ones they sent stay.
        invitations = GroupInvitation.objects.filter(email__iexact=user.email)
        touched_groups.update(invitations.filter(state="pending").values_list("group_id", flat=True))
        invitations.delete()
        invitations = ListInvitation.objects.filter(email__iexact=user.email)
        touched_projects.update(invitations.filter(state="pending").values_list("task_list_id", flat=True))
        invitations.delete()
        EmailDelivery.objects.filter(recipient__iexact=user.email).delete()
        GroupInvitation.objects.filter(invited_by=user).update(invited_by=None)

        _scrub_activity(user)

        # New versions, so every member's app syncs what changed.
        TaskGroup.objects.filter(pk__in=touched_groups).update(version=F("version") + 1, updated_at=now)
        TaskList.objects.filter(Q(pk__in=touched_projects) | Q(group_id__in=touched_groups)).update(
            version=F("version") + 1, updated_at=now)

        OutstandingToken.objects.filter(user=user).delete()
        # Cascades the rest of the account: Google link, sessions, free dictations,
        # notifications and project preferences.
        user.delete()

        # Never remove a file that an attachment still uses.
        stored -= set(Attachment.objects.filter(file__in=stored).values_list("file", flat=True))
        stored.discard("")
        if stored:
            transaction.on_commit(partial(_remove_files, Attachment._meta.get_field("file").storage, sorted(stored)))
    return True


def _refused(code, detail):
    return Response({"code": code, "detail": detail}, status=400)


def _reauthentication_failure(user, data):
    """None when the person has proved it's them; otherwise the 400 response."""
    data = data if isinstance(data, dict) else {}
    password, token = data.get("password"), data.get("google_id_token")
    if isinstance(password, str) and password:
        # Sign-in's lock: after five wrong passwords, both wait 15 minutes.
        key = "login-fail:" + hashlib.sha256(user.email.strip().casefold().encode()).hexdigest()
        if cache.get(key, 0) >= 5:
            raise Throttled(wait=900, detail="Too many failed attempts. Try again in 15 minutes.")
        if len(password) > 128 or not user.check_password(password):
            if not cache.add(key, 1, 900):
                cache.incr(key)
            return _refused("wrong_password", "Your password is incorrect.")
        cache.delete(key)
        return None
    if isinstance(token, str) and token:
        identity = GoogleIdentity.objects.filter(user=user).first()
        subject = None
        if identity is not None and len(token) <= 12000:
            try:
                # The Google sign-in's own verification. An outage stays a 503.
                subject, _ = verify_google_identity(token)
            except AuthenticationFailed:
                pass
        if subject is None or subject != identity.subject:
            return _refused("google_reauth_failed", "Sign in with the Google account linked to this TaskFlow account.")
        return None
    return _refused("reauth_required", "Confirm with your password or Google sign-in to delete this account.")


class DeleteAccountView(APIView):
    # Sign-in's burst throttle, so the password can't be guessed here instead.
    throttle_scope = "auth"

    def get(self, request):
        return Response(deletion_preview(request.user))

    def post(self, request):
        # The password first, so a wrong one is always wrong_password.
        failure = _reauthentication_failure(request.user, request.data)
        if failure is not None:
            return failure
        plan = request.data.get("plan") if isinstance(request.data, dict) else None
        if not isinstance(plan, str) or not plan:
            return _refused("plan_required", "Show the deletion preview first, and send its plan.")
        try:
            delete_account(request.user, expected_plan=plan)
        except PlanChanged:
            return Response({"code": "plan_changed",
                             "detail": "Who receives your shared projects or groups has changed. Review it again."},
                            status=409)
        return Response(status=204)
