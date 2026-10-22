## UX verify — run 2026-10-22-changes, round 1, area D — 2026-10-22
**Verdict:** Ship after fixes — all 11 findings fixed in code and tests; one small copy regression (the Pro screen's example is Normal's free rhythm).
**Scope:** P247 (UX-2007, UX-2011), P244 (UX-1803, UX-1808, UX-2003, UX-2008), P246 (UX-2004, UX-2005, UX-2009, UX-2010, UX-2012). `git diff HEAD` of the listed files; renders `reminders/sheet.pro-screen.*`, `reminders/offer.asked.*`, `settings/reminders.all-day-off-plans.*` (14:49–14:51, newer than every file under App/lib and App/assets, so current).

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-2007 | fixed | `subscription_screen.dart`: reason in `Semantics(header: true)`, titleMedium, then `billingReasonReminderPlansExample` in body style; card gets `explicitChildNodes` only with a reason. ES/EN/CA copy as briefed. Renders es 1×, es 2×, ca 2×: heading, example and pinned «Ver suscripción»/«Mostra la subscripció» all in view. But see R1D-1. |
| UX-2011 | fixed | `notification_settings_screen.dart` `_plansWithoutTime()` (open task, `ReminderPlans.active` non-null, `time == null`) → `dateOnlyOffPlans(_time(defaultMinute))`; set time unchanged. Render `settings/reminders.all-day-off-plans.es.light.1x`: «Desactivado · «Hasta la fecha límite»: 09:00». |
| UX-1803 | fixed | `reminder_plans.dart` `offerable`: `reminderMinutes == null && reminderTime == null`. `task_editor.dart:563-575`: `offerPlan` only when no earlier anchor or the anchor's day moved; creates keep the default. Tests pass. |
| UX-1808 | fixed | `reminder_ask_sheet.dart` `_PlanOfferSheet`: `_TaskLine` «{title} · {taskDayLine / taskDeadlineLabel}» (2 lines, title cut, day kept, TalkBack full), question with Normal's lowercase rhythm, `reminderAskYes`, one merged header + live region. `reminderPlanOfferYes` removed in the 3 catalogs. Renders: es 1× «Presentar el proyecto de empresa · jue, 12 de nov» / «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?» / «Sí, recuérdamelo» / «Ahora no»; es and ca 2×: all on screen. TalkBack order is a device check. |
| UX-2003 | fixed | `_offer` → `ringsHereAlone`: personal or member-assigned-to-me only; project read from `taskListsProvider`, `TaskDatabase.reminderBlock(... archived, muted, role) == null`; unknown project not asked. Two-phone check is the owner's. |
| UX-2008 | fixed | «Listo. Te lo recordaré hasta el …» via `showFeedback(actionLabel: undo)`; action `updateTask(current)` + `showLocal()`, `undoError` on failure; the task stays offered. Same FeedbackTimeout pattern as the app's other undos. |
| UX-2005 | fixed | `ReminderCopy.planBody(task, daysBefore)`: date via `formatMediumDate`, time via the shared `_clock` (`use24`, `hour` for «a la 1:00»), deadline forms incl. `notificationDeadlineAt`/`notificationDeadlineToday`/new `reminderPlanNoticeDeadlineTomorrow`; `planNotice` deleted; snooze rows in `reconcile` use it. Shade wrapping is a device check. |
| UX-2012 | fixed | `app_en.arb` `reminderPlanNoticeWas` “It was planned for yesterday”; ES/CA unchanged. |
| UX-2009 | fixed | `notification_service.dart`: plan notices get only «Completar» on Android; iOS `plan_<lang>` category with `snooze: false` registered beside `task_<lang>`. iOS registration and «Completar» from the shade: device checks. |
| UX-2004 | fixed | `reminder_engine.dart` reconcile: per task, elapsed plan rows already fired, sorted by `fire_at`, all but the newest cancelled and set inactive. Runs on refresh (job, hourly, app open); stacking until then on a phone that defers work is a device check. |
| UX-2010 | fixed | `planReminders`: `index < window || alert.daysBefore <= 1` — next four plus the day before, the day and the day after, one list so no duplicate identity. Battery-restricted delivery: device check. |

### Regressions
**R1D-1 · Severity 2 · Pro screen sells Normal's free rhythm as Pro**
- Where: `App/lib/l10n/app_es.arb` `billingReasonReminderPlansExample` («cada 3 días y la última semana a diario»; EN/CA alike), shown by `subscription_screen.dart` (render `reminders/sheet.pro-screen.*`).
- The moment: "Me acaba de ofrecer gratis «cada 3 días, y a diario la última semana»… ¿y ahora me lo quieren cobrar?"
- What happens: this round's offer (P244) asks every free user «¿Te aviso cada 3 días, y a diario la última semana?», which is Normal, free. The new Pro example (P247) promises the same rhythm as what Pro adds. P241 changed the «A tu manera» helper to «una semana antes y el día antes a las 8» precisely because the example must be "a shape the strengths can't give" (UX-1908).
- Why it fails: match with the real world and consistency (Nielsen 1994); one concept, one name (ISO 24495-1) — the same words now mean "free" in one place and "Pro" in the other.
- Fix: reuse the field's example: ES `«una semana antes y el día antes a las 8»`, EN `“a week before, and the day before at 8”`, CA `«una setmana abans i el dia abans a les 8»`; no final period, as now. Update the P247 tests and the pro-screen preview description.
- Verify: re-render `reminders/sheet.pro-screen` es 1×/2×, ca 2× — heading, new example and «Ver suscripción» in view; P247 tests read the new example.
- Evidence: verified in code and in current renders.

No other regressions found in the changed files and the flows they touch (offer sheet, Pro screen, Recordatorios, plan notices).

### Device checks for the main session
TalkBack order on the offer; two-phone «Todos» task; shade shows plan bodies whole (es/ca, 24h/12h); «Completar» is the only action and completes; «cada día» plan over 3 days leaves one line; battery-restricted phone still gets «Es mañana»/«Es hoy».
