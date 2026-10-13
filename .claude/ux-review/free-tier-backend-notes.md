The backend half of the free tier is built and all tests pass on SQLite and PostgreSQL. Nothing is committed: HEAD is still `38bb1af` with no stash, and nothing under `App/` was touched. The `api` container is rebuilt, runs the new code, and the migration is applied to the local dev database.

## Files changed (all under `Backend/`)
- **New:**
  - `core/free_tier.py` (the monthly dictation records, the `free_voice` block, the hash of the words, the reserve step)
  - `core/migrations/0018_freedictation.py`
  - `core/test_free_tier.py` (23 tests)
- **Code:**
  - `core/models.py`, `core/billing.py`, `core/views.py`, `core/serializers.py`
  - `core/attachment_views.py`, `core/list_views.py`, `core/group_views.py`
  - `config/settings.py`, `config/test_settings.py`, `config/urls.py`
- **Tests updated:**
  - `test_billing_access.py`, `test_complimentary_access.py`
  - `tests.py`, `test_capture_assignments.py`, `test_notes.py`
  - `test_attachments.py`, `test_attachment_concurrency.py`, `test_groups.py`, `test_sharing.py`
- **Other:**
  - `.env.example`
  - `scripts/validate_projects.py`, `scripts/validate_staging.py`
  - `README.md`, `docs/ARCHITECTURE.md`, `docs/STAGING.md`

**Migration:** `0018_freedictation`

## Test results
| Command | Before | After |
|---|---|---|
| `docker compose exec -T api python manage.py test core --settings=config.test_settings` | 181 OK, 7 skipped | **204 OK, 8 skipped, 0 failed** (the new concurrency test is skipped on SQLite) |
| same with `--settings=config.postgres_test_settings --noinput` | 181 OK | **204 OK, 0 skipped, 0 failed** |
| `makemigrations --check --dry-run` | – | No changes detected |

I also checked that the concurrency test really guards the account lock: with the lock removed (in the container's copy only), it fails 3 out of 3 runs with `[200, 200]`.

## Deviations from the plan
1. **New module.** The dictation logic lives in `core/free_tier.py`, so the user serializer doesn't have to import views.
2. **503 body.** `BillingUnavailable` now always returns `{"code": "billing_unavailable", "detail": "We could not verify TaskFlow Pro. Please try again."}`. The old text said "voice access", which is wrong now that it also guards storage. This adds a field to every existing 503, including `billing/access/`.
3. **`left` counts in-flight dictations as used.** So a 402 always shows `left: 0`.
4. **No `capture_id`, no free retry.** A request without one is never treated as a retry or a duplicate in progress. Read literally, the plan would match empty to empty, so repeating the same words would be free all month.
5. **`free_voice` in every successful response.** That includes Pro (count unchanged) and the legacy `ai/draft/`.
6. **`storage_full` details.** It keeps the old English `detail` text. The 1,000-file limit also returns `storage_full`, as the plan's helper does.
7. **Outage tests.** They live in the updated `test_billing_access.py` rather than being duplicated in the new file.
8. **Not edited: `App/docs/REVENUECAT_SETUP.md` lines 3 and 238**, because `App/` was off-limits. Both still say voice requires Pro; the main session should update them.
9. **Extra stale docs fixed:** README line 126, line 169 and the `auth/me/` row, `STAGING.md` line 136, and `ARCHITECTURE.md` line 94. Also removed the `settings` imports that are now unused in `list_views.py` and `group_views.py`.
10. **Skipped:** the optional cleanup of old months in `maintain_staging`.

**Known gap, not fixed:** if the cancel arrives before its own request has reserved a slot, it deletes nothing and that dictation still counts. That can happen with a slow WAV upload, or a Pro check of up to 6 s when the billing cache is empty. A fix would be a short-lived "cancelled" marker per account and `capture_id`, checked against when the request started.

## For the app half, as built
**Account blocks** (on `auth/me/` and the `user` object of login, register and Google):
- `free_voice: {limit: int, left: int, resets_at: "YYYY-MM-01T00:00:00Z"}`
- `storage: {used_bytes: int, limit_bytes: int}`, where `limit_bytes` is the free cap.

**Dictation request:** send an optional `capture_id` (UUID) as a JSON or multipart field. `source` is still ignored.

**Responses from `POST ai/drafts/`:**

| Case | HTTP | Body |
|---|---|---|
| Success | 200 | drafts + `free_voice` |
| Free dictations used up | 402 | `code: free_voice_used_up`, `detail`, `free_voice` |
| Same dictation already in flight | 409 | `code: capture_in_progress`, `detail` |
| Cancelled before the AI finished | 409 | `code: capture_cancelled`, `detail`, no `tasks` |
| Pro unknown and no dictations left | 503 | `code: billing_unavailable`, `detail` |

**Cancel:** `DELETE ai/drafts/<uuid>/` always returns 204, needs sign-in, and uses the `tasks` throttle.

**Uploads:**
- A full space returns 400 with `{code: "storage_full", shared: bool, detail}`. The `storage` block is included only when `shared` is false.
- An unknown Pro status above the free cap returns the 503 above.
- The three move paths keep their existing 400 messages.

**Retries:** the same `capture_id` with the same capture type and the same words (or identical WAV bytes), in the same UTC month, is free even with none left. New words count again. Daily-budget 429s don't count.

**One trap:** the current app's `requestProblem` reads any 400 whose body has a `code` as a recovery-code error. Don't send `storage_full` through it. Today's sync only stores `detail`, so the current app is unaffected.
