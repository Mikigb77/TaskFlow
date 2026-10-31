## UX review — Slice A: voice capture ("say it → see it on my calendar") — 2026-10-13

Paths are under `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\App\` unless a full path is given.

**Verdict:** Don't ship. The main loop still fails the newcomer. U1–U5 are still open, and seven new severity-3 problems sit on the same path:
- a "saved" bar that never goes away, and whose only button undoes the save;
- phantom "Capturas pendientes" entries;
- error messages in raw English;
- listening that stops whenever anything covers the app;
- live words off-screen at large text;
- a Pro wall with no way out;
- no way to fix a microphone that was blocked for good.

**Walked**, as each persona: newcomer (Spanish, text at 1.3–2×, one hand), daily user, TalkBack / low vision.
1. Calendar → Dictar una tarea → speak → Parar → wait → Revisar tarea (one task, a batch, an AM/PM question) → Guardar → back on Calendar → find the day. 7 steps.
2. Widget or launcher "Dicta una tarea" from a cold start, including the Pro check and the first permission ask. 8 steps.
3. Launcher "Captura texto", and sharing text from another Android app. 5 steps.
4. Notes → Dictar una nota → Revisar nota → Guardar. 4 steps.
5. Recovery. Leave while listening, while waiting, or from review; notification shade, call, backgrounding, app killed → Capturas pendientes → resume. 3–4 steps.
6. Microphone permission: first ask, denied, permanently denied. Failures: offline, slow AI, server errors 400 and 422, daily limit.

**Evidence:**
- **Code:** read for every flow.
- **Current renders:** `build/review-{direct,batch}-{light,dark}.png` and `build/calendar-feedback-light.png`.
- **Flutter 3.44.5 SDK source:** for the snackbar behaviour.
- **Capture screen:** no current render exists and I didn't run Flutter, so layout claims for that screen are estimated from widget sizes and paddings.

**Numbers:**

| Measure | Today | Proposed |
|---|---|---|
| Creation controls on an empty Calendar day | 3: Dictar una tarea, Nueva tarea, Escribir una tarea | 1 (U8) |
| Taps from an open app to a dated task visible on the calendar | 4 at best (Dictar → Parar → Guardar → tap the day); 6 for a typical newcomer (tap the mic again after a pause, pick 17:00); +1 for the permission on first use | 3 under U3–U5 (Añadir → Listo → Añadir al calendario); 4 with an AM/PM choice. The "find the day" tap disappears |
| Decisions on that path | 5 | 3 |
| Capture screen, idle | 8 tap targets, ~115 words in Spanish, ~12 concepts | U9 sheet: Cancelar, Listo, ⌨ and the user's own words |
| Review screen, one task | 8 tap targets; the date is the 4th row, at subtitle size | U4: date as the main line |
| Waiting after Done | ~5 s typical, 20.5 s worst seen. The message never changes, and the app only gives up at 100 s (`lib/services/api_client.dart:335`) | U7 |

- **Recovery on the default path:** yes. "Capturas pendientes · N" sits above the creation buttons on Calendar and Tasks whenever N > 0, and any Back, error or leaving during the wait makes N > 0 (UX-102). Once opened, the list is understandable — except for phantom entries. In Spanish and Catalan, "captura" usually means a screenshot.
- **Capture diagnostics:** not on this path, but it's a Settings row everyone sees (UX-120).

### Findings (most severe first)

**UX-101 · Severity 3 · "Saved" bar never leaves; its only button undoes**
- **Where:**
  - `lib/screens/review_tasks_screen.dart:153-219`: the save snackbar has an Undo action, `duration: 8 s`, and no `persist`.
  - `:233-245`: the "Borrador retirado" snackbar has the same problem.
  - Flutter 3.44.5 makes any snackbar with an action persistent unless `persist: false` is set (`C:\Users\mikig\Desktop\Custom\Flutter\flutter\packages\flutter\lib\src\material\snack_bar.dart:303`, `scaffold.dart:622`).
  - It also re-shows the current snackbar on every newly pushed screen (`scaffold.dart:211-216`).
  - Task completion already opts out, with the comment "Snackbars with an action persist by default" (`lib/widgets/task_interactions.dart:19-31`).
- **The moment:** "It still says '1 tarea guardada · Deshacer'. How do I close it?… I pressed it, my task vanished and the review page came back."
- **What happens:**
  - After Guardar, the bar stays above the capture bar indefinitely. It has no close control.
  - It follows the user into the next capture and onto its review screen, where it floats directly above "Guardar tarea".
  - Tapping that stale "Deshacer" removes the earlier task and pushes the old review on top (`review_tasks_screen.dart:190-200`).
- **Why it fails:**
  - Android's Snackbar reference: snackbars "automatically disappear after a timeout"; an indefinite one comes with a close icon.
  - Undo beats confirmation (Raskin 2000), but an undo that never expires becomes a trap.
  - Fitts: a stale target right next to the primary action.
  - It breaks the app's own completion pattern.
- **Fix:**
  - Add `persist: false` and `duration: await FeedbackTimeout.forAction()` to both snackbars — the same code task completion uses.
  - Call `hideCurrentSnackBar()` when a capture opens.
- **Verify:**
  - A widget test that mirrors `test/calendar_feedback_test.dart:87-93`: the save snackbar is gone after the accessibility timeout.
  - Open a second review screen and confirm no "Deshacer" is visible.
- **Evidence:** verified in code and in the SDK source; a quick device look is still worthwhile.

**UX-102 · Severity 3 · Leaving creates phantom "Capturas pendientes", even empty ones**
- **Where:**
  - `lib/screens/voice_task_screen.dart:397-401`: a capture record is written as soon as listening starts, before any words.
  - `:675-695`: leaving never deletes an empty record.
  - Widget and shortcut taps write an empty record before the screen even opens (`lib/main.dart:158-166`, `lib/services/capture_store.dart:81-112`).
  - The count is shown by `lib/widgets/task_actions.dart:18-30`; entries are titled by `lib/screens/captures_screen.dart:13-18`.
- **The moment:** "I only opened the microphone and went back. Now it says 'Capturas pendientes · 1'. What did I leave pending?"
- **What happens:**
  - Every abandoned attempt adds a permanent entry above the creation buttons on Calendar and Tasks. That includes tapping "Dictar una tarea" then Back, an accidental widget tap, and a widget tap while the mic is denied.
  - Opened, the entry reads "Grabación de voz" with a notes icon, then "Tareas · Guardado en este teléfono · Toca para continuar", and leads to an empty capture.
  - Clearing one takes 4 taps. Entries pile up.
- **Why it fails:**
  - The app changes state without the user doing anything.
  - The status describes something that doesn't exist (Nielsen: visibility of system status).
  - "Back = never mind" breaks (Norman: the user's model of the app).
- **Fix:** subtract. Never keep a capture with no words, no audio and no drafts. Write the record on the first words or audio bytes, and delete it on exit if it's still empty. Widget and shortcut entries carry no text, so they shouldn't write one up front.
- **Verify:**
  - Widget test: open `VoiceTaskScreen(startRecording: true)`, send no speech, leave → `pendingCapturesProvider` is empty.
  - Device: tap the widget, then Back → no count appears.
- **Evidence:** verified in code.

**UX-103 · Severity 3 · Errors show raw English and jargon, out of view**
- **Where:**
  - `lib/l10n/capture_messages.dart:35`: unknown values are shown as-is.
  - `lib/services/capture_problem.dart:62-93`: status codes 400, 404 and 422 aren't mapped.
  - `lib/services/api_client.dart:277-293`: validation errors become "field: message".
  - Copy: `lib/l10n/app_en.arb:1160-1172, 1184`, plus Spanish and Catalan.
  - The banner sits below the primary button (`voice_task_screen.dart:964-971`).
  - `MessageBanner` isn't a live region (`lib/widgets/app_components.dart:102-131`).
- **The moment:** "It says 'text: This field may not be blank' in English. Did I break it?" / "'Comprueba la dirección del servidor' — what server?"
- **What happens:**
  - "Revisar tareas del texto" stays enabled with no words (`voice_task_screen.dart:950`). After a silent attempt it sends empty text and shows "text: This field may not be blank."
  - With saved audio, a recording under 1 s shows "Use a 16-bit PCM WAV recording between 1 and 60 seconds." Silence shows "No clear speech was detected…". Both are English text from the server; the cause is server-side, but the app displays it raw.
  - Offline: "…Comprueba la conexión y la dirección del servidor…".
  - Speech engine stopped: "…graba audio o escribe…" — but the audio mode is hidden inside "Opciones de voz".
  - Daily limit: "Se ha alcanzado el límite de solicitudes del servicio." It says neither when it resets nor what to do instead.
  - Every banner appends "Tu captura se conserva…". It appears at or below the bottom edge even at 1× (estimated), and TalkBack doesn't announce it.
- **Why it fails:** Nielsen (2001) on error messages; plain language (ISO 24495-1); gulf of evaluation (Norman); WCAG 2.2 SC 4.1.3 (status messages).
- **Fix** (U7 handles slow and failed AI itself; this fix is copy and placement only):
  1. Disable the continue button while there are no words.
  2. Replace the raw fallback with one message — EN "That didn't work. Your words are saved here — try again." / ES "No ha funcionado. Tus palabras siguen aquí; inténtalo de nuevo." / CA "No ha funcionat. Les teves paraules continuen aquí; torna-ho a provar."
  3. Short or silent audio — EN "I didn't catch that. Tap the mic and try again." / ES "No te he entendido. Toca el micrófono y vuelve a intentarlo." / CA "No t'he entès. Toca el micròfon i torna-ho a provar."
  4. Offline — EN "No internet. Your words are saved — try again when you're online." / ES "Sin conexión. Tus palabras están guardadas; inténtalo cuando tengas internet." / CA "Sense connexió. Les teves paraules estan desades; torna-ho a provar quan tinguis internet."
  5. Speech stopped — EN "Listening stopped. Tap the mic to keep talking, or type." / ES "Se ha dejado de escuchar. Toca el micrófono para seguir o escribe." / CA "S'ha deixat d'escoltar. Toca el micròfon per continuar o escriu."
  6. Daily limit — EN "You've reached today's limit. Type the task, or try again tomorrow." / ES "Has llegado al límite de hoy. Escribe la tarea o inténtalo mañana." / CA "Has arribat al límit d'avui. Escriu la tasca o torna-ho a provar demà."
  7. Drop the appended "Tu captura se conserva…". Put the banner directly under the status line. Wrap `MessageBanner` in `Semantics(liveRegion: true)`.
- **Verify:**
  - Unit test on `captureProblemText`: no input produces English text or "field:" in Spanish or Catalan.
  - Widget test: with empty words the button is disabled.
  - At 2× on a 360×740 screen, the banner is visible without scrolling.
- **Evidence:** verified in code. I read the server messages only to confirm what the user sees.

**UX-104 · Severity 3 · Listening stops whenever anything covers the app**
- **Where:**
  - `voice_task_screen.dart:574-579`: stops on any lifecycle state other than `resumed`.
  - `:428-433` and `:476-481`: stops right after starting if the state isn't `resumed`.
  - On Android, Flutter reports `inactive` whenever the window loses focus — the notification shade, a system dialog (SDK `AppLifecycleState.inactive` docs).
- **The moment:** "I pulled down the bar to read a message and it stopped listening." / First use: "I said yes to the microphone and it still says 'Pulsa para hablar'."
- **What happens:**
  - Pulling down the shade mid-sentence ends the session and parks the words (the U2 path).
  - On first use, the permission answer reaches the app before its window gets focus back. Writing the record and starting the recognizer take only tens of milliseconds, so the check at `:428-431` can still see `inactive` and stop the session it just started.
- **Why it fails:** listening must never end without the user (lens J); only actually leaving the app is an interruption (lens I); it spoils the very first experience (peak–end rule).
- **Fix:** treat only `hidden`, `paused` and `detached` as interruptions — remove `inactive` from `:576`, `:429-430` and `:477`. The native side already stops on `Activity.onPause` (`android/app/src/main/kotlin/com/example/agenda/MainActivity.kt:36`), and the recorder already handles losing audio focus.
- **Verify:**
  - Device: on a fresh install, tap "Dictar una tarea", allow, speak at once → it keeps listening.
  - Pull the shade for 3 s mid-sentence → it keeps listening.
  - Widget test: report `inactive` during start → recording continues.
- **Evidence:**
  - Shade case: verified in code and SDK docs.
  - First-permission race: inferred from the order of events; needs a device check.

**UX-105 · Severity 3 · At large text, live words are off-screen**
- **Where:**
  - `voice_task_screen.dart:709-738`: headline, intro and Tareas/Nota chips sit first.
  - `:740-826`: then the mic block and help line.
  - `:925-947`: the words field comes last.
- **The moment:** "Is it hearing me? I only see a clock."
- **What happens:**
  - Estimated at 2× (Android's non-linear scaling) on a 393×852 dp phone: the words field starts about 800 dp down, so the first line of words is at or below the bottom edge.
  - On a 360×740 phone the words are fully hidden. At 1.3× they're still visible.
  - While listening, the user sees only "Escuchando · 00:07" and a 4 dp level bar.
- **Why it fails:** listening must show live words (Budiu & Laubheimer 2018; lens J); WCAG 1.4.4 resize text; the newcomer uses 1.3–2× text.
- **Fix:** subtract. While listening, hide the headline, intro, chips and help line, and show the words large, directly under the status line. U3's sheet needs this same shape.
- **Verify:**
  - Acceptance: at 2× on 360×740, the newest words are visible while listening.
  - Add a 2× Spanish capture preview, like the existing review previews.
- **Evidence:** inferred from widget sizes; needs a 2× render.

**UX-106 · Severity 3 · Without Pro, every way into capture dead-ends**
- **Where:**
  - `voice_task_screen.dart:44-92`: the Pro wall replaces the whole capture screen — voice, typing and shared text alike.
  - It's reached from the filled primary button (`task_actions.dart:42-50`), the widget, both launcher shortcuts, and Android share (`main.dart:173-183`).
  - Copy: `app_en.arb:1495` (`voiceProRequired`), `:1375` (`billingRefresh`).
  - `hasPro` also needs billing to be loaded (`lib/providers/subscription_provider.dart:82-88`).
- **The moment:** "I pressed the big green button and it wants me to pay? I just wanted to write something down." / "I shared a WhatsApp message and it says voice is Pro — I didn't say anything."
- **What happens:**
  - Without Pro, every way in lands on "La captura por voz está incluida en TaskFlow Pro." with "Ver Pro" and "Actualizar estado".
  - There's no way to the free typed editor.
  - Shared text waits in Capturas pendientes, and opening it leads back to the same wall.
  - Pro users may briefly see this wall on a cold start before billing loads (inferred).
- **Why it fails:**
  - Dead end (lens A).
  - Typed and shared text are blocked with a message about voice (Nielsen: match the real world).
  - "Actualizar estado" is jargon.
  - Removing "Nueva tarea" under U8 before this is fixed would remove non-Pro users' only free way to create a task from home.
- **Fix:**
  - Replace "Actualizar estado" (it belongs on the Subscription screen) with "Escribir la tarea" / "Type it instead" / "Escriu la tasca". It opens the typed editor with any kept or shared words as the title, and closes that capture. The server also requires Pro for AI, so this escape has to be the local editor. Note that the local date suggestion is off when a draft is passed in (`lib/widgets/task_editor.dart:461-468`).
  - For text and share entries — EN "Turning text into tasks is part of TaskFlow Pro. You can still type the task." / ES "Convertir texto en tareas es parte de TaskFlow Pro. Aún puedes escribir la tarea." / CA "Convertir text en tasques forma part de TaskFlow Pro. Encara pots escriure la tasca."
  - While billing hasn't loaded, show only a spinner, not the Pro headline.
- **Verify:**
  - Widget test with `hasPro` false: the button opens the editor pre-filled with the shared text.
  - Device: share text on a non-Pro account.
- **Evidence:** verified in code; the cold-start flash is inferred.

**UX-107 · Severity 3 · A blocked microphone can't be fixed from the app**
- **Where:** `voice_task_screen.dart:383-390`; `android/.../NativeSpeechBridge.kt:52-61`; copy `app_en.arb:1168` (`captureMicrophone`).
- **The moment:** "It says 'Permite el acceso al micrófono' — but how? Nothing is asking me."
- **What happens:**
  - After two denials, Android refuses instantly with no dialog.
  - Every tap shows the same red banner, below the fold.
  - There's no path to Settings, so voice never works again.
- **Why it fails:** error messages must say how to fix the problem (Nielsen 2001); dead end (lenses A and I); cautious newcomers often tap "Don't allow".
- **Fix:**
  - When Android won't ask again, show the banner next to the mic with one action:
    - EN "Microphone is off for TaskFlow. Turn it on in Settings, or type instead." [Open Settings]
    - ES "El micrófono está desactivado para TaskFlow. Actívalo en Ajustes o escribe." [Abrir Ajustes]
    - CA "El micròfon està desactivat per a TaskFlow. Activa'l a Configuració o escriu." [Obre Configuració]
  - When the user comes back, check again and start listening.
- **Verify:** device — deny twice, tap "Dictar una tarea", then use "Abrir Ajustes" → back in the app, listening starts.
- **Evidence:** verified in code; the permanent-denial path needs a device check.

**Severity 2**
- **UX-108 · 2 · Wrong status while starting.** `voice_task_screen.dart:127, 797-814, 418`; `NativeSpeechBridge.kt:123`.
  - Every capture opens with "Preparando tu plan…" and a progress bar before anything is said: loading and processing share the same `_busy` flag.
  - It then shows "Escuchando" before the recognizer reports ready — the `ready` event is ignored — so the first words may be cut off (device check).
  - → Show "Un momento…" / "One moment…" / "Un moment…" while starting. Switch to "Escuchando" and start the clock on `ready`.
- **UX-109 · 2 · TalkBack.** `voice_task_screen.dart:234-249, 762-792`; `task_actions.dart:39-41`.
  - Listening starts by itself while TalkBack is still reading the new screen; TalkBack's own speech may end up in the transcript (device check).
  - There's no spoken "Escuchando" cue.
  - The mic has a Semantics label and a different tooltip: "Parar y crear borrador" vs "Detener la grabación".
  - "Dictar una tarea" also reads its tooltip aloud.
  - → When `accessibleNavigation` is on, don't auto-start; focus the mic, labelled "Empezar a hablar". Announce "Escuchando" and "Listo". Use one label per state.
- **UX-110 · 2 · The AM/PM question shows four buttons.** `lib/widgets/capture_review_editor.dart:150-211`.
  - For "¿a las 5 de la mañana o de la tarde?" the card shows "5:00", "17:00", "Cambiar este dato" and "✓ Mantener este dato tal como está".
  - The AI leaves the time empty for this question, so the reassuring ✓ saves the task without the time the user said.
  - → When times are offered, show only the time chips plus "Sin hora" / "No time" / "Sense hora". Drop "Cambiar este dato" — the date row above already opens the editor. Elsewhere, relabel the confirm "Así está bien" / "That's right" / "Així està bé".
- **UX-111 · 2 · The review date has no weekday.** `lib/widgets/task_schedule_label.dart:10-12`, `lib/l10n/region.dart:16`.
  - The review shows "16 oct · 17:00" when the user said "el viernes", so checking it means knowing today's date.
  - → Lead with the weekday, using the locale formatter, and use Hoy / Mañana when they apply. U4 and U6 need this.
- **UX-112 · 2 · Spoken tasks ignore the selected day.** `lib/screens/calendar_screen.dart:69-70` vs `task_actions.dart:45-48`.
  - With Thursday selected, "Nueva tarea" pre-fills Thursday. "Dictar una tarea" ignores it: saying "comprar pan" sends the task to Bandeja with no date, and Thursday stays empty.
  - → For spoken tasks with no date, use the selected day when it isn't today. A spoken time without a day needs server support (cause partly server-side).
- **UX-113 · 2 · Voice notes get the whole transcript as title.** `lib/services/capture_processor.dart:45-55`; `capture_review_editor.dart:316-320`.
  - Speech has no line breaks, so the whole transcript (up to 160 characters) becomes the title and repeats in the body. Then the app shows "Usa un título breve…".
  - → Use the first sentence, or about 60 characters cut at a word, and drop the hint.
- **UX-114 · 2 · Typing entries open a mic-first screen.** `main.dart:177-180`; `voice_task_screen.dart:925-946`.
  - The "Captura texto" shortcut and shared text land on "Pulsa para hablar" and a big mic, with the text field unfocused further down.
  - → For text entries, focus the field with the keyboard up and hide the mic block. Rename the shortcut "Escribir una tarea" / "Type a task" / "Escriu una tasca" (`android/app/src/main/res/values*/strings.xml:3`).
- **UX-115 · 2 · Speech language.** `NativeSpeechBridge.kt:51, 68`; `voice_task_screen.dart:146, 309-319, 820`.
  - Speech language follows the phone, not the app.
  - A manual choice is forgotten every time the screen opens.
  - The help line shows a raw code: "Transcripción local · es-ES".
  - → Default to the app language, remember the last choice, and drop the code.
- **UX-116 · 2 · Batch cards.** `capture_review_editor.dart:282-287, 290-321`.
  - A question about the title only shows on an expanded card, so Save reads "Revisa los datos de arriba" with nothing visible above it.
  - ✕ only appears after expanding.
  - → Show every open question on collapsed cards. Put ✕ on each collapsed card and drop the pencil — tapping the title already expands it.
- **UX-117 · 2 · Nothing left to review.** `review_tasks_screen.dart:335-344, 381-391`.
  - With every draft removed, the pinned button reads "Revisa los datos de arriba" and is disabled, while the real exit is a small "Terminar" link.
  - → Make the bottom button an enabled "Terminar" / "Done" / "Fet" and remove the link.
- **UX-118 · 2 · Notes flips the emphasis.** `lib/screens/notes_screen.dart:138-157` vs `task_actions.dart:39-62`.
  - On Notes, typing is the filled button and voice is outlined — the opposite of Calendar and Tasks.
  - → Use the same emphasis everywhere until U8 leaves one button.
- **UX-119 · 2 · Share messages are English-only.** `android/app/src/main/kotlin/com/example/agenda/CaptureEntryBridge.kt:66, 71, 82`.
  - The three share messages are hard-coded in English.
  - → Move them to `res/values*/strings.xml`. ES "TaskFlow admite hasta 4000 caracteres. Comparte un texto más corto." / CA "TaskFlow admet fins a 4.000 caràcters. Comparteix un text més curt."
- **UX-120 · 2 · Developer screen in Settings.** `lib/screens/settings_screen.dart:262-268`; `app_en.arb:1289`.
  - "Diagnóstico de captura" (P50/P95, "tasa de conversión de usuarios") is a Settings row every user sees.
  - → Hide it in release builds.

**Severity 1**
- **UX-121 · 1 · One stop control, three names** (`app_es.arb` tapStopHelp / stopRecording / stopDraft): "Parar", "Detener la grabación" and "Parar y crear borrador", with no visible label. Spanish also says "Dictar una tarea" in the app but "Dicta una tarea" on the widget and shortcut (`res/values-es/strings.xml:2`). → Use one verb, "Listo", once U3 labels Done.
- **UX-122 · 1 · Catalan mixes verb forms** (`app_ca.arb` reviewSaveOne, reviewEditDetail, reviewConfirmDetail, reviewRemove, reviewRepair): infinitives sit among imperative buttons, e.g. "Desar tasca" next to "Desa la nota". → Use imperatives: "Desa la tasca", "Canvia…", "Mantén…", "Treu…", "Corregeix el text".
- **UX-123 · 1 · Missing plural** (`app_en.arb:1226` `captureKeptForReview`, English and Catalan): Catalan reads "1 conservades per revisar". → Add ICU plurals, e.g. CA "{count, plural, one{1 pendent de revisar} other{{count} pendents de revisar}}".
- **UX-124 · 1 · Two small labels** (`app_en.arb:232, 7`): "Task Title" → "Task title". "Ver lo que dije" also appears for typed and shared text → show it only for speech; otherwise "Texto original" / "Original text" / "Text original".
- **UX-125 · 1 · Shortcut icons** (`res/xml/capture_shortcuts.xml:2, 6`): both shortcuts use the app icon. → Mic for voice, pencil for typing.
- **UX-126 · 1 · Discard placement** (`voice_task_screen.dart:949-976, 633-636`): "Descartar captura" sits directly under the primary button, and its dialog makes Discard the filled button. → Fold it into U2's Cancel decision and make it a text button.
- **UX-127 · 1 · Default details shown as if chosen** (`capture_review_editor.dart:466-468`): "Más opciones" shows "Prioridad Baja · No se repite" on every task. → Drop that subtitle.
- **UX-128 · 1 · Widget picker jargon** (`res/values*/strings.xml:4`): "…conserva las capturas pendientes". → "Toca para dictar una tarea." / "Tap to say a task." / "Toca per dictar una tasca."

### Keep
- Captures survive Back, calls and the app being killed. Saving twice can't create duplicates, and saving part of a batch works (`lib/services/capture_store.dart:150-157`).
- The microphone permission is asked at the first capture, not at launch, and typing stays available if it's refused (`voice_task_screen.dart:383-390`).
- The current single-task review render is clean: Save is pinned in the thumb zone, extras fold under "Más opciones", and dark mode holds up.
- Time choices appear right on the card, formatted with the locale's clock (`capture_review_editor.dart:155-193`).
- The undo pattern on task completion (`task_interactions.dart:19-31`): reuse it for capture (UX-101).

### Progress against UX_REVIEW.md (U1–U14)

Nothing has advanced or regressed: no in-scope code has changed since 2026-10-12. All items in this slice are still open.

- **U1 Open.**
  - Still a one-shot `ACTION_RECOGNIZE_SPEECH` session (`NativeSpeechBridge.kt:39-46`).
  - A recognizer error ends the session (`lib/services/native_speech.dart:27-28`), and an automatic stop parks the words (`voice_task_screen.dart:348-353`).
  - New: hesitating also shows a red "No se ha detectado voz clara…" banner (`:347`).
- **U2 Open.** Three automatic stops park the words: end of speech (`:352`), the 59 s cap (`:364`) and focus loss (`:577`, UX-104). New: at 2× text, the only "continue" button (`:949-963`) is below the fold.
- **U3 Open.** Capture is a full page (`task_actions.dart:42-50`) with a second mic (`voice_task_screen.dart:767-791`). There's no Cancel while listening; Back silently keeps the capture (UX-102).
- **U4 Open.**
  - The result is on a separate page (`voice_task_screen.dart:612-619`).
  - The date is the 4th row's subtitle (`capture_review_editor.dart:373-380`) and has no weekday (UX-111).
  - "Bandeja personal" is always shown.
- **U5 Open.**
  - Saving just pops back (`review_tasks_screen.dart:152`), and the calendar keeps its selected day (`calendar_screen.dart:29`).
  - Saving a resumed capture lands back on the Capturas pendientes list.
  - The only feedback is the bar from UX-101.
- **U6 Open** (app side). No `EXTRA_BIASING_STRINGS` (`NativeSpeechBridge.kt:39-46`), and no speech/typed flag in the request (`capture_processor.dart:84-90`). The prompt change is server-side.
- **U7 Open.** No "Guardar tal cual". The local parser is used only in the typed editor (`task_editor.dart:461-468`). The app waits up to 100 s before giving up.
- **U8 Open.** An empty day has 3 creation controls (`task_actions.dart:39-62`, `calendar_screen.dart:452-456`). Notes flips the emphasis, and Day timeline adds a "+" button (`day_timeline_screen.dart:242`).
- **U9 Open.** Chips (`voice_task_screen.dart:720-738`), options (`:828-924`), privacy text (`:983-986`). New:
  - Engine, language and hold-to-talk reset every time the screen opens (`:142, 146, 190`).
  - They're hidden while the automatically started session runs (`:828`), so hold-to-talk is effectively unreachable. Remove it.
- **U10:** slice B.
- **U11 Open** in this slice: "Capturas pendientes" ("captura" reads as screenshot in Spanish and Catalan), "Lista para cuando tú quieras", "Revisar tareas del texto", "Bandeja de entrada · Sin fecha" (`task_schedule_label.dart:10`). U11's scope must also cover native strings: "Captura texto" and the widget description.
- **U12:** slice D. The microphone permission is already asked at the right moment.
- **U13 / U14:** undecided. U14 also decides whether capture works before sign-in; today shared and widget entries wait for an account (`main.dart:125-131`).

**U8 decision (slice A):**
- Keep one filled button with a mic icon — "Añadir tarea" / "Add a task" / "Afegeix una tasca" — on Calendar and Tasks. It opens the listening sheet (U3).
- Remove "Nueva tarea" and the empty-state "Escribir una tarea". Typing moves behind ⌨ inside the sheet.
- Before removing "Nueva tarea":
  1. the ⌨ path must work without Pro and offline (UX-106, U7);
  2. the sheet must carry the selected day, as "Nueva tarea" does today (UX-112);
  3. with TalkBack on, the sheet must not start listening by itself (UX-109).

### Questions for the owner
1. Voice and AI are Pro-only, on both the app and the server. For a newcomer without Pro, should the single "Añadir tarea" open free typing with the local date parser, or the paywall? This blocks U8. Is your father's account Pro or complimentary? If it is, the 10-minute test in §7 won't show the wall other newcomers hit.
2. Should a spoken task with no date go on the day selected in the calendar, as "Nueva tarea" does today?
3. Should Capture diagnostics stay visible in release builds?

### Cross-slice notes
- **B:** Day timeline's "+" button is a fourth way to create a task (`day_timeline_screen.dart:242`).
- **B:** Filters on the Tasks tab can hide a task that was just saved, so U5 needs to cover that tab too.
- **B:** `calendarEmpty` (`app_en.arb:290`) names the buttons that U8 and U11 remove.
- **C:** Confirm that a newly saved voice note appears at the top of Notes. Notes counts pending captures for notes only, while Calendar counts all kinds.
- **D:** The iOS microphone permission text says "task draft" / "borrador" (`ios/Runner/*.lproj/InfoPlist.strings`).
- **D:** `guestTrialHelp` can no longer appear, because sign-in is required.
- **D:** The Settings row in UX-120 is in your area — remove duplicates when merging.

### Memory notes
- **New issues (2026-10-13), all OPEN:**
  - UX-101 (3): review save/remove snackbars persist (Flutter 3.44 default when an action is set) and follow to the next screens.
  - UX-102 (3): empty or abandoned captures, including widget taps, become "Capturas pendientes".
  - UX-103 (3): capture errors show raw English server text (400/422), jargon, and a banner below the fold that isn't a live region; the continue button is enabled with no words.
  - UX-104 (3): listening stops on `inactive` (shade, dialogs); possible race right after the first permission grant.
  - UX-105 (3): live words below the fold at 1.5–2× text.
  - UX-106 (3): non-Pro users dead-end on the Pro wall from every capture entry.
  - UX-107 (3): no Settings path when the mic is permanently denied.
  - UX-108–120 (2): startup status, TalkBack, four-button AM/PM card, no weekday in the review date, selected day ignored, transcript used as note title, mic-first text entries, speech language, batch cards, nothing-left state, Notes emphasis, English share messages, diagnostics row.
  - UX-121–128 (1): copy and icon nits.
- **U1–U14:** none closed. Evidence added to U1, U2, U5, U7, U8, U9 and U11 as listed above.
- **Patterns:**
  - Every undo snackbar needs `persist: false` plus `FeedbackTimeout.forAction()`; the reference is `task_interactions.dart`.
  - `captureProblemText` falls back to raw text, so every new error must map to translated copy.
  - In `voice_task_screen`, `_busy` means both "loading" and "processing".
  - Every capture entry passes through the `hasProProvider` gate.
- **Screen map:**
  - Calendar and Tasks bottom bar: filled "Dictar una tarea" → VoiceTaskScreen (starts listening); outlined "Nueva tarea" → typed editor with the selected day.
  - Notes: typing is the filled button, voice the outlined one.
  - Widget, both shortcuts and share → native queue → `main.dart _openEntries` (signed-in only) → VoiceTaskScreen(captureId).
  - VoiceTaskScreen → replaced by ReviewTasksScreen → Save pops back to where the user started.
  - Back keeps the capture → "Capturas pendientes" list → resume.
  - No notification action leads to capture.
  - Settings → Capture diagnostics.

Sources:
- [Android Snackbar reference](https://developer.android.com/reference/com/google/android/material/snackbar/Snackbar)
- [Material 3 snackbar guidelines](https://m3.material.io/components/snackbar/guidelines) — located by search; the page itself returned no text when fetched.
