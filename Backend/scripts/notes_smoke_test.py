"""Explicit local-only test: one synthetic WAV transcription, note sync, cleanup.

Uses the configured transcription model; does not call task extraction or fall
back to a different provider. Supply a synthetic WAV path inside the container.
"""
import argparse
import os
import secrets
import sys
import time
import uuid
from pathlib import Path
import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()
from core.models import User


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('audio', type=Path)
    args = parser.parse_args()
    base = 'http://127.0.0.1:8000/api/'
    email = f'notes-live-{uuid.uuid4().hex}@example.invalid'
    password = secrets.token_urlsafe(24)
    account = None
    try:
        # Made already confirmed: signing up through the API now waits for the emailed code.
        account = User.objects.create_user(email, password, email_verified=True)
        login = requests.post(base + 'auth/login/', json={'email': email, 'password': password}, timeout=30)
        assert login.status_code == 200, login.status_code
        headers = {'Authorization': f"Bearer {login.json()['access']}"}
        started = time.monotonic()
        with args.audio.open('rb') as recording:
            response = requests.post(base + 'ai/drafts/', headers=headers,
                data={'capture_type': 'note', 'timezone': 'UTC'},
                files={'audio': ('synthetic.wav', recording, 'audio/wav')}, timeout=100)
        elapsed = round((time.monotonic() - started) * 1000)
        assert response.status_code == 200, f'Live transcription HTTP {response.status_code}; elapsed={elapsed} ms'
        result = response.json()
        assert len(result['tasks']) == 1
        note = result['tasks'][0]
        assert note['kind'] == 'note' and note['notes'] == result['transcript'] and note['notes'].strip()
        assert note['due_date'] is None and note['scheduled_date'] is None
        key = uuid.uuid4()
        created = requests.put(base + f'tasks/{key}/', headers=headers,
            json={key: value for key, value in note.items() if key in {'kind', 'title', 'notes', 'priority'}}, timeout=30)
        assert created.status_code == 201, created.status_code
        fresh = requests.post(base + 'auth/login/', json={'email': email, 'password': password}, timeout=30)
        assert fresh.status_code == 200
        read = requests.get(base + f'tasks/{key}/', headers={'Authorization': f"Bearer {fresh.json()['access']}"}, timeout=30)
        assert read.status_code == 200 and read.json()['kind'] == 'note' and read.json()['notes'] == note['notes']
        print(f'PASS live synthetic WAV to one unchanged note; new-session HTTP restoration; {elapsed} ms, {len(note["notes"])} characters')
    finally:
        if account is not None:
            query = User.objects.filter(pk=account.pk, email=email)
            assert not query.filter(attachments__isnull=False).exists()
            query.delete()
            print('Removed exact synthetic note account and records; no server file fixtures')


if __name__ == '__main__':
    main()
