**Meeting notes from a recording — functional requirements**

Status: built on 2026-11-04 (server and app), checked with tests and rendered previews only; not yet checked on an emulator or phone, or against real Vertex AI calls ([MEETING_NOTES_PLAN.md](MEETING_NOTES_PLAN.md), "Not proven here"). Agreed with the owner on 2026-11-03; prices were checked on that date.

**What it is.** The person taps once to record a conversation, such as a meeting with a client, and taps again to stop. A few seconds later they get notes: a short summary, the decisions, the to-dos, and one line per half hour. One more tap turns the to-dos into a task with a checklist. Recording has no length limit, and works through hours without signal.

**Owner decisions behind this document (2026-11-03)**

- Record on the phone and send the audio in pieces of about 5 minutes while recording. No live streaming.
- As cheap as possible while keeping quality.
- Cover any language people speak, at least the common ones (English, Spanish and other widely spoken languages).
- All AI runs on **Vertex AI**, which the owner already pays for. No AI Studio credits.
- Keep nothing on the server that isn't needed: once the final notes exist, everything in between is deleted.
- Abandoned recordings must not stay forever ("zombies"), but a long trip without signal must not lose a real meeting.

## 1. Recording on the phone

- **MN-1.** One control starts recording and the same control stops it. The recording runs in an Android foreground service with the microphone type, keeps going with the screen off or the app in the background, and shows a notification with **Stop** and **Discard**.
- **MN-2.** Audio is mono, 16 kHz, compressed to about 24 kbps (about 11 MB an hour; the current WAV format would be about 115 MB). Gemini reduces audio to 16 kbps anyway, so higher quality only costs bandwidth.
- **MN-3.** Audio is written to disk as it's recorded, in a container that survives a sudden stop (Ogg Opus, not M4A). A battery that dies or a killed process loses at most a few seconds.
- **MN-4.** About every 5 minutes the recording is cut at a pause, so no word is split. Each piece is about 1 MB. Long silences are left out of the pieces, since audio is paid by the minute.
- **MN-5.** Each piece is numbered (0, 1, 2…) within its meeting, and the meeting has an id made on the phone.
- **MN-6.** The app warns before recording when the phone is low on space, and stops safely below about 100 MB free.
- **MN-7.** While recording, the screen shows the elapsed time and that it's listening. No live transcript in the first version.

## 2. Upload and recovery

The rule that makes recovery work: **the phone deletes a piece only after the server confirms its text is saved.** Every call is safe to repeat.

- **MN-8.** Pieces upload in the background through Android's job scheduler (WorkManager), also with the app closed, with retries and growing pauses after failures.
- **MN-9.** A backlog (for example 4 hours offline, about 48 pieces) uploads two pieces at a time, so the API's Cloud Run instances aren't flooded.
- **MN-10.** The phone makes only two kinds of call, with the person's normal login token. It never starts server jobs, queues or workers:
  1. "Here is piece N of meeting X."
  2. "Meeting X is finished; the last piece is N." The phone repeats this until it gets the notes back.
- **MN-11.** No signal: recording continues and pieces wait on the phone. Stop pressed offline shows the meeting as "Waiting for signal"; the notes are made once everything has arrived, and a notification says they're ready.
- **MN-12.** App closed or killed mid-recording, or the phone shut down: on reopening, the app asks "Your recording stopped at 1:42. Continue, finish or discard?" Continue adds to the same meeting.
- **MN-13.** Pieces belong to one account and only upload with that account's login. Signing out with pieces still waiting asks: upload first, or discard.

## 3. Server

- **MN-14.** No server instance holds a meeting. Its state is in PostgreSQL: the meeting, which pieces have arrived and their text, the chapter notes, and whether the phone said it's finished. Cloud Run can scale to zero between pieces, and the next piece may reach a new instance. The first call after a quiet spell wakes Cloud Run and the Neon database; that takes a few seconds in the background.
- **MN-15.** The server never stores audio. A piece is kept in memory only during its transcription call, then dropped. Memory per piece is about 1 MB; the limit to watch is Cloud Run request concurrency, since each piece holds a request open while Vertex works.
- **MN-16.** Receiving a piece: transcribe it in whatever language is spoken, save the text, confirm. The last sentence of the previous piece goes in as context, so names stay spelled the same. A piece received twice is saved once and charged once.
- **MN-17.** Chapter notes: when a piece completes a half hour, the same request turns that half hour's text into short notes (topics, decisions, to-dos, with times).
- **MN-18.** Final notes: when the meeting is finished and every piece up to the last number is in, the request that completes the set writes the final notes. Only the last piece and this step remain at Stop, so the result takes seconds whatever the length.
- **MN-19.** A failed step is done again by the next call (another piece, or the phone repeating "finished"). No queue or always-on worker is needed.

## 4. The result

- **MN-20.** The final step reads all chapter notes plus the full transcript and returns, as structured data:
  - a title;
  - a summary of three to five sentences;
  - the to-dos, with who and when if they were said;
  - decisions and open questions;
  - chapters: one line per half hour with its time range ("0:30–1:00 Pricing for the pilot"), which opens to that part's notes.
- **MN-21.** The result is saved as an ordinary note (the existing Note type), in the language of the meeting.
- **MN-22.** One tap turns the to-dos into a task with a checklist, through the existing review screen, so the person can untick what they don't want before saving.
- **MN-23.** Long meetings: four hours is about 36,000 words, or 50,000 tokens. Gemini 3.5 Flash-Lite reads up to 1,048,576 tokens in one call, so length isn't the limit; the chapter notes keep a long summary from turning vague.

## 5. Cleanup and abandoned recordings

- **MN-24.** Once the final notes are saved, the server deletes the meeting: its piece texts, chapter notes and row. Only the note (and a task, if made) remains.
- **MN-25.** **Discard** (in the notification and in the app) deletes the pieces on the phone and the meeting on the server at once.
- **MN-26.** A stopped recording whose question (MN-12) is ignored stays as a banner. After 7 days with no answer, the phone finishes it into a note, which the person can delete like any note. A real meeting is never thrown away silently.
- **MN-27.** The server deletes an unfinished meeting **30 days after its last piece arrived**, not after it started. This covers a phone that's uninstalled, never opened again, or left in an account nobody uses, while a trip of a few weeks without signal still works.
- **MN-28.** If a phone returns after the server deleted its meeting, the remaining pieces still become notes, marked "the start of this recording expired".
- **MN-29.** The existing daily maintenance job (03:17, Europe/Madrid) runs the 30-day sweep. Deleting the account deletes its meetings with everything else.

## 6. AI models and cost

All calls go to Vertex AI, global endpoint ([pricing](https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing)). On Vertex, "Google won't use your data to train or fine-tune any AI/ML models without your prior permission" ([zero data retention](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/vertex-ai-zero-data-retention)).

- **MN-30.** Default model for every step: **Gemini 3.5 Flash-Lite** ($0.30 per million tokens in, $2.50 out).
- **MN-31.** The model that transcribes pieces is a server setting. The fallback is **Gemini 3.5 Transcribe**, Google's dedicated speech model: 85+ languages detected automatically, up to three speakers, public preview, about $0.0051 a minute ([announcement](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-3-5-transcribe/)).

| Meeting length | Flash-Lite for everything | Transcribe for the pieces |
| --- | --- | --- |
| 1 hour | US$0.08 | US$0.32 |
| 2 hours | US$0.15 | US$0.64 |
| 4 hours | US$0.30 | US$1.28 |

Assumes 32 audio tokens a second ([audio docs](https://ai.google.dev/gemini-api/docs/audio)) and about 175 transcript tokens a minute. Chapter notes and the final step together cost under 2 cents an hour.

Not chosen: live streaming (Gemini 3.5 Transcribe Live, about $0.55 an hour, 10-minute sessions); Android's on-device recognizer (free, but built for close-up dictation); Whisper on the phone (large, battery-heavy, weak small models in Spanish and Catalan); ML Kit GenAI on Gemini Nano (alpha, few devices, summaries only in English, Japanese and Korean); Google Cloud Speech-to-Text and OpenAI transcription (no cheaper, another vendor). The free AI Studio tier is ruled out: its terms allow only paid services for apps used in the EEA, Switzerland and the UK, and say not to send confidential information ([terms](https://ai.google.dev/gemini-api/terms)).

## 7. Before building

- **MN-32.** Test the server side first on three real recordings, one of them over an hour, in Spanish, English and one other language (Catalan, if Catalan speakers matter: neither model's pages confirm it). Compare Flash-Lite pieces with Transcribe pieces, notes side by side, and set MN-31's default from the result.
- **MN-33.** Every new string goes in the three ARB files (English, Spanish, Catalan), checked at 2× text size.
- **MN-34.** When it ships, the website's privacy page says what happens to recordings, through the `/ux-web` loop in `../TaskFlowWeb`.

## Open decisions for the owner

Decided on 2026-11-04: staging's dictations run on Vertex only too (`AI_ROUTE=vertex` in the staging deploy), off the free AI Studio tier.


- Who gets meeting notes. Recommended: Pro only, since turning speech into tasks is the paid capability; at about $0.08 an hour no cap is needed, beyond perhaps 20 hours a month against abuse.
- A one-line reminder before recording that the other people should know they're being recorded.
- The 7-day (MN-26) and 30-day (MN-27) limits.
