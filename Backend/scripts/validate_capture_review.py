"""Real staging extraction checks using synthetic text and a private test user.

Never prints credentials. It creates no tasks, sends no emails, and uses the
same authenticated, metered capture endpoint as the phone.
"""
import argparse
import json
from pathlib import Path
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['es-details', 'es-long-title', 'ca', 'en-batch', 'es-ambiguous'])
    selected = parser.parse_args().case
    fixture = json.loads(Path('../App/build/staging-e2e.json').read_text(encoding='utf-8-sig'))
    base = fixture['API_BASE_URL'].rstrip('/') + '/api/'
    assert base == 'https://taskflow-api-staging-177649734578.europe-west3.run.app/api/'
    assert fixture['PROJECT_E2E_EMAIL'].startswith('delivered+tf-owner-')

    def call(endpoint, body, token=None):
        request = Request(base + endpoint, data=json.dumps(body, ensure_ascii=False).encode('utf-8'),
                          headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer ' + token} if token else {})})
        with urlopen(request, timeout=110) as response:
            return json.loads(response.read().decode('utf-8'))

    login = call('auth/login/', {'email': fixture['PROJECT_E2E_EMAIL'], 'password': fixture['PROJECT_E2E_PASSWORD']})
    token = login['access']
    cases = [
        ('es-details', 'El viernes a las cinco de la tarde tengo una cita con el médico. Necesito llevar los análisis de sangre del mes pasado.', 1),
        ('es-long-title', 'Mañana tengo que comprobar que la aplicación esté funcionando y que no tenga que utilizar ninguna funcionalidad que no esté ya programada.', 1),
        ('ca', 'Demà a les deu del matí tinc una reunió amb la Núria i he de portar els apunts de física.', 1),
        ('en-batch', 'Call Ana tomorrow at 09:30. Buy coffee sometime. Submit the report by Friday.', 3),
        ('es-ambiguous', 'Mañana a las cinco tengo una cita con el médico.', 1),
    ]
    output = []
    for name, text, count in cases:
        if selected and name != selected:
            continue
        result = call('ai/drafts/', {'text': text, 'timezone': 'Europe/Madrid',
                                    'reference_time': '2026-10-12T10:00:00Z', 'capture_type': 'task'}, token)
        tasks = result['tasks']
        assert len(tasks) == count, (name, 'task count')
        assert all(len(t['title']) <= 80 for t in tasks), (name, 'title length')
        assert all('Ã' not in t['title'] and 'Ã' not in t['notes'] for t in tasks), (name, 'Unicode')
        if name == 'es-details':
            assert tasks[0]['due_date'].startswith('2026-10-16T17:00'), 'Spanish appointment time'
            assert 'análisis' in tasks[0]['notes'].lower() and 'mes' in tasks[0]['notes'].lower(), 'Preparation notes'
        elif name == 'es-long-title':
            assert tasks[0]['scheduled_date'] == '2026-10-13' and tasks[0]['due_date'] is None, 'Date only'
            assert tasks[0]['notes'], 'Long-title details retained'
        elif name == 'ca':
            assert tasks[0]['due_date'].startswith('2026-10-13T10:00'), 'Catalan appointment time'
            assert 'apunts' in tasks[0]['notes'].lower(), 'Catalan preparation notes'
        elif name == 'en-batch':
            assert any(t['due_date'] and t['due_date'].startswith('2026-10-13T09:30') for t in tasks)
            assert any(t['due_date'] is None and t['scheduled_date'] is None and t['deadline_date'] is None for t in tasks)
            assert any(t['deadline_date'] == '2026-10-16' and t['due_date'] is None for t in tasks)
        else:
            assert tasks[0]['scheduled_date'] == '2026-10-13' and tasks[0]['due_date'] is None, 'Ambiguous time remains unset'
            assert any(c['field'] == 'schedule' and set(c['times']) == {'05:00', '17:00'} for c in tasks[0]['clarifications']), 'Explicit morning/afternoon choices'
        output.append({'case': name, 'tasks': tasks, 'timings': result.get('timings')})
        print(f'{name}: passed ({len(tasks)} tasks)', flush=True)
    destination = f'artifacts/capture-review-live-{selected}.json' if selected else 'artifacts/capture-review-live.json'
    Path(destination).write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
