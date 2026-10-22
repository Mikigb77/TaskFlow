# UX run 2026-10-22-changes — report

**Verdict:** All 31 planned findings are fixed in code, and a widget or unit test now covers each one. 23 are verified. 8 are verified in code but still need a phone check. Nothing was escalated. Two lines stay open:
- UX-2020 (S1): the round 3 check found it, and no round was left to fix it.
- UX-2021 (S2): it was already there before this run. The round 1 check noticed it, and it is now in the ledger.

Evidence comes from code (`git diff HEAD`), widget and unit tests (all rounds passed), and the current preview renders under `App/build/ux/`. No device or emulator was used in this run.

## Verified (23)

**Area A, voice capture**
- **UX-1805**: Said reminders now have one home on the card: one «Recordatorio» row above «Más opciones» (P242).
- **UX-1802**: When this phone won't ring, the card shows «Activar recordatorios» under the plan line (P242).
- **UX-1809**: When several tasks are collapsed, a said reminder shows as one line, built like the date line (P242).
- **UX-1811**: A plan made useless by «Sin fecha» or a repeat is dropped when the task is saved (P242).
- **UX-1806**: The plan line now says it is reminders and names their strength (P241; merged UX-1902).
- **UX-1807**: The plan line now says when they ring, in the app's clock (P241).
- **UX-1804**: «próximo» only names a notice that will actually come; a plan with nothing ahead reads `noReminderTimePassed` (P241; merged UX-1903).
- **UX-1801**: A free account's own dictated rhythm shows selected, with its preview and «Listo», and no Pro badge (P243; merged UX-1901).
- **UX-1810**: The sheet opens with the task's plan in view (P243).
- **UX-1803**: The offer only comes while the reminder is the default, after a create or a moved day (P244; merged UX-2006).
- **UX-2016**: A reminder changed inside «Más opciones» no longer jumps out of view (P248; this was R1A-1).
- **UX-2018**: A reminder changed inside «Más opciones» is summarised with the existing reminder line, in the subtitle and on a collapsed row (P250; this was R2A-1).

**Area B, calendar, home and tasks**
- **UX-1910**: «13 avisos · próximo: mañana, 09:00». The «el» is gone (P241).
- **UX-1904**: Plan rows only show for tasks 2 or more days away, or for tasks that already have a plan (P243).
- **UX-1906**: Words already read are kept when the sheet closes (P245).
- **UX-1908**: «A tu manera» shows its example from the start; «Dictarlo» clears words it misunderstood (P245).
- **UX-1909**: The Catalan now says «Fins al termini» everywhere (P245).

**Area D, settings, notifications and native surfaces**
- **UX-2007**: The Pro screen's reason is a heading followed by an example of «A tu manera» (P247).
- **UX-2011**: «Tareas sin hora» shows the hour that plans use when it is off (P247).
- **UX-2008**: «Sí» to the offer now comes with Deshacer (P244).
- **UX-2012**: The English last notice reads "It was planned for yesterday" (P246).
- **UX-2017**: The Pro screen's example is no longer Normal's free rhythm (P249; this was R1D-1).
- **UX-2019**: The «8» no longer wraps onto a line of its own: a no-break space sits before the hour, in ES, CA and EN (P251; this was R2D-1).

## Verified in code; a phone check is left (8)
- **UX-1907**: TalkBack is told the plan rows expand (P243).
- **UX-1905**: At 2× in «A tu manera», the stop control and Listo stay in view (P245).
- **UX-1808**: The offer names the task and the rhythm, and says «Sí, recuérdamelo» (P244; merged UX-2002).
- **UX-2003**: The offer only shows for tasks that ring on this phone alone (P244).
- **UX-2005**: Plan notices name the day and the hour (P246).
- **UX-2009**: Plan notices have no «Posponer 10 min» (P246).
- **UX-2004**: Old plan notices no longer pile up (P246).
- **UX-2010**: The last days' notices no longer depend on background work (P246).

## Still open
- **UX-2020** · S1 · D: In Spanish, the «a» now ends the line before «las 8», in both the Pro screen's example and the helper.
  - This was regression R3D-1 from P251. It was found in round 3, the last round.
  - The reviewer's fix: also put a U+00A0 between «a» and «las» (ES) and between «a» and «les» (CA), in both keys. The wording stays the same, and EN needs nothing. Update UX-1908's test literals and the preposition passed to `_expectHourKeptWithPreposition`.
  - It goes to the next run.
- **UX-2021** · S2 · B: While listening, «A tu manera»'s field hides the newest words.
  - The field is unfocused and capped at `maxLines: 4`. Render `sheet.your-way-listening-long.es.light.2x` ends at «…luego cada día, y el».
  - This change didn't cause it, and the reviewer asked for a ledger entry. I set the severity myself.
  - It goes to the next run.

## Escalations
None.

## Checks for the owner's phone
1. **UX-1907.** With TalkBack on, open «Hasta la fecha límite». The expanded state must not be read twice («desplegado … desplegado»).
2. **UX-1905.** At the largest font, dictate a long rhythm into «A tu manera» with the real microphone. The stop control, and then Listo, should stay in view.
3. **UX-1808.** With TalkBack on, the offer should read the task line, then the question, then «Sí, recuérdamelo» and «Ahora no».
4. **UX-2003.** Use two phones in one shared project. A task for «Todos» should get no offer, and «Sí» on a task assigned to you should ring only your phone.
5. **UX-2005.** Plan notices should show whole in the shade, in Spanish and Catalan, on a 24-hour phone and on a 12-hour phone.
6. **UX-2009.** «Completar» should be the only action on a plan notice, and it should complete the task from the shade. On iOS, the `plan_<lang>` category should register.
7. **UX-2004.** A «cada día» plan running over 3 days should leave one notice in the shade, also on a phone that delays background work.
8. **UX-2010.** On a battery-restricted phone, «Es mañana» and «Es hoy» should still arrive.

## Files changed
- **Screens:** `App/lib/screens/subscription_screen.dart`, `App/lib/screens/notification_settings_screen.dart`.
- **Widgets:** `App/lib/widgets/capture_review_editor.dart`, `App/lib/widgets/reminder_control.dart`, `App/lib/widgets/reminder_plan_sheet.dart`, `App/lib/widgets/reminder_ask_sheet.dart`, `App/lib/widgets/task_editor.dart`.
- **Services:** `App/lib/services/capture_store.dart`, `App/lib/services/reminder_plans.dart`, `App/lib/services/reminder_copy.dart`, `App/lib/services/reminder_engine.dart`, `App/lib/services/notification_service.dart`.
- **Text:**
  - `App/lib/l10n/app_en.arb`, `App/lib/l10n/app_es.arb`, `App/lib/l10n/app_ca.arb`, `App/lib/l10n/reminder_plan_words.dart`;
  - the generated catalogs, `App/lib/l10n/generated/app_localizations*.dart`.
- **Tests:** `App/test/reminder_plan_sheet_test.dart`, `App/test/reminder_plans_test.dart`, `App/test/reminder_plan_engine_test.dart`, `App/test/capture_recovery_test.dart`, `App/test/support/capture_fixtures.dart`.
- **Previews:** `App/test/ux_previews/reminders_previews.dart`, `App/test/ux_previews/settings_previews.dart`, `App/test/ux_previews/ux_previews_test.dart`.
- **Ledger:** `.claude/ux-review/ISSUES.md`.

## Which verified findings a test now protects
All 31:
- **Area A:** UX-1801 to UX-1811, UX-2016 and UX-2018.
- **Area B:** UX-1904 to UX-1910.
- **Area D:** UX-2003 to UX-2005, UX-2007 to UX-2012, UX-2017 and UX-2019.

Where the tests live:
- `App/test/reminder_plan_sheet_test.dart` has most of them.
- UX-2005 and UX-2012 are in `App/test/reminder_plans_test.dart`.
- UX-2004, UX-2009 and UX-2010 are in `App/test/reminder_plan_engine_test.dart`.
- UX-1811 is also in `App/test/capture_recovery_test.dart`.

Each ledger line gives the exact test lines.

## Rounds

| Round | Packages | Tests | Result | Regressions found |
|---|---|---|---|---|
| 1 | P241–P247, in 3 waves (3, 3, 1) | passed | 27 findings fixed (checks verify-r1-A, verify-r1-B, verify-r1-D) | R1A-1, which became UX-2016; R1D-1, which became UX-2017 |
| 2 | P248, P249, in 2 waves | passed | UX-2016 and UX-2017 fixed (checks verify-r2-A, verify-r2-D) | R2A-1, which became UX-2018; R2D-1, which became UX-2019 |
| 3 | P250, P251, in 2 waves | passed | UX-2018 and UX-2019 fixed (checks verify-r3-A, verify-r3-D) | R3D-1, which became UX-2020 and stays open |

The round summary listed UX-2018 and UX-2019 as both "fixed" and "unchecked". The round 3 checks say "fixed" for both, with code, test and render evidence, and no test failed. So both are recorded as verified.

## Reviewer notes (not counted as regressions)
- **UX-1804.** On the task's own day, once the plan's time has passed, the chip reads «Sin recordatorio», yet the engine still sends «Era para ayer» the next day. P241 settled this on purpose. If it confuses people, raise it with D1/D2.
- **UX-1906.** When a Pro account has kept words and the task now has a strength, the sheet opens on «A tu manera» while the ✓ is on «Hasta la fecha límite». The brief's rule says kept words win. This is rare.
- **UX-2018.** When reminders can't ring on this phone, the subtitle reads «Sin recordatorio · Activar». The brief chose this on purpose.
