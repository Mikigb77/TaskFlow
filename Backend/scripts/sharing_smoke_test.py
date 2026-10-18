"""Explicit local-only PostgreSQL/HTTP concurrency check with scoped cleanup.

No AI calls, emails or real accounts. Run inside the development API container.
"""
import os
import sys
import secrets
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from pathlib import Path
import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()
from core.models import User


def main():
    base = 'http://127.0.0.1:8000/api/'
    stamp = uuid.uuid4().hex
    accounts = []
    list_id = uuid.uuid4()

    def call(method, path, token=None, data=None, expected=200):
        result = requests.request(method, base + path, json=data,
            headers={'Authorization': f'Bearer {token}'} if token else {}, timeout=30)
        assert result.status_code == expected, f'{path}: HTTP {result.status_code}'
        return result.json() if result.content else None

    try:
        for name in ['owner', 'editor']:
            email = f'sharing-race-{stamp}-{name}@example.invalid'
            password = secrets.token_urlsafe(24)
            # Made already confirmed: signing up through the API now waits for the emailed code.
            user = User.objects.create_user(email, password, email_verified=True)
            accounts.append([user.pk, email, None])  # recorded first, so cleanup always removes it
            accounts[-1][2] = call('POST', 'auth/login/', data={'email': email, 'password': password})['access']
        owner, editor = [account[2] for account in accounts]
        root = f'lists/{list_id}/'
        call('PUT', root, owner, {'name': 'Race fixture', 'version': 0}, 201)
        invitation = call('POST', root + 'invite/', owner, {'email': accounts[1][1], 'role': 'editor'}, 201)
        call('POST', f"invitations/{invitation['id']}/respond/", editor, {'decision': 'accept', 'code': invitation['code']})
        key = uuid.uuid4()
        task = call('PUT', f'tasks/{key}/', editor, {'title': 'Original', 'list_id': str(list_id), 'version': 0}, 201)
        barrier = Barrier(2)
        def edit(token, title):
            barrier.wait(timeout=10)
            return requests.put(base + f'tasks/{key}/', json={**task, 'title': title}, headers={'Authorization': f'Bearer {token}'}, timeout=30).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(edit, owner, 'Owner edit')
            b = pool.submit(edit, editor, 'Editor edit')
            statuses = sorted([a.result(), b.result()])
        assert statuses == [200, 409], statuses
        current = call('GET', f'tasks/{key}/', owner)
        assert current['version'] == 2 and current['title'] in ['Owner edit', 'Editor edit']
        print('PASS concurrent PostgreSQL writes: one success, one 409; no lost version')

        barrier = Barrier(2)
        def remove():
            barrier.wait(timeout=10)
            return requests.post(base + root + 'member/', json={'user_id': accounts[1][0], 'role': 'remove'}, headers={'Authorization': f'Bearer {owner}'}, timeout=30).status_code
        task = current
        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(edit, editor, 'Last permitted edit')
            b = pool.submit(remove)
            edit_status, removal_status = a.result(), b.result()
        assert removal_status == 204 and edit_status in [200, 404], (edit_status, removal_status)
        call('GET', f'tasks/{key}/', editor, expected=404)
        assert call('GET', 'lists/access/', editor)['lists'] == []
        print(f'PASS membership removal/write race: edit={edit_status}; all later access revoked')
    finally:
        if accounts:
            token = accounts[0][2]
            result = requests.get(base + f'lists/{list_id}/', headers={'Authorization': f'Bearer {token}'}, timeout=30)
            if result.status_code == 200:
                call('DELETE', f'lists/{list_id}/', token, {'version': result.json()['version']}, 204)
        for user_id, email, _ in accounts:
            query = User.objects.filter(pk=user_id, email=email)
            assert not query.filter(attachments__isnull=False).exists()
            query.delete()
        print('Removed exact synthetic race accounts and list; no file fixtures created')


if __name__ == '__main__':
    main()
