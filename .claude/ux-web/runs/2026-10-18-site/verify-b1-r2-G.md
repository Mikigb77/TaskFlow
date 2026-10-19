## UX web verify — run 2026-10-18-site, round 2 (b1), area G — WP34 — 2026-10-19

**Scope:** WP34 (WEB-2, WEB-707; alias R1G-1). Changed files: `src/components/HomePage.tsx`, `tests/ux-web-home.spec.ts` (plus the tester's `tests/ux-web-global.spec.ts`). `src/proxy.ts` was not changed this round.
**Evidence used:** code (`ux-web.sh diff`, current files), the tester's results, and the fresh renders (`home.es.desktop.light.full.png` 04:43, `home.ca.mobile.dark.full.png` 04:44, newer than `HomePage.tsx` 04:21). Nothing run.

### WEB-2 · partly fixed
- Acceptance 1–3 met (tester, `tests/ux-web-global.spec.ts:91-136`, pass): the 200s for / are `private, no-store` + nosniff; the 307s go to /es/ and /ca/, are `private, no-store`, and Vary names accept-language and cookie. Check 4 of WP15 is replaced as the brief asked (`:88-90` comment).
- Not done: the brief's host-free redirect. The brief says: check the built server's Location, and *if it's absolute*, answer the 307 with a path-only Location. The tester found it absolute ("proxy.ts still builds it from request.url"), and `src/proxy.ts:37` is unchanged: `NextResponse.redirect(new URL(homePath(language), request.url), 307)`. The implementer's notes don't mention this step. The plan's title for WP34 names it ("a host-free redirect"; `plan.md:263`: "makes it path-only if it's absolute, which removes the risk of a redirect to the Cloud Run host after deploy").
- Why it matters to a visitor: the site runs as a Next standalone server (`next.config.ts:4`, `Dockerfile:18` `HOSTNAME=0.0.0.0 PORT=8080`) behind the edge worker, which rewrites a Location only when it starts with `env.ORIGIN` exactly (`edge/worker.ts:78-83`, `edge/wrangler.jsonc:11` `https://taskflow-web-…run.app`). If `request.url` behind Cloud Run comes out as `http://…`, with a port, or as `0.0.0.0`/`localhost` (a known standalone pattern), every Spanish or Catalan visitor typing the bare address is sent off taskflow.garbar.tech to a Cloud Run or dead host. Inferred, not seen; cause likely server-side; the local acceptance can't catch it because locally the request's origin is the public one.
- Fix (as briefed, one line, `src/proxy.ts:37`): `: new NextResponse(null, { status: 307, headers: { Location: homePath(language) } });` and keep `:38-39` on both answers. The tester's check at `ux-web-global.spec.ts:127` already accepts a path-only Location (`toBe(to)`). Verify: `curl -sI -H 'Accept-Language: es' http://localhost:3000/` shows `location: /es/`; after deploy, the device check in WP34.

### WEB-707 · fixed (alias R1G-1, demo half; the FAQ half is WP19's)
- `src/components/HomePage.tsx:62-65`: `<div lang="en" style={{ display: "contents" }}><VoiceDemo /></div>`, with the briefed comment at `:62`. VoiceDemo.tsx untouched, no props passed.
- Tester: `ux-web-global.spec.ts:138-170` passes on both projects (closest `[lang]` of `#voice` is `en`, wrapper display `contents`; hero, #features, #questions, #get-taskflow keep es/ca; / is all en). Axe clean on the three homes, light and dark (`ux-web-home.spec.ts` "WEB-6, WEB-19, WEB-707…").
- Layout unchanged: in `home.es.desktop.light.full.png` and `home.ca.mobile.dark.full.png` the demo sits directly under the hero, same spacing, no new box. No selector in `global.css`/`voice.css` depends on the demo's parent or siblings (searched `+`, `~`, `>`, `:first-child`, `:nth-`; only `.faq-item`, `.mini-day`, `.header-menu`, `.voice-heading` inner ones).
- Device check stays: TalkBack in Spanish on /es/ reading the demo heading with English pronunciation; and VoiceOver on Safari, where older WebKit handled `display: contents` poorly in the accessibility tree (the wrapper is a generic div, so only the lang inheritance is at stake).

### Regressions (changed files and the pages they touch)
- None caused by this round. `HomePage.tsx` adds only the wrapper; `tests/ux-web-home.spec.ts`'s WEB-10 order check looks through the `display: contents` wrapper correctly (`:166-178`).
- Seen but not regressions (already in the ledger / other packages): the header on /es/ and /ca/ is still English (`Features`, `Try voice`, `Questions`, `Explore the app`; WP20), and the demo is English (WP26–WP29), visible in both renders above.

### Reminder for the plan
- WP26 must remove the `lang="en"` wrapper at `HomePage.tsx:62-65` when the demo reads the page's language (`plan.md:264`).
