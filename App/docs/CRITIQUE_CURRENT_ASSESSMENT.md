# TaskFlow: current assessment of the critique

23 September 2026. This supplements the [original evaluation and B01–B23 backlog](CRITIQUE_REVIEW.md). The supplied critique was about an earlier development build; its line references and missing-feature claims should not be applied unchanged to the current `dev` branch. This is a product and source assessment, not a new usability study or a claim that every acceptance test has passed.

## My evaluation

The central argument is sound: TaskFlow earns trust by preserving a thought, turning it into the right task with little effort, and surfacing it when needed. Visual polish and a long feature list cannot compensate for losing a recording, making a wrong appointment, or missing a reminder. Capture recovery and reminder controls were stronger priorities than another visual overhaul.

The critique is useful as a diagnosis, but too absolute as a specification. It mixes observed code defects with assumptions about abandonment, competitor behavior, implementation effort and what every user wants. Those assumptions need observation. It also proposes enough features to undermine its own demand for simplicity. Keep the quick path small even as the supporting model grows.

Its praise is worth preserving: local operation, conflict-preserving sync, date-only values, anchored recurrence, accessible controls, bounded AI output and the existing visual identity. Extend those foundations; avoid a rewrite justified only by the length of the critique.

## Recommendations I would change

- **Keep confirmation for AI-created schedules.** An empty clarification list does not establish correctness. A compact confirmation with direct corrections is a better initial default than silent saving. Auto-save could be a later opt-in experiment with measured error rates and durable Undo.
- **Measure the right parts of speed.** Count launch-to-ready, speaking time, stop-to-draft and confirmation-to-save separately. The critique's five-action claim overstated the simple auto-starting microphone route. A long spoken list cannot finish five seconds after its beginning.
- **Treat offline speech as a tested capability.** Having a native recognizer API is not evidence that a particular phone and language work offline. Retained text/audio and a typed path remain necessary. Local transcription alone does not make cloud extraction offline.
- **Keep permission and delivery behavior explicit.** Repeating a notification containing an old task snapshot would repeat stale information. Generic check-ins are appropriate unless fresh digest generation is proven. Exact scheduling access also needs denial/revocation handling and actual receipt tests.
- **Keep local parsing conservative.** Common phrases deserve accepted/dismissed schedule suggestions; ambiguous hours and unsupported language should remain editable text. A short parser is not incapable of mistakes.
- **Respect the product choices already made.** Keep Calendar first, make today's agenda prominent and preserve accessible theme controls. The critique's preference for removing those choices is not user evidence.
- **Do not equate missing breadth with a broken product.** Collaboration, time blocking, standalone notes and calendar integration are product choices. Their implementation now needs to demonstrate value without complicating basic capture.

## What has changed since the critique

The branch now contains durable unfinished captures, clearer voice/typed entry, quick typed scheduling, inline review and partial-batch saving, explicit reminder controls and actions, a more immediate agenda, external capture entries, checklists, personal/shared lists, recurrence exceptions, data import/export, attachment restoration, regional settings, read-only device calendars, planning fields and notes. [Implementation status](IMPLEMENTATION_STATUS.md) maps each change to B01–B23 and its evidence.

The latest validation exposed and fixed Android database contention between notification workers and the foreground app, plus a refresh that could skip an edit while another worker was running. The updated branch passes 190 Flutter tests, static analysis and a native Android suite covering competing database operations and real Spanish Complete/Snooze buttons. This is emulator evidence, not physical-device delivery evidence.

These are implemented capabilities, not proof of a dependable released product. The important remaining work is operational behavior and user understanding. For example, the recorded live extraction corpus passed 5 of 14 cases and had nine service failures; successful requests had a 31.975-second median. Subsequent two-case availability checks on both 22 and 23 September also failed. The latest requests returned service errors after 18.765 and 45.091 seconds. Those observations do not support a public sub-five-second promise. Likewise, synthetic file-input recognition on an emulator is useful diagnostic evidence, but does not establish real microphone accuracy or production endpointing. See [the evaluation record](CAPTURE_EVALUATION.md).

## Remaining to-do list, in priority order

| Priority | Work | What would count as done |
|---|---|---|
| P0 | Make live task extraction sufficiently available and fast. | Run the full English/Spanish corpus against the configured provider, count service failures as failures, score task/schedule mistakes and record latency. Compare a fallback or alternative model only as an explicit product decision; preserve retained input throughout. |
| P0 | Finish reminder delivery validation. | Extend the passing concurrency and native action tests to physical target phones with the app closed and under the documented permission, battery and reboot conditions. Observe actual receipt, not only successful scheduling. |
| P0 | Validate real capture recovery and speech on target phones. | Short tasks, longer lists, pauses, corrections, network loss and a call/background interruption retain usable input. Retry/Save creates one copy. Verify the actual English/Spanish offline support and endpoint behavior per device. |
| P1 | Observe first use and correction. | A small exploratory group finds both capture modes, creates a plain task, corrects a wrong time and saves a mixed batch without instruction. Compare with their existing method and act on observed hesitation/errors. |
| P1 | Finish language consistency and accessibility checks. | Remaining detailed action messages and recoverable server/platform errors have suitable English/Spanish presentation. User text stays unchanged; enlarged text, screen readers and both themes keep primary actions reachable. |
| P1 | Prove external handoffs and recovery in the intended setup. | A configured calendar app opens a selected event; a fresh signed-in installation restores supported task/file data and opens representative attachments. Keep provider fixtures distinct from real calendar-account evidence. |
| P2 | Validate the value of the expanded feature set. | Test one household/shared-list workflow and explicit task-versus-note capture. Keep capabilities that help recurring use; simplify entry and navigation where added choices obscure the core loop. |
| P2 | Define and validate the supported platform scope. | State which devices, languages and platforms are supported by evidence. Complete the relevant native builds and device checks before making broader claims. |

Do not reopen B01–B23 as another blanket feature-building round. Use the [remaining evidence register](VALIDATION_REMAINING.md) to close specific failures and gaps. No new main merge is implied by this assessment. The critique explicitly excludes monetization, operations and release packaging; it does not establish willingness to pay or a viable price.
