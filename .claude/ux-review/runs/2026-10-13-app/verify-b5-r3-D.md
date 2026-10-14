## UX verify — run 2026-10-13-app, batch 5 round 3, area D (P76) — 2026-10-14
**Verdict:** UX-483 is fixed in code and by tests. The only thing left is the TalkBack check on a phone. No regressions.
**Walked:** Ajustes › Idioma (tap the current language, tap another language), Ajustes › Apariencia (tap the current theme, tap another), and Iniciar sesión › language button (same sheet). Personas: newcomer and TalkBack user.
**Evidence level:** code, the Flutter SDK source (3.44.5 at C:\Users\mikig\Desktop\Custom\Flutter\flutter), and the ux-tester widget tests. No preview covers these sheets, so there was no render to read.

### UX-483 · fixed (needs a phone for TalkBack)
- Idioma, `App/lib/widgets/language_selector.dart:100-108,121`. Every `RadioListTile` now has `toggleable: true`. In `onChanged`, a non-null value still calls `_choose(value)`, and `null` pops the sheet only when `!_saving`. The `null` branch doesn't save, doesn't call `TaskReminders.refreshLanguage()` and shows no message.
- Apariencia, `App/lib/screens/settings_screen.dart:173-181,201`. Every row has `toggleable: true`, and `null` now pops the sheet and returns. Choosing a different option still pops, then `setMode`, then `appearanceError` if that fails.
- How the SDK behaves:
  - `RadioListTile._handleListTileTap` (radio_list_tile.dart:619-629) now sends `null` when the checked row is tapped.
  - `RawRadio.value` (raw_radio.dart:191) is still `widget.value == groupValue`, a non-null bool. Turning on `tristate` therefore doesn't make the radio draw as "mixed" or empty.
  - The semantics are unchanged: `checked` plus `inMutuallyExclusiveGroup` (raw_radio.dart:220-222).
  - The implementer took the `toggleable` route, which the brief allowed.
- Tests: `App/test/settings_screen_test.dart:745-930`. They run in Spanish through MyApp › Ajustes and cover all five widget-test checks:
  - tapping the current choice closes the sheet with 0 store writes and no snackbar;
  - choosing another option saves exactly once;
  - the checked row reads isChecked inside a mutually exclusive group, and the other rows read unchecked.
- Code check: neither sheet has an `IconButton` or a close icon, so there's still no X. The copy keys haven't changed: `language`, `languageAutomatic`, `appearance`, `light`, `dark`, `deviceDefault`. The keys, row order, paddings and SingleChildScrollView are the same as before.
- Still needs a phone: with TalkBack on, the current language should be announced as selected, and double-tapping it should close the sheet.

### Regressions
None.
- The sign-in screen's language button (`App/lib/screens/login_screen.dart:286`) opens the same sheet. Tapping the current language there now closes the sheet too, which is the intended behaviour.
- While a save is running, the rows are disabled (`enabled: !_saving`), so a second tap can't pop the sheet in the middle of the save.
- Swiping the sheet down and tapping outside it still close it, as before.

### Memory notes
- Settled pattern for single-choice sheets (Idioma, Apariencia):
  - `RadioGroup` plus `RadioListTile` with `toggleable: true`;
  - tapping the current choice closes the sheet and saves nothing;
  - drag handle, no close X.
  Any future choice sheet should follow the same pattern.
