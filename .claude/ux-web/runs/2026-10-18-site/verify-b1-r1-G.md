# Verify — run 2026-10-18-site, round 1, area G (WP15) — 2026-10-19

Scope: WP15 (WEB-2, alias WEB-301). Files: `src/content/site/{types,index,en,es,ca}.ts`, `src/components/useSiteLanguage.ts`, `src/components/HomePage.tsx`, `src/app/page.tsx`, `src/app/[language]/page.tsx`, `src/proxy.ts`, `tests/ux-renders.spec.ts`.
Evidence: code, the tester's results, `AUDIT.md` (03:38) and renders (03:35), both newer than the code (HomePage.tsx 03:09, content 03:08). No npm or Playwright run by me.

## WEB-2 — partly fixed

Acceptance, one by one:

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | /es/ and /ca/ return 200; the wrapper has lang es / ca, / has en | met | `src/components/HomePage.tsx:18` `<div lang={language}>`; `src/app/[language]/page.tsx:6,13-14` (`dynamicParams = false`, es and ca); tester pass; renders `home.es.mobile.light.fold.png`, `home.ca.desktop.light.fold.png` show the Spanish and Catalan hero |
| 2 | canonical to self, hreflang en/es/ca/x-default | met | `src/content/site/index.ts:30-41` `homeAlternates`; `src/app/page.tsx` and `[language]/page.tsx:16-18`; AUDIT §11 rows 7-9: canonical `/`, `/es/`, `/ca/`, hreflang `en, es, ca, x-default`, no hreflang problem |
| 3 | Accept-Language and cookie cases | met | `src/proxy.ts:6-30` (cookie first, then q-values, ties to the first listed, never IP); tester pass on all five cases |
| 4 | Every answer for / has Vary naming Accept-Language and Cookie, Cache-Control private; nosniff on the 200 | **not met on the 200** | `src/proxy.ts:39-40` sets both, but Next 16 overwrites Vary on the page render: `node_modules/next/dist/build/templates/app-page-runtime.js:466-467` `res.setHeader('Vary', varyHeader)` (confirmed by reading it). The 200 carries `Vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch, accept-encoding`; the 307s carry the proxy's. Cache-Control `private, no-store` and nosniff survive on the 200 (tester) |
| 5 | /privacy/, /es/privacy/ no redirect; /xx/ 404 | met | `src/proxy.ts:43` `matcher: "/"`; tester pass |
| 6 | Renders list home es and ca; coverage passes | met | INDEX.md Pages table rows home es and ca; tester pass |
| 7 | axe clean on the three homes, light and dark | met | tester pass |

What the visitor feels: nothing, today. Because the 200 is `Cache-Control: private, no-store`, no browser or shared cache stores the English answer, so a missing Vary can't make a Spanish visitor get a cached English home (RFC 9111: `no-store` forbids storing; Vary only matters to stored responses). The edge worker (`edge/worker.ts:79-93`) adds no caching. The intent of check 4 (no cache serves the wrong language) is met; its letter isn't.

Recommendation to the main session: relax check 4 to “every answer for / has `Cache-Control` with `private` and `no-store`; the 307s also name Accept-Language and Cookie in Vary”. Then WEB-2 (WP15's half) is fixed. Don't patch `ServerResponse.setHeader` in instrumentation to force it: a fragile workaround for no visible gain.

Note: WEB-2 as a whole also covers the demo's strings, dates and error messages and the header/footer language; those belong to WP16–WP29 and aren't judged here.

## Regressions (changed files and the pages they touch only)

**R1G-1 · Severity 2 · English passages marked as Spanish and Catalan**
- Where: `src/components/HomePage.tsx:18` (`lang={language}` wraps everything), with `<VoiceDemo />` at `:61` still English, and `src/content/site/es.ts:44-46,63` / `ca.ts:50-52,69` reusing the English FAQ eyebrow, heading “Glad you asked.”, intro, doodle and answers 4–7. Render: `crops/home.es.desktop.light.full.s2-4.png` (from `home.es.desktop.light.full.png`): “Say it. See it take shape.”, “A minute is plenty.”, “Try the live demo”, “3 free tries · no account”, “Glad you asked.”, “How does voice-to-task work?” and three more English questions on the Spanish home.
- The moment: the Spanish newcomer scrolls past a Spanish hero into an English demo and an English FAQ: «¿Ahora en inglés?» With TalkBack set to Spanish, those English lines are read with Spanish pronunciation, because they sit inside `lang="es"` (WCAG 3.1.2).
- Cause: this package created the wrapper and the reused-English tables, which the plan allowed as an interim. axe can't detect a wrong `lang` (AX-11), so the clean axe row isn't a pass here.
- Fix: no new code if WP19 (FAQ, commits in this run) and WP26–WP29 (demo, held) land: they translate the passages, and the wrapper becomes right. If WP26–WP29 stay held and uncommitted while WP15 commits, the committed /es/ and /ca/ show an English demo labelled Spanish; then, as a stop-gap, the organizer should either hold the commit of the /es/ and /ca/ routes until the demo speaks the page's language, or accept the mix knowingly. The organizer may close this as tracked by WP19/WP26–WP29.
- Verify: on /es/ and /ca/, a scan of `main` finds none of “the”, “your”, “and”, “demo”, “Glad you asked”, “Try the live demo” (WEB-2's own stop-list check).
- Evidence: seen in a current render; verified in code.

Not counted as regressions (tracked by other packages of this run): the header and phone menu stay English on /es/ and /ca/ (“Features”, “Try voice”, “Questions”, “Explore the app”; `home.ca.desktop.light.fold.png`) → WP20; `<html lang="en">` and the shared English title, description and `og:url` pointing at `/` on /es/ and /ca/ (AUDIT §11 rows 8-9, 29-30) → WP21, WP22.

## Sequencing condition (not a regression, but check before committing)

Nothing writes `taskflow-lang` yet (`grep` finds only `src/proxy.ts:7`). Until WP20's switch lands, a person whose browser prefers Spanish or Catalan can't reach the English home at all: every `/` (the logo, the legal pages' back link) answers 307 to `/es/` or `/ca/`. WD5 intends the switch to override this. WP20 lists exactly this check (“Clicking Català on / … sets the cookie … a new request to / then answers 307 to /ca/”). Commit WP15 together with WP20, not alone.

## Device check after the owner deploys

The 307's Location is absolute, built from `request.url` (`src/proxy.ts:37`). Behind the edge worker the request's Host is the origin's (`edge/worker.ts:65`); the worker rewrites a Location only when it starts with `env.ORIGIN` exactly (`:79-83`). If Next builds `http://…` (not `https://`) or adds a port, the newcomer would be sent to the Cloud Run hostname. Inferred, not verified (hosting is out of my lane). Check after the deploy: `curl -sI -H 'Accept-Language: es' https://taskflow.garbar.tech/` → `location` must be `https://taskflow.garbar.tech/es/` (or `/es/`). A relative `Location: /es/` would remove the risk.

## Catalan for a native read

None added by WP15 itself; the Catalan in `ca.ts` belongs to WP16–WP18 and is verified there.
