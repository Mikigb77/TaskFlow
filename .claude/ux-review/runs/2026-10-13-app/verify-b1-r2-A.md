## Verify — run 2026-10-13-app, round 2, area A (P49) — 2026-10-13

**UX-437 · fixed (needs a device check)**
- `App/lib/screens/voice_task_screen.dart:340-345`: on a `ready` event, `_nativePrefix` becomes the trimmed field text, capped at 4000 characters. This matches the start-of-listening prefix at :447.
- `:358-360`: a partial shows as prefix + text; only a `segment` advances the prefix. After a segment the field already equals the prefix, so the next `ready` changes nothing and the words aren't repeated. On an empty field the prefix stays empty and is filtered out of the join, so no leading space appears.
- Bridge ordering checked, read-only: `NativeSpeechBridge.kt:248` sends `ready` once for each `startListening`, and `attemptOver` (:170-184) only starts a new attempt after the previous one has finished. `current()` drops late events from the old attempt, so a stale partial can't arrive after the new `ready`.
- ux-tester: all three acceptance cases pass in `App/test/native_speech_test.dart` (group "P49", from :764).
- Still needs a phone: the Android 12 restart fallback and the Android 13+ segmented session.

**Regressions:** none. The P49 change is the `ready` branch alone. Other changes in this file belong to round 1 and were verified there. There's no visual change, so I didn't need a preview.

Edge cases I considered and ruled out:
- Text typed during listening is kept at the next `ready`, as the brief intended.
- If the field is longer than 4000 characters, only the prefix is cut; the field itself is unchanged.
- A `ready` carries no text, so it doesn't re-enter the text branch.
