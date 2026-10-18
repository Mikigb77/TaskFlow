## UX web review — G (global: navigation, header and footer, languages, performance, accessibility, SEO and meta, light and dark) — 2026-10-18

**Verdict:** Ship after fixes. The shared frame works: contrast passes, the keyboard path works and the footer has every legal link. But the Spanish or Catalan newcomer gets an English home and an English link preview that doesn't say what TaskFlow is. On a phone, the menu's "Get TaskFlow" promises a download that doesn't exist.

**Walked:**
1. **A wrong URL:** 404 → "Back to TaskFlow" → the English home. 1 step, and the language is lost.
2. **The Leaver, coming in as the Play listing will send them:** `/delete-account/` → «Español» → «Volver a TaskFlow». 2 steps, and they end on the English home.
3. **The Newcomer on a phone:** menu → "Get TaskFlow" → the closing card → "Find your flow" → back up to `#demo`. 3 steps that loop.
4. **The Comparer on desktop:** "Explore the app ↗" → the website's sample walkthrough. 1 step, and the label doesn't match the destination.
5. **Keyboard:** skip link → header → page → footer, on `/`, `/es/privacy/` and the 404.
6. **Screen reader:** landmarks, names and `lang`, read from the code and the built HTML.
7. **320 px and text at 200%:** worked out from the CSS.
8. **Light and dark, no JavaScript, slow network:** from the built HTML and the CSS.
9. **Sharing:** the home and legal-page previews, from the built `<head>`s and `opengraph-image.png`.

- **People:** Newcomer (Spanish or Catalan, phone), Comparer (desktop), assistive-technology user, Leaver.
- **Viewports:** 1440 × 1000 and 390 × 664 renders; 360 and 320 px from the code.
- **Languages:** EN on every page. ES and CA exist only for the legal pages, because the home and the 404 have no ES or CA version.
- **Themes:** light and dark.
- **Evidence:**
  - the renders of 2026-10-18 (files stamped 19:24), all newer than the code they show (last code change 2026-10-16);
  - the prerendered HTML of the same build, in `.next/server/app/`;
  - the code.
  - No device, no screen reader and no lab run were used.

**Numbers:**
- **Words in the frame:** the desktop header has 10 words, in English on all 14 pages. The phone header has 0 words: 2 icon-only buttons and the wordmark.
- **Filled buttons in the desktop first viewport:**
  - home 2, both going to `#demo`;
  - 404: 2;
  - delete-account: 2;
  - privacy, terms and legal: 1, and that one is the header's English "Explore the app".
- **One destination, many names:** `#demo` has 5 labels, `#features` 2, `#voice` 2.
- **Languages:**
  - 14 of 18 page × language versions exist; the home and the 404 are English only;
  - 0 of 8 ES or CA pages have a translated frame: each shows the same 28 English strings (12 header, 15 footer, 1 skip link);
  - `<html lang>` is right on 6 of 14 pages;
  - a language switcher appears on 12 of 14 pages, none on the home or the 404.
- **Link previews:** `og:image` on 2 of 14 pages. `og:locale` on 0 of 14. `twitter:title` matches the page on 2 of 14.
- **Steps to account deletion:**
  - from any footer: 1 tap, and it lands on the English page;
  - in Spanish or Catalan through the footer: 2 (English page → «Español»), or 1 through the legal page's own link;
  - from the 404 on a phone: 1 scroll + 1 tap, because the link sits at y ≈ 760 of a 664-px screen.
- **Phone header:** sticky, 73 px tall, which is 11% of a 664-px screen.
- **Type:** 7 styles in the frame are under 12 px, the smallest 8 px. Every size is in px.
- **Contrast:**
  - muted text: 5.48:1 light, 8.86:1 dark;
  - focus ring on the page: 5.76:1 light, 10.47:1 dark;
  - focus ring on the closing card, light theme: **1.58:1**.
- **First-view downloads:** a 164,700-byte TTF font, and 2 hero images preloaded where only 1 is shown.
- **Claims checked:** 5. False 2, misnamed 2, true 1.

**Attention:** predicted from the renders with GUIDELINES §21.4; nothing here was measured.
- **`home.en.desktop.*.fold`** (the frame's share of it):
  1. the H1, top-left;
  2. the hero screenshot, right half, first looked at after about 2–3 s;
  3. two filled green buttons competing for the same `#demo`: the hero's "See it in action" and the header's "Explore the app" in the top-right corner.
  - The wordmark is seen early but names no product type. The header nav (muted, 13 px) is low salience.
  - "For Android" isn't among the first three.
- **`home.en.mobile.*.fold`:**
  1. the H1, in the top half;
  2. "See it in action";
  3. the wordmark and two 42-px icon circles (moon, menu).
  - The frame adds no words to the 5-second test. The screenshot only peeks into the bottom third, a discounted zone.
- **`privacy.es` and `delete-account.ca`, `.desktop.light.fold`:**
  1. the H1;
  2. the header's English "Explore the app". It is the only filled button on the privacy, terms and legal pages; on the delete page it competes with «Escriure sol·licitud d'eliminació»;
  3. the language pill and the «Eliminar cuenta» link.
  - An English nav row sits above the Spanish or Catalan H1.
- **`delete-account.es.mobile.light.fold`:**
  1. the H1;
  2. the language pill, large and bordered, which is good for language;
  3. «Volver a TaskFlow».
  - The filled request button is at y ≈ 570–622, in the bottom third (about 14% of gaze per Lagun 2014).
- **`not-found.en.desktop.*`:**
  1. "Let's find your flow again.";
  2. "Back to TaskFlow";
  3. the header's filled "Explore the app", which competes.
  - "404" is in a 10-px eyebrow and is likely missed.
- **`not-found.en.mobile.*`:**
  1. the H1, an idiom;
  2. the button, whose arrow glyph renders as a box in the render;
  3. the header icons.
  - Nothing large says "page not found". "Delete account" is below the fold.
- **`opengraph-image.png`:**
  1. "Make room for a clearer day.";
  2. the wordmark;
  3. "A LITTLE FOCUS. A LITTLE FLOW."
  - Nothing shows an app, a phone, a task, a calendar or Android.

### Findings (most severe first)

**WEB-301 · Severity 3 · No Spanish or Catalan home, and no way to switch**
- **Where:**
  - `src/app/page.tsx`: the home is English only, and there is no `src/app/[language]/page.tsx`. `/es/` and `/ca/` return the English 404.
  - `src/app/not-found.tsx`: English only.
  - `src/components/Header.tsx:28-69` and `src/components/Footer.tsx:4-46` have no language switcher.
  - The only switcher is inside the legal pages (`src/components/LegalPage.tsx:113-125`). Their back link (`:110-112`) and the logo go to the English `/`.
  - Evidence: INDEX.md, "Languages the site doesn't have"; `home.en.mobile.light.fold.png`; `privacy.es.mobile.light.fold.png`. The build has no `es/index.html` or `ca/index.html`.
- **The moment:**
  - The Newcomer arrives from a WhatsApp link: «Esto está en inglés… ¿qué es?»
  - The Leaver on `/es/delete-account/` taps «Volver a TaskFlow»: «¿Por qué ahora está en inglés?»
- **What happens:**
  - The main entry page exists only in English.
  - Nothing on it, in the header or in the footer offers Español or Català.
  - A language picked on a legal page is lost on the next tap home.
- **Why it fails:**
  - ML-5 (CSA 2020: 76% prefer their own language and 40% never buy in another; self-reported).
  - ML-4 (a switcher in the header or menu of every page).
  - ML-1 (stable URLs per language).
  - NV-7 (the switcher belongs in every footer).
  - The owner decided the site's copy is written in English, Spanish and Catalan (`.claude/ux-web/DECISIONS.md:21`).
  - The reviewer's scale lists "an entry page that isn't in the newcomer's language" as Major.
- **Fix:**
  1. Add `/es/` and `/ca/` homes, written by a fluent speaker from the home copy area H settles, not word for word from today's idioms. The app already has its key lines in all three languages, for example `authPitch` (`App/lib/l10n/app_es.arb:412`, `app_ca.arb:391`).
  2. Put a switcher in the shared frame of every page, keeping the visitor on the same page:
     - on desktop, in the header, in the space WEB-305 frees;
     - on phones, as the first rows of the menu;
     - in the footer.

     Use plain links "Español · Català · English", each with its own `lang` and `hreflang`. No `<select>` and no flags (OL-3). Reuse the legal pages' pattern (`LegalPage.tsx:113-125`). Name it "Language" · «Idioma» · «Idioma».
  3. Every link in the frame keeps the language prefix: the logo, the nav anchors (`/es/#…`), the footer links and «Volver a TaskFlow».
  4. Give the home `alternates.languages` (en, es, ca, x-default), and list `/es/` and `/ca/` in `sitemap.ts:13-20`.
- **Files:**
  - committed and clean: `page.tsx`, `Header.tsx`;
  - holding the other session's uncommitted lines: `Footer.tsx`, `layout.tsx`, `sitemap.ts`;
  - untracked, the other session's: `src/app/[language]/`, `LegalPage.tsx`.
  - Tests that pin today's frame: `tests/website.spec.ts:111-146`, `tests/legal.spec.ts:24`.
- **Verify:**
  - `home.es.*` and `home.ca.*` renders exist, and INDEX.md no longer lists the home under missing languages.
  - `/es/` returns 200 with `<html lang="es">`.
  - Playwright on `/`, `/es/`, `/ca/privacy/` and the 404: links named «Español», «Català» and "English", with `hreflang`, are visible on desktop and inside the open menu on mobile.
  - From `/es/privacy/`, the logo, «Volver a TaskFlow» and every footer link stay under `/es/`.
- **Evidence:** verified in code and in the build; seen in current renders.

**WEB-302 · Severity 3 · The link preview doesn't say what TaskFlow is**
- **Where:**
  - `src/app/layout.tsx:11-13, 24-31`: title, description, Open Graph and X/Twitter;
  - `src/app/opengraph-image.tsx:57-83`;
  - render `opengraph-image.png`; built `<head>` in `.next/server/app/index.html`.
- **The moment:** the Newcomer gets a WhatsApp link showing a big slogan and "A little focus. A little flow. Meet the calm task planner that brings your calendar, priorities, and voice-to-task capture together." «¿Qué es esto? ¿Una app? ¿De qué?»
- **What happens:**
  - The preview image shows only the wordmark, "Make room for a clearer day." and "A LITTLE FOCUS. A LITTLE FLOW.": no phone, no task, no Android.
  - The tab title and search title are the same slogan.
  - The description says "voice-to-task capture". The app's words are "dictation", «dictado» and «dictat».
  - Everything is in English, and there is no `og:locale`.
- **Why it fails:**
  - ML-9: the preview should show the product and the promise, in the page's language.
  - HE-1 and HE-2: the slogan fails the competitor test, since any planner could say it.
  - HE-10: "capture" is jargon.
  - ML-8: each page needs a descriptive title.
  - FN-2 and FN-3: use the app's own words.
  - GUIDELINES §21.3: for the Newcomer, the shared-link preview comes before the page.
- **Fix** (match the H1 area H settles; until then, lead with the app's own sign-in line):
  - **`<title>` and `og:title`:**
    - EN: "TaskFlow — say it, and it's on your calendar"
    - ES: «TaskFlow — dilo y ya está en tu calendario»
    - CA: «TaskFlow — digues-ho i ja és al teu calendari»
  - **Description and `og:description`:**
    - EN: "Note down what you need to do, and TaskFlow puts it on your calendar. You can say several things at once. Android app, coming soon."
    - ES: «Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario. Puedes decir varias cosas a la vez. App para Android, muy pronto.»
    - CA: «Apunta el que has de fer i TaskFlow ho posa al teu calendari. Pots dir diverses coses alhora. App per a Android, molt aviat.»
    - The first sentence is the app's `authPitch` (`App/lib/l10n/app_en.arb:674`, `app_es.arb:412`, `app_ca.arb:391`). The rest of the Catalan needs a native check, and "coming soon" must match the availability line areas H and F settle.
  - **Image:**
    - Replace the slogan card with the title line and a current app screen showing a spoken sentence and the dated tasks it became. Use the app's own example (`calendarTrySaying`, `app_en.arb:312`, `app_es.arb:221`, `app_ca.arb:200`):
      - EN: "Tomorrow, call the dentist and buy bread"
      - ES: «Mañana, llamar al dentista y comprar pan»
      - CA: «Demà, trucar al dentista i comprar pa»
    - Make one image per language: `src/app/[language]/opengraph-image.tsx`, once the ES and CA homes exist.
    - Keep it legible at 300 px wide, drop "A LITTLE FOCUS. A LITTLE FLOW.", and translate the `alt`.
  - **Locale:** `openGraph.locale` en_US, es_ES or ca_ES, with `alternateLocale`.
- **Files:** `opengraph-image.tsx` is committed and clean. `layout.tsx` holds the other session's line 8 only.
- **Verify:**
  - the built `<head>` of each home carries the new title, description and `og:locale`;
  - `opengraph-image.png` shows a phone screen and the promise, and reads at 300 px wide;
  - after the owner deploys, paste the URL into WhatsApp on a phone (device check).
- **Evidence:** verified in the built `<head>` and the current `opengraph-image.png`.

**WEB-303 · Severity 3 · "Get TaskFlow" promises a download that doesn't exist**
- **Where:**
  - `src/components/Header.tsx:62-64`: the phone menu, at 800 px and narrower;
  - it leads to `src/app/page.tsx:399-428` (`#get-taskflow`);
  - seen in `crops/home.en.mobile.light.full.s11-13.png`.
- **The moment:** the Newcomer opens the menu to download it: «Get TaskFlow, ¡ahí!» They land on "Less on your mind. More room for life." with a "Find your flow" button that sends them back up to the demo. «¿Dónde se descarga?»
- **What happens:** the site's only "get it" item leads to a card whose button loops back to `#demo`. The truth ("Android app in development · Public download coming soon") is 10-px text under that button (`global.css:1398-1407`).
- **Why it fails:**
  - CT-4: the destination must keep the label's promise.
  - AP-5: before launch, say "Coming soon to Android" in plain text.
  - Lens C: nothing may imply the app can be installed today.
  - The owner: "Until then, the calls to action must be honest" (`.claude/ux-web/DECISIONS.md:14`).
- **Fix:**
  - Rename the item to "Coming soon to Android" · «Próximamente en Android» · «Properament a Android», or remove it until the Play listing exists.
  - Areas H and F own the card. Its first view should say, in body-size text, that the app can't be downloaded yet, with no button that loops back.
  - When the listing exists, the item becomes the Play link (AP-3); the package ID is still open.
- **Files:** `Header.tsx` (clean).
- **Verify:**
  - at 390 px, the open menu has no "Get" item;
  - the availability item lands on a view whose first line says the app isn't downloadable yet (Playwright text check);
  - walking it, nothing loops back to `#demo`.
- **Evidence:** verified in code; the destination is seen in the current render.

**WEB-304 · Severity 2 · Spanish and Catalan pages keep an English frame**
- **Where:**
  - `src/app/layout.tsx:43`: `<html lang="en">` on every page. `:56-58`: "Skip to content".
  - `src/components/Header.tsx:7-12, 31, 39, 49, 52, 56, 63`; `src/components/ThemeProvider.tsx:82-85`.
  - `src/components/Footer.tsx:9-43`. The legal links at `:27-30` point to `/privacy/` … `/delete-account/` from every language.
  - Built: `.next/server/app/es/privacy.html` and `ca/delete-account.html` have `<html lang="en">`.
  - Renders:
    - `privacy.es.desktop.light.fold.png`: an English nav and "Explore the app" above «Tu privacidad, con claridad.»;
    - `crops/privacy.es.mobile.light.full.s21-22.png`: an English footer.
- **The moment:**
  - The Leaver, reading in Spanish, taps "Delete account" in the footer and gets an English page: «¿Me he equivocado?»
  - A screen-reader user hears the Spanish `<title>` read with an English voice.
- **What happens:**
  - The 28 frame strings stay English on all 8 ES and CA pages.
  - The footer's legal links leave the language: from `/es/privacy/`, "Delete account" opens the English `/delete-account/`.
  - Only the `<article lang>` (`LegalPage.tsx:107`) is right, so the `<title>` and the frame are announced in English.
- **Why it fails:**
  - ML-5: translate everything, including `aria-label`s and the skip link.
  - ML-2 and WCAG 3.1.1, Language of Page (A).
  - PV-7: the deletion link in each language.
  - NV-7.
  - FN-2: the app's Catalan name for deletion is «Suprimeix el compte» (`App/lib/l10n/app_ca.arb:909`).
- **Fix:**
  1. `<html lang>` follows the route (es, ca or en), for example with a root layout per language. The `<article lang>` then becomes unnecessary.
  2. The header, menu, footer, skip link and theme switch take the page's language. The footer's legal links use `legalPath(document, language)`.
  3. Subtract before translating: delete "A little focus. A little flow." (`Footer.tsx:17`) and "Made for a little more headspace." (`Footer.tsx:37-42`). Neither says anything a visitor needs.
  4. The strings, EN · ES · CA (nav labels: see WEB-305):

     | EN | ES | CA |
     |---|---|---|
     | Skip to content | Saltar al contenido | Salta al contingut |
     | TaskFlow home | Inicio de TaskFlow | Inici de TaskFlow |
     | Main navigation | Navegación principal | Navegació principal |
     | Menu | Menú | Menú |
     | Switch to dark mode / light mode | Cambiar a modo oscuro / claro | Canvia al mode fosc / clar |
     | A product by {company} | Un producto de {company} | Un producte de {company} |
     | Privacy | Privacidad | Privacitat |
     | Terms and Conditions | Términos y condiciones | Termes i condicions |
     | Legal Notice | Aviso legal | Avís legal |
     | Delete account | Eliminar cuenta | Suprimeix el compte |
     | Contact support | Contactar con soporte | Contacta amb el suport |
     | Back to top | Volver arriba | Torna a dalt |
     | Legal and privacy | Legal y privacidad | Legal i privacitat |
- **Files:**
  - holding the other session's uncommitted lines: `layout.tsx` (line 8), `Footer.tsx` (lines 2, 18, 26-32, 35);
  - clean: `Header.tsx`, `ThemeProvider.tsx`;
  - `tests/website.spec.ts:114-131` pins "Open navigation", "Main navigation" and "Mobile navigation".
- **Verify:**
  - on `/es/privacy/` and `/ca/delete-account/`, `html[lang]` is es or ca;
  - a Playwright text scan finds no English in the header, the open menu or the footer;
  - the footer's deletion link reads «Eliminar cuenta» or «Suprimeix el compte» and goes to `/es/delete-account/` or `/ca/delete-account/`;
  - axe `html-has-lang` and `valid-lang` pass;
  - TalkBack reads the title in Spanish (device check).
- **Evidence:** verified in the build and in code; seen in current renders.

**WEB-305 · Severity 2 · The header button misnames the demo, and one place has five names**
- **Where:**
  - `src/components/Header.tsx:48-50`: a filled "Explore the app" with a ↗ icon, on every page 581 px and wider;
  - the nav, `Header.tsx:7-12`, and the footer, `Footer.tsx:21-23`;
  - the same `#demo` is also reached from `page.tsx:68` ("See it in action") and `:419` ("Find your flow").
  - Renders:
    - `home.en.desktop.light.fold.png`: two filled buttons, both going to `#demo`;
    - `delete-account.ca.desktop.light.fold.png`: an English filled button above the Catalan request button.
- **The moment:**
  - The Comparer clicks "Explore the app ↗" expecting the app or its store page, and lands on "02 / FROM THOUGHT TO TASK", a sample on the website: "So where's the app?"
  - On the Catalan delete page, the most prominent control at the top is an English button that leads away.
- **What happens:**
  - `#demo` has 5 labels: "Explore the app", "How it works", "Try the demo", "See it in action", "Find your flow".
  - `#features` has 2: "Features", "Meet TaskFlow". `#voice` has 2: "Try voice", "Give it a try".
  - The nav lists "How it works" (`#demo`) before "Try voice" (`#voice`), though the page shows the voice demo first.
  - The labels don't match the section headings: "Questions" lands on "Glad you asked."
- **Why it fails:**
  - CT-1 and CT-2: one primary action per view, never two in one view.
  - CT-3 and CT-4: "the app" and the ↗ icon promise something else.
  - NV-4: anchor text should match the heading it leads to.
  - Lens G: one concept, one name.
- **Fix:**
  1. Remove the header button (`Header.tsx:48-50` and the `.header-cta` CSS) until Google Play has the app. That slot later becomes the store link (AP-1 to AP-3), and in the meantime it frees room for WEB-301's switcher.
  2. Give each destination one label, in page order, in the header, menu and footer:

     | Destination | EN | ES | CA |
     |---|---|---|---|
     | `#features` | What it does | Qué hace | Què fa |
     | `#voice` | Try it with your voice | Pruébalo con tu voz | Prova-ho amb la teva veu |
     | `#demo` | See an example | Mira un ejemplo | Mira un exemple |
     | `#questions` | Questions | Preguntas | Preguntes |

     If area H merges or renames the demos, these labels follow the headings it settles. The hero and closing buttons are H's.
- **Files:** `Header.tsx`, `global.css` (clean); `Footer.tsx` (holds the other session's changes elsewhere).
- **Verify:**
  - the desktop fold renders of the home, legal pages and 404 show no filled button in the header;
  - each anchor has one label across `Header.tsx`, `Footer.tsx` and `page.tsx`;
  - the nav order matches the section order.
- **Evidence:** verified in code; seen in current renders.

**WEB-306 · Severity 2 · The 404 page is an English idiom that hides "not found"**
- **Where:**
  - `src/app/not-found.tsx:4-13`;
  - built `.next/server/app/_not-found.html`, whose title is `<title>TaskFlow — Make room for a clearer day</title>`;
  - renders `not-found.en.mobile.light.fold.png`, `not-found.en.desktop.light.full.png`.
- **The moment:** the Leaver types `/es/eliminar-cuenta` and reads "Let's find your flow again.": «¿Qué flujo? ¿Funciona la web?»
- **What happens:**
  - The H1 is a pun, and "404 / A LITTLE OFF TRACK" is 8–10 px. The only plain sentence is muted.
  - The page is English for every URL, including `/es/…` and `/ca/…`.
  - Browser tabs and screen readers get the home page's title.
  - The button's "↗" isn't in Manrope (its character map has no U+2197). It renders as a box in the Chromium render, and ↗ suggests leaving the site.
  - On phones, "Delete account" is below the fold.
- **Why it fails:**
  - HE-3: clear beats clever.
  - RD-1: lead with the conclusion.
  - ML-5: every page translated.
  - AX-5 and WCAG 2.4.2, Page Titled (A).
  - OL-2: say what happened and what to do.
- **Fix:** remove the eyebrow and the pun. Write one short block per language: English first, because the page is `lang="en"`, and the others marked with their own `lang`:
  - **EN:** H1 "Page not found". "This address doesn't exist on the TaskFlow website." Links: "TaskFlow home page" (`/`) and "Delete account" (`/delete-account/`).
  - **ES:** «Página no encontrada. Esta dirección no existe en la web de TaskFlow.» Links: «Inicio de TaskFlow» (`/es/` once it exists) and «Eliminar cuenta» (`/es/delete-account/`).
  - **CA:** «No hem trobat aquesta pàgina. Aquesta adreça no existeix al web de TaskFlow.» Links: «Inici de TaskFlow» (`/ca/`) and «Suprimeix el compte» (`/ca/delete-account/`).
  - Add `export const metadata = { title: "Page not found · Página no encontrada · Pàgina no trobada — TaskFlow" }`.
  - Replace the "↗" glyph with `<Icon name="arrow">`.
- **Files:** `not-found.tsx` (clean). `tests/website.spec.ts:143` pins "Back to TaskFlow".
- **Verify:**
  - the title in `_not-found.html`;
  - the 404 renders show the three lines, with the deletion links above the fold at 390 × 664;
  - no missing-glyph box;
  - axe `document-title` passes.
- **Evidence:** seen in current renders; verified in the build and in the font's character map.

**WEB-307 · Severity 2 · Phone header: two unlabelled icons, and the theme switch outranks the menu**
- **Where:**
  - `src/components/Header.tsx:47, 51-55`;
  - `src/components/ThemeProvider.tsx:86-105`;
  - `src/styles/global.css:313-321, 1653-1680`;
  - renders `home.en.mobile.light.fold.png`, `delete-account.es.mobile.light.fold.png`.
- **The moment:** the Newcomer: «¿Qué es la luna? ¿Y las dos rayas?» They don't open menus.
- **What happens:**
  - On phones, the header's only controls are a moon or sun circle and a two-line circle, each 42 × 42 px, with no words. The theme switch carries the same weight as the menu.
  - The menu's name stays "Open navigation" while it's open, and a tap outside doesn't close it.
  - The two lines are `<span>` backgrounds (`global.css:1668-1674`). In forced-colours mode those turn into the page colour, so the button looks empty (inferred).
- **Why it fails:**
  - AX-8: the theme, language and menu controls should show words (Harley 2014: few icons are universally understood).
  - NV-1: visible menus get used 86% of the time on phones, against 57% for hidden ones (Pernice 2016a).
  - CT-6: TaskFlow's bar is 44–48 px. WCAG 2.5.8 (AA) passes.
  - Lens N: the theme switch shouldn't compete for attention.
- **Fix,** on phones (800 px and narrower):
  1. The menu button shows a word, "Menu" · «Menú» · «Menú», with an SVG icon from `Icon.tsx`, which keeps its colour in forced-colours mode. Drop `aria-label="Open navigation"` so the visible word is the name.
  2. Move the theme switch into the menu, as a labelled row (strings in WEB-304). Keep it in the desktop header.
  3. Make both targets 48 × 48 px.
  4. Optionally, close the menu on a tap outside it.
- **Files:** `Header.tsx`, `ThemeProvider.tsx`, `global.css` (clean). Update `tests/website.spec.ts:114, 122`.
- **Verify:**
  - the mobile fold renders show «Menú» or "Menu" and a single header control;
  - Playwright at 390 px: the summary's name is «Menú» on `/es/…`, and the theme switch is inside the open menu;
  - a Playwright screenshot with `forcedColors: 'active'` shows the menu icon;
  - both targets measure 48 px or more.
- **Evidence:** seen in current renders and verified in code. The forced-colours behaviour is inferred and needs a browser check.

**WEB-308 · Severity 2 · Keyboard focus vanishes on the closing card in light mode**
- **Where:**
  - `src/styles/global.css:99-102`: the focus style, a 3-px `var(--green)` outline offset by 5 px;
  - it lands on `.closing-card` (`global.css:1358-1367`), whose background is `#214c38` in both themes;
  - the "Find your flow" button (`page.tsx:419-421`), in light mode.
- **The moment:** a keyboard user tabs to the page's last call to action: "Where am I?"
- **What happens:** the ring `#176e59` sits on `#214c38` at 1.58:1. In dark mode it's 5.86:1, and elsewhere in light mode 5.76:1.
- **Why it fails:** AX-4 and AX-2: WCAG 2.4.7, Focus Visible (AA), and 1.4.11, Non-text Contrast (AA, 3:1).
- **Fix:** `.closing-card :focus-visible { outline-color: #d4eca3; }`, which gives 7.57:1 on `#214c38`.
- **Files:** `global.css` (clean).
- **Verify:** Playwright in light mode: Tab to the card's button and check that the computed `outline-color` has at least 3:1 against `#214c38`; take a screenshot.
- **Evidence:** computed from the CSS tokens; needs a keyboard check in a browser.

**WEB-309 · Severity 2 · The frame's small print is 8–11 px and ignores text-size settings**
- **Where:**
  - `src/styles/global.css`:
    - `:59`: body text 15 px;
    - `:121-126` and `:2088-2091`: `.eyebrow` at 10 px (8 px on phones), with 1.75-px letter spacing;
    - `:176-182`: `.button-small` at 11 px;
    - `:1458-1462`: the footer tagline at 10 px;
    - `:1468-1477` and `:2321-2325`: the footer's bottom row at 10 px.
  - `src/styles/legal.css:322-326`: the operator line at 11 px.
  - Every size is in px.
  - Renders: `crops/home.en.mobile.light.full.s11-13.png`; `not-found.en.desktop.light.full.png`; `privacy.es.mobile.light.fold.png`, where the eyebrow's wide letter spacing pulls the letters of «Política de privacidad» apart.
- **The moment:** the 60+ Newcomer: «No leo eso». The line that tells them who runs TaskFlow, "A product by GARBAR, IN-TEC, S.L.", is among the smallest text on the page.
- **What happens:**
  - 7 frame styles are under 12 px.
  - Because every size is in px, a visitor who sets a larger default font in Chrome, Edge or Firefox gets no larger text; only page zoom helps.
  - The eyebrow's capitals spacing is applied to mixed-case legal labels.
- **Why it fails:**
  - RD-5: body text at least 16 CSS px in rem or em; small print at least 12 px.
  - AX-3 and WCAG 1.4.4.
  - Nielsen 2013 and Kane 2019: tiny type is a recurring problem for older users.
  - TR-1: the company line has to be readable.
- **Fix:**
  1. Size the frame in rem, with the root at 100%: body text 1rem, and a floor of 0.75rem (12 px) for the eyebrow, the footer lines, the operator line and small buttons.
  2. Remove the footer's decorative lines (WEB-304) instead of enlarging them.
  3. Add `.eyebrow { text-transform: uppercase; }`, and write eyebrow strings in sentence case.
- **Files:** `global.css` (clean); `legal.css` (untracked, the other session's).
- **Verify:**
  - every footer, eyebrow and header text computes to 12 px or more at 390 and 1440 px;
  - with Chrome's Settings › Appearance › Font size set to "Very large", the footer text grows;
  - the legal eyebrows render in capitals.
- **Evidence:** verified in code; seen in current renders.

**WEB-310 · Severity 2 · At 200% text, the header and language switcher overflow on phones**
- **Where:**
  - `src/styles/global.css:262-269, 1958-1970`: the header holds the brand, a 42-px theme switch and a 42-px menu in a fixed 73-px bar;
  - `src/styles/legal.css:12-23, 386-389`: the language pill is `display: flex` with no wrapping.
  - Worked out from the code; there is no render at 200% text.
- **The moment:** the Newcomer has set large text on the phone. The page slides sideways and «Català» is cut off.
- **What happens:**
  - At 2× text the wordmark can't wrap. The header needs about 347 px: the brand ≈ 227, the gap 25 and the controls 95. That's wider than the content box: 288 px at 320 px and 328 px at 360 px.
  - The language pill needs about 412 px, against 288–372 px on phones.
  - Either way, the page scrolls sideways.
- **Why it fails:**
  - AX-3: WCAG 1.4.4, and no two-direction scrolling (1.4.10 at 320 CSS px).
  - ML-7: leave room for the text to grow.
  - CT-7: labels should survive 200% text.
- **Fix:**
  - `.legal-languages { flex-wrap: wrap; }`.
  - On phones, the theme switch leaves the header (WEB-307), and the header's gaps drop to 12 px. That gives 227 + 12 + 48 = 287 px, which fits.
- **Files:** `global.css` (clean); `legal.css` (untracked, the other session's).
- **Verify:**
  - after WEB-309, Playwright at 320 × 664 with the root font at 200%: `scrollWidth <= clientWidth` on `/`, `/es/privacy/` and the 404;
  - device check: Android at the largest font size, with Chrome › Accessibility › Text scaling at 200%, on a 360-px phone.
- **Evidence:** inferred from code, with widths scaled from the 100% renders; needs a device check.

**WEB-311 · Severity 1 · The first view downloads a 165 KB font file and both screenshots**
- **Where:**
  - `src/styles/global.css:3-9` and `src/app/layout.tsx:45-51`: `/fonts/Manrope.ttf` is a 164,700-byte variable TTF with `font-display: swap`, and the built `<head>` preloads it twice;
  - `src/components/Phone.tsx:22-39`: the light image has `preload` and the dark one `loading="eager"`, which makes React preload it too. `.next/server/app/index.html` preloads both `agenda-light` and `agenda-dark`.
- **The moment:** the Newcomer on mobile data: the headline appears, then jumps to another font.
- **What happens:** every first visit fetches a TTF font with no size-matched fallback, so text moves when it arrives. It also fetches, at high priority, the hero screenshot for the theme that isn't showing.
- **Why it fails:**
  - PF-5: the font shouldn't move the page; Next.js recommends `next/font`.
  - PF-3: the image that's shown should load first. Next.js's image docs advise against eager loading or preloading a light/dark pair (`[Next.js Image]`, not re-checked today).
  - PF-7.
- **Fix:**
  - Load Manrope through `next/font/local` as a WOFF2 Latin subset with its automatic fallback, and delete the manual preload and the `@font-face`.
  - In `Phone.tsx`, drop `preload` and `loading="eager"` from the light/dark pair and use `fetchPriority="high"`. While the hidden image is `display: none` and lazy, it isn't fetched.
- **Files:** `layout.tsx` (the other session's line 8 only); `global.css` and `Phone.tsx` (clean).
- **Verify:**
  - the built `<head>` has one font preload (WOFF2) and no image preload for the hidden theme;
  - a lab Lighthouse run (mobile, slow 4G), labelled as lab: CLS ≤ 0.1 and LCP ≤ 2.5 s. Raise this to Severity 2 if it fails.
- **Evidence:** verified in the build. The impact is inferred: there is no lab or field data.

**WEB-312 · Severity 1 · Legal pages share without an image, and their X tags are in English**
- **Where:**
  - `src/content/legal/index.ts:190-194`: `openGraph` has no `images`, `locale`, `siteName` or `type`, and there is no `twitter` entry;
  - built `privacy.html`, `es/privacy.html` and `ca/delete-account.html`: no `og:image`, and `twitter:title` is "TaskFlow — Make room for a clearer day", with the English home description, on every legal page.
- **The moment:** someone shares `/es/privacy/` on WhatsApp and gets a bare text link. On X or Slack, an English slogan sits over a Spanish page.
- **Why it fails:** ML-9 and ML-5.
- **Fix:** in `legalMetadata`, add:
  - `images`: the language's preview image from WEB-302;
  - `locale`;
  - `siteName: "TaskFlow"` and `type: "website"`;
  - `twitter: { card: "summary_large_image", title, description }`, with the document's own title and description.
- **Files:** `src/content/legal/index.ts` (untracked, the other session's).
- **Verify:** the built `<head>` of all 12 legal pages carries `og:image` and `og:locale`, and a `twitter:title` equal to `og:title`.
- **Evidence:** verified in the build.

**WEB-313 · Severity 1 · Dark first visit: a light toolbar and a greyed-out theme switch**
- **Where:**
  - `src/app/layout.tsx:33-38`: one `theme-color`, `#f7f8f2`;
  - `layout.tsx:39`: the inline theme script sets `data-theme` but not the meta;
  - `src/components/ThemeProvider.tsx:24-30, 93`: `disabled={!ready}`. In the built `index.html`, the theme switch is `disabled` and labelled "Switch to dark mode", even for a dark-mode visitor.
- **The moment:** the Newcomer, with a phone in dark mode on slow data, sees a light address bar over a dark page, and a faded moon button that doesn't work yet.
- **What happens:** until the scripts load (seconds on a slow network; never without JavaScript), the toolbar is light, and the switch sits at 55% opacity with the wrong label.
- **Why it fails:** lens N, both themes look designed; AX-8, the accessible name matches the state.
- **Fix:**
  - Give `viewport.themeColor` two entries, `media: "(prefers-color-scheme: light)"` and `"(prefers-color-scheme: dark)"`, and have `apply()` update both metas when the visitor chooses.
  - Hide the switch until it's ready (`visibility: hidden`), and with a `<noscript>` style.
- **Files:** `layout.tsx` (the other session's line 8 only), `ThemeProvider.tsx` (clean).
- **Verify:**
  - the built `<head>` has two `theme-color` metas with `media`;
  - the server-rendered `.theme-toggle` is never shown disabled;
  - device check: a phone in dark mode on a throttled network shows a dark toolbar from the first paint.
- **Evidence:** verified in the build; the toolbar effect needs a device check.

### Claims checked
| Claim (page, `path:line`) | Source of truth (`path:line`) | Verdict |
|---|---|---|
| The tab title, search description and preview of every page say the site is "the calm task planner that brings your calendar, priorities, and voice-to-task capture together" (`src/app/layout.tsx:12-13`) | Calendar is the first screen: `.claude/ux-review/DECISIONS.md:170`. Priority: `App/lib/l10n/app_en.arb:214`. Dictation: `app_en.arb:1891`. The app's pitch line: `app_en.arb:674` | True in substance, but misnamed: the app says "dictation", «dictado», «dictat» |
| Header button "Explore the app" (every page, `src/components/Header.tsx:49`) | It leads to the site's sample walkthrough (`src/app/page.tsx:287-309`). The app isn't downloadable (`.claude/ux-web/DECISIONS.md:14`) | False |
| Phone menu "Get TaskFlow" (`src/components/Header.tsx:63`) | Not on Google Play (`.claude/ux-web/DECISIONS.md:14`; the site's own `page.tsx:8, 423-424`) | False |
| "A product by GARBAR, IN-TEC, S.L." (`src/components/Footer.tsx:18`) | `src/content/legal/company.json:2` | True |
| The site's Catalan name for deletion, «Eliminar compte» (`src/content/legal/index.ts:156`; the CA footer link per WEB-304) | The app: «Suprimeix el compte» (`App/lib/l10n/app_ca.arb:909`). ES «Eliminar cuenta» matches `app_es.arb:1205`; EN matches `app_en.arb:2034` | Misnamed in CA |

### Missing from the site (app features worth telling)
- **The app's own one-line pitch:** «Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario.» It is the `authPitch` the newcomer reads at the app's sign-in (decision D8), in all three languages (`App/lib/l10n/app_en.arb:674`, `app_es.arb:412`, `app_ca.arb:391`). It belongs in the site's description and link preview (WEB-302), so the site's first words match the app's.
- **Several tasks in one dictation** (owner's "absolutely a must", `.claude/ux-review/DECISIONS.md:46-51`). The preview image can show the app's own example becoming two tasks (`calendarTrySaying`, `app_es.arb:221`). This sharpens the preview without adding a section.

### Keep
- The legal pages' language switcher (`LegalPage.tsx:113-125`): each language named in itself, `lang` and `hreflang` on each link, `aria-current`, at the top of the page. It's the model for WEB-301.
- The footer's legal row on every page (`Footer.tsx:26-32`): Privacy, Terms, Legal Notice, Delete account and Contact support, with targets of 44 px or more, in the same order everywhere (WCAG 3.2.6).
- The colour tokens:
  - muted text 5.48:1 light and 8.86:1 dark; the focus ring 5.76:1 and 10.47:1;
  - the reduced-motion block (`global.css:2407-2415`);
  - `scroll-padding-top` under the sticky header;
  - the existing test already proves there's no sideways scrolling at 320 px with 100% text.
- The `<details>` menu works without JavaScript, and Escape closes it and returns focus to its button (`Header.tsx:15-24`).
- The legal pages' metadata: translated titles and descriptions, and reciprocal `hreflang` including `x-default` (`content/legal/index.ts:172-189`).

### Questions for the owner (product decisions only)
1. **Which language should the bare `/` show?**
   - **The options:** pick Spanish, Catalan or English from the browser's language, or always show English, with `/es/` and `/ca/` beside it.
   - **The evidence:** the bar newcomer is Spanish or Catalan, and links shared on WhatsApp will mostly be the bare domain. ML-1 allows choosing on the bare root only, from the browser's language and never from the IP address, with a visible switch always available (W3C Conneg).
   - **Recommendation:** choose on `/` from the browser's language, fall back to English, and remember a choice the visitor makes.
2. **Which delete-account URL goes into the Play Console** (one URL for all users)?
   - **The options:** `/delete-account/` (English, with the switcher at the top), or `/es/delete-account/`.
   - It can be settled with the package ID, which is still `com.example.agenda` and blocks any Play link anyway.
   - **Recommendation:** `/delete-account/`, keeping the language pill as the first control on that page (PV-7, ML-1).

### Cross-slice notes
- **H:** the home copy is English and full of idioms. The ES and CA homes (WEB-301) should translate the copy H settles, not today's.
- **H:** the hero's "See it in action" (`page.tsx:68`) and the closing "Find your flow" (`page.tsx:419`) are two of `#demo`'s five names; align them with WEB-305.
- **H:** screen readers ignore `aria-label` on plain `<div>`s (`page.tsx:87, 129`). Decorative captions are read aloud ("JUST SAY THE WORD", "YOUR DAY, LOOKING A LITTLE LIGHTER.").
- **H:** home text at 5–9 px:
  - `.appearance-tag` 5 px (`global.css:1910`);
  - `.hero-art-label` 6–7 px;
  - the floating-note labels 6–7 px;
  - the promise bar 7–8 px (`global.css:2074, 2371`);
  - `.demo-preview-badge` 6–7 px.
- **H/F:** the `#get-taskflow` card (`page.tsx:399-428`) is WEB-303's destination. Its button loops back to `#demo`, and its "not downloadable yet" line is 10 px (`global.css:1402-1407`).
- **F:** FAQ answers contradict the app on dev:
  - using it without an account (`page.tsx:12, 20`), against the login wall (`.claude/ux-review/DECISIONS.md:73-76`);
  - "Choose Task or Note when capturing" (`page.tsx:28`), against D3 (`DECISIONS.md:123`);
  - "shared lists", against projects (`DECISIONS.md:172-178`);
  - "Launch pricing has not been announced" (`page.tsx:32`), against the free tier (`DECISIONS.md:77-99`).
- **F:** the hero and appearance screenshots (`public/images/*.png`, 2026-09-21) predate October's app changes; compare them with `App/build/*.png`.
- **L:**
  - the Catalan deletion title «Eliminar compte» (`content/legal/index.ts:156`) differs from the app's «Suprimeix el compte» (`App/lib/l10n/app_ca.arb:909`);
  - the legal pages use the ↗ "leaves the site" icon on internal links (`LegalPage.tsx:139, 189, 222`).
- **L** (no finding): `legalMetadata` sets `robots: undefined` once publication is approved (`content/legal/index.ts:180`), so the legal pages drop the root `noindex`. It's harmless while `robots.txt` disallows everything.
- **H:** "Try real voice-to-task" (`VoiceDemo.tsx:373`) is jargon (HE-10).

### Memory notes
- **Site map:**
  - Home anchors in page order: `#features` (`page.tsx:145`), `#voice` (`VoiceDemo.tsx:363`), `#demo` (`page.tsx:288`), `#appearance`, `#questions` (`page.tsx:361`), `#get-taskflow` (`page.tsx:400`).
  - Legal pages: English at `/<doc>/` and ES/CA at `/<lang>/<doc>/`, with English slugs, from `src/app/[language]/[document]/page.tsx` (`dynamicParams = false`).
  - There is no `[language]/page.tsx` or `[language]/layout.tsx`, so `/es/` and `/ca/` return 404.
  - The 404 is root-only and English.
- **The frame:**
  - `<html lang="en">` is hard-coded (`layout.tsx:43`).
  - `Header` and `Footer` are English-only, with unprefixed links.
  - The header CTA "Explore the app" goes to `#demo`, and the phone menu's "Get TaskFlow" to `#get-taskflow`.
  - The theme switch is in the header (icon only) and in the appearance section (the "mood" variant).
  - The only language switcher is `LegalPage.tsx:113-125`.
- **Claims map:**
  - the meta and OG description: `layout.tsx:12-13`;
  - the OG image slogan: `opengraph-image.tsx:71-82`;
  - the header CTA: `Header.tsx:49`; the menu's "Get TaskFlow": `Header.tsx:63`;
  - the footer operator: `Footer.tsx:18`;
  - the deletion names: `content/legal/index.ts:70, 113, 156`.
  - The app's `authPitch` (`app_en.arb:674`, `app_es.arb:412`, `app_ca.arb:391`) and `calendarTrySaying` (`app_en.arb:312`, `app_es.arb:221`, `app_ca.arb:200`) are ready-made, three-language copy for the site's meta.
- **Techniques that worked:**
  - Read the build's prerendered `<head>`s in `../TaskFlowWeb/.next/server/app/*.html` (same build as the renders; no npm needed) for `lang`, title, OG, Twitter, preloads and `disabled` attributes. They had no `SITE_URL`, so canonical and `hreflang` don't appear, and `og:image` points to localhost.
  - Contrast from the tokens with a Python WCAG formula.
  - Glyph coverage from the TTF's character map: Manrope lacks U+2197 ↗ and U+0140 ŀ; Catalan uses U+00B7, which is covered.
  - Widths at 200% text scaled from the 100% renders.
- **Recurring problems:**
  - English chrome around translated content;
  - one anchor with many labels;
  - px-only type with 8–11 px small print;
  - text glyphs (↗ ↑ ←) used instead of `Icon`.
- **Tests that pin frame strings:** `tests/website.spec.ts:111-146` ("Open navigation", "Main navigation", "Mobile navigation", the 404's "Back to TaskFlow") and `tests/legal.spec.ts:24` (`article[lang]`).
