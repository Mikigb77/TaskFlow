## UX verify — P319 (round 1) — 2026-11-03
**Verdict:** UX-2704 fixed at widget level; one polish regression, and one rare wrong notice. Phone check still owed.
**Read:** the package diff (waves.py diff on wf_fe15d9eb-d17-3), `App/lib/providers/subscription_provider.dart:56-71`, `App/lib/screens/voice_task_screen.dart` (showCaptureSheet :77-165, VoiceTaskScreen.build :489-515, initState :669-672, `_sayAgain` :1848, banners :2546-2565), the readers of `voiceAvailableProvider` (notes_screen.dart:308, calendar_screen.dart:1031, task_actions.dart:60/117, task_editor.dart:930/1299, captures_screen.dart:44), the P319 tests (`App/test/capture_sheet_test.dart:4398-`), and the render `meetings/notes-lines.recording.es.light.1x.png` (23:38, newer than every file under lib/).
**Evidence level:** code and widget tests, plus one current render. No device.

### UX-2704 · fixed
- One check, where every entry already looks: `voiceAvailableProvider` is now `!meetingHoldsMicProvider && (hasPro || freeLeft > 0)`, and `meetingHoldsMicProvider` watches `meetingsProvider.select((m) => m.recording != null)` (subscription_provider.dart:62-71). The implementer took the brief's simpler option. meeting_banners.dart and the meeting services are untouched.
- The entries follow it without being edited: Notes' «Añadir nota» shows + (render `meetings/notes-lines.recording.es.light.1x.png`: + «Añadir nota» under «Grabando una reunión · 12:03»). Calendar's and Tareas' TaskActions show + and keep the label «Añadir tarea» for Pro, because `opensFormProvider` needs typesInForm, which is false with Pro. Task-page voice warming stays off (task_actions.dart:60).
- The sheet types: `voice` false comes from VoiceTaskScreen.build (:490), so `_voice` is false, no `_recorder` is made (:672), and `_autoStart` is false (:707), so the recognizer never starts. `_meetingMic = !_voice && meetingHoldsMic` (:671) adds «Se está grabando una reunión: escribe aquí.» in onSurfaceVariant bodyMedium, above the field (:2548-2555). It also stops the `captureSpeakingIsPro` and «Ver Pro» line for askedToSpeak entries (:2560-2561). For Pro, `freeVoiceLeft` is null, so no used-up line can show.
- Copy matches the brief exactly in ES, EN and CA, with ’ in CA. The key is next to the meeting keys, and the generated files were regenerated (git status).
- Tests: the four P319 tests cover acceptance 1–3. They check Notes, Calendar, a widget 'voice' entry after launch, and the mic coming back once `recording` becomes null, with the sheet listening and no line. Acceptance 4: 136 of 136 in capture_sheet_test.dart pass unchanged (tester).
- Device check still owed: on the phone, the meeting keeps recording through a widget or «Añadir nota» attempt, with no «El micrófono dejó de funcionar».

### Regressions
**R1-P319-1 · Severity 1 · The meeting line outlives the meeting**
- Where: `App/lib/screens/voice_task_screen.dart:566,671` (`late final bool _meetingMic`, set once in initState) and `:2548`.
- What happens: suppose the meeting stops while the typing sheet is open. It can stop from the ongoing notification, or by itself on a mic failure, no space or the 7-day finish. The line still says «Se está grabando una reunión: escribe aquí.», although `meetingsProvider.recording` is null. Typing still works and nothing is lost, so this is polish (recurring problem: help copy outliving state).
- Fix: show the line on `_meetingMic && field && ref.watch(meetingHoldsMicProvider)`. The sheet still types, because `_voice` was decided at open, which is the existing rule. It just stops claiming that a meeting records.
- Evidence: verified in code.

**R1-P319-2 · Severity 1 · A free account with dictations left, mid-meeting, is told «Hablar es de Pro»**
- Where: `App/lib/screens/voice_task_screen.dart:161-163` (`captureOpensForm`) → `App/lib/widgets/task_editor.dart:928-931,1299-1320` (`_noMic`).
- What happens: a meeting can keep recording after Pro lapses, because Pro is checked only at the start (meeting_screen.dart:48). In that state `voiceAvailableProvider` is false, so a widget or voice-shortcut entry (askedToSpeak) opens the form. `freeVoiceUsedUpProvider` is false because dictations are left, so `_noMic` shows «Hablar es de Pro» with «Ver Pro». That is untrue, since the account can still dictate. The real reason is the meeting. Before P319, this entry listened, which caused the mic conflict. The brief asked for "the form, as it would with no mic; no line there". The form now shows a wrong line instead.
- How often: rare. It needs a free account with a meeting already recording.
- Fix: in `_noMic`'s condition (task_editor.dart:929-931), also require `!ref.watch(meetingHoldsMicProvider)`. Then no line shows during a meeting, as the brief says. Alternatively, show `meetingTypeHere` there. This touches task_editor.dart, which the brief kept out of scope, so it belongs with the organizer.
- Evidence: verified in code (traced, not tested).

### Checked, not regressions
- Billing spinner (VoiceTaskScreen.build :491-500): a Pro entry during a meeting now has `voice` false. If billing were still loading with no free count, it would show the spinner. `loading` is only true before the first ready (subscription_provider.dart:170), and a recording meeting means the app is already running, so this is not reachable in practice.
- A Pro text shortcut (typing: true) during a meeting also shows the line. That is harmless and still true.
- `App/analysis_options.yaml` and `App/pubspec.lock` show in the diff, but every worktree of this run carries them from seeding, so they are not P319's.
- The analyzer warning at task_editor.dart:223 predates P319.

### Memory notes
- `voiceAvailableProvider` now also means "no meeting holds the mic" (`meetingHoldsMicProvider`, subscription_provider.dart). Any future recorder should hook in there.
- Watch for state decided once at open (`late final`) that drives copy: it goes stale when the state it describes changes while the sheet is open.
