# UX web plan — 2026-10-18-site (whole site, recheck)

72 findings from the four rechecked reviews: 62 fixes in 19 packages (WP14–WP32), 1 that waits on you (WD15), and 9 skipped (8 duplicates, 1 withdrawn). WD1–WD13 are decided, so everything that waited on them is now a fix.
The fixes make the home say what TaskFlow is and that it isn't on Google Play yet, send every button to the live demo, put the home, the frame and the demo in Spanish and Catalan, make the demo look and talk like the app, and bring the legal pages up to date with the app (RevenueCat, email codes, speech on the phone). Ten packages touch the other session's files and stay uncommitted for you.

This plan replaces the first one (`plan-first.md`, WP1–WP13, now history). New numbers start at WP14 and WD14 so the two can't be confused.

**How it runs**
- No approval this time (your instruction): the plan goes straight to the implementers, in batches of about five, in this order.
- **Commits.** WP14–WP21 and WP25 commit on `dev`. WP22–WP24 and WP26–WP32 change the other session's files, so those files **stay uncommitted for you** (each package's `commit` field in `plan.json` lists them). For WP30–WP32, your review of the uncommitted legal change is the sign-off WD3 asked for.

## Decisions

### WD14 · Should “unlimited” carry its safety limit? (new, from review F)
WD2 publishes "TaskFlow Pro: unlimited dictation and file space", as the app says. Every account, Pro included, also has a safety limit of 50 dictations a day, a 200-a-day budget shared by everyone, and 6 MB a file, 20 files a task and 1,000 files.
- **WEB-104** (S3, part) the FAQ's pricing answer.

**Recommend:** yes, once, in the FAQ only: "(with a safety limit of 50 dictations a day)" / «(con un límite de seguridad de 50 dictados al día)» / «(amb un límit de seguretat de 50 dictats al dia)».
- The closing card and the line under the demo keep WD2's short wording.
- Raise the shared 200-a-day budget before launch, so one busy day can't block Pro customers.
- It's also a consumer-law wording check for you.

Until it's recorded, WP18 publishes WD2's wording without the clause. Once it is, the clause is a one-line change in a scoped run.

### WD15 · Is TaskFlow's type thin in Safari on your iPhone? (new, from review G; needs your phone)
In Playwright's WebKit on Windows, all 56 renders draw Manrope at its thinnest weight, so headings and buttons look thin and the small print nearly disappears. Chromium is fine. Safari on iPhone most likely isn't affected, but only a real device can tell.
- **WEB-701** (S2) WebKit draws every weight at Manrope's thinnest.

**Recommend:** open `/`, `/es/privacy/` and a missing page in Safari on your iPhone.
- **Bold:** close WEB-701 as a Windows-WebKit artifact.
- **Thin:** a small package loads Manrope as static font files for the weights the site uses.

The main session can't answer this one for you.

### Still yours from earlier
- **WD12's two facts:** the backup window, and paid or free Gemini. The legal pages keep today's cautious wording.
- **Legal checks:**
  - WD14's wording;
  - the legal notice's "features are only those expressly offered" next to the home's free-plan lines (review F);
  - the registry line's English and Spanish translation (WEB-211, WP30).
- **At launch:** Google's approval of the Android trademark line.

## Packages, in run order
Severity 4 first, then 3, then 2. A package's prerequisites run before it, even when they're less severe. Each line reads: finding (severity), the problem, then the fix.

### WP14 · Subtract: the walkthrough, the appearance section, the slogan bar and a fake microphone go; the live demo moves under the hero · H · M · commits
- **WEB-6** (S3) the sample walkthrough teaches a form → removed (WD1); WP26 adds the static example.
- **WEB-17** (S2; merged WEB-112) a section sells the website's dark mode → removed, with its "mood" button and screenshot.
- **WEB-11** (S2) the "at a glance" bar is four slogans at 7–11 px → removed.
- **WEB-10** (S2) the live demo starts 5.4 phone screens down → it follows the hero.
- **WEB-16** (S2) a features drawing is a fourth fake microphone → removed.
- **WEB-114** (S1) the drawing says "September 2026" → gone.

### WP15 · Spanish and Catalan homes at /es/ and /ca/; the bare address picks the visitor's language · G · L · commits · after WP14
- **WEB-2** (S3; merged WEB-301) the home exists only in English → `/es/` and `/ca/` from one copy table per language, with hreflang.
  - The bare `/` follows the browser's language, or the language you picked, never the IP (WD5).
  - The page's language comes from its address.

### WP16 · Hero: what TaskFlow is, that it isn't out yet, today's app · H · L · commits · after WP15
- **WEB-1** (S4) the hero never says what TaskFlow is → "Say it, and it's on your calendar.", then one button, several things at once, reminders, "An app for Android™ phones".
- **WEB-3** (S3) nothing near a button says it isn't out → "Coming soon to Google Play. You can't download it yet." under the button.
- **WEB-4** (S3) the button went to a sample form → "Try it with your voice", to the live demo.
- **WEB-5** (S3; merged WEB-103) the screenshot shows an old app, tilted and unreadable → WD4's Calendar in the page's language and theme, upright, at least 272 px wide.
- **WEB-19** (S1) decorative captions are read aloud, and the name glues "aclearer" → removed or hidden; spaces kept.
- **WEB-311** (S1) both theme screenshots download → only the visible one.

### WP17 · Features: plain headings and true cards · F · M · commits · after WP15
- **WEB-101** (S4) the cards say signing in is optional → files and tasks are kept in your account.
- **WEB-105** (S3) several tasks at once is never told → "Say several things at once".
- **WEB-106** (S2) reminders are never told → "it asks once, the first time you add one".
- **WEB-504** (S2) your phone's calendars are never mentioned → "beside the events from your phone's calendars".
- **WEB-111** (S2) the headings are mood lines → "What TaskFlow does" and four plain card headings.
- **WEB-4** (S3) "Give it a try" is another name for the demo → "Try it with your voice".

### WP18 · Closing card and the first FAQ answers: how to get it, what's free, why an account · F · M · commits · after WP15
- **WEB-3** (S3; merged WEB-102) "not yet" was 10 px on screen 12 → the card says "Coming soon to Android." The download answer says Android only, in three languages.
- **WEB-4** (S3) "Find your flow" loops back up → "Try it with your voice".
- **WEB-104** (S3) nothing about the free plan or Pro → WD2's line in the card, and a "Is TaskFlow free?" answer, second in the FAQ. The safety-limit clause waits on WD14.
- **WEB-101** (S4) the FAQ says no account is needed → "Yes. You sign in once: Continue with Google, or your email and a 6-digit code".
- **WEB-503** (S1) opening one answer closes the other → several can be open.
- **WEB-308** (S2) keyboard focus on the card is 1.58:1 → a lime ring at 7.57:1.

### WP19 · FAQ: what TaskFlow does, in the app's words · F · M · commits · after WP18
- **WEB-105** (S3) the voice answer misses several tasks, changes by voice and Undo → "How do I add tasks by voice?"
- **WEB-107** (S2) the sharing answer says "list" and the old invitation → "Can I share tasks with my family?", with projects, Share, «Creada por» and one person's tasks.
- **WEB-110** (S2) the notes answer describes a removed choice → the Notes tab and Add a note.
- **WEB-109** (S2) "sync", "shared-list", "transcribes" → the app's words, checked across the home.
- **WEB-111** (S2) "Glad you asked." → "Questions".

### WP20 · Header: honest labels, a language switch, a worded phone menu · G · L · commits · after WP15
- **WEB-4** (S3; merged WEB-305) the filled "Explore the app ↗" → removed; one label per place, in page order.
- **WEB-3** (S3; merged WEB-303) "Get TaskFlow" promises a download → "Coming soon to Android".
- **WEB-2** (S3) no way to change language → "English · Español · Català" in the header and the menu, remembered in a cookie.
- **WEB-304** (S2) the header is English on Spanish and Catalan pages → translated, names included.
- **WEB-307** (S2) two unlabelled icons on phones → a "Menu" button with a word; Light and Dark move into the menu; 48 px targets.

### WP21 · Titles, link previews and the 404 say what TaskFlow is, in each language · G · M · commits · after WP15, WP16
- **WEB-302** (S3) the WhatsApp preview is an English slogan → "TaskFlow — Say it, and it's on your calendar", the app's own pitch, og:locale, and a preview image per language with the app's Calendar.
- **WEB-306** (S2) the 404 is an English pun → "Page not found" in three languages, with home and deletion links above the fold.

### WP22 · The page's head: its language before first paint, a translated skip link, two theme colours, the font · G · M · **layout.tsx stays uncommitted** · after WP15, WP21
- **WEB-2** (S3) `<html lang>` is "en" on Spanish and Catalan pages → set from the address before first paint.
- **WEB-304** (S2) "Skip to content" is English → translated.
- **WEB-313** (S1) dark-mode visitors get a light toolbar → two theme colours.
- **WEB-311** (S1) a hand-preloaded TTF → Next's font loader, a smaller file if the tool installs.
- **WEB-302** (S3) the layout's defaults are the old slogan → the English home's.

### WP23 · Footer in the page's language, with the switch, the trademark line and bigger targets · G · M · **Footer.tsx and legal.css stay uncommitted** · after WP20
- **WEB-304** (S2) the footer is English and its legal links open English pages → translated; links keep the language («Suprimeix el compte» in Catalan).
- **WEB-2** (S3) no switch in the footer → the same switch.
- **WEB-4** (S3) "Try the demo" points at the removed `#demo` → "Try it with your voice".
- **WEB-704** (S1) Android named without the trademark line → "Android is a trademark of Google LLC." in three languages.
- **WEB-703** (S1) "Back to top" 62 × 33 px → 44 px targets, 8 px apart.
- **WEB-309** (S2) the operator line is 11 px → 12 px or more, in rem. WD6's "A little focus. A little flow." goes.

### WP24 · Legal pages keep the visitor's language · L · S · **uncommitted** · after WP15, WP20
- **WEB-2** (S3) «Volver a TaskFlow» goes to the English home; the sitemap lacks `/es/` and `/ca/` → the language's home; both added.
- **WEB-208** (S1, was S2; its overflow half withdrawn by review L) the current language is shown by a 1.12:1 fill → the shared switch's ring and bold, remembered like the header's.

### WP25 · Readable type in rem, tap feedback, a 48 px logo, and dark mode without JavaScript · G · L · commits · after WP16–WP21, WP23
- **WEB-8** (S3) 39% of the home's text is under 12 px; 0 of 137 texts grow with the browser's text size → 16 px body in rem, nothing under 12 px.
- **WEB-309** (S2) the frame's small print is 8–11 px in px → rem. Withdrawn WEB-310's overflow check now lives here.
- **WEB-313** (S1) without JavaScript, a dead faded switch on a light page → dark tokens follow the system; the theme controls are hidden until they work.
- **WEB-702** (S1) taps give no feedback → the tap highlight returns; hover effects only where hover exists.
- **WEB-703** (S1) the logo is 34 px tall → 48 px.

### WP26 · Live demo, intro: what it is, a static example, the privacy line where you talk · H · M · **uncommitted** · after WP14, WP15
- **WEB-6** (S3) → WD1's static example: "For example, say: “Tomorrow, call the dentist and buy bread.”" and its two task cards, visible without JavaScript.
- **WEB-12** (S2) jargon and slogans → "Try it with your voice"; badge "This demo: 3 tries a day, no sign-up" (WD8).
- **WEB-18** (S1) without JavaScript the button does nothing → disabled, with a line saying why.
- **WEB-207** (S2) "How we use your data" lands on the app's section → the demo's section, in the page's language, next to the talk button.
- **WEB-16** (S2) the intro's 78 px microphone orb → removed.
- **WEB-4** (S3) on phones the hero's button lands below the demo's button → it's in view.

### WP27 · Live demo, talking and typing: one tap, Done sends, the app's words · H · L · **uncommitted** · after WP26
- **WEB-9** (S2) three taps, a listen-back stage, a near-invisible switch → "Tap to talk", then "Done" sends; "Type instead" as a link.
- **WEB-16** (S2) the real record button is the palest control → a solid green 72 px button with words.
- **WEB-14** (S2) microphone errors in the browser's English → plain steps in three languages, and the text box opens.
- **WEB-15** (S2) the timer is announced every second → three announcements, and "10 seconds left".
- **WEB-402** (S2) the text box's edge is 1.31:1 → 3:1; the counter leaves the label.
- **WEB-502** (S2) typed sentences become tasks, which is Pro in the app → one line says so.

### WP28 · Live demo, the result: as the app shows it, then an honest hand-over · H · L · **uncommitted** · after WP27
- **WEB-7** (S3) the result becomes a toy task manager → it ends at the result, then "In the app: tap Add a task, say it, tap Done… Coming soon to Google Play."
- **WEB-108** (S2) "Task N" and a priority chip → title, date line, notes, like the app.
- **WEB-104** (S3) → WD2's line under the demo, in every state.
- **WEB-9** (S2) → "2 things to add", "No date", "See what I said", "Say it again".
- **WEB-2** (S3) dates follow the browser and mix 12- and 24-hour times → the page's language, one format.
- **WEB-12** (S2) "no tasks" shows a success tick → "No tasks were found. Your words are kept. That used a try."

### WP29 · Live demo, waiting and failures: plain messages, a way forward, readable type · H · L · **uncommitted** · after WP28
- **WEB-13** (S2) the same spinner from 1 s to 54 s, no way out → a new line and "Stop waiting" at 10 s; 40 s timeout.
- **WEB-401** (S2) "Failed to fetch" and JSON errors → plain messages and "Try again".
- **WEB-403** (S2) the security check greys the button with no reason → a line, "Try again", and the static example after two failures.
- **WEB-12** (S2) server messages shown as they are (PCM, chunk, "tomorrow") → a message per code, in three languages.
- **WEB-8** (S3) the demo's text is 11–13 px in px → rem, nothing under 12 px.
- **WEB-2** (S3) → no English left in any demo state on `/es/` and `/ca/`.

### WP30 · Legal template: each page names its document, readable text, plain labels, link previews · L · L · **uncommitted** · after WP21, WP24
- **WEB-203** (S2) the privacy page's first screen has no privacy fact → H1 "TaskFlow Privacy Policy", and the summary leads with "We don't sell your data or show you ads."
- **WEB-205** (S2) 14 px grey text in ≈140-character lines that doesn't grow → 16 px in rem, 68 characters wide, 44 px rows, no clipped focus.
- **WEB-212** (S1) ↗ on links that stay on the site → → for pages, ↗ for other sites, none for email.
- **WEB-213** (S1) "Versión 2026-10-16" → "In force since 19 October 2026" (the edit's date, WD3).
- **WEB-211** (S1) a placeholder-like line, a mislabelled button, a Catalan-only registry line → fixed; you confirm the registry translation.
- **WEB-312** (S1) legal pages share with no image and English X tags → their language's preview and their own titles.

### WP31 · Privacy and terms say what the app and the site do today · L · L · **uncommitted** · after WP14, WP20, WP27, WP30
- **WEB-113** (S2; merged WEB-201) six points behind the app → email codes, Google's first name, speech on the phone, phone calendars stay on the phone, names on shared tasks, "we never delete your tasks on our own".
- **WEB-501** (S2; merged WEB-601) "RevenueCat keeps your record" → "we also ask RevenueCat … to delete its record of you".
- **WEB-207** (S2) → §8 opens with "we don't keep your recording".
- **WEB-602** (S2) §8 describes the removed walkthrough and "Create drafts" → gone. Adds the language cookie and the bare address's choice (WD5).
- **WEB-209** (S2) TTL, keyed hashes, endpoint, SDK, APK, staging → plain words.
- **WEB-210** (S1) Apple in privacy and terms → Google Play only (WD7).

### WP32 · Delete page: the app's route first, plain words, the app's Catalan · L · M · **uncommitted** · after WP30, WP31
- **WEB-202** (S2) what goes, explained in database words → the app's own lines: "Deleted: your account and your tasks, notes and files…"
- **WEB-204** (S2) the in-app route is 14 px grey under the email button → "With the app: Settings → Account → Delete account…" first, in ink; "No app, or can't sign in? Email us:".
- **WEB-206** (S2) Catalan «Eliminar» vs the app's «Suprimeix» → «Suprimeix el compte» throughout.
- **WEB-501** (S2) §3's RevenueCat bullet → the record is deleted on request.
- **WEB-210** (S1) "Manage Apple subscriptions" → gone.

## How the reports were settled
Say if any of these is wrong; only the package named changes.
- **The main label** is "Try it with your voice" (reviews H and G). The demo's own start button keeps "Try the live demo" (WP26).
- **The menu row and closing heading** are «Muy pronto en Android» / «Molt aviat a Android» (review H, matching the hero's «Muy pronto en Google Play»). Review G proposed «Próximamente» / «Properament».
- **The closing card** takes review H's heading and paragraph. Review F's "an app for Android phones" is already in the hero and the download answer.
- **WD2's line** is one line, the same words in the closing card and under the demo:
  - "Free with an account" comes from review F;
  - "a monthly subscription" comes from review H;
  - the line sits under the demo's card, visible in every demo state, as review F asked.
- **Privacy §5's name sentence** merges both reviews: review L's assigned tasks with review F's "the start of your email" and one person's tasks.
- **RevenueCat** uses review L's wording on both pages, because it says who RevenueCat is.
- **Privacy §8's first sentence** is review L's, with two changes: "drafts" becomes the app's word, and «en directo» / «en directe» is how the demo says it (instead of «en vivo»).
- **"Email support"** is «Escriu al suport» in Catalan, in the footer and on the legal pages (review G wrote «al», review L «a»).
- **The current-language cue** is review L's 2 px ring plus bold, in the header, the menu, the footer and the legal pill. Review G asked for one pattern; its check icon would widen the pill.
- **The footer's labels** are review G's ("Privacy", not "Privacy Policy").
- **«l'aplicació» or «l'app» in Catalan:** the home, the frame and the demo say «l'aplicació», as the app does; the legal documents keep their own «l'app».
- **The demo's capture heading** is the app's «¿Qué quieres recordar?», instead of "What's on your mind?".
- **The line under the talk button** drops review H's "Tap to talk," because the button now says it.
- **The hero's alt text** is review H's (it names the button in the app's words).
- **The hero's height:** review H wanted the demo above y = 1328 on a phone, which was measured before WD4 made the phone 272 px and upright. The checks allow 1400, about two screens.

**Removals the organizer added** (strike any you want kept):
- the home's remaining eyebrows (features, FAQ, demo);
- the FAQ's intro and its doodle;
- the hero card's "JUST SAY THE WORD";
- the features' "High priority" and "Bring the results" chips and "Your plans can come along.";
- the demo's "Your drafts will appear right here";
- privacy §8's repeated sentence about the 24-hour transcript.

**Copy the reports didn't give** (the demo's buttons and labels, some FAQ questions, the drawing's words) is the organizer's. Each brief marks it "(organizer's)", and its Catalan wants a native read.

## Skipped
- **WEB-102, WEB-303** → duplicates of WEB-3 (WP16, WP18, WP20).
- **WEB-103** → duplicate of WEB-5 (WP16).
- **WEB-112** → duplicate of WEB-17 (WP14).
- **WEB-201** → duplicate of WEB-113 (WP31).
- **WEB-301** → duplicate of WEB-2 (WP15, WP20, WP22–WP24, WP28, WP29).
- **WEB-305** → duplicate of WEB-4 (WP16–WP18, WP20, WP23, WP26).
- **WEB-601** → duplicate of WEB-501: reviews F and L found the same RevenueCat sentence (WP31, WP32).
- **WEB-310** → withdrawn by review G. Measured: nothing scrolls sideways at 320 px, 200% zoom or doubled text, because no text grows yet. Its check moves into WEB-309 (WP25).

## For the main session
- **What stays uncommitted** (never stage these):
  - `layout.tsx` (WP22);
  - `Footer.tsx` (WP23);
  - `LegalPage.tsx`, `legal.css`, `sitemap.ts`, `src/content/legal/`, `tests/legal.spec.ts` and `docs/LEGAL_RELEASE.md` (WP23, WP24, WP30–WP32);
  - `VoiceDemo.tsx` (WP26–WP29), and with it `src/styles/voice.css`, the demo packages' changes to `tests/voice.spec.ts` and `tests/support/ux-voice.ts`, and the tester's `tests/ux-web-voice.spec.ts`, `tests/ux-web-frame.spec.ts` and `tests/ux-web-legal.spec.ts`.

  In the first batch, WP14's own changes to `tests/voice.spec.ts` and `tests/support/ux-voice.ts` do commit. New files (`src/content/site/`, `src/components/*`, `src/app/[language]/page.tsx`, `src/app/[language]/opengraph-image.tsx`, `src/proxy.ts`) commit.
- **WD14:** record it, then the clause is a one-line scoped run.
- **WD15:** waits on the owner's iPhone.
- **When the owner commits `layout.tsx` (WP22):**
  - delete `global.css`'s `@font-face` (lines 3–9), and the TTF if next/font uses a new file (keep `OFL.txt`);
  - once the demo and legal packages are committed too, check whether `.eyebrow` and `.section-eyebrow` are unused, and delete them if so.
- **The WD4 images show "October" and "Tuesday, October 20".** They date the page, as WEB-114 warns. Re-render them shortly before publishing (WD13). The README gives the command.
- **Stale records outside the website** (the loop doesn't edit them):
  - `Backend/docs/ACCOUNT_DELETION.md:65-67`;
  - the Open list of `.claude/ux-review/DECISIONS.md` (still lists decided items, and says the website's delete page has no in-app route; it has one).
- **For `/ux` in the app:**
  - `app_en.arb:1703` still says "available in the Android and iOS app" (WD7);
  - WD11's Privacy and Terms links aren't in `App/lib` yet. Play requires a privacy-policy link inside the app.
- **Checks only you can do** (also in each package):
  - Safari on an iPhone: type weight (WD15) and the FAQ jump;
  - TalkBack: the hero, the recording, a Spanish title;
  - Android at its largest font size;
  - a dark-mode phone on a slow network;
  - denying the microphone on Android and iPhone;
  - the live demo with the real AI;
  - Turnstile with a content blocker, after a deploy;
  - WhatsApp previews, after a deploy;
  - a native Catalan read;
  - the delete summary read aloud to someone over 60.
