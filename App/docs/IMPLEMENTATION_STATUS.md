**Full product backlog implementation**

The user authorized implementation of the entire B01–B23 backlog on 22 September 2026, including the items previously marked Validate. This file tracks delivery and verification; the scope remains the full list in CRITIQUE_REVIEW.md. Calendar remains the first screen and both appearance modes remain available. Work stays on dev in each repository.

Baseline: existing toolchain changes and critique review committed and pushed as 7b9db0e. The backend containers are running and healthy. Existing product checks are historical evidence; changed behavior will receive new checks.

| Item | Required outcome | State / current evidence |
|---|---|---|
| B01 | Durable, account-isolated capture sessions with retry/resume/discard and no duplicate saves | Implemented; SQLite restart, failed requests, interrupted WAV recovery, transactions and duplicate-save tests pass. Android route exit/resume passes. OS process-kill/real microphone matrix remains. |
| B02 | Explicit task reminder controls and notification Settings | Pending |
| B03 | Inspectable reminder scheduling, continuing summaries, delivery/reboot checks | Pending |
| B04 | Content-free diagnostics and repeatable capture evaluation | Local bounded counts/timings and Settings view implemented; evaluation corpus and remaining funnel events pending. |
| B05 | Correct website/app claims and guest/attachment disclosures | Current guest and local-attachment disclosures corrected in both repositories; web commit b93b596 pushed. Recheck as later features ship. |
| B06 | Prominent voice and typed capture, simpler capture UI and onboarding | Labeled primary voice entry, retained typed entry and simpler capture screen implemented. Empty-state teaching / usability checks remain. |
| B07 | Native speech, live feedback, endpointing, capability-aware offline fallback | Pending |
| B08 | Quick typed capture, scheduling shortcuts and bounded local parsing | Pending |
| B09 | Inline draft editing, neutral clarification, recoverable partial-batch saving | Implemented. Inline schedule/priority, field edits, explicit confirmation and ready-only save pass widget and persistence tests, including 2× text in both themes. |
| B10 | Agenda hierarchy, stable Inbox, clear navigation and direct task actions | Pending |
| B11 | Consistent gestures, Undo, quieter metadata and retained theme access | Pending |
| B12 | Android shortcut, share entry and microphone widget | Pending |
| B13 | Notification open/complete/snooze for the correct occurrence | Pending |
| B14 | Synced checklists, progress and structured AI extraction | Pending |
| B15 | Personal lists and labels, preserving task identity and sync | Pending |
| B16 | Interval/weekday recurrence and single-occurrence exceptions | Pending |
| B17 | Versioned export/import with preview and round-trip fidelity | Pending |
| B18 | Device-aware preferences and localization infrastructure/translations | Pending |
| B19 | Attachment upload/download and fresh-device restoration | Pending |
| B20 | Read-only external calendar display with permission and duplicate handling | Pending |
| B21 | Planned start, deadline, duration and hourly day view | Pending |
| B22 | Shared lists, membership/invitations, permissions and cross-user sync | Pending |
| B23 | Standalone notes and explicit capture routing with useful note structure | Pending |

Completion requires inspecting each acceptance criterion and recording applicable tests, app builds, backend/API checks and runtime evidence. Emulator checks must be distinguished from physical-device delivery/speech tests and human usability research. Missing evidence remains outstanding. Tests must exercise behavior and failure recovery, not merely mirror implementation.

Capture checkpoint, 22 September 2026: all 50 Flutter tests pass; flutter analyze reports no issues; Android x64 debug APK builds. Docker backend's 32 tests pass. The Android integration driver passes capture exit/resume, batch review, registration, local save, real HTTP/PostgreSQL sync and re-login restoration. That run substitutes only AI responses (`FIXTURE_AI=true`); it is not a speech/provider accuracy or latency measurement. Web Next.js type generation and TypeScript checks pass. Logs are in the ignored App/artifacts directory.
