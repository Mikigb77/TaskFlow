## UX review — Area A: voice capture (whole-app run 2026-10-19-app) — 2026-10-19

**Verdict:** Ship after fixes. The three-tap path (Añadir tarea → Listo → Añadir al calendario) works from every way in and saves land lit, but three things fail the newcomer: two microphone refusals end voice for good on the online path, «No se encontraron tareas» loops or saves nonsense, and at 2× an open question's answers sit below the pinned buttons.

**How I looked** (GUIDELINES.md present):
- **Renders:** `App/build/ux/{capture,commands,calendar,notes,settings}/` and AUDIT.md, rendered 13:26–13:28 from 3a6ad40. `find App/lib App/assets -newer` lists nothing, so all are current (widget-test evidence).
- **Device captures:** `App/build/ux/device/`, 13:30–14:42, from 3a6ad40. The only uncommitted changes are in pubspec and scripts, outside the UI. Emulator evidence: no real voice.
- **Code:** for everything else, as each finding says.
- **SEEN-2026-10-19:**
  - confirmed in the new captures: #3, #4, #5, #6, #8, #12 (shortcuts and widget);
  - #7: partly; it's question 1;
  - #14: not reproduced with real taps;
  - #1: fixed;
  - #2, #9, #10, #11, #13: other areas.

**Walked** (newcomer: Spanish, 2× text, 360 dp; daily user: several in a row; TalkBack user):
- **Dictation from Calendar (Pro):** Añadir tarea → speak → Listo → Añadir al calendario → Calendar on the day, lit, «Añadida al…» with Deshacer. 3 taps, plus Android's dialog on first use.
- **Free accounts:**
  - with dictations left: the same, plus «Escribir» → form;
  - at 0 left: «Nueva tarea» → monthly notice → «Crear una tarea» → form.
- **Ways in:**
  - the widget, warm and cold;
  - «Dictar una tarea» → listening;
  - «Escribir una tarea» → form (free);
  - sharing → form (free) or the typing sheet (Pro);
  - «Sin guardar» → resume.
- **Microphone:** first ask; one refusal; two refusals on the on-device path (ES) and the online path (CA); Abrir Ajustes.
- **Listening:** the pause hint, the 50 s warning, the 60 s limit with and without words, leaving the app, TalkBack start.
- **Waiting and failure:** Entendiendo…; slow (8 s); offline; 503; nothing understood; 429; on-device start failure.
- **Results:** one task; three tasks (one opened); AM/PM question; no date; free 3/1/0 left — at 1× and 2×, ES and CA.
- **Commands:**
  - projects: new, existing, ambiguous;
  - find: results and none;
  - change: which one, which day, other details;
  - delete: a task and a series;
  - mixed and not found;
  - applied, then Deshacer.
- **Voice note:** Añadir nota → Guardar nota.
- **Interrupted:** Cancelar keep/discard, Back, the scrim, the app killed → «Sin guardar · N».

**Numbers:**

| What | Before | After |
|---|---|---|
| Taps for one dated spoken task | 3 (+1 Android dialog on first use) | unchanged |
| From «No se encontraron tareas» back to listening | 3 taps and a destructive choice (Cancelar → Descartar → Añadir tarea) | 1 («Volver a decirlo») |
| Voice back after two refusals, online path | no way from the app | 1 tap, then 3 named steps in Android's Settings |
| Voice back after two refusals, on-device path | the dominant button does nothing; 5 unguided taps | 1 tap, then 3 named steps |
| 2× AM/PM result: answer chips in view on arrival | 0 of 3 | 3 of 3 |
| Gap between adjacent capture controls (AUDIT) | Listo↔Cancelar/Escribir 4 dp; «Sin guardar»↔«Añadir tarea» 0; «Descartar»↔«Conservar» 0 (2×); Cancelar↔Volver a decirlo 0 (≥1.3×); ↔«Ver lo que dije» 1 | ≥ 8 dp everywhere |
| Batch result day lines | 40 dp, no sign they can be tapped | 48 dp with a chevron |
| Pro listening sheet: labelled controls | 2 of 3 | 3 of 3 |
| «Sin guardar» row subtitle | 8 fixed words; 5 lines at ES 2× | 2–3 words; 2 lines |

### Findings (most severe first)

**UX-107 (reopened) · Severity 3 · Two refusals end voice for good on the online path**
- **Where:** `App/lib/screens/voice_task_screen.dart:956-971`; the capture sheet, microphone refused twice, on the online path. That path is used with Voz «En línea, al terminar», on phones without on-device recognition, and for languages the phone can't recognise itself (Catalan on the emulator).
- **The moment:** "I pressed No by mistake. Now it keeps saying allow the microphone, but nothing asks me."
- **What happens:**
  - `_recorder!.hasPermission()` only answers yes or no, so «blocked» is never set.
  - After Android stops asking, the sheet keeps the first refusal's «Permet l’accés al micròfon per gravar o escriu a sota.» and a filled «Comença a parlar» that does nothing.
  - There is no «Obre Configuració».
- **Why it fails:** ON-7 (Android Permissions; Android 11 Permissions): a denial isn't a dead end, and Settings is offered when the user tries again. UN-7. UX-107's fix covered only the on-device path.
- **Fix:**
  1. Ask through a check that can answer «blocked» on both paths, instead of `hasPermission()`: the bridge's `permission` (`NativeSpeechBridge.kt:85-94`, which already answers granted, denied or blocked), or `Permission.microphone.request()` from permission_handler (already imported).
  2. Then show UX-1303's blocked state.
- **Verify:**
  - widget test: online path with a permanently denied permission → blocked state with «Abrir Ajustes»;
  - emulator lane: re-capture `permission-mic.blocked.ca.*` and it shows «Obre Configuració».
- **Evidence:** seen in an emulator capture (`device/permission-mic.blocked.ca.light.1.0.png`, 14:32); verified in code.

**UX-1301 · Severity 3 · «No se encontraron tareas»: retry repeats, the main button saves nonsense**
- **Where:**
  - `voice_task_screen.dart:1937-1981` (primary buttons when failed) and `:1326-1357`;
  - `capture_processor.dart:276-278` (an answer with no task and no command);
  - `app_es.arb:886`.
- **The moment:** "I said «Hola, ¿me oyes?» to try it. Now it says it found no tasks, and the big green button wants to save that as a task."
- **What happens:**
  - The sheet shows «No se encontraron tareas. Tus palabras se conservan.», the tonal «Reintentar» and the filled «Guardar como tarea».
  - «Reintentar» sends the same words again and gets the same answer.
  - «Guardar como tarea» saves «Bueno, a ver, no sé» as an undated task.
  - There is no way to say it again: Cancelar → «¿Conservar…?» → Descartar → Añadir tarea.
  - Render: `capture/sheet.error-nothing-understood.es.light.1x.png`.
- **Why it fails:**
  - VO-4 (Yankelovich 1995; Myers 2021): show an example after a failed attempt.
  - VO-11 (Goetsu 2020; Google Errors): name what's missing.
  - VO-6 / UN-7: a next step that can work.
  - SC-4: the one filled button should be the likely next action.
  - Newcomers often test with a non-task phrase, so the first dictation fails (VO-15).
- **Fix:**
  1. For this problem only, the filled button becomes «Volver a decirlo» (`captureSayAgain`): it clears the words and listens, as on a result. With no dictations left, «Escribir» takes that place, as on a result.
  2. «Guardar como tarea» becomes a text button under it.
  3. Drop «Reintentar»: the same words give the same answer.
  4. Typed words keep the editable field, with «Listo».
  5. New copy for `captureNoTasks`:
     - ES «No he encontrado ninguna tarea. Di qué y cuándo, por ejemplo: «Mañana, llamar al dentista».»
     - EN "I didn't find a task. Say what and when, for example: “Tomorrow, call the dentist.”"
     - CA «No he trobat cap tasca. Digues què i quan, per exemple: «Demà, trucar al dentista».»
- **Verify:**
  - preview `sheet.error-nothing-understood.*`: «Volver a decirlo» filled, no «Reintentar»;
  - widget test: the tap clears the words, renews the capture and starts listening;
  - TalkBack reads the new line once (live region).
- **Evidence:** seen in a current render; verified in code.

**UX-1302 · Severity 3 · At 2×, an open question's answers sit below the pinned buttons**
- **Where:** `voice_task_screen.dart:3694-3816` (scroll area plus pinned footer, «Ver lo que dije» at `:3789`); `capture_review_editor.dart:162-258`.
- **The moment:** "It asks «¿A las 5 de la mañana o de la tarde?» but there's nothing to tap, and the grey button says «Revisa los datos de arriba»."
- **What happens:**
  - At 2× on 360 dp, the title (3 lines) and the date (2 lines) fill the scroll area.
  - «05:00 · 17:00 · Sin hora» are out of view, and the box is cut under the question.
  - The pinned footer takes about 280 of 752 dp: the button, Cancelar, Volver a decirlo, «Ver lo que dije».
  - Renders: `capture/result.question.es.light.2x.png`, `…ca.light.2x.png`.
  - In `commands/cards.mixed.es.light.2x.png`, the card the button will delete is entirely below the fold too.
- **Why it fails:**
  - SC-5 (Fessenden 2018): what's needed to finish shows without scrolling, or is pinned.
  - VO-9: the question's answers are the action.
  - VO-8: a deletion is confirmed by something visible.
  - Recurring problem: key content off-screen at large text.
- **Fix:**
  1. When a result shows, and after each answer, scroll the first card with an open question or blocking choice into view, bottom-aligned (`Scrollable.ensureVisible`; jump when animations are off).
  2. Move «Ver lo que dije» from the pinned footer to the end of the scrolling cards. It is rarely needed, and that frees about 60 dp at 2×.
- **Verify:**
  - re-render `result.question.{es,ca}.light.2x`: the three chips are in view;
  - widget test at 2× on 360×800: the first chip's rect is inside the viewport.
- **Evidence:** seen in current renders.

**UX-1303 · Severity 2 · Microphone blocked: the big button is dead; Settings lands on App info**
- **Where:**
  - `voice_task_screen.dart:1944-1949` («Empezar a hablar» shows while `_micBlocked`);
  - `:2051-2064` (banner and text «Abrir Ajustes»);
  - `app_es.arb:896`.
- **The moment:** "I press «Empezar a hablar» and nothing happens. I open Ajustes and it's a page with Desinstalar and Forzar detención."
- **What happens:**
  - When blocked, the focused filled «Empezar a hablar» re-asks; Android answers «blocked» without a dialog, so nothing happens.
  - The way out, «Abrir Ajustes», is a small text button.
  - It lands on «Información de la app» (`device/permission-mic.open-settings-landing.es.light.1.0.png`), where the person must find Permisos › Micrófono › Permitir on their own.
  - AUDIT: TalkBack focus starts on the dead button.
- **Why it fails:**
  - ON-7: offer Settings when the user tries again.
  - SC-4: the dominant button must work.
  - CO-3 (Cowan 2001): the steps in Android's Settings must be said before the user leaves.
  - OL-2: the red error style implies a fault.
- **Fix:**
  1. While blocked, hide «Empezar a hablar».
  2. Make «Abrir Ajustes» the filled button, with the autofocus.
  3. Keep «Escribir» and Cancelar.
  4. Show the banner in the neutral style:
     - ES «Para volver a dictar, abre Ajustes y toca Permisos › Micrófono › Permitir.»
     - EN "To dictate again, open Settings and tap Permissions › Microphone › Allow."
     - CA «Per tornar a dictar, obre Configuració i toca Permisos › Micròfon › Permet.»
  5. The return path stays: `_checkMicrophone` listens when the person comes back with the microphone allowed.
- **Verify:**
  - preview `capture/sheet.mic-blocked.*`: one filled «Abrir Ajustes», no «Empezar a hablar»;
  - AUDIT: focus on «Abrir Ajustes»;
  - emulator lane: `permission-mic.blocked.*`.
- **Evidence:** seen in a current render and an emulator capture; verified in code.

**UX-1304 · Severity 2 · Listening hints and the limit say the wrong thing**
- **Where:**
  - `voice_task_screen.dart:1915-1923` (hint);
  - `:923-935` (timer);
  - `:1166-1167` (announcement);
  - `app_es.arb:904-905`.
- **The moment:**
  - "It says «Toca Listo» but Listo is grey."
  - "It said 10 seconds left a while ago."
  - "It just reset; did it hear me?"
- **What happens:**
  1. With no words yet, after 5 s it shows «Sigo escuchando. Toca Listo cuando termines.» while «Listo» is off (`device/capture.listening-hint.es.light.1.0.png`, `widget.tap-landing-cold.*`, `capture/sheet.listening-quiet.es.light.2x.png`).
  2. «Quedan 10 segundos» stays from 50 s to 60 s; at 00:57 it still says 10 (`device/capture.listening-countdown-late.es.light.1.0.png`).
  3. At 60 s with nothing heard, the on-device path silently returns to «Empezar a hablar» (`device/capture.listening-ended.es.light.1.0.png`), and TalkBack hears «Listo». The online path instead says «No te he entendido…».
  4. On the online path, no words ever appear while speaking, and nothing says so (`device/capture.listening.ca.light.1.0.png`).
- **Why it fails:**
  - VO-1 and VO-3 (Yankelovich 1995; Budiu 2018): people can't tell a silent system from one that didn't hear them.
  - Recurring problems: copy written for one moment read at another; instruction copy outliving its state.
  - AC-11: the time limit isn't announced.
- **Fix:**
  1. No words yet (on-device):
     - ES «Aún no he oído nada. Habla cuando quieras o toca Escribir.»
     - EN "Nothing heard yet. Speak when you're ready, or tap Type instead."
     - CA «Encara no he sentit res. Parla quan vulguis o toca Escriu.»
  2. Make the countdown real, with an ICU plural on 60 − seconds, and announce it once at 50 s:
     - ES «{seconds, plural, =1{Queda 1 segundo} other{Quedan {seconds} segundos}}»
     - EN «{seconds, plural, =1{1 second left} other{{seconds} seconds left}}»
     - CA «{seconds, plural, =1{Queda 1 segon} other{Queden {seconds} segons}}»
  3. At 60 s with nothing heard, show the existing `captureNoSpeech` («No te he entendido. Vuelve a intentarlo o escríbelo.»), as the online path already does, and don't announce «Listo».
  4. On the online path, from the start:
     - ES «Te escucho. Verás tus palabras al tocar Listo.»
     - EN "I'm listening. You'll see your words when you tap Done."
     - CA «T’escolto. Veuràs les paraules quan toquis Fet.»
- **Verify:**
  - previews `sheet.listening-quiet` and `listening-time-left`, the latter at 57 s showing «Quedan 3 segundos»;
  - emulator lane: re-capture `capture.listening-ended`;
  - semantics test: no «Listo» announcement when nothing was heard.
- **Evidence:** seen in emulator captures and current renders; verified in code.

**UX-1305 · Severity 2 · First microphone ask has no reason; the refusal says «escribe abajo»**
- **Where:** `voice_task_screen.dart:956-971`, `:1984-1991` (the disabled «Listo» while asking); `app_es.arb:895`.
- **The moment:**
  - "I tapped «Añadir tarea» and it asks if TaskFlow can record audio? Record what?"
  - Then: "Write below where?"
- **What happens:**
  - The very first tap brings Android's «¿Permitir que TaskFlow grabe audio?» with nothing from the app (`device/permission-mic.dialog.es.light.{1,2}.0.png`).
  - After «No permitir», a red banner says «Permite el acceso al micrófono para grabar o escribe abajo.» There is no field below, only «Escribir» (`device/permission-mic.denied.es.light.1.0.png`).
- **Why it fails:**
  - ON-6 (Tan 2014: reasons raised approval from 66% to 74%; Rosala 2019): give the benefit in one sentence.
  - OL-2: refusing is a choice, not an error.
  - SC-9: «grabar» isn't the app's word.
- **Fix:**
  1. While Android's question is up, replace the disabled «Listo» with one line. Show it only when the permission isn't granted yet, so a normal start doesn't flicker. It stays visible under the dialog at 1× and 2×, as the captures show the sheet's bottom, so it costs no taps:
     - ES «Permite el micrófono para dictar tus tareas. Solo escucha mientras dictas.»
     - EN "Allow the microphone to dictate your tasks. It only listens while you dictate."
     - CA «Permet el micròfon per dictar les tasques. Només escolta mentre dictes.»
  2. After a refusal, `captureMicrophone`, in the neutral (non-error) banner:
     - ES «Sin micrófono no puedo escucharte. Toca Empezar a hablar para permitirlo, o Escribir.»
     - EN "Without the microphone I can't hear you. Tap Start talking to allow it, or Type instead."
     - CA «Sense micròfon no et puc escoltar. Toca Comença a parlar per permetre-ho, o Escriu.»
- **Verify:** emulator lane, `permission-mic.dialog.*` (the line under the dialog) and `permission-mic.denied.*`.
- **Evidence:** seen in emulator captures.

**UX-1306 · Severity 2 · On-device speech that can't start loops, in jargon**
- **Where:**
  - `NativeSpeechBridge.kt:124` (Android 12 reports usable without checking the language) and `:278-281`;
  - `native_speech.dart:26`;
  - `voice_task_screen.dart:950`, `:1087-1099`;
  - `app_es.arb:912-913`.
- **The moment:** "It says «reconocimiento local no está instalado… graba audio». Where do I record audio? I press «Empezar a hablar» and it says it again."
- **What happens:**
  - When the recognizer can't do the language (Android 12, or a probe that timed out), the start fails.
  - The sheet says «…Elige otro idioma, graba audio o escribe.», but the sheet has neither control.
  - «Empezar a hablar» retries the same path, because this sheet's `_capability` never changes; the next sheet probes «usable» again.
  - Voz already promises the alternative: «Este teléfono no puede con este idioma por sí solo, así que TaskFlow lo hace en línea.»
- **Why it fails:** UN-7 (Neusesser 2023); recurring problem: developer text on user screens; VO-16.
- **Fix:**
  1. On `speechLanguage`, `speechUnavailable` or an error before `ready`, switch this sheet to the online path (`_nativeMode = false`) and start listening again at once, as Voz promises.
  2. Remember «not usable» for the session (`NativeSpeech.remember`).
  3. Only if that fails too, show (replacing both keys):
     - ES «Ahora no puedo escucharte en este teléfono. Toca Escribir.»
     - EN "I can't listen on this phone right now. Tap Type instead."
     - CA «Ara no et puc escoltar en aquest telèfon. Toca Escriu.»
- **Verify:**
  - widget test with a fake bridge whose `start` fails with the language error: the sheet records, with no error and no extra tap;
  - device check: Android 12, app in Catalan.
- **Evidence:** verified in code; inferred, needs a device check.

**UX-1307 · Severity 2 · Six dictations in a minute says «límite de hoy… mañana»**
- **Where:** `capture_problem.dart:92` (every 429 is `allowance`); `app_es.arb:890`.
- **The moment:** "I added five things quickly and now it says try tomorrow?"
- **What happens:** Three different refusals all show «Has llegado al límite de hoy. Escribe la tarea o inténtalo mañana.», next to a «Reintentar» that would work in a minute:
  - the server's 6-per-minute AI throttle;
  - the daily budget (Retry-After 3600);
  - Google's quota (429 with no Retry-After).
- **Why it fails:** UN-7; the owner's bar is several tasks in a row at speed (DECISIONS 2026-10-13); OL-2.
- **Fix:** Read `ApiException.retryAfter` in `CaptureProblem.from`:
  - ≤ 120 s → new `tooFast`:
    - ES «Has dictado muchas veces seguidas. Espera un minuto y toca Reintentar.»
    - EN "You've dictated a lot in a row. Wait a minute, then tap Try again."
    - CA «Has dictat moltes vegades seguides. Espera un minut i toca Torna-ho a provar.»
  - no Retry-After → `unavailable`;
  - otherwise → `allowance`, pointing at the button that's there:
    - ES «Has llegado al límite de dictados de hoy. Toca Guardar como tarea o inténtalo mañana.»
    - EN "You've reached today's dictation limit. Tap Save as a task, or try again tomorrow."
    - CA «Has arribat al límit de dictats d’avui. Toca Desa-ho com a tasca o torna-ho a provar demà.»
  - Cause partly server-side: the daily refusal's Retry-After is 1 h, and the quota refusal sends none.
- **Verify:** unit tests for 429 with Retry-After 30, 3600 and none.
- **Evidence:** verified in code (app mapping; `Backend/config/settings.py:55`, `Backend/core/views.py`).

**UX-1308 · Severity 2 · TalkBack isn't told the result arrived, or what it says**
- **Where:** `voice_task_screen.dart:2341-2356` (`CaptureResult.initState`: nothing announced).
- **The moment:** "I pressed Listo, it said «Listo»… then silence. Is it done? What did it understand?"
- **What happens:**
  - Listening, «Listo», «En pausa» and the slow line are announced.
  - The result replaces the focused «Listo» without a word, so the most important state, the date, is never spoken.
- **Why it fails:** AC-7 (Android A11y testing): results are announced politely; VO-1; VO-5.
- **Fix:** After the result's first frame, `sendAnnouncement`, without moving focus:
  - one task: «{title}, {date line}» (e.g. «Llamar al médico, vie, 23 de oct · 10:00»);
  - several: `captureThingsToAdd(n)`;
  - an open question: add its text.
  - No new strings.
- **Verify:** semantics test: one announcement holding the title and the date; TalkBack device check.
- **Evidence:** verified in code.

**UX-1309 · Severity 2 · The save message covers the task it just lit**
- **Where:** `calendar_screen.dart:158-205` (`_reveal`: fixed 88 dp clearance; the measured clearance is used only for the no-date row, UX-475) and `:781` (only the first lit row is revealed).
- **The moment:** "It says «3 tareas añadidas»… I see one, half hidden under the grey box."
- **What happens:**
  - At 2×, the 4-line message covers the lit row's lower half (`calendar/agenda.added.es.light.2x.png`, `commands/applied.change-applied.es.light.2x.png`).
  - At 1×, a 3-line message already reaches the lit row's last line and hides its bottom edge (`commands/applied.mixed-applied.es.light.1x.png`).
  - A second task on the same day («Recoger a los niños», 17:00) lands below the fold, out of sight (`agenda.added.es.light.1x.png`).
  - The highlight has faded by the time the message leaves.
- **Why it fails:**
  - SC-10 (Rensink 1997): show the change where the user looks.
  - SC-11 (Kahneman 1993): end on visible success.
  - U5: "visible and highlighted… every time".
- **Fix:**
  1. Use `_messageClearance()` (UX-475's measured height) for dated landings too, instead of the fixed 88 dp.
  2. When several rows landed on the shown day, reveal from the first to the last if they fit above the message, otherwise the first.
- **Verify:**
  - re-render `agenda.added.es.light.2x`, `applied.change-applied.es.light.2x` and `applied.mixed-applied.es.light.1x`: lit rows clear the message;
  - widget test: two same-day dictated tasks at 393 dp, both above the message.
- **Evidence:** seen in current renders; verified in code.

**UX-1310 · Severity 2 · Pro's keyboard is an unlabelled icon; free accounts get «Escribir»**
- **Where:** `voice_task_screen.dart:2225-2238`, `:2250-2260`.
- **The moment:** "I can't talk here. How do I write it?" Then: "what's that little grid?"
- **What happens:**
  - Pro sees [Cancelar][Listo][⌨]: an unlabelled 48 dp icon in the corner, 4 dp from Listo. Free accounts see a full-width «Listo» with «⌨ Escribir» under it, the same control labelled (`capture/sheet.listening.es.light.1x.png` and `sheet.listening-free.es.light.1x.png`).
  - In the slow state, «Guardar como tarea» wraps to two lines inside a 166 dp button (`sheet.understanding-slow.es.light.1x.png`).
- **Why it fails:**
  - SC-6 (Harley 2014): label icons on the default path.
  - OL-4.
  - SC-9: same control, same look.
  - RE-2: the primary is the largest target.
- **Fix:** Use the free layout for every account:
  - the filled action full width;
  - under it, Cancelar at the start and «⌨ Escribir» (`captureTypeInstead`) at the end.
  - Same 3 targets; +1 word.
- **Verify:** re-render `sheet.listening.es.light.1x`: AUDIT shows «Escribir» labelled, the primary 312 dp wide, «Guardar como tarea» on one line.
- **Evidence:** seen in current renders.

**UX-1311 · Severity 2 · Capture controls touch; «Descartar» touches «Conservar»**
- **Where and gaps** (AUDIT; all in `voice_task_screen.dart` unless named):

  | Place | Pair | Gap now |
  |---|---|---|
  | `task_actions.dart:122-146` | «Sin guardar · N» above «Añadir tarea» | 0 dp |
  | `_controls` `:2274`, `:2258` | Listo ↔ Cancelar / Escribir | 4 dp |
  | `_exits` `:3449-3481` | Cancelar ↔ Volver a decirlo (stacked, ≥1.3×) | 0 dp |
  | `_exits` | ↔ «Ver lo que dije» | 1 dp |
  | `_askToKeep` `:304` and `_askToDeleteSeries` `:2915` at 2× | «Descartar» above «Conservar»; «Eliminar» above «Conservar tarea» | 0 dp |
  | `capture_command_cards.dart:266` | project chips | 4 dp |

- **The moment:** "I meant Conservar and hit Descartar; my words are gone."
- **What happens:**
  - Descartar has no undo.
  - Every other pair is a frequent mis-tap for an unsteady hand.
- **Why it fails:**
  - RE-3 (Kobayashi 2011; Jin 2007): zero spacing gave older adults the worst accuracy.
  - RE-6 (Harada 2013): keep destructive actions apart.
- **Fix:**
  - 8 dp under «Sin guardar · N»;
  - 12 dp under the filled button(s) in `_controls`;
  - 8 dp between the stacked exits and before «Ver lo que dije»;
  - `actionsOverflowButtonSpacing: 12` on both dialogs (Flutter's default is 0);
  - `runSpacing: 8` for the project chips.
- **Verify:** re-render; AUDIT shows no «Gap under 8 dp» for these pairs, including `sheet.keep-question` and `cards.delete-series`.
- **Evidence:** measured in AUDIT (current renders).

**UX-1312 · Severity 2 · Batch cards' day line is 40 dp and looks untappable**
- **Where:** `capture_review_editor.dart:366-397` (`dense`, `VisualDensity.compact`; chevron only on the main line).
- **The moment:** "The doctor is on Friday at 10, it should be 11. How do I change it?"
- **What happens:**
  - On a several-task result, each day line is a 286 × 40 dp button with no chevron (AUDIT `capture/result · several`: 3 targets under 48 dp).
  - The single-task line, the same component, is 56 dp with a chevron.
- **Why it fails:**
  - RE-2 (Parhi 2006; Android Touch targets);
  - SC-9;
  - VO-6 (Suhm 2001): fix by touch needs a visible tap target;
  - several tasks per dictation is the owner's must-have.
- **Fix:** Drop `dense` / `VisualDensity.compact` so the row is ≥ 48 dp, and show the main line's trailing chevron (20 dp) on compact cards too.
- **Verify:** AUDIT `result · several`: no target under 48 dp; the render shows the chevrons.
- **Evidence:** measured in AUDIT; seen in current renders.

**UX-1313 · Severity 2 · Typing at 2×: an invisible example pushes the words off the top**
- **Where:** `voice_task_screen.dart:1996-2017`.
- **The moment:** "Where's the start of what I wrote?"
- **What happens:**
  - Flutter 3.44.5's `maintainHintSize` (default true) keeps the space of the hidden three-sentence `examplePlan` hint.
  - The field is 164 dp for two lines at 1×; at 2× it's taller than the space above the keyboard.
  - The reversed scroll shows the empty bottom of the field, and the typed words' first lines go under the sheet's top edge (`capture/sheet.typing.es.light.2x.png`, also `sheet.error-offline`).
- **Why it fails:** FO-8 (WCAG 2.4.11); AC-3.
- **Fix:** `maintainHintSize: false` on the field's `InputDecoration`. The example still shows while the field is empty.
- **Verify:** re-render `sheet.typing.es.light.2x`: the words show from the first line with the field's top edge; AUDIT field height ≈ text height.
- **Evidence:** seen in a current render; verified in code and Flutter source (`input_decorator.dart:1085-1087`).

**UX-1314 · Severity 2 · Project question chips are cut at 2×: «Crear «Mat…», «Otro proye…»**
- **Where:** `capture_command_cards.dart:495-511` (34 dp indent) and `:255-258` (one line, 230 dp, ellipsis).
- **The moment:** "Crear… what?"
- **What happens:**
  - AUDIT `commands/cards · project-question`, ES 2×: «Crear «Mates»» is 21 dp too wide, «Otro proyecto…» 32 dp.
  - CA 2×: «Un altre projecte…» is 71 dp too wide.
  - These are the answers that unblock the button.
- **Why it fails:** a cut button label is a broken button (§20.8); LO-1 (W3C Text size); AC-3.
- **Fix:**
  - Let the choices span the card, as the day question box already does (`:971-974`).
  - Let chip labels wrap to 2 lines instead of an ellipsis.
- **Verify:** re-render `cards.project-question.{es,ca}.light.2x`: AUDIT «Cut text» 0.
- **Evidence:** measured in AUDIT; seen in current renders.

**UX-1315 · Severity 2 · «En Mates…» never offers «Matemáticas»**
- **Where:** `capture_command_cards.dart:181-190` (`_similar`: prefix or contains only).
- **The moment:** "I meant Matemáticas, obviously. Now it wants to create «Mates»."
- **What happens:**
  - The server flags `ambiguous_project` for «Mates» beside «Matemáticas» and «Matemáticas II».
  - «mates» is neither a prefix nor a part of «matematicas», so the card offers only «Crear «Mates»» (first) and «Otro proyecto…» (`commands/cards.project-question.es.light.1x.png`).
  - The likely answer takes a sheet and a scan; the easy tap makes a duplicate project.
- **Why it fails:** CO-4 (Chernev 2015): a default plus «Other…»; UX-908's acceptance promised similar projects as chips.
- **Fix:**
  - Also match projects whose folded name shares the said name's first 4 letters («mate»), ranked after prefix and contains matches, at most 3 chips.
  - Cause partly server-side: the server knows which projects matched but sends no ids. Sending them would let the card show exactly those.
- **Verify:** re-render `cards.project-question`: chips «Matemáticas» and «Matemáticas II»; unit test `_similar('Mates', …)`.
- **Evidence:** seen in a current render; verified in code.

**UX-1316 · Severity 2 · Widget and launcher shortcut labels are cut at large text**
- **Where:** `CaptureShortcuts.kt:29-34` (only `setShortLabel`); `res/layout/capture_widget.xml:8` (12 sp, 2 lines, fixed cell).
- **The moment:** "«Dictar un…» what?"
- **What happens:**
  - At 2× the shortcuts read «Dictar un…» and «Escribir u…» (`device/launcher.shortcuts.es.light.2.0.png`, `-360dp`).
  - The widget's second line is sliced through: «Dictar una / ~~tarea~~», CA «Dicta una / ~~tasca~~» (`device/widget.home.{es,ca}.light.2.0.png`).
- **Why it fails:** PL-9 (Android Shortcuts): short labels ≈ 10 characters, long ≈ 25; AC-3.
- **Fix:**
  1. Shortcuts: one-word short labels (new `capture_voice_short` / `capture_text_short`), with today's text as `setLongLabel`. The launcher shows the long label only where it fits.
     - ES «Dictar» / «Escribir»
     - EN "Dictate" / "Type"
     - CA «Dicta» / «Escriu»
  2. Widget: `android:autoSizeTextType="uniform"` (10–14 sp) on the label. API 26+; minSdk 24 keeps today's look.
- **Verify:** emulator lane at 2×: `launcher.shortcuts.*` and `widget.home.*` show whole words.
- **Evidence:** seen in emulator captures.

**UX-1317 · Severity 2 · «Sin guardar» rows repeat 8 words and can't be told apart**
- **Where:** `captures_screen.dart:25-39`, `:75-76`.
- **The moment:** "Three «Grabación de voz»… which is the one from this morning?"
- **What happens:**
  - Every row says «Tareas · Guardado en este teléfono · Toca para continuar»: 8 fixed words, 5 lines at ES 2× (`settings/pending-captures.three.es.light.{1x,2x}.png`).
  - «Tareas» is a plural for one capture.
  - No row says when it was kept.
- **Why it fails:** SC-1 (Nielsen 2006f): front-load what distinguishes rows; SC-2; CO-5; OL-7.
- **Fix:** The subtitle leads with when (existing day and clock helpers: «Hoy, 9:41», «Ayer, 18:05», «vie, 16 oct»), then only what differs:
  - «Nota» for notes;
  - `captureDraftSummary` («2 sin añadir»);
  - the used-up line for a waiting recording.
  - Drop «Tareas ·» and «Guardado en este teléfono · Toca para continuar»: the title and the chevron already say it. No new strings.
- **Verify:** re-render `pending-captures.three.es.light.2x`: each row ≤ 3 lines; test: two recordings show different times.
- **Evidence:** seen in current renders.

**UX-1318 · Severity 1 · Rare capture errors: jargon, or no next step**
- **Where:**
  - `voice_task_screen.dart:3093-3118` (`_apply` sets `saveFailed` for every error, so a command result applied offline never says «Sin conexión»);
  - `app_es.arb:887`, `:893`, `:914-920`;
  - the sheet's `timezoneFallback` banner (`:2050`, shows «Europe/Madrid»).
- **Fix** (ES / EN / CA):
  - In `_apply`, use `CaptureProblem.from(error)` for request errors.
  - `captureSaveFailed`:
    - ES «No se ha podido añadir. Tus palabras siguen aquí; vuelve a intentarlo.»
    - EN "Couldn't add it. Your words are still here; try again."
    - CA «No s’ha pogut afegir. Les paraules continuen aquí; torna-ho a provar.»
  - `captureStopFailed`:
    - ES «No he podido terminar de escuchar. Lo que dijiste antes se conserva.»
    - EN "I couldn't finish listening. What you said before is kept."
    - CA «No he pogut acabar d’escoltar. El que has dit abans es conserva.»
  - `captureIncompleteAudio`:
    - ES «Esta grabación no se puede usar. Descártala y vuelve a dictarla.»
    - EN "This recording can't be used. Discard it and dictate it again."
    - CA «Aquesta gravació no es pot fer servir. Descarta-la i torna-la a dictar.»
  - `captureTooLarge`:
    - ES «Esta grabación es demasiado larga. Descártala y dicta algo más corto.»
    - EN "This recording is too long. Discard it and dictate something shorter."
    - CA «Aquesta gravació és massa llarga. Descarta-la i dicta alguna cosa més curta.»
  - `captureUnsupportedKind` («Este servidor…») and `captureSpeechBusy` («solicitud del micrófono»): map to `captureFailed` and delete the keys.
  - Time zone: name the city Hora y región shows (UX-486), or leave the notice to that screen.
- **Why it fails:** UN-7 (Neusesser 2023); recurring problem: developer text.
- **Verify:** catalog test: no «servidor», «servicio» or «solicitud» in capture keys; unit test: `_apply` offline → «Sin conexión…».
- **Evidence:** verified in code.

**UX-1319 · Severity 1 · The too-long share toast is cut mid-word**
- **Where:** `res/values*/strings.xml:6` (`share_too_long`; also `share_queue_full`, `share_not_saved`).
- **What happens:** «TaskFlow admite hasta 4000 caracteres. Comparte un texto más co…» (`device/share.too-long-toast.es.light.1.0.png`). Android toasts keep 2 lines.
- **Fix:** At most 50 characters each:
  - `share_too_long`:
    - ES «Texto demasiado largo. Comparte uno más corto.»
    - EN "That text is too long. Share a shorter one."
    - CA «Text massa llarg. Comparteix-ne un de més curt.»
  - `share_not_saved`:
    - ES «No se ha podido guardar. Vuelve a compartirlo.»
    - EN "Couldn't save it. Please share it again."
    - CA «No s’ha pogut desar. Torna-ho a compartir.»
  - `share_queue_full`:
    - ES «Abre TaskFlow y acaba lo que ya compartiste.»
    - EN "Open TaskFlow and finish what you shared."
    - CA «Obre TaskFlow i acaba el que ja has compartit.»
- **Why it fails:** PL-6; LO-1.
- **Verify:** `native_resources_test.dart` asserts ≤ 50 characters; emulator lane `share.too-long-toast.*`.
- **Evidence:** seen in an emulator capture.

**UX-1320 · Severity 1 · A voice note's title stops mid-phrase («…y por la»)**
- **Where:** `capture_processor.dart:32-33` (`leadingTitle`).
- **What happens:** «Para la reunión del cole: preguntar por el comedor y por la» (`notes/note-capture.result.es.light.1x.png`). The list then shows the same words twice, as title and body.
- **Fix:**
  - End the title at «:» or «;» when at least 3 words come before.
  - Never end on a short linking word:
    - ES y, o, de, del, la, el, los, las, por, para, a, en, con, que;
    - CA i, o, de, del, la, el, els, les, per, a, en, amb, que;
    - EN and, or, of, the, a, to, for, with.
  - The example becomes «Para la reunión del cole».
- **Why it fails:** SC-1; recurring problem: translation and copy slips.
- **Verify:** unit tests for `noteTitle`; re-render `note-capture.result`.
- **Evidence:** seen in a current render.

**UX-1321 · Severity 1 · TalkBack polish in capture and command cards**
- **Where:** `voice_task_screen.dart:1996-2017`; `capture_command_cards.dart:664`, `:759`, `:886`, `:1167`.
- **What happens** (AUDIT):
  - the words field reads «text field (no label)» once typed into;
  - found rows and pick rows read «tappable», not buttons;
  - the ✕ on «¿Cuál quieres cambiar?» reads the search keywords: «No cambiar llamar ana».
- **Fix:**
  - `Semantics(label: captureYourWords)` on the field (an existing, unused key: «Tus palabras» / "Your words" / «Les teves paraules»).
  - `Semantics(button: true)` on `_FoundRow` and `_Choice` rows.
  - The ✕ on a choosing card:
    - ES «No cambiar ninguna» / «No eliminar ninguna»;
    - EN "Don't change any" / "Don't delete any";
    - CA: needs a Catalan translation (suggested «No en canviïs cap» / «No en suprimeixis cap»).
- **Why it fails:** AC-6 (WCAG 4.1.2).
- **Verify:** AUDIT TalkBack lists after re-render.
- **Evidence:** measured in AUDIT.

**UX-1322 · Severity 1 · While «Entendiendo…», the microphone still shows**
- **Where:** `voice_task_screen.dart:2175-2201` (`_ring` keeps the mic glyph under the spinner).
- **What happens:** The understanding state looks like listening with a spinner (`capture/sheet.understanding.es.light.1x.png`), so a newcomer may keep talking.
- **Fix:** Show the spinner alone, without the mic glyph, while processing.
- **Why it fails:** VO-1 (Yankelovich 1995): distinct states; the microphone is shown only while listening.
- **Verify:** re-render `sheet.understanding.*`.
- **Evidence:** seen in a current render.

### Keep
- **One sheet, one microphone, every way in.** The button, the widget, both shortcuts (fixed in 3a6ad40) and sharing all land in it. Android's green microphone dot shows only while «Escuchando» (`device/capture.listening-360dp.es.light.2.0.png`).
- **Nothing said is lost.** The shade, a call or leaving the app gives «En pausa» with Seguir. Cancelar asks only when something was said.
- **Results.** The date comes first, changes show as before → after, a deletion alone gets the red «Eliminar», and one «Deshacer» takes everything back (`commands/*`).
- **TalkBack start.** With TalkBack on, listening waits for «Empezar a hablar», which has the focus (`device/talkback.capture-sheet.es.light.1.0.png`).
- **Free tier.** The labelled «Escribir» and a short, honest monthly notice (`capture/used-up-notice.*`).

### Progress against UX_REVIEW.md (U1–U14)
- **U1:** holds in code. The emulator listened 60 s without a spurious stop, but with no voice; the real-voice phone check is still pending.
- **U2:** holds, but the 60 s limit with nothing heard resets silently (UX-1304).
- **U3:** holds. The device lane confirms every way in opens the same sheet.
- **U4:** holds at 1×. Regressed at 2×: an open question's answers sit under the pinned footer (UX-1302); batch day lines are 40 dp (UX-1312).
- **U5:** advanced, but still open: the message covers the lit row, and a second same-day task lands out of sight (UX-1309).
- **U6:** unchanged; device check.
- **U7:** holds. On «No se encontraron tareas» it becomes the only forward action (UX-1301).
- **U8:** holds: one button, «Nueva tarea» at 0 left. «Sin guardar · N» touches it (UX-1311).
- **U9:** holds. Pro's keyboard is unlabelled (UX-1310).
- **U11:** holds in capture.
- **U12:** the microphone is asked in context, but with no reason (UX-1305).
- **U10, U13, U14:** outside this area; unchanged.

### Questions for the owner
1. **Shared words in the free form.** Should their day and time be read, as D2 does for dictated words?
   - Evidence: sharing «Comprar pan y leche el viernes» opens the form with no day chosen (`device/share.landing.es.light.1.0.png`). Back saves it undated, with «el viernes» in the title (`share.after-back`: «Sin fecha · 1»).
   - The newcomer reads the title as dated and gets no reminder.
   - Recommendation: yes, the same parser and rules as D2.
2. **Should a dictation in which the assistant found nothing use one of the 10 free dictations?** Today it counts, because the assistant answered. A newcomer's «Hola, ¿esto funciona?» costs 1 of 10. Recommendation: don't count answers with no task and no command (server-side).
3. **Still open, no change asked here:** the widget and shortcut wording at 0 left (UX-910). UX-1316 only stops the labels being cut.

### Cross-slice notes
- **B:** with phone calendars on, Calendar's subtitle reads «No hay tareas de TaskFlow programadas», and untimed rows show «Sin hora» (`device/share.after-back`, `capture.result`).
- **B:** at 2× the week strip splits «dom» («do/m»), and day targets are 43 × 48 dp (AUDIT `calendar/agenda · pending-captures`; SEEN #12).
- **B:** the form opened by «Escribir una tarea» showed its title focused but no keyboard (`device/shortcut-text.after-tap`). Device check.
- **D:** the FilledButton theme minimum is 52 dp (`app_theme.dart:97`). AUDIT flags every primary under 56 dp (RE-3 aims at ≈ 63 dp for 60+).
- **D:** SEEN #2, #9, #10, #11 and #13 (reminder delay, calendar permission, reminder tap lands on the day, the alarms flash, the non-adaptive launcher icon) weren't re-checked here.
- **C:** the name sheet's prefill drops accents («Maria» from maria@…; `sharing/project-sharing.name-ask.*`).
- **A device check:** SEEN #14 (the text shortcut sent with launcher flags while the app is open lands on Calendar) wasn't reproduced with real taps.

### Memory notes
- **The evidence lane:**
  - `App/build/ux/INDEX.md` and `AUDIT.md` measure targets, gaps, cut text and TalkBack reading for 327 renders.
  - AUDIT's `textContrastGuideline` lines on tinted banners are histogram false positives; the full contrast pass is authoritative.
  - «Gap < 8» includes list rows that touch by design.
  - The INDEX's `listening-free` description still says «Rellenar a mano»; the render shows «Escribir».
- **Device lane:** `App/build/ux/device/INDEX.md` has 230 emulator captures with a11y XML. The review account is free tier with dictations left; Catalan uses the online (recorder) path on the emulator.
- **Flutter 3.44.5 facts:**
  - `InputDecoration.maintainHintSize` defaults to true, so a long hint sizes a multiline field;
  - `AlertDialog.actionsOverflowButtonSpacing` defaults to 0, so stacked actions touch at large text.
- **Launcher shortcuts:** Pixel Launcher shows a shortcut's long label only when it fits; `CaptureShortcuts` sets only the short one.
- **Android 12:** the speech capability probe reports usable without checking the language, so start errors there are the real signal.
- **Capture layout today:**
  - free and Pro control rows differ (Pro: an unlabelled ⌨);
  - the result's pinned footer is the button, Cancelar / Volver a decirlo and «Ver lo que dije»;
  - landings clear dated rows by a fixed 88 dp; only no-date landings measure the message.
- **New recurring problem types:**
  - hint copy pointing at a disabled control;
  - static numbers in a countdown;
  - key content under a pinned footer at 2×;
  - one control presented differently by tier;
  - a permission check that can't say «blocked» on one path.
- **Server limits the app sees as 429:** 6 per minute (Retry-After seconds), the daily budget (Retry-After 3600), Google's quota (no Retry-After).
