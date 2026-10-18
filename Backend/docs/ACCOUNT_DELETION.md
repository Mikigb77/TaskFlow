# Account deletion

The owner asked for this on 2026-10-15. Deletion must keep the promises on the website's privacy and delete-account pages (`../TaskFlowWeb/src/content/legal/*.ts`, sections "retention" and "delete-account"):
- the deletion is complete;
- shared content is handled explicitly;
- ownership is never transferred silently;
- deleting an account doesn't cancel a store subscription.

## The owner's rules
- Deleting an account removes the person's own data.
- What they put in a shared project or group stays with the group. The owner's example: a task created in "my maths group" stays visible to the group until it's completed or removed.
- A confirmation email from the no-reply address comes later, as a separate step. It isn't part of this one.

## What happens to each kind of data

Everything runs in one transaction on the server. Stored files are removed only after the commit.

| Data | What happens |
|---|---|
| Account: email, name, password hash, time zone, `billing_id`, Google link (`GoogleIdentity`), sessions (`LoginSession`), free-dictation rows, notifications, project preferences, memberships | Deleted. |
| Personal tasks and notes (no project, or in a personal project being deleted), soft-deleted rows included | Deleted, with their checklists, events and attachments. The attachment files are removed from storage. |
| Personal projects (no members, no group) | Deleted with their tasks. |
| Shared projects the person owns, with no group | Handed to an heir: the earliest editor, otherwise the earliest member. The heir's membership row goes, because owners aren't members. The version is bumped. |
| Projects the person owns inside a group someone else owns | Handed to that group's owner. |
| Groups the person owns | Handed to an heir: the earliest admin, then editor, then viewer, by membership order. If there's no one else, the group and its projects are deleted like personal ones. |
| Tasks the person created in projects owned by others, or in projects being handed over | Kept for the group, and `owner` becomes the project's (new) owner. `created_by` (shown as «Creada por») becomes null in the same update, so the project's owner never appears as the creator; the version is bumped once. Any other task that still names the person as its creator loses it too. Attachments the person added to those tasks stay too, with `owner` moved to the project's owner, which is where storage is charged. |
| Tasks assigned to the person | Kept, and unassigned (`assignee` is set to null; the existing `SET_NULL`). |
| Activity events by the person | Kept for the group with `actor` null. Any name or email of the person in `details` is scrubbed. |
| Pending invitations to the person's email | Deleted, together with their `EmailDelivery` rows. |
| Invitations the person sent | They stay valid for the project or group (`invited_by` is set to null). An unsent invitation email that names them is signed «Someone», «Alguien» or «Algú» instead, in its language. |
| Queued or old emails to the person's address (`EmailDelivery`) | Deleted. |
| RevenueCat customer, and store purchase records | Not touched in this step; to do later with the owner (see below). The store keeps its own legally required records. |

**Showing what will happen before deleting.** `GET /api/auth/delete-account/` returns a preview, and the app shows it before the person confirms. It lists:
- what will be deleted, as counts;
- what stays in shared projects: tasks (`kept_in_shared`) and files (`kept_files_in_shared`), as counts;
- each handover, as the project or group name plus the name of the person receiving it;
- whether the account has Pro, so the app can say that deleting the account doesn't cancel the Google Play subscription. When billing can't be checked, it says Pro: the note is harmless to someone without a subscription;
- a `plan`: a fingerprint of the handovers, as who receives which project or group, by id. Renaming something doesn't change it.

This is what makes the handovers explicit instead of silent.

**Confirming.** `POST /api/auth/delete-account/` re-authenticates the person and checks the plan:
- an account with a password sends `{"password": …, "plan": …}`;
- an account with only Google sign-in sends `{"google_id_token": …, "plan": …}`, from a fresh Google sign-in;
- the password or token is checked first: a wrong password, or a token that's wrong or belongs to someone else, gets 400 with a `code`, whatever the plan;
- without a plan, the answer is 400 `plan_required`;
- if the handovers are no longer the ones the plan describes, for example because an heir left, the answer is 409 `plan_changed` and nothing is deleted. The app shows the new preview;
- otherwise the account is deleted, and the answer is 204;
- it uses the same burst throttle as sign-in.

After a 204, the person's other devices get 401 on their next request.

**On the phone, after a 204:**
- clear the local database, pending captures, cached files and the stored session;
- cancel scheduled reminders;
- show the sign-in screen with "Tu cuenta se ha eliminado.".

If the request fails, nothing changes on the phone. Deleting needs a connection; offline, the app says so.

## Out of scope for this step, to decide with the owner
1. **The confirmation email** from `taskflow.noreply@garbar.tech`: the next step. The address is in memory at deletion time; nothing is kept for it.
2. **Deleting the RevenueCat customer** (`DELETE /v1/subscribers/{billing_id}`). The delete-account page says subscription-provider data is deleted subject to payment, accounting and anti-fraud duties.
3. **A cleanup job for tasks.** The owner described completed tasks being removed after 1 month (free) or 3 months (Pro). That job doesn't exist, and the privacy page currently says the opposite: "Las tareas completadas no se eliminan automáticamente a los 30 o 90 días". The owner has to choose, and the website text must match.
4. **Free-dictation reuse.** Deleting an account and signing up again gives 10 new free dictations. Preventing that means keeping a hash of the email, which must then be disclosed.
5. **The website.** Once the in-app option ships, the delete-account page's line "La versión de pruebas actual todavía no tiene una opción de eliminación dentro de la app" must change (separate repo).

## Implementation
- Module: `core/account_deletion.py` (`deletion_preview`, `delete_account` and the view).
- Endpoint: `GET` and `POST /api/auth/delete-account/`.
- Tests: `core/test_account_deletion.py`; the creator of kept tasks in `core/test_task_creator.py`.
