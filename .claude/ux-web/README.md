# The UX web loop

One command reviews TaskFlow's marketing website, fixes what it finds, and checks the fixes. It's the app's UX loop (`.claude/ux-review/README.md`) adapted to the website, with one more duty: the site must tell the truth about the app. By default it looks only at what changed since the last web review, on the website and in the app features the website describes.

## Commands

| Command | What it does |
|---|---|
| `/ux-web` | Reviews what changed since the last web review, fixes it, re-checks, and commits. |
| `/ux-web site` | Reviews the whole website, then **stops at the plan** for your approval. |
| `/ux-web fix` | Carries out the approved plan. Add `skip WP3` or `only WP1 WP2` to change what runs. |
| `/ux-web plan <run id>` | Plans again from that run's reports, without a new review. Use it after you answer decisions. |
| `/ux-web home, delete-account` | Reviews only the pages, journeys or areas you name. |

The main session runs `/ux-web` by itself after website work, and whenever an app feature changes what the site should say; CLAUDE.md asks it to.

## What happens

1. **Scope.** `ux-web.sh changed` compares the website's user-facing files with a snapshot taken at the end of the last web review, and `ux-web.sh app` does the same for the app-repo files the site's claims rest on (`App/docs/`, the app's English ARB, `Backend/docs/`, and the app loop's decisions and approved plans).
   - If nothing changed, nothing runs.
   - Each area touched gets one reviewer:
     - **H** — home and hero, the value proposition, demos and calls to action;
     - **F** — features and faithfulness to the app, the funnel to download and Pro, pricing;
     - **L** — legal, privacy, terms, delete-account and trust;
     - **G** — global: navigation, header and footer, language switching, performance, accessibility, SEO and meta, light and dark.
   - An app-side change brings in F, to check what the site says about it.
2. **Render.** The site is built, and every public page is rendered in each language it has, on desktop and phone, in light and dark (below).
3. **Review.** `web-ux-reviewer` (Opus, max effort) writes a report for each area into the run folder. It reviews against `GUIDELINES.md` and the funnel (first visit → understanding and wanting the app → download → the app's first run → Pro), checks every claim against the app, predicts attention on the first-viewport renders, and reads the copy in Spanish, Catalan and English.
4. **Plan.** `web-ux-organizer` (Opus, max effort):
   - merges duplicates;
   - sends product decisions to you;
   - groups the fixes into work packages, each with an exact brief and acceptance checks.
5. **Fix.** `web-ux-implementer` (Opus, high effort) works through the packages one at a time. Each one changes the site, with all copy in the three languages, builds it, runs the Playwright tests it affects, and refreshes the renders.
6. **Test.** `web-ux-tester` (Opus, high effort) runs once per round.
   - It writes a Playwright test for every acceptance check a test can prove, working from the plan rather than the code, including axe accessibility checks, on the desktop and mobile projects and in light and dark.
   - It then runs the type check, the legal check, the build, the whole suite, the unit tests and the renders, and classes every failure as the site's or the infrastructure's.
   - If a test fails because the site falls short, that finding counts as not fixed, whatever the reviewer says.
7. **Verify.** The reviewer checks only the findings just fixed and the files just changed.
8. **Re-plan.** Anything that failed goes back to the organizer, for at most 2 more rounds. A finding that fails twice comes to you instead.
9. **Record.** The issue log and the run report are updated, and the reviewer updates its memory. If the gate passed, the round is committed on `dev`: the site's files in TaskFlowWeb, the loop's records in this repo. The snapshot then moves forward.

## Rules (your decisions, 2026-10-18)

- The loop fixes everything the reviewers find **except product decisions**; those come to you.
- Only whole-site runs stop for your approval.
- Each verified round becomes one commit on `dev` in each repo. Nothing is ever pushed or deployed, and `main` is never touched.
- The site teaches and creates desire; it doesn't replicate the app. Every claim must be true of the app today.
- No agent touches a phone. Anything that needs a real device, a screen reader or the live voice demo is listed for you to check.

## Two repos, and where each command runs

| What | Where | How |
|---|---|---|
| Build, type check, tests, renders | **WSL** | `wsl -e bash -lc 'source ~/.nvm/nvm.sh && cd /mnt/c/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb && <command>'` |
| Cropping a render | **WSL** | `wsl -e bash -lc 'source ~/.nvm/nvm.sh && node /mnt/c/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlow/.claude/ux-web/crop.mjs <render> <screen>'` |
| Git, for either repo | **Windows** | from this repo: `git …` and `git -C ../TaskFlowWeb …` |
| `ux-web.sh` | **Windows** (Git Bash) | `bash .claude/ux-web/ux-web.sh <command>` |
| `pkg.py` | **Windows** | `python -I -X utf8 .claude/ux-review/pkg.py .claude/ux-web/runs/<run id> WP1 --conventions` |

- **Why WSL:** the website's `node_modules` holds Linux binaries (Next.js, sharp, Playwright's Chromium), and Windows has no Node. nvm loads Node 26 only from `~/.bashrc`, which `bash -lc` skips, hence `source ~/.nvm/nvm.sh`. npm 12 prints `npm notice` lines and progress; pipe through `| tail -n 40` (or `| cat`) to keep output readable.
- **Why Windows for git:** both checkouts belong to Windows git, and `ux-web.sh` runs in Git Bash, like `ux.sh`.

The website's commands, run in WSL from its root:

| Command | What it checks |
|---|---|
| `npm run check` | Next.js route types and TypeScript, tests included. |
| `npm run legal:check` | The legal pages' company details and publication sign-off. |
| `npm run build` | The production build. **Needed before any Playwright run.** |
| `npm test` | Playwright on the `desktop` and `mobile` projects, with axe. `npm test -- --reporter=dot` prints only failures in detail. |
| `npm run test:unit` | Unit tests for the voice demo's rules. |
| `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts` | The renders. Add `-g "privacy es"` for one page and language. |

Playwright's web server is `npm run start`: the production server on port 3000, serving the **last build**. So build first, or every test and render shows old code. And if something already listens on port 3000, Playwright reuses it: stop it first.

## Renders

`tests/ux-renders.spec.ts`, in the website repo, runs only with `UX_RENDERS=1`. Otherwise it shows one skipped placeholder per project, so `npm test` is unaffected.

- It covers every public page (home, privacy, terms, legal, delete-account, and the 404 page) in each language the page exists in, on desktop (1440 × 1000) and mobile (iPhone 13 in Chromium, 390 × 664, at 3×), in light and dark.
- For each, it writes to `TaskFlowWeb/artifacts/ux-web/` (git ignores `artifacts/`):
  - `<page>.<language>.<desktop|mobile>.<light|dark>.fold.png`: the first viewport;
  - `<page>.<language>.<desktop|mobile>.<light|dark>.full.png`: the whole page at 1 px per CSS px, with a magenta line where the first viewport ends;
  - `opengraph-image.png`: the link preview;
  - `INDEX.md`: every PNG's URL and source files, and the languages a page lacks.
- On 2026-10-18 that was 113 PNGs, in about a minute. The home and 404 pages exist only in English, so they have no Spanish or Catalan renders.
- A coverage check fails when a page file under `src/app` isn't in the spec's `PAGES` table, so a new page can't be left out. `web-ux-tester` keeps the table current.
- Image viewers shrink tall pages until their text can't be read. `crop.mjs` cuts screenfuls out of a full-page render at full size, into `artifacts/ux-web/crops/`.

## Another session's work in the website

TaskFlowWeb holds another session's uncommitted and untracked work: the legal pages and content, docs, `Dockerfile`, `package.json`, `src/app/layout.tsx` and more. The loop reviews it as part of the site, but never commits, stages or reverts it.

- `ux-web.sh base`, run just before a fix run, records the website's whole working tree, including that work.
- `ux-web.sh ran` and `ux-web.sh diff` then show only the run's own changes.
- `ux-web.sh stage <files>` stages only those:
  - a file that was clean when the run started is staged whole;
  - a file that already held the other session's changes gets only the run's hunks, through `git apply --cached`;
  - a file it can't separate is refused: the run's lines touch the other session's, or the file is one the other session created and hasn't committed. Its change stays uncommitted, and you're told.

## Files

| File | What it holds |
|---|---|
| `GUIDELINES.md` | The research-backed guide the reviewer reviews against, with sources. |
| `ISSUES.md` | Every web issue and its current status, `WEB-1` upward. |
| `DECISIONS.md` | Your decisions about the site. Every agent reads it first. |
| `KNOWN_FAILURES.md` | Checks that were already failing before the loop started, and the baseline. |
| `runs/<run id>/` | One run: `review-*.md`, `plan.md`, `plan.json`, `plan-r*.json`, `verify-*.md`, `report.md`. |
| `ux-web.sh` | Snapshots (`refs/ux-web/last` in the website, `refs/ux-web/app-last` here) and the run's own changes (`refs/ux-web/base`). It never moves a branch or touches a working tree, and it leaves both indexes alone, except `stage`, which stages the run's own changes in the website's index. |
| `crop.mjs` | Cuts screenfuls out of a full-page render. |

Shared with the app loop: `.claude/ux-review/pkg.py`, which prints a plan's packages from any run folder.

The other pieces:
- the agents: `.claude/agents/web-ux-reviewer.md`, `web-ux-organizer.md`, `web-ux-implementer.md`, `web-ux-tester.md`; the reviewer's memory is in `.claude/agent-memory/web-ux-reviewer/`;
- the workflows: `.claude/workflows/ux-web-review.js` and `ux-web-fix.js`;
- the command: `.claude/skills/ux-web/SKILL.md`;
- in the website: `tests/ux-renders.spec.ts`, and the loop's own tests, `tests/ux-web-*.spec.ts`.

Project agents and skills load when a session starts or changes folder. After adding or editing them mid-session, move the session to this repo again (`change_directory`) to reload them.

## How it differs from the app loop

- Two repos: the loop lives here, the site in `../TaskFlowWeb`, with a commit in each.
- IDs are `WEB-`, packages `WP`, decisions `WD`, so they can't be confused with the app's.
- The areas are H, F, L and G, and the reviewer checks the site against the app (faithfulness), with a second snapshot of the app-side files.
- Renders come from Playwright, not Flutter previews, and the build must come first.
- Tests are Playwright with axe, on two projects; a failure is the site's or the infrastructure's.
- There's no starting-point commit of uncommitted work, because most of it belongs to another session. `ux-web.sh base` and `stage` separate the run's changes instead.
- Verify notes, like review reports, come back as text when a reviewer can't save them, and the main session saves them.

## Cost

- **Scoped run** (one area): about 7 agents.
- **Whole-site run:** 4 reviewers and an organizer, then one implementer per package you approve, plus, each round, one tester and one verifier per area.
- Every implementer and tester builds the site (about 1.5 minutes) and runs Playwright in WSL.

To change a model or an effort level, edit the agent's frontmatter.
