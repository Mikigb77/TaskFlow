# TaskFlow free tier: implementation plan

All paths below are relative to `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\`. Backend line numbers are from `dev` at 38bb1af.

App line numbers come from the working tree, which already holds uncommitted P38 work:
- a new `App/lib/services/local_capture.dart`;
- edits to `voice_task_screen.dart`, `subscription_provider.dart` and `capture_processor.dart`.

They will drift, so the app part below describes responsibilities.

## 1. Current state

**How Pro is decided (server)**
- `subscription_access()` (`Backend/core/billing.py:90-118`) is the single source of truth.
  - It checks complimentary grants first, without caching (`:93-94`). The rule (`:84-87`) needs the email on the allowlist, plus either an allowlisted billing ID or a linked Google identity.
  - Otherwise it asks RevenueCat for the account's opaque `billing_id` (`models.py:46-47`), with a fixed host and a 6 s timeout (`billing.py:28-46`).
  - It reads `taskflow_pro` from subscriptions or lifetime purchases (`:58-81`). Refunds revoke access, grace periods count, and sandbox purchases count only in development or staging (`:95-97`).
  - Results are cached 30 s when active and 5 s when not, never past the expiry date (`:111-117`).
  - `POST /api/billing/access/` forces a refresh (`:126-133`). The app sends it whenever hasPro turns on (`App/lib/main.dart:263-277`).
- The gate is `require_pro()`, which returns 402 `pro_required` (`billing.py:22-25, :121-123`). Only the AI views use it (`views.py:94`). If the store can't be reached, the answer is 503 `billing_unavailable` (`:16-19`).
- Existing tests:
  - `test_billing_access.py`: forged fields, grace, refunds, sandbox, test keys, malformed data, cache expiry, outage;
  - `test_billing_identity.py`;
  - `test_complimentary_access.py`.

**How AI capture is gated and limited today**
- `DraftView` and `DraftBatchView` (`views.py:83-114`) run in this order:
  1. validate the request (`:90-92`);
  2. load the project context (`:93`);
  3. `require_pro` (`:94`);
  4. a per-account daily budget, `ai:{UTC day}:user:{pk}`, against `AI_REQUESTS_PER_DAY` (`:95-97`; `settings.py:138`; default 50);
  5. a global budget of 200 a day, hard-coded (`:98-102`);
  6. the AI call (`:105`).
- A failed AI call gives the account budget back, but not the global one (`:106-110`). There is also a burst throttle, `ai` at 6/min (`settings.py:55`).
- The counters are cache entries (`views.py:66-80`). That's Redis locally, and `RuntimeState` rows when `STATE_BACKEND=postgres` (`runtime_state.py:14-59`).
- There is no database log of AI calls. `TaskEvent` (`models.py:198-204`) only logs task changes. `docs/ARCHITECTURE.md:50` already says a generic database cache "is not an atomic quota ledger".
- `make_draft` turns every failure into `AIUnavailable` with 400, 422, 429, 502 or 503 (`ai.py:370-403`). One request is one AI call, producing 1 to 12 tasks (`ai.py:66-67`).
- `DraftRequestSerializer` (`serializers.py:281-292`) ignores the app's `source` field.
- About the named settings:
  - `AI_GUEST_REQUESTS_PER_DAY` appears only in `.env.example:27`; nothing reads it.
  - `AI_FREE_ATTEMPT_SECONDS` (`settings.py:128`, `ai_routing.py:88-91`) is the timeout for Google's free AI Studio route before the paid fallback. It has nothing to do with a free tier.

**How attachments are uploaded and stored**
- Upload is `PUT /api/attachments/<uuid>/` (`attachment_views.py:127-182`).
- The size is known while the upload is parsed (`BoundedUploadHandler :24-37`, `settings.py:97-100`) and is limited to 6 MiB (`:64-67`).
- Under row locks (`:141-147`), the quota owner is the list's owner, or the task's owner when there is no list (`:146`; `quota_files :89-94`).
- Today's cap is `ATTACHMENT_ACCOUNT_BYTES`, 64 MiB for everyone (`settings.py:103`), plus 1,000 files (`:163-166`) and 20 per task (`:167-168`). A full account gets a plain 400 with no stable code.
- The same cap is checked in three other places: moving a task between lists (`:97-106`, called from `task_views.py:43`), moving a project into a group (`list_views.py:92-98`), and transferring a group (`group_views.py:222-229`).
- Deleting frees space immediately. The quota counts only live files on live tasks (`:89-94`). Deleting a file (`:197-208`) or a task (`:79-86`) marks rows deleted inside the transaction, and the stored file is removed after commit on a best-effort basis (`:70-76`).

**App**
- `hasPro` is the RevenueCat SDK entitlement or the server's `complimentary_pro` flag. While billing is still loading, it reads as "not Pro" (`subscription_provider.dart:87-93`). P38 adds `billingLoadingProvider` (`:54-56, :104`).
- The Pro decision happens in `VoiceTaskScreen.build` (`voice_task_screen.dart:239-247`). P38 passes `voice: pro` and fixes it when the sheet opens (`_voice`, `:323`).
- That same flag decides whether words are understood on the phone or by the server (`local: !_voice`, `:986-988`; `capture_processor.dart:23-36, :62-97`).
- `CaptureProcessor` posts to `ai/drafts/` (`:105-123`).
  - Only the sheet calls it, and it de-duplicates concurrent calls (`:32`).
  - On failure it keeps the capture with a stable error code (`:182-186`).
- `ApiClient.request` turns any status of 400 or above into `ApiException(status, detail, body)` (`api_client.dart:277-293`). The AI timeout is 100 s (`:335`), and no network gives status 0.
- `CaptureProblem.from` maps 402 to `pro_required`, 429 to `allowance` and 5xx to `unavailable` (`capture_problem.dart:62-76`).
- `Account` (`api_client.dart:18-32`) comes from `/auth/me/` and is saved with the session.
  - It refreshes at start (`auth_provider.dart:61-79`).
  - It refreshes on every resume (`main.dart:121` → `subscription_provider.dart:235-240`).
- Attachment errors:
  - `AttachmentStore.sync` runs on every task sync (`attachment_store.dart:180-248`; triggered via `task_provider.dart:33-47` → `cloud_task_repository.dart:235`).
  - A refused upload stays queued and is re-sent on every sync.
  - Its error is saved as the server's English text (`:174-178`) and translated later by matching substrings (`request_locale.dart:62-105`). "Storage is full" matches nothing today, so the panel shows a generic error (`attachment_panel.dart:217-227`).

## 2. Backend changes

### 2.1 Model and migration
Nothing existing can be reused. The daily counters live in a cache that can be flushed, and there is no AI log. Add one table in migration `0018_freedictation`:

```python
class FreeDictation(models.Model):
    # One AI dictation by an account without Pro. Pro dictations are not recorded.
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="free_dictations")
    period = models.CharField(max_length=7)      # "2026-10", UTC calendar month
    capture_id = models.UUIDField(null=True)      # the app's capture UUID, so it can be cancelled
    digest = models.CharField(max_length=64)      # sha256(capture_type + text or WAV bytes)
    counted = models.BooleanField(default=False)  # False while the AI is still working
    created_at = models.DateTimeField()           # set from the same clock as period
    class Meta:
        indexes = [models.Index(fields=["user", "period"], name="free_dictation_month")]
```

A free account adds at most about 10 rows a month. Pruning old months is optional; it would be one line in `maintain_staging`.

### 2.2 How a month is defined
I recommend the **calendar month in UTC**:
- `period = now.strftime("%Y-%m")`;
- `resets_at` = 00:00 UTC on the first day of the next month.

Reasons:
- `User.timezone` is only written at sign-up (`serializers.py:35`, `google_auth.py:29, :76`). No endpoint updates it (`MeView` only answers GET, `auth_views.py:107-109`), so it can be stale.
- The time zone sent with each request is chosen by the client, and `/auth/me/` doesn't have one.
- The daily budget already uses UTC days (`views.py:95`).
- In Madrid the reset happens at 01:00 or 02:00 on the 1st. The app shows `resets_at` as a local date.

### 2.3 Where the check runs, atomically
The check goes in `DraftView.post`, exactly where `require_pro` is today. That is after validation and the project context, so a 400 never spends a dictation, and before the budgets.

1. **Decide Pro with `has_pro(user)`.** It replaces `require_pro` and `ProRequired` in `billing.py` and returns True, False or None:
   - with an empty `REVENUECAT_API_KEY` it returns `complimentary_pro(user)`, since billing isn't configured and only grants can be Pro;
   - otherwise it returns `subscription_access(...)["active"]`;
   - if that raises `BillingUnavailable`, it returns None.
2. **Reserve a dictation** (not Pro only) with `reserve_free_dictation()`, all in one `transaction.atomic()`:
   - Lock the account row with `User.objects.select_for_update()`, the same pattern as `attachment_views.py:147`.
   - Delete this account's pending rows that are more than 5 minutes old. These come from crashed requests; each AI stage has 45 s (`ai_routing.py:68`) and gunicorn times out at 120 s.
   - If a row with the same `capture_id` and digest exists this month:
     - and it's counted, charge nothing — this is a retry after a lost response, and it works even at 0 left;
     - and it's pending, return 409 `capture_in_progress`.
   - If counted plus pending rows reach the limit, return 402 `free_voice_used_up`. If Pro couldn't be checked (`pro is None`), return 503 `billing_unavailable` instead, so a paying customer is never told they've run out.
   - Insert a pending row. `ATOMIC_REQUESTS` is off (`settings.py:32`), so this commits before the AI call; keep it off.
   - The digest hashes the text or the WAV in chunks, then rewinds (`seek(0)`), as in `attachment_views.py:134-138`. Reusing a `capture_id` with different words therefore counts as a new dictation.
3. **Run the budgets and the AI as today.** If anything fails — `AIUnavailable`, `Throttled` or any other exception — delete the pending row so it doesn't count.
4. **On success,** run `filter(pk=row.pk, counted=False).update(counted=True)`.
   - If it updated 1 row, return the result plus the `free_voice` block.
   - If it updated 0 rows, the dictation was cancelled meanwhile: return 409 `capture_cancelled` and discard the result.
5. **Cancel.** Add a small `DELETE /api/ai/drafts/<uuid:capture_id>/` view (throttle scope `tasks`).
   - It deletes only the caller's *pending* rows for that capture, returns 204, and can be repeated safely.
   - A cancelled dictation never returns its result, so cancelling can't be used to get free AI.
   - This is needed because P40's "Guardar tal cual", offered after 8 s, makes cancelling after sending a normal path. If the owner accepts that such a dictation counts, drop this view; nothing else depends on it.

### 2.4 Storage
Add one helper in `attachment_views.py` and use it at the four places that compare against `ATTACHMENT_ACCOUNT_BYTES` (`:105`, `:165`, `list_views.py:97`, `group_views.py:228`):

```python
def storage_allows(owner_id, total_bytes, file_count):
    if file_count > 1000: return False                        # technical bound, every tier
    if total_bytes <= settings.FREE_ATTACHMENT_BYTES: return True
    pro = has_pro(User.objects.get(pk=owner_id))              # asked only above the free cap
    if pro is None: raise BillingUnavailable()                # 503; the app retries later
    return pro
```

- The cap follows the quota owner:
  - a free member uploading into a Pro owner's project has no cap;
  - a Pro member uploading into a free owner's full project is refused.
- For uploads, raise a small `StorageFull` inside the atomic block and turn it into a structured 400 outside it.
- The three move paths keep their existing messages.
- Downloads and deletes never check the cap. That follows `docs/ARCHITECTURE.md:75, :90`: when Pro ends, files stay readable and removable, and only new uploads above the cap are refused.

### 2.5 Response shape
`/api/auth/me/` gets two new blocks. So does the `user` object in login, register and Google responses, since they all use `UserSerializer`. That costs two cheap queries and no RevenueCat call:

```json
"free_voice": {"limit": 10, "left": 7, "resets_at": "2026-11-01T00:00:00Z"},
"storage": {"used_bytes": 12582912, "limit_bytes": 104857600}
```

`limit_bytes` is the cap without Pro. The app knows whether the user has Pro, so it shows storage only to free users. A successful `ai/drafts/` response adds the same `free_voice` block, counted after this dictation.

### 2.6 Error codes

| Case | HTTP | `code` | Extra fields |
|---|---|---|---|
| Free voice used up | 402 | `free_voice_used_up` | `free_voice` |
| Pro can't be checked and the free limit is reached (voice or storage) | 503 | `billing_unavailable` (existing) | none |
| Same dictation already in flight | 409 | `capture_in_progress` | none |
| Cancelled before the AI finished | 409 | `capture_cancelled` | none (result discarded) |
| Storage full | 400 | `storage_full` | `shared`; `storage` only when it's the user's own storage |

- Build these bodies with `Response(...)` in the view. If you raise an `APIException` with a dict as its detail, DRF turns the numbers into strings.
- 402 `pro_required` goes away. Older app builds still show the Pro message for any 402 (`capture_problem.dart:70`).

### 2.7 Settings and defaults
- Add `FREE_VOICE_CAPTURES_PER_MONTH`, default 10.
- Replace `ATTACHMENT_ACCOUNT_BYTES` (`settings.py:103`) with `FREE_ATTACHMENT_BYTES = int(os.getenv("FREE_ATTACHMENT_MB", "100")) * 1024 * 1024`. It's in MiB like the 6 MiB file limit; the app says "MB".
- `.env.example`: add both names and remove the dead `AI_GUEST_REQUESTS_PER_DAY`.
- `config/test_settings.py`: set `REVENUECAT_API_KEY = ""` so no test can reach RevenueCat through the new storage check.
- Optional: turn the hard-coded global 200 a day (`views.py:99`) into `AI_GLOBAL_REQUESTS_PER_DAY`.
- Unchanged: `ATTACHMENT_MAX_BYTES`, `AI_REQUESTS_PER_DAY`, the throttles and `AI_FREE_ATTEMPT_SECONDS`.

### 2.8 Django tests to add (`core/test_free_tier.py`)

**Voice**
- **Limit:** 10 dictations succeed. The 11th returns 402 with `left` 0 and `resets_at`, and neither the AI nor the budgets are touched.
- **Batches:** a batch of 5 tasks counts once. `/ai/draft/` counts the same way.
- **Failures:** an `AIUnavailable` (400, 422, 502 or 503) and the 429 budget limits don't count. The next success counts once.
- **Retries:**
  - a retry with the same `capture_id` and digest after success charges nothing, even at 0 left;
  - the same `capture_id` with new words is charged.
- **In flight:**
  - a duplicate while pending returns 409 and the AI isn't called;
  - a pending row holds a slot, but one older than 5 minutes doesn't.
- **Cancel:**
  - cancelling while the AI runs (the mock calls DELETE) returns 409 `capture_cancelled` and nothing is counted;
  - cancelling after success refunds nothing;
  - a user can't cancel another account's rows.
- **Months:**
  - with the clock at 2026-10-31T23:59:59Z and then 2026-11-01T00:00Z, the count resets;
  - December's `resets_at` is 2027-01-01T00:00:00Z.
- **Pro accounts:**
  - Pro (mocked `_customer`) and complimentary accounts are unlimited and create no rows;
  - complimentary accounts never call RevenueCat.
- **Outage:**
  - with dictations left, the request succeeds and is charged;
  - with none left, it returns 503 without leaking provider details.
- **Forged fields:** `has_pro`, `free_voice`, `billing_id` and `source: "typed"` change nothing; typed text from a free account still counts.
- **Notes:** a WAV note counts once.
- **Account payload:** `/auth/me/`, login and register include both blocks.
- **Concurrency:** PostgreSQL only, with `@skipUnlessDBFeature("has_select_for_update")`, like `test_attachment_concurrency.py`. With one dictation left, two simultaneous requests return [200, 402] and leave one counted row.

**Storage**
- A free owner over the cap gets `storage_full` with the `storage` block.
- A Pro owner gets 201, and RevenueCat is only asked above the cap.
- Shared projects:
  - a full free owner gives `shared: true` and no numbers;
  - a Pro owner accepts a free member's upload.
- Deleting a file or a task frees space immediately.
- After Pro expires, downloads return 200, deletes return 204, and uploads over the cap are refused.
- Moving into a Pro owner's space is allowed.
- Unknown billing above the cap returns 503.

**Existing tests to update**
- `test_billing_access.py:28-40`: use up the allowance first, then expect 402.
- `test_billing_access.py:119-125`: the outage cases above.
- `test_complimentary_access.py:60-72`: a forged grant spends a free dictation instead of getting Pro.
- `tests.py:309, :319`, `test_capture_assignments.py:144` and `test_notes.py:82`: patch `core.views.has_pro` instead of `require_pro`.
- The setting rename at `test_attachments.py:86`, `test_attachment_concurrency.py:22`, `test_groups.py:202` and `test_sharing.py:159`.

**Scripts and docs**
- The staging scripts expect 402 for a free account (`scripts/validate_projects.py:78`, `scripts/validate_staging.py:86`). Change them to check `/auth/me/` `free_voice` and leave the 402 case to the Django tests.
- Update the docs: `README.md:7, :228`, `docs/ARCHITECTURE.md:79-90, :109` and `App/docs/REVENUECAT_SETUP.md:3, :238`.

## 3. App changes (responsibilities)
Build on P38–P40 once they're committed. P38 already gives the seam: the sheet's single `voice` flag.

**Where to read the counts**
- `Account` parses `free_voice` and `storage`. Both are nullable, for sessions saved before this change.
- They're saved with the session, so they work offline.
- They refresh:
  - at start;
  - on resume;
  - after every dictation — the 200 or 402 body carries the block, so write it straight into the account cache.
- One derived provider, `voiceAvailable`:
  - Pro or complimentary means true;
  - otherwise it's `left > 0`, and once `now ≥ resets_at` it treats `left` as the full limit;
  - if the server sent no block (an old server), it falls back to hasPro.
- The decision never waits on the network.

**When the sheet decides voice or typing**

Split P38's single flag in two:
- the mic follows `voiceAvailable`;
- typed words go to the assistant only with Pro: `local: !pro && source != 'speech'`. A free account's spoken words go to the server and count; typed words never do.

Decide at four moments:
- when the sheet opens;
- on "Volver a decirlo", which starts a new dictation;
- on widget and voice-shortcut entries (P39);
- for the Añadir tarea icon, mic or + (P38).

Details:
- P38's billing spinner is only needed when the account has no Pro, 0 dictations left and billing is still loading.
- "Seguir" continues an unsent dictation, so it stays allowed.
- At 0 left, open in typing with the used-up line (it replaces P39's "voice is Pro" line) and "Ver Pro", and never create a recorder.

**Handling "free voice used up" without losing words**
- Map 402 plus the code to a new `CaptureProblem.freeVoiceUsedUp`. Keep `pro_required` as a legacy value with the same text.
- The capture is already kept with its words, because the processor stores failures.
- After a 402, the sheet switches to typing with the phone's own transcript in the field, the used-up line, and P40's "Guardar tal cual" (local parser). No second request is made.
- A capture that is only a WAV recording can't be saved as written (P40). It stays in "Sin guardar" with the reset date, which is why blocking the recording before it starts is the real safeguard.
- A spoken capture reopened at 0 left opens the same way.
- Send `capture_id` (the session's UUID) with every AI request.
- Send the cancel (DELETE) without waiting, and ignore the 409 that follows, in two cases:
  - "Guardar tal cual" while the request is in flight;
  - Cancel dropping words that were said again while they're being understood.
- Closing the sheet while it's understanding keeps the result in "Sin guardar", so that dictation counts.

**Attachment usage near the cap**
- When the body says `storage_full`, save a stable token instead of the English text.
- Background sync must not re-send that file; today it would re-upload up to 6 MiB on every task change. Re-send it only when:
  - the person taps its Retry;
  - the person removes a file;
  - hasPro turns on.
- In the attachment panel, for accounts without Pro:
  - show one usage line once storage is at 80% or more;
  - show the own or shared message on a refused file, with "Ver Pro" only when it's the user's own storage.
- Refresh the account after a removal.
- Optionally, after P44, show both lines on the Pro screen.
- No new screens or settings.

**Strings (draft; the UX loop will polish them)**
1. `freeVoiceLeft`, shown on the result only when 3 or fewer are left:
   - EN: `{count, plural, =1{1 free dictation left this month} other{{count} free dictations left this month}}`
   - ES: `{count, plural, =1{Te queda 1 dictado gratis este mes} other{Te quedan {count} dictados gratis este mes}}`
   - CA: `{count, plural, =1{Et queda 1 dictat gratuït aquest mes} other{Et queden {count} dictats gratuïts aquest mes}}`
2. `freeVoiceUsedUp`, with `{date}` as the local short date:
   - EN: `You've used this month's free dictations. You can type it here — more on {date}.`
   - ES: `Ya has usado los dictados gratis de este mes. Puedes escribirla aquí; tendrás más el {date}.`
   - CA: `Ja has fet servir els dictats gratuïts d’aquest mes. La pots escriure aquí; en tindràs més el {date}.`
3. `freeVoiceUsedUpRecording`:
   - EN: `Your recording is kept. It can be understood from {date}, or now with Pro.`
   - ES: `Tu grabación se conserva. Se podrá entender a partir del {date}, o ahora con Pro.`
   - CA: `La gravació es conserva. Es podrà entendre a partir del {date}, o ara amb Pro.`
4. `storageUsage`:
   - EN: `Files: {used} of {limit} MB used`
   - ES: `Archivos: {used} de {limit} MB usados`
   - CA: `Fitxers: {used} de {limit} MB utilitzats`
5. `storageFull`:
   - EN: `Your file space is full ({limit} MB). Remove a file to make room, or get Pro for unlimited space.`
   - ES: `Tu espacio para archivos está lleno ({limit} MB). Elimina un archivo para hacer sitio o hazte Pro para tener espacio ilimitado.`
   - CA: `El teu espai per a fitxers és ple ({limit} MB). Treu un fitxer per fer lloc o fes-te Pro per tenir espai il·limitat.`
6. `storageFullShared`:
   - EN: `This project's file space is full. Its owner can remove files to make room.`
   - ES: `El espacio para archivos de este proyecto está lleno. Su propietario puede eliminar archivos para hacer sitio.`
   - CA: `L’espai per a fitxers d’aquest projecte és ple. El seu propietari pot treure fitxers per fer lloc.`
7. Change `billingTestMode` from "unlocks voice and AI capture" to "unlimited dictation and file space", in all three languages.
8. Reuse `voiceProAction` (Explore Pro / Ver Pro / Descobreix Pro).
9. Remove:
   - `voiceAccessUnavailable` (no Dart code uses it today);
   - `voiceProRequired`, once P39 lands;
   - P39's Pro line.

The copy says "dictations", never "tasks" (`DECISIONS.md:19`).

## 4. Edge cases
- **Offline:**
  - typing is understood on the phone and never counts;
  - spoken words fail before reaching the server (status 0), so they don't count; the words are kept and "Guardar tal cual" works;
  - the decision uses the cached count, which rolls over locally at `resets_at`;
  - if the cache is stale, the 402 path takes over.
- **Pro bought mid-month:**
  - the existing `POST billing/access/` clears the server's 5 s negative cache, so voice is unlimited from the next request;
  - unused free dictations stay in reserve for the rest of the month;
  - refused uploads are re-sent.
- **Pro expires mid-month:**
  - a cached grant never outlives its expiry (`billing.py:114-115`);
  - Pro-period dictations weren't recorded, so the user has whatever remains of their 10;
  - files are never deleted; uploads are refused while over 100 MB;
  - the "communicated grace period" in `ARCHITECTURE.md:90` is the owner's call.
- **Restoring purchases:** works like a purchase. The counter belongs to the TaskFlow account, not the device or store account, so reinstalling, restoring or using a second device can't reset it, and devices share the count.
- **Counter reset:** no job runs; the new month's key simply starts at zero.
- **A dictation whose AI step fails:** the pending row is deleted. A crash stops counting after 5 minutes.
- **A cancelled dictation:**
  - cancelled before sending, no request is made;
  - cancelled while being understood, the DELETE removes it;
  - it counts only if the AI had already finished, in which case the result exists.
- **A batch result:** one row per request, whatever the number of tasks.
- **Notes:**
  - a WAV note counts once;
  - notes typed or transcribed on the phone stay local (`capture_processor.dart:62-97`) and never count.
- **Complimentary accounts:**
  - they are Pro on both sides without RevenueCat;
  - removing them from the allowlist makes them free immediately.
- **Shared projects:**
  - storage is charged to the project's owner;
  - a Pro uploader doesn't lift a free owner's cap, and the message doesn't suggest Pro in that case.
- **Billing outage:** free use still works; at the limit the answer is 503 ("try again"), never "used up" or "full".

## 5. Order of work, risks and verification

**Order**
0. **Main session, before the next `/ux`:**
   - Record in `DECISIONS.md` that the free tier replaces D4a's "voice and AI stay Pro". Voice now means Pro *or* a free dictation left; the assistant for typed words stays Pro. Otherwise the UX reviewer will flag the mic for free users as a regression.
   - If P39 isn't verified yet, tell the loop its Pro line will become the used-up line.
1. **Backend** can start now, and it's safe to finish first: today's app keeps non-Pro users off voice, and the storage cap only goes up. Steps:
   1. settings and `test_settings`;
   2. model and migration;
   3. the `billing.py` helpers;
   4. views, serializer, URLs;
   5. the storage helper at the four call sites;
   6. tests on SQLite and PostgreSQL;
   7. docs and scripts.
2. **App,** after P38–P40 are committed:
   1. `Account` and the provider;
   2. the four decision points;
   3. the 402 handling, `capture_id` and cancel;
   4. attachments;
   5. strings;
   6. tests;
   7. `/ux` on the capture sheet and the attachment panel.
3. **Device checks.** No deploy unless the owner asks.

**Risks**
- `App/lib` is being edited right now (P38 is uncommitted). Wait for those commits before starting the app part.
- Uploads above the free cap may hold row locks during a RevenueCat call. This is rare, and the 30 s cache helps. If it matters, check Pro before the transaction.
- The global cap of 200 AI calls a day (`views.py:99`) will be hit sooner once free accounts can dictate.
- "Pro has no limits" collides with existing safeguards: 50 AI calls a day, 6/min, 6 MiB per file, 20 per task and 1,000 files. The owner should decide; until then, avoid promising "unlimited" in the copy.
- An empty `REVENUECAT_API_KEY` in production would now quietly mean "nobody is Pro except grants" (today it gives 503).
- The paywall's benefit text lives in the RevenueCat dashboard and needs updating there.
- Re-sending refused uploads already wastes data at today's 64 MB cap, until the app's sync fix lands.

**Verification**
- **Backend:** run both
  - `docker compose exec -T api python manage.py test core --settings=config.test_settings`
  - the same command with `--settings=config.postgres_test_settings` (the concurrency tests only run there).
- **App:** `flutter gen-l10n`, `flutter analyze --no-pub`, then `flutter test --no-pub`, adding these widget tests:
  - account parsing;
  - a truth table for `voiceAvailable`;
  - at 0 left: typing, no recorder, no `ai/drafts` request;
  - with 2 left: exactly one request, carrying `capture_id`;
  - free typing never makes a request;
  - a 402 keeps the words and offers "Guardar tal cual";
  - "Guardar tal cual" while waiting sends DELETE and ignores the late 409;
  - "Volver a decirlo" at 0 left opens typing;
  - Pro with 0 free left still gets the mic;
  - a refused file isn't re-sent by sync, and Retry, removing a file or Pro allows one new upload;
  - the panel's 80% line, and own vs shared message;
  - localization tests show no English in ES or CA.
- **Manual,** stating emulator or physical phone, with the local server using `FREE_VOICE_CAPTURES_PER_MONTH=2` and `FREE_ATTACHMENT_MB=1` set as environment variables:
  1. **Voice limit:** dictate twice. The third sheet opens in typing with the date shown, Añadir tarea shows +, and a typed task saves with its date without spending a dictation.
  2. **Server says used up:** lower the server limit after the app has cached its count. The next dictation gets a 402, keeps its words and saves with "Guardar tal cual".
  3. **Offline and slow AI:** in airplane mode, and with "Guardar tal cual" after 8 s, the count on `/auth/me/` doesn't change.
  4. **Pro and complimentary:** a Test Store purchase mid-month unlocks voice and uploads over the cap; restore on a second device; a complimentary account shows no counts.
  5. **Attachments:**
     - the usage line appears near 1 MB;
     - going over shows the own message;
     - removing a file lets Retry succeed;
     - a free owner's shared project shows the shared message;
     - the server log shows no repeated uploads.
  6. **Languages and TalkBack:** ES and CA at 2× text in light and dark; TalkBack reads the used-up line.
  7. **Paywall:** the RevenueCat paywall text is updated.

### Critical Files for Implementation
- C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\Backend\core\views.py
- C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\Backend\core\billing.py
- C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\Backend\core\attachment_views.py
- C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\Backend\core\models.py
- C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\App\lib\screens\voice_task_screen.dart (with `App\lib\services\capture_processor.dart`, `App\lib\services\capture_problem.dart` and `App\lib\services\attachment_store.dart`)
