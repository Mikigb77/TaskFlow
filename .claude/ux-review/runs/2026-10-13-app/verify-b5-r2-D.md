## UX verify — b5 round 2, area D (P75) — 2026-10-14
**Verdict:** Ship. All three findings are fixed in code and covered by passing widget tests. One polish regression: tapping the language that's already selected now does nothing.
**Evidence level:** code plus ux-tester's widget tests. No preview covers Ajustes, Idioma or Hora y región. The only renders (`App/artifacts/design/settings-*.png`, `regional-*.png`) date from 2026-09-22, older than the code (2026-10-14 04:55), so they aren't evidence. I didn't run Flutter.

### Results
**UX-481 · fixed (needs a phone)**
- `App/lib/screens/settings_screen.dart:17-55`:
  - SettingsScreen is now a `ConsumerStatefulWidget` with `WidgetsBindingObserver`.
  - `_readAccess()` reads `reminderAccessProvider.capability()` on init, on `resumed`, and after `await Navigator.pushNamed('/notifications')`.
  - A throw keeps the last answer.
  - Nothing requests the permission or calls `reconcile`.
- `:66-97`: when reminders are on and `_allowed == false`, the subtitle shows `Icons.notifications_off_outlined` (18 dp) plus `remindersBlocked` (`Expanded`, so it wraps at 2× text), both in `colors.error`. Otherwise it shows `remindersOnLead` / `remindersOff`. Until the first answer it shows today's subtitle.
- Strings in all three ARBs: EN `Blocked by your phone` / ES `Bloqueados por el teléfono` / CA `Bloquejats pel telèfon` (en:264, es:191, ca:170).
- Contrast: the error colour `#B44238` light / `#FFB4AA` dark (`lib/theme/app_theme.dart:30`) passes 4.5:1 on the surfaces. The icon means colour isn't the only signal.
- Tests pass: blocked, allowed, off, and resume without leaving the screen.
- Still needs a phone: revoke the permission on Android 13+ and return to Ajustes.

**UX-482 · fixed**
- `App/lib/widgets/language_selector.dart:85-133` now follows the Apariencia pattern:
  - `headlineSmall` heading with padding `fromLTRB(24,0,24,8)`;
  - a `RadioGroup<String>` with one `RadioListTile` per code, `contentPadding` horizontal 24, `ValueKey('language-$code')`, and `enabled: !_saving`;
  - inside a `SingleChildScrollView`.
- Removed: the close X, the tinted cards, the check icon and the `Semantics(selected:)` wrapper.
- The system row keeps the phone's language name as its subtitle.
- Renames done in all three ARBs: `languageAutomatic` reads `Same as phone` / `Como el teléfono` / `Com el telèfon`, and `languageFollowing` reads `… · {language}` (en:55-56, es:25-26, ca:26-27).
- Tests pass: RadioListTile rows with no close button, and Catalan at 2× text on 320×568 with no overflow and every row reachable.
- Note, not a regression: Idioma lists `Como el teléfono` first, while Apariencia (`settings_screen.dart:186-190`, frozen by the brief) lists it last. That was the case before this change too. If the owner wants the two sheets fully alike, move `ThemeMode.system` to the top of Apariencia.

**UX-422 · fixed**
- In all three ARBs (en:291/295, es:207/211, ca:186/190):
  - `timezoneHelp` is now one line: ES `Las tareas nuevas usan esta zona para entender las fechas.`
  - `timezoneFallback` reads ES `No se puede obtener la zona del dispositivo. Las tareas nuevas usarán {zone}.`
- No `captura` / `capture` is left in either key.
- The strings are used at `regional_settings_screen.dart:105` and `:112`. The capture sheet's banner (`voice_task_screen.dart:1573`) reads naturally with the new wording.
- Tests pass, including the grep check.
- Leftover, not visible: `regionalSettingsHelp` still says `zona de captura` / `capture timezone`, but no Dart code references it. The conventions ask to remove unused keys; that's housekeeping, with no user impact.

### Regressions
**R2D-1 · Severity 1 · Tapping the current language no longer closes the sheet**
- Where: `App/lib/widgets/language_selector.dart:100-126`, the Idioma sheet.
- The moment: "I opened Idioma and tapped Español to keep it… nothing happened. Is it stuck?"
- What happens:
  - Flutter's `RadioListTile._handleListTileTap` returns early when the row is already checked (`radio_list_tile.dart:619-622`), so `_choose` never runs.
  - The old `ListTile.onTap` re-saved and popped.
  - With the close X now gone too, the ways out are the scrim, a drag down, or system back. All of them are standard, but a newcomer may not know them.
  - The Apariencia sheet already behaves this way.
- Why it fails: feedback within 0.1 s for every tap (Nielsen #1, visibility of system status). A tap with no response is a small gulf of evaluation (Norman).
- Fix: in both sheets, close the sheet when the user taps the row that's already selected. For example, wrap each row so that a tap on the checked value calls `Navigator.pop(context)`. Keep the radio rows. No copy change.
- Verify: widget test — open Idioma with `Español` selected, tap `Español`, and the sheet is gone. Do the same for Apariencia with `Claro`.
- Evidence: verified in code (app code plus the Flutter 3.44 SDK source).

No other regressions in the changed files:
- Ajustes still shows 6 rows, with Recordatorios first.
- The Idioma row's subtitle reads `Como el teléfono · Español`, which matches the Apariencia row's `Como el teléfono`.
- The blocked row still opens Recordatorios, and that screen explains the fix.
