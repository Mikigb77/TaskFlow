"""Check dictations against the real AI model, through the real views, as the app sends them.

For prompt changes: each named case goes to POST /api/ai/drafts/ (with commands, as today's app
asks) or, for «A tu manera», POST /api/ai/reminder-plan/, and the drafts' key fields are printed.
It uses an in-memory database and a throwaway account, as Pro, so the free account's monthly
dictations never stop a long check. Settings come from Backend/.env, loaded into this process only;
the AI is Vertex, signed in with the ADC from scripts/login-vertex.ps1. Run a case a few times
before trusting it.

Run from Backend/ with its virtualenv:
    .venv/Scripts/python.exe -X utf8 scripts/check_dictations.py [--times N] [case ...]
With no case, it runs them all. The reference time is Wednesday 21 October 2026, 10:00, Madrid.
"""
import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from unittest import mock
from zoneinfo import ZoneInfo

BACKEND = Path(__file__).resolve().parents[1]
for line in (BACKEND / ".env").read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))
os.environ["DJANGO_SECRET_KEY"] = "local-check-only"
os.environ.setdefault("AI_VERTEX_PROJECT", "taskflow-511107")
adc = BACKEND / ".credentials" / "gcloud" / "application_default_credentials.json"
if adc.exists():
    os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", str(adc))
os.environ["DJANGO_SETTINGS_MODULE"] = "config.test_settings"
sys.path.insert(0, str(BACKEND))
import django  # noqa: E402

django.setup()
from django.core.management import call_command  # noqa: E402
from django.test.utils import setup_test_environment  # noqa: E402

setup_test_environment()
call_command("migrate", verbosity=0)
from rest_framework.test import APIClient  # noqa: E402

from core.models import User  # noqa: E402

REFERENCE = datetime(2026, 10, 21, 10, 0, tzinfo=ZoneInfo("Europe/Madrid"))
# name: (language, words). Reminder plans (docs/REMINDER_PLANS.md) and the overdue search.
DICTATIONS = {
    "project-es": ("es", "Presentar el proyecto de la empresa en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día"),
    "report-ca": ("ca", "Entregar l'informe d'aquí a dues setmanes, recorda-m'ho cada dos dies"),
    "rent-en": ("en", "Pay the rent on the 30th, remind me the day before at 9"),
    "call-es": ("es", "Llamar a Ana mañana a las 10, avísame una hora antes"),
    "plain-es": ("es", "Comprar pan mañana"),
    "until-es": ("es", "Terminar la solicitud el jueves y recuérdamelo hasta la fecha límite"),
    "until-ca": ("ca", "Acabar la sol·licitud dijous i recorda-m'ho fins al termini"),
    "until-en": ("en", "Finish the application on Friday and remind me until the due date"),
    "noday-es": ("es", "Renovar el pasaporte, recuérdamelo cada semana"),
    "noday-en": ("en", "Book the car service, remind me every few days"),
    "noday-ca": ("ca", "Trucar al gestor, avisa'm una hora abans"),
    "week-before-es": ("es", "Comprar el regalo de Laura, recuérdamelo una semana antes"),
    "far-es": ("es", "Entregar la tesis en tres meses, recuérdamelo cada semana"),
    "habit-es": ("es", "Llamar a mamá, recuérdamelo cada día"),
    "overdue-es": ("es", "¿Qué tengo atrasado?"),
}
# name: (language, words, the task's anchor day). Pro only in the app.
MY_WAY = {
    "myway-es": ("es", "cada 3 días y la última semana a diario", "2026-11-11"),
    "myway-en": ("en", "every other day, then daily for the last 5 days, at 8 in the morning", "2026-11-11"),
    "myway-unclear": ("es", "comprar leche", "2026-11-11"),
}
KEYS = ("title", "date", "time", "deadline_date", "recurrence", "reminder_minutes", "reminder_plan",
        "reminder_needs_day", "questions")


def post(client, name):
    utc = REFERENCE.astimezone(ZoneInfo("UTC")).isoformat()
    with mock.patch("core.views.has_pro", return_value=True):
        if name in DICTATIONS:
            language, words = DICTATIONS[name]
            return client.post("/api/ai/drafts/", {
                "timezone": "Europe/Madrid", "capture_type": "task", "text": words, "source": "speech",
                "reference_time": utc, "language": language, "commands": True}, format="json")
        language, words, anchor = MY_WAY[name]
        return client.post("/api/ai/reminder-plan/", {
            "text": words, "timezone": "Europe/Madrid", "anchor_date": anchor, "language": language,
            "reference_time": utc}, format="json")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--times", type=int, default=1, help="runs of each case (default 1)")
    parser.add_argument("cases", nargs="*", help=f"any of: {', '.join([*DICTATIONS, *MY_WAY])}")
    args = parser.parse_args()
    unknown = [c for c in args.cases if c not in DICTATIONS and c not in MY_WAY]
    if unknown:
        raise SystemExit(f"unknown case(s): {', '.join(unknown)}")
    client = APIClient()
    client.force_authenticate(user=User.objects.create_user("check@example.invalid", "Check-only-password-2026"))
    for name in args.cases or [*DICTATIONS, *MY_WAY]:
        for run in range(1, args.times + 1):
            for attempt in range(1, 5):
                response = post(client, name)
                if response.status_code not in (429, 502, 503, 504):
                    break
                print(f"--- {name} #{run}: HTTP {response.status_code}, waiting (attempt {attempt})")
                time.sleep(25)
            body = response.json()
            if name in MY_WAY:
                print(f"=== {name} #{run}: HTTP {response.status_code} {json.dumps(body, ensure_ascii=False)}")
            else:
                print(f"=== {name} #{run}: HTTP {response.status_code}")
                for task in body.get("tasks", []):
                    print("   ", json.dumps({k: task.get(k) for k in KEYS}, ensure_ascii=False))
                for command in body.get("commands", []):
                    print("    command:", json.dumps(command, ensure_ascii=False)[:300])
            sys.stdout.flush()
            time.sleep(8)  # the free tier's rate


main()
