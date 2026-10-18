# Owner decisions — the website

Every agent in the UX web loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

The app's decisions are in `.claude/ux-review/DECISIONS.md`. They bind the site too: the site may only say what the app does, and anything open there is open here.

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
- Nothing recorded for the site yet. The first whole-site run's `plan.md` lists the questions it raises.
- The app's open items bind the site too: see the Open section of `.claude/ux-review/DECISIONS.md`. Account deletion and the clean-up of completed tasks are listed there, and the privacy and delete-account pages must match whatever is chosen.
