## UX verify — P319 (round 1, check 2) — 2026-11-03
**Verdict:** UX-2704 still fixed at widget level. Both check-1 regressions are fixed in code. No new regressions. The phone check is still owed.
**Read:** the package diff (waves.py diff on wf_fe15d9eb-d17-3), `App/lib/providers/subscription_provider.dart:56-71`, `App/lib/screens/voice_task_screen.dart:562-566, 668-672, 2544-2585`, `App/lib/widgets/task_editor.dart:205-235, 928-933, 1298-1325`, the P319 test group's names (`App/test/capture_sheet_test.dart`), and the render `meetings/notes-lines.recording.es.light.1x.png` (23:38).
**Evidence level:** code and widget tests (2062 passed, as the implementer reports), plus one render. No device was used.

### UX-2704 · fixed
- `voiceAvailableProvider` is `!meetingHoldsMicProvider && (hasPro || freeLeft > 0)` (subscription_provider.dart:61-66). `meetingHoldsMicProvider` reads `meetingsProvider.select(recording != null)` (:68-71). The fix left it unchanged.
- In the render, Notes' «Añadir nota» shows + under «Grabando una reunión · 12:03». The only files changed after the render are voice_task_screen.dart and task_editor.dart. Neither draws the Notes tab, so the render is still current for the icon.
- The sheet types and starts no recognizer or recorder (`_voice` false, :668-672). It shows «Se está grabando una reunión: escribe aquí.» above the field (:2549-2556). The four P319 tests prove acceptance 1–3. Acceptance 4 is met: 136 of 136 tests in capture_sheet_test.dart pass unchanged.
- Still owed on the phone: the meeting keeps recording through a widget or «Añadir nota» attempt, and «El micrófono dejó de funcionar» never shows.

### Regressions from check 1
**R1-P319-1 · Meeting line outlives the meeting while the sheet is open · fixed**
- `voice_task_screen.dart:2549`: the line now shows only on `_meetingMic && field && ref.watch(meetingHoldsMicProvider)`, so it goes away when the recording stops. The sheet keeps typing, because `_voice` was decided when it opened, which is the existing rule.
- `!_meetingMic` (:2561) still keeps «Hablar es de Pro» away, after the meeting ends too.
- Evidence: verified in code. No test emits a stop while the sheet is open.

**R1-P319-2 · Free account mid-meeting told «Hablar es de Pro» in the form · fixed**
- `task_editor.dart:929-933`: `_noMic()` now also requires `!ref.watch(meetingHoldsMicProvider)`. During a meeting, the form shows no line, as the brief says.
- This touches task_editor.dart, which the brief left out, as check 1 noted. No other package of this run lists that file as shared.
- Evidence: verified in code (traced, not tested). The tester notes that a free account during a meeting is untested.

### New regressions
None.

### Checked, not regressions
- `task_editor.dart:223`: `return _writeWords(text);` became `await _writeWords(text); return;`. Inside an async `Future<void>` this behaves the same. It clears the analyzer warning check 1 mentioned, and nothing the user sees changes.
- Suppose a free account has used up its dictations and a meeting is recording, after Pro lapsed mid-meeting. A widget voice entry then opens the form with no used-up line. That's the brief's "no line there", and it is very rare. If the meeting stops while the form is open, the used-up line appears, which is true.
- Suppose a free account still has dictations left and the meeting stops while the form is open. `voiceAvailable` becomes true, so `_noMic` stays hidden. No wrong notice appears.
- `App/analysis_options.yaml` and `App/pubspec.lock` come from seeding, not from P319.

### Memory notes
- `_noMic` in the task form and the sheet's used-up and Pro line both now skip the meeting case. Any future "why it types" line has to check `meetingHoldsMicProvider` the same way.
