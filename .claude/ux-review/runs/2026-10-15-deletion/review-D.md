## UX review — D · Delete my account (run 2026-10-15-deletion) — 2026-10-15

**Verdict:** Ship after fixes. Nothing can be deleted by accident: it takes the password or a fresh Google sign-in, plus the server's plan check. Errors never lose what was typed, and the ending is clear. But a forgotten password is a dead end, "save a copy" silently leaves files out, and several lines can mislead a newcomer just before a tap that can't be undone.

**How I looked:**
- **Code and the widget tests only.** I didn't run Flutter: this is inside the UX loop.
- **No preview renders the delete page or the «Tu cuenta se ha eliminado.» notice.** `App/artifacts/auth/login-light.png` (23:02:24, after the 23:02:03 code change) shows plain sign-in only.
- **Scope:** `git diff refs/ux-review/last` (96404f1 → e1df0a7) for:
  - `account_screen.dart`, `delete_account_screen.dart` (new), `login_screen.dart`, `main.dart`;
  - `auth_provider.dart`, `account_deletion.dart`, `api_client.dart`;
  - the 30 ARB keys in EN, ES and CA.
- **The server:** I read `Backend/docs/ACCOUNT_DELETION.md` and `Backend/core/account_deletion.py` only to know what people see.
- **Line widths:** I measured them with Manrope (`App/assets/fonts/Manrope.ttf`, Pillow; matched renders to within about 1 dp in earlier runs).

**Walked**, as the newcomer (Spanish, 1.3–2× text, one-handed), the daily user, and a TalkBack or low-vision user:
1. **Find it:** Calendario → Ajustes → Cuenta → Eliminar cuenta, 3 taps. The header's person icon reaches Account too, in 2.
2. **Read what will happen, in every state:**
   - loading; load failed with Reintentar;
   - counts only; nothing of their own;
   - tasks kept in shared projects (1 and many);
   - named handovers (a project and a group);
   - Pro;
   - 2× text on 320 dp in ES and CA; dark mode.
3. **Save a copy first:** the link → Exportar e importar → Exportar archivo TaskFlow → Android's Guardar → Back. That's 4 taps.
4. **Confirm with the password:** the field, typing, closing the keyboard, Eliminar mi cuenta. That's 3 taps plus typing. Errors walked: wrong password, offline, no answer, throttled, failed, plan_required, reauth_required, and plan_changed (the page reloads in place).
5. **Confirm with Google:** Confirmar con Google, pick the account, Eliminar mi cuenta. That's 3 taps. Errors walked: the Google sheet closed, a Google error on the phone, another Google account.
6. **Deleting** (up to 60 s), then sign-in with «Tu cuenta se ha eliminado.». A retry after a lost answer ends the same way, and so does the next request after a deletion made on another phone.
7. **Pro:** the Google Play line and its link, which opens the browser.

**Numbers:**
- **Calendar → account deleted:** 6 taps plus the password, or 6 taps with Google. Saving a copy first adds 4 taps today, and 2 with UX-807.
- **Delete page:**
  - tap targets: 5 with a password (back, copy link, field, eye, delete) and 4 with Google, plus 1 with Pro;
  - decisions: 2 (save a copy? delete?).
- **Words before the destructive tap** (Spanish, with the tests' default preview: 12 tasks, 3 notes, 2 files, 1 project, 4 kept, 2 handovers):
  - about 78, or 93 with Pro;
  - the copy detour adds a 53-word screen with 2 choices (JSON, CSV, Todoist) — 0 with UX-807.
- **Account screen:** 2 red text buttons 8 dp apart (Cerrar sesión, Eliminar cuenta).
- **Heading «¿Eliminar tu cuenta?» at 2× (linear) on 320 dp:**
  - 3 lines in ES and EN, 4 in CA, one word per line: «¿Eliminar» is 250 px, "account?" 254 px and «compte?» 239 px, of 272 px available;
  - no word breaks in the middle today;
  - «TaskFlow?» would measure 280 px and break mid-word, so UX-803 puts "TaskFlow" in the intro, not in the heading.

### Findings (most severe first)

**UX-801 · Severity 3 · A forgotten password is a dead end on this page**
- **Where:** `App/lib/screens/delete_account_screen.dart:450-496` (the password confirmation) and `:473-475` (the error under the field); `App/lib/l10n/app_es.arb:1201`. State: a password account, with the password forgotten or wrong.
- **The moment:** «Hace meses que entré. ¿Cuál era la contraseña? Ya he probado tres.»
- **What happens:**
  - The page asks only for the password. A wrong one gets «La contraseña no es correcta.» and nothing else.
  - On sign-in, «¿Has olvidado tu contraseña?» sits right where wrong credentials appear (`login_screen.dart:578-592`, `:644-657`). From here, the only way to it is signing out, and the page never says so.
  - After 5 wrong tries, the server locks both deleting and signing in for 15 minutes (`Backend/core/account_deletion.py:307-310`). The page shows that only as UX-809's vague line.
  - The website's email route isn't mentioned either.
- **Why it fails:**
  - no dead ends (lens A);
  - error messages say how to fix the problem (Nielsen 2001);
  - consistency with sign-in (Nielsen 1994);
  - older users give up after one or two dead ends (Nielsen 2013, and the persona).
- **Fix:**
  - **The link:** put sign-in's own link under the field, right-aligned as on sign-in: `¿Has olvidado tu contraseña?` / `Forgot password?` / `Has oblidat la contrasenya?` (`forgotPassword`).
  - **What it does:** it runs sign-in's two recovery steps for this account's email: `sendRecoveryCode`, then `recoveryCode` + `newPassword` + `saveNewPassword`. All these strings already exist.
  - **Where it ends:** back on this page, with the new password in the field. The server ends every session on a reset (`Backend/core/auth_views.py:159`), so the page signs in again with the email and the new password before returning.
  - **The minimum, if the organizer finds that too large for the loop:** change the error copy only.
    - ES `La contraseña no es correcta. Si no la recuerdas, cierra sesión y toca “¿Has olvidado tu contraseña?”.`
    - EN `That password isn’t right. If you don’t remember it, sign out and tap “Forgot password?”.`
    - CA `La contrasenya no és correcta. Si no te’n recordes, tanca la sessió i toca “Has oblidat la contrasenya?”.`
- **Verify:**
  - Widget test:
    - the link shows under the field, before and after `wrong_password`;
    - tapping it posts `auth/password-reset/` with the account's email;
    - after `saveNewPassword`, the page is back, the field holds the new password, and `Eliminar mi cuenta` is enabled.
  - Walkthrough: a password account that doesn't know its password reaches deletion without leaving the page.
- **Evidence:** verified in code (the app, and the server's reset and lock). How often people forget is inferred.

**UX-802 · Severity 3 · "Save a copy" leaves the files out, and says nothing**
- **Where:**
  - `delete_account_screen.dart:390` (the files count) and `:303-313` (the copy link);
  - `App/lib/services/archive_store.dart:35-58` and `App/lib/models/task_archive.dart:339-343`: the export keeps each file's name, not the file;
  - `app_es.arb:1187`, `:1194`.
- **The moment:** «Guardo la copia, como dice, y así no pierdo las fotos de las recetas.» Later, the copy holds the tasks, and only the photos' names.
- **What happens:**
  - «Lo que se eliminará: … 2 archivos» is followed by «Guardar antes una copia de tus tareas».
  - The copy holds tasks, notes and projects, but only the names of their files. Neither this page nor Exportar e importar says so.
  - After deleting, the files are gone from the server and from the phone.
- **Why it fails:**
  - error prevention, and match with how the person thinks (Nielsen 1994): a copy offered right before a step that can't be undone reads as "everything listed above";
  - the owner's promise that people can export first;
  - peak–end (Kahneman 1993): the gap is found only after it can no longer be fixed.
- **Fix:**
  - When files > 0, add one line right under the copy link (or under UX-807's «Copia guardada»):
    - ES `La copia no incluye los archivos.`
    - EN `The copy doesn’t include files.`
    - CA `La còpia no inclou els fitxers.`
  - No line when files = 0.
  - Whether the copy should carry the files themselves is a question for the owner (below).
- **Verify:** widget test: with 2 files, the line shows under the link in ES, EN and CA and fits at 2× on 320 dp; with 0 files, it's absent.
- **Evidence:** verified in code.

**UX-803 · Severity 2 · The page doesn't say which account goes, or that Google stays**
- **Where:** `delete_account_screen.dart:290-295` (heading and intro), `:511` (the Google help line), `:501-502` (another Google account); `app_es.arb:1182-1183`, `:1196`, `:1202`.
- **The moment:**
  - Signed in with Google: «¿Eliminar tu cuenta? ¿Y ahora "Confirmar con Google"? ¿Me van a borrar el Gmail?»
  - With two accounts: «¿Cuál de las dos es esta?»
- **What happens:**
  - The heading and the intro say «tu cuenta», without "TaskFlow" and without the email. Account shows the email (`account_screen.dart:187-190`); this page doesn't.
  - For a Google account, the next line is «Para confirmar, elige tu cuenta de Google.», beside a Google button. So «tu cuenta» now reads as the Google account.
  - If the wrong Google account is picked, «Elige la misma cuenta de Google con la que entras en TaskFlow.» doesn't say which one to pick.
- **Why it fails:**
  - recognition over recall, and error prevention (Nielsen 1994): name the thing an irreversible action destroys;
  - plain language is specific (ISO 24495-1);
  - the website promises «La baja no elimina tu cuenta de Google o Apple», and the app never says it.
- **Fix:**
  - **Under the heading:** the account's email in `onSurfaceVariant`, as on Account.
  - **The intro:**
    - ES `Se eliminarán tu cuenta de TaskFlow y tus tareas, notas y archivos en todos tus dispositivos. No se puede deshacer.`
    - EN `This deletes your TaskFlow account and your tasks, notes and files on all your devices. It can’t be undone.`
    - CA `Es suprimiran el compte de TaskFlow i les teves tasques, notes i fitxers a tots els dispositius. No es pot desfer.`
    - "TaskFlow" goes here, not in the heading: «TaskFlow?» is 280 px at 2×, wider than the 272 px available, and would break mid-word.
  - **The Google help line:**
    - ES `Para confirmar, elige {email} cuando Google te lo pida. Tu cuenta de Google no se elimina.`
    - EN `To confirm, choose {email} when Google asks. Your Google account isn’t deleted.`
    - CA `Per confirmar-ho, tria {email} quan Google t’ho demani. El compte de Google no se suprimeix.`
  - **Another Google account:**
    - ES `Elige {email}, la cuenta de Google con la que entras en TaskFlow.`
    - EN `Choose {email}, the Google account you use for TaskFlow.`
    - CA `Tria {email}, el compte de Google amb què entres a TaskFlow.`
    - An account that signs in only with Google has its Google address as its email, so naming it is accurate.
- **Verify:**
  - Widget test in ES, EN and CA:
    - the email sits under the heading;
    - with Google, the help line and the mismatch error name it;
    - at 2× on 320 dp nothing overflows (include a 34-character email, which wraps).
  - Update the intro text the test pins at `delete_account_test.dart:360-362`.
- **Evidence:** verified in code. The fear for the Google account is inferred; watch for it in the §7 test.

**UX-804 · Severity 2 · What stays reads like more of what goes**
- **Where:** `delete_account_screen.dart:394-429`; `app_es.arb:1190-1191`.
- **The moment:** «Lo que se eliminará: 12 tareas, 3 notas… 4 tareas que añadiste… ¿También se borran las que puse en la lista de la familia?»
- **What happens:**
  - The kept line and the handover lines follow the bulleted list, with no heading of their own.
  - The kept line opens with «4 tareas que añadiste a proyectos compartidos…» and only reaches «se quedan para los demás» at words 8–9.
  - Files the person added in shared projects also stay (`ACCOUNT_DELETION.md`), but nothing says so.
  - A group's line doesn't say that the person's projects in it go with it, although `groupTransferHelp` already says a group's owner controls «este grupo y sus proyectos».
- **Why it fails:**
  - people scan the first words of each line (Nielsen 1997; Pernice 2017);
  - Gestalt common region (Palmer 1992): two outcomes need two visible groups;
  - the owner's rule that shared content is handled explicitly.
- **Fix:** two parallel lists.
  - ES:
    - `Lo que se eliminará:` (as now);
    - then `Lo que se queda para los demás:`, with these bullets:
      - `{count} tareas y los archivos que añadiste a proyectos compartidos, sin tu nombre` (singular: `1 tarea y los archivos que añadiste…`);
      - `El proyecto «{name}» pasará a {person}`;
      - `El grupo «{name}» y sus proyectos pasarán a {person}`.
  - EN:
    - `What stays for the others:`
    - `{count} tasks and the files you added to shared projects, without your name` (singular: `1 task and…`);
    - `The project “{name}” will go to {person}`;
    - `The group “{name}” and its projects will go to {person}`.
  - CA:
    - `El que es queda per als altres:`
    - `{count} tasques i els fitxers que vas afegir a projectes compartits, sense el teu nom` (singular: `1 tasca i…`);
    - `El projecte «{name}» passarà a {person}`;
    - `El grup «{name}» i els seus projectes passaran a {person}`.
  - The second heading shows only when it has a bullet.
  - Someone who added files, but no tasks, to shared projects still sees nothing, because the preview doesn't count those files. The cause is likely server-side.
- **Verify:**
  - Widget test:
    - the order is: the first heading, its bullets, the second heading, the kept bullet, the handover bullets;
    - the kept bullet starts with its count;
    - ES, EN and CA fit at 2× on 320 dp;
    - with 0 kept and no handovers, there is no second heading.
  - Update `delete_account_test.dart:354-406` and `:1359-1387`. The second test calls today's Spanish "the owner's brief", but `DECISIONS.md` records no deletion copy, so this review doesn't treat it as a decision. The main session can confirm.
- **Evidence:** verified in code. The misreading is inferred.

**UX-805 · Severity 2 · «Algo ha cambiado» doesn't say what changed**
- **Where:** `delete_account_screen.dart:203-214` (the reload) and `:321-331` (the banner); `app_es.arb:1206`.
- **The moment:** «Algo ha cambiado… ¿el qué? Arriba parece todo igual.» They tap Eliminar mi cuenta again.
- **What happens:**
  - After a 409, the page reloads in place, keeps the password, enables the button again, and scrolls to the banner above it.
  - The changed handover line is updated somewhere above, with no mark.
  - The old line is gone, so there's nothing to compare it with. One tap confirms.
- **Why it fails:**
  - change blindness (Rensink, O'Regan & Clark 1997);
  - working memory (Cowan 2001): never make anyone carry the old line in their head;
  - habituation (Raskin 2000): a generic "check and confirm again" gets tapped through;
  - this is exactly when a new handover would otherwise go unnoticed — the case the owner's "never silently" promise is about.
- **Fix:**
  - Compare the handover lines before and after the reload.
  - Keep today's first sentence, ending it with a colon. Below it, show each new or changed handover on its own line, using the same handover string. Then a closing line:
    - ES `Algo ha cambiado desde que abriste esta pantalla:` / `• El proyecto «Casa» pasará a Luis` / `Revísalo y vuelve a confirmar.`
    - EN `Something has changed since you opened this screen:` / `• The project “Casa” will go to Luis` / `Check it and confirm again.`
    - CA `Alguna cosa ha canviat des que has obert aquesta pantalla:` / `• El projecte «Casa» passarà a Luis` / `Revisa-ho i torna a confirmar-ho.`
  - The same lines are bold in the list until the next tap.
  - When nothing new appears (a handover only disappeared), keep today's text.
- **Verify:**
  - Extend `delete_account_test.dart:817` (Casa moves from Ana to Luis):
    - the banner contains `El proyecto «Casa» pasará a Luis`;
    - that line in the list is bold;
    - the banner is in view above the button at 2× on 320 dp.
  - A change that only removes a handover shows today's text.
- **Evidence:** verified in code.

**UX-806 · Severity 2 · The Google Play line can be untrue, and its link means reading**
- **Where:**
  - `delete_account_screen.dart:430-445`, `:16-19`, `:251-263`;
  - `Backend/core/account_deletion.py:115-121` and `Backend/core/billing.py:82-92`, `:119-127`: `pro` is true for complimentary Pro, and when billing can't be checked;
  - `app_es.arb:1192-1193`.
- **The moment:**
  - A complimentary tester: «¿Tengo una suscripción de Google Play? ¿Me están cobrando?»
  - A subscriber: «Me ha abierto una página de ayuda de Google con cinco pasos…»
- **What happens:**
  - The bold line «Eliminar tu cuenta no cancela tu suscripción de Google Play.» shows whenever the server says `pro`. That includes complimentary accounts (probably the family testers) and unknown billing. For those people, it states a subscription they don't have.
  - «Cómo cancelarla en Google Play» opens a help article in the browser. Meanwhile, the Pro screen manages the same subscription in one tap: `Gestionar suscripción`, kept by D4d (`subscription_screen.dart:200-210`).
- **Why it fails:**
  - plain language must be accurate (ISO 24495-1);
  - consistency: one concept, one name (Nielsen 1994);
  - instructions are hard to read on a phone (Moran 2016); an action beats a how-to;
  - Android documents a deep link to the subscriptions center for this purpose (developer.android.com, "Use deep links to allow users to manage a subscription").
- **Fix:**
  - **Complimentary accounts:** no Google Play block (`Account.complimentaryPro`), as the Pro screen already hides its store buttons for them.
  - **Everyone else:** a line that's true whoever reads it, in plain weight:
    - ES `Si pagas TaskFlow Pro en Google Play, eliminar tu cuenta no cancela la suscripción.`
    - EN `If you pay for TaskFlow Pro on Google Play, deleting your account doesn’t cancel the subscription.`
    - CA `Si pagues TaskFlow Pro a Google Play, suprimir el compte no cancel·la la subscripció.`
  - **The link:**
    - It becomes the Pro screen's `Gestionar suscripción` (`billingManage`), with the same Customer Center action and the same condition.
    - When billing isn't ready, or knows of no purchase, it opens `https://play.google.com/store/account/subscriptions`.
    - This replaces `deleteAccountSubscriptionHelp` and the help-article URL.
- **Verify:**
  - Widget test:
    - complimentary → no block;
    - `pro` with a purchase → the new line, and `Gestionar suscripción` calling the controller's Customer Center;
    - billing not ready → the subscriptions URL;
    - ES, EN and CA fit at 2× on 320 dp.
  - Phone: a sandbox subscriber reaches Cancel in 2 taps from the page.
- **Evidence:** verified in code (app and server). The help article's steps are inferred.

**UX-807 · Severity 2 · Saving a copy detours through Export & import, with no confirmation**
- **Where:** `delete_account_screen.dart:303-313`; `App/lib/screens/data_transfer_screen.dart:148-164`; `app_es.arb:591-595`.
- **The moment:** «¿Exportar o importar? ¿JSON? … Ya está, creo. Vuelvo… ¿se ha guardado?»
- **What happens:**
  - The link opens Exportar e importar, which shows:
    - a slogan heading and an intro;
    - `Exportar archivo TaskFlow` and `Elegir archivo para importar`;
    - a 26-word line about JSON, CSV, Todoist and 32 MB.
  - After saving, Back returns to the delete page, which looks exactly as before. Nothing says a copy exists.
  - The link shows even when there's nothing to copy.
- **Why it fails:**
  - feedback belongs where the person is (Norman 2013; visibility of system status, Nielsen 1994);
  - Hick–Hyman: import is an extra choice this flow doesn't need;
  - cognitive load (Sweller 1988);
  - a recurring problem in this app: empty things shown as content.
- **Fix:**
  - The link runs the export itself, with the same `ArchiveStore.export()` + `ArchiveFiles.save()` as `Exportar archivo TaskFlow`, so Android's save screen opens straight away.
  - Once saved, a check row replaces the link in place, like «Confirmado con Google»:
    - ES `Copia guardada`
    - EN `Copy saved`
    - CA `Còpia desada`
  - A cancelled save changes nothing. A failure shows `transferError` under the link.
  - The link shows only when the preview has tasks or notes.
  - The page no longer opens `/dataTransfer`.
- **Numbers:** 4 taps → 2; 2 screens → 1; 53 words and 2 choices → none.
- **Verify:**
  - Widget test with a fake `ArchiveFiles`:
    - one tap calls save once and shows `Copia guardada` where the link was;
    - a cancelled save (null) keeps the link;
    - a throw shows `transferError`;
    - with no tasks and no notes, there's no link.
  - This replaces the test at `delete_account_test.dart:466-479`.
- **Evidence:** verified in code.

**UX-808 · Severity 2 · While deleting, the page looks frozen, and Back does nothing**
- **Where:** `delete_account_screen.dart:278-282` (PopScope), `:336-368` (the button), `:354` (the spinner's label); `App/lib/services/api_client.dart:511-520` (the 60 s limit); `app_es.arb:1200`.
- **The moment:** «Le he dado y se ha puesto gris… ¿lo está haciendo? Atrás no va.»
- **What happens:**
  - The button turns grey (disabled) with a small spinner, and still reads `Eliminar mi cuenta`.
  - «Eliminando tu cuenta» exists only as the spinner's TalkBack label.
  - Back and the app-bar arrow do nothing until the answer comes, which can take up to 60 s.
- **Why it fails:**
  - visibility of system status (Nielsen 1994);
  - response-time limits (Miller 1968; Nielsen 1993): past 1 s show progress, and past 10 s explain;
  - a back arrow that does nothing looks broken (Android's back conventions);
  - peak–end (Kahneman 1993).
- **Fix:**
  - While deleting, the button's visible text is `deleteAccountDeleting` with an ellipsis:
    - ES `Eliminando tu cuenta…`
    - EN `Deleting your account…`
    - CA `S’està suprimint el compte…`
  - The spinner drops its own label, so TalkBack says it once.
  - Hide the app-bar back arrow while deleting.
- **Verify:** widget test with `holdDelete`:
  - the button reads `Eliminando tu cuenta…`, and its semantics label contains it once;
  - there's no back arrow;
  - after an error, the old label and the arrow return.
- **Evidence:** verified in code.

**UX-809 · Severity 2 · «Inténtalo más tarde» hides a 15-minute lock**
- **Where:**
  - `delete_account_screen.dart:142`, `:273`; `app_es.arb:1205`;
  - on the server: `Backend/core/account_deletion.py:307-310` (5 wrong passwords lock for 15 minutes, shared with sign-in) and the `auth` limit of 10 a minute (`Backend/config/settings.py:55`).
- **The moment:** «Ya ha pasado un rato y sigue igual. Esto no funciona.» — two minutes into a 15-minute lock.
- **What happens:**
  - A one-minute burst limit and a 15-minute lock both show «Demasiados intentos. Inténtalo más tarde.».
  - The lock also stops signing in. The cause is server-side.
- **Why it fails:**
  - error messages say how to fix the problem (Nielsen 2001);
  - plain language is specific (ISO 24495-1).
- **Fix:**
  - Use the wait the answer carries, rounded up to whole minutes. DRF sends it as `Retry-After`, and in `detail` as «Expected available in N seconds».
    - ES `{minutes, plural, =1{Demasiados intentos. Espera un minuto y vuelve a intentarlo.} other{Demasiados intentos. Espera {minutes} minutos y vuelve a intentarlo.}}`
    - EN `{minutes, plural, =1{Too many tries. Wait a minute and try again.} other{Too many tries. Wait {minutes} minutes and try again.}}`
    - CA `{minutes, plural, =1{Massa intents. Espera un minut i torna-ho a provar.} other{Massa intents. Espera {minutes} minuts i torna-ho a provar.}}`
  - When the answer carries no wait, keep today's line.
- **Verify:** widget test:
  - a 429 with 900 s → «Espera 15 minutos»;
  - 40 s → «Espera un minuto»;
  - no wait → today's line;
  - the Catalan line fits at 2× on 320 dp.
- **Evidence:** verified in code (app and server).

**UX-810 · Severity 2 · Confirming with Google is silent to TalkBack**
- **Where:** `delete_account_screen.dart:513-529`, `:111-125`.
- **The moment:**
  - With TalkBack: «Se ha cerrado lo de Google… ¿ha funcionado?»
  - At 2× text: «Pone Confirmado… ¿y ahora qué toco?»
- **What happens:**
  - TalkBack's focus was on the Google button, and the button is replaced by «Confirmado con Google». That row isn't a live region, so nothing is announced.
  - At large text, the newly enabled `Eliminar mi cuenta` can sit below the screen, and nothing brings it into view.
- **Why it fails:**
  - gulf of evaluation (Norman 2013);
  - WCAG 2.2, 4.1.3 Status Messages;
  - "What is their next action, and how do they know?"
- **Fix:**
  - Make the confirmed row a live region.
  - Once it shows, bring `Eliminar mi cuenta` into view with the page's `_reveal`, which respects reduced motion.
  - No copy change.
- **Verify:**
  - Widget test: after a token, the row's semantics have `liveRegion`, and at 2× on 320×640 the confirm button is inside the viewport.
  - Phone: TalkBack says «Confirmado con Google».
- **Evidence:** verified in code. TalkBack's behaviour is inferred and needs a device check.

**UX-811 · Severity 1 · Cerrar sesión and Eliminar cuenta look identical, 8 dp apart**
- **Where:** `App/lib/screens/account_screen.dart:284-316`.
- **The moment:** «¿Cuál es para salir? Los dos están en rojo.»
- **What happens:**
  - Two red text buttons of the same size and weight sit at the bottom of Account, 8 dp apart.
  - A mis-tap only opens a dialog or the page, but the two read as one group.
- **Why it fails:**
  - two different actions never look alike side by side (lens D);
  - Gestalt proximity (Wertheimer 1923);
  - keep the most destructive action apart (Clark 2015).
- **Fix:** give `Eliminar cuenta` its own group: a `Divider` with 24 dp above it, instead of 8 dp. It stays last and red. No copy change.
- **Verify:** in `delete_account_test.dart:310-350`, the gap between the two buttons is at least 24 dp, with a divider between them; Eliminar cuenta is still last; it still fits at 2× on 320 dp.
- **Evidence:** verified in code.

### Keep
- **One plain page, not a dialog.** It shows the counts, what stays, and every handover by name, and only then asks the person to confirm it's them. The server deletes only the plan that was shown (409 otherwise), so nothing is handed over unseen.
- **Nothing is lost on failure.** The typed password survives every error and every reload. Offline says «No se ha eliminado nada»; a lost answer doesn't claim that.
- **One ending for every path.** A retry after a lost answer, and a deletion made on another phone, both end on «Tu cuenta se ha eliminado.» instead of an error. Back can't return to the deleted account.
- **Answers show where they belong:** under the field, under the Google button, or under the delete button. At large text they scroll into view, respecting reduced motion.
- **The phone is cleaned in the right order.** Reminders stop before the phone's copy is erased, and only this account's copy is erased.

### Progress against UX_REVIEW.md (U1–U14)
- **Advanced:** none; this change is outside U1–U14.
- **Regressed:** none.
  - U14 holds: the deleted notice sits above the sign-in card, so Google is still first inside it.
  - `login-light.png` (23:02) shows sign-in without the notice.
- **Still open:** U10 and U13, both decisions, unchanged.

### Questions for the owner
1. **Choosing the heir.** Heirs are picked automatically (the earliest admin or editor). Should a handover line let the person pick someone else first? Groups already have Transferir propiedad; projects don't. It adds a control.
2. **Telling the heir.** Should the person who receives a project or group be told? Today nothing tells them.
3. **Files in the copy.** Should «Guardar antes una copia» carry the files themselves? Today the copy keeps only their names, and UX-802 only says so.
4. **Google instead of the password.** Password accounts that have Google linked must type the password. Should they be able to confirm with Google instead? That would remove most of UX-801's dead end, but it's a server and security rule.

### Memory notes
- **Memory location.** The agent prompt points at `App/.claude/agent-memory/frontend-ux-reviewer/`, which is empty. The real memory is `.claude/agent-memory/frontend-ux-reviewer/` at the repo root.
- **Area D map (2026-10-15):**
  - **Account:** it ends with a red `Eliminar cuenta` TextButton, 8 dp under the red `Cerrar sesión`. It opens `/deleteAccount` (`DeleteAccountScreen`).
  - **The page, top to bottom:**
    - heading and intro;
    - a spinner while loading, or `LoadFailed` with Reintentar;
    - counts above 0: tasks, notes, files, projects, groups;
    - the kept-in-shared line, and one line per handover;
    - the Pro block: a bold line and a Play help link;
    - `Guardar antes una copia`, which opens `/dataTransfer`;
    - the password field, or `Confirmar con Google` → «Confirmado con Google»;
    - the red FilledButton (`colorScheme.error`), disabled until confirmed.
  - **Errors:** general ones under the button; a wrong password under the field; Google errors under the Google button. A 409 reloads in place, with a banner above the button.
  - **Deleting:** a spinner in the button, Back blocked, a 60 s limit.
  - **The ending:** a 204, or any 401 `user_not_found`, runs `forgetDeletedAccount()`. Sign-in then shows `accountDeleted` above the card until the next try (`clearError` drops `deleted`). Reminders are cancelled first, then the phone's copy is erased.
- **Server facts that shape this UI:**
  - the preview's `pro` is true for complimentary Pro and when billing is unknown;
  - 5 wrong passwords lock both deleting and signing in for 15 min;
  - a password reset revokes every session;
  - a group's handover line covers its projects;
  - the plan is a fingerprint of who receives what;
  - the export file keeps attachment names, not files.
- **Stale pattern line.** `ui-patterns` says "Nothing uses colorScheme.error" for destructive buttons. The delete page's main button and `groupConfirm(destructive: true)` now do.
- **Candidate recurring problems:**
  - a how-to link to a help article where the app already has the action (Play help vs `Gestionar suscripción`);
  - a confirmation that replaces the focused control without a live region;
  - a word added to a big heading can break mid-word at 2× on 320 dp: «TaskFlow?» is 280 px at 56 px, wider than 272 px. Measure before proposing heading copy.
