---
name: ux-web
description: Run TaskFlow's UX web loop on the marketing website (TaskFlowWeb). web-ux-reviewer reviews what changed since the last web review (or the whole site, or named pages) — including whether the site still tells the truth about the app — web-ux-organizer plans the fixes, web-ux-implementer makes them one package at a time, web-ux-tester locks them with Playwright, and the reviewer re-checks until they hold. Use when the owner types /ux-web, asks for a UX review of the website, after website work, and when an app feature changes what the site should say (CLAUDE.md's UX web loop section).
argument-hint: "[site | fix [skip WP3 | only WP1 WP2] | plan <run id> | <pages or areas>]"
---

# /ux-web — TaskFlow's UX web loop

Invoking this skill is the owner's opt-in to running the `ux-web-review` and `ux-web-fix` workflows (decided 2026-10-18; see `.claude/ux-web/DECISIONS.md`). How the loop works: `.claude/ux-web/README.md`.

Two repos are involved:
- **the app repo** (this one) holds the loop: agents, workflows, this skill, and the state in `.claude/ux-web/`;
- **the website**, `../TaskFlowWeb` (`C:/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb`), is what gets reviewed and fixed.

**Where commands run.** Git, `ux-web.sh` and `pkg.py` run on Windows, from the app repo. Node, npm, npx and Playwright run only in WSL, because the website's `node_modules` holds Linux binaries. Every WSL command has this shape (written `WSL: <command>` below):

```
wsl -e bash -lc 'source ~/.nvm/nvm.sh && cd /mnt/c/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb && <command> 2>&1 | tail -n 40'
```

`source ~/.nvm/nvm.sh` is required: nvm loads Node 26 only from `.bashrc`, which a non-interactive shell skips.

## 1. Read the argument

| Argument | Mode | What happens |
|---|---|---|
| (none) | **changes** | Review what changed on the website, and in the app features it describes, since the last web review; then fix and verify without stopping. |
| `site` | **site** | Review the whole website. Stop after the plan for the owner's approval. |
| `fix`, optionally followed by `skip WP3 WP7` or `only WP1 WP2` | — | Carry out the latest plan waiting for approval (§6). |
| `plan <run id>` | the run's mode | Plan again from the reports already in that run folder, without a new review. Use it after the owner answers decisions. Call `ux-web-review` with `reportPaths` set to the folder's `review-*.md` files, then continue as in §5. |
| anything else | **pages** | Review only the named pages, journeys or areas (`home`, `privacy`, `delete-account`, `languages`, `F`…), then fix and verify without stopping. |

## 2. Before starting

- Check that both repos are on `dev`: `git branch --show-current` and `git -C ../TaskFlowWeb branch --show-current`. If either isn't, stop and ask.
- Check that no merge, rebase or cherry-pick is in progress in either repo.
- Name the run `<today>-<mode>`, adding `-2`, `-3` and so on if that folder already exists. The run folder is `.claude/ux-web/runs/<run id>/`; create it.
- Look at `git -C ../TaskFlowWeb status --porcelain`. Another session has uncommitted and untracked work in the website: the legal pages and content, docs, `Dockerfile`, `package.json`, `src/app/layout.tsx` and more. It's part of the site being reviewed. **Never commit it, stage it or revert it**; §6 says how a run's own changes are told apart from it.
- Handle owner decisions from this conversation:
  - add the lasting ones to `.claude/ux-web/DECISIONS.md`, dated and in the owner's words;
  - pass everything else the agents should know as `notes`. They can't see the conversation.

## 3. Work out the scope

### changes
1. Run `bash .claude/ux-web/ux-web.sh changed` (website files) and `bash .claude/ux-web/ux-web.sh app` (the app-repo files the site's claims rest on: `App/docs/`, the app's English ARB, `Backend/docs/`, the app loop's DECISIONS and approved plans).
   - Either prints `NO_SNAPSHOT`: tell the owner there's no baseline yet, suggest `/ux-web site`, and stop.
   - Both print nothing: say "Nothing on the website changed since the last web review, and nothing in the app it describes" (the date comes from `ux-web.sh status`), and stop.
2. Map every website file to an area with the table below. Each area touched gets one reviewer. Its scope is its changed files, "and the pages, journeys and states they touch".
3. App-side changes add area **F** (if it isn't there already), with the scope "the site's claims about what these app-repo files changed: <list>". Add area **L** too when `Backend/docs/ACCOUNT_DELETION.md`, or a decision about data, privacy or deletion, changed. Pass the list as `appChanged`. If the app-side changes are clearly only wording the site never quotes, you may drop them; say so to the owner.

### pages
Map the named pages, journeys or areas to areas with the table. The scope is those pages and journeys, in every state, language, viewport and theme.

### site
Use all four areas, with the full scope from the table.

### Areas

| Area | Name | Files | Journeys to walk (site mode) |
|---|---|---|---|
| H | Home and hero, the value proposition, demos and calls to action | `src/app/page.tsx` (hero, the "at a glance" bar, the demo sections, appearance, closing call to action), `src/components/TaskDemo.tsx`, `VoiceDemo.tsx`, `Phone.tsx`, `src/styles/voice.css`, `src/lib/voice/policy.ts` and `recorder.ts` (the limits and recording a visitor feels), `public/images/`, `public/audio-capture.js` | first visit to wanting it, on a phone in Spanish and on desktop in English; both demos in every state (idle, recording, microphone denied, waiting, result, error, allowance used, no JavaScript); every call to action and where it leads |
| F | Features and faithfulness, the funnel to download and Pro, pricing | `src/app/page.tsx` (features, FAQ, and anything about downloading, pricing or Pro), `src/components/Phone.tsx` and `public/images/` (the app as shown), checked against the app-side sources (`ux-web.sh app` lists the ones that changed) | from wanting it to getting it, honestly, while Google Play isn't published; free and Pro against the app; the claims inventory for the whole site; app features the site doesn't tell |
| L | Legal, privacy, terms, delete-account and trust | `src/app/{privacy,terms,legal,delete-account}/page.tsx`, `src/app/[language]/[document]/page.tsx`, `src/components/LegalPage.tsx`, `src/content/legal/`, `src/styles/legal.css` | trust: who runs TaskFlow, privacy, terms and contact, from the home page and from the app's links; deleting an account from Google Play's link, a search and the app, in each language; the legal pages' claims against the app and `Backend/docs/ACCOUNT_DELETION.md` |
| G | Global: navigation, header and footer, language switching, performance, accessibility, SEO and meta, light and dark | `src/app/layout.tsx`, `not-found.tsx`, `opengraph-image.tsx`, `robots.ts`, `sitemap.ts`, `src/components/Header.tsx`, `Footer.tsx`, `ThemeProvider.tsx`, `Icon.tsx`, `src/styles/global.css` (tokens, base, header, footer, buttons), `public/fonts/`, `public/favicon.svg`, `next.config.ts` | a wrong URL, a language switch and the way back; navigation on phone and desktop; every page at 320 px and at text 200%, by keyboard and screen reader, in light and dark; titles, descriptions, link previews, `lang` and `hreflang` for every page and language |

Shared files:
- `src/app/page.tsx` belongs to H for the hero, the demo sections, the appearance section and the closing call to action, and to F for the features and the FAQ. When a diff touches both, both.
- `src/styles/global.css` belongs to the area of the selectors the diff touches (`.hero`, `.demo-`, `.voice-`, `.appearance-`, `.closing-` → H; `.feature-`, `.faq-` → F; tokens, base, `.site-header`, `.site-footer`, `.button` → G). If unclear, G.
- `src/components/Phone.tsx` and `public/images/` belong to H and F.
- `src/app/layout.tsx`, `Header.tsx` and `Footer.tsx` show on every page: G, plus L when the legal pages' language or trust links are affected.
- A new file belongs to the area it fits by what it shows.

### ID ranges
- Let N be the highest WEB number in `.claude/ux-web/ISSUES.md`, or 0 if there's none: `grep -oE 'WEB-[0-9]+' .claude/ux-web/ISSUES.md | sort -t- -k2 -n | tail -1`.
- Let B be 0 when N is 0, otherwise `floor(N / 100) + 1`.
- Reviewer k (0-based) gets `idStart = (B + k) * 100 + 1`. The first whole-site run numbers its four areas from WEB-1, WEB-101, WEB-201 and WEB-301.

## 4. Render and measure the pages

Before any reviewer starts, make sure nothing listens on port 3000 (`WSL: ss -ltn | grep ':3000 ' || echo free`). Playwright would reuse that server, which may serve an older build. Then, in WSL, two commands; give the second a 10-minute timeout:

```
WSL: SITE_URL=https://taskflow.garbar.tech npm run build
WSL: rm -rf artifacts/ux-web && UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=6 --grep-invert "perf " --reporter=dot && UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=1 --grep "perf " --reporter=dot
```

- **The build comes first,** because the Playwright config serves the last production build (`npm run start`); without it the renders show old code. `SITE_URL` is production's, as the `Dockerfile` sets it: without it the pages have no canonical, hreflang or `og:url`, and the audit can't judge them. The build takes 1.5 to 6 minutes.
- **The renders and the audit** take about 3.5 minutes on 6 workers. **Lab performance** follows on its own, about 2 minutes, because other work running alongside slows its throttled CPU.
- Everything lands in `../TaskFlowWeb/artifacts/ux-web/` (git ignores `artifacts/`), and its `INDEX.md` explains every file:
  - every public page, in each language it exists in, on desktop (1440 × 1000) and mobile (iPhone 13 in Chromium, 390 × 664), in light and dark: a first-viewport PNG and a full-page PNG with a magenta line at the fold;
  - the same pages with the browser's text size doubled (`text200`), at 200% zoom (`zoom200`) and 320 px wide (`w320`);
  - every state of both demos on the home page, with the voice API stubbed and never called: recording, microphone refused, waiting, the timeout, results, every error the API sends, the sample walkthrough, and more;
  - the home without JavaScript, the phone menu open, an FAQ answer open;
  - `AUDIT.md` and `audit.json`, the measured audit: axe, target sizes, text sizes, contrast, what a screen reader gets (with `aria/`), the keyboard path (with `focus/`), headings, metadata, overflow, and lab performance;
  - the link preview.

  On 2026-10-18 that was 550 PNGs, 446 focus screenshots and 103 ARIA snapshots.
- **Safari:** with Playwright's WebKit installed in WSL, the same command adds first-viewport renders in WebKit on the iPhone 13 profile. It isn't installed, and installing it is the owner's call: `npx playwright install webkit` downloads about 107 MB, and WSL here runs Kali Linux, where Playwright's `install-deps` can't find WebKit's libraries (it only knows Ubuntu), so they would need installing by hand with `sudo`.
- If the build or a render fails, mention it but keep going: renders are evidence, not a gate. A failing build is itself something to tell the owner.

## 5. Review and plan — workflow `ux-web-review`

Call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-web-review.js` (the repo root comes from `git rev-parse --show-toplevel`). Don't use `name`: saved workflows are only looked up by name if they existed when the session started. Pass these args:

```
{ runId, runDir, date, mode,
  webDir: "C:/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb",
  slices: [{ key, name, scope, idStart }],
  appChanged,
  notes }
```

When it returns:
- **`inlineReports` isn't empty:** a reviewer wasn't allowed to save its report. Write each `text` to its `path`.
- **`plan` is null** (no findings): run `bash .claude/ux-web/ux-web.sh save`, tell the owner, and stop.
- **site mode:**
  1. Run `bash .claude/ux-web/ux-web.sh save`.
  2. Show the owner:
     - each area's verdict;
     - the counts;
     - the decisions, with the organizer's recommendations;
     - the packages, one line each;
     - a link to `plan.md`.
  3. Stop. The owner approves ("go"), strikes packages, or answers decisions.
  4. Record their answers in `.claude/ux-web/DECISIONS.md`. If an answer unblocks findings, run `/ux-web plan <run id>`, so those findings become packages.
  5. Then go to §6.
- **changes or pages mode:** go straight on to §6.

## 6. Fix and verify — workflow `ux-web-fix`

1. **Make the starting point.**
   - If this session made website changes of its own before the run (the work being reviewed), commit them first in the website repo, as in step 3's website commit: `ux-web.sh ran` lists them if a `base` was taken before that work began (CLAUDE.md asks for one). Message: `Changes reviewed by the UX web loop (<run id>)`, plus the attribution line. If no `base` was taken, commit only files that `git -C ../TaskFlowWeb status` shows as changed by this session alone, and leave the rest for the owner.
   - Then run `bash .claude/ux-web/ux-web.sh base`. It records the website's whole working tree, including the other session's uncommitted work, so the run's own changes can be told apart from it afterwards.
2. **Run the workflow.** Call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-web-fix.js`, and args `{ runId, runDir, date, webDir, skip, only, batch, recordMemory, notes }`. For `/ux-web fix`, the run folder is the newest one under `.claude/ux-web/runs/` that has a `plan.json` but no `report.md`.
3. **When it returns:**
   - **Save the reports.** Write `close.report` to `<runDir>/<reportName>`, and each of `inlineNotes` to its `path`. Subagents may not write report files, so the agents return the text.
   - **`testsPassed` is true:** commit, one commit in each repo.
     - **Website.** Run `bash .claude/ux-web/ux-web.sh ran`. Stage the files that appear both there and in the workflow's `webFiles`, with `bash .claude/ux-web/ux-web.sh stage <files>`:
       - a file that was clean when the run started is staged whole;
       - a file that held the other session's uncommitted changes gets only the run's hunks (`git apply --cached`);
       - a file it can't separate is **refused**: the run's lines touch the other session's, or the file is one the other session created and hasn't committed. Leave it uncommitted and tell the owner.

       A file in `ran` but not in `webFiles` changed under the run, by someone else: don't stage it. Check `git -C ../TaskFlowWeb diff --cached` (only the run's lines), then commit in the website repo: subject `UX web loop <run id>: <n> fixes verified`; body: the verified IDs, then the IDs still open with a short reason each, then any refused files; end with the attribution line.
     - **App repo.** Stage only the loop's records: `git add -- .claude/ux-web/ISSUES.md .claude/ux-web/KNOWN_FAILURES.md .claude/ux-web/runs/<run id>`, plus `.claude/agent-memory/web-ux-reviewer` once it exists (the first batch that records memory creates it) and `.claude/ux-web/DECISIONS.md` if you recorded decisions. The app repo has other sessions' uncommitted work too; never stage anything else. Subject `UX web loop <run id>: ledger, report and reviewer memory`; name the website commit in the body; end with the attribution line.
   - **`testsPassed` is false:** don't commit in either repo. Tell the owner which checks fail, and that the changes are left uncommitted for them to look at.
   - Either way, run `bash .claude/ux-web/ux-web.sh save` afterwards.

Never push. Never deploy: no `scripts/deploy-*`, `gcloud`, `wrangler` or `docker`. Never commit on `main`. Never skip hooks. Never commit, stage or revert the other session's work.

### Big plans run in batches

A plan with more than about 6 packages runs in batches of about 5, in plan order.
- Each batch is one `ux-web-fix` run, with `only` set to the batch's packages and `batch` set to `b1`, `b2`, and so on.
- Set `recordMemory: false` on every batch except the last, so the reviewer updates its memory once per plan.
- After each batch: save its report, commit, run `ux-web.sh save`, then `ux-web.sh base`, then start the next batch.
- Don't wait for the owner between batches.
- Stop and tell the owner if a batch's tests fail, or if it escalates more than two findings.

## 7. Tell the owner

Keep it short; the details live in `report.md`.
- The verdict, in one line.
- What was fixed and verified: up to five IDs with titles, then "and N more".
- What's still open, what was escalated, and the decisions needed, each with its question.
- Files `stage` refused, which stay uncommitted.
- Checks for a real device or a person: Safari on an iPhone, a screen reader, the live voice demo.
- Links to `report.md`, `.claude/ux-web/ISSUES.md`, and both commits.

## Size and cost

- **Scoped run, one area:** 1 reviewer, 1 organizer, 1–3 implementers, 1 tester, 1 verifier, 2 recording steps. That's about 7–8 agents.
- **Whole site:** 4 reviewers and 1 organizer, then one implementer per approved package, one tester per round, and one verifier per area touched.
- Every implementer and tester builds the site (1.5 to 6 minutes) and runs Playwright in WSL; the tester's full renders and audit add about 5.5 minutes.

Models and effort are set in each agent's frontmatter in `.claude/agents/web-ux-*.md`.
