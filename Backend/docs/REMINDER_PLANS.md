# Reminder plans

Decided by the owner on 2026-10-22 (`.claude/ux-review/DECISIONS.md`, «Reminder plans»). A reminder plan nudges about one task more and more often as its day comes closer: «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día». It's never a copy of the task: the task stays one row on its day, and the plan only sends notifications about it.

## Who gets what

| | Free | Pro |
|---|---|---|
| «Hasta la fecha límite» with Suave, Normal or Intenso, worked out on the phone | yes | yes |
| A rhythm said while dictating a task, read in that dictation's own AI call | yes | yes |
| «A tu manera» in the reminder sheet: a rhythm typed, or said and recognised on the phone, read by `POST /api/ai/reminder-plan/` | no: a Pro badge; tapping it opens the Pro screen with «Con Pro, tus recordatorios a tu manera» | yes |

No other AI call is added for anyone.

## The anchor

The plan counts back from the task's **deadline** when it has one, otherwise from the task's **own day** (its planned day). Most tasks only have a day: the owner, "the deadline most of the time … will be the same as the task". A task with neither has no plan, and the sheet doesn't offer one.

- Moving the anchor, by hand or by voice, moves the whole plan, because it's counted back from the anchor.
- Marking the task done cancels every reminder left. Undoing that brings them back.
- A repeating task has no plan in this first version: the sheet offers only what it offers today.

## The field: `reminder_plan`

A task field, synced like the others: `null`, or

```json
{"kind": "rhythm", "strength": "normal", "time": null}
{"kind": "custom", "phases": [{"from_days": 21, "to_days": 8, "every_days": 3},
                              {"from_days": 7, "to_days": 0, "every_days": 1}],
 "time": "09:00", "said": "cada 3 días las dos primeras semanas y luego cada día"}
```

| Key | Meaning |
|---|---|
| `kind` | `"rhythm"`: one of the three strengths. `"custom"`: the phases as read from the person's words. |
| `strength` | `rhythm` only: `"gentle"` (Suave), `"normal"` or `"intense"` (Intenso). |
| `phases` | `custom` only: 1 to 4 phases. Each covers the days from `from_days` down to `to_days` before the anchor (`from_days` ≥ `to_days` ≥ 0, at most 366), with a reminder every `every_days` days (1 to 30), counted back from `to_days`: on `to_days`, `to_days + every_days`, and so on up to `from_days`. |
| `time` | `"HH:MM"`, the time of day for every reminder of the plan, in the person's time zone. `null`: the reminder time for all-day tasks in Settings. |
| `said` | `custom` only: the words as typed or said, shown in the sheet. At most 200 characters. |

The three strengths, as phases (366 means "from now on"; only days still to come are scheduled), each with a reminder on the day itself:

| Strength | Phases |
|---|---|
| Suave (`gentle`) | every 7 days down to 4 days before, then daily for the last 3 days and the day |
| Normal (`normal`) | every 3 days down to 8 days before, then daily for the last 7 days and the day |
| Intenso (`intense`) | every 2 days down to 15 days before, then daily for the last 14 days and the day |

- A plan replaces the single reminder: with a plan, `reminder_minutes` and `reminder_time` are left as they are but not used. The sheet's choices are exclusive: no reminders, once (today's single reminder), until the day (a strength), or «A tu manera».
- The server checks the shape, and nothing else: the plan is the phone's to schedule.

## The notifications

- **Each one is a notification about the task:** its title, and how far the day is: «Presentar el proyecto · faltan 12 días», «… · es mañana», «… · es hoy». Tapping it opens the task, as today's reminders do.
- **After the day, if the task isn't done:** one last notice the next day, then nothing more. It says «… · era para ayer» for a task with only a day, and «… · venció ayer» for a task with a deadline (the owner's choice).
- **Scheduling:** the phone schedules only the next few reminders of each plan, not the whole plan. It plans them again when the app starts, when the task changes, and when one fires, so a long plan never fills Android's alarm limit.
- **Settings:** reminders turned off in Settings silence plans too, as they silence single reminders.

## The sheet and the task (app)

- **On the task:** one line, only when there's a plan: «🔔 Cada 3 días, y a diario la última semana · próximo: sáb 25». A strength reads «Cada vez más a menudo hasta el jue 12».
- **The reminder sheet:** the choices above, then the preview of whichever is chosen: the plan in words, a strip of dots from today to the anchor, and «N avisos · el próximo sáb 25, 9:00».
  - **The strengths:** Suave, Normal and Intenso sit under «Hasta la fecha límite».
  - **«A tu manera»:** a text field with a microphone, «Escríbelo o dilo como se lo dirías a alguien.» The words go to `POST /api/ai/reminder-plan/`, and the preview updates. It needs a connection; offline it says so, and the strengths still work.
- **The offer:** after saving a task whose anchor is 14 or more days away, with no plan, the reminder question offers one: «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?», where «Sí» sets Normal. It's asked at most once per task, and never when reminders are off.
- **The capture's review card:** a plan read from a dictation shows as its one line, like the other details. Tapping it opens the same sheet.

## The dictation (drafts)

The drafts endpoint (`POST /api/ai/drafts/`) reads reminders said while dictating, for everyone:
- **A rhythm, or a reminder some days before:** the draft gets `reminder_plan` with `kind` `"custom"` and its `phases`, counted back from the draft's anchor (its deadline, else its day). A rhythm also gets a reminder on the day itself, unless the words exclude it. A single reminder said is just that one: «recuérdamelo el día antes a las 9» is one phase, `{"from_days":1,"to_days":1,"every_days":1}`, at `"09:00"`.
- **A reminder some minutes or hours before a timed task** («una hora antes»): the existing `reminder_minutes`, 60.
- **No anchor, or nothing said about reminders:** neither key is set.

## «A tu manera»: `POST /api/ai/reminder-plan/`

Pro only. It reads one rhythm typed or said in the reminder sheet:

```json
{"text": "cada 3 días y la última semana a diario", "timezone": "Europe/Madrid",
 "reference_time": "2026-10-22T10:00:00Z", "anchor_date": "2026-11-12", "language": "es"}
```

| Answer | When |
|---|---|
| `200 {"reminder_plan": {...}}` | The words describe reminders: a `custom` plan, with `said` set to the words. |
| `200 {"reminder_plan": null, "issue": "unclear"}` | The words don't describe reminders. The sheet asks for them again. |
| `402 {"code": "pro_required"}` | Not Pro. |

It uses the same throttle and daily AI budget as dictation, and doesn't count as a dictation.
