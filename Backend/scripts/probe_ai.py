"""Explicit manual provider check. Does not print credentials or create tasks."""
import os
import sys
from pathlib import Path
import django

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()
from core.ai import generate, build_prompt, validate_draft
from datetime import datetime, timezone

try:
    raw = generate(build_prompt({"text": "I have a doctor appointment on Friday at 5.", "timezone": "Europe/Madrid", "reference_time": datetime(2026, 9, 20, 12, tzinfo=timezone.utc)}))
    print(raw)
    print(validate_draft(raw))
except Exception as error:
    print(type(error).__name__, str(getattr(error, "message", error)))
