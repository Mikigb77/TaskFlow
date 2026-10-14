# Capture-speed review: the brief

The main session wrote this on 2026-10-14 for the focused review the owner asked for ("don't stop until… the UX/UI is as perfect as we can get it"). It runs after the free tier's app half (P81–P84), as `/ux` in screens mode on area A, with the text below as the reviewer's notes.

## Notes for the reviewer

Focused review: **capture speed**. Speed is the owner's selling point (DECISIONS.md, top).
- Creating a task must be super quick, with as little interaction as possible beyond the time spent speaking. About 5 seconds is a guide, not a hard number.
- Creating several tasks in a row (2, 3, 4, 5) must stay just as fast.
- Capture must feel clearly faster than typing.
- The north star still holds: a first-time, non-technical user must manage it without help.

Walk these paths in the code and the renders. Count every tap, wait, screen change, animation and decision between the first touch and a saved task:
1. From Calendar, cold start and warm: one spoken task with a date.
2. Three tasks in a row:
   - one dictation that holds three tasks;
   - three separate dictations back to back. Where does the user land after each save, and how many taps until listening starts again?
3. The same with typing: a free account after its 10 dictations (P81–P82), and the offline path.
4. From the home-screen widget and the launcher shortcut.
5. A task the assistant got wrong: the fastest way to correct it.

What to report:
- every avoidable tap, wait, animation, confirmation or screen, with the time it costs;
- anything that makes a first-time user hesitate;
- concrete fixes.

Don't propose new settings. Subtract before adding.

Some things only a phone can measure, such as how long the mic takes to start or how long the recognizer takes to finish. Report those as device-check findings, each with a concrete measuring step.
