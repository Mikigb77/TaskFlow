# Recurrence rules and individual dates

B16 adds intervals from 1–99, selected ISO weekdays for weekly repetition, and individual moves/skips. Monthly and yearly rules clamp short months without permanently changing the original anchor. The end date includes the final original occurrence; moving it beyond that end date is allowed.

Each occurrence is identified by its original calendar date. Moving it preserves that identity, completion and checklist progress. Two occurrences can share a displayed day. Calendar, details, completion history, notification navigation and notification actions use the original identity. Whole-series changes reset individual exceptions with an explicit choice in the editor; the reschedule sheet explains the same behavior before saving. Skipped dates can be restored in the editor. Undo preserves unrelated changes and refuses a newer schedule.

SQLite migration 10 and Django migration 0006 preserve existing records with an interval of one and no exceptions. The API bounds interval, weekday, exception count, date/time exclusivity and unique original dates. Older clients that omit the new fields retain them. Account ownership and existing optimistic conflict checks still apply.

Validation on 22 September 2026:

- All 96 Flutter tests and 52 backend tests pass. Flutter analysis is clean; Django has no ungenerated migrations.
- Tests cover alternate weeks, selected weekdays, month-end/leap dates, same-day collisions, end dates, canonical storage, occurrence completion/checklists, skipped/reset dates, history after pattern changes, and Undo after intervening edits.
- Real SQLite reminder tests verify unchanged alert identities/tokens, replacement of a moved alert, cancellation of a skipped alert, stale action rejection, and completion of the original date.
- Repeat controls and task metadata pass 320×568 screens at 2× text in both themes. The repeat interval dialog scrolls with large text and the keyboard.
- Android integration passes real SQLite, HTTP/PostgreSQL sync and fresh-cache restoration of alternate-week rules, weekday selections, a moved occurrence, its checklist and original completion key. The UI skips that occurrence and restores it with Undo. The actual notification plugin holds the moved alert; its guarded action completes the original date. Light/dark detail screenshots were captured. This invokes the notification action handler directly; it is not a new physical delivery or drawer-action claim.

Extraction supports the new fields in structured output and review. The synthetic corpus has 19 English/Spanish cases, including alternate weeks and workdays. Both new live cases failed with provider service errors (3,349 ms and 30,005 ms). No recurrence extraction accuracy or latency claim can be made from that run. Existing provider availability concerns remain; no different model was substituted. The ignored report is `Backend/artifacts/recurrence-evaluation.json`.

This is calendar recurrence using the device's local wall clock, matching the existing task model. Ordinal business-day/holiday rules and independent historical timezone rules are not inferred. Physical-device and iOS delivery validation remain separate from the scheduling tests.
