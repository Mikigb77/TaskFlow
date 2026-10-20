# Verify, run 2026-10-19-app, batch b2, round 1, area A (P171 to P174), 2026-10-20

Evidence: code (`git diff HEAD`), plus the previews the tester re-rendered at 09:04–09:05, all newer than the app files they show, and `App/build/ux/AUDIT.md`. No device evidence.

## Results

| ID | Result | Evidence |
|---|---|---|
| UX-1310 | fixed | `voice_task_screen.dart:2454-2510`: `_controls` is now one Column for every account. The filled action spans the width, then a `Wrap(spaceBetween, runSpacing: 8)` with Cancelar and a labelled `TextButton.icon` «Escribir». The icon-only `IconButton` is gone. Renders `capture/sheet.listening.es.light.{1x,1.3x,2x}`, `sheet.listening-free.es.light.1x` and `ca.light.2x` all show Listo at 312 dp wide, with Cancelar at the start and ⌨ Escribir at the end. `sheet.understanding-slow.es.light.1x`: «Guardar como tarea» fits on one line. AUDIT lists TalkBack's order as Listo → Cancelar → Escribir. Device check still open: one-handed use on a phone. |
| UX-1311 | fixed | `task_actions.dart:128-149` adds 8 dp under «Sin guardar · N». `voice_task_screen.dart:2501` puts 12 dp under the filled buttons, `:3862` puts 8 dp between the stacked Cancelar and Volver a decirlo, and `:314` and `:3303` set `actionsOverflowButtonSpacing: 12`. `capture_command_cards.dart:308` sets `runSpacing: 8`. AUDIT measures: Listo 12 dp above Cancelar; «Descartar» 12 dp above «Conservar»; chips 8 dp apart; no gap entry for «Sin guardar · 1» in `calendar/agenda.pending-captures`. The 8 dp above «Ver lo que dije» was replaced by P198's 16 dp (UX-1626), so it isn't counted against this finding. |
| UX-1313 | fixed | `voice_task_screen.dart:2244` sets `maintainHintSize: false`. Render `sheet.typing.es.light.2x`: «Llamar al» is the first line, under the field's top border, and the field fits its 4 lines. `sheet.error-offline.es.light.2x`: the first typed line shows directly under the banner. |
| UX-1321 | fixed | (a) `voice_task_screen.dart:2222-2223`: `Semantics(label: captureYourWords)`. (b) `capture_command_cards.dart:718` and `:818` add `Semantics(button: true)`. (c) `:947` and `:1227` use `commandDontChangeAny` and `commandDontDeleteAny` (ES «No cambiar ninguna» / «No eliminar ninguna»; CA «No en canviïs cap» / «No en suprimeixis cap»). AUDIT `commands/cards · change-which`: the ✕ reads «No cambiar ninguna», and the pick rows read as buttons. Device check still open: what TalkBack actually says. |
| UX-1314 | fixed | `capture_command_cards.dart:290-362`: the labels get their room from a LayoutBuilder (card width minus 52 dp) and wrap to 2 lines. `:547`: the chips start at the card's edge (the old 34 dp inset is gone). Renders `cards.project-question.es.light.2x`: «Crear «Mates»» and «Otro proyecto…» show whole; `ca.light.2x`: «Un altre projecte…» shows whole on 2 lines. AUDIT lists no cut text. |
| UX-1315 | fixed | `capture_command_cards.dart:185-199`: `similarProjects` adds the 4-letter folded-prefix rule, ranked after prefix and contains matches, and keeps at most 3. `:277-286`: the server's `candidates` come first when any of them is on the phone. `capture_command.dart`: `_candidates` keeps at most 3 ids, and they're stored and read back. Render `cards.project-question.es.light.1x` offers «Matemáticas» and «Matemáticas II». The name `project_candidates` matches `Backend/docs/VOICE_COMMANDS.md:173`. |
| UX-1307 | fixed | `capture_problem.dart:94-101`: Retry-After of 120 s or less → `tooFast`; no Retry-After → `unavailable`; otherwise `allowance`. The copy matches the brief in all three languages. Device check still open: seven dictations within a minute on staging. See R1A-1 for the recorded-audio path. |
| UX-1318 | fixed | (a) `voice_task_screen.dart:3492-3500`: a request error goes through `CaptureProblem.from`, and the generic `failed` maps to `saveFailed`. (b)–(e): the copy matches the brief. (f) `captureUnsupportedKind` and `captureSpeechBusy` are gone from all three ARBs and fall through to `captureFailed` (`capture_messages.dart:57`). (g) `:2282`: `timeZoneName(_zone)`, now shared in `region.dart`. See R1A-2. |
| UX-1317 | fixed | `captures_screen.dart:27-51`: the subtitle is `pastMoment` (`region.dart:36-47`), then «Nota», then `captureDraftSummary` or the used-up line. `captureResumeHelp` is removed. Render `settings/pending-captures.three.es.light.2x`: «Hoy, 08:41», «Hoy, 06:41» and «Ayer, 09:41 · 2 sin añadir», each at most 2 lines. The clock reads «09:41» because the app's 24-hour helper pads the hour, which is consistent with the rest of the app. The new key `yesterday` («Ayer» / «Ahir») is needed and is in all three ARBs. |

## Regressions

**R1A-1 · S2 · The daily-limit message names a button that recorded audio doesn't have**
- Where: `App/lib/screens/voice_task_screen.dart:2119-2120` and `:2182-2196`, with `captureAllowance` in the ARBs.
- What happens: «Toca Guardar como tarea» relies on `saveAsWritten`, which needs `_hasWords`. When the sheet sends recorded audio (`_nativeMode` false: no on-device recognizer, or the online-speech preference) and the server refuses with the daily limit, there are no words. The sheet then shows only «Reintentar», which keeps failing until tomorrow, and Cancelar.
- The moment: "It says tap Save as a task. Where is it?"
- The old copy («Escribe la tarea…») was just as wrong in this case, but the new copy promises a specific button.
- Fix: when `allowance` comes with no words (`recorded && !_hasWords`), show copy that matches the buttons on screen. EN “You’ve reached today’s dictation limit. Your recording is kept; try again tomorrow.” / ES «Has llegado al límite de dictados de hoy. Tu grabación se conserva; inténtalo mañana.» / CA «Has arribat al límit de dictats d’avui. La gravació es conserva; torna-ho a provar demà.» Also hide «Reintentar» in this state, since it can't work today.
- Evidence: verified in code.

**R1A-2 · S1 · Save errors now speak of "the assistant" or "your dictations"**
- Where: `voice_task_screen.dart:3492-3500`, in `_apply`.
- What happens: every `ApiException` now goes through `CaptureProblem.from`, so a failed save reads as follows:
  - a 5xx, a timeout or an unreachable server: «No he podido contactar con el asistente…»;
  - a 403: «Esta cuenta no puede convertir tus palabras en tareas…»;
  - a 413: «Esta grabación es demasiado larga…»;
  - a 422: «No te he entendido…»;
  - a 429: the dictation limit.

  None of these describes saving tasks. Before, every one of them read `captureSaveFailed`.
- Fix: in `_apply`, keep only `offline` (and, if wanted, `timeout`) from `CaptureProblem.from`, and map everything else to `saveFailed`.
- Evidence: verified in code. The brief said "use `CaptureProblem.from(error)` for request errors", and the intent was the offline line.

## Observations (not counted)

- `commands/cards.project-question.ca.light.2x`: P168's reveal (`ensureVisible`, alignment 1) scrolls the card so the question's first line («Vols crear el») sits under the sticky «2 coses per afegir» header. AUDIT's «No creïs Mates» at 48 × 4 dp and ES's 48 × 44 dp come from the same scroll position. The 2-line chips from P172 make the card a little taller. This is the cost already accepted in verify-b1-r1-A, and isn't counted here.
- `captureTooLarge` and `captureIncompleteAudio` say «Descártala», but the sheet's button is «Cancelar», which then asks with «Descartar». It's reachable in two taps, and it's the plan's copy.
- `pending-captures.three`: AUDIT's 0 dp row gaps measure the ListTiles inside 12 dp of AppSurface padding. The render shows the cards clearly apart. This isn't a change from this batch.
