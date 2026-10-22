---
name: site-map
description: TaskFlowWeb pages, home anchors, components, legal section ids and which renders show what (as of run 2026-10-18-site, b5 closed 2026-10-20)
metadata:
  type: project
---

Snapshot 2026-10-22 (after run 2026-10-21-changes; 2026-10-22-changes changed only copy in `features.calendar.body` and FAQ item 2, plus `.feature-card p` wrapping). Check against the code before relying on line numbers.

**Home** (`src/components/HomePage.tsx`; copy in `src/content/site/{en,es,ca}.ts`, shared type `types.ts`):
- hero `#hero-title`; primary CTA → `#voice` (`.button`), secondary text link → `#features`
- `#features` (cards: voice, calendar/reminders — `.feature-calendar` is a flex column and `.calendar-illustration` grows to the card bottom (WEB-1004; at desktop text200 the week panel shows ~460 px blank, accepted), notes/checklist/files, offline as a full-width card)
- live voice demo `#voice` (`VoiceDemo.tsx`, static fallback `VoiceExample.tsx`; plans block `.voice-plans` inside the section; `?developer=1` shows English-only developer text, not visitor-facing)
- FAQ `#questions` (8 items: download yet, free, account, voice, offline, family, notes, home screen/WhatsApp); closing `#get-taskflow` (lime button → `#voice`)
- `TaskDemo.tsx` (sample walkthrough) no longer exists; the agent prompt still names it.
- Other components: `Header`, `Footer` (back-to-top → `#main-content`, company name GARBAR), `LanguageSwitch` (cookie `taskflow-lang`, 1 year), `SkipLink`, `NotFoundPage`, `useSiteLanguage`. Language routing in `src/proxy.ts` (cookie, then Accept-Language).
- Hero screenshots: `public/images/hero-calendar-{en,es,ca}-{light,dark}.png` (one per language and theme), copied from the app's renders (see [[site-patterns]]); also drawn in `opengraph-image.<lang>.png`.

**Legal** (`LegalPage.tsx`, content `src/content/legal/{en,es,ca}.ts`, metadata/UI strings `index.ts`, company data `company.json`, styles `src/styles/legal.css`):
- h1 = the document's name; no eyebrow, no visible description (description is meta/og/twitter only).
- `.legal-version` line is only "In force since <date>" (Intl long date, UTC); company name lives in footer/legal notice/company card.
- privacy ids: controller, data, purposes, voice, sharing, transfers, retention, website (live demo + language cookie), permissions, rights, age-changes
- terms ids: operator, account, service, content, ai, subscription, withdrawal, ending, responsibility, complaints
- legal notice: company, scope, rights
- delete-account: in-app, request (in-app route first, bold "No app, or can't sign in? Email us:", mailto button, then mail details; h2 visually hidden on phones), scope, timing, subscription, other-rights. Language switch sits after the request box on this page only.

**Tests the loop maintains** (TaskFlowWeb `tests/`): `ux-web-voice.spec.ts`, `ux-web-legal.spec.ts`, `legal.spec.ts`, `ux-web-home.spec.ts`, `ux-web-features.spec.ts`, `ux-web-frame.spec.ts`, `ux-web-global.spec.ts`. A fixed finding is expected to have a test.

**Demo state renders** (artifacts/ux-web): voice-capture, voice-waiting-10s, voice-stop-waiting, voice-timeout, voice-connect-offline, voice-connect-gateway, voice-offline, voice-check-pending/-unreachable/-gave-up, voice-connect-paused (demo off), voice-resend-waiting, voice-typing, voice-error-budget-pause, plus results/tries-used. AUDIT §13 holds the demo-state rows (axe, announcement).

Related: [[claims-map]], [[site-patterns]].
