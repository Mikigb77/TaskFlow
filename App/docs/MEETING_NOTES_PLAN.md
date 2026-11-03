**Meeting notes — build plan**

How the requirements in [MEETING_NOTES.md](MEETING_NOTES.md) (MN-1 to MN-34) get built. The server–app contract is [Backend/docs/MEETINGS.md](../../Backend/docs/MEETINGS.md); both sides build against it and neither changes it alone.

Started on 2026-11-03 in a cloud session (4 CPUs, so at most two agents at once). That machine has Flutter and Python but no Android SDK, emulator or Docker: the evidence it can give is unit and widget tests, static analysis and rendered previews. The native recording path (foreground service, real microphone, battery, a killed process) needs the emulator or a phone afterwards, and is listed under "Not proven here".

## Packages

Each package is one implementer's work. The orchestrator runs packages whose dependencies are done, as many at once as the machine allows, then has each one checked by a tester before the next depends on it.

| Package | Depends on | Where | What |
|---|---|---|---|
| **S1 Server** | — | `Backend/` | Models `Meeting`, `MeetingPiece`, `MeetingChapter` (rows cascade from the user) and their migration; the four endpoints in `MEETINGS.md` with Pro, allowance and idempotency rules; `core/meetings.py` for the flow (save piece, chapter notes, final notes); prompts and pydantic validation in `core/ai.py` (always Vertex, `AI_MEETING_AUDIO_MODEL`, `AI_MEETING_TEXT_MODEL`); the 30-day sweep in `maintain_staging`; settings with defaults; tests with the AI mocked (`core/test_meetings.py`). |
| **A1 App core** | — | `App/lib/services/`, `App/lib/models/`, `App/android/` manifest only | `MeetingStore`: meetings and pieces in SQLite, account-scoped, audio files under the app's support directory, a piece deleted only after the server confirms it (MN-5, MN-13). `MeetingRecorder`: the `record` package (6.2) with `AndroidRecordConfig(service: …)` for the foreground service, mono 16 kHz Opus (or AAC if Opus can't survive a sudden stop), rotating to a new file at a pause after about 5 minutes, silence left out (MN-1 to MN-4). `MeetingUploader`: the API calls, two uploads at a time, retries with growing pauses, `finish` repeated until `ready`, then the note saved and `DELETE` sent (MN-8 to MN-11); a `workmanager` task with a network constraint so it runs with the app closed. Recovery: an interrupted recording found on start, the 7-day auto-finish, sign-out with pieces waiting (MN-12, MN-13, MN-26). Unit tests with fakes for the recorder, clock and API. |
| **A2 App screens** | A1 | `App/lib/screens/`, `App/lib/widgets/`, `App/lib/l10n/` | Entry point: «Grabar una reunión» in the Notes tab, Pro only (free accounts get the existing Pro sheet). The recording screen: elapsed time, a level, Stop, Discard with a confirmation (MN-7, MN-25). After Stop: «Preparando tus notas…», then the saved note. The note's «Crear tarea» opens the existing review editor with the to-dos as a checklist (MN-22). The Notes tab banner for a stopped or waiting meeting: «Continuar», «Terminar», «Descartar» (MN-11, MN-12). The "notes ready" notification. Every string in English, Spanish and Catalan; widget tests; UX previews of each new state at 2× text. |
| **T Test and review** | S1, A1, A2 | everything | Whole backend suite, `flutter analyze`, whole Flutter suite, previews; a review against MN-1 to MN-34 and `MEETINGS.md`; fixes for what it finds, then the same checks again. |
| **UX** | T | the new screens | The app's `/ux` loop on the change, as `AGENTS.md` requires for user-facing work. |

S1 and A1 run at the same time. A1 codes against `MEETINGS.md`, never against S1's code.

## Decisions the build takes, until the owner says otherwise

- Pro only, with a soft allowance of 240 pieces (about 20 hours) a month (`AI_MEETING_PIECES_PER_MONTH`).
- No consent reminder before recording in this version.
- The 7-day and 30-day limits as in MN-26 and MN-27.
- The result is saved as a note in the meeting's language; the to-dos become a task only on the person's tap.

## Not proven here

- Recording through Android's foreground service with the screen off, on a real microphone, for an hour.
- A killed process or a dead battery mid-recording (the file format's recovery).
- `workmanager` uploads with the app closed.
- Real Vertex AI calls: no Vertex project is configured (`AI_VERTEX_PROJECT` is unset), so the server's AI is mocked in tests. MN-32's test on three real recordings needs that project.
- The website's privacy page (MN-34): a legal text, changed only with the owner's sign-off (`../TaskFlowWeb/docs/LEGAL_RELEASE.md`).
