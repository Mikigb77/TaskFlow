"""Run explicitly against the local Docker API. Uses synthetic accounts and tasks.

python scripts/smoke_test.py [--audio /tmp/doctor.wav]
Calls the configured Google models; it never prints keys, passwords or tokens.
"""
import argparse
import json
import secrets
import uuid
import requests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio")
    parser.add_argument("--base", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    base = args.base + "/api/"
    email = f"smoke-{uuid.uuid4().hex}@example.invalid"
    password = secrets.token_urlsafe(24)

    def call(path, data=None, token=None, method="POST", expected=200, **kwargs):
        response = requests.request(method, base + path, json=data,
            headers={"Authorization": f"Bearer {token}"} if token else {}, timeout=110, **kwargs)
        assert response.status_code == expected, f"{path}: HTTP {response.status_code}: {response.text[:300]}"
        return response.json() if response.content else None

    session = call("auth/register/", {"email": email, "password": password, "timezone": "Europe/Madrid"}, expected=201)
    session = call("auth/login/", {"email": email.upper(), "password": password})
    rotated = call("auth/refresh/", {"refresh": session["refresh"]})
    call("auth/refresh/", {"refresh": session["refresh"]}, expected=401)
    session.update(rotated)
    token = session["access"]
    assert call("auth/me/", token=token, method="GET")["email"] == email
    print("PASS registration, login, authenticated profile, refresh rotation and replay prevention")

    sample = {"text": "On Friday at 5 p.m. I have an appointment with the doctor. I need to bring the blood test results from last month.",
              "timezone": "Europe/Madrid", "reference_time": "2026-09-20T12:00:00+02:00"}
    draft = call("ai/draft/", sample, token)
    assert draft["due_date"] == "2026-09-25T17:00:00+02:00", draft
    assert draft["priority"] == 3 and "blood" in draft["notes"].lower(), draft
    assert call("tasks/", token=token, method="GET")["count"] == 0
    print("PASS live Gemma draft:", json.dumps(draft, ensure_ascii=False))
    task = call("tasks/", {key: draft[key] for key in ["title", "due_date", "priority", "notes"]}, token, expected=201)
    recovered = call("auth/login/", {"email": email, "password": password})
    assert call("tasks/", token=recovered["access"], method="GET")["results"][0]["id"] == task["id"]
    print("PASS task saved and recovered in a new session")
    other = call("auth/register/", {"email": f"other-{uuid.uuid4().hex}@example.invalid", "password": secrets.token_urlsafe(24)}, expected=201)
    assert call("tasks/", token=other["access"], method="GET")["count"] == 0
    call(f"tasks/{task['id']}/", token=other["access"], method="GET", expected=404)
    print("PASS cross-account isolation")

    ambiguous = call("ai/draft/", {**sample, "text": "I have a doctor appointment on Friday at 5."}, token)
    assert ambiguous["due_date"] is None and ambiguous["questions"], ambiguous
    print("PASS ambiguous time asks for clarification")
    if args.audio:
        with open(args.audio, "rb") as audio:
            response = requests.post(base + "ai/draft/", headers={"Authorization": f"Bearer {token}"},
                data={"timezone": sample["timezone"], "reference_time": sample["reference_time"]},
                files={"audio": ("doctor.wav", audio, "audio/wav")}, timeout=110)
        assert response.status_code == 200, f"Audio draft: {response.status_code}: {response.text[:300]}"
        spoken = response.json()
        assert "doctor" in spoken["transcript"].lower() and spoken["due_date"] == "2026-09-25T17:00:00+02:00", spoken
        print("PASS live speech-to-text and task extraction:", json.dumps(spoken, ensure_ascii=False))

    call("auth/password-reset/", {"email": email})
    inbox = requests.get("http://mailpit:8025/api/v1/messages", timeout=10).json()
    matching = [m for m in inbox["messages"] if any(to["Address"] == email for to in m["To"])]
    assert matching, "Recovery email was not delivered to Mailpit"
    message = requests.get("http://mailpit:8025/api/v1/message/" + matching[0]["ID"], timeout=10).json()
    code = message["Text"].replace("\r\n", "\n").split("recovery code in the app:\n", 1)[1].splitlines()[0]
    call("auth/password-reset/confirm/", {"code": code, "password": secrets.token_urlsafe(24)})
    call("auth/me/", token=token, method="GET", expected=401)
    print("PASS recovery email delivery, reset and session revocation")
    call("auth/logout/", {}, other["access"], expected=204)
    call("auth/me/", token=other["access"], method="GET", expected=401)
    print("PASS logout revokes access immediately")


if __name__ == "__main__":
    main()
