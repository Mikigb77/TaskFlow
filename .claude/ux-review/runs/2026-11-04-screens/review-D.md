## UX review — D · Meeting notes: Pro screen limit (D4) and notes-ready notification (D6) — 2026-11-04
**Verdict:** Ship. Both decisions are carried out as recorded. There are two polish findings, and one owner question: on a phone with Android's default lock-screen setting, "private" still shows the title.

**Scope and evidence:** `git diff HEAD` of `App/lib/screens/subscription_screen.dart`, `App/lib/l10n/meeting_copy.dart`, `App/lib/services/notification_service.dart` and the ARB keys `proBenefitMeetingNotes` and `billingReasonMeetingNotesLimit` (EN/ES/CA, plus the generated files). Renders: `meetings/pro.reason.{es.light.1x, ca.light.2x}`, `meetings/pro.held-back.es.light.1x`, `settings/pro.free.{es 1x, es 2x, ca 2x}`, `reminders/sheet.pro-screen.{es 1x, es 2x, ca 2x}`, all rendered 2026-11-04 21:50–21:54. `find App/lib App/assets -newer <png>` lists nothing for any of them, so they are fresh. Read with AUDIT.md (`meetings/pro · reason`, `settings/pro · free`, `reminders/sheet · pro-screen`). Evidence levels: widget-test renders, unit tests (`meeting_screens_test.dart:1211-1218`, `:4398-4405`; `subscription_screen_test.dart:1310-1345`, `:1429-1475`), and code. The `flutter_local_notifications` 22.3.3 Android source is in the pub cache. No device or emulator was used.
- **Not rendered:** English, dark mode, and ES 2× of the meeting reason. I reasoned those from the code. The new lines reuse `colors.onPrimaryContainer` on `primaryContainer`, the same tokens as the neighbouring lines, so no new colour pair is introduced. Neither text has a line limit, so nothing can be cut off. English is about as long as Spanish.
- **The 2× renders of `settings/pro.free`** stop at the second benefit. I took the fourth benefit at 2× from `subscription_screen_test.dart:1429-1475` («…, last and whole»; ES 1× and CA 2×).

**Walked** (newcomer first, then daily user and TalkBack):
1. A free account taps Notas › «Grabar una reunión»: the Pro screen with the meeting reason → «Ver suscripción». 1 tap to reach the screen, 1 to the paywall. ES 1× and CA 2× (rendered). The held-back recording's «Ver Pro» shows the same screen (rendered).
2. Ajustes › TaskFlow Pro, free account: the benefits list now ends «…, hasta 20 horas al mes». ES 1×/2× and CA 2× (rendered).
3. The reminder sheet's Pro badge opens the Pro screen with the reminders reason; its benefits include the meeting hours. ES 1×/2× and CA 2× (rendered).
4. Stop → the notes are made → "notes ready" posts → the phone is locked → unlock → tap opens the note. From code only; the lock screen is a phone check.

**Numbers:**
- Pro screen, meeting reason: the card goes from 7 to 8 text blocks, and +7 words in ES (Hasta 20 horas de reuniones al mes.). Tap targets stay at 3 (Atrás, Restaurar compras, Ver suscripción).
- Ajustes › TaskFlow Pro: the meeting benefit goes from 6 to 10 words (ES). It wraps at the comma at ES 1×, «…que grabas, / hasta 20 horas al mes», which reads well.
- The hours appear once per screen. On the meeting reason, the reason block says them and the benefit line stays hidden (`subscription_screen.dart:132-141`, `:192-193`). No repetition.
- TalkBack, meeting reason (AUDIT): heading «Con Pro, tus reuniones se convierten en notas:», then «un resumen…», then «Hasta 20 horas de reuniones al mes.», each as its own node, before the plan.

### Findings (most severe first)

**UX-3001 · Severity 1 · Hours line runs on from the example**
- Where: `App/lib/screens/subscription_screen.dart:132-141`, the Pro screen opened for a meeting (also from a held-back recording's «Ver Pro»).
- The moment: "…las decisiones y las cosas por hacer Hasta 20 horas… Is the 20 hours part of what's in the notes?"
- What happens: the new line sits 4 dp under the example, with the example's style and colour. It sits at the same spacing as heading → example, and the example deliberately has no final period, because it completes the heading's colon (`@billingReasonMeetingNotesExample`). So the three lines read as one paragraph. At CA 2× the 4 dp disappears between 28 dp lines: «…les coses / per fer / Fins a 20 hores de / reunions al mes.» (`meetings/pro.reason.ca.light.2x`). Only the capital letter tells the allowance apart from the list of what the notes hold.
- Why it fails: Gestalt proximity (Wertheimer 1923; Palmer 1992). The heading and example are one unit, and the allowance is another fact, so they need a visible break. SC-2 (one point per line where people decide) also applies.
- Fix: raise the gap above the hours line from 4 dp to 8 dp, the step the card already uses between its other lines (`:160`, `:172`, the benefits' `top: 8`). Change no copy and add no new style.
- Verify: re-render `meetings/pro.reason.*`. At ES 1× and CA 2× there should be a visible break between «…por hacer» / «…per fer» and «Hasta…» / «Fins a…». In the widget test, the gap between `subscription-reason-example` and `subscription-meeting-limit` should be ≥ 8 dp.
- Evidence: seen in current renders, and verified in code.

**UX-3002 · Severity 1 · "{hours} horas" has no ICU plural**
- Where: `App/lib/l10n/app_en.arb:4469`, `:4490`; `app_es.arb:1507`, `:1511`; `app_ca.arb:1211`, `:1215`. The value is `meetingHoursPerMonth` (`App/lib/l10n/meeting_copy.dart:13`), whose comment says "Change both together" with the server.
- The moment: none today. 20 reads correctly. But if the server's allowance changes to 1 hour (say, a trial), the three languages would read «hasta 1 horas», «fins a 1 hores» and "up to 1 hours".
- What happens: both keys take an `int` and put the noun after it with no plural. The meeting copy next to them already uses plurals (`meetingRecordedHours`, `app_es.arb:1459`).
- Why it fails: LO-2 (every count uses an ICU plural; CLDR Plurals, Flutter i18n), and `App/docs/LOCALIZATION.md` rule 2.
- Fix: in all three ARBs, use a plural:
  - EN: `{hours, plural, =1{up to 1 hour a month} other{up to {hours} hours a month}}` inside `proBenefitMeetingNotes`, and `{hours, plural, =1{Up to 1 hour of meetings a month.} other{Up to {hours} hours of meetings a month.}}`;
  - ES: `=1{hasta 1 hora al mes} other{hasta {hours} horas al mes}`, and `=1{Hasta 1 hora de reuniones al mes.} other{Hasta {hours} horas de reuniones al mes.}`;
  - CA: `=1{fins a 1 hora al mes} other{fins a {hours} hores al mes}`, and `=1{Fins a 1 hora de reunions al mes.} other{Fins a {hours} hores de reunions al mes.}`;
  - write each case as a whole sentence, as LO-2 asks. No change to the visible text at 20.
- Verify: unit test that `proBenefitMeetingNotes(1)` and `billingReasonMeetingNotesLimit(1)` read the singular in EN, ES and CA, and that 20 is unchanged.
- Evidence: verified in code.

### Keep
- The hours appear once, where the decision is made. On the meeting reason they are under the example, and the benefit line is left out. Elsewhere they sit on the benefit line itself. The number comes from one constant tied to `AI_MEETING_PIECES_PER_MONTH`, not from copy.
- «Hasta 20 horas de reuniones al mes.» and «Notas de las reuniones que grabas, hasta 20 horas al mes» are plain and front-loaded. Their CA and EN versions read naturally («Fins a 20 hores de reunions al mes.», "Up to 20 hours of meetings a month."). They match the run-out copy's «el tiempo de reuniones de este mes».
- Each reason line is its own TalkBack node, read in visual order, with the heading flagged as a heading (AUDIT `meetings/pro · reason`).
- At CA 2× the new line fits whole, and «Mostra la subscripció» stays pinned in view (`meetings/pro.reason.ca.light.2x`). The first benefit is still above the pinned button on the no-reason screen (test `subscription_screen_test.dart:1429-1452`).
- D6 is scoped right. Only "notes ready" turns private. The recording notification stays public (`notification_service.dart:242`), because its Parar/Descartar must work from the lock screen and it carries no meeting content.

### Progress against UX_REVIEW.md (U1–U14)
`../UX_REVIEW.md` is not present in this session. The change doesn't touch U1–U14. UX-2720 (D4): carried out on both screens; UX-3001 and UX-3002 are polish on it. UX-2814 (D6): carried out in code, as the decision is worded (see question 1); the lock screen is owed as a phone check.

### Questions for the owner (product decisions only)
1. **Lock screen, NO-9 (UX-2814, D6): "private" is what Android already did.**
   - On Android, a notification's visibility is private unless set otherwise: `NotificationCompat.Builder`'s default, and the plugin only calls `setVisibility` when one is given (`flutter_local_notifications-22.3.3/.../FlutterLocalNotificationsPlugin.java:936-958`). So the explicit `NotificationVisibility.private` (`notification_service.dart:159`) changes nothing on a phone.
   - On a phone left at Android's default lock-screen setting (show all notification content), the meeting's title still shows on the lock screen, as before. It is hidden only where the person turned on "hide sensitive content", and there Android shows TaskFlow with its own "Contents hidden".
   - That matches D6 as recorded. If you meant "never show the title on the lock screen", there are two ways:
     - (a) secret: the notification doesn't appear on the lock screen at all;
     - (b) a title-free lock-screen version, «Las notas de la reunión están listas», with the title once unlocked. This needs native code, because the plugin has no public-version option.
   - Phone check either way: both lock-screen settings, on the `TaskFlow_Review` emulator or a phone.
2. **«Hasta 20 horas» and short meetings (D4).**
   - The server counts pieces, not minutes (`Backend/core/meetings.py:302-318`). Every meeting's last piece counts in full: a 2-minute call uses one of the 240, and a 12-minute one uses three.
   - Someone who records many short meetings runs out well before 20 recorded hours. «Hasta» keeps the line truthful, but a newcomer reads «20 horas» as their time.
   - Keep it as is, count by minutes on the server, or say «unas 20 horas»? Cause: server-side.
3. **RevenueCat paywall (D7, UX-2815):** the app now says «Notas de las reuniones que grabas, hasta 20 horas al mes». When you add the line in the dashboard, use the same words, hours included, so the paywall and the Pro screen agree (SC-9).

### Cross-slice notes
- Main session: the change adds a limit that people will read («hasta 20 horas al mes»). Per AGENTS.md, the website's `/ux-web` loop should check that the site states the same allowance (and D5's audio line, MN-34).
- Preview suite (not user-facing): the INDEX/AUDIT descriptions for `meetings/pro · reason`, `settings/pro · free` and `reminders/sheet · pro-screen` still describe the copy without the hours line. The pixels and TalkBack lists are current; only the prose lags.
- C: none from this slice.

### Memory notes
- The Pro screen's reason block (`subscription_screen.dart:114-143`) is heading → example (no final period, completing the heading's colon) → for meetings only, the hours line. The benefit for the reason being shown is left out of the list.
- `meetingHoursPerMonth = 20` (`App/lib/l10n/meeting_copy.dart:13`) mirrors the server's `AI_MEETING_PIECES_PER_MONTH = 240`. The server counts pieces, so short meetings use the allowance faster than their length.
- `NotificationVisibility.private` equals Android's default. Setting it explicitly is a no-op on the device. `flutter_local_notifications` 22.3.3 has no public-version option, so a redacted lock-screen text needs native code. The recording notification is public by design.
- Recurring problem: count placeholders added without ICU plurals when the value is a constant today (LO-2).
- Preview INDEX/AUDIT descriptions can lag a copy change. Trust the pixels and the TalkBack list, not the prose.
