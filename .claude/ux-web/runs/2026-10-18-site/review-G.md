## UX web review — G (global: navigation, header and footer, languages, performance, accessibility, SEO and meta, light and dark) — recheck — 2026-10-19

**Verdict:** Ship after fixes. Measured, the frame is sound:
- axe found 0 violations on all 56 page states;
- every text colour pair passes in both themes;
- focus is visible at all 2,148 measured Tab stops;
- nothing scrolls sideways at 320 px or at 200% zoom.

But the Spanish or Catalan newcomer still meets:
- an English home and an English slogan as the link preview;
- a phone menu that promises a download that doesn't exist;
- a 404 page that's a pun;
- frame text of 8–11 px that doesn't grow when they ask the browser for bigger text.

**Walked** (journey, steps, people):
1. **A wrong URL** (`/es/eliminar-cuenta`), as the Leaver on a phone:
   - English 404 → "Back to TaskFlow" → the English home: 1 step, and the language is lost.
   - "Delete account" sits below the fold: y ≈ 760 at 390 px and y ≈ 782 at 320 px, so it takes 1 scroll and 1 tap.
2. **The Leaver from the Play listing** (WD13: `/delete-account/`):
   - «Español» is 1 tap, at y ≈ 154–200 on a phone;
   - on the Spanish page, the request button sits in the bottom third (y ≈ 569–623);
   - «Volver a TaskFlow» then lands on the English home.
3. **Arriving from the app** (WD11: the app will open `/es/privacy/` and `/es/terms/` in its own language):
   - the document is Spanish, but the header, the menu and the footer are English;
   - the footer's "Privacy" and "Delete account" open English pages.
4. **The newcomer on a phone:** menu → "Get TaskFlow" → the closing card → "Find your flow" → back up to `#demo`. 3 steps, and they loop.
5. **The Comparer on desktop:** "Explore the app ↗" lands on the website's sample walkthrough, which WD1 removes. 1 step, and the label doesn't match the place.
6. **Keyboard:** every page × viewport × theme (AUDIT §10, §14).
7. **Screen reader:** Chromium's accessibility tree and Playwright's ARIA snapshots (AUDIT §9, `aria/`).
8. **320 px, 200% zoom and doubled default text:** AUDIT §3, plus the `w320`, `zoom200` and `text200` renders.
9. **Light and dark, no JavaScript, a throttled phone:**
   - the renders, the `home-nojs` renders and lab performance (AUDIT §2);
   - all 56 WebKit renders, compared pixel by pixel with Chromium.
10. **Sharing:** AUDIT §11, `opengraph-image.png`, and the built `<head>`s in `.next/server/app/`.
- **People:** Newcomer (Spanish or Catalan, phone), Comparer (desktop), assistive-technology user, Leaver.
- **Languages:** EN on all 14 pages. ES and CA only on the 12 legal page versions; the home and the 404 have none (INDEX.md).
- **Evidence:**
  - Chromium renders and audit: built 20:45 UTC, measured 21:52–21:56 UTC on 2026-10-18, with `SITE_URL`;
  - WebKit renders: 00:19 on 2026-10-19, from a rebuild of the same source at 00:03 without `SITE_URL`;
  - all of them are newer than the newest website source (2026-10-16 08:01).
  - No device, no screen reader and no field data. Performance is lab data.

**Numbers** (first review → now, measured):
- **Languages:**
  - page × language versions that exist: 14 of 18;
  - `<html lang>` right: 6 of 14 (AUDIT §11: "lang is en" on all 8 ES and CA pages);
  - about 30 English strings in the frame of every ES and CA page (header, menu, footer, skip link and their accessible names);
  - a language switch on 12 of 14 pages, never in the header, the menu or the footer.
- **Link previews:**
  - `og:image` on 2 of 14 pages, `og:locale` on 0 of 14;
  - `twitter:title` matches the page on 2 of 14, and one of those two is the 404, which borrows the home's title;
  - the 404 also declares the home as its canonical URL.
- **Filled buttons in the desktop first viewport:**
  - home 2 and 404 2, both counting the header's "Explore the app";
  - delete-account 2;
  - privacy, terms and legal 1, the header's English button.
- **Names:**
  - `#demo` has 5 labels;
  - the phone header has 1 word, the wordmark, plus 2 icon-only 42 × 42 px buttons 11 px apart.
- **Steps to account deletion:**
  - from any footer: 1, but it lands on the English page;
  - in ES or CA: 2 through the footer, or 1 through the legal page's own link;
  - from the 404 on a phone: 1 scroll and 1 tap.
- **Type:**
  - 8 frame and eyebrow text styles are under 12 px; the smallest is 8 px;
  - 40–41% of the 404's characters are under 12 px (AUDIT §6);
  - with the browser's default text doubled, none of the 23–145 text elements per page grows (AUDIT §3). The `text200` renders I diffed are pixel-identical to the 100% ones: `home` mobile, `privacy.es` mobile, `not-found` desktop and `delete-account.ca` mobile full.
- **Contrast (AUDIT §7, §10):**
  - muted text 5.47:1 light and 8.86:1 dark;
  - the focus ring 5.76:1 and 10.47:1;
  - the closing card's ring **1.58:1** in light.
- **Keyboard:** 2,148 Tab stops; 0 with focus not visible; 0 hidden behind the sticky header; 1 element whose ring is under 3:1 (on desktop and mobile).
- **Lab performance (mobile, Lighthouse's throttling):**
  - home: LCP 1.82 s (1.77–1.98 s over 3 runs), CLS 0.000;
  - other pages: LCP 1.54–1.96 s, CLS 0.000;
  - Manrope TTF: 68 KB over the wire (164,700 bytes on disk), arriving 23–195 ms after first paint;
  - the home fetches both theme screenshots, 61 KB;
  - TBT is 125–817 ms with the same JavaScript on every page, which is single-run noise, not a finding.
- **WebKit (56 renders):**
  - every one draws Manrope at its thinnest weight;
  - 43 of 56, including 27 of 28 iPhone-profile renders, were captured with the theme switch still disabled (pre-hydration);
  - in Chromium, that happened in 0 of 84 fold renders.
- **Claims checked:** 6. False 2, misnamed 2, true 2.

**Attention** (predicted from the renders with GUIDELINES §21.4; nothing here is measured eye-tracking):
- **`home.en.desktop.*.fold`:**
  1. the H1, top-left;
  2. the hero screenshot in the right half, first looked at after about 2–3 s;
  3. two filled green buttons for the same `#demo`: "See it in action" and the header's "Explore the app ↗" in the top-right corner.
  - The muted 13 px nav is low salience. "For Android" isn't on screen.
- **`home.en.mobile.*.fold`:**
  1. the H1, in the top half;
  2. "See it in action", mid-screen;
  3. the wordmark and two unlabelled circles, a moon and a menu.
  - The frame adds no words, and the screenshot only enters the bottom third.
- **`privacy.es.desktop.light.fold`:**
  1. the H1;
  2. the header's English "Explore the app", the only filled button;
  3. the language pill.
  - An English nav sits above a Spanish H1.
- **`delete-account.ca.desktop.light.fold`:**
  1. the H1;
  2. «Escriure sol·licitud d'eliminació», which competes with the header's filled English button;
  3. the pill.
- **`delete-account.es.mobile.light.fold`:**
  1. the H1;
  2. the language pill, which is good;
  3. «Volver a TaskFlow».
  - The request button is in the bottom third, where Lagun 2014 measured about 14% of gaze.
- **`not-found.en.desktop.*`:**
  1. "Let's find your flow again.";
  2. "Back to TaskFlow";
  3. the header's filled "Explore the app": two filled buttons (CT-1).
  - "404" is in a 10 px eyebrow.
- **`not-found.en.mobile.*`:**
  1. the H1, an idiom;
  2. the button;
  3. the header circles.
  - Nothing large says "not found", and deletion is below the fold.
- **`opengraph-image.png`:**
  1. "Make room for a clearer day.";
  2. the wordmark;
  3. "A LITTLE FOCUS. A LITTLE FLOW.", which can't be read at thumbnail size.
  - No phone, task, calendar or Android.
- **WebKit, the same folds:** the same order, but with ExtraLight type and a faded moon (WEB-701, WEB-313).

### Rechecks at a glance
| ID | First | Now | What the new evidence says |
|---|---|---|---|
| WEB-301 | S3 | **S3, confirmed** | INDEX.md: no ES or CA home or 404; AUDIT §11: the home has no hreflang. WD5 now decides the bare `/`. Ledger: merged into WEB-2 |
| WEB-302 | S3 | **S3, confirmed** | AUDIT §11; `opengraph-image.png`. WD4 now decides the image |
| WEB-303 | S3 | **S3, confirmed** | `home-menu.en.mobile.*` and `privacy-menu.es.mobile.light`: "Get TaskFlow" is the last menu row, in English on the Spanish page. WD9: no pre-registration yet. Ledger: merged into WEB-3 |
| WEB-304 | S2 | **S2, confirmed** | AUDIT §11: lang "en" on 8 of 8 ES and CA pages; §9 and §14: English names; WD11 adds a journey from the app |
| WEB-305 | S2 | **S2, confirmed; fix updated for WD1** | AUDIT §14: stop 8 on every desktop page; §6: 11 px; `zoom200`: shown next to the menu at 720 px. Ledger: merged into WEB-4 |
| WEB-306 | S2 | **S2, confirmed; one point corrected** | AUDIT §11: the title and canonical are the home's; §6: 40–41% of characters under 12 px. The "box" glyph comes from the render machine, not phones |
| WEB-307 | S2 | **S2, confirmed** | Renders; AUDIT §5: 42 × 42, 11 px apart; §9: "Open navigation"; §14: the theme switch comes before the menu. Forced colours still inferred |
| WEB-308 | S2 | **S2, confirmed, now measured** | AUDIT §10: 1.58:1 on desktop and mobile, light; `focus/home.en.desktop.light.31.png` |
| WEB-309 | S2 | **S2, confirmed, measured; citation corrected** | AUDIT §3: nothing grows at text200; pixel-identical renders. Not a 1.4.4 failure, because zoom works |
| WEB-310 | S2 | **Withdrawn** | AUDIT §3: no sideways scroll at text200, zoom200 or w320 on any page. Its check moves into WEB-309 |
| WEB-311 | S1 | **S1, corrected** | AUDIT §2: the font is 68 KB over the wire, not 165 KB; CLS 0.000; LCP passes. The double image fetch is confirmed |
| WEB-312 | S1 | **S1, confirmed** | AUDIT §11 |
| WEB-313 | S1 | **S1, confirmed, more evidence** | Built HTML; the no-JS renders; WebKit: 43 of 56 renders show the disabled switch |
| WEB-701 | — | **S2, new (device check)** | WebKit draws all type at weight 200 |
| WEB-702 | — | **S1, new** | Taps give no feedback on links without hover styles |
| WEB-703 | — | **S1, new** | Logo, footer and "Back to top" targets under 44 px |
| WEB-704 | — | **S1, new** | No Android trademark line (owner decision, 2026-10-18) |

### Findings (most severe first)

**WEB-301 · Severity 3 · No Spanish or Catalan home, and no way to switch**
*(Recheck: confirmed. Ledger: merged into WEB-2; written in full here so the plan has the G half.)*
- **Where:**
  - `src/app/page.tsx` is English only. `src/app/[language]/` holds only `[document]/page.tsx`, so `/es/` and `/ca/` return the English 404.
  - `src/components/Header.tsx:28-69` and `src/components/Footer.tsx:4-46` have no language switch. The only one is the legal pages' (`src/components/LegalPage.tsx:113-125`).
  - Their back link (`LegalPage.tsx:110-112`) and every logo go to the English `/`.
  - Evidence: INDEX.md, "Languages the site doesn't have"; AUDIT §11 (the home has no hreflang); renders `home.en.mobile.light.fold.png` and `privacy.es.mobile.light.fold.png`.
- **The moment:**
  - The newcomer opens a WhatsApp link: «Esto está en inglés… ¿qué es?»
  - The Leaver on `/es/delete-account/` taps «Volver a TaskFlow»: «¿Por qué ahora en inglés?»
- **What happens:**
  - The main entry page exists only in English, and nothing in the header, the menu or the footer offers Español or Català.
  - A language picked on a legal page is lost on the next tap home.
- **Why it fails:**
  - ML-5 (CSA 2020: 76% prefer their own language and 40% never buy in another; self-reported);
  - ML-4 (a switch in the header or menu of every page);
  - ML-1 (stable URLs per language; only the bare root may choose);
  - ML-3;
  - NV-7;
  - the owner wants the site's copy in three languages (`.claude/ux-web/DECISIONS.md:75`) and decided how the bare `/` behaves (WD5, `:39-41`);
  - the reviewer's scale rates "an entry page not in the newcomer's language" as Major.
- **Fix:**
  1. **The homes:** `/es/` and `/ca/`, written by a fluent speaker from the copy area H settles, not from today's idioms. Each sets its own canonical and `alternates.languages`: `en` → `/`, `es` → `/es/`, `ca` → `/ca/`, `x-default` → `/`.
  2. **The bare `/` only (WD5):**
     - a server-side check (Next 16 `src/proxy.ts`, matching `/` exactly; docs in `node_modules/next/dist/docs/01-app/01-getting-started/16-proxy.md`);
     - it answers 307 → `/es/` or `/ca/` when the visitor's stored choice says so, or, with no choice, when `Accept-Language` prefers es or ca;
     - never by IP, and English otherwise;
     - the response carries `Vary: Accept-Language, Cookie` and `Cache-Control: private, no-store`, so a CDN never serves one visitor's redirect to another;
     - no other path ever redirects.
  3. **A language switch in the frame of every page:** "English · Español · Català" as plain links, with no `<select>` and no flags (OL-3).
     - **Where:** in the desktop header, where "Explore the app" was (WEB-305); as the phone menu's first row; and in the footer.
     - **Each link:** carries its own `lang` and `hreflang`, and keeps the visitor on the same page (`/privacy/` ↔ `/es/privacy/`, `/` ↔ `/es/`).
     - **The current language:** `aria-current="page"` plus a cue that isn't colour (bold and a check icon). The legal pill today shows it only by a fill of 1.12:1 light and 1.43:1 dark (AUDIT §8; WEB-208), so fix that pattern once for both.
     - **The name:** "Language" · «Idioma» · «Idioma».
  4. **Remember the choice (WD5):** a tap stores it in a first-party preference cookie (for example `taskflow-lang`, 12 months), which step 2 reads. Privacy §8 lists it beside `taskflow-theme`; that's area L (WD3).
  5. **Every frame link keeps the prefix:** the logo, the nav anchors (`/es/#voice`), the footer links and «Volver a TaskFlow». The sitemap lists `/es/` and `/ca/` (`src/app/sitemap.ts:13-20`).
  6. **Fit:** the desktop header must fit in Catalan at 801 px with the new labels (WEB-305) and the switch. If it doesn't, show the phone menu up to 1024 px (the breakpoint is 800 px today, `src/styles/global.css:1640`).
- **Files:**
  - clean: `page.tsx`, `Header.tsx`, `global.css`;
  - new: `src/proxy.ts`;
  - the other session's uncommitted lines: `Footer.tsx`, `layout.tsx` (line 8), `sitemap.ts`;
  - the other session's untracked files: `src/app/[language]/`, `LegalPage.tsx`, `legal.css`;
  - tests that pin today's frame: `tests/website.spec.ts:84, 114-130, 143`; `tests/legal.spec.ts:24`.
- **Verify:**
  - `/es/` and `/ca/` return 200 with `<html lang="es">` and `lang="ca"`;
  - INDEX.md no longer lists the home under missing languages;
  - AUDIT §11 shows en, es, ca and x-default on all three homes;
  - `/` answers 307 to `/es/` for `Accept-Language: es-ES` and 200 for `en`, and a stored "English" choice beats an `es` header; the response has `Vary` and `Cache-Control: private`;
  - Playwright on `/`, `/es/`, `/ca/privacy/` and the 404: the switch is visible on desktop and inside the open menu on mobile, with `hreflang` set;
  - from `/es/privacy/`, the logo, «Volver a TaskFlow» and every footer link stay under `/es/`;
  - renders at 801, 1024 and 1100 px in Catalan: nothing scrolls sideways.
- **Evidence:** verified in the code and the build; seen in current renders; measured (AUDIT §11).

**WEB-302 · Severity 3 · The link preview doesn't say what TaskFlow is**
*(Recheck: confirmed. WD4 now decides the image.)*
- **Where:**
  - `src/app/layout.tsx:11-13, 24-31`: the title, description, Open Graph and X tags;
  - `src/app/opengraph-image.tsx:3`: the alt text, the slogan;
  - `opengraph-image.tsx:57-83`: the wordmark, the slogan and the tagline, drawn in a generic `sans-serif` (`:18`), not Manrope;
  - AUDIT §11; render `opengraph-image.png`.
- **The moment:** a WhatsApp link shows a big slogan and "A little focus. A little flow. Meet the calm task planner…": «¿Qué es esto? ¿Una app? ¿De qué?»
- **What happens:**
  - The image shows no phone, no task and no Android.
  - The tab and search title is the same slogan.
  - The description says "voice-to-task capture", where the app says "dictation", «dictado» and «dictat».
  - Everything is in English, with no `og:locale` on any of the 14 pages (AUDIT §11).
- **Why it fails:**
  - ML-9 (the product and the promise, in the page's language);
  - HE-1 and HE-2: the competitor test fails, because any planner could say it;
  - HE-10 ("capture");
  - ML-8;
  - FN-2;
  - EY-3;
  - GUIDELINES §21.3: for the newcomer, the preview comes before the page.
- **Fix** (the title follows the H1 that H settles; this copy matches WP3's "Say it, and it's on your calendar"):
  - **`<title>` and `og:title`:**
    - EN: "TaskFlow — Say it, and it's on your calendar"
    - ES: «TaskFlow — Dilo y ya está en tu calendario»
    - CA: «TaskFlow — Digues-ho i ja és al teu calendari»
  - **Description and `og:description`** (the first sentence is the app's `authPitch`: `App/lib/l10n/app_en.arb:674`, `app_es.arb:412`, `app_ca.arb:391`):
    - EN: "Note down what you need to do, and TaskFlow puts it on your calendar. Say several things at once. For Android phones, coming soon to Google Play."
    - ES: «Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario. Di varias cosas a la vez. Para móviles Android, muy pronto en Google Play.»
    - CA: «Apunta el que has de fer i TaskFlow ho posa al teu calendari. Digues diverses coses alhora. Per a mòbils Android, aviat a Google Play.» The Catalan needs a native read.
  - **Image (WD4):**
    - 1200 × 630, with the title line in Manrope at 64 px or more on the left;
    - on the right, the top of `public/images/hero-calendar-<language>-light.png` in a phone outline, showing "Call the dentist" and "Buy bread" on tomorrow;
    - no tagline, and legible at 300 px wide;
    - one per language: `src/app/opengraph-image.tsx` for `/`, plus `src/app/[language]/opengraph-image.tsx` alongside WEB-301's homes.
  - **The image's `alt`,** matching the text in WD4's renders:
    - EN: "TaskFlow's calendar on an Android phone, with “Call the dentist” and “Buy bread” on tomorrow"
    - ES: «El calendario de TaskFlow en un móvil Android, con «Llamar al dentista» y «Comprar pan» para mañana»
    - CA: «El calendari de TaskFlow en un mòbil Android, amb «Trucar al dentista» i «Comprar pa» per a demà»
  - **Locale:** `openGraph.locale` en_US (the site's English is American), es_ES or ca_ES, with `alternateLocale` the other two. `twitter` carries the same title and description.
  - **A note on the bare domain (WD5):** a link-preview fetcher rarely sends a Spanish `Accept-Language`, so `taskflow.garbar.tech` will usually preview in English.
    - The switch keeps the language in the URL, so links copied from a Spanish page carry `/es/`.
    - Links the owner shares himself should be `/es/` or `/ca/`.
- **Files:** `opengraph-image.tsx` (clean); `layout.tsx` (the other session's line 8 only); new files under `src/app/[language]/` (that folder is the other session's and untracked).
- **Verify:**
  - the built `<head>` of each home carries the new title and description, `og:locale` and an `og:image` of its own language;
  - `opengraph-image.png`, and its ES and CA versions, show the phone screen and read at 300 px wide;
  - device check after the owner deploys: paste `…/es/` and the bare domain into WhatsApp on a Spanish phone.
- **Evidence:** measured (AUDIT §11); seen in the current `opengraph-image.png`; verified in the code.

**WEB-303 · Severity 3 · "Get TaskFlow" promises a download that doesn't exist**
*(Recheck: confirmed by the menu renders. Ledger: merged into WEB-3.)*
- **Where:**
  - `src/components/Header.tsx:62-64`, in the phone menu at 800 px and narrower;
  - it leads to `src/app/page.tsx:399-428` (`#get-taskflow`), whose button (`:419`) goes back to `#demo`;
  - renders `home-menu.en.mobile.light.fold.png` and `privacy-menu.es.mobile.light.fold.png`: the last row, in English on the Spanish page.
- **The moment:** «Get TaskFlow, ¡ahí!» They land on "Less on your mind. More room for life." and a "Find your flow" button that scrolls them back up: «¿Dónde se descarga?»
- **What happens:**
  - The only "get it" item in the frame lands on a card whose button loops.
  - The truth, "Android app in development · Public download coming soon", is 10 px text under that button (AUDIT §6, `.launch-note`).
- **Why it fails:**
  - CT-4 (the destination keeps the label's promise);
  - AP-5 (before launch, say "Coming soon to Android" in plain text);
  - CT-3;
  - the owner: "Until then, the calls to action must be honest" (`.claude/ux-web/DECISIONS.md:68`); no pre-registration yet (WD9, `:45-46`).
- **Fix:**
  - Rename the row "Coming soon to Android" · «Próximamente en Android» · «Properament a Android», still to `#get-taskflow`.
  - Area H's closing card must open with that line, in body-size text, and nothing on it may loop back.
  - The Android ™ goes on the first "Android" in the page's main content, not on this row (WEB-704).
  - When Play has the app (package `tech.garbar.taskflow`, `.claude/ux-review/DECISIONS.md:53`), the row becomes the Play link (AP-3).
- **Files:** `Header.tsx` (clean); `tests/website.spec.ts:114-130`.
- **Verify:**
  - at 390 px, the open menu has no "Get" row;
  - the row lands on a view whose first line says the app can't be downloaded yet (Playwright text check);
  - walking it, nothing loops back.
- **Evidence:** verified in the code; seen in current renders.

**WEB-304 · Severity 2 · Spanish and Catalan pages keep an English frame**
*(Recheck: confirmed and measured.)*
- **Where:**
  - `src/app/layout.tsx:43`: `<html lang="en">`; `:56-58`: "Skip to content";
  - `src/components/Header.tsx:7-12, 31, 39, 49, 52, 56, 63`; `src/components/ThemeProvider.tsx:82-85`;
  - `src/components/Footer.tsx:9-43`, whose legal links (`:27-31`) always open the English pages;
  - AUDIT §11 ("lang is en, not es/ca" on 8 of 8 pages), §9 (landmarks "Main navigation", "Footer navigation" and "Legal and privacy") and §14 (English names in the tab order of `/es/…` and `/ca/…`);
  - render `privacy-menu.es.mobile.light.fold.png`.
- **The moment:**
  - The Leaver, reading in Spanish, taps "Delete account" in the footer and gets an English page: «¿Me he equivocado?»
  - From the app (WD11), «Privacidad» opens `/es/privacy/` inside an English header, menu and footer.
- **What happens:**
  - About 30 frame strings stay English on all 8 ES and CA pages.
  - The `<title>` is Spanish but sits under `lang="en"`, so it's announced with an English voice.
  - Only `<article lang>` (`LegalPage.tsx:107`) is right.
- **Why it fails:**
  - ML-5 (translate everything, including names and the skip link);
  - ML-2 and WCAG 3.1.1. The page-level failure is arguable while the frame really is English, but the title isn't;
  - PV-7 (deletion in each language);
  - NV-7;
  - TR-3 (untranslated strings are trust bugs);
  - FN-2: the app's Catalan for deletion is «Suprimeix el compte» (`App/lib/l10n/app_ca.arb:910`).
- **Fix:**
  1. `<html lang>` follows the route: es, ca or en. WP2's pre-paint approach is fine; without JavaScript it stays `en`, an accepted remainder.
  2. The header, menu, footer, skip link, theme switch and every `aria-label` take the page's language, and the footer's legal links use `legalPath(document, language)`.
  3. Subtract before translating: "A little focus. A little flow." (`Footer.tsx:17`, WD6) and "Made for a little more headspace." (`:37-42`) go.
  4. Rename "Contact support" to say what happens, since it opens an email draft (RD-7).
  5. The strings (nav labels in WEB-305; appearance words from the app, `app_en.arb:245-247`, `app_es.arb:180-182`, `app_ca.arb:159-161`):

     | EN | ES | CA |
     |---|---|---|
     | Skip to content | Saltar al contenido | Salta al contingut |
     | TaskFlow home | Inicio de TaskFlow | Inici de TaskFlow |
     | Main navigation (also the phone menu's nav) | Navegación principal | Navegació principal |
     | Menu | Menú | Menú |
     | Appearance · Light · Dark | Apariencia · Claro · Oscuro | Aparença · Clar · Fosc |
     | Switch to dark mode / light mode | Cambiar a modo oscuro / claro | Canvia al mode fosc / clar |
     | Language | Idioma | Idioma |
     | A product by {company} | Un producto de {company} | Un producte de {company} |
     | Footer navigation | Navegación del pie de página | Navegació del peu de pàgina |
     | Legal and privacy | Legal y privacidad | Legal i privacitat |
     | Privacy | Privacidad | Privacitat |
     | Terms and Conditions | Términos y condiciones | Termes i condicions |
     | Legal Notice | Aviso legal | Avís legal |
     | Delete account | Eliminar cuenta | Suprimeix el compte |
     | Email support | Escribir a soporte | Escriu al suport |
     | Back to top | Volver arriba | Torna a dalt |
- **Files:**
  - the other session's uncommitted lines: `layout.tsx` (line 8), `Footer.tsx` (lines 2, 18, 26-32, 34-36);
  - clean: `Header.tsx`, `ThemeProvider.tsx`;
  - tests: `tests/website.spec.ts:114-130`.
- **Verify:**
  - `html[lang]` is es or ca on `/es/privacy/` and `/ca/delete-account/` (AUDIT §11 problem column empty);
  - a Playwright text and name scan finds no English in the header, the open menu, the footer or their accessible names on ES and CA pages;
  - the footer's deletion link reads «Eliminar cuenta» or «Suprimeix el compte» and stays in the language;
  - device check: TalkBack reads the title in Spanish.
- **Evidence:** measured (AUDIT §9, §11, §14); verified in the build and the code; seen in renders.

**WEB-305 · Severity 2 · The header button misnames the demo; one place has five names**
*(Recheck: confirmed. Fix updated for WD1: the walkthrough is removed, so `#demo` disappears. Ledger: merged into WEB-4.)*
- **Where:**
  - `src/components/Header.tsx:48-50`: a filled "Explore the app" with a north-east arrow (`Icon.tsx:4`, the "leaves the site" glyph), at 581 px and wider;
  - AUDIT §14: stop 8 on every desktop page; §6: 11 px; the `zoom200` render shows it next to the menu at 720 px;
  - `#demo` is also reached from `Header.tsx:9`, `Footer.tsx:22` ("Try the demo"), `page.tsx:68` and `:419`;
  - renders `home.en.desktop.light.fold.png` and `delete-account.ca.desktop.light.fold.png`, where it's an English filled button above the Catalan request button.
- **The moment:** the Comparer clicks "Explore the app ↗" expecting the app or its store page, and lands on a sample form on the website: "So where's the app?"
- **What happens:**
  - `#demo` has 5 labels, `#features` 2 and `#voice` 2.
  - The nav order doesn't follow the page.
  - "Questions" lands on "Glad you asked."
- **Why it fails:**
  - CT-1 and CT-2 (one primary per view);
  - CT-3 ("Explore");
  - CT-4;
  - NV-4 (anchor text matches the heading);
  - lens G (one concept, one name).
- **Fix:**
  1. Remove the header button (`Header.tsx:48-50`; `.header-cta`, `global.css:1968-1970`). Its slot takes the language switch (WEB-301). When Play has the app, the store link may come back (AP-1 to AP-3).
  2. One label per destination, in page order once WP1 moves the live demo under the hero, the same in the header, the menu and the footer:

     | Destination | EN | ES | CA |
     |---|---|---|---|
     | `#voice` | Try it with your voice | Pruébalo con tu voz | Prova-ho amb la teva veu |
     | `#features` | What it does | Qué hace | Què fa |
     | `#questions` | Questions | Preguntas | Preguntes |
     | `#get-taskflow` (phone menu only) | Coming soon to Android | Próximamente en Android | Properament a Android |

     The section headings H settles should start with the same words (NV-4).
- **Files:** `Header.tsx`, `global.css` (clean); `Footer.tsx` (the other session's lines elsewhere).
- **Verify:**
  - no filled button in the header of any desktop fold render;
  - each anchor has one label across `Header.tsx`, `Footer.tsx` and `page.tsx`;
  - the nav order matches the section order;
  - no link points at `#demo`.
- **Evidence:** measured (AUDIT §6, §14); verified in the code; seen in renders.

**WEB-306 · Severity 2 · The 404 page is an English pun that hides "not found"**
*(Recheck: confirmed, with one correction: the missing-glyph box in the Chromium render comes from the render machine. WebKit on Windows draws "↗" from a fallback font. Phones depend on their system fonts. The point stands that "↗" isn't in Manrope and reads as "leaves the site".)*
- **Where:**
  - `src/app/not-found.tsx:4-13`;
  - AUDIT §11: the title, description, canonical (`https://taskflow.garbar.tech/`) and `og:url` are the home's, inherited from `layout.tsx:11-31`;
  - AUDIT §6: the "404 / A LITTLE OFF TRACK" eyebrow is 10 px (8 px on phones), and 40–41% of the page's characters are under 12 px;
  - renders `not-found.en.mobile.light.full.png` (deletion at y ≈ 760) and `mobile-w320` (y ≈ 782);
  - `webkit/not-found.*`.
- **The moment:** the Leaver types `/es/eliminar-cuenta` and reads "Let's find your flow again.": «¿Qué flujo? ¿Funciona la web?»
- **What happens:**
  - The H1 is a pun, and the only plain sentence is muted.
  - It's English for every URL, `/es/…` and `/ca/…` included.
  - Tabs, screen readers and link previews get the home's title; the page even declares the home as its canonical URL.
  - Two filled buttons: "Back to TaskFlow" and the header's.
  - On phones, "Delete account" is below the fold.
- **Why it fails:**
  - HE-3;
  - RD-1;
  - OL-2 (say what happened and what to do);
  - ML-5;
  - AX-5 and WCAG 2.4.2 Page Titled (A);
  - ML-8;
  - PV-7 (deletion in one step).
- **Fix:** remove the eyebrow, the pun and the glyph, and write one short block per language. The page's language comes first as the `h1`; the other two are `h2`s, each with its own `lang`.
  - **EN:** "Page not found". "This address doesn't exist on the TaskFlow website." Links: "Go to the TaskFlow home page" (`/`) and "Delete account" (`/delete-account/`).
  - **ES:** «Página no encontrada». «Esta dirección no existe en la web de TaskFlow.» Links: «Ir al inicio de TaskFlow» (`/es/`) and «Eliminar cuenta» (`/es/delete-account/`).
  - **CA:** «No hem trobat aquesta pàgina». «Aquesta adreça no existeix al web de TaskFlow.» Links: «Ves a l'inici de TaskFlow» (`/ca/`) and «Suprimeix el compte» (`/ca/delete-account/`).
  - **Metadata:** the root not-found file supports `export const metadata` (`node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/not-found.md:185-187`):
    - title "Page not found · Página no encontrada · No hem trobat la pàgina — TaskFlow";
    - no canonical (`alternates: { canonical: null }`) and no `og:url`.
  - **Layout:** the deletion links sit above the fold at 390 × 664 and at 320 × 568.
- **Files:** `not-found.tsx` (clean); `tests/website.spec.ts:143` pins "Back to TaskFlow".
- **Verify:**
  - AUDIT §11's 404 row shows its own title and no canonical;
  - the 404 renders show the three blocks, with deletion links above the fold at both widths;
  - no "↗" anywhere on the page;
  - axe `document-title` passes.
- **Evidence:** measured (AUDIT §6, §11); seen in Chromium and WebKit renders; the font's character map has no U+2197 (parsed from `public/fonts/Manrope.ttf`).

**WEB-307 · Severity 2 · Phone header: two unlabelled icons, and the theme switch outranks the menu**
*(Recheck: confirmed. Forced colours still inferred.)*
- **Where:**
  - `src/components/Header.tsx:47, 51-55`; `src/components/ThemeProvider.tsx:87-105`; `src/styles/global.css:313-321, 1656-1680`;
  - AUDIT §5: both 42 × 42 px, 11 px apart; §9: the summary is named "Open navigation", even when open; §14: the theme switch is the stop before the menu;
  - renders `home.en.mobile.light.fold.png` and `delete-account.es.mobile.light.fold.png`.
- **The moment:** «¿Qué es la luna? ¿Y las dos rayas?» The newcomer doesn't open menus.
- **What happens:**
  - The phone header's only controls are a moon or sun and two lines, with no words.
  - The theme switch has the same weight as the menu.
  - A tap outside doesn't close the menu (no handler in `Header.tsx`).
  - The two lines are `<span>` backgrounds (`global.css:1668-1674`), which forced-colours mode repaints in the page colour. That's inferred: there's no forced-colours render.
- **Why it fails:**
  - AX-8 (controls show words; Harley 2014);
  - NV-1 (visible navigation used 86% vs 57% hidden on phones; Pernice 2016a);
  - CT-6 and CT-7 (44–48 px; WCAG 2.5.8 passes);
  - OL-4;
  - lens N.
- **Fix,** at 800 px and narrower:
  1. The menu button shows a word, "Menu" · «Menú» · «Menú», next to an SVG icon. Add a `menu` path to `Icon.tsx`; `currentColor` survives forced colours. Drop `aria-label` so the word is the name.
  2. The theme switch moves into the menu as an "Appearance" row with two buttons, "Light" and "Dark", in the app's words (WEB-304's table). It uses `aria-pressed` and a check on the current one. Desktop keeps the icon.
  3. The language row (WEB-301) is the menu's first row.
  4. Make both header targets 48 × 48 px.
  5. Optionally, close the menu on a tap outside it.
- **Files:** `Header.tsx`, `ThemeProvider.tsx`, `Icon.tsx`, `global.css` (all clean); update `tests/website.spec.ts:114-130`.
- **Verify:**
  - the mobile fold renders show «Menú» or "Menu" and one header control;
  - Playwright at 390 px: the summary's name is «Menú» on `/es/…`, and the theme row is inside the open menu;
  - a screenshot with `forcedColors: 'active'` shows the menu icon;
  - AUDIT §5 measures 48 px.
- **Evidence:** measured (AUDIT §5, §9, §14); seen in renders; forced colours inferred, so a browser check.

**WEB-308 · Severity 2 · Keyboard focus nearly vanishes on the closing card in light mode**
*(Recheck: confirmed, now measured.)*
- **Where:**
  - `src/styles/global.css:99-102`: a 3 px `var(--green)` outline, 5 px out;
  - it lands on `.closing-card`, which is `#214c38` in both themes (`global.css:1358-1367`), around "Find your flow" (`page.tsx:419-421`);
  - AUDIT §10, "Focus ring under 3:1": 1.58:1 on desktop and mobile, light; `focus/home.en.desktop.light.31.png`.
- **The moment:** a keyboard user tabs to the page's last call to action: "Where am I?"
- **What happens:** the ring is `#176e59` on `#214c38`, at 1.58:1. In dark it's 5.86:1, and elsewhere in light 5.76:1.
- **Why it fails:** AX-4 and AX-2: WCAG 2.4.7 (AA) and 1.4.11 (AA, 3:1).
- **Fix:** `.closing-card :focus-visible { outline-color: var(--lime); }`, which is `#d4eca3` on `#214c38` at 7.57:1 in both themes. It applies to whatever control H's new closing card keeps.
- **Files:** `global.css` (clean).
- **Verify:** AUDIT §10 lists no ring under 3:1, and `focus/home.en.*.light.*` shows a pale ring.
- **Evidence:** measured (AUDIT §10); seen in the focus screenshot.

**WEB-309 · Severity 2 · The frame's small print is 8–11 px and ignores the text-size setting**
*(Recheck: confirmed and measured. Citation corrected: it isn't a WCAG 1.4.4 failure, because page zoom works (the `zoom200` renders reflow, AUDIT §3); it fails RD-5 and the older-reader evidence. It now carries WEB-310's check.)*
- **Where:**
  - in `src/styles/global.css`:
    - `:59`: body text 15 px;
    - `:121-126` and `:2088-2091`: the eyebrow, 10 px and 8 px on phones, with 1.75 px tracking;
    - `:176-182`: `.button-small`, 11 px;
    - `:1458-1462`: the footer's lines, 10 px;
    - `:1468-1477` and `:2321-2325`: the footer's bottom row, 10 px;
  - `src/styles/legal.css:322-326`: the operator line, 11 px;
  - every size is in px.
- **Measured:**
  - AUDIT §6: footer tagline, ©, note and "Back to top" 10 px; operator 11 px; header button 11 px; legal and 404 eyebrows 10/8 px; 40–41% of the 404's characters and 38–39% of the home's are under 12 px.
  - AUDIT §3: with the default font doubled (root 32 px), body stays 15 px and **none** of the 23–145 text elements per page grows.
  - `home.en.mobile`, `privacy.es.mobile`, `not-found.en.desktop` and `delete-account.ca.mobile` (full) are pixel-identical between 100% and `text200`.
  - On phones the eyebrow's tracking pulls «E l i m i n a r  c o m p t e» apart (`delete-account.ca.mobile-w320.light.fold.png`).
- **The moment:** the 60+ newcomer: «No leo eso». "A product by GARBAR, IN-TEC, S.L.", which says who runs TaskFlow, is among the smallest text on the page.
- **Why it fails:**
  - RD-5 (body 16 px or more in rem; small print 12 px or more);
  - OL-1 (Nielsen 2013; Kane 2019: tiny type stays older adults' recurring problem);
  - TR-1 (the operator line must be readable);
  - ML-7.
- **Fix:**
  1. Size the frame in rem with the root at 100%: body 1rem, and a floor of 0.75rem (12 px) for eyebrows, footer lines, the operator line and small buttons.
  2. Remove the footer's decorative lines (WEB-304, WD6) instead of enlarging them.
  3. `.eyebrow { text-transform: uppercase; }`, with eyebrow strings written in sentence case, so translations don't hard-code capitals.
- **Files:** `global.css` (clean); `legal.css` (the other session's, untracked).
- **Verify:**
  - AUDIT §6 lists no frame text under 12 px;
  - AUDIT §3's "Text that grew" is no longer "none" on any page;
  - **WEB-310's check:** at `text200` on mobile and at 320 px, nothing scrolls sideways (§3), the header fits and the language switch wraps;
  - device check: Android at its largest font size on a 360 px phone.
- **Evidence:** measured (AUDIT §3, §6); pixel diff of the renders; verified in the code.

**WEB-701 · Severity 2 · WebKit draws every weight at Manrope's thinnest (device check)**
*(New.)*
- **Where:**
  - `src/styles/global.css:3-9`: one variable TTF, `font-weight: 200 800`;
  - the font's weight axis defaults to 200 (parsed from `public/fonts/Manrope.ttf`'s `fvar`: wght 200–800, default 200);
  - all 56 renders in `artifacts/ux-web/webkit/`, for example `webkit/home.en.mobile.light.fold.png`, `webkit/not-found.en.mobile.light.fold.png` and `webkit/privacy.es.mobile.light.fold.png`.
- **The moment:** on an iPhone, if this is real: a thin H1, thin buttons, and an 8–10 px eyebrow and footer that almost disappear (crop `crops/not-found.en.mobile.light.full.s1-2.png` from the WebKit 404).
- **What happens:**
  - Chromium draws the specified weights: headings 650, buttons 750, wordmark 800.
  - Playwright's WebKit on Windows draws every text element at ExtraLight, the font's default instance, on every page, viewport and theme.
- **Why it fails, if it's real:** RD-5 and OL-1 (Kane 2019: pale, thin type is a recurring barrier for older readers); TR-3.
- **Likely cause:** Playwright's Windows WebKit build not applying variable-font weights. Safari on iPhone and Mac uses Core Text, which does apply them, so it's probably not what iPhone visitors see.
- **Fix:**
  - **First, the device check:** open `/`, `/es/privacy/` and the 404 in Safari on an iPhone (and on a Mac).
  - **If the type is bold there:** no site change. Close this as a WebKit-on-Windows artifact, and note it in `artifacts/ux-web/webkit/INDEX.md` (main session) so future WebKit renders aren't misread for weight.
  - **If it's thin there:** load Manrope through `next/font/local` as static WOFF2 files for the weights the CSS uses (400, 600, 700, 800; round 650 to 600 and 750 to 700). Then raise this to Severity 3.
- **Files:** `global.css`, `layout.tsx` (with WEB-311).
- **Verify:** the device check above, with a photo of the iPhone home fold.
- **Evidence:** seen in all 56 WebKit renders, against Chromium's; the font axis verified from the file; the cause inferred, so it needs a real iPhone.

**WEB-311 · Severity 1 · First view fetches both theme screenshots and a TTF font**
*(Recheck: corrected. AUDIT §2's lab run withdraws the "headline jumps" claim (CLS 0.000) and the 165 KB figure.)*
- **Where:**
  - `src/styles/global.css:3-9` and `src/app/layout.tsx:45-51`: `/fonts/Manrope.ttf`, `font-display: swap`;
  - the built `<head>` preloads it twice; browsers fetch it once;
  - `src/components/Phone.tsx:29` (`preload`) and `:38` (`loading="eager"`): the built `index.html` preloads both `agenda-light` and `agenda-dark`;
  - AUDIT §2: home LCP 1.82 s (1.77–1.98 s over 3 runs), CLS 0.000, the font 68 KB over the wire arriving 195 ms after first paint, 2 images at 61 KB;
  - the LCP element is `img.light-only`.
- **The moment:** on mobile data, the first paint shows the fallback typeface and swaps to Manrope about 0.2 s later. A light-theme visitor also downloads the dark screenshot they never see.
- **Why it fails:**
  - PF-5 (`next/font`, variable fonts and subsets);
  - PF-3 and the installed Next 16.4 docs: "You cannot use `preload` or `loading="eager"` because that would cause both images to load. Instead, you can use `fetchPriority="high"`" (`node_modules/next/dist/docs/01-app/03-api-reference/02-components/image.md:1266-1331`);
  - PF-7.
  - The lab passes PF-1 today, so this is waste, not a slow page (PF-2: lab, not field).
- **Fix:**
  - Load Manrope with `next/font/local` as a WOFF2 Latin and Latin-1 subset (Catalan's `l·l`, `ª` and `º` are in it), with its automatic fallback.
  - Delete the manual preload and the `@font-face`.
  - For the light/dark pair, and for WD4's new `hero-calendar-<language>-<theme>.png` that replace it: no `preload`, no `eager`, `fetchPriority="high"` on both.
- **Files:** `layout.tsx` (the other session's line 8 only); `global.css`, `Phone.tsx` (clean).
- **Verify:** AUDIT §2 on the home shows:
  - one font request (WOFF2) and one hero image request;
  - lab LCP at most 2.5 s, and no worse than today's 1.82 s median;
  - CLS at most 0.1.
- **Evidence:** measured (AUDIT §2); verified in the build and the docs.

**WEB-312 · Severity 1 · Legal pages share without an image; their X tags are the home's**
*(Recheck: confirmed and measured.)*
- **Where:**
  - `src/content/legal/index.ts:190-194`: `openGraph` has no `images`, `locale`, `siteName` or `type`, and there's no `twitter`;
  - AUDIT §11 on all 12 legal pages: "no og:image; no og:locale; twitter:title isn't this page's title";
  - built `es/privacy.html`: `twitter:title` "TaskFlow — Make room for a clearer day", with the English home description.
- **The moment:** `/es/privacy/` shared on WhatsApp is a bare text link. On X or Slack, an English slogan sits over a Spanish page.
- **Why it fails:** ML-9 and ML-5.
- **Fix:** in `legalMetadata`, add:
  - `openGraph.images`: the language's preview image from WEB-302;
  - `locale`, with `alternateLocale`;
  - `siteName: "TaskFlow"` and `type: "website"`;
  - `twitter: { card: "summary_large_image", title, description }` with the document's own title and description.
- **Files:** `src/content/legal/index.ts` (the other session's, untracked: stays uncommitted).
- **Verify:** AUDIT §11 shows no problems in the og or twitter columns for all 12 legal pages.
- **Evidence:** measured (AUDIT §11); verified in the build.

**WEB-313 · Severity 1 · Before the scripts run: a greyed-out switch and a light toolbar**
*(Recheck: confirmed, with more evidence.)*
- **Where:**
  - `src/app/layout.tsx:33-38`: one `theme-color`, `#f7f8f2`;
  - `layout.tsx:39`: the inline script sets `data-theme`, not the meta;
  - `src/components/ThemeProvider.tsx:24-30` (`apply()` updates one meta after hydration) and `:93` (`disabled={!ready}`);
  - `src/styles/global.css:91-94`: disabled is 55% opacity.
- **Measured:**
  - The built HTML of every page ships the switch `disabled` and labelled "Switch to dark mode", even for dark visitors.
  - After hydration, dark renders carry `#121c18` (audit meta), so the mismatch lasts until the scripts run.
  - Without JavaScript, it lasts forever: `home-nojs.en.mobile.dark` is identical to light, a light page with a dead, faded switch.
  - In WebKit, 43 of 56 renders, including 27 of 28 iPhone-profile ones, were taken after network idle with the switch still disabled. The sampled icon colour is `#828e86`, the same as the no-JS render. Chromium: 0 of 84.
- **The moment:** on a slow phone in dark mode: a light address bar over a dark page, and a faded moon that doesn't respond.
- **Why it fails:** lens N (both themes look designed); AX-8 and WCAG 4.1.2 (the name must match the state).
- **Fix:**
  1. `viewport.themeColor`: two entries with `media` (light `#f7f8f2`, dark `#121c18`; documented in `node_modules/next/dist/docs/01-app/03-api-reference/04-functions/generate-viewport.md:95-119`). `apply()` sets every `theme-color` meta to the chosen colour.
  2. The dark tokens also apply under `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { … } }`, so a dark-mode visitor without JavaScript gets the dark page the toolbar now matches.
  3. The switch is `visibility: hidden` until it works (no layout shift), and absent without JavaScript.
- **Files:** `layout.tsx` (the other session's line 8 only); `ThemeProvider.tsx`, `global.css` (clean).
- **Verify:**
  - two `theme-color` metas with `media` in the built `<head>`;
  - no render, Chromium or WebKit, shows a 55% switch;
  - `home-nojs.*.dark` renders are dark;
  - device check: a dark-mode phone on a throttled network shows a dark toolbar from first paint.
- **Evidence:** verified in the build; seen in the no-JS and WebKit renders (pixel-sampled); the toolbar is a device check.

**WEB-702 · Severity 1 · Taps on frame links give no visible feedback**
*(New.)*
- **Where:**
  - `src/styles/global.css:67-71` turns off the tap highlight for every link, button and summary;
  - no `:active` style exists in any stylesheet (`global.css`, `legal.css`, `voice.css`);
  - the footer's legal links (`legal.css:316-321`), the logo, "Back to top" and the menu button have no hover style either;
  - meanwhile `.button:hover` (`global.css:171-175`) and `.theme-toggle:hover` (`:322-324`) stick on touch after a tap.
- **The moment:** on mobile data, the Leaver taps "Delete account". Nothing changes for 1.5–2 s (lab LCP of the delete page: 1.74–1.96 s), so they tap again: «¿Lo he pulsado?»
- **Why it fails:** PF-8 (Nielsen 1993: answer within about 0.1 s); OL-1 (older users are slower and repeat actions).
- **Fix:** subtract the override at `global.css:67-71`, which restores the browser's tap highlight. Wrap the hover-only effects (lift, colour, mint fill) in `@media (hover: hover)`.
- **Files:** `global.css` (clean).
- **Verify:**
  - Playwright on the mobile project: the tap highlight isn't `transparent`, and hover rules sit under `(hover: hover)`;
  - device check: tap a footer link on a throttled Android phone.
- **Evidence:** verified in the code; the effect needs a device, since renders can't show taps.

**WEB-703 · Severity 1 · Logo, footer links and "Back to top" are under the 44 px bar**
*(New.)*
- **Where** (AUDIT §5, every page):
  - the header logo, 135.7 × 34.5 px;
  - the footer logo, 129.7 × 33;
  - "Back to top ↑", 62 × 33 at 10 px;
  - the footer's "Privacy", 40 × 44;
  - footer legal rows 6 px apart on phones (`legal.css:419-421`);
  - the two header circles, 42 × 42 (WEB-307).
  - The accessible name "Back to top ↑" includes the arrow (AUDIT §14), so it's read as "…up arrow".
- **Why it fails:**
  - CT-6 and CT-7: TaskFlow's bar is 44–48 px with 8 px between neighbours (Hoober 2017c);
  - WCAG 2.5.8 (AA) passes (AUDIT §5: 0 fails), so this is the site's own bar, not a WCAG failure.
- **Fix:**
  - `.brand { min-height: 48px; }` in the header and the footer;
  - "Back to top": `display: inline-flex; min-height: 44px; align-items: center`, with the arrow in an `aria-hidden` span;
  - `.footer-legal a { min-width: 44px; justify-content: center; }`;
  - the footer legal gap 8 px or more on phones.
- **Files:** `global.css`, `Footer.tsx` (the other session's lines elsewhere); `legal.css` (untracked).
- **Verify:** AUDIT §5 lists none of these under 44 × 44, and §14 names the link "Back to top".
- **Evidence:** measured (AUDIT §5, §14).

**WEB-704 · Severity 1 · No Android trademark line where the site names Android**
*(New. The owner's decision of 2026-10-18 makes this a fix, not a question.)*
- **Where:**
  - the home names Android in the FAQ (`page.tsx:8, 24`), the closing card (`:423`) and the screenshot alt text (`src/components/Phone.tsx:4-7`), with no ™ and no trademark line;
  - after WEB-303 and WP3, every page's menu and hero will name it too.
- **Why it fails:** AP-7 (Android Brand) and `.claude/ux-web/DECISIONS.md:58-59`: the line "and ™ on first use, added wherever the site names Android".
- **Fix:**
  - **The footer of every page,** at 12 px or more (WEB-309):
    - EN: "Android is a trademark of Google LLC."
    - ES: «Android es una marca comercial de Google LLC.»
    - CA: «Android és una marca comercial de Google LLC.»
  - **™ on the first "Android" in each page's main content,** such as the hero line, not in the nav (H and F own that copy). Manrope has U+2122.
  - Approval by Google's Android brand team stays the owner's action at launch.
- **Files:** `Footer.tsx` (the other session's lines elsewhere: stays uncommitted).
- **Verify:** a Playwright text check finds the line in the right language on every page whose text contains "Android".
- **Evidence:** verified in the code and in `DECISIONS.md`.

**Withdrawn — WEB-310 · At 200% text, the header and language switcher overflow on phones**
- **Withdrawn because:** measured (AUDIT §3), no page scrolls sideways or clips text:
  - at 320 px (`mobile-w320`);
  - at 200% zoom (`desktop-zoom200`, 720 CSS px);
  - with the default font doubled (`text200`, desktop and mobile).
- The first review computed widths for text that grows. Today nothing grows (WEB-309), so the overflow can't happen.
- The risk returns only once WEB-309 moves sizes to rem, so its check is now part of WEB-309's Verify.
- The legal pill's `flex-wrap` stays in WEB-208 (area L).

### Device checks (for the owner)
- **WEB-701:** iPhone Safari, `/`, `/es/privacy/` and the 404: is the type bold?
- **WEB-302:** WhatsApp previews of `/es/` and of the bare domain, after a deploy.
- **WEB-313:** a dark-mode phone on a throttled network: the toolbar colour, and when the switch appears.
- **WEB-702:** a footer tap on a throttled Android phone.
- **WEB-309:** Android at its largest font size.
- **WEB-304:** TalkBack reading an ES page's title.

### Claims checked
| Claim (page, `path:line`) | Source of truth (`path:line`) | Verdict |
|---|---|---|
| Title, description and preview of the home and the 404: "the calm task planner that brings your calendar, priorities, and voice-to-task capture together" (`src/app/layout.tsx:12-13`; AUDIT §11) | Calendar is the first screen: `.claude/ux-review/DECISIONS.md:223`. Priority: `App/lib/l10n/app_en.arb:214`. The app says "dictation": `app_en.arb:1899`, `app_es.arb:1188`, `app_ca.arb:892`. Pitch: `app_en.arb:674` | True in substance, misnamed ("capture") |
| Header button "Explore the app" (every desktop page, `src/components/Header.tsx:49`) | It opens the website's sample walkthrough (`src/app/page.tsx:287-318`), which WD1 removes; the app can't be downloaded (`.claude/ux-web/DECISIONS.md:68`) | False |
| Phone menu "Get TaskFlow" (`Header.tsx:63`) | Not on Google Play (`.claude/ux-web/DECISIONS.md:68`; WD9 `:45-46`; the site's own `page.tsx:8, 423`) | False |
| "A product by GARBAR, IN-TEC, S.L." (`src/components/Footer.tsx:18`) | `src/content/legal/company.json:2` | True |
| "Contact support" → `mailto:taskflow.support@garbar.tech` (`Footer.tsx:31`) | `company.json:7`; CLAUDE.md, Email (support and account-deletion address) | True |
| The Catalan deletion name «Eliminar compte» (`src/content/legal/index.ts:156`; the title of `/ca/delete-account/`, AUDIT §11) | The app: «Suprimeix el compte» (`App/lib/l10n/app_ca.arb:910`); ES «Eliminar cuenta» matches `app_es.arb:1206`, EN `app_en.arb:2038` | Misnamed in CA (WEB-206, area L; the footer adopts the app's word in WEB-304) |

### Missing from the site (app features worth telling)
- **The app's one-line pitch,** `authPitch`: «Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario.» (`App/lib/l10n/app_es.arb:412`, `app_en.arb:674`, `app_ca.arb:391`). It's what the newcomer reads at the app's sign-in; it belongs in the description and the preview (WEB-302), so the site's first words are the app's.
- **Several tasks in one dictation,** the owner's "must" (`.claude/ux-review/DECISIONS.md:99`). WD4's preview image shows "Tomorrow, call the dentist and buy bread" as two tasks (`calendarTrySaying`, `app_en.arb:312`, `app_es.arb:221`, `app_ca.arb:200`). This sharpens the preview without a new section.

### Keep
- **The footer's legal row on every page:** Privacy, Terms, Legal Notice, Delete account, Contact. Same order everywhere (WCAG 3.2.6), 44 px tall.
- **Measured accessibility basics:**
  - 0 axe violations;
  - 0 text-contrast failures in either theme (muted text 5.47:1 and 8.86:1);
  - focus visible at all 2,148 stops, never hidden behind the sticky header (`scroll-padding-top` works);
  - no sideways scrolling at 320 px or 200% zoom.
- **The `<details>` menu:** works without JavaScript, and Escape closes it and returns focus (`Header.tsx:15-24`).
- **The legal pages' metadata:** translated titles and descriptions, canonical, and reciprocal hreflang with `x-default` (AUDIT §11).
- **The legal switch's naming:** each language named in itself, with `lang` and `hreflang` (`LegalPage.tsx:113-125`). It's the model for WEB-301, once its current-language cue gets more than a 1.12:1 fill (WEB-208).

### Questions for the owner (product decisions only)
None new. WD5 (the bare `/`) and WD13 (the Play Console URL, `/delete-account/`) answered both of the first review's questions, and the new evidence raises no product decision. The device checks above are his, on his own phone.

### Cross-slice notes
- **H:**
  - In WebKit's iPhone profile, the walkthrough's controls (`TaskDemo.tsx`, `disabled={!ready}`) render faded before hydration (`crops/home.en.mobile.light.full.s7-9.png`, from `webkit/`).
  - The live demo's start button does nothing until hydration (WEB-18). Check both on a real iPhone.
- **H:** AUDIT §9 names the hero region "Make room for aclearer day." (Chromium's tree joins the `<br>` and the span without a space). WP3's H1 should avoid a `<br>` inside the heading.
- **H:** the closing card is WEB-303's destination; its "not yet" line is 10 px (AUDIT §6). WEB-308's ring fix must cover whatever control the card keeps.
- **L:**
  - The legal sidebar's 15 focus rings are clipped by up to 6 px on desktop (AUDIT §10), so WEB-205's inferred clipping is now measured.
  - The language pill's state is a 1.12:1 fill (AUDIT §8, WEB-208); WEB-301 reuses that pill, so fix it once.
- **L:** privacy §8 must list the language-preference cookie (WEB-301, WD5) beside `taskflow-theme`.
- **L:** the delete page's request button sits in the bottom third on phones (y ≈ 569–623, `delete-account.es.mobile.light.fold.png`).
- **F:** nothing new in the frame. The free-plan line (WD2) stays in H and F's copy, not the header.

### Memory notes
- **Site map (G):**
  - Frame: `layout.tsx` (html lang, skip link, metadata, `theme-color`, the font preload), `Header.tsx` (nav, CTA, theme switch, `<details>` menu), `Footer.tsx` (tagline, operator, nav, legal row, Back to top).
  - Home anchors in page order: `#features` `page.tsx:145`, `#voice` `VoiceDemo.tsx:363`, `#demo` `:288`, `#appearance` `:321`, `#questions` `:361`, `#get-taskflow` `:400`.
  - `src/app/[language]/` holds only `[document]/page.tsx`, so `/es/` and `/ca/` 404.
  - The 404 is root-only, inherits the home's title and canonical, and supports `export const metadata`.
- **Claims map:**
  - meta and OG: `layout.tsx:11-13`;
  - OG image: `opengraph-image.tsx:3, 57-83`;
  - header CTA `Header.tsx:49`; "Get TaskFlow" `:63`;
  - operator `Footer.tsx:18`; contact `:31`;
  - "Android" mentions: `page.tsx:8, 24, 423`, `Phone.tsx:4-7`;
  - the app's three-language copy for meta: `authPitch` (`app_en.arb:674`, `app_es.arb:412`, `app_ca.arb:391`), `calendarTrySaying` (`:312`, `:221`, `:200`), Appearance/Light/Dark (`app_en.arb:245-247`), `deleteAccount` (`app_en.arb:2038`, `app_es.arb:1206`, `app_ca.arb:910`).
- **Settled patterns** (plan-first):
  - one label per anchor: "Try it with your voice", "What it does", "Questions", "Coming soon to Android";
  - `<html lang>` set before first paint (WP2) rather than a root layout per language, because the legal pages are the other session's;
  - the language switch as plain links, in the header, the menu and the footer.
- **Techniques that worked:**
  - Pixel-diffing the `text200` renders against 100% (PIL `ImageChops`) proves px sizing in one line.
  - Sampling the theme switch's icon colour (`#828e86` = 55% opacity) detects pre-hydration renders: WebKit 43 of 56, Chromium 0.
  - Parsing the TTF's `fvar` and `cmap` with `struct`: wght default 200; no U+2197 or U+0140; has ™, ↑, ←, →, ·.
  - Reading the built `<head>`s in `.next/server/app/*.html`, which can come from a later build without `SITE_URL`: check its time.
  - The version-matched Next.js docs are in `node_modules/next/dist/docs/` (16.4.0).
  - `crop.mjs` takes an absolute WSL path for `webkit/` renders, but writes the same crop name as the Chromium render.
- **Recurring problems:**
  - English frame around translated content;
  - one anchor with many names;
  - px-only type with 8–11 px small print;
  - text glyphs (↗) instead of `Icon`;
  - the 404 inheriting the home's metadata;
  - controls rendered disabled until hydration;
  - Playwright's Windows WebKit drawing variable fonts at their default (thinnest) weight. Don't read weight from WebKit renders without a device check.
- **Tests pinning frame strings:** `tests/website.spec.ts:84` (legal "Back to TaskFlow", "Try a different mood"), `:114-130` ("Open navigation", "Mobile navigation", "Main navigation"), `:143` (the 404's "Back to TaskFlow"); `tests/legal.spec.ts:24` (`article[lang]`).
