"""The newest staging build of the app, for the staging app's own updater.

GitHub Actions publishes each staging APK as the newest release of the private
app repository (.github/workflows/deploy.yml), with `staging-build.json`
beside it. A phone can't read a private release, so the backend reads it with a
read-only token and gives a signed-in phone what it needs: the build's version,
its SHA-256, and on request a short-lived download link straight from GitHub.

Only staging has the token (APP_UPDATE_GITHUB_TOKEN). Without it the endpoints
answer that there is no update, which is also what production says: the
production app updates through Google Play.
"""
import re

import httpx
from django.conf import settings
from django.core.cache import cache
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

APPLICATION_ID = "com.example.agenda.staging"
APK_NAME = "taskflow-staging.apk"
BUILD_NAME = "staging-build.json"
CACHE_KEY = "app-update:latest"
CACHE_SECONDS = 300
_API = "https://api.github.com"
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class UpdateUnavailable(Exception):
    pass


def _client():
    return httpx.Client(
        timeout=10,
        headers={
            "Authorization": f"Bearer {settings.APP_UPDATE_GITHUB_TOKEN}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "taskflow-api",
        },
    )


def configured():
    return bool(settings.APP_UPDATE_GITHUB_TOKEN and settings.APP_UPDATE_REPOSITORY)


def _fetch_latest():
    repo = settings.APP_UPDATE_REPOSITORY
    with _client() as client:
        release = client.get(f"{_API}/repos/{repo}/releases/latest",
                             headers={"Accept": "application/vnd.github+json"})
        if release.status_code == 404:
            return None
        release.raise_for_status()
        data = release.json()
        assets = {asset.get("name"): asset for asset in data.get("assets") or []}
        apk, build = assets.get(APK_NAME), assets.get(BUILD_NAME)
        if not apk or not build:
            return None
        # GitHub answers an asset's API URL with a redirect to its storage;
        # httpx drops the token when it follows it to another host.
        described = client.get(build["url"], headers={"Accept": "application/octet-stream"},
                               follow_redirects=True)
        described.raise_for_status()
        info = described.json()
    try:
        code = int(info["versionCode"])
    except (KeyError, TypeError, ValueError):
        return None
    sha256 = str(info.get("sha256", "")).lower()
    if info.get("applicationId") != APPLICATION_ID or not _SHA256.match(sha256) or code <= 0:
        return None
    return {
        "version": str(info.get("version", "")),
        "version_code": code,
        "sha256": sha256,
        "size": int(apk.get("size") or 0),
        "commit": str(info.get("commit", ""))[:40],
        "published_at": data.get("published_at"),
        "asset_id": int(apk["id"]),
    }


def latest_build():
    """The newest published staging build, or None. Cached for five minutes,
    so phones checking on every start cost GitHub one call per instance."""
    cached = cache.get(CACHE_KEY)
    if cached is not None:
        return cached or None
    try:
        build = _fetch_latest()
    except (httpx.HTTPError, ValueError) as error:
        raise UpdateUnavailable() from error
    cache.set(CACHE_KEY, build or {}, CACHE_SECONDS)
    return build


def download_url(asset_id):
    """A short-lived, unauthenticated link to the APK on GitHub's storage."""
    repo = settings.APP_UPDATE_REPOSITORY
    try:
        with _client() as client:
            response = client.get(f"{_API}/repos/{repo}/releases/assets/{asset_id}",
                                  headers={"Accept": "application/octet-stream"})
    except httpx.HTTPError as error:
        raise UpdateUnavailable() from error
    location = response.headers.get("location", "")
    if response.status_code not in (301, 302, 303, 307, 308) or not location.startswith("https://"):
        raise UpdateUnavailable()
    return location


def _public(build):
    return {key: value for key, value in build.items() if key != "asset_id"}


class AppUpdateView(APIView):
    """GET: the newest staging build, for the app to compare with its own."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not configured():
            return Response({"available": False})
        try:
            build = latest_build()
        except UpdateUnavailable:
            return Response({"detail": "The update service is unavailable."}, status=503)
        if not build:
            return Response({"available": False})
        return Response({"available": True, **_public(build)})


class AppUpdateDownloadView(APIView):
    """GET: where to download the newest staging APK, for a few minutes."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not configured():
            return Response({"detail": "No update is available."}, status=404)
        try:
            build = latest_build()
            if not build:
                return Response({"detail": "No update is available."}, status=404)
            url = download_url(build["asset_id"])
        except UpdateUnavailable:
            return Response({"detail": "The update service is unavailable."}, status=503)
        return Response({"url": url, "version": build["version"], "version_code": build["version_code"],
                         "sha256": build["sha256"]})
