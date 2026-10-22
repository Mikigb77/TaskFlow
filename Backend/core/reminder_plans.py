"""Reminder plans: nudges about one task that come more often as its day approaches.

The contract with the app is docs/REMINDER_PLANS.md. The server checks a plan's shape, and
nothing else: the phone schedules it. A plan said while dictating is read in that dictation's own
AI call (reminders_prompt, in build_prompt in core/ai.py), for everyone. «A tu manera» in the
reminder sheet is read by POST /api/ai/reminder-plan/, for Pro (build_plan_prompt in core/ai.py).
"""
import json
import re
from datetime import timedelta

STRENGTHS = ("gentle", "normal", "intense")
MAX_PHASES = 4
MAX_DAYS = 366  # Also "from now on": the phone only schedules days still to come.
MAX_EVERY_DAYS = 30
MAX_SAID = 200
MAX_LEAD_MINUTES = 10080  # reminder_minutes, as the task field allows: a week.
PHASE_KEYS = ("from_days", "to_days", "every_days")
CLOCK = re.compile(r"([01]\d|2[0-3]):[0-5]\d")


class InvalidPlan(ValueError):
    """Why a plan's shape is refused, in words for the task API's 400."""


def _whole(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _check_phase(phase, number):
    if not isinstance(phase, dict) or set(phase) != set(PHASE_KEYS):
        raise InvalidPlan(f"Phase {number} has exactly from_days, to_days and every_days.")
    start, end, every = (phase[key] for key in PHASE_KEYS)
    if not all(_whole(value) for value in (start, end, every)):
        raise InvalidPlan(f"Phase {number}: from_days, to_days and every_days are whole numbers.")
    if not 0 <= end <= start <= MAX_DAYS:
        raise InvalidPlan(f"Phase {number}: to_days is at least 0, from_days at least to_days, "
                          f"and neither more than {MAX_DAYS}.")
    if not 1 <= every <= MAX_EVERY_DAYS:
        raise InvalidPlan(f"Phase {number}: every_days is from 1 to {MAX_EVERY_DAYS}.")


def check_plan(plan):
    """The plan, unchanged, when its shape is the contract's, and None for no plan. Otherwise
    InvalidPlan. A missing time means null, the all-day reminder time in Settings."""
    if plan is None:
        return None
    if not isinstance(plan, dict):
        raise InvalidPlan("A reminder plan is an object, or null.")
    kind = plan.get("kind")
    if kind not in ("rhythm", "custom"):
        raise InvalidPlan('kind is "rhythm" or "custom".')
    allowed = {"kind", "time"} | ({"strength"} if kind == "rhythm" else {"phases", "said"})
    unknown = sorted(set(plan) - allowed)
    if unknown:
        raise InvalidPlan(f"A {kind} plan has no {', '.join(unknown)}.")
    time = plan.get("time")
    if time is not None and not (isinstance(time, str) and CLOCK.fullmatch(time)):
        raise InvalidPlan('time is "HH:MM", 24-hour, or null.')
    if kind == "rhythm":
        if plan.get("strength") not in STRENGTHS:
            raise InvalidPlan('strength is "gentle", "normal" or "intense".')
        return plan
    phases = plan.get("phases")
    if not isinstance(phases, list) or not 1 <= len(phases) <= MAX_PHASES:
        raise InvalidPlan(f"phases is a list of 1 to {MAX_PHASES} phases.")
    for number, phase in enumerate(phases, 1):
        _check_phase(phase, number)
    said = plan.get("said")
    if said is not None and not (isinstance(said, str) and len(said) <= MAX_SAID):
        raise InvalidPlan(f"said is the words, at most {MAX_SAID} characters, or null.")
    return plan


def whole_number(value):
    """A whole number the model wrote, maybe as a string or as a float such as 3.0; else None."""
    if isinstance(value, str):
        try:
            value = float(value.strip())
        except ValueError:
            return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return value if _whole(value) else None


def lead_minutes(value):
    """reminder_minutes as the model wrote it: minutes before the task, from 1 up to a week. Anything
    else is None, so a slip drops the reminder, never the dictation. 0 too: a model that writes 0 for
    "nothing said" would otherwise move the reminder to the task's own start."""
    value = whole_number(value)
    return value if value is not None and 1 <= value <= MAX_LEAD_MINUTES else None


def _clock(value):
    """«9:00», «09:00» or «09:00:00» as "09:00"; None for no time; False for something else."""
    if value is None or (isinstance(value, str) and not value.strip()):
        return None
    if isinstance(value, str):
        match = re.fullmatch(r"\s*(\d{1,2}):([0-5]\d)(?::00)?\s*", value)
        if match and int(match[1]) < 24:
            return f"{int(match[1]):02d}:{match[2]}"
    return False


def read_plan(value, said=None, strengths=False):
    """A custom plan from what the model wrote, or None when it isn't a valid one. With strengths
    (a dictation), «until the day» with no rhythm said may also be a strength and no phases (D4).

    Tolerates the usual slips: numbers as strings, from_days and to_days the wrong way round, one
    phase without its list, «9:00». said, when given, is the person's own words (the reminder
    sheet's); otherwise the model's, kept only when they fit, and never cut."""
    if isinstance(value, str):
        try:
            value = json.loads(value)  # A plan written as a JSON string.
        except ValueError:
            return None
    if not isinstance(value, dict):
        return None
    if strengths and value.get("strength") in STRENGTHS and not value.get("phases"):
        time = _clock(value.get("time"))
        return None if time is False else {"kind": "rhythm", "strength": value["strength"], "time": time}
    if value.get("kind") not in (None, "", "custom"):
        return None
    phases = value.get("phases")
    if isinstance(phases, dict):
        phases = [phases]
    if not isinstance(phases, list):
        return None
    clean = []
    for phase in phases:
        if not isinstance(phase, dict):
            return None
        start, end, every = (whole_number(phase.get(key)) for key in PHASE_KEYS)
        if start is None or end is None or every is None:
            return None
        clean.append({"from_days": max(start, end), "to_days": min(start, end), "every_days": every})
    time = _clock(value.get("time"))
    if time is False:
        return None
    if said is None:
        words = value.get("said")
        said = " ".join(words.split()) if isinstance(words, str) else None
        if not said or len(said) > MAX_SAID:
            said = None  # The words are only shown in the sheet: the plan stands without them.
    plan = {"kind": "custom", "phases": clean, "time": time, "said": said}
    try:
        return check_plan(plan)
    except InvalidPlan:
        return None


def plan_answer(raw, said):
    """The plan in the model's answer to build_plan_prompt, with said set to the person's words.
    None when the words weren't about reminders, or what was read isn't a valid plan. ValueError
    when the answer isn't a JSON object at all."""
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
    answer = json.loads(raw)
    if isinstance(answer, list) and len(answer) == 1:
        answer = answer[0]
    if not isinstance(answer, dict):
        raise ValueError("The answer is not a JSON object.")
    # The envelope, or the plan itself when the model left the envelope out.
    value = answer["reminder_plan"] if "reminder_plan" in answer else answer if "phases" in answer else None
    return read_plan(value, said=said)


# How phases work, in both prompts: the dictation's and «A tu manera»'s.
PHASES_RULE = (
    "Each phase covers the days from from_days down to to_days before the anchor, with a reminder every "
    "every_days days counted back from to_days: on to_days, to_days + every_days, and so on up to from_days. "
    "Use 1 to 4 phases, 0 <= to_days <= from_days <= 366, and every_days from 1 to 30. A rhythm said without a "
    "start runs from now on: from_days 366. A rhythm also reminds on the day itself, to_days 0, unless the words "
    "exclude it; a single reminder said is just that one, one phase with from_days equal to to_days: 'una semana "
    "antes' is {\"from_days\":7,\"to_days\":7,\"every_days\":1}. time is the time of day said for the reminders "
    "(HH:MM, 24-hour), else null. "
)


def _json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _plan(phases, time, said):
    return {"phases": [dict(zip(PHASE_KEYS, phase)) for phase in phases], "time": time, "said": said}


def reminders_prompt(today):
    """The drafts prompt's section on reminders said while dictating, with examples in Spanish,
    Catalan and English whose dates come from the reference: today, in the person's time zone."""
    def day(offset):
        return (today + timedelta(days=offset)).isoformat()
    examples = (
        ("Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día",
         {"title": "Presentar el proyecto", "date": day(21), "reminder_plan": _plan(
             [(21, 8, 3), (7, 0, 1)], None, "cada 3 días las dos primeras semanas y luego cada día")}),
        ("Pagar el alquiler pasado mañana, recuérdamelo el día antes a las 9",
         {"title": "Pagar el alquiler", "date": day(2),
          "reminder_plan": _plan([(1, 1, 1)], "09:00", "el día antes a las 9")}),
        ("Entregar l’informe com a molt tard d’aquí a deu dies, recorda-m’ho cada dos dies",
         {"title": "Entregar l’informe", "date": None, "deadline_date": day(10),
          "reminder_plan": _plan([(366, 0, 2)], None, "cada dos dies")}),
        ("Dentist tomorrow at 5, remind me an hour before",
         {"title": "Go to the dentist", "date": day(1), "time": "17:00", "reminder_minutes": 60,
          "reminder_plan": None}),
        ("Renew the passport in two weeks, remind me every day the last week but not on the day",
         {"title": "Renew the passport", "date": day(14), "reminder_plan": _plan(
             [(7, 1, 1)], None, "every day the last week but not on the day")}),
        ("Terminar la solicitud en 10 días y recuérdamelo hasta la fecha límite",
         {"title": "Terminar la solicitud", "date": day(10), "deadline_date": None,
          "reminder_plan": {"strength": "normal", "time": None}}),
        ("Renovar el passaport, recorda-m’ho cada setmana",
         {"title": "Renovar el passaport", "date": None, "reminder_plan": _plan([(366, 0, 7)], None, "cada setmana")}),
    )
    return (
        "Reminders: each task also has reminder_minutes and reminder_plan, both null unless the user asks to be "
        "reminded about it ('recuérdamelo', 'avísame'; Catalan 'recorda-m’ho', 'avisa’m'; English 'remind me'). "
        "Minutes or hours before the task are reminder_minutes, an integer: 'una hora antes' is 60, also for a "
        "task said without a time. "
        "A rhythm of reminders, or reminders some days before, is reminder_plan: an object with phases, time and "
        "said, counted back from the task's anchor, which is its deadline_date when it has one, else its date. A task "
        "with neither yet still keeps every reminder asked for: write its reminder_plan or reminder_minutes as usual, "
        "and they count back from the day it gets later. "
        + PHASES_RULE +
        "said is the user's words saying when to remind, as said, without the request itself ('recuérdamelo'); "
        "those words never go in the title or notes. A reminder plan counts down to one task's day: something to do "
        "every day or every week is a repeating task, and a repeating task has no reminder_plan. Reminders until "
        "the task's day or deadline with no rhythm said ('recuérdamelo hasta la fecha límite', 'hasta entonces'; "
        "Catalan 'fins al termini', 'fins aleshores'; English 'until the due date', 'until then') are reminder_plan "
        "{\"strength\":\"normal\",\"time\":null} with no phases; a time said for them goes in time. Those words "
        "name no deadline of their own: a task said for a day keeps that day as its date, with no deadline_date. "
        + "".join(f"Example: '{words}' has {_json(task)}. " for words, task in examples) +
        "'Recorda’m prendre la pastilla cada dia' is a daily repeating task from today, not a reminder plan.\n"
    )
