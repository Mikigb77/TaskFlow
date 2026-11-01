## UX review — D · First run, sign-in, settings, notifications, native surfaces and theme — whole-app run 2026-10-28-app — 2026-10-31

**Verdict:** Ship after fixes. Sign-in, Ajustes, Pro, the delete page and the native surfaces hold on current renders and on the emulator. Two reminder paths fail without telling anyone:
- After a «No permitir», allowing notifications on Android's page still leaves reminders off, with no sign (UX-2601).
- A reader taps «Completar» on a reminder. The next sync undoes it and leaves an English «(offline copy)» task behind (UX-2602).

**Evidence used:**
- **UX previews** at `6281e3d`, rendered 2026-10-28 17:56 to 2026-10-29 08:56.
  - `find App/lib App/assets App/android/app/src/main/res App/ios/Runner -newer <render>` lists nothing.
  - HEAD moved from `ad25079` to `bc80025` during this review, with no app file changed. `bc80025` is D9's server half.
  - AUDIT.md was read with the renders. That's widget-test evidence.
- **Device captures** from the TaskFlow_Review emulator (API 36, Pixel 4 profile, 393 dp, a few at 360 dp), 2026-10-29 09:13–10:08.
  - The APK was built at `30c8ce0`, which has the app code of `6281e3d`. The uiautomator trees are in `device/a11y/`.
  - This is emulator evidence, not a phone.
- **Code**, for what neither shows: notification actions, sync, resume paths.
- **guidelines.md:** §0, §18 and §20, plus CO, SC, PL, RE, ON, TA, NO, UN, FO, AC, OL, SU, LO and PR.
- **Site copy**, for the Pro check: `../TaskFlowWeb/src/content/site/{es,en,ca}.ts` (FAQ, `es.ts:94`).

**Walked.** Personas: N newcomer, D daily user, AT TalkBack, low vision or tremor.
1. **Install → first screen** (N, AT): launcher icon «TaskFlow», then the logo with a spinner, then sign-in.
2. **Google** (N): 3 actions to Calendar — the icon, «Continuar con Google», the account.
3. **Email sign-in** (N): «Continuar con mi correo» opens the form in place. A wrong password or an unknown account ends on «Crear una cuenta con este correo».
4. **Sign-up with the email code** (N): about 8 actions plus a trip to the inbox.
5. **Recovery** (N): email → «Enviar código» → code and new password → back to sign-in. 5 actions plus the inbox.
6. **Ajustes, 6 rows** (N, D, AT): Recordatorios, Idioma, Apariencia, Cuenta, TaskFlow Pro, Otros ajustes.
7. **Turning reminders on** (N): first dated save → «¿Quieres un recordatorio antes?» → «Sí» → Android's dialog. On Android 14+, add the «Alarmas y recordatorios» sheet, Android's page and the way back. 2–5 actions. Then the refusal path.
8. **A reminder arrives** (D, emulator): expand → «Completar» or «Posponer 10 min» → «Completada: …». Tapping the reminder opens the task. The same as a reader in a shared project, from code.
9. **Cuenta** (N): name, Vincular Google, sync, sign out. Eliminar cuenta, checked for regressions only.
10. **TaskFlow Pro** (N; SU-8 walk): free, used up, file space full (→ Tareas con archivos), active, complimentary, store error. Also reached from «A tu manera»'s Pro badge.
11. **Otros ajustes** (N): Hora y región, Voz, Calendarios del teléfono (allowed, refused, blocked), Botón de dictar, Exportar e importar, Licencias, Privacidad, Términos.
12. **Native** (N): icon, shortcuts, widget and share toasts in ES, CA and EN at 1.0 and 2.0, plus the iOS strings.
13. **Theme** (AT): light and dark; 1×, 1.3× and 2×; 360 and 393 dp; ES, CA and EN.

**Numbers:**
- **Sign-in's first screen:** 5 tap targets in a release build and 1 decision (Google or email). Unchanged.
- **Install → Calendar:** 3 actions with Google; about 8 actions plus the inbox for an email sign-up.
- **Ajustes:** 11 tap targets, counting the avatar and the tabs.
- **The refusal path today:** «Sí» → «No permitir» → «Permitir avisos» → Android's switch → back, and reminders are still off.
  - It costs 3 more taps, if the person ever finds Ajustes › Recordatorios › the switch. After UX-2601: 0.
  - Recordatorios with the switch off and notifications blocked shows the switch and a filled «Permitir avisos». After UX-2601: the switch alone.
- **A reader's «Completar»:** 1 tap, then apparent success, then undone at the next sync, plus 1 duplicate task. For a repeating «Todos» task the copy rings every week. After UX-2602: no «Completar».
- **The Pro screen** names 2 of the site's 3 Pro benefits → 3 (UX-2603).
- **Calendarios del teléfono**, after connecting: 23 words of caveats above the list → 0 (UX-2610).
- **New findings:** S4 0 · S3 2 · S2 4 · S1 5. UX-2032 (decided: D9 (b)) is planned as a package.

### Findings (most severe first)

**UX-2601 · Severity 3 · Allowing notifications in Android leaves reminders off**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:242-250`: a refusal shows «El teléfono no deja que TaskFlow te avise.» with «Permitir avisos», and returns before `enabled: true` is written (`:254-268`).
  - `App/lib/widgets/reminder_ask_sheet.dart:175-194`: the question is marked as asked whatever the answer, so it never comes back.
  - `App/lib/screens/notification_settings_screen.dart:54-60`: on return, the screen only re-reads.
  - Same file, `:206-246` and `:271-280`: with the switch off, «Permitir avisos» shows as a filled button next to it.
  - State: first dated save → «Sí, recuérdamelo» → Android's «No permitir». Or Recordatorios with the switch off and notifications blocked.
- **The moment:** "Le di a «Permitir avisos», encendí el interruptor de Android… ¿por qué no me avisó?"
- **What happens:**
  - «Sí», then «No permitir» — a reflex tap is common — shows the message with «Permitir avisos».
  - That opens TaskFlow's notifications page in Android. The person switches notifications on and comes back.
  - Nothing finishes the job:
    - reminders stay off: `enabled` is false and there's no 9:00 default;
    - «Listo. Recordatorios activados.» never shows;
    - the question is never asked again;
    - a date-only task's line reads «Recordatorio: Desactivado».
  - In Ajustes › Recordatorios the same filled «Permitir avisos» sits next to the off switch. Using it leaves the switch off too.
  - The person has said yes twice and gets nothing. They find out when a reminder doesn't come.
- **Why it fails:**
  - ON-7: a denial is not a dead end (Android Permissions; Rosala 2019).
  - TA-6: reminders fire on time, or the app says why not.
  - SC-11: end on visible success (Kahneman 1993). This is a gulf of evaluation (Norman 2013).
  - OL-2: older users blame themselves (Nielsen 2013).
- **Fix** (no new copy):
  - **Finish the request on return.** When «Permitir avisos» — the message's, or the switch's own fallback to it — sends the person to Android, remember that reminders were asked for.
    - On return, if notifications are now allowed, finish exactly as `turnOnReminders` does:
      - reminders on;
      - 9:00 for tasks without a time, unless a time was already chosen;
      - the alerts set;
      - «Listo. Recordatorios activados.»;
      - then «Alarmas y recordatorios» on Android 14+.
    - Forget the request once it's done, or refused again.
  - **One way in on Recordatorios.** While the switch is off, drop the «El teléfono no deja…» line and its «Permitir avisos». The switch is the one way in: its flow asks Android, or offers the page.
    - With the switch on and the phone blocking, keep today's line and button (UX-1606).
- **Verify:**
  - Widget test: refusal → the action → the capability is now allowed → resume. Preferences are on with 540, and the confirmation shows.
  - Widget test: Recordatorios with the switch off and permission off shows the switch alone.
  - Emulator lane: question → «Sí» → «No permitir» → «Permitir avisos» → switch on → back. Ajustes reads «Activados · 10 minutos antes».
- **Evidence:** verified in code. Emulator captures of the current code show:
  - the refusal message with «Permitir avisos», still there after 4 s (`device/permission-notifications.denied-after-4s.es.light.1.0.png`);
  - the off switch next to the filled «Permitir avisos» (`device/permission-notifications.settings-off.es.light.1.0.png`).

  The return after allowing wasn't captured.

**UX-2602 · Severity 3 · A reader's «Completar» on a reminder is undone, plus an English copy**
- **Where:**
  - `App/lib/services/notification_service.dart:65-71`: «Completar» on every task reminder.
  - `App/lib/services/task_database.dart:377-425` and `App/lib/models/task.dart:66-70`: a «Todos» task rings for every member, readers included.
  - `App/lib/services/reminder_engine.dart:749-798`: the tap marks the task done on the phone and posts «Completada: …» with Deshacer.
  - `App/lib/repositories/cloud_task_repository.dart:154-171`: sync turns a reader's pending change into a personal copy and restores the shared task.
  - `App/lib/services/task_database.dart:735-786`: the copy is titled «… (offline copy)» in English (`:770`) and uploaded.
  - In the app itself, a reader's row has no circle to tick (`App/lib/widgets/task_tile.dart:73`, `:275`).
- **The moment:** "Ya saqué la basura y le di a Completar. ¿Por qué vuelve a salir pendiente… y qué es esto de «offline copy»?"
- **What happens:**
  - A «lector» in «Familia López» gets «Sacar la basura · Hoy a las 20:00 · en 10 min», with «Completar».
  - The tap shows «Completada: Sacar la basura» with Deshacer.
  - At the next sync the server refuses the change, so the app:
    - puts the shared task back as not done;
    - keeps the tap as a new personal task, «Sacar la basura (offline copy)»;
    - shows in Cuenta «Este proyecto ahora es de solo lectura. Tu cambio pendiente se ha conservado como copia personal.»
  - For a repeating task the copy keeps repeating. Next Monday it appears in the reader's Calendar and rings on its own, beside the shared task.
- **Why it fails:**
  - The reminder offers an action the person isn't allowed to take, and that the app itself never offers: the row has no circle. That breaks consistency and error prevention (Nielsen 1994).
  - UN-10: honest about sync (Android Offline-first).
  - SH-1: viewers need no training (Neustaedter 2006).
  - OL-2: never imply fault.
  - The M lens: no hard-coded English.
  - D9 keeps everything except their own reminders read-only for readers (DECISIONS 2026-10-31).
- **Fix** (no new copy):
  - **No «Completar» where the person can't complete.** A reminder for a task this account can't change — its project's role is «viewer» — has no «Completar».
    - The single reminder keeps «Posponer 10 min».
    - A plan notice has no action; tapping it opens the task.
    - Carry the role from `reminderTasks` into the planned reminder. On iOS, use a category without «complete».
  - **Refuse it in the engine too.** `ReminderEngine.action('complete')` does nothing for such a task, since an older notification may still carry the button: no `isCompleted`, no pending change, nothing to copy.
- **Verify:**
  - Unit test: a viewer project's «Todos» task plans a reminder whose only Android action is «snooze». A plan notice has none.
  - Unit test: `action(id, 'complete')` on that reminder returns false and leaves the row unchanged and not pending.
  - Emulator lane, if a reader account can be set up: the reminder shows only «Posponer 10 min».
- **Evidence:** verified in code. Not captured: the lane's account owns its projects.

**UX-2603 · Severity 2 · Pro screen names two of Pro's three benefits**
- **Where:**
  - `App/lib/screens/subscription_screen.dart:116-121`, the string `billingIntro` (`app_es.arb:1092`, `app_en.arb:1981`, `app_ca.arb:796`).
  - The site's FAQ: `../TaskFlowWeb/src/content/site/es.ts:94` (`en.ts:94`, `ca.ts:100`).
  - Renders `settings/pro.free.es.light.1x` and `pro.free.ca.light.2x`.
- **The moment:** "¿Y qué me da Pro, aparte de dictar? En la web decía algo de escribir frases…"
- **What happens:**
  - The screen's first line is «Dictados sin límite y espacio para todos tus archivos.»
  - The site lists two more benefits, and so does the paywall the owner fills in: typed sentences turned into tasks, and reminders in your own words.
  - A free newcomer who types in the capture sheet and gets the form can't learn why here.
  - «A tu manera» appears only when the screen is opened from its badge.
- **Why it fails:**
  - SU-2: say what Pro gives and what stays free (Play Subscriptions).
  - SC-9: the same thing in the same words on every surface (WCAG 3.2.4).
  - SU-8: walk every upsell as the newcomer.
- **Fix:** three short lines instead of one sentence, in the site's words. The first keeps the decided "sin límite" wording (DECISIONS 2026-10-13).
  - ES: «Dictados y espacio para archivos sin límite» · «Tus frases escritas se convierten en tareas» · «Pide los recordatorios con tus palabras»
  - EN: "Unlimited dictation and file space" · "Sentences you type become tasks" · "Ask for reminders in your own words"
  - CA: «Dictats i espai per a fitxers sense límit» · «Les frases que escrius es converteixen en tasques» · «Demana els recordatoris amb les teves paraules»
  - Opened from «A tu manera» (`ProReason.reminderPlans`), the heading already says the third, so leave it out of the list there.
- **Verify:**
  - Renders `settings/pro.free` (ES 1× and 2×, CA 2×) show three lines.
  - Render `reminders/sheet.pro-screen` ES 1× doesn't repeat the reason.
  - The ARB catalog test covers the three languages.
- **Evidence:** seen in a current render; site copy read in the website repo.

**UX-2604 · Severity 2 · «A tu manera» never says the words go to Google's AI**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:646-737`: the field, «Dictarlo» and «Un momento…». Its only helper is the example (`:667-673`).
  - `App/lib/screens/voice_settings_screen.dart:196-205`: the string `capturePrivacy` (`app_es.arb:307`, `app_en.arb:527`, `app_ca.arb:286`).
  - Renders `reminders/sheet.your-way.es.light.1x` and `settings/voice.on-phone.es.light.1x`.
- **The moment:** "¿Esto que escribo aquí lo lee alguien? Solo dice «Un momento…»."
- **What happens:**
  - With Pro, words typed or said in «A tu manera» go to the server's AI, as a dictation does.
  - The sheet says nothing about it.
  - Ajustes › Voz's note lists only «Para añadir, buscar o cambiar tareas».
  - The privacy policy now says reminder words go there too.
- **Why it fails:**
  - PR-1: explain at the moment of use, with the same text findable in Settings (GDPR arts. 12–13; WP260 2018).
  - PR-5 and PR-7: nobody "left in the dark" (EDPB 03/2022).
- **Fix:**
  - **In the sheet:** under the «A tu manera» field, reuse the capture sheet's line `capturePrivacyLine`:
    - ES «Tus palabras van por internet. Más en Ajustes.»
    - EN "Your words go online. More in Settings."
    - CA «Les paraules van per internet. Més a Configuració.»
  - **In Ajustes › Voz,** the note names the reminders:
    - ES «…Para añadir, buscar o cambiar tareas, o leer los recordatorios «A tu manera», tus palabras van por internet a la IA de Google. …»
    - EN "…To add, find or change tasks, or to read “Your way” reminders, your words go over the internet to Google’s AI. …"
    - CA «…Per afegir, cercar o canviar tasques, o llegir els recordatoris «A la teva manera», les teves paraules van per internet a la IA de Google. …»
- **Verify:**
  - Renders `reminders/sheet.your-way` (ES 1× and 2×, CA 2×): the line sits under the field, and «Listo» stays in view.
  - Render `settings/voice` ES 1× shows the new note.
- **Evidence:** verified in code and in current renders.

**UX-2605 · Severity 2 · Ajustes' Pro row says «compras y facturación», not your plan**
- **Where:**
  - `App/lib/screens/settings_screen.dart:127-133`, the string `billingSettingsHelp` (`app_es.arb:1091`, `app_en.arb:1980`, `app_ca.arb:795`).
  - Renders `settings/settings-tab.normal.*`; device capture `screen-settings.list.es.light.1.0` (a free account).
- **The moment:** "¿Cuántos dictados gratis me quedan? Aquí solo pone «Suscripción, compras y facturación»… no quiero pagar nada."
- **What happens:**
  - Every other row shows its current value: «Activados · 10 minutos antes», «Español», «Claro», the email. The Pro row shows billing words.
  - A free account's one useful number — dictations left this month — isn't in Ajustes.
  - «compras y facturación» frames the row as payment.
  - At 2× it takes 2–3 lines and pushes «Otros ajustes» below the fold.
- **Why it fails:**
  - SC-9: one pattern per list — the value under the name.
  - CO-5 and OL-7: cut words that don't help (Sweller 1988).
  - SU-2: say the free path exists.
- **Fix:** the subtitle is the plan's state, from strings that already exist; `billingSettingsHelp` goes.
  - Pro or complimentary: `billingStatus(active)` — ES «Pro está activo», EN "Pro is active", CA «Pro està actiu».
  - Free, with the count known: `freeVoiceLeft` — ES «Te quedan 4 dictados gratis este mes», or «Ya no te quedan dictados gratis este mes» at 0. EN and CA use their existing forms.
  - Not known yet: no subtitle, as Recordatorios does while loading.
- **Verify:** settings-tab renders for free (4 left and 0 left) and Pro, in ES 1× and 2× and CA 2×. The Pro row reads the plan.
- **Evidence:** seen in current renders and in an emulator capture.

**UX-2606 · Severity 2 · First screen says «Inicia sesión» to people with no account**
- **Where:**
  - `App/lib/screens/login_screen.dart:564-570`: the heading is `signInHeading` whenever the person isn't creating an account or recovering, so the folded first screen gets it too (`:151`).
  - Strings: `app_es.arb:422`, `app_en.arb:840`, `app_ca.arb:401`.
  - Renders `auth/sign-in.sign-in.*`; device capture `first-run.sign-in.es.light.1.0`.
- **The moment:** "«Inicia sesión»… pero yo no tengo cuenta todavía. ¿Dónde me apunto?"
- **What happens:**
  - Since D2 the first screen holds only «Continuar con Google» and «Continuar con mi correo», for new and returning people alike.
  - «Crear una cuenta» appears only after «Continuar con mi correo».
  - The heading still names one of the two: sign in.
  - A newcomer without Google goes to the email form and may type a new password into sign-in. They get «No encontramos esa cuenta…» before «Crear una cuenta con este correo». The heading set up that wrong turn.
- **Why it fails:**
  - CO-1: the heading names the screen's one job (Spencer 2000; COGA 2021).
  - ON-9: give before you take (Budiu 2014).
  - Jakob's law: combined entry screens name both modes ("Log in or sign up").
- **Fix:** while the email form is folded, the heading reads:
  - ES «Entra o crea tu cuenta»
  - EN "Sign in or sign up"
  - CA «Entra o crea el teu compte» (as `registerHeading`'s «Crea el teu compte»)

  The open sign-in form keeps «Inicia sesión»; create and recovery keep theirs. TalkBack names the screen with the new heading.
- **Verify:** renders `auth/sign-in.sign-in` (ES 1× and 2×, CA 2×, EN 2×) show the heading on 2 lines or fewer at its 1.2× cap on 360 dp. `email-open` still reads «Inicia sesión».
- **Evidence:** seen in current renders and in an emulator capture. The wrong turn is inferred.

**UX-2607 · Severity 1 · Pro screen copy: a literal ES line, a split unit, a promised trial**
- **Where:** `freeVoiceStatus` (`app_es.arb:1211`); `storageUsage` (`app_es.arb:1220`, `app_en.arb:2348`, `app_ca.arb:924`); `billingRenewalHelp` (`app_es.arb:1101`). Renders `settings/pro.free.es.light.1x` and `.2x`.
- **The moment:** "«Más el 1 nov.»… ¿más qué?"
- **What happens:**
  1. ES «…este mes. Más el 1 nov.» reads as "plus the 1st of November". CA says «El dia … en tindràs més», and the used-up notice says «El 1 nov tendrás 10 dictados más».
  2. At 2× «Archivos: 42 de 100 / MB usados» breaks the number from its unit.
  3. ES «Revisa … las condiciones de prueba» says there is a trial. EN says "any trial terms", CA «les condicions de qualsevol prova».
- **Why it fails:**
  - The G lens: each language reads naturally.
  - Recurring problem: no-break spaces must bind the whole phrase.
  - SU-3: a trial is spelled out, never implied.
- **Fix:**
  1. ES «Dictados gratis: {…} de {limit} este mes. El {date} tendrás más.»
  2. A U+00A0 between {limit} and «MB», and between {used} and its word, in ES, EN and CA.
  3. ES «…y las condiciones de cualquier prueba antes de confirmar.»
- **Verify:** render `settings/pro.free.es.light.2x` keeps «100 MB» on one line; the catalog test covers the three strings.
- **Evidence:** seen in current renders.

**UX-2608 · Severity 1 · Two-line button labels sit left and touch the edges at 2×**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:286-289` (the exact-alarms sheet);
  - `App/lib/screens/notification_settings_screen.dart:229-244`;
  - `App/lib/screens/subscription_screen.dart:258-265`;
  - `App/lib/screens/device_calendars_screen.dart:102-108`;
  - `App/lib/screens/data_transfer_screen.dart:197-204`;
  - the theme: `App/lib/theme/app_theme.dart:95-97`.
  - Renders `settings/pro.free.ca.light.2x` («Mostra la / subscripció») and `first-run/reminder-question.exact-alarms.es.light.2x`; device capture `permission-alarms.app-sheet.es.light.2.0`.
- **The moment** (low vision, 2×): "Las letras del botón se salen por los bordes."
- **What happens:**
  - These filled buttons have no vertical padding and no centring.
  - At 2× a wrapped label starts at the left, and its lines touch the button's top and bottom edges.
  - Sign-in and «Confirma tu correo» pad their labels by 12 dp and centre them.
- **Why it fails:**
  - The F lens: the same component looks the same everywhere.
  - AC-3: works at 200% text (WCAG 1.4.4).
- **Fix:** the theme's FilledButton gets 12 dp of vertical padding, and these labels get `textAlign: TextAlign.center`. No copy change.
- **Verify:** in those renders the lines are centred, with at least 8 dp between the text and the button's edge.
- **Evidence:** seen in current renders and in an emulator capture.

**UX-2609 · Severity 1 · Language sheet stays open while reminders are rewritten**
- **Where:** `App/lib/widgets/language_selector.dart:57-67`. The sheet awaits `TaskReminders.refreshLanguage()` — which waits for any reminder work queued before it — and only then closes. Every row is disabled meanwhile.
- **The moment:** "Ya está en catalán… ¿por qué no se cierra? Toco y no hace nada."
- **What happens:**
  - The app switches language at once.
  - Then the sheet waits for every reminder to be rewritten and rescheduled before it closes. Its rows are greyed, with no sign of work.
  - With many reminders, or behind a sync, that can take seconds. A reminders refresh took up to about 8 s on the emulator (run 2026-10-19-app, review D).
- **Why it fails:**
  - UN-1 and PE-1: every tap answers at once (Nielsen 1993).
  - Recurring problem: background work awaited in the tap path.
- **Fix:** close the sheet as soon as the language is saved. `AppLanguageBridge.apply` and `refreshLanguage()` run afterwards, not awaited; they queue and record their own errors.
- **Verify:** widget test with a `refreshLanguage` that never completes — the sheet closes after the choice.
- **Evidence:** verified in code. The wait is inferred and needs a device check.

**UX-2610 · Severity 1 · Phone calendars: 23 words of caveats; addresses split mid-word**
- **Where:**
  - `App/lib/screens/device_calendars_screen.dart:111-112`, the string `calendarChooseHelp` (`app_es.arb:101`, `app_en.arb:175`, `app_ca.arb:80`).
  - Same file, `:125-127`: the account line, a plain `Text`.
  - Render `first-run/phone-calendars.allowed.es.light.2x`; device capture `permission-calendar.allowed.es.light.2.0`.
- **The moment:** "«Los eventos de día completo conservan sus fechas originales»… ¿tengo que hacer algo?"
- **What happens:**
  - Right after «Conectado. Los eventos se ven en Calendario.» comes «Selecciona hasta 50 calendarios. Las horas siguen la zona de tu dispositivo; los eventos de día completo conservan sus fechas originales.» That's 7 lines at 2×, between «ELEGIR CALENDARIOS» and the checkboxes.
  - At 2× the account under each calendar breaks as «maria.lopez@exam / ple.com».
- **Why it fails:**
  - CO-5 and SC-2: no paragraphs where people decide (Sweller 1988; Nielsen 1997).
  - OL-7: fewer words.
  - AC-3, and UX-1618's rule for addresses.
- **Fix:**
  - Remove `calendarChooseHelp` from the screen and from the three ARB files. The heading and the ticked boxes say it, and `calendarTruncated` covers the rare overflow.
  - Show the account with `breakableAddress`, as Cuenta does.
- **Verify:** render `first-run/phone-calendars.allowed` (ES 1× and 2×) shows no paragraph, and the address breaks after «@».
- **Evidence:** seen in a current render and in an emulator capture.

**UX-2611 · Severity 1 · Recovery's two links touch**
- **Where:** `App/lib/screens/login_screen.dart:1008-1024`. AUDIT, `auth/sign-in · recovery`: «Ya tengo un código» sits 0 dp above «Volver a iniciar sesión».
- **The moment** (tremor): "Quería volver y me abrió lo del código."
- **What happens:** two full-width, 48 dp text buttons share an edge.
- **Why it fails:** RE-3: spaced targets for older hands (Kobayashi 2011; Jin 2007).
- **Fix:** 8 dp between them, as «Confirma tu correo» does (`verify_email_screen.dart:729-730`).
- **Verify:** in AUDIT's recovery section, the gap is 8 dp or more.
- **Evidence:** measured (AUDIT, widget test).

### Decided — planned as a package

**UX-2032 · Severity 1 (in the ledger) · D9 (b): a reader chooses their own reminders — the app half**
- **Where:**
  - `App/lib/screens/task_detail_screen.dart:375-400`: `onChanged: !canEdit ? null`.
  - `App/lib/widgets/reminder_control.dart:568-592`: the line's tap is `onChanged`.
  - `App/lib/services/task_database.dart:501-513`: `updateTask` → `validateList` refuses any change in a viewer project (`:313-329`).
  - `App/lib/repositories/cloud_task_repository.dart:154-171`: a reader's pending change becomes a personal «(offline copy)».
  - The server half is done: `Backend/core/task_views.py:51-73` (`bc80025`) saves a reader's PUT that changes only their own reminders, even at a stale version, before any 409.
- **What to build:**
  - **The line opens the choices.** On a task that rings here (`reminderRingsHere`), in a project this account reads, the reminder line gets its tap and opens the same choices. «Estos avisos son solo para ti.» sits on top, since it's a shared task.
  - **Saving.** A choice saves only `reminderMinutes`, `reminderTime` and `reminderPlan`, through a reminder-only update that skips the read-only refusal.
  - **Sync.** It's sent as a normal PUT, never as a copy. On a 409, take the server's task: the reminders are already saved there.
  - **Nothing else changes for readers:** no circle to tick, no editing, no «Cambiar fecha», and no «Completar» on their reminders (UX-2602).
  - No new copy.
- **Verify:**
  - Widget test, a reader with a «Todos» task: the reminder line has a tap, and picking «1 hora antes» saves. Any other field is still refused.
  - Repository test: a reader's reminder-only pending row is sent as a PUT, not copied. A 409 leaves no copy.
  - Emulator, with a reader account: choose «Desactivado» on one task; no notification comes.
- **Evidence:** verified in the app code and in the server commit.

### Ledger items with new evidence (not new findings)
- **UX-411** (device-check): on the emulator, after «Completar» the line «Completada: Llamar al denti…» sits collapsed in TaskFlow's group. Its Deshacer shows only once that row's own chevron is opened (`device/notification.after-complete.es.light.1.0.png`).
  - Android draws grouped rows collapsed, and unticking the task in the app is the second way back, so no app change is proposed.
  - For the phone check: Deshacer needs the row expanded.
- **UX-1603 / U14:** the emulator shows the folded first screen with Google's G logo (`device/first-run.sign-in.es.light.1.0.png`). The 1× preview's missing logo is the known harness quirk.
- **UX-406:** the light/dark toggle is gone from every app bar and from sign-in (`custom_app_bar.dart:61-71`; renders). It lives only in Ajustes › Apariencia.

### Keep
- **Sign-in's folded first screen:** Google first, 5 targets, and «Continuar con mi correo» opening the form in place (emulator).
- **Reminder notifications:** absolute times («Hoy a las 9:50 · en 10 min»), «Completar» and «Posponer 10 min», tapping opens the task, and Android groups them (emulator, ES and CA).
- **Recordatorios:** one plain line and one button per problem. The «Alarmas y recordatorios» round trip ends on «Listo. Recordatorios activados.» (emulator).
- **Theme contrast holds** (computed from `app_theme.dart`):
  - secondary text: 4.92:1 on light, 7.97:1 or more on dark;
  - field and button borders: 3.55–5.4:1;
  - the Pro card: 7.27:1 light, 9.16:1 dark.
- **The used-up notice** says what still works («Puedes seguir creando tareas a mano, sin límite») and when more dictations come.

### Progress against UX_REVIEW.md (U1–U14)
- **U12:** holds. The question comes after the first dated save, before Android's dialog (emulator). Its refusal path is UX-2601.
- **U14 (option 1):** holds. UX-2606 is about the heading's words.
- **U11:** holds on area D's default path. «Sincronizar ahora» stays in Cuenta, off the default path.
- **U10 and U13:** still decisions. Ajustes has 11 tap targets with the tabs and the avatar, and the avatar duplicates «Cuenta».

### Questions for the owner
None new. UX-2602 follows D9: readers still can't complete tasks.

### Cross-slice notes
- **B1:** WD34. Calendar's last tick of the day shows «Todo listo. Respira.» / "All clear. Take a breath." / «Tot fet. Respira.» (the site's `completionTitle`). One line, with reduced motion respected.
- **B2:** UX-2032's line is in `task_detail_screen.dart:375`; UX-2604's line goes in `reminder_plan_sheet.dart:667`.
- **C (sync):**
  - `task_database.dart:770` writes «(offline copy)» in English into every conflict copy's title: assignment changed, read-only, task conflict.
  - `syncProblem(readOnly)` tells someone who was always a reader that the project «ahora es de solo lectura».
- **Main session (server):** `Backend/core/invitation_email.py:18` links the bare `https://taskflow.garbar.tech/` in all three languages.
  - The site picks the browser's language (`../TaskFlowWeb/src/proxy.ts`), so a Catalan invitation can open the Spanish or English site.
  - Link `/es/` or `/ca/`, as `site_links.dart` does.
  - Partly real; the cause is server-side.

### Memory notes
- **Area D map (2026-10-31):**
  - Root app bar: the brand, announced as the tab's name; Activity, only with an active shared project; the avatar. The light/dark toggle appears only in Ajustes › Apariencia. Sign-in's header has only the language button.
  - Ajustes, 6 rows: Recordatorios, Idioma, Apariencia, Cuenta, TaskFlow Pro, Otros ajustes.
  - Otros ajustes: Hora y región, Voz, Calendarios del teléfono, Botón de dictar en la pantalla de inicio, Exportar e importar, Licencias, Privacidad, Términos, the version line.
  - Cuenta: the name row; Vincular Google (password accounts); «Guardado en tu cuenta» with «Sincronizar ahora»; «Cerrar sesión», confirmed first; a divider; «Eliminar cuenta».
- **New recurring problem:** an action outside the app — a notification action, the widget, a shortcut — skips the role rules the in-app control applies. Example: a reader's «Completar» (UX-2602). Check every such action against the in-app gate.
- **New recurring problem:** a detour to Android's settings never finishes the request that started it. Example: reminders stay off after allowing (UX-2601). When the app sends the person to a system page, the original request must complete on return.
- **Facts:**
  - `cloud_task_repository.dart:154` turns any pending change in a reader's project into an English «(offline copy)» personal task, and `updateTask` → `validateList` refuses viewer projects.
  - Server `bc80025` accepts a reader's reminders-only PUT.
  - Any new path a reader can write must bypass both.
- **Pattern:** FilledButton labels that can wrap get 12 dp vertical padding and centred text, as sign-in and «Confirma tu correo» do.
- **Reference:** the site's copy is in `../TaskFlowWeb/src/content/site/{es,en,ca}.ts` (Pro benefits in the FAQ, `es.ts:94`). The bare address redirects by Accept-Language in `src/proxy.ts`.
