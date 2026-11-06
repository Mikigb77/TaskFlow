# Meeting notes

The contract between the server and the app for notes made from a recorded conversation. Requirements and the owner's decisions: `App/docs/MEETING_NOTES.md` (MN-1 to MN-34). Build plan: `App/docs/MEETING_NOTES_PLAN.md`.

- **The app** records, cuts the recording into numbered pieces of about 5 minutes, keeps each piece on the phone until the server confirms it, and saves the final result as an ordinary note.
- **The server** transcribes each piece, writes chapter notes for each half hour, and writes the final notes once every piece is in. It never stores audio, and deletes the meeting once the app confirms it saved the note.
- **Every call is safe to repeat.** No call starts background work; the request that completes a step does it.

## Access

Every endpoint needs the normal login token and **TaskFlow Pro**, except `DELETE`, which needs only the login and the meeting being the person's own: a discard or an acknowledgement always deletes at once, also after Pro lapsed or while RevenueCat is unreachable (MN-24, MN-25).

| Case | Answer |
|---|---|
| Not Pro | `402` `{"code": "pro_required"}` (not on `DELETE`) |
| RevenueCat unreachable | `503`, as the existing `BillingUnavailable` (never tell a paying customer they're not Pro); not on `DELETE` |
| Monthly allowance used (`AI_MEETING_PIECES_PER_MONTH`, default 240 pieces, about 20 hours) | `402` `{"code": "meeting_allowance_used"}` on a new piece; pieces already saved still answer `200` |
| Vertex AI not configured | `503` `{"detail": …}` (`AIUnavailable`) |
| Meeting owned by someone else | `404` |

## Endpoints

### `PUT /api/meetings/<uuid:meeting_id>/pieces/<int:index>/`

Multipart form:

| Field | Type | Meaning |
|---|---|---|
| `audio` | file, required | One piece. `audio/ogg`, `audio/opus`, `audio/aac`, `audio/mp4`, `audio/m4a`, `audio/wav` or `audio/webm`; at most 8 MB. |
| `offset_seconds` | number, required | Where the piece starts, in seconds from the start of the meeting. |
| `duration_seconds` | number, required | The piece's length in seconds, at most 600. |
| `language` | string, optional | BCP-47 hint from the app's voice settings; the model detects the language anyway. |

- The first piece received creates the meeting for this user, with the id the phone made. If that first piece's `index` is above 0 (the start expired on the server, MN-28), the meeting is marked `start_missing`.
- A piece already saved answers `200` again without transcribing it again or counting it again.
- A piece for a meeting whose final notes exist answers `200` if it's already saved, else `409` `{"code": "meeting_finished"}`.
- The server transcribes the piece with `AI_MEETING_AUDIO_MODEL` on Vertex, giving the last sentence of the piece before as context, saves the text and drops the audio. A silent piece saves empty text.
- If the piece completes a half hour (chapter `k` = pieces `6k` to `6k+5`, all saved) and that chapter has no notes yet, the same request writes them. Chapters are six pieces, not six times five minutes: the app drops silent pieces and gives their number to the next piece, so a chapter can span more than 30 minutes of the meeting. Its times come from the pieces' offsets, so they stay true.
- If the meeting is finished and this piece completes the set, the same request writes the final notes.

`200` `{"meeting_id": "…", "index": 3, "saved": true, "status": "recording" | "waiting" | "ready"}`

### `POST /api/meetings/<uuid:meeting_id>/finish/`

JSON `{"last_index": 49}`: the last piece's number. Repeating it is safe; a different `last_index` after the first one is ignored.

- Every piece from the first one (0, or the first received when `start_missing`) to `last_index` saved: the server writes any missing chapter notes and the final notes (once), and answers `200` `{"status": "ready", "result": {…}}`.
- Pieces missing: `202` `{"status": "waiting", "missing": [7, 8]}`. The final notes are then written by the piece that completes the set; the app repeats `finish` (or `GET`) until `ready`.
- `202` `waiting` with an empty `missing` list: every piece is in and the notes are being written; repeat.
- No meeting yet (no piece ever arrived): `202` `{"status": "waiting", "missing": [0, …, last_index]}`; nothing is stored.
- The server never leaves out a piece it has saved: the set ends at the higher of `last_index` and the highest piece saved.

### `GET /api/meetings/<uuid:meeting_id>/`

`200` with the same body as `finish` (`recording` when the app hasn't finished it, with `"received": [0, 1, 2]`), or `404` when there's no such meeting.

### `DELETE /api/meetings/<uuid:meeting_id>/`

Discard, or the app's acknowledgement after saving the note. Deletes the meeting, its pieces' text and its chapter notes. `204`, also when nothing exists. Needs no Pro (see Access).

After a `DELETE`, a piece for that meeting id answers `404` for about a day (a piece still in flight never brings the meeting back).

## The result

```json
{
  "title": "Pilot pricing with Acme",
  "summary": "Three to five sentences.",
  "tasks": [{"title": "Send the pilot quote", "who": "Miki", "when": "Friday", "steps": ["Price for 20 seats", "Start date"], "sure": true},
            {"title": "Book the room", "who": null, "when": null, "steps": []}],
  "todos": [{"text": "Send the pilot quote", "who": "Miki", "when": "Friday"}, {"text": "Book the room", "who": null, "when": null}],
  "decisions": ["Start the pilot in December"],
  "open_questions": ["Who signs for Acme?"],
  "chapters": [{"start_minute": 0, "end_minute": 30, "title": "Introductions and scope", "notes": "Short notes."}],
  "start_missing": false,
  "language": "en"
}
```

- Written in the language mostly spoken in the meeting (`language`, BCP-47 primary tag).
- `tasks`: one entry per separate task said in the meeting. `steps` are the parts of that same task that were said (`[]` when none); something with its own goal is its own task, even when said right after another one or on the same day (owner, 2026-11-05). `sure` is `true` when it was said as something to do, `false` when it was only floated; the app's «Tareas sugeridas» ticks only the sure ones (owner, 2026-11-06). A result written before this field existed has none, which the app reads as `true`.
- `who` and `when` are `null` unless they were said. `when` is the words as said; the app reads the day from them against the meeting's date.
- `todos` is `tasks` without the steps, one line per task, for an app from before tasks had steps. A new app reads `tasks`.
- The transcript comes from speech recognition, so the notes steps are told to write the word that was meant where the context makes a misheard one clear ("paga general" where "vaga general" was meant), and never to change a name, figure, date or time on a guess. The transcript itself isn't corrected or returned.
- Empty lists are `[]`, never missing. A meeting with no speech answers a result with an empty summary and empty lists.

## Models and cost

- `AI_MEETING_AUDIO_MODEL` (pieces) and `AI_MEETING_TEXT_MODEL` (chapter and final notes), both default `gemini-3.5-flash-lite`, on Vertex (`AI_VERTEX_PROJECT`, `AI_VERTEX_LOCATION`), like all AI. The fallback for pieces is `gemini-3.5-transcribe`; changing the setting is enough.
- Meetings don't use the daily dictation budget (`AI_REQUESTS_PER_DAY`) or free dictations; the monthly allowance above bounds them.
- About US$0.08 for an hour of meeting with Flash-Lite, US$0.32 with Transcribe for the pieces (`App/docs/MEETING_NOTES.md` §6).

## Cleanup

- `DELETE` after the app saved the note removes everything (MN-24).
- `maintain_staging` (the daily maintenance job) deletes a meeting whose last piece arrived more than 30 days ago, finished or not (MN-27), and finished results the app never acknowledged after 30 days.
- Deleting the account deletes its meetings (the rows cascade from the user).
