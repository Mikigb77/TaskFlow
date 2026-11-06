import json
from unittest.mock import patch

import httpx
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from . import app_updates
from .models import User

SHA = "a" * 64
RELEASE = {
    "published_at": "2026-11-06T10:00:00Z",
    "assets": [
        {"id": 11, "name": "taskflow-staging.apk", "size": 61_000_000,
         "url": "https://api.github.com/repos/o/r/releases/assets/11"},
        {"id": 12, "name": "staging-build.json", "size": 300,
         "url": "https://api.github.com/repos/o/r/releases/assets/12"},
    ],
}
BUILD = {"applicationId": "com.example.agenda.staging", "version": "1.0.6", "versionCode": "5210",
         "sha256": SHA, "commit": "abc1234"}


def github(release=RELEASE, build=BUILD, calls=None):
    def handler(request):
        if calls is not None:
            calls.append(request)
        path = request.url.path
        if path.endswith("/releases/latest"):
            return httpx.Response(200, json=release) if release else httpx.Response(404)
        if path.endswith("/assets/12"):
            return httpx.Response(302, headers={"location": "https://objects.example/build.json"})
        if request.url.host == "objects.example":
            return httpx.Response(200, content=json.dumps(build).encode())
        if path.endswith("/assets/11"):
            return httpx.Response(302, headers={"location": "https://objects.example/apk?sig=1"})
        return httpx.Response(500)

    def client():
        return httpx.Client(transport=httpx.MockTransport(handler),
                            headers={"Authorization": "Bearer t0ken"})
    return client


@override_settings(APP_UPDATE_GITHUB_TOKEN="t0ken", APP_UPDATE_REPOSITORY="o/r")
class AppUpdateTests(TestCase):
    def setUp(self):
        cache.clear()
        self.api = APIClient()
        self.api.force_authenticate(User.objects.create_user(email="tester@example.invalid", password="pw-123456789"))

    def test_signed_out_phones_get_nothing(self):
        self.assertEqual(APIClient().get("/api/app/update/").status_code, 401)
        self.assertEqual(APIClient().get("/api/app/update/download/").status_code, 401)

    @override_settings(APP_UPDATE_GITHUB_TOKEN="")
    def test_without_a_token_there_is_no_update(self):
        self.assertEqual(self.api.get("/api/app/update/").json(), {"available": False})
        self.assertEqual(self.api.get("/api/app/update/download/").status_code, 404)

    def test_newest_build_and_its_download(self):
        calls = []
        with patch.object(app_updates, "_client", github(calls=calls)):
            answer = self.api.get("/api/app/update/").json()
            self.assertEqual(answer, {"available": True, "version": "1.0.6", "version_code": 5210, "sha256": SHA,
                                      "size": 61_000_000, "commit": "abc1234",
                                      "published_at": "2026-11-06T10:00:00Z"})
            # Cached: a second phone doesn't ask GitHub again.
            self.api.get("/api/app/update/")
            self.assertEqual(sum(c.url.path.endswith("/latest") for c in calls), 1)
            download = self.api.get("/api/app/update/download/").json()
        self.assertEqual(download, {"url": "https://objects.example/apk?sig=1", "version": "1.0.6", "version_code": 5210,
                                    "sha256": SHA})
        # The token never travels to GitHub's storage.
        storage = [c for c in calls if c.url.host == "objects.example"]
        self.assertTrue(storage)
        self.assertTrue(all("authorization" not in c.headers for c in storage))

    def test_a_release_without_a_valid_build_is_no_update(self):
        for release, build in [(None, BUILD), ({"assets": RELEASE["assets"][:1]}, BUILD),
                               (RELEASE, {**BUILD, "applicationId": "com.example.agenda"}),
                               (RELEASE, {**BUILD, "sha256": "nope"}),
                               (RELEASE, {**BUILD, "versionCode": "x"})]:
            cache.clear()
            with patch.object(app_updates, "_client", github(release, build)):
                self.assertEqual(self.api.get("/api/app/update/").json(), {"available": False})
                self.assertEqual(self.api.get("/api/app/update/download/").status_code, 404)

    def test_github_trouble_is_a_503(self):
        def broken():
            return httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(502)))
        with patch.object(app_updates, "_client", broken):
            self.assertEqual(self.api.get("/api/app/update/").status_code, 503)
            self.assertEqual(self.api.get("/api/app/update/download/").status_code, 503)
