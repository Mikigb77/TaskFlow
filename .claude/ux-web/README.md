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
2. **Render and measure.** The site is built, and every public page is rendered in each language it has, on desktop and phone, in light and dark, also with text and zoom at 200% and at 320 px. Every state of both demos is rendered with the voice API stubbed. A measured audit covers accessibility, sizes, contrast, the screen reader's view, the keyboard path, metadata and lab speed (below).
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
| `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=6 --grep-invert "perf "` | The renders and the audit. Add `-g "privacy es"` for one page and language, `-g "voice-waiting"` for one demo scenario. |
| `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=1 --grep "perf "` | Lab performance, after the renders and on its own. |

Playwright's web server is `npm run start`: the production server on port 3000, serving the **last build**. So build first, or every test and render shows old code. Build with `SITE_URL=https://taskflow.garbar.tech npm run build` when the audit should judge canonical, hreflang and `og:url`: production builds set it, and pages built without it have none. And if something already listens on port 3000, Playwright reuses it: stop it first.

## Renders

`tests/ux-renders.spec.ts`, in the website repo, runs only with `UX_RENDERS=1`. Otherwise it shows one skipped placeholder per project, so `npm test` is unaffected. Its helpers are in `tests/support/`: `ux-voice.ts` (the demo states and the API stub), `ux-collect.ts` and `ux-audit.ts` (the audit), `ux-perf.ts` (lab performance).

It writes to `TaskFlowWeb/artifacts/ux-web/` (git ignores `artifacts/`), where `INDEX.md` explains every file:
- **Pages:** every public page (home, privacy, terms, legal, delete-account, and the 404 page) in each language it exists in, on desktop (1440 × 1000) and mobile (iPhone 13 in Chromium, 390 × 664, at 3×), in light and dark:
  - `<page>.<language>.<desktop|mobile>.<light|dark>.fold.png`: the first viewport;
  - `<page>.<language>.<desktop|mobile>.<light|dark>.full.png`: the whole page at 1 px per CSS px, with a magenta line where the first viewport ends;
  - `opengraph-image.png`: the link preview.
- **Text size and zoom,** in light, with the same names: `desktop-text200` and `mobile-text200` double the browser's default font size, as Chrome's font-size setting does, so text sized in px stays as it was; `desktop-zoom200` is a desktop at 200% zoom (720 × 500 CSS px at 2×); `mobile-w320` is 320 px wide, WCAG's reflow width.
- **Demo states:** `<state>.en.<desktop|mobile>.<light|dark>.view.png` (the screen at that moment) and `….panel.png` (the whole demo card), for every state of the live voice demo and the sample walkthrough: recording, microphone refused or missing, waiting at 1, 10, 30 and 54 s, the timeout, results, tries used, every error the API sends, and more. **The real voice API is never called:** the test answers every request in the shapes the site's server code returns, and reads the errors from the code, so a new error is rendered on the next run. Cloudflare's check is a same-size stand-in, and the microphone is Chromium's fake device.
- **Other states:** the home without JavaScript, the phone menu open, an FAQ answer open.
- **The audit:** `AUDIT.md` and `audit.json`, per page, language, viewport and theme, and per demo state: axe (WCAG 2.2 A and AA); every target's size against 24 and 44 px, with links inside sentences marked; text under 12 px and body text under 16 px; contrast for every text colour pair and for controls and toggle states; what a screen reader gets, from Chromium's accessibility tree (names, alt text, label in name, landmarks), with Playwright's ARIA snapshots in `aria/`; the keyboard path, every Tab stop with its name, whether focus is visible, hidden behind the sticky header or cut off, with screenshots in `focus/`; headings; metadata; overflow; and lab performance (LCP, CLS, TBT, bytes, fonts) under Lighthouse's mobile throttling, which is lab data, not field data.
- **Safari:** first-viewport renders in Playwright's WebKit on the iPhone 13 profile, `<page>.<language>.mobile-webkit.<theme>.fold.png`, when WebKit is installed in WSL. It isn't yet: it's about 107 MB, and WSL here runs Kali Linux, where Playwright's `install-deps` can't install WebKit's libraries, so they'd go in by hand.

Running it:
- Build first, with `SITE_URL` as above. Then the renders and the audit take about 3.5 minutes on 6 workers, and lab performance about 2 minutes on its own (the two Playwright commands in the table above; §4 of the skill chains them). On 2026-10-18 that was 550 PNGs, 446 focus screenshots and 103 ARIA snapshots, in 5.2 minutes.
- The home and 404 pages exist only in English, so they have no Spanish or Catalan renders.
- A coverage check fails when a page file under `src/app` isn't in the spec's `PAGES` table, so a new page can't be left out. `web-ux-tester` keeps the table current, and the demo scenarios in `tests/support/ux-voice.ts` too: they find the demo by its structure (classes, `data-stage`), not its copy, so a structural change makes them fail loudly.
- Each test saves its measurements in `artifacts/ux-web/.audit/`; a run with `-g` replaces only what it measures, and every Playwright worker merges them into `AUDIT.md` when it finishes. `npx tsx tests/support/ux-audit.ts` merges them again.
- Image viewers shrink tall images until their text can't be read. `crop.mjs` cuts screenfuls out of a full-page render or a demo card at full size, into `artifacts/ux-web/crops/`.

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
| `crop.mjs` | Cuts screenfuls out of a full-page render or a demo card. |

Shared with the app loop: `.claude/ux-review/pkg.py`, which prints a plan's packages from any run folder.

The other pieces:
- the agents: `.claude/agents/web-ux-reviewer.md`, `web-ux-organizer.md`, `web-ux-implementer.md`, `web-ux-tester.md`; the reviewer's memory is in `.claude/agent-memory/web-ux-reviewer/`;
- the workflows: `.claude/workflows/ux-web-review.js` and `ux-web-fix.js`;
- the command: `.claude/skills/ux-web/SKILL.md`;
- in the website: `tests/ux-renders.spec.ts` with its helpers in `tests/support/ux-*.ts`, and the loop's own tests, `tests/ux-web-*.spec.ts`.

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
- Every implementer and tester builds the site (1.5 to 6 minutes) and runs Playwright in WSL. The tester's full renders and audit add about 5.5 minutes a round.

To change a model or an effort level, edit the agent's frontmatter.
