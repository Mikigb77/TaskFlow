# Owner decisions — the website

Every agent in the UX web loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

The app's decisions are in `.claude/ux-review/DECISIONS.md`. They bind the site too: the site may only say what the app does, and anything open there is open here.

## 2026-10-21 (evening) — WD18 and WD19 of run 2026-10-21-changes
The owner answered both, and not as recommended («not now» for both):
- **WD18, changing many tasks at once beyond the FAQ:** "Yes, on the card". One sentence on the «Say several things at once» card says that voice can also move or finish many tasks at once, as in «move all of yesterday's tasks to tomorrow». The hero stays as it is. The FAQ's voice answer still names it too (WP53).
- **WD19, the other ways into TaskFlow:** "Yes, briefly". One short line, or one FAQ answer, names the home-screen widget, the launcher shortcuts and sharing a message from another app such as WhatsApp. Each is named as the app shows it in that language (the widget and shortcuts say «Dictate a task» in English since 2026-10-21; see `.claude/ux-review/DECISIONS.md`).
- Both stay short, in English, Spanish and Catalan, and the live demo still only adds tasks.

## 2026-10-21 — WD17: completion belongs above the complete task group
The owner clarifies that the final all-clear / take-a-breath message should apply across all generated tasks: show it on top, in front of the task list, rather than inside the final task. This corrects the placement chosen for WD16 and authorizes a bounded group-level banner change, with tasks/details and undo retained. The owner also requests an explanation and assessment of the earlier layout changes; that does not authorize a broader redesign. Existing EN/ES/CA completion copy remains.

## 2026-10-21 — WD16: a warm completion moment in the live demo
The owner requests a rewarding, emotionally warm response after a visitor marks every generated demo task complete, to convey a feeling they want daily from the app. The current request authorizes local completion controls and feedback in this demo journey. The primary session’s bounded implementation brief keeps the existing card and completed tasks visible, permits undo/retry, excludes account saving, additional voice requests, quota changes and new download/subscription capabilities, and clears feedback on undo, new results and reset. Those details are the implementation constraints for this run, rather than a broader change to product policy.

WD16 supersedes WEB-7’s earlier no-ticking rule for generated demo results; WEB-7’s historical record remains intact.

This is the current bounded request. The temporary owner-away authority below is historical and does not apply to new work.

## 2026-10-18 (night) — The owner is away: the main session decides, records and moves on
**The owner, before leaving:** "whatever question you have for me, whatever decisions, even if it concerns the product, just for now, record what decision you made, what was your recommendation, and you move forward with your recommendation… you are on your own… prioritize completing everything to the best degree possible."

What that means for the loop:
- The main session answers each decision here, and the loop builds it.
- Whole-site runs don't stop for approval.
- Everything is reversible. He reviews it afterwards; the summary is `.claude/AWAY-2026-10-18.md`.
- Unchanged: never push, never deploy, never commit or revert the other session's work in TaskFlowWeb. Edits to its files stay uncommitted for him.

The owner also asked that the reviewers get every tool they need before they judge ("we cannot compromise the quality"). Then they recheck their areas:
- the live demo in every state, with the API stubbed;
- 200% text, zoom and 320 px renders;
- a measured audit: axe, target sizes, contrast, a screen-reader snapshot, the keyboard path, lab speed;
- WebKit renders if possible.

**Run 2026-10-18-site, WD1–WD13 (details in its `plan.md`), decided as recommended unless noted:**
- **WD1 — the sample walkthrough (`#demo`):** removed. One static example takes its place in the live demo's intro: the spoken "Tomorrow, call the dentist and buy bread." and its two task cards. It shows without JavaScript, and whenever the live demo can't run.
- **WD2 — free and Pro on the site:** yes, without a price and without "100 MB":
  - 10 dictations a month without Pro;
  - tasks by hand with no limit;
  - TaskFlow Pro, monthly, for unlimited dictation and file space.

  It goes in the FAQ, in one line in the closing card and in one line after the demo, in three languages.
- **WD3 — editing the legal documents:** yes. The privacy policy gains:
  - the email codes;
  - the first name from Google;
  - speech recognised on the phone;
  - phone calendars staying on the phone;
  - «Creada por».

  The jargon, the Catalan «Eliminar» and "Versión 2026-10-16" are fixed, and `company.version` moves to the edit date. These are the other session's untracked files, so the changes stay uncommitted for his sign-off.
- **WD4 — the hero image and the link preview:** the Calendar with the hero card's example done: "Call the dentist" and "Buy bread" on tomorrow, with the one «Añadir tarea» button. One image per language and theme (6 PNGs, 780 × 1688), rendered by the main session from the app.
- **WD5 — the language of the bare `/`:** chosen from the browser's language on `/` only, never from the IP, falling back to English.
  - A choice made in the language switch is remembered in the browser and always wins.
  - Privacy §8 says so (with WD3).
- **WD6 — "A little focus. A little flow.":** dropped from the footer.
- **WD7 — Android only:** the site says "for Android phones". The Apple mentions go from the legal pages (with WD3), and the app's own "Android and iOS" line goes through /ux.
- **WD8 — the live demo against the free app:** kept as it is; its tries are labelled as the demo's. Once UX-616's route is deployed, the demo gets the same one.
- **WD9 — "tell me when it launches":** not yet. Use Play pre-registration once the package ID is final.
  - The research (second pass) found a Spanish "Pre-register" badge but no Catalan one, so /ca/ would use a text link.
- **WD10 — a family-sharing section:** not now; the FAQ answer is rewritten instead.
- **WD11 — Privacy and Terms inside the app:** yes, at sign-up and in Ajustes, through /ux. It's recorded in `.claude/ux-review/DECISIONS.md`.
- **WD12 — backup retention, and paid or free Gemini:** only the owner knows these.
  - The site states nothing new about backup windows or model training; today's cautious wording stays ("no prometemos retención cero").
  - Ask him when he's back.
- **WD13 — publishing:** the site goes out together with, or after, the app and backend it describes. Play Console gets `/delete-account/`. Nothing is deployed now.

**From the recheck (2026-10-19), decided the same way:**
- **WD14 — "unlimited" and its safety limit:** yes, once, in the FAQ only.
  - After "unlimited dictation and file space" it says EN "(with a safety limit of 50 dictations a day)", ES «(con un límite de seguridad de 50 dictados al día)», CA «(amb un límit de seguretat de 50 dictats al dia)».
  - The closing card and the line under the demo keep WD2's short wording.
  - Raising the shared 200-a-day dictation budget before launch is the owner's: it's a server setting in `Backend/config/settings.py`, which another session is editing.
- **WD15 — thin type in WebKit:** treated as an artifact of Playwright's WebKit build for Windows. Nothing changes.
  - The site's `@font-face` already declares the variable font's weight range (`font-weight: 200 800`, `src/styles/global.css:7`), and Safari on iOS has supported variable fonts since iOS 11.
  - Reviewers: weight differences in `webkit/` aren't findings unless they're seen on a real iPhone.
  - The owner can confirm on his iPhone (/, /es/privacy/ and a missing page) when he's back.

**Also decided:**
- **Analytics:** none before launch.
  - At launch, the first choice is server-log or first-party audience measurement within the AEPD's 2024 conditions (the guide's PV-6 and FN-9): no consent banner, own audience only, anonymous, cookies at most 13 months.
  - Whether a given tool qualifies is a legal check for him.
- **The Android trademark line** ("Android is a trademark of Google LLC." and ™ on first use): added wherever the site names Android.
  - Approval by Google's Android brand team is his action, at launch.

## 2026-10-18 — What the website is for, and how the UX web loop runs
The owner asked for a review-and-fix loop for the website, as thorough as the app's. His goals, paraphrased:
- **The website is the entry point.** Many people will only know TaskFlow through it, so their experience must be flawless.
- **The journey must be seamless:** seeing TaskFlow on the web → downloading the app → getting into the app → thinking "this feels amazing" → buying Pro.
- **The site teaches; the app provides.** The web must not provide what the app provides. It teaches what TaskFlow can do and makes people think "I really need this app".
- **The site stays faithful to the app.** When app features change, the web reflects them.
- **What he wants from the loop:** a check of whether the web is built correctly, the corrections it needs, and a visual improvement.
- **Google Play isn't published yet.** A download page waits until the app is on Google Play. Until then, the calls to action must be honest.

How the loop runs, the same policy as the app's:
- Fix everything the reviewers find **except product decisions**, at every severity, 1 to 4.
- Stop for the owner's approval only on whole-site runs (`/ux-web site`). Scoped runs fix straight away.
- Commit each verified round on `dev`, in each repo: the site's files in TaskFlowWeb, the loop's records in the app repo. Never push, and never deploy.
- From the loop's brief (main session, 2026-10-18):
  - the site's copy is written in English, Spanish and Catalan, as the app's is (CLAUDE.md, "Text");
  - the reviewer and organizer run at max effort, the implementer and tester at high, all on Opus;
  - another session has uncommitted work in TaskFlowWeb (the legal pages and content, docs, `Dockerfile`, `package.json`, `src/app/layout.tsx` and more). The loop never commits, stages or reverts it.

## Standing decisions
- The decisions in the 2026-10-18 entry above.

## Open — not decided; anything that depends on these is a decision, not a fix
- WD1–WD13 of the first whole-site run were decided by the main session on 2026-10-18 (night); see the top. Still for the owner: WD12's two facts, the legal checks, and the Android brand approval at launch.
- The app's open items bind the site too: see the Open section of `.claude/ux-review/DECISIONS.md`. Account deletion and the clean-up of completed tasks are listed there, and the privacy and delete-account pages must match whatever is chosen.
