# Reminder plans

Decided by the owner on 2026-10-22 (`.claude/ux-review/DECISIONS.md`, «Reminder plans», and his answers to D1–D7 of run 2026-10-22-changes the same evening). A reminder plan nudges about one task more and more often as its day comes closer: «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día». It's never a copy of the task: the task stays one row on its day, and the plan only sends notifications about it.

**Every reminder is personal.** A plan rings only for the person who set it, and each member of a shared project can set their own on the same task (D6). The single reminder is personal too, with its lead, its time and what it counts from: one person's change never reaches anyone else's phone (the owner, 2026-10-23).

## Who gets what

| | Free | Pro |
|---|---|---|
| «Hasta la fecha límite» with Suave, Normal or Intenso, worked out on the phone | yes | yes |
| A rhythm said while dictating a task, read in that dictation's own AI call | yes | yes |
| «A tu manera» in the reminder sheet: a rhythm typed, or said and recognised on the phone, read by `POST /api/ai/reminder-plan/` | no: a Pro badge; tapping it opens the Pro screen with «Con Pro, tus recordatorios a tu manera» | yes |

No other AI call is added for anyone.

## The anchor

The plan counts back from the task's **deadline** when it has one, otherwise from the task's **own day** (its planned day). Most tasks only have a day: the owner, "the deadline most of the time … will be the same as the task". A task without a deadline treats its own day, and its time, as the deadline, so «Hasta la fecha límite» means until that day (D4). A task with neither has no plan, and the sheet doesn't offer one.

- Moving the anchor, by hand or by voice, moves the whole plan, because it's counted back from the anchor.
- Marking the task done cancels every reminder left. Undoing that brings them back.
- A repeating task has no plan in this first version: the sheet offers only what it offers today.

## The field: `reminder_plan`

Each person's own reminders for a task. The server keeps one row per person and task (`TaskReminder`), and the task API shows it as the task's four reminder fields, always those of the account asking:

| Field | Meaning | Default |
|---|---|---|
| `reminder_minutes` | Minutes before a timed task; `-1` is no reminder | `null`: the lead in Settings |
| `reminder_time` | A date-only task's reminder time, in minutes after midnight | `null`: the time in Settings |
| `reminder_anchor` | What the single reminder counts from: `"planned"` or `"deadline"` | `"planned"` |
| `reminder_plan` | The plan, below | `null`: no plan |

- **Reading:** every task answer carries your own values, or the defaults. Nobody sees anyone else's.
- **Writing:** a task `PUT` sets your own values for the fields it sends. A field it leaves out stays as it is. Back at every default, the row goes.
- **A change to your reminders alone isn't a change to the task:** no new `version`, no activity entry, no notification to the project. Your other phones get it at their next sync, which reads every task anyway. A `PUT` whose `version` is stale still saves your reminders before it answers 409.
- **Readers too (D9, the owner, 2026-10-31):** a «lector» chooses their own reminders like anyone. A reader's `PUT` that changes only their reminders is saved as above; any other change from a reader is still refused with 403, and so is a new task in the project.
- **The deadline:** `reminder_anchor` `"deadline"` is refused for a task without one. When someone removes a task's deadline, everyone's reminders on it count from the planned start again.
- **Reminders chosen before they were personal** went to the person whose phone rang for the task: the person it's given to, else its creator, else its owner (plans in migration 0024, single reminders in 0025). Everyone else has their defaults.

The plan is `null`, or

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

The three strengths, as phases, each with a reminder on the day itself. They start at most 4 weeks (28 days) before the day, so a far task never gets more than a few weeks of them (D2). Only days still to come are scheduled.

| Strength | Phases | At most |
|---|---|---|
| Suave (`gentle`) | every 7 days from 28 down to 4 days before, then daily for the last 3 days and the day | 8 |
| Normal (`normal`) | every 3 days from 28 down to 8 days before, then daily for the last 7 days and the day | 15 |
| Intenso (`intense`) | every 2 days from 28 down to 15 days before, then daily for the last 14 days and the day | 22 |

A rhythm the person says or types (`custom`) is kept as said, however far back it reaches, up to 366 days: "if you specifically say it" (D2). A rhythm said without a start runs from now on.

- A plan replaces the single reminder: with a plan, `reminder_minutes` and `reminder_time` are left as they are but not used. The sheet's choices are exclusive: no reminders, once (today's single reminder), until the day (a strength), or «A tu manera».
- **Except on the day of a timed task (D1).** A task with a time, or a deadline with a time, gets that day's notice at the single reminder's moment: its own lead (`reminder_minutes`, when it's 0 or more), else «Tareas con hora» (10 minutes by default), in the single reminder's words («Hoy a las 17:00 · en 10 min»). The earlier days keep the plan's time, and the number of notices doesn't change.
- **A time of the plan's own stays (D8).** A plan whose `time` was said or typed («recuérdamelo el mismo día a las 9», «cada día a las 8») keeps that time on the task's day too. Only a plan without a time of its own (a strength, «Sí» to the offer, a rhythm said without an hour) moves the day's notice as D1 says.
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
- **The offer:** after saving a task whose anchor is 14 or more days away, with no plan, the reminder question offers one: «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?», where «Sí» sets Normal. It's asked at most once per task, and never when reminders are off. After two «Ahora no» in a row on this phone it's no longer asked; «Hasta la fecha límite» stays in every task's sheet (D5).
- **Shared tasks (D6, and the single reminder since 2026-10-23):** the reminder choices show wherever the task's reminders ring on this phone: a personal task, a «Todos» task, one given to you, and an unassigned one in a project you manage, for readers too (D9). They don't show on a task given to someone else, whose reminders are theirs and never sent to this phone. On a shared task the sheet says that its reminders ring only for you, and the offer can come for it too, since «Sí» sets only your own plan.
- **The capture's review card:** a plan read from a dictation shows as its one line, like the other details. Tapping it opens the same sheet.

## The dictation (drafts)

The drafts endpoint (`POST /api/ai/drafts/`) reads reminders said while dictating, for everyone:
- **A rhythm, or a reminder some days before:** the draft gets `reminder_plan` with `kind` `"custom"` and its `phases`, counted back from the draft's anchor (its deadline, else its day). A rhythm also gets a reminder on the day itself, unless the words exclude it. A single reminder said is just that one: «recuérdamelo el día antes a las 9» is one phase, `{"from_days":1,"to_days":1,"every_days":1}`, at `"09:00"`.
- **A reminder some minutes or hours before a timed task** («una hora antes»): the existing `reminder_minutes`, 60.
- **Until the day, with no rhythm said** («recuérdamelo hasta la fecha límite», «hasta el jueves», «fins al termini», "until the due date"): `{"kind": "rhythm", "strength": "normal", "time": null}`, the same as Normal in the sheet, counted back from the anchor. A task that only has a day counts back from that day (D4).
- **No anchor (D3):** a reminder said for a task with neither a day nor a deadline isn't dropped. The draft keeps its `reminder_plan` (counted back from whatever day the task gets) or its `reminder_minutes`, and gets `"reminder_needs_day": true`. The card says «Para recordártelo, ponle un día.» under the date, and tapping it opens the date. Once the task has a day, the reminder said applies; saved without one, it's dropped.
- **Nothing said about reminders:** neither key is set.

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
