"""Run with Django shell in the staging container, with /fixtures mounted privately.

Creates two isolated synthetic users, never the owner's personal account. The
result contains credentials and belongs in ignored App/build, never Git/logs.
"""
import json
from pathlib import Path
import secrets
import uuid
from django.conf import settings
from django.db import connection
from core.models import User

assert settings.DEPLOYMENT_ENVIRONMENT == 'staging'
assert connection.settings_dict['NAME'] == 'taskflow_staging'
path = Path('/fixtures/staging-e2e.json')
if path.exists():
    fixture = json.loads(path.read_text())
    assert User.objects.filter(email=fixture['PROJECT_E2E_EMAIL']).exists()
else:
    suffix = uuid.uuid4().hex[:10]
    password = secrets.token_urlsafe(24) + '9!'
    owner = User.objects.create_user(f'delivered+tf-owner-{suffix}@resend.dev', password)
    outsider = User.objects.create_user(f'delivered+tf-outsider-{suffix}@resend.dev', password)
    fixture = {
        'PROJECT_E2E_EMAIL': owner.email, 'PROJECT_E2E_PASSWORD': password,
        'PROJECT_E2E_MEMBER_EMAIL': f'delivered+tf-member-{suffix}@resend.dev',
        'STAGING_OUTSIDER_EMAIL': outsider.email,
        'API_BASE_URL': 'https://taskflow-api-staging-177649734578.europe-west3.run.app',
        'APP_ENV': 'staging', 'DEV_LOGIN_ENABLED': False,
    }
    path.write_text(json.dumps(fixture, indent=2) + '\n')
print('Isolated staging fixture ready; credentials saved privately.')
