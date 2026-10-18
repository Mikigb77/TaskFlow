## UX web review — Area H: home, hero, demos and calls to action (`/`) — recheck with renders and the measured audit — 2026-10-19

**Verdict:** Don't ship. From the first screen a newcomer can't tell what TaskFlow is or that it isn't out yet. The page is English-only, with 39% of its characters under 12 px, and every main button leads to a sample form. The live demo ends in a toy list and, when something fails, shows programmer text.

**Recheck summary.** This report replaces `review-H-first.md`. All 19 first-round findings still hold; none is withdrawn. Four are corrected (WEB-5, 8, 9, 11), and 3 are new (WEB-401 to 403). New evidence is folded into the findings it belongs to, marked "Recheck" in each.

| ID | Sev | Now | What changed |
|---|---|---|---|
| WEB-1 | 4 | confirmed | Seen in current renders, both engines; fix follows WD4, WD6 and the Android ™ decision; adds a Catalan overflow risk |
| WEB-2 | 3 | confirmed | Measured (AUDIT §11, §13); bare `/` decided (WD5); adds mixed 12/24-hour formats |
| WEB-3 | 3 | confirmed | Positions measured; menu label aligned to the plan's "Coming soon to Android"; WD2 line joins the closing card |
| WEB-4 | 3 | confirmed | The phone landing on `#voice` now seen in a render; WD1 means every `#demo` link moves |
| WEB-5 | 3 | corrected | Fix follows WD4 (the Calendar, `hero-calendar-<language>-<theme>.png`), plus size, tilt and overlap so it can be read |
| WEB-6 | 3 | confirmed, now a fix | WD1 decided removal; measured: its fields fail 1.4.11, its text is 6–11 px |
| WEB-7 | 3 | confirmed | Adds the tries-used screen, the preview contrast failure; the WD2 line is now a fix |
| WEB-8 | 3 | corrected | Measured: 39% of characters under 12 px; 0 texts grow at 200% text; smallest is 6 px at 390 px (5 px only at 581–800 px) |
| WEB-9 | 2 | corrected | Adds the input switch's invisible state (1.13:1 / 1.03:1), the always-visible "Success!" box, the 23.8 px row; the 320 px overflow claim narrowed |
| WEB-10 | 2 | confirmed | Measured: demo button at y = 3585 on a phone (5.4 screens), 2693 on desktop |
| WEB-11 | 2 | corrected | WD2 puts the free plan elsewhere, so the bar simply goes |
| WEB-12 | 2 | confirmed | Every server message now rendered; adds a code-to-message table, the no-tasks state, a sometimes-false "tomorrow", the badge's place, the privacy line's place |
| WEB-13 | 2 | confirmed | Measured: the same text from 1 s to 54 s; the tries badge drops 3 → 2 with nothing shown; "Try again" names no button |
| WEB-14 | 2 | confirmed | Each browser error rendered; adds a line before the permission prompt; "not allowed" wording |
| WEB-15 | 2 | confirmed | The ticking live region measured; adds a visible "10 seconds left" |
| WEB-16 | 2 | confirmed | Measured: the real microphone's fill 1.20:1 vs the disabled "Create drafts" at 6.16:1; the stop control has no word |
| WEB-17 | 2 | confirmed | Measured: its button's border 1.22:1 / 1.77:1 |
| WEB-18 | 1 | confirmed | Seen in the no-JavaScript render |
| WEB-19 | 1 | confirmed | axe; adds the security box's label (an axe violation) and a glued word in the hero's spoken name |
| WEB-401 | 2 | new | Connection failures show "Failed to fetch" and a JSON parse error |
| WEB-402 | 2 | new | The demo's text box has no visible edge (1.31:1) |
| WEB-403 | 2 | new | The security check disables the button with no reason and no retry |

**Walked:**
- **Evidence and its age:**
  - Chromium renders and the measured audit were made at 23:52–23:56 on 2026-10-18 (21:52–21:56 UTC, per AUDIT.md). The WebKit renders were made at 00:19 on 2026-10-19.
  - Every source they show is older: `page.tsx` 10-09, `VoiceDemo.tsx` 10-15, `global.css` 09-21, `voice.css` 10-09, `public/images/*` 09-21.
  - App renders: `App/build/*.png`, 00:17–00:20 on 2026-10-19.
  - The demo's API was never called: every demo state is the stubbed render.
- **Newcomer (Spanish, 60+, phone).** There's still no `/es/` home (`artifacts/ux-web/INDEX.md`, "Languages the site doesn't have"), so I walked the English page as she'd meet it. 10 steps:
  1. The WhatsApp preview (`opengraph-image.png`).
  2. The hero.
  3. The "at a glance" bar.
  4. The feature cards.
  5. The live demo, in all 67 states.
  6. The sample walkthrough, in its 4 states.
  7. The appearance section.
  8. The FAQ (`home-faq…`).
  9. The closing card.
  10. The phone menu's "Get TaskFlow" (`home-menu…`).

  Renders: 390 × 664, light and dark; `mobile-w320`; `mobile-text200`; `home-nojs`; WebKit iPhone 13, light and dark.
- **Comparer.** Desktop 1440 × 1000, light and dark, and `desktop-zoom200`. 6 steps: header "Explore the app", the walkthrough, the nav's "Try voice", the live demo, the FAQ, the closing card.
- **Assistive-technology user.** 5 steps:
  1. The skip link.
  2. The hero's names and reading order (AUDIT §9; `aria/home.en.*.txt`).
  3. The Tab path: 41 stops on desktop, 37 on the phone, focus visible at every stop (AUDIT §10, §14).
  4. The demo: focus and live regions in every state (AUDIT §13; `aria/voice-*.txt`).
  5. Text at 200% (AUDIT §3).
- **Leaver.** Outside area H. The home's "Delete account" link is in the footer, at y = 7802 on a phone (11.7 screens).

**Numbers** (before → after the fixes):
- **First viewport** (renders):
  - Phone: about 56 words, 1 filled button and 1 text link.
    - Words that say what TaskFlow is: **0**. The only "Android" is the image's alt text, which only screen readers get.
    - After: about the same number of words, but the H1 and subheadline say what it is, for Android, and that it's not out yet. Still 1 filled button.
  - Desktop: about 104 words, **2** filled buttons ("Explore the app", "See it in action"), 1 text link and 4 nav links.
    - The one word that says what it is: "calendar", in the 11 px bar at y ≈ 847.
    - After: 1 filled button.
- **Phone scrolling:**
  - The first call to action is visible at once (y = 367), but it goes to the sample form.
  - The live demo's start button is at y = 3585: **5.4 screens** down (AUDIT §5 positions). Desktop: 2.7 screens. After WEB-10: about 2–3 screens, and one tap from the hero button.
  - The honest "not yet":
    - the 10 px launch note at y ≈ 7446: **11.2 screens**;
    - the closed FAQ item at y = 6514: 9.8 screens;
    - the menu: 2 taps, then the same 10 px line.
    - After WEB-3: 0, as a line under the hero button.
- **Calls to action:**
  - 4 filled labels: "Explore the app", "See it in action", "Try the live demo", "Find your flow".
  - Plus "Give it a try", "Try voice", "How it works", "Try the demo" and "Get TaskFlow".
  - 3 of the 4 filled ones go to the sample form (`#demo`).
  - After WEB-4: 1 label, 1 destination (`#voice`).
- **Live demo:**
  - Taps from the open demo to a result: **3** (microphone, stop, "Create drafts"). Before them, "Try the live demo"; on top, the browser's prompt and a Cloudflare tap when it asks.
  - The app: 2 to a result («Añadir tarea», «Listo») and 1 more to save. After WEB-9: 2.
  - Of the 67 voice states:
    - **6** show the browser's or JavaScript's own text;
    - **20** announce jargon or developer wording in their alert or status (AUDIT §13);
    - every capture state's fine print says "rolling 24 hours", "Shared-network limits" and "AI".
- **Type:**
  - **39%** of the home's visible characters on a phone are under 12 px (38% on desktop). Only 14% (13% on desktop) are 16 px or more.
  - Text elements under 12 px: 68 on the phone, 71 on desktop.
  - The smallest is **6 px**.
  - With the browser's default font size doubled, **0 of 137** texts grow (AUDIT §1, §3, §6).
- **Copy:**
  - "little" appears 23 times in `page.tsx`, `VoiceDemo.tsx` and `TaskDemo.tsx`, and 31 times across the site's visible files.
  - Headings-only test: 0 of the 13 headings (AUDIT §12) mention Android, getting the app or a price.
- **Claims:** 33 checked: 22 true (4 of them in words the app doesn't use, or misleading as the app's), **4 false** (2 of them only sometimes), **7 outdated**.

**Attention** (predicted from the renders with GUIDELINES §21.4; not measured eye-tracking):
- **`home.en.mobile.light.fold.png`:**
  1. The H1 "Make room for a clearer day." (42 px, y ≈ 157–255, top half; the largest, highest-contrast text).
  2. "See it in action": the only filled control, 148 × 49 at y = 367, isolated in the middle band.
  3. The phone screenshot (from y ≈ 483, bottom third: about 14% of gaze, Lagun 2014), or the grey 13 px subheadline.

  The "JUST SAY THE WORD / 'A walk at six.'" card (6 and 10 px, y ≈ 597–658) competes from the bottom third. The 8 px eyebrow and the 10 px footnote are effectively unseen. Missing from the first three: what TaskFlow is, "Android", "not yet", what's free.
- **`home.en.mobile.dark.fold.png`:** the same order; the mint button stands out more. The same gaps.
- **`home.en.desktop.light.fold.png`:**
  1. The H1 (77 px, top-left quadrant).
  2. "See it in action": filled, left half, y = 567.
  3. "Explore the app": the second filled button, top right, going to the same place (CT-1). The phone screenshot competes for this place: it's the largest image, but on the right, which gets its first look after 2–3 s (Buscher 2009).

  The 11 px bar (y ≈ 847) and the 7–12 px cards are likely skipped.
- **`home.en.desktop.dark.fold.png`:** the same, but both buttons are equally bright mint fills, so they compete harder.
- **Variants:**
  - `mobile-text200` and `desktop-text200` are pixel-identical to 100%: someone who enlarges text gets nothing.
  - `mobile-w320`: the same order; the button sits at y ≈ 366 of 568.
  - `desktop-zoom200` (720 × 500): "Explore the app" (top right) and "See it in action" (bottom left) are both filled and both in view.
  - `home-nojs`: identical, except the theme switch is greyed.
  - `webkit/home.*.fold.png`: the same layout, but every weight is drawn thin. The H1 keeps its size and loses its weight, and the 11 px white button label gets thinner. Legibility changes, not the order.
- **`voice-capture.en.mobile.light.view.png`** (the demo once open):
  1. "What's on your mind?"
  2. The 17 px example quote.
  3. The white "Record a thought" pill.

  The control that actually records, a pale microphone (fill 1.20:1), comes 4th, competing with Cloudflare's "Success!" box.
- **Five-second answers** (GUIDELINES §21.5), the same on all home folds:
  - Q1, what is it: "a calm planner? a calendar?" Fails the competitor test.
  - Q2, what does it do for me: "a clearer day". Vague.
  - Q3, who for, and which phone: nothing.
  - Q4, what would I tap: "See it in action", which leads to a sample form.
  - Q5, what did I notice first: the H1.
  - Q6, unknown words: none in the first viewport.

  **Fail.**

### Findings (most severe first)

**WEB-1 · Severity 4 · The hero never says what TaskFlow is**
- **Recheck:** confirmed, now seen in the current fold renders: Chromium and WebKit, both themes, 100% and 200% text, 320 px. It's measured too (AUDIT §6, §9, §12). The fix now follows WD4 (the hero image), WD6 (the brand line goes) and the Android ™ decision. It adds a warning: the accent span's `nowrap` would push a Catalan H1 off a 320 px screen.
- **Where:**
  - `src/app/page.tsx:41-127`: eyebrow :43-45, H1 :46-61, subheadline :62-66, footnote :78-83, hero art :85-126.
  - `/`, English, phone and desktop, light and dark.
  - Renders: `home.en.{mobile,desktop}.{light,dark}.fold.png`, `home.en.mobile-w320.light.fold.png`, `webkit/home.en.*.fold.png`.
- **The moment:** "Make room for a clearer day… Is this a calendar? A wellness thing? Is it an app? For my phone?"
- **What happens:**
  - The phone's first viewport says: "A LITTLE FOCUS. A LITTLE FLOW. / Make room for a clearer day. / Big plans. Small reminders. All the things in between. Bring them together in one calm space, and get back to living. / See it in action · Meet TaskFlow / Less organizing. More getting on with your day. / JUST SAY THE WORD “A walk at six.”"
  - None of those words is app, phone, Android, task, calendar or voice. "Android" appears only in the screenshot's alt text, so only screen-reader users get it (`aria/home.en.mobile.txt`).
  - The only hint that you speak to it is the card in the bottom third: "JUST SAY THE WORD" at 6 px and "A walk at six." at 10 px.
  - Measured on the phone (AUDIT §6): eyebrow 8 px, subheadline 13 px in grey, footnote 10 px.
  - None of the page's 13 headings (AUDIT §12) says it's an app for Android or how to get it.
- **Why it fails:**
  - HE-1: on the competitor test, "Make room for a clearer day" fits any planner, a cleaning service or a meditation app.
  - HE-2 and HE-3: clear beats clever; promotional wording cost 27% in usability (Morkes 1997).
  - HE-6.
  - AT-1 and AT-2: about 70% of phone gaze falls on the top half (Lagun 2014).
  - AT-7 (Liu 2010; Nielsen 2011d).
  - SC-1: the headings-only test.
  - FN-2: the app's own pitch already says it plainly (`authPitch`, `App/lib/l10n/app_en.arb:674`).
- **Fix:** replace, don't add.
  1. **Remove** the eyebrow (:43-45), the footnote (:78-83), the stage caption (:94), the "Make a little time for you" card (:111-122) and the art label (:123-125).
  2. **H1:**
     - EN "Say it, and it’s on your calendar."
     - ES «Dilo y ya está en tu calendario.»
     - CA «Digues-ho i ja és al teu calendari.»

     If an accent span stays, put its leading space inside it. Drop `white-space: nowrap` (`global.css:359`) at 360 px and below: «al teu calendari.» at 42 px is about 350 px wide, and the column at 320 px is 288 px.
  3. **Subheadline.** The first "Android" on the page carries ™ (the trademark decision); the trademark line itself goes in area G's footer.
     - EN "Tap one button and say what you need to do, even several things at once. TaskFlow puts each one on its day and can remind you before it. An app for Android™ phones."
     - ES «Toca un botón y di lo que tienes que hacer, aunque sean varias cosas a la vez. TaskFlow pone cada una en su día y puede avisarte antes. Una app para móviles Android™.»
     - CA «Toca un botó i digues el que has de fer, encara que siguin diverses coses alhora. TaskFlow posa cada una el seu dia i et pot avisar abans. Una aplicació per a mòbils Android™.»
  4. **The voice card** (:96-109) shows the app's own teaching example (`calendarTrySaying`: `app_en.arb:312`, `app_es.arb:221`, `app_ca.arb:200`). It's placed above or beside the phone, never over its screen (WEB-5):
     - EN “Tomorrow, call the dentist and buy bread.”
     - ES «Mañana, llamar al dentista y comprar pan.»
     - CA «Demà, trucar al dentista i comprar pa.»
  5. **The footnote's slot** takes the availability line (WEB-3). The button is WEB-4's.
  6. **The `<title>`, description and link preview** follow the H1 (area G, WEB-302).
- **Verify:**
  - Re-render the folds in en, es and ca. On 390 × 664, the H1, subheadline, the filled button and the status line are all visible. At `mobile-w320` in Catalan, nothing scrolls sideways (AUDIT §3).
  - Answer the five-second questions from the H1 and subheadline alone: Q1–Q3 must be right.
  - Playwright: the `h1` contains "calendar" / «calendario» / «calendari»; `.hero` contains "Android"; no `.hero` text matches /a little|un poco|una mica/i.
  - The hero region's name in Chromium's tree (AUDIT §9) has every space. Today it's "Make room for aclearer day.".
- **Evidence:** seen in current renders; measured (AUDIT §6, §9, §12); verified in code.

**WEB-2 · Severity 3 · Home, hero and demos exist only in English**
- **Recheck:** confirmed and now measured. INDEX lists no Spanish or Catalan home. AUDIT §11 gives the home `lang="en"` and no hreflang. All 67 demo states show English (AUDIT §13, "Announced"). WD5 decided the bare `/`. Added: the demo mixes 12- and 24-hour times in one card.
- **Where:**
  - Every string in `src/app/page.tsx`, `src/components/VoiceDemo.tsx` and `TaskDemo.tsx`.
  - Alt text: `src/components/Phone.tsx:2-8`.
  - The server messages shown on the page: `src/lib/voice/policy.ts:73, :80, :87, :152-204`; `security.ts`, `store.ts`, `challenge.ts` (INDEX lists each).
  - Dates: `VoiceDemo.tsx:15-24, :820-827`.
  - `src/app/layout.tsx:43`: `lang="en"`. This file holds the other session's edits.
  - Renders: every `voice-*.en.*` state.
- **The moment:** the Spanish newcomer, 60+, from WhatsApp: «Está todo en inglés. Esto no es para mí.»
- **What happens:**
  - The journey "first visit on a phone in Spanish" fails at step 1: `/` exists only in English (AUDIT §11).
  - The legal pages have `/es/` and `/ca/`, but every way home leads to English.
  - In the live demo, task titles come back in the visitor's language, but every label, hint and error is English (AUDIT §13).
  - Dates and times follow the browser, not the page, and mix formats in one card: "Fri, Oct 23 · 17:00" (24-hour, from the API) above "Your allowance returns Mon 7:54 PM" (12-hour, `toLocaleString(undefined…)`). See `voice-last-try.en.mobile.light.panel.png`.
- **Why it fails:**
  - ML-5: 76% prefer their own language and 40% never buy in another (CSA 2020).
  - ML-6.
  - Lens G: every string in all three languages.
  - The brief: the site's copy in EN, ES and CA (`.claude/ux-web/DECISIONS.md:75`).
  - TR-3: untranslated strings are trust bugs.
- **Fix:**
  - Build `/es/` and `/ca/` homes from one copy table, as the legal pages do with `src/content/legal/{en,es,ca}.ts`. The copy is in WEB-1, 3–7, 9, 12–14 and 401–403.
  - The bare `/`, per WD5: the browser's language on `/` only, never the IP, falling back to English. A choice made in the switch is remembered and wins. Routing and the switch are area G's.
  - Format every demo date and time with `Intl.DateTimeFormat(<page language>)`, the same way for a task and for the tries line, so they never disagree.
  - Map the API's error `code`s to translated messages on the page: the table in WEB-12, and WEB-401 for anything unknown. No server change is needed.
- **Verify:**
  - `home.es.*` and `home.ca.*` renders exist, with `lang` es and ca and hreflang en, es, ca and x-default (AUDIT §11).
  - A stop-list scan of `main` on `/es/` and `/ca/` finds none of "the", "your", "and", "demo", "tries".
  - Every voice state rendered in es and ca shows no English.
  - A native speaker reads the Catalan.
- **Evidence:** measured (AUDIT §11, §13); seen in current renders; verified in code.

**WEB-3 · Severity 3 · Nothing near a button says the app isn't out**
- **Recheck:** confirmed, with measured positions. The menu label now follows the plan's settled "Coming soon to Android" (review G's wording, which replaces my "Download: coming soon"). WD2's free-plan line joins the closing card.
- **Where:**
  - Hero: `src/app/page.tsx:67-83`.
  - Closing card: :399-428. The note at :422-425 is 10 px (AUDIT §6; `global.css:2302-2306`).
  - FAQ: :7-8, closed.
  - Menu: `src/components/Header.tsx:62-64`.
  - Renders: `home.en.mobile.light.full.png` (screen 12), `home-menu.en.mobile.light.fold.png`, `home-faq.en.mobile.light.view.png`.
- **The moment:** "It looks nice. Where do I get it? Is it on the Play Store?"
- **What happens:**
  - The only plain statement that TaskFlow can't be installed yet is the 10 px "Android app in development · Public download coming soon", under the last button. On a phone it's at y ≈ 7446 of 7981, 11.2 screens down; on desktop, y ≈ 5800 of 6235.
  - The other is the FAQ's first item, closed, at y = 6514: 9.8 screens down.
  - The menu's last item, "Get TaskFlow", jumps to that card. Its button, "Find your flow", goes to the sample form.
  - By the end of the second phone screen, nothing has said it's for Android, that it isn't out, or what's free.
- **Why it fails:**
  - AT-1 and AT-6.
  - AP-5: before launch, plain text and no badge.
  - AP-7: "for Android" near the primary action.
  - CT-4: the menu item's promise isn't kept.
  - CT-10: the cost next to the button.
  - TR-2: disclose up front.
  - Lens C: calls to action are honest about what happens next.
- **Fix:** one sentence, the same words everywhere, and no Google artwork.
  1. **Under the hero button**, in the footnote's place:
     - EN "Coming soon to Google Play. You can’t download it yet."
     - ES «Muy pronto en Google Play. Todavía no se puede descargar.»
     - CA «Molt aviat a Google Play. Encara no es pot descarregar.»
  2. **The closing card** (:404-427) makes this its message.
     - H2:
       - EN "Coming soon to Android."
       - ES «Muy pronto en Android.»
       - CA «Molt aviat a Android.»
     - Paragraph:
       - EN "TaskFlow isn’t on Google Play yet. Until then, you can try it with your voice on this page."
       - ES «TaskFlow todavía no está en Google Play. Mientras tanto, puedes probarlo con tu voz en esta página.»
       - CA «TaskFlow encara no és a Google Play. Mentrestant, el pots provar amb la teva veu en aquesta pàgina.»
     - The button is WEB-4's.
     - Under it, WD2's line. It's the same line as after the demo (WEB-7):
       - EN "Free: 10 dictations a month and tasks by hand with no limit. TaskFlow Pro, a monthly subscription: unlimited dictation and file space."
       - ES «Gratis: 10 dictados al mes y tareas a mano sin límite. TaskFlow Pro, una suscripción mensual: dictados y espacio para archivos sin límite.»
       - CA «Gratuït: 10 dictats al mes i tasques a mà sense límit. TaskFlow Pro, una subscripció mensual: dictats i espai per a fitxers sense límit.»
     - Delete the eyebrow (:408), the old H2 (:409-413), the "next chapter" line (:414-418) and the 10 px note (:422-425).
  3. **The menu item "Get TaskFlow"** becomes, with the same target:
     - EN "Coming soon to Android"
     - ES «Muy pronto en Android»
     - CA «Molt aviat a Android»

     `Header.tsx` is area G's file.
  4. **The demo's hand-over** says it too (WEB-7).
- **Verify:**
  - The status line is fully visible on the 390 × 664 fold render.
  - On the full phone render, it appears above y = 1328.
  - No `play.google.com` link exists.
  - The closing card's text is 14 px or more (AUDIT §6).
- **Evidence:** seen in current renders; measured (AUDIT §5 positions, §6); verified in code.

**WEB-4 · Severity 3 · Every call to action loops back to a sample form**
- **Recheck:** confirmed. Where "Try voice" lands on a phone is now seen in a render; in the first review I computed it. WD1 removes `#demo`, so every link to it has to move.
- **Where:**
  - Header: `src/components/Header.tsx:48-50`, "Explore the app" with the ↗ icon (`Icon.tsx:4`). The nav's "How it works" is `Header.tsx:9`.
  - Hero: `page.tsx:68-76`.
  - Features link: :235-237.
  - Closing: :419-421.
  - The footer's "Try the demo": `Footer.tsx:22`, the other session's file.
  - `src/styles/voice.css:3`.
  - Renders: `home.en.desktop.{light,dark}.fold.png`, `home.en.desktop-zoom200.light.fold.png`, `voice-intro.en.mobile.light.view.png`.
- **The moment:** "Explore the app ↗… oh, it's a form on the website. Is this the app?" And at the end: "Find your flow… it took me back up."
- **What happens:**
  - There are 4 filled labels: "Explore the app", "See it in action", "Try the live demo", "Find your flow". On top come "Give it a try", "Try voice", "How it works", "Try the demo" and "Get TaskFlow".
  - Three of the filled ones ("Explore the app", "See it in action", "Find your flow") go to `#demo`, the sample form (`aria/home.en.desktop.txt`; AUDIT §14). They skip the live demo above it.
  - The ↗ icon reads as "opens the app or a store".
  - Two filled buttons share the desktop fold, and the 200% zoom view too.
  - On a phone, the closing button sends the visitor from y = 7361 back up to about y = 3800.
  - "Try voice" lands with the section top 170 px down: 90 px of root `scroll-padding-top` plus the section's 80 px `scroll-margin-top`. On a phone, the "Try the live demo" button is below the fold: the render shows the heading, the badge and the orb, but not the button (`voice-intro.en.mobile.light.view.png`).
- **Why it fails:**
  - CT-1.
  - CT-3: the labels don't name what happens.
  - CT-4: the destination doesn't keep the promise.
  - CT-11, NV-4 and AP-13.
- **Fix:** one primary action, one label, one destination.
  1. **The hero button, the closing button and the features link** all become the same label, going to `#voice`:
     - EN "Try it with your voice"
     - ES «Pruébalo con tu voz»
     - CA «Prova-ho amb la teva veu»
  2. **The hero's secondary link** becomes the plan's settled nav name, still going to `#features`. It replaces "Meet TaskFlow":
     - EN "What it does"
     - ES «Qué hace»
     - CA «Què fa»
  3. **Remove the header button** (Header.tsx:48-50; area G). The desktop fold drops to one filled button.
  4. **Delete `scroll-margin-top: 80px`** (voice.css:3), and put the demo's first control at the top of its card (WEB-16).
  5. **With `#demo` gone (WD1), repoint** the nav's "How it works" (Header.tsx:9) and the footer's "Try the demo" (Footer.tsx:22, the other session's file) to `#voice`, with the header's label. Area G owns both.
- **Verify:**
  - Playwright: every link with the primary label ends in `#voice`, and no link ends in `#demo`.
  - The desktop and zoom-200 folds have one filled `.button`.
  - After the hero click on the phone project, the demo's first button is `toBeInViewport()`.
  - Update `tests/website.spec.ts:19-20`.
- **Evidence:** seen in current renders; measured (AUDIT §5, §14); verified in code.

**WEB-5 · Severity 3 · Hero and appearance screenshots show the old app**
- **Recheck:** corrected. The problem stands; I compared the site's images with today's `App/build` renders. The fix now follows WD4: the Calendar with the example done, not the result sheet I first proposed. Added: at its current size and tilt, the image can't be read on a phone.
- **Where:**
  - `public/images/agenda-{light,dark}.png` and `tasks-{light,dark}.png`, all from 2026-09-21.
  - `src/components/Phone.tsx:2-8, 22-38`; `src/app/page.tsx:110, :327`.
  - `global.css:457-520, 2032-2040`: the frame is 210 px wide on phones, rotated 7°.
  - Compare with `App/build/calendar-es-1.3x-light.png` (2026-10-19 00:18).
- **The moment** (after installing): "The website showed a microphone and a New task button. Where are they?"
- **What happens:**
  - The hero phone shows an old version of the app:
    - a separate microphone beside "+ New task";
    - three tabs: Calendar, Tasks, Settings;
    - a moon switch in the app bar;
    - "A LITTLE FOCUS. A LITTLE FLOW." and "Your calendar".
  - Today's app is different:
    - one «Añadir tarea» button with a microphone;
    - four tabs: Calendario, Tareas, Notas, Ajustes;
    - no switch in the app bar, since D5 moved it to Ajustes (`.claude/ux-review/DECISIONS.md:184`);
    - a week strip with «octubre Semana ▾», and «Agenda de hoy».
  - The screenshots are in English, while the newcomer will see Spanish. The tasks shown have nothing to do with the hero card.
  - This image is the page's LCP element (AUDIT §2), so the outdated app is literally the first thing that paints.
  - On a phone, the 210 px frame tilted 7° shows the app's text at about a quarter of its size, and the floating cards cover the screen's left and bottom edges.
  - The unused `calendar-*.png` ship too.
- **Why it fails:**
  - HE-5 and FN-3: the real, current app, in the page's language; what the site shows first is what the app shows first.
  - HE-4.
  - EY-3: text inside screenshots is legible at its displayed size.
  - AP-12.
  - TR-3: outdated screenshots are trust bugs.
- **Fix (WD4):**
  - **The images:** `public/images/hero-calendar-<language>-<theme>.png`, 780 × 1688, for en, es and ca in light and dark. Each shows the Calendar with "Call the dentist" and "Buy bread" on tomorrow, and the one «Añadir tarea» button. The main session supplies them.
    - `Phone.tsx` takes the page's language.
    - Its `width`/`height` become 780 × 1688; today they're 1080 × 2400.
  - **The display:** on phones, at least 272 px wide, upright (drop `rotate(7deg)`), with no card over the screen. At that size the task titles read at about 12 px.
  - **Alt text:**
    - EN "TaskFlow on an Android phone: tomorrow’s calendar with two tasks, Call the dentist and Buy bread, and the Add a task button."
    - ES «TaskFlow en un móvil Android: el calendario de mañana con dos tareas, Llamar al dentista y Comprar pan, y el botón Añadir tarea.»
    - CA «TaskFlow en un mòbil Android: el calendari de demà amb dues tasques, Trucar al dentista i Comprar pa, i el botó Afegeix una tasca.»
  - **Delete `calendar-*.png`.** The `tasks-*` pair goes with WEB-17.
  - Both theme images download today (AUDIT §2: 2 images). That's area G's WEB-311.
- **Verify:**
  - Side by side with the app's renders.
  - Playwright: the `.hero-phone img` alt contains "dentist" / «dentista», and its `src` contains the page's language.
  - On the 390 render, the task titles inside the image read at about 12 px, and nothing overlaps the phone's screen.
  - Lab LCP stays at 2.5 s or less (AUDIT §2).
- **Evidence:** seen in current renders (the site's and `App/build`); measured (AUDIT §2); verified in code.

**WEB-6 · Severity 3 · The sample walkthrough teaches a form, not the app**
- **Recheck:** confirmed, and now a fix: WD1 removes it. New measured evidence:
  - its five fields fail WCAG 1.4.11, at 1.31:1 in light and 1.52:1 in dark (AUDIT §8);
  - its text runs 6–11 px (AUDIT §13).
- **Where:**
  - All of `src/components/TaskDemo.tsx`; `src/app/page.tsx:287-318`; `global.css:892-1191` and its responsive blocks.
  - The visitor-facing strings that name "the sample walkthrough": `VoiceDemo.tsx:828`, `src/lib/voice/policy.ts:87`, `security.ts:18, :101`.
  - Renders: `sample-{start,no-title,added,done}.en.*`; `home.en.mobile.light.full.png`, screens 7–8.
- **The moment:** under "No perfect wording. No field-by-field thinking.": "So I fill in a title, date, time, priority and a note? That's what I do now." Then they tap the big green microphone, and nothing happens.
- **What happens:**
  - It's a five-field form: Task title, Date, Time, Priority and A note for later.
  - "Add to my preview" leads to a pretend saved task you can tick ("There. A little lighter."): a copy of the app's editor and list.
  - The examples are dated 21–25 September 2026, a month ago, and the copy says "a sample week in September 2026". On the phone render they show as "09/25/2026" and "05:00 PM".
  - A solid green 50 px microphone, a waveform and "0:08" look like a recorder and do nothing.
  - Its error, "Give your task a title before adding it.", is green 12 px text, the colour the page uses for success.
  - The app's real result shows the title, the date as its main line, the notes and «Más opciones», then takes one «Añadir al calendario» tap (`App/build/review-direct-light.png`).
- **Why it fails:**
  - AP-13, and the owner's rule: a demo is a taste, never a replacement (`.claude/ux-web/DECISIONS.md:65`).
  - FN-3 and FN-4.
  - HE-11.
  - TR-3: stale dates.
  - The speed bar (`.claude/ux-review/DECISIONS.md:120-125`).
  - AX-2: WCAG 1.4.11.
- **Fix (WD1):**
  1. **Remove** the section, `TaskDemo.tsx` and its CSS.
  2. **Put a static example in the live demo's intro**, laid out like the app's result, with no inputs. It renders on the server, so it shows without JavaScript and whenever the live demo can't run.
     - Label:
       - EN "For example, say:"
       - ES «Por ejemplo, di:»
       - CA «Per exemple, digues:»
     - The spoken line:
       - EN “Tomorrow, call the dentist and buy bread.”
       - ES «Mañana, llamar al dentista y comprar pan.»
       - CA «Demà, trucar al dentista i comprar pa.»
     - The app's heading (`captureThingsToAdd`):
       - EN "2 things to add"
       - ES «2 cosas para añadir»
       - CA «2 coses per afegir»
     - Two cards, each a title and then a date line:
       - EN "Call the dentist · Tomorrow", "Buy bread · Tomorrow"
       - ES «Llamar al dentista · Mañana», «Comprar pan · Mañana»
       - CA «Trucar al dentista · Demà», «Comprar pa · Demà»
  3. **Repoint** the visitor-facing strings that name the walkthrough to the example: `VoiceDemo.tsx:828`, `policy.ts:87`, `security.ts:18, :101`. Change only the strings; the copy is in WEB-12.
  4. **Move** the useful sentence of the `<noscript>` (page.tsx:310-316) next to the example (WEB-18).
  5. **Update the tests and the loop's renders:**
     - `tests/website.spec.ts:19-34, :92-110, :194-197`;
     - `tests/voice.spec.ts:205-238`;
     - the `sample-*` states in `tests/support/ux-voice.ts:825` onward.
- **Verify:**
  - No `#demo` in the DOM.
  - With `javaScriptEnabled: false`, the example renders (the `home-nojs` renders).
  - axe passes on both projects.
  - The example's text is 14 px or more.
- **Evidence:** seen in current renders; measured (AUDIT §8, §13); verified in code.

**WEB-7 · Severity 3 · The live demo ends in a toy list, not the app**
- **Recheck:** confirmed in the result, preview and tries renders. Added:
  - the tries-used screen invites a recording it then blocks;
  - the checked-off task fails contrast.

  WD2's free-plan line is now a fix, not a condition.
- **Where:**
  - `src/components/VoiceDemo.tsx:606-830`: results :606-817; the preview list :636-661; the edit forms :696-768; "Add to preview list" :772-776; the actions :779-807; tries used :818-830.
  - The capture stage while tries are used: :469-605.
  - Renders (`.en.mobile.light`, panels and views): `voice-result`, `voice-result-open`, `voice-result-six`, `voice-preview`, `voice-last-try`, `voice-tries-used`, `voice-error-visitor-limit`.
- **The moment:** after 3 tries, at peak interest: "Great, it worked! So how do I get this? It says my 'allowance returns' Monday."
- **What happens:**
  - After a result, the visitor can edit each draft in a five-field form, "Add to preview list" and tick tasks off ("Try checking one off. That’s one less thing on your mind."): a small task manager.
  - On a phone the result card is 1,184 px tall, 1.8 screens; with six tasks, 1,834 px. It ends with "Edit original thought", "Try a new thought", "Your transcript" and "AI can make mistakes…". Nothing says this is what the app does, that it's coming to Android, or what the app gives.
  - In light mode the checked-off title is at 3.61:1 (#78857c on #f7f8f2): an axe failure (AUDIT §13, `voice-preview`).
  - **Tries used** (`voice-tries-used.en.mobile.light.view.png`): the first screen shows "0 of 3 tries left", "What's on your mind?" and "Tap to record · up to 60 seconds". Under them is a microphone that barely looks disabled, then a disabled "Create drafts". The only explanation is the panel's last line, below the fold: "Your allowance returns Mon 4:54 AM. The sample walkthrough below is always available."
  - After `visitor_limit`, the panel gives two answers to one question: "Your allowance returns tomorrow." at the top and "…returns Mon 4:54 AM" at the bottom.
- **Why it fails:**
  - AP-13: after a result, the next step or the honest "not yet" is in view.
  - Lens D: each stage hands over to the next.
  - The owner's rule: teach, don't replicate.
  - Lens B: end on "I want this on my phone".
  - FN-5.
  - OL-2: an instruction the page then refuses.
  - AX-2: WCAG 1.4.3.
- **Fix:** end at the result, then hand over.
  1. **Remove** the preview list and ticking (the saved branch at :611-627, :636-661 and :780-786), the per-task edit forms (:696-768) and "Add to preview list" (:772-776).
  2. **Show each task as the app does:** the title, then the date and time as one line, then the notes, under the app's heading (WEB-9).
  3. **Below the tasks, one block:**
     - EN "In the app: tap Add a task, say it, tap Done, and add it to your calendar. Coming soon to Google Play."
     - ES «En la app: toca Añadir tarea, dilo, toca Listo y añádelo al calendario. Muy pronto en Google Play.»
     - CA «A l’aplicació: toca Afegeix una tasca, digues-ho, toca Fet i afegeix-ho al calendari. Molt aviat a Google Play.»

     Then WD2's line, the same words as in the closing card (WEB-3). Then "Say it again" and the collapsed "See what I said" (WEB-9).
  4. **Tries used:** at the top of the panel, followed by the block from step 3. No "What's on your mind?", no "Tap to record", and no disabled microphone or "Create drafts":
     - EN "You’ve used this demo’s 3 tries. You can try again on {weekday} at {time}."
     - ES «Ya has usado los 3 intentos de esta demo. Podrás volver a probar el {día} a las {hora}.»
     - CA «Ja has fet servir els 3 intents d’aquesta demo. Hi podràs tornar a provar {dia} a les {hora}.»

     The time is the status's `resetAt`, in the page's language (WEB-2). The server's "tomorrow" isn't shown (WEB-12).
- **Verify:**
  - With the stubbed API, after a result, `#voice` contains "Google Play" and WD2's line, and no "Add to preview list" button.
  - In the tries-used state, the message is the first text after the badge and is inside the 664 px view. That state has no "Tap to record" and no disabled `button`.
  - Update `tests/voice.spec.ts:122-160`, and the `voice-preview` state in `tests/support/ux-voice.ts:705-722`.
- **Evidence:** seen in current renders; measured (AUDIT §13); verified in code.

**WEB-8 · Severity 3 · Text in hero, demos and closing card is tiny**
- **Recheck:** confirmed and now measured. Corrected: the smallest size on the 390 px render is 6 px; the 5 px appearance tag applies only between 581 and 800 px. My count of CSS declarations is replaced by measured elements.
- **Where:** `src/styles/global.css` and `src/styles/voice.css`. Renders: `home.en.mobile.light.fold.png`, and `home.en.mobile-text200.light.*`, which is identical to 100%.
- **The moment:** the newcomer, who reads larger text, squints at the grey 13 px subheadline and can't read the 8 px bar or the 10 px "coming soon" line. She turns up her browser's text size, and nothing changes.
- **What happens:**
  - **39%** of the home's visible characters on a phone are under 12 px (38% on desktop); only 14% are 16 px or more (AUDIT §6).
  - Text elements under 12 px: 68 on the phone, 71 on desktop (AUDIT §1).
  - Doubling the browser's default font size grows **0 of 137** texts on the phone and 0 of 144 on desktop: every size is in px (AUDIT §3).
  - Measured on the phone (AUDIT §6, §13):

    | Element | Size | Line |
    |---|---|---|
    | Hero eyebrow | 8 px | `global.css:1983` |
    | Subheadline | 13 px | :1997 |
    | Primary button label | 11 px | :2014 |
    | "Meet TaskFlow" | 10 px | :2009 |
    | Footnote | 10 px | :2020 |
    | Floating cards ("JUST SAY THE WORD" / "A walk at six.") | 6 / 10 px | :2047-2062 |
    | Art label | 6 px | :2066 |
    | Bar | 8 px; 7 px at ≤ 360 px | :2074, :2371 |
    | Closing eyebrow | 6 px | :2289 |
    | Closing paragraph | 11 px | :2297 |
    | Closing button | 11 px | :1395 |
    | Launch note | 10 px | :2303 |
    | Walkthrough text | 6–11 px | :2151, :2188 |
    | Demo labels ("READY TO REVIEW", "Task 1", priority) and the character counter | 11 px | `voice.css:116, :274, :357` |
    | Demo error box | 13 px | `voice.css:321` |
    | Appearance tag | 6 px; 5 px at 581–800 px | :2263, :1910 |

  - In Playwright's WebKit every weight draws thin (`webkit/` renders), so these sizes get thinner still. That's a Safari check (cross-slice note G).
- **Why it fails:**
  - RD-5: body ≥ 16 CSS px in rem or em; small print ≥ 12 px.
  - CT-7: the primary label holds at 200% in Spanish and Catalan.
  - OL-1: tiny type is older adults' recurring problem (Nielsen 2013; Kane 2019).
  - AX-3: browser zoom reflows (AUDIT §3, zoom200), but the browser's text-size setting does nothing.
  - Lens J.
- **Fix:**
  - In these sections: body and subheadline 18 px on phones (16 px at the least), button labels 16 px or more, small print 14 px or more, nothing under 12 px. Use `rem`.
  - Most of the smallest text disappears with WEB-1, 3, 6, 7, 11 and 17. Size what remains: the demo's labels, counter, fine print and error box.
  - Text contrast already passes (see Keep).
- **Verify:**
  - On new renders, AUDIT §6 shows no text under 12 px in `.hero`, `#voice` or `.closing-card`, `p` at 16 px or more, and the hero subheadline at 18 px or more at 390 px.
  - At text200, AUDIT §3 shows text growing, and the `mobile-text200` render differs from 100%.
  - A real phone at arm's length.
- **Evidence:** measured (AUDIT §1, §3, §6, §13); seen in renders; verified in code.

**WEB-9 · Severity 2 · Live demo: twice the app's taps, different words**
- **Recheck:** confirmed, with these additions:
  - the input switch's state can't be seen (measured);
  - the security box is always visible (render);
  - after recording, the send button is pushed to the screen's edge (render);
  - the "Your transcript" row is 23.8 px tall (measured).

  Corrected: at 320 px the security box overlaps the card's edges but stays inside the screen. That's computed: the capture state isn't rendered at 320 px.
- **Where:** `src/components/VoiceDemo.tsx`:
  - Turnstile, rendered without an `appearance` option: :36-102.
  - Intro: :380-398.
  - Capture: :469-605.
  - Mode switch: :483-507 (`voice.css:186-214`).
  - Listen back: :541-556.
  - "Create drafts": :585-596.
  - Labels: :15-24, :609-627, :673-678, :808-811.
  - Renders: `voice-{capture,recording,recorded,typing,result}.en.mobile.light.*` and `voice-capture.en.mobile.dark.panel.png`.
- **The moment:** "Record, stop, listen, a box says 'Success!', Create drafts… is the app slower than this?"
- **What happens:**
  - From the open demo to a result takes 3 taps: the microphone, stop, then "Create drafts". "Try the live demo" comes before them, and on top come the browser's microphone prompt and a Cloudflare tap when it asks.
  - The app takes 2 taps to a result («Añadir tarea», «Listo») and 1 more to save, since the confirming tap stays (UX-615, `.claude/ux-review/DECISIONS.md:46`).
  - Cloudflare's box is always on screen, saying "Success!" before the visitor has done anything. Every capture render shows it; the stand-in has the real widget's 300 × 65 size.
  - **After recording** (`voice-recorded…view.png`): "Ready when you are. Listen back…", a player, "Record again" and the security box push "Create drafts" to the bottom edge of the phone screen.
  - **The input switch** marks the chosen mode with a white pill on light grey. Pressed against not pressed is 1.13:1 in light and 1.03:1 in dark (AUDIT §13, toggles). The only other cue is darker text: weak for WCAG 1.4.11, and nearly invisible in dark.
  - **Small rows:** "Your transcript" and "Edit task N" are 23.8 px tall (AUDIT §13, targets).
  - **Stopping:** the app stops with a large worded «Listo» button (`App/build/capture-listening-es-2x.png`). The site stops with an icon-only square.
  - **The words differ at every step:**

    | Site today | App: EN · ES · CA (ARB key) |
    |---|---|
    | Create drafts / stop | Done · Listo · Fet (`done`, en:850) |
    | Making a little clarity… | Understanding… · Entendiendo… · Entenent… (`captureUnderstanding`, en:1562) |
    | Recording · 12s / 60s | Listening · 0:12 · Escuchando · 0:12 · S’està escoltant · 0:12 (`listeningSeconds`, en:460) |
    | 2 drafts, ready for you. | 2 things to add · 2 cosas para añadir · 2 coses per afegir (`captureThingsToAdd`, en:1566) |
    | Whenever you’re ready | No date · Sin fecha · Sense data (`noDate`, en:198) |
    | Check this: … | Check this detail · Revisa este dato · Revisa aquesta dada (`reviewResolve`, en:23) |
    | Your transcript | See what I said · Ver lo que dije · Mostra què he dit (`reviewOriginal`, en:7) |
    | Try a new thought / Edit original thought | Say it again · Volver a decirlo · Torna-ho a dir (`captureSayAgain`, en:1584) |
    | Type it instead | Type instead · Escribir · Escriu (`captureTypeInstead`, en:1450) |
    | Getting your demo ready… | One moment… · Un momento… · Un moment… (`captureStarting`, en:1430) |

  - Each card also carries "Task N" and a priority chip, which the app's result doesn't show.
- **Why it fails:**
  - FN-2: the app's names, so visitors recognise them after installing.
  - FN-3.
  - The owner's speed bar (`.claude/ux-review/DECISIONS.md:120-125`).
  - CT-11 and AP-13.
  - AX-2: WCAG 1.4.11.
  - CT-6.
- **Fix:**
  1. Use the app's strings in the table.
  2. **One tap starts listening.** «Done / Listo / Fet», a worded, filled button, stops and sends.
     - Remove the listen-back stage: :473-480 and :541-556.
     - "Say it again" on the result records again.
     - The 3-try cap holds either way.
  3. **Replace the two-button switch** (:483-507) with the microphone by default and a "Type instead" text link, like the app's keyboard option. No `aria-pressed` toggles remain.
  4. **Show Turnstile only when Cloudflare needs a tap,** through its `appearance` option ("interaction-only"); on narrow cards, use its compact size. Confirm both in Cloudflare's docs, which this review can't fetch.
  5. **Drop "Task N" and the priority chip** (:672-679).
  6. **Make the "See what I said" row** 44 px tall or more.
  7. **The intro's privacy line** names the new button: "only when you tap Done". It's next to the other session's line at :396.
- **Verify:**
  - With the stubbed API, a result appears after exactly 2 clicks once the demo is open.
  - Every label matches the table.
  - No visible `.voice-verification` box with Turnstile's always-pass test key.
  - No `[aria-pressed]` inside `#voice`.
  - In the result states, AUDIT §13 lists no target under 44 px.
- **Evidence:** seen in current renders; measured (AUDIT §13); verified in code against `App/build/capture-listening-es-2x.png`, `review-batch-light.png`, `review-direct-light.png` and the ARB files. Turnstile's real look needs a check on the deployed site.

**WEB-10 · Severity 2 · The proof sits 4½ phone screens below the hero**
- **Recheck:** confirmed, now measured.
- **Where:** `src/app/page.tsx:286`: `<VoiceDemo />` comes after `#features` (:144-284). Render: `home.en.mobile.light.full.png`.
- **The moment:** a scroller (most visitors) passes a mock calendar and a microphone drawing before seeing anything real.
- **What happens:**
  - On a phone, the live demo's heading starts at y ≈ 3084 (4.6 screens) and its "Try the live demo" button is at y = 3585 (5.4 screens). On desktop the button is at y = 2693, 2.7 screens (AUDIT §5).
  - Between the hero and the demo sit the bar and four feature cards. Their pictures are drawings ("A good week ahead", "September 2026", circles around a microphone), not the app.
- **Why it fails:**
  - AT-4: no screenful of decoration between the hero and the first proof.
  - AT-6.
  - HE-11: the core loop first.
  - EY-3.
- **Fix:** move `<VoiceDemo />` (:286) to directly after the hero; the bar goes with WEB-11. Nothing is added; area F's features follow it.
- **Verify:** on the new full phone render, `#voice` starts above y = 1,328. In the DOM, `#voice` comes before `#features`.
- **Evidence:** measured (AUDIT §5); seen in current renders; verified in code.

**WEB-11 · Severity 2 · The “at a glance” bar says nothing concrete**
- **Recheck:** confirmed and measured. Corrected fix: WD2 puts the free plan in the FAQ, the closing card and after the demo, so the bar simply goes, with no strip in its place.
- **Where:** `src/app/page.tsx:129-142`; `global.css:607-627, 1601-1604, 1773-1781, 2068-2080, 2370-2372`. Renders: the desktop fold at y ≈ 847; phone screen 2.
- **The moment:** "A calmer kind of productive… what does it actually do?"
- **What happens:**
  - Four slogans: "A clearer calendar", "Your words, into action", "Every detail, together", "A calmer kind of productive".
  - Sizes: 11 px on desktop, 8 px on phones, 7 px at 360 px and below (AUDIT §6).
  - An `aria-label` sits on a plain `div` (axe needs review, AUDIT §4).
- **Why it fails:**
  - AT-6 and RD-1.
  - HE-3.
  - SC-6: facts as digits.
  - EY-5: strip-shaped elements get skipped.
  - RD-5.
- **Fix:** remove the bar.
- **Verify:** there's no `.promise-bar`.
- **Evidence:** measured (AUDIT §4, §6); seen in renders.

**WEB-12 · Severity 2 · Demo copy uses jargon a newcomer can't parse**
- **Recheck:** confirmed, with every message now rendered (AUDIT §13, "Announced"). Added:
  - the server messages a visitor can actually meet, with their copy;
  - the no-tasks state;
  - a "tomorrow" that's sometimes false;
  - where the badge and the privacy line sit.

  Per WD8, the badge now says the tries are the demo's.
- **Where:**
  - `src/components/VoiceDemo.tsx:313, 370-377, 385-388, 393-397, 439, 512-515, 566, 600-602, 609-634, 812-815, 820-828`.
  - Server strings shown on the page: `src/lib/voice/policy.ts:73, :80, :87, :152-204`, `model.ts:77`, `security.ts`, `store.ts`, `challenge.ts` (INDEX lists each).
  - Renders: every `voice-*` state; `voice-intro.en.desktop.light.view.png`; `voice-no-tasks.en.mobile.light.panel.png`.
- **The moment:** "Three submissions in a rolling 24 hours… shared-network limits… allowance… mono, 16 kHz PCM… what?"
- **What happens:**
  - **Main-path jargon:** "voice-to-task", "drafts", "transcript", "Checking your allowance…", "Three submissions in a rolling 24 hours. … Shared-network limits also apply.", "do not sync to the app", "without another AI call", "Your allowance returns".
  - **Headings are slogans:** "Say it. See it take shape.", "A minute is plenty.", "Making a little clarity…".
  - **The badge** "3 free tries · no account" reads as the app's offer. On desktop it sits in the far right column, away from the button (EY-2).
  - **Server messages shown as they are** (AUDIT §13):
    - "The AI could not make a reliable draft. Try a shorter, clearer sentence."
    - "This network has reached its demo allowance."
    - "Please use the website recorder (mono, 16 kHz PCM)."
    - "The recording contains an unsupported chunk."
    - "This request has expired. Start a new draft."
    - "Your timezone could not be read."

    20 of the 67 states announce jargon or developer text.
  - **A sometimes-false "tomorrow":** "Your allowance returns tomorrow." (`policy.ts:73`) and "Please try again tomorrow." (:80) can be wrong. The window is rolling (`policy.ts:55`): with a first try yesterday at 22:00, the tries return today at 22:00.
  - **No tasks found** (`voice-no-tasks`): a success tick next to "NO TASKS YET", then "A little structure for your thoughts. Check the details or edit anything." over nothing. Nothing says the try was used, though the badge now says 2 of 3.
  - **The privacy line** is in the intro only. Once the demo opens, nothing next to the microphone says where the recording goes (PV-3).
- **Why it fails:**
  - HE-10: no AI, sync, allowance or transcription on the main path.
  - RD-3.
  - OL-2.
  - PR-3: qualify every "free".
  - HE-3.
  - PV-3.
  - EY-2.
  - FN-1: the "tomorrow" claim.
- **Fix** (WEB-9's renames aren't repeated):

  | Where | EN | ES | CA |
  |---|---|---|---|
  | H2 :371, matching the button (CT-4) | Try it with your voice | Pruébalo con tu voz | Prova-ho amb la teva veu |
  | :373-374 | Say a few things you need to do, and when. You’ll see the tasks TaskFlow would add. | Di algunas cosas que tengas que hacer y cuándo. Verás las tareas que TaskFlow añadiría. | Digues algunes coses que hagis de fer i quan. Veuràs les tasques que TaskFlow afegiria. |
  | Badge :377, under that paragraph at every width (WD8) | This demo: 3 tries a day, no sign-up | Esta demo: 3 intentos al día, sin registrarte | Aquesta demo: 3 intents al dia, sense registrar-te |
  | Intro :386-388; delete "A minute is plenty." (:385) | Speak in English, Spanish or Catalan, for up to a minute. | Habla en español, catalán o inglés, hasta un minuto. | Parla en català, castellà o anglès, fins a un minut. |
  | Fine print :600-602 and :812-815 | It can get dates wrong, so check them. Nothing here is saved to the app. | Puede equivocarse con las fechas: revísalas. Nada de esto se guarda en la app. | Es pot equivocar amb les dates: revisa-les. Res d’això es desa a l’aplicació. |
  | No tasks :612-634, with no tick (`captureNoTasks`, en:1412) | No tasks were found. Your words are kept. That used a try. | No se encontraron tareas. Tus palabras se conservan. Ha contado como un intento. | No s’ha trobat cap tasca. Les teves paraules es conserven. Ha comptat com un intent. |
  | Timeout :313 | This is taking too long. Try again in a moment; it won’t use another try. | Está tardando demasiado. Vuelve a probar en un momento; no gastará otro intento. | Està trigant massa. Torna-ho a provar d’aquí a un moment; no gastarà cap altre intent. |

  - The example (:512-515) and the typing placeholder (:566) both become the app's example (WEB-1, step 4).
  - Remove "Checking your allowance…" (:439); the "One moment…" heading covers it.
  - The privacy line (:393-397) moves to sit under the talk button. It keeps the 60 s limit, Google and the link, and names Done (WEB-9). Its retention wording, in privacy §8's words, is area L's.
  - Map the API's codes on the page. No server change is needed. Each code below fails before the try is recorded unless the row says otherwise (`src/app/api/voice/draft/route.ts:52-87`):

    | Code | EN | ES | CA |
    |---|---|---|---|
    | `network_limit` | Many people on this network have tried the demo. Try again later, or from another connection. | Mucha gente en esta red ha probado la demo. Vuelve a probar más tarde o desde otra conexión. | Molta gent d’aquesta xarxa ha provat la demo. Torna-ho a provar més tard o des d’una altra connexió. |
    | `budget_pause`, `paused`, `not_ready`, `budget_config`, `unavailable` | The live demo is off for now. The example above shows what TaskFlow does. | La demo en directo está parada por ahora. El ejemplo de arriba muestra lo que hace TaskFlow. | La demo en directe està aturada de moment. L’exemple de dalt mostra què fa TaskFlow. |
    | `invalid_draft` (counted, after admission) | We couldn’t turn that into tasks, and it used a try. Say what you need to do, and when. | No hemos podido convertirlo en tareas y ha contado como un intento. Di qué tienes que hacer y cuándo. | No ho hem pogut convertir en tasques i ha comptat com un intent. Digues què has de fer i quan. |
    | `invalid_audio`, `audio_length`, `too_large`, `payload` | We couldn’t hear that recording. Record it again; it didn’t use a try. | No hemos podido oír la grabación. Grábala otra vez; no ha contado como intento. | No hem pogut sentir l’enregistrament. Torna’l a gravar; no ha comptat com un intent. |
    | `processing` | Still understanding. Try again in a moment; it won’t use another try. | Sigo entendiendo. Vuelve a probar en un momento; no gastará otro intento. | Encara ho estic entenent. Torna-ho a provar d’aquí a un moment; no gastarà cap altre intent. |
    | `expired`, `previous_failure`, `request_id`, `session_required` | Something went wrong. Say it again. | Algo ha fallado. Vuelve a decirlo. | Alguna cosa ha fallat. Torna-ho a dir. |
    | `empty` (`captureEmptyInput`) | Say or type what you need to do first. | Primero di o escribe lo que necesitas hacer. | Primer digues o escriu què has de fer. |
    | `visitor_limit` | WEB-7's tries-used message | | |
    | `verification` | WEB-403 | | |
    | anything else | WEB-401's fallback | | |

- **Verify:**
  - A stop-list scan of `#voice` in every state finds none of "allowance", "rolling", "submission", "sync", "AI call", "voice-to-task", "draft", "request", "PCM", "chunk", "timezone".
  - Each stubbed code shows its row.
  - A native speaker reads the Catalan.
- **Evidence:** measured (AUDIT §13); seen in renders; verified in code. The order of the route's checks, and so which codes use a try, was read in `route.ts` only to confirm what the visitor is told.

**WEB-13 · Severity 2 · Waiting for a result: no update, no way out**
- **Recheck:** confirmed and measured:
  - the status text is identical at 1, 10, 30 and 54 s (AUDIT §13);
  - "Close demo" is greyed;
  - the tries badge says "3 of 3" through the wait, then "2 of 3" when the timeout shows;
  - the timeout's "Try again" names no button: the one that resends, "Create drafts", is below the fold on a phone.
- **Where:**
  - `src/components/VoiceDemo.tsx:447-468` (waiting).
  - :409-419: "Close demo" is disabled while `busy`.
  - :285: the page's 55 s timeout.
  - :309-315.
  - Renders: `voice-waiting-{01s,10s,30s,54s}` and `voice-timeout` (`.en.mobile.light.view.png`).
- **The moment:** 15 seconds of the same spinner: "Has it frozen? I can't even close it." Then: "2 of 3 tries left? I got nothing."
- **What happens:**
  - "Making a little clarity… Finding the tasks, dates, and details in your words." never changes.
  - The only way out is to scroll away.
  - The error comes at 55 s, although the model's own timeout is 35 s (`src/lib/voice/model.ts:48`).
  - The visitor then sees a spent try and a message that points to a button it doesn't name.
- **Why it fails:**
  - PF-8: past about 10 s, explain and offer a way forward that keeps what was said (Nielsen 1993).
  - OL-1 and OL-2.
  - CT-4.
- **Fix:**
  - At 10 s, replace the line and show a text button:

    | | Line | Button |
    |---|---|---|
    | EN | Still understanding. This can take up to half a minute. | Stop waiting |
    | ES | Sigo entendiendo. Puede tardar hasta medio minuto. | Dejar de esperar |
    | CA | Encara ho estic entenent. Pot trigar fins a mig minut. | Deixa d’esperar |

  - "Stop waiting" aborts the request, keeps the recording or the text, and returns to capture with a filled "Try again" button (`tryAgain`: Try again · Reintentar · Torna-ho a provar). It resends through `retryPending`, so no new try is used (`store.ts:94`).
  - The timeout's message (WEB-12) sits above the same "Try again" button.
  - "Close demo" stays available while waiting; it aborts too.
  - Bring the page's timeout down to about 40 s.
  - Long waits are likely caused on the server.
- **Verify:**
  - With a mock delayed by 15 s, the new line and "Stop waiting" appear at 10 s.
  - Clicking it shows "Try again" and keeps the typed text; a retry doesn't change the badge.
  - `voice-waiting-10s` differs from `voice-waiting-01s`.
- **Evidence:** measured (AUDIT §13); seen in renders; verified in code. Real wait times weren't measured.

**WEB-14 · Severity 2 · Microphone errors are raw English or dead ends**
- **Recheck:** confirmed, with each browser error now rendered. These are Chromium's names and wording; Safari and Firefox word them differently. Added: tell the visitor before the browser asks; the denial message says "not allowed".
- **Where:** `src/components/VoiceDemo.tsx:235-238, 253-258`; `src/lib/voice/recorder.ts:1-5, 92-96`. Renders: `voice-mic-{waiting,denied,missing,busy,unsupported}`.
- **The moment:** they tap "Block" on the browser's prompt by reflex, then read "Microphone access was not allowed…": "How do I undo that?" Or, on a device without a microphone: "Requested device not found."
- **What happens:**
  - **Denied:** "Microphone access was not allowed. You can still use “Type it instead”." It says what happened, not how to turn the microphone back on, and "not allowed" sounds like a reprimand.
  - **No microphone:** "Requested device not found". **Busy:** "Could not start audio source". Both are the browser's own English (AUDIT §13).
  - **No recording support:** "This browser cannot record audio. Try the text option instead." Nothing on the page is called "the text option".
  - In every case the panel stays in voice mode: the microphone is still offered and the text box stays closed.
  - Nothing before the tap says the browser is about to ask. "Getting your microphone ready…" shows only while the prompt is open (`voice-mic-waiting`).
- **Why it fails:**
  - AX-10: Chrome allowed the prompt 12% of the time without a gesture and 30% after one (web.dev Permissions), so how it's asked matters.
  - OL-2: older users blame themselves 90% of the time (Nielsen 2013), and the guide forbids "not allowed".
  - PV-3.
- **Fix:**
  - **Under the button, before the first tap,** replacing "Tap to record · up to 60 seconds":
    - EN "Tap to talk, up to a minute. Your browser will ask to use the microphone."
    - ES «Toca para hablar, hasta un minuto. El navegador te pedirá usar el micrófono.»
    - CA «Toca per parlar, fins a un minut. El navegador et demanarà fer servir el micròfon.»
  - **Map each error by name,** and switch the panel to typing in the same step, with the text box open and focused:

    | Error | EN | ES | CA |
    |---|---|---|---|
    | `NotAllowedError` (mirrors the app's `captureMicrophoneBlocked`) | The microphone is off for this page. Turn it on in your browser’s settings for this site, or type instead. | El micrófono está desactivado para esta página. Actívalo en los ajustes del navegador para este sitio o escribe. | El micròfon està desactivat per a aquesta pàgina. Activa’l a la configuració del navegador per a aquest lloc o escriu. |
    | `NotFoundError` | We can’t find a microphone on this device. You can type instead. | No encontramos ningún micrófono en este dispositivo. Puedes escribir. | No trobem cap micròfon en aquest dispositiu. Pots escriure. |
    | Anything else | The microphone isn’t responding. Close other apps that may be using it and try again, or type instead. | El micrófono no responde. Cierra otras apps que puedan estar usándolo y vuelve a probar, o escribe. | El micròfon no respon. Tanca altres aplicacions que el puguin estar fent servir i torna-ho a provar, o escriu. |
    | No `getUserMedia` | This browser can’t record your voice. You can type instead. | Este navegador no puede grabar tu voz. Puedes escribir. | Aquest navegador no pot gravar la teva veu. Pots escriure. |

- **Verify:**
  - Stub `getUserMedia` to reject with each name: the mapped text shows with `role="alert"`, and the text box is visible and focused.
  - Device check: deny the prompt in Chrome on Android and in Safari on an iPhone.
- **Evidence:** seen in current renders; measured (AUDIT §13); verified in code. The other browsers' wording needs a device check.

**WEB-15 · Severity 2 · The recording timer is announced every second**
- **Recheck:** confirmed and measured. The polite live region holds "Recording · 5s / 60s", and then "Recording · 50s / 60s" (AUDIT §13). Added: nothing on screen warns that the time is nearly up.
- **Where:** `src/components/VoiceDemo.tsx:532-540`, the `aria-live="polite"` status line, updated every 200 ms and changing every second (:248-252). Renders: `voice-recording` and `voice-recording-50s`.
- **The moment:** a TalkBack user starts speaking, and the phone talks over them: "Recording 1 s / 60 s… 2 s / 60 s…"
- **What happens:**
  - The live region changes every second, so a screen reader keeps talking through the recording. The microphone may pick that speech up too.
  - At 50 s, the screen changes only the number ("Recording · 50s / 60s", grey).
- **Why it fails:**
  - AX-9: announce the start and stop, not each tick.
  - AX-10: show recording clearly, with the time limit.
  - OL-4 / COGA: few interruptions.
- **Fix:**
  - Keep the timer visible but drop its `aria-live`.
  - Add one visually hidden `role="status"` that speaks only three times. The first two use the app's own words:

    | When | EN | ES | CA |
    |---|---|---|---|
    | Start | Listening | Escuchando | S’està escoltant |
    | At 50 s | 10 seconds left | Quedan 10 segundos | Queden 10 segons |
    | Sent | Understanding… | Entendiendo… | Entenent… |

  - At 50 s, the visible line also says "10 seconds left".
- **Verify:**
  - Playwright: the timer has no `aria-live`, and the status text changes only at start, at 50 s and when sent.
  - The `voice-recording-50s` render shows "10 seconds left".
  - Device check with TalkBack: silence while recording, and no screen-reader speech in the transcript.
- **Evidence:** measured (AUDIT §13); verified in code. The microphone picking up the screen reader is inferred and needs a TalkBack check.

**WEB-16 · Severity 2 · Four microphones look tappable; three do nothing**
- **Recheck:** confirmed and measured. The real record button's fill is 1.20:1 against the card and its border 1.31:1, while the disabled "Create drafts" below it keeps a 6.16:1 fill (AUDIT §13, controls, `voice-capture`). The stop control shows no word.
- **Where:**
  - Hero card: `src/app/page.tsx:96-99`, 36 px.
  - Features card: :239-244, 75 px. Area F's WP4 removes it.
  - The live demo intro's orb: `src/components/VoiceDemo.tsx:382-384`, a 78 px `span`.
  - The walkthrough: `src/components/TaskDemo.tsx:138-151`, 50 px, solid green.
  - The real button: `VoiceDemo.tsx:516-529` (`voice.css:229-245`).
  - Renders: `voice-intro`, `voice-capture`, `voice-recording`, `sample-start`.
- **The moment:** "Just say the word." They tap the big microphone above "Try the live demo". Nothing. "Did I break it?"
- **What happens:**
  - Of the five microphones on the page, only one works.
  - It appears only after "Try the live demo", and it's the palest of them. It's predicted to draw the eye fourth in its own card (see Attention).
  - It's named "Start recording" for screen readers but "Tap to record" in the text below.
  - While recording, it's a dark square on peach with no word; "Stop recording" exists only for screen readers. The app's equivalent is the worded «Listo» button.
  - The walkthrough's fake microphone is solid green, like a primary button.
- **Why it fails:**
  - CT-5: weak signifiers take 22% longer to find (Moran 2017f).
  - AX-8 and WCAG 2.5.3: words on controls, with the visible label in the accessible name.
  - CT-1.
  - OL-2.
- **Fix:**
  - Make the record button a solid green (`--green`) circle, 72 px or more, with the paper-coloured microphone. Its label sits inside it or directly attached:
    - EN "Tap to talk", ES «Toca para hablar», CA «Toca per parlar».
    - While listening it becomes the filled, worded "Done" / «Listo» / «Fet» button (WEB-9).
  - The intro's orb goes; the intro shows the static example and its start button (WEB-6).
  - The walkthrough's microphone goes with WEB-6.
  - The hero card's small icon can stay as an icon inside a text card, `aria-hidden`.
- **Verify:**
  - Every microphone icon 48 px or larger is inside a `button`, and its accessible name contains its visible text (AUDIT §9, "Name ≠ label" stays 0).
  - The button's fill is 3:1 or more against the card: #176e59 on #ffffff is 6.16:1 in light, #9ed5b3 on #1d2a23 is 8.97:1 in dark.
- **Evidence:** measured (AUDIT §13); seen in renders; verified in code.

**WEB-17 · Severity 2 · A whole section sells the website's dark mode**
- **Recheck:** confirmed and measured: "Try a different mood" has a 1.22:1 border in light and 1.77:1 in dark (AUDIT §8, weak boundary).
- **Where:** `src/app/page.tsx:320-358`; `src/components/ThemeProvider.tsx:75-107` (the "mood" variant); `global.css:1193-1280`. Renders: mobile screens 9–10, desktop screen 5.
- **The moment:** "A softer start. A quieter finish… Try a different mood?" They tap it, and the whole website goes dark. "Was that the app?"
- **What happens:**
  - About 1.7 phone screens about light and dark mode.
  - A tilted phone shows the outdated Tasks screenshot, with the app-bar moon switch that no longer exists (D5).
  - An outline button switches the website's theme, which the header switch already does.
- **Why it fails:**
  - HE-11: extras later, and briefly.
  - AT-4.
  - CT-5: a ghost button.
  - FN-3.
  - Subtract first.
- **Fix:** remove the section, its CSS, the "mood" variant and `tasks-*.png`. The header switch stays.
- **Verify:** there's no `#appearance`. Update `tests/website.spec.ts:176-178`.
- **Evidence:** measured (AUDIT §8); seen in renders; verified in code.

**WEB-401 · Severity 2 · Connection failures show raw developer text**
- **Where:** `src/components/VoiceDemo.tsx`:
  - `refresh` reads `response.json()` before checking `ok`: :151-159.
  - Opening shows the raw `reason.message`: :221-223.
  - `submit` reads `response.json()` before checking `ok`: :287-294.
  - Its catch shows the raw message for anything but a timeout: :308-315.
  - Renders: `voice-connect-offline`, `voice-offline`, `voice-connect-gateway`, `voice-gateway` (`.en.mobile.light.view.png`).
- **The moment:** "Failed to fetch? Unexpected token… DOCTYPE… Did I break it?"
- **What happens:**
  - **The connection drops** while opening or sending: the alert reads "Failed to fetch". That's Chromium's wording; other browsers word it differently.
    - The badge doesn't change, and nothing says whether the try was used.
    - Nothing says that sending again is free, although it is (`retryPending`, :309-310).
  - **Any answer that isn't JSON** (a proxy's or the host's HTML error page, or an empty 500): the alert reads "Unexpected token '<', "<!DOCTYPE "... is not valid JSON" (AUDIT §13 lists both as alerts).
  - When opening fails this way, the panel does offer "Let's try that again." and "Try connecting again", but under the programmer text.
- **Why it fails:**
  - OL-2: older users blame themselves 90% of the time and are almost twice as likely to give up (Nielsen 2013).
  - PF-8: a way forward.
  - TR-3: errors are trust bugs.
  - ML-5: English only, in the browser's words.
- **Fix:**
  - Read the body only when it's JSON: check `ok` and the content type first. Never show a browser or JavaScript `message`.
  - Map the cases:

    | Case | EN | ES | CA |
    |---|---|---|---|
    | No connection (`TypeError`) | No connection. Check Wi-Fi or mobile data and try again. What you said is kept, and trying again won’t cost an extra try. | No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo. Lo que dijiste se conserva y volver a probar no te costará otro intento. | No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar. El que has dit es conserva i tornar-ho a provar no et costarà cap altre intent. |
    | Not the demo's answer (not JSON, or a 5xx with no code), or a `code` the page doesn't know | The demo isn’t answering right now. Try again in a few minutes. | La demo no responde ahora mismo. Vuelve a probar en unos minutos. | La demo no respon ara mateix. Torna-ho a provar d’aquí a uns minuts. |

  - The first sentence of each row follows the app's own network message (`requestError`, `App/lib/l10n/app_en.arb:43`).
  - Each message sits above a filled "Try again" (`tryAgain`).
  - HTML answers are likely caused on the server (the host or a proxy); here the fix is how the page handles them.
- **Verify:**
  - Playwright, with `/api/voice/*` aborted and with a 502 HTML body: the alert contains the mapped text and none of "fetch", "JSON", "token", "DOCTYPE", and a retry button exists.
  - Re-take the `*offline` and `*gateway` renders in en, es and ca.
- **Evidence:** seen in current renders; measured (AUDIT §13); verified in code.

**WEB-402 · Severity 2 · The demo's text box has no visible edge**
- **Where:** `src/styles/voice.css:278-290`: `border: 1px solid var(--line)` and `background: var(--paper)`, inside a white card. `src/components/VoiceDemo.tsx:559-575`. Renders: `voice-typing`, `voice-offline`, `voice-timeout` and the other typing states, in light and dark.
- **The moment:** the visitor who refused the microphone, or has none, is sent to "Type it instead", and sees a faint box: "Where do I write?"
- **What happens:**
  - The text box's edge is 1.31:1 against the card in light and 1.52:1 in dark; its fill is 1.07:1 and 1.17:1. AUDIT §13 marks it "fail-boundary" in every typing state: 28 of the 67.
  - Only the green focus ring makes it obvious, and only once it's focused.
  - The character counter under it is 11 px and sits inside the `<label>`. So the field's accessible name is "What is on your mind? 109 / 1,500 characters", and it changes with every keystroke (`aria/voice-typing.en.txt`).
- **Why it fails:**
  - WCAG 1.4.11 (AA): a field's boundary needs 3:1 (AX-2).
  - AX-12.
  - It's the fallback path for anyone who can't or won't speak (AX-10).
- **Fix:**
  - A field border at 3:1 or more against both the card and the page: light #7d8a80 (3.61:1 on #ffffff, 3.38:1 on #f7f8f2), dark #6f8276 (3.64:1 on #1d2a23). It applies to every `.voice-panel` field; after WEB-7, only the text box is left.
  - Move the counter out of the `<label>` and tie it with `aria-describedby`, at 12 px or more (WEB-8).
- **Verify:**
  - AUDIT §13 shows no "fail-boundary" in the typing states.
  - The text box's accessible name is the label alone.
- **Evidence:** measured (AUDIT §13); seen in renders; verified in code.

**WEB-403 · Severity 2 · Security check: a disabled button, no reason, no retry**
- **Where:** `src/components/VoiceDemo.tsx`:
  - `Verification`: :36-102. Its error texts are at :61-63 and :84-86, and it has no retry.
  - "Create drafts", disabled without a token: :585-596.
  - :577-584.
  - Renders: `voice-check-pending`, `voice-check-unreachable`, `voice-check-error` (`.en.mobile.light.panel.png`).
- **The moment:** "I typed it, but the button is grey. Why?" Or: "The security check could not load… try again later. So what do I do now?"
- **What happens:**
  - **When Cloudflare wants a tap** (`voice-check-pending`): "Create drafts" is greyed, and nothing near it says the box above needs a tap.
  - **When Cloudflare's script doesn't load** (`voice-check-unreachable`; content blockers or strict networks): the alert says "Check your connection or try again later", and there's no way to retry.
    - The microphone stays active, so the visitor can record a whole minute. "Create drafts" then stays grey for good.
    - An empty 66 px gap marks where the box was.
  - **When the widget reports an error** (`voice-check-error`): "Please reopen the live demo." Reopening means "Close demo" and then "Try the live demo", which the message doesn't say.
- **Why it fails:**
  - PF-8: a way forward.
  - OL-1: every step can be retried.
  - OL-2.
  - CT-4.
- **Fix:**
  - **While the check waits for a tap,** one line just above the disabled button:
    - EN "Tap the security check above to continue."
    - ES «Toca la comprobación de seguridad de arriba para continuar.»
    - CA «Toca la comprovació de seguretat de dalt per continuar.»
  - **When it fails,** the message and a "Try again" button (`tryAgain`) that reloads the check in place (`setGeneration`). The microphone stays off until a check passes:
    - EN "The security check didn’t load. Check your connection, then tap Try again."
    - ES «La comprobación de seguridad no se ha cargado. Revisa la conexión y toca Reintentar.»
    - CA «La comprovació de seguretat no s’ha carregat. Revisa la connexió i toca Torna-ho a provar.»
  - **After two failures,** the panel shows the static example (WD1) and the hand-over (WEB-7) instead of a dead form.
  - **The API's `verification` code** gets the same in-place "Try again", with no reopening.
- **Verify:**
  - Stub the script failure and the widget error: a "Try again" button appears in the panel, the microphone is disabled until a token arrives, and after two failures the static example shows.
  - Stub a pending check: the line is visible next to the disabled button.
- **Evidence:** seen in current renders; verified in code. Turnstile's real behaviour needs a check on the deployed site with a content blocker.

**WEB-18 · Severity 1 · Without JavaScript, the live demo's button does nothing**
- **Recheck:** confirmed in `home-nojs.en.mobile.light.full.png`: "Try the live demo" looks fully active, while the walkthrough below it is greyed out and carries its `<noscript>` note.
- **Where:** `src/components/VoiceDemo.tsx:390-392`. The button isn't disabled before the script loads, and `#voice` has no `<noscript>`.
- **The moment:** JavaScript is off, or failed to load on a slow network. "Try the live demo" does nothing.
- **What happens:** the walkthrough disables itself until it's ready and has a `<noscript>` note. The live demo has neither.
- **Why it fails:** lens L: nothing waits without saying why. OL-1.
- **Fix:**
  - The static example (WD1, WEB-6) is the content without JavaScript.
  - Render the start button `disabled` until the script loads, as `TaskDemo.tsx:83-88` does.
  - Add a `<noscript>` line:
    - EN "Turn on JavaScript to try it with your voice."
    - ES «Activa JavaScript para probarlo con tu voz.»
    - CA «Activa JavaScript per provar-ho amb la teva veu.»
- **Verify:** the `home-nojs` renders show the example, the line and a disabled button.
- **Evidence:** seen in current renders; verified in code.

**WEB-19 · Severity 1 · Decorative hero text is read aloud; div labels ignored**
- **Recheck:** confirmed and measured. Added: the security box's label, which axe flags as a violation, and a glued word in the hero's spoken name.
- **Where:**
  - `aria-label` on plain `div`s: `src/app/page.tsx:85-88` and :129 (axe needs review, `aria-prohibited-attr`, AUDIT §4). Also `src/components/VoiceDemo.tsx:96-100` (`.voice-verification`), an axe **violation** in `voice-check-unreachable` (AUDIT §13).
  - Decorative captions in the reading order: page.tsx :94, :101-102, :116-117, :124 (`aria/home.en.mobile.txt`).
  - Capitals typed into the source: :44, :94, :101, :124, :408; `VoiceDemo.tsx:370, :612-615`.
  - The hero region's name in Chromium's tree is "Make room for aclearer day." (AUDIT §9): the space before the accent span (page.tsx:49-51) is lost.
- **The moment:** a TalkBack user hears "Make room for aclearer day", then after the button: "Less organizing… JUST SAY THE WORD, A walk at six… Make a little time for you. That belongs on your list, too. YOUR DAY, LOOKING A LITTLE LIGHTER."
- **What happens:**
  - An `aria-label` on a generic `div` isn't exposed.
  - Decorative captions are read as content.
  - Some screen readers spell out text typed in capitals.
  - A glued word is read as one nonsense word.
- **Why it fails:** AX-5, AX-6 and WCAG 1.3.1.
- **Fix:** WEB-1 and WEB-11 remove most of this. For what stays:
  - `aria-hidden="true"` on decorative captions;
  - no `aria-label` on plain `div`s: use `role="group"` if a name is needed (the security box needs none);
  - sentence case in the source, with `text-transform: uppercase` in CSS;
  - the H1's spaces kept inside text nodes, checked against Chromium's name.
- **Verify:**
  - axe shows no `aria-prohibited-attr` on the pages or in the demo states (AUDIT §4, §13).
  - AUDIT §9's region names contain no glued words.
  - A manual pass with TalkBack.
- **Evidence:** measured (AUDIT §4, §9, §13); verified in code. What a screen reader says aloud needs a device.

### Claims checked

| Claim (page, `path:line`) | Source of truth (`path:line`) | Verdict |
|---|---|---|
| Hero: "Small reminders" (`src/app/page.tsx:63`) | D2, `.claude/ux-review/DECISIONS.md:163-168`; `reminderAskQuestion` (`App/lib/l10n/app_en.arb:1037`) | true |
| Hero card: "Just say the word — 'A walk at six.'" (`page.tsx:101-102`) | `addTask` (`app_en.arb:204`); the app's own example names two tasks (`calendarTrySaying`, `app_en.arb:312`) | true |
| Hero image and alt: an agenda with two buttons, three tabs and an app-bar switch (`page.tsx:110`; `Phone.tsx:3-4`; `public/images/agenda-*.png`) | `App/build/calendar-es-1.3x-light.png` (2026-10-19); D5, `DECISIONS.md:184` | outdated |
| Bar: "A clearer calendar" (`page.tsx:131`) | Calendar is the first screen (`DECISIONS.md:223`) | true |
| Bar: "Your words, into action" (`page.tsx:134`) | Free tier, `DECISIONS.md:130-133`; `freeVoiceLeft` (`app_en.arb:1899`) | true |
| Bar: "Every detail, together" (`page.tsx:137`) | `App/docs/IMPLEMENTATION_STATUS.md:27` (B19) | true |
| "Try real voice-to-task, right here." (`VoiceDemo.tsx:373`) | The demo calls `gemini-3.5-flash-lite` (`src/lib/voice/model.ts:51`); the app's route is in `DECISIONS.md:47, :251`; WD8 keeps the demo and labels its tries (`.claude/ux-web/DECISIONS.md:44`) | true of the demo |
| "One thought or a few plans" (`VoiceDemo.tsx:373-374`) | `policy.ts:136` (up to 6 tasks); `DECISIONS.md:99-104` | true |
| "3 free tries · no account" (`VoiceDemo.tsx:377`) | `policy.ts:3-4, :51-56`; the app needs an account (`IMPLEMENTATION_STATUS.md:47`; `DECISIONS.md:126-129`) | true of the demo; misleading as the app's (WEB-12) |
| "Speak in English, Spanish, or Catalan." (`VoiceDemo.tsx:387`) | `App/lib/l10n/app_{en,es,ca}.arb` | true |
| "Review the transcript, then make the drafts your own." (`VoiceDemo.tsx:387-388`) | The app's result: «Ver lo que dije», collapsed, and no edit forms (`App/build/review-batch-light.png`, `review-direct-light.png`; `reviewOriginal`, `app_en.arb:7`) | outdated |
| "Up to 60 seconds." (`VoiceDemo.tsx:394`) | `policy.ts:7`; `VoiceDemo.tsx:249-251` | true |
| "Sent to Google … only when you choose 'Create drafts'" (`VoiceDemo.tsx:394-395`) | `VoiceDemo.tsx:263-287` | true |
| "Three submissions in a rolling 24 hours… Shared-network limits also apply." (`VoiceDemo.tsx:600`) | `policy.ts:3-5, :44-57` | true |
| "Recording and editing do not use a try." (`VoiceDemo.tsx:600`) | Only submitting is admitted (`src/app/api/voice/draft/route.ts:79-86`) | true |
| "Do not sync to the app" (`VoiceDemo.tsx:601-602, :813-814`) | The page keeps them in memory (`VoiceDemo.tsx:663-668`) | true |
| A "Task N" label and a priority chip on each result (`VoiceDemo.tsx:672-679`) | The app's result shows neither (`App/build/review-batch-light.png`, `review-direct-light.png`) | outdated |
| "Whenever you’re ready" for an undated task (`VoiceDemo.tsx:22`) | `noDate`: "No date", «Sin fecha» (`app_en.arb:198`, `app_es.arb:136`) | outdated (the app's name differs) |
| "Check this: …" (`VoiceDemo.tsx:692-694`) | `reviewResolve`: "Check this detail", «Revisa este dato» (`app_en.arb:23`, `app_es.arb:20`) | true; the app's words differ |
| "No tasks were found. Try describing something you want to do." (`VoiceDemo.tsx:631-634`) | `captureNoTasks`: "No tasks were found. Your words are kept." (`app_en.arb:1412`) | true; the app's words differ |
| "Your allowance returns tomorrow." (`policy.ts:73`) | A rolling window: `resetAt` = the earliest try + 24 h (`policy.ts:55`) | false at times |
| "Please try again tomorrow." (network, `policy.ts:80`) | The same window (`policy.ts:55, :68`) | false at times |
| Timeout: "Try again to retrieve this request without another AI call." (`VoiceDemo.tsx:313`) | `retryPending` (`VoiceDemo.tsx:309-310`); `store.ts:94` | true (jargon: WEB-12) |
| "The sample walkthrough below is always available" (`VoiceDemo.tsx:828`; `policy.ts:87`; `security.ts:18, :101`) | WD1 removes the walkthrough (`.claude/ux-web/DECISIONS.md:23`) | true today; false once WD1 is built (WEB-6, step 3) |
| Walkthrough: "a sample week in September 2026", fixed 21–25 September dates (`TaskDemo.tsx:11, :22, :33, :167-168`) | Today is 2026-10-19 | outdated |
| Walkthrough: a five-field draft with Priority (`TaskDemo.tsx:212-272`) | The app's result: title, date line, notes, «Más opciones» (`App/build/review-direct-light.png`; `reviewOptions`, `app_en.arb:6`) | outdated |
| Walkthrough: "No microphone, AI request, or account needed." (`TaskDemo.tsx:168`) | `TaskDemo.tsx` makes no network call | true |
| `<noscript>`: "an editable draft with a title, schedule, priority, and notes" (`page.tsx:312-314`) | `App/build/review-direct-light.png`: priority sits under «Más opciones» | true in substance ("draft" isn't the app's word) |
| Appearance: "light or dark mode" (`page.tsx:341-342`) | D5 (`DECISIONS.md:184`) | true |
| Appearance screenshot: Tasks with an app-bar moon (`page.tsx:327`; `public/images/tasks-*.png`) | D5; the app's current bars (`App/build/calendar-es-1.3x-light.png`) | outdated |
| Closing: "Android app in development · Public download coming soon" (`page.tsx:423-424`) | Google Play isn't published (`.claude/ux-web/DECISIONS.md:68`) | true |
| Header: "Explore the app ↗" (`src/components/Header.tsx:48-50`) | `.claude/ux-web/DECISIONS.md:68` | false: there's no app to explore; it opens a sample form |
| Menu: "Get TaskFlow" (`Header.tsx:62-64`) | `.claude/ux-web/DECISIONS.md:68` | false today |

### Missing from the site (app features worth telling)
- **Several things in one dictation.** The owner calls it "absolutely a must" (`.claude/ux-review/DECISIONS.md:99-104`). The app teaches it on first run (`calendarTrySaying`).
  - Where it belongs: the hero subheadline (WEB-1), the hero image (WEB-5) and the demo's static example (WEB-6).
  - It replaces the single-task examples.
- **One button, «Añadir tarea».** The north star (CLAUDE.md, Product rules; `addTask`).
  - Where it belongs: the hero image (WEB-5) and the demo's hand-over line (WEB-7).
  - It replaces the old two-button image.
- **Reminders when you want them.** «¿Quieres un recordatorio antes?» comes at the first dated task (D2; `reminderAskQuestion`).
  - Where it belongs: the hero subheadline (WEB-1).
  - It replaces "Small reminders".
- **Nothing is added without your tap, and «Deshacer» undoes it** (D3, D11; `captureAddToCalendar`, `undo`).
  - This is a trust point for the wary newcomer. It belongs in area F's voice card or the FAQ, not the demo, which talks about itself.
- **Voice commands:** create a project, assign, find, change and delete tasks by voice (`.claude/ux-review/voice-commands-plan.md`). They belong in area F's features, not the hero (HE-11).

### Keep
- **The live demo asks well.** It asks for the microphone only after a tap, caps recordings at 60 s with a visible counter, and always offers typing (`VoiceDemo.tsx:227-252, 483-507`; renders `voice-mic-waiting`, `voice-typing`). Keep that through WEB-9 and WEB-14.
- **Focus follows the demo.** Each new stage moves focus to its heading, and each error to its message, which uses `role="alert"`. Updates made in place, such as recording, leave focus where it was (AUDIT §13, Focus and Announced columns). Keep that when reworking it (AX-9).
- **Text contrast passes in both themes.** The home has no failures. Its lowest pairs are 4.87:1 in light and 6.21:1 in dark (AUDIT §7). The only failure is in the preview list, which WEB-7 removes.
- **Fast and stable in the lab.** The home's LCP is 1.82 s and CLS 0.000 under mobile throttling (AUDIT §2; lab data, not field data). Nothing scrolls sideways at 320 px, and nothing is clipped at 200% zoom (AUDIT §3).
- **Nothing in the hero moves by itself.** Reduced motion stops the reveal, the spinner and smooth scrolling (`global.css:2407-2415`; `voice.css:539-544`).

### Questions for the owner (product decisions only)
None. WD1–WD13 (`.claude/ux-web/DECISIONS.md`, 2026-10-18, night) are decided, and the findings above build them. The new evidence raised no new product question.

### Cross-slice notes
- **G:**
  - Playwright's WebKit (on Windows) draws every weight of Manrope as its thinnest (compare `webkit/home.en.*.fold.png` with Chromium). The likely cause is the variable font's `font-weight: 200 800` in `@font-face` (`global.css:3-9`). Check Safari on an iPhone: if it reproduces, the hero's H1 and its 10–11 px labels lose their weight.
  - Chromium's accessible names lose a space:
    - the hero region reads "Make room for aclearer day." (AUDIT §9; WEB-19);
    - the 404's heading is measured as "Let’s findyour flow again." (AUDIT §2, LCP element; `not-found.tsx`).
  - With `#demo` gone (WD1), the nav's "How it works" (`Header.tsx:9`) and the footer's "Try the demo" (`Footer.tsx:22`) must move (WEB-4, step 5).
  - The home's lab TBT is 562 ms, and both hero screenshots download (AUDIT §2): WEB-311.
- **F:**
  - The FAQ's "Can I download TaskFlow yet?" (`page.tsx:8`) sends people to "the real app screens" and "the interactive walkthrough". Both change with WD4 and WD1.
  - The features' voice-card drawing (`page.tsx:239-248`) is the fourth fake microphone (WEB-16; F's WP4).
- **L:**
  - The demo's privacy line needs its retention in privacy §8's words, and now sits next to the microphone (WEB-12).
  - Its link is WEB-207.
  - The server strings that name "the sample walkthrough" (`policy.ts:87`, `security.ts:18, :101`) are repointed by WEB-6, step 3, strings only.

### Memory notes
- **Site map.**
  - `/` sections, in order: hero (no id), `.promise-bar`, `#features`, `#voice` (VoiceDemo), `#demo` (TaskDemo), `#appearance`, `#questions`, `#get-taskflow`.
  - Header nav: `/#features`, `/#demo` ("How it works"), `/#voice`, `/#questions`. The CTA "Explore the app" goes to `/#demo`; the menu's "Get TaskFlow" goes to `/#get-taskflow`.
  - Full renders are 7981 px on a phone (12 screens) and 6235 on desktop.
  - Measured positions on a phone: hero button y = 367; "Try the live demo" y = 3585; closing button y = 7361; launch note y ≈ 7446; footer "Delete account" y = 7802. On desktop, the demo button is at y = 2693.
- **Claims map.**
  - Hero: reminders at `page.tsx:63`, the voice example at :101.
  - Screenshots: `public/images/{agenda,tasks,calendar}-*.png`, from 2026-09-21. WD4's replacements are `hero-calendar-<language>-<theme>.png`, 780 × 1688.
  - Demo limits: `VoiceDemo.tsx:377, 394, 600`, backed by `policy.ts:3-7, :55`. Tries are recorded at `route.ts:79`; everything checked before that line doesn't use a try.
  - The demo's model: `model.ts:51`.
  - Availability: `page.tsx:423`; `Header.tsx:48-64`.
- **App vocabulary to match** (ARB keys): `addTask`, `done`, `captureStarting`, `listeningSeconds`, `captureUnderstanding`, `captureThingsToAdd`, `captureAddTasks`, `captureAddToCalendar`, `captureSayAgain`, `reviewOriginal`, `reviewResolve`, `noDate`, `captureNoTasks`, `captureEmptyInput`, `captureTypeInstead`, `captureMicrophone`, `captureMicrophoneBlocked`, `tryAgain`, `requestError` (network), `freeVoiceLeft`, `freeVoiceNoticeBody`, `taskflowPro`, `authPitch`, `calendarTrySaying`.
- **Patterns.**
  - Every call to action is an in-page anchor.
  - All font sizes are in px, so text200 renders come out identical to 100%.
  - Eyebrows are typed in capitals.
  - The demo shows the server's `error` string, or the browser's `message`, as it is.
- **Recurring problems.**
  - Slogans instead of what the product does.
  - Tiny type.
  - Decorative microphones.
  - Outdated screenshots.
  - English only.
  - Demos without a next step.
  - Raw error text.
  - Controls whose state is shown only by a near-identical fill.
- **Techniques that worked.**
  - `audit.json`: `pages[]` and `demos[]`; each has `collected.targets` (with y positions), `texts` (sizes and contrast), `controls` (fill, border and icon ratios), `live`, and `screenReader.landmarks`. Query them with Python, using `PYTHONIOENCODING=utf-8`.
  - AUDIT §13's "Announced" column lists every message the demo shows.
  - Chromium's names (AUDIT §9) can differ from Playwright's snapshot names (`aria/`): trust AUDIT for what TalkBack gets.
  - `crop.mjs` names its output after the render's basename, so cropping a `webkit/` render overwrites the Chromium crop of the same name. Crop one engine at a time.
  - Compare the hero with `App/build/calendar-es-1.3x-light.png`, and the demo with `review-*` and `capture-listening-es-2x.png`.
