---
name: screens-a-voice-capture
description: Screen and flow map for UX-loop area A (voice capture) as of 2026-10-13 — every way into capture, the Pro gate, the capture screen, review and save, the recovery list, and baseline counts
metadata:
  type: project
---

Current as of 2026-10-13 (whole-app run, slice A). The capture direction in UX_REVIEW §3 will reshape this area, so re-check before relying on it. Paths are under `App/`.

**Why:** reviews start faster from a current map, and the baselines supply the "before" numbers.
**How to apply:** start area-A reviews here, walk every way in below, and refresh this file whenever the flow changes.

## Ways in
- **Bottom bar on Calendar, Tasks and project pages** (`lib/widgets/task_actions.dart`):
  - filled "Dictar una tarea" → VoiceTaskScreen, which starts listening at once;
  - outlined "Nueva tarea" → the typed TaskEditor (`/createTask`).
- **More create controls:** an empty Calendar day adds "Escribir una tarea"; the Day timeline adds "+".
- **Notes tab:** the emphasis is flipped — "Nueva nota" is filled, "Dictar una nota" outlined.
- **Native entries:** the home-screen widget ("Dicta una tarea"), the launcher shortcuts "Dicta una tarea" and "Captura texto", and Android text sharing.
  - All go through the native queue → `_openEntries` in `lib/main.dart` (only once signed in) → VoiceTaskScreen(captureId).
  - Text entries also land on the mic-first screen.
- No notification action leads to capture.
- **The Pro gate.** Every entry first passes `hasProProvider`. Without Pro, a full-page wall appears with no way to typing:
  - "La captura por voz está incluida en TaskFlow Pro.";
  - buttons "Ver Pro" and "Actualizar estado".

## VoiceTaskScreen (`lib/screens/voice_task_screen.dart`, a full page)
- **Top to bottom:**
  1. headline and intro;
  2. Tareas / Nota chips;
  3. the mic, with "Escuchando · 00:07" and a 4 dp level bar;
  4. the help line ("Transcripción local · es-ES");
  5. "Opciones de voz" — engine, language, hold-to-talk. These reset every time the screen opens and are hidden while listening;
  6. the words field;
  7. "Revisar tareas del texto";
  8. the error banner;
  9. "Descartar captura".
- **Recognizer:** a one-shot `ACTION_RECOGNIZE_SPEECH` session (`android/app/src/main/kotlin/com/example/agenda/NativeSpeechBridge.kt`). The language follows the phone, not the app.
  - It ends at the end of speech, at the 59 s cap, or when the window loses focus.
  - Automatic stops park the words.
- **Microphone permission:** asked at the first capture. If it's permanently denied, a red banner appears with no way to Settings.
- **Waiting after Stop:** "Preparando tu plan…" with a progress bar. About 5 s typically, 20.5 s at worst; the app gives up at 100 s.

## Review and save
- **The review page.** VoiceTaskScreen is replaced by ReviewTasksScreen (`lib/screens/review_tasks_screen.dart` with `lib/widgets/capture_review_editor.dart`).
  - It shows one task, or batch cards that expand.
  - The date is the 4th row's subtitle, with no weekday.
  - An AM/PM question shows time chips plus "Cambiar este dato" and "Mantener este dato tal como está".
  - The project chip (TaskAssignmentPicker) reads "Bandeja personal".
  - The fold reads "Más opciones · Prioridad Baja · No se repite".
  - "Guardar tarea" is pinned at the bottom.
- **After Guardar:**
  - the app pops back to where the user started, and Calendar keeps its selected day;
  - a resumed capture returns to the Capturas pendientes list;
  - the snackbar "1 tarea guardada · Deshacer" never times out.
- **Voice notes:** Notes → "Dictar una nota" → "Revisar nota" → "Guardar". The whole transcript becomes the title.

## Recovery
- **The path back:**
  1. Back, an error or leaving the app keeps the capture.
  2. "Capturas pendientes · N" then sits above the create buttons on Calendar and Tasks. Notes counts only note captures.
  3. That row opens `/captures` (CapturesScreen), with entries like "Grabación de voz · Tareas · Guardado en este teléfono · Toca para continuar".
  4. Tapping an entry resumes it.
- Captures survive Back, calls and the app being killed. Saving twice can't create duplicates.

## Elsewhere
- Ajustes → "Diagnóstico de captura" (`/captureDiagnostics`) is visible to every user.

## Baselines (2026-10-13)
- **Create controls on an empty Calendar day:** 3 (4 counting the timeline's "+").
- **Opening the app to seeing a dated task on the calendar:**
  - 4 taps at best, 6 for a typical newcomer, and 1 more for the permission on first use;
  - 5 decisions along the way.
- **Capture screen, idle:** 8 tap targets, ~115 words in Spanish, ~12 concepts.
- **Review screen, one task:** 8 tap targets.

Related: [[ui-patterns]], [[screens-b-calendar-tasks]].
