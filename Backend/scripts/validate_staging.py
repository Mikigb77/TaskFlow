"""Opt-in real HTTPS staging smoke test. Uses Resend's simulated recipients only.

Seed with seed_staging_check.py first: it also creates the invited member, already
confirmed. Credentials/invitation codes remain in the ignored fixture; stdout
reports checks, never tokens or provider payloads.
"""
import argparse
import hashlib
import json
from pathlib import Path
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from validate_projects import verify_billing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixture', default='../App/build/staging-e2e.json')
    parser.add_argument('--billing-only', action='store_true')
    parser.add_argument('--skip-ai', action='store_true')
    args = parser.parse_args()
    path = Path(args.fixture)
    f = json.loads(path.read_text(encoding='utf-8-sig'))
    base = f['API_BASE_URL'] + '/api/'
    assert base == 'https://taskflow-api-staging-177649734578.europe-west3.run.app/api/'
    assert f['PROJECT_E2E_EMAIL'].startswith('delivered+tf-owner-')

    def call(method, endpoint, data=None, token=None, expect=200, headers=None, binary=False):
        request = Request(base + endpoint, method=method,
            data=data if isinstance(data, bytes) else None if data is None else json.dumps(data).encode(),
            headers={'Content-Type': 'application/json',
                **({'Authorization': f'Bearer {token}'} if token else {}), **(headers or {})})
        try:
            with urlopen(request, timeout=110) as response:
                status, raw = response.status, response.read()
        except HTTPError as error:
            status, raw = error.code, error.read()
        if status != expect:
            raise AssertionError(f'{method} {endpoint.split("?")[0]}: expected {expect}, received {status}')
        return raw if binary else json.loads(raw) if raw else None

    owner = call('POST', 'auth/login/', {'email': f['PROJECT_E2E_EMAIL'], 'password': f['PROJECT_E2E_PASSWORD']})
    own = owner['access']
    if not args.billing_only:
        call('GET', 'health/')
        call('GET', 'auth/me/', token=own)
        rotated = call('POST', 'auth/refresh/', {'refresh': owner['refresh']})
        call('POST', 'auth/refresh/', {'refresh': owner['refresh']}, expect=401)
        own = rotated['access']
        owner['access'] = own
        # Staging sign-up is open, and waits for the emailed code. The sign-up is never finished.
        signup = call('POST', 'auth/register/', {'email': 'delivered+tf-not-invited@resend.dev', 'password': f['PROJECT_E2E_PASSWORD']}, expect=201)
        assert signup.get('verification_required') is True and not {'access', 'refresh'} & set(signup), 'Sign-up must wait for the emailed code.'
        outsider = call('POST', 'auth/login/', {'email': f['STAGING_OUTSIDER_EMAIL'], 'password': f['PROJECT_E2E_PASSWORD']})
        out = outsider['access']
        print('HTTPS, Neon health, login, refresh rotation and open sign-up waiting for the email code passed.', flush=True)
        group = call('POST', 'groups/', {'name': '[Staging check] Master', 'version': 0}, own, 201)
        invitation = call('POST', f"groups/{group['id']}/invite/", {'email': f['PROJECT_E2E_MEMBER_EMAIL'], 'role': 'editor'}, own, 201)
        assert invitation['email_status'] == 'sent', 'Invitation has not reached Resend yet.'
        f.update({'PROJECT_E2E_GROUP': group['id'], 'STAGING_INVITATION_ID': invitation['id'], 'STAGING_INVITATION_CODE': invitation['code']})
        path.write_text(json.dumps(f, indent=2) + '\n')
        # The invited member is a seeded, confirmed account: signing up would need the emailed code.
        member = call('POST', 'auth/login/', {'email': f['PROJECT_E2E_MEMBER_EMAIL'], 'password': f['PROJECT_E2E_PASSWORD']})
        mem = member['access']
        call('POST', f"group-invitations/{invitation['id']}/respond/", {'decision':'accept', 'code': invitation['code']}, out, 404)
        call('POST', f"group-invitations/{invitation['id']}/respond/", {'decision':'accept', 'code': 'wrong-code'}, mem, 400)
        call('POST', f"group-invitations/{invitation['id']}/respond/", {'decision':'accept', 'code': invitation['code']}, mem)
        call('POST', f"groups/{group['id']}/profile/", {'voice_name':'Ana'}, mem)
        project = call('PUT', f'lists/{uuid.uuid4()}/', {'name':'Physics', 'color':'blue', 'group_id':group['id'], 'version':0}, own, 201)
        task = call('POST', 'tasks/', {'title':'Finish exercise three', 'priority':1, 'list_id':project['id'], 'assignment':'member', 'assignee_id':member['user']['id'], 'deadline_date':'2026-10-15'}, own, 201)
        call('GET', f"tasks/{task['id']}/", token=out, expect=404)
        done = call('PUT', f"tasks/{task['id']}/", {**task, 'is_completed':True}, mem)
        assert call('GET', f"tasks/{task['id']}/", token=own)['is_completed']
        call('PUT', f"tasks/{task['id']}/", {**done, 'is_completed':False}, own)
        payload = b'TaskFlow private staging attachment: synthetic test only.\n'
        boundary = uuid.uuid4().hex
        parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode() for key,value in {'task_id':task['id'], 'name':'staging-check.txt'}.items()]
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="staging-check.txt"\r\nContent-Type: text/plain\r\n\r\n'.encode()+payload+f'\r\n--{boundary}--\r\n'.encode())
        attachment_id = str(uuid.uuid4())
        item = call('PUT', f'attachments/{attachment_id}/', b''.join(parts), own, 201, {'Content-Type':f'multipart/form-data; boundary={boundary}'})
        assert item['sha256'] == hashlib.sha256(payload).hexdigest()
        assert call('GET', f'attachments/{attachment_id}/content/', token=mem, binary=True) == payload
        call('GET', f'attachments/{attachment_id}/content/', token=out, expect=404)
        call('DELETE', f'attachments/{attachment_id}/', token=own, expect=204)
        call('GET', f'attachments/{attachment_id}/content/', token=mem, expect=404)
        call('POST', 'auth/password-reset/', {'email':f['STAGING_OUTSIDER_EMAIL']})
        call('POST', 'auth/logout/', {}, out, 204)
        call('GET', 'auth/me/', token=out, expect=401)
        # The Django tests cover the free limits; earlier runs may have used some, so check the shape only.
        me = call('GET', 'auth/me/', token=own)
        assert {'limit', 'left', 'resets_at'} <= set(me['free_voice']) and {'used_bytes', 'limit_bytes'} <= set(me['storage'])
        f.update({'PROJECT_E2E_MEMBER_ID':str(member['user']['id']), 'PROJECT_E2E_PROJECT':project['id'], 'PROJECT_E2E_TASK':task['id']})
        path.write_text(json.dumps(f, indent=2) + '\n')
        print('Real Resend invitation, invited member, acceptance proof, shared tasks, private Neon files, deletion, recovery and logout passed.', flush=True)
    config = json.loads((Path(__file__).parents[2] / 'App/config/staging.json').read_text())
    f.update({key:config[key] for key in ('GOOGLE_SERVER_CLIENT_ID','REVENUECAT_TEST_API_KEY')})
    path.write_text(json.dumps(f, indent=2) + '\n')
    verify_billing(base, config['REVENUECAT_TEST_API_KEY'], owner, f, skip_ai=args.skip_ai)


if __name__ == '__main__':
    main()
