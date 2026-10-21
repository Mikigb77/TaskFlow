# Run 2026-10-19-app: batch b5 on the review emulator (2026-10-21)

**Evidence level: emulator.** TaskFlow_Review: Android 16, Pixel 4 profile at about 393 dp, Pixel Launcher. There's no real voice, and it isn't a physical phone. The APK is 6ea4ab0, batch b5's app code, built from a clean worktree. The backend is the local Docker API at cf39f6e, which has the recovery half. The run captured 150 PNGs in 51 minutes, with nothing missing, into `App/build/ux/device/`.

The lane now adds one local phone calendar, «Trabajo», with two of today's events (6ea4ab0), so D7 has calendars to tick.

## Confirmed on the emulator
| Finding | What the capture shows | Capture |
|---|---|---|
| UX-1611 (D7, P188) | After «Permitir», the screen says «Conectado. Los eventos se ven en Calendario.» and «Trabajo» is ticked. Calendar's today then shows «2 eventos · 10:00 · 17:00». | `permission-calendar.allowed.es.*`, `permission-calendar.calendar-after.es.*` |
| UX-1651 (P217) | Under the list there's one outlined «Actualizar calendarios» and a text link, «Ocultar eventos del calendario». | `permission-calendar.allowed.es.light.1.0` |
| UX-1316 (P186), ES and CA | At 2.0 the shortcuts read «Dictar» and «Escribir», and «Dicta» and «Escriu». The widget reads «Dictar una tarea» and «Dicta una tasca», all whole. This was SEEN #12, now fixed. | `launcher.shortcuts.{es,ca}.light.2.0`, `widget.home.{es,ca}.*.2.0` |
| UX-1319 (P186), in part | The too-long share message is whole: «Texto demasiado largo. Comparte uno más corto.» This was SEEN #8. The empty-share message is captured too; the other two of the four aren't. | `share.too-long-toast.es.light.1.0`, `share.empty-toast.es.light.1.0` |
| SEEN #10 | Tapping a reminder opens the task's own page («Tarea · Pagar la luz»), not the calendar's day. | `notification.tap-landing.es.light.1.0` |

## Not fixed in English: the launcher shortcuts at 2.0 (a new finding, for batch b7)
- **What the captures show:** at 2.0 the English shortcuts read «Say a ta…» and «Type a t…» (`launcher.shortcuts.en.light.2.0`). At 1.0 they're whole («Say a task», «Type a task»), and the English widget is whole at 2.0.
- **Why:** P186 gives each shortcut a short label («Dictate», «Type») and a long one. The Pixel Launcher shows the long label whenever it judges it fits, and at 2.0 that judgment is a few characters too generous.
  - Spanish and Catalan long labels are 15–18 characters, clearly too long, so the launcher falls back to the short ones.
  - The English ones are 10–11 characters: they pass the launcher's check, and then get cut.
- **Options for the fix:**
  - (a) English long labels long enough to fall back like ES and CA, for example «Dictate a task». The text label is the harder one: «Type a task» is 11 characters.
  - (b) English long labels equal to the short ones, «Dictate» and «Type», at every size.
  - Either way, the labels at 1.0 shouldn't get worse.

## Not covered by the lane (still phone or TalkBack checks)
- **UX-1621:** the app's language differs from the phone's. The lane switches the phone's language, not the app's.
- **UX-1649 and UX-1653:** language switches.
- **UX-1605:** Recordatorios right after allowing alarms. The journey wasn't run this time.
- **UX-1607:** Do Not Disturb.
- **UX-1612 and UX-1648:** TalkBack on Cuenta and on Activity.
- **UX-1652:** reduced motion.

## Noticed, for the next review
- Calendarios del teléfono: the help paragraph above the list is long and technical: «Selecciona hasta 50 calendarios. Las horas siguen la zona de tu dispositivo; los eventos de día completo conservan sus fechas originales.».
- The launcher icon is still the old «M» in a white disc (P195 in b7, D8), and so is the small icon in the share messages.
