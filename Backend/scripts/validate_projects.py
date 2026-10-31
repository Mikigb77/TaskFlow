"""Opt-in local integration fixture. Creates isolated synthetic accounts only.

Run from the repository root, with the local Docker stack running. Test Store
purchases follow RevenueCat's official CLI receipt flow (internal/api/sdk.go and
internal/cli/customers.go). A test_ SDK key cannot charge a real payment method.
No credentials are printed.
"""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen


# A fixed Sunday keeps relative-date assertions reproducible on every run.
REFERENCE_TIME = "2026-10-11T12:00:00+02:00"
BACKEND = Path(__file__).resolve().parents[1]


def create_confirmed_accounts(emails, password):
    """Make the accounts already confirmed, through Django in the local API container.

    Signing up through the API now waits for the code emailed to the address. The password
    reaches the container on stdin, never on a command line."""
    program = ("import json, sys\n"
               "from core.models import User\n"
               "data = json.load(sys.stdin)\n"
               "for email in data['emails']:\n"
               "    User.objects.create_user(email, data['password'], timezone='Europe/Madrid', email_verified=True)\n")
    subprocess.run(["docker", "compose", "exec", "-T", "api", "python", "manage.py", "shell", "-c", program],
                   input=json.dumps({"emails": emails, "password": password}), text=True, check=True,
                   cwd=BACKEND, stdout=subprocess.DEVNULL)


def call(base, method, path, data=None, token=None, expect=200, headers=None):
    request = Request(base + path, method=method, data=None if data is None else data if isinstance(data, bytes) else json.dumps(data).encode(),
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {}), **(headers or {})})
    try:
        with urlopen(request, timeout=90) as response:
            status, raw = response.status, response.read()
    except HTTPError as error:
        status, raw = error.code, error.read()
    if status != expect:
        raise AssertionError(f"{method} {path}: expected {expect}, received {status}; {raw.decode()[:400]}")
    return json.loads(raw) if raw else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-key", default="")
    parser.add_argument("--fixture", default="App/build/project-e2e.json")
    parser.add_argument("--billing-only", action="store_true", help="Retry billing/AI using the existing isolated fixture.")
    parser.add_argument("--skip-ai", action="store_true", help="Refresh only the sandbox purchase, without an AI request.")
    args = parser.parse_args()
    base = "http://127.0.0.1:8088/api/"
    if args.billing_only:
        fixture = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
        owner = call(base, "POST", "auth/login/", {"email": fixture["PROJECT_E2E_EMAIL"], "password": fixture["PROJECT_E2E_PASSWORD"]})
        verify_billing(base, args.test_key, owner, fixture, skip_ai=args.skip_ai)
        return
    suffix = uuid.uuid4().hex[:8]
    password = secrets.token_urlsafe(24) + "4!"
    emails = [f"{prefix}-{suffix}@example.invalid" for prefix in ("project-owner", "ana-project", "project-outsider")]
    create_confirmed_accounts(emails, password)
    people = [{"email": email, **call(base, "POST", "auth/login/", {"email": email, "password": password})}
              for email in emails]
    owner, member, outsider = people
    own, mem, out = [person["access"] for person in people]
    group = call(base, "POST", "groups/", {"name": f"Master {suffix}", "version": 0}, own, expect=201)
    invitation = call(base, "POST", f"groups/{group['id']}/invite/", {"email": member["email"], "role": "editor"}, own, expect=201)
    call(base, "POST", f"group-invitations/{invitation['id']}/respond/", {"decision": "accept", "code": "wrong-code"}, mem, expect=400)
    call(base, "POST", f"group-invitations/{invitation['id']}/respond/", {"decision": "accept", "code": invitation["code"]}, mem)
    call(base, "POST", f"groups/{group['id']}/profile/", {"voice_name": "Ana"}, mem)
    project = call(base, "PUT", f"lists/{uuid.uuid4()}/", {"name": "Physics", "color": "blue", "group_id": group["id"], "version": 0}, own, expect=201)
    payload = {"title": "Finish exercise three", "priority": 1, "list_id": project["id"],
        "assignment": "member", "assignee_id": member["user"]["id"], "deadline_date": "2026-10-15", "notes": "Bring the presentation"}
    task = call(base, "POST", "tasks/", payload, own, expect=201)
    assert call(base, "GET", f"tasks/{task['id']}/", token=mem)["assignee_id"] == member["user"]["id"]
    call(base, "GET", f"tasks/{task['id']}/", token=out, expect=404)
    completed = call(base, "PUT", f"tasks/{task['id']}/", {**task, "is_completed": True}, mem)
    assert call(base, "GET", f"tasks/{task['id']}/", token=own)["is_completed"] is True
    history = call(base, "GET", f"tasks/{task['id']}/history/", token=own)
    assert any(event["action"] == "completed" and event["actor_id"] == member["user"]["id"] for event in history)
    call(base, "PUT", f"tasks/{task['id']}/", {**completed, "is_completed": False}, own)
    notifications = call(base, "GET", "notifications/", token=mem)
    assert notifications["count"] > 0
    call(base, "POST", "notifications/read_all/", {}, mem, expect=204)
    assert call(base, "GET", "notifications/unread/", token=mem)["count"] == 0
    call(base, "POST", f"lists/{project['id']}/preferences/", {"pinned": True, "notifications": "assigned"}, own)
    assert any(item["pinned"] for item in call(base, "GET", "lists/access/", token=own)["lists"])
    # The Django tests cover the free dictation limit; a new account starts with all of it.
    me = call(base, "GET", "auth/me/", token=own)
    limits = {"free_voice": me["free_voice"], "storage": me["storage"]}
    assert me["free_voice"]["left"] == me["free_voice"]["limit"] and me["storage"]["used_bytes"] == 0, limits
    fixture = {
        "PROJECT_E2E_EMAIL": owner["email"], "PROJECT_E2E_PASSWORD": password,
        "PROJECT_E2E_MEMBER_EMAIL": member["email"], "PROJECT_E2E_MEMBER_ID": str(member["user"]["id"]),
        "PROJECT_E2E_GROUP": group["id"], "PROJECT_E2E_PROJECT": project["id"],
        "PROJECT_E2E_TASK": task["id"], "API_BASE_URL": "http://10.0.2.2:8088",
    }
    path = Path(args.fixture)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
    print("Live groups, invitation, assignment, shared completion, isolation, history, preferences and free tier passed.", flush=True)
    verify_billing(base, args.test_key, owner, fixture, skip_ai=args.skip_ai)
    print(json.dumps({"groups": "passed", "invitations": "passed", "member_assignment": "passed",
        "shared_completion": "passed", "access_isolation": "passed", "history": "passed",
        "notifications": "passed", "preferences": "passed", "free_tier": "passed"}))


def verify_billing(base, test_key, owner, fixture, *, skip_ai=False):
    own = owner["access"]
    project = {"id": fixture["PROJECT_E2E_PROJECT"]}
    billing_active = False
    if test_key:
        assert test_key.startswith("test_"), "This validator refuses real store keys."
        receipt = call("https://api.revenuecat.com/v1/", "POST", "receipts", {
            "fetch_token": f"TEST_{int(time.time() * 1000)}_{secrets.token_hex(16)}",
            "app_user_id": owner["user"]["billing_id"], "product_id": "monthly",
            "initiation_source": "purchase", "sdk_originated": True,
        }, test_key, headers={"X-Platform": "iOS", "X-Version": "rc-cli", "X-Client-Bundle-Id": "com.revenuecat.cli"})
        assert "taskflow_pro" in receipt["subscriber"]["entitlements"], {"entitlements": receipt["subscriber"]["entitlements"], "subscriptions": receipt["subscriber"]["subscriptions"]}
        status = call(base, "POST", "billing/access/", {}, own)
        assert status["active"] and status["sandbox"], status
        billing_active = True
        if skip_ai:
            print('Real Test Store purchase and server entitlement passed. AI explicitly skipped.')
            return
        drafts = call(base, "POST", "ai/drafts/", {"text": "Ana needs to finish exercise three in Physics by Thursday. We all need to prepare the final presentation in Physics by Friday.",
            "timezone": "Europe/Madrid", "reference_time": REFERENCE_TIME, "project_id": project["id"]}, own)
        assert len(drafts["tasks"]) == 2, drafts
        assigned = [d for d in drafts["tasks"] if d["assignment"] == "member"]
        assert len(assigned) == 1 and assigned[0]["assignee_id"] == int(fixture["PROJECT_E2E_MEMBER_ID"]), drafts
        assert all(d["list_id"] == project["id"] and not d["assignment_issues"] for d in drafts["tasks"]), drafts
        group = [d for d in drafts["tasks"] if d["assignment"] == "group"]
        assert len(group) == 1, drafts
        assert assigned[0]["deadline_date"] == "2026-10-15", drafts
        assert group[0]["deadline_date"] == "2026-10-16", drafts
        assert all(not d["due_date"] and not d.get("deadline_at") for d in drafts["tasks"]), drafts
    print(json.dumps({"real_test_store_and_ai": "passed" if billing_active else "not requested"}))


if __name__ == "__main__":
    main()
