# UX web plan — 2026-10-18-site (whole site)

59 findings from the four reviews: 40 fixes in 13 packages, 12 that wait on you (13 questions below), and 7 duplicates.
The fixes make the home say what TaskFlow is and that it isn't on Google Play yet, send every button to the live demo, put the home and the frame in Spanish and Catalan, and correct six false or outdated FAQ answers. Five packages touch the other session's files, so they stay uncommitted for you.

**How it runs**
- Answer WD1–WD7 when you approve: they change this plan. WD8–WD13 can wait.
- The main session then records your answers in `.claude/ux-web/DECISIONS.md` and runs `/ux-web plan 2026-10-18-site`, which turns the answered parts into packages, before `/ux-web fix`.
- To run the packages as they are: `/ux-web fix`. To hold some back: `/ux-web fix skip WP4`, or `/ux-web fix only WP1 WP2 WP3`.
- **Commits.** WP1–WP6, WP9 and WP12 commit on `dev`. WP7, WP8, WP10, WP11 and WP13 change the other session's files, or lines next to theirs, so they **stay uncommitted for you**: `VoiceDemo.tsx` (line 396 is theirs; `voice.css` waits with it), `Footer.tsx`, `sitemap.ts`, `LegalPage.tsx`, `src/content/legal/`, `legal.css` and `tests/legal.spec.ts`.

## Decisions

### These change this plan

#### WD1 · Remove the sample walkthrough, or keep a trimmed one?
The walkthrough (`#demo`) is a form with Task title, Date, Time, Priority and a note, then a pretend saved task you can tick. Removing a demo is your call.
- **WEB-6** (S3) it teaches a form, not the app; three of the four buttons land on it.
- **WEB-108** (S2) both demos show a review step the app doesn't have. The live demo's half is fixed with WEB-9 (WP8).
- Parts of WEB-4 (its menu item), WEB-12 (server messages that name it), WEB-16 (its fake microphone), WEB-18 (a static example without JavaScript) and WEB-114 (its September dates).

**Recommend:** remove it (review H).
- It copies the app's editor and list, which the site isn't meant to provide; its examples are dated September 2026; its green microphone does nothing.
- In its place, one static example inside the live demo's intro, with no inputs: the spoken "Tomorrow, call the dentist and buy bread." and its two task cards. It shows without JavaScript and whenever the live demo can't run.
- If you keep it (review F): no Priority field, dates relative to today, no "September 2026", no fake microphone, translated.

Until you answer, it stays as it is, in English on the Spanish and Catalan homes too.

#### WD2 · Publish the free plan and TaskFlow Pro on the site now?
Saying what's free is your call. Today the site says nothing about it; the FAQ only says launch pricing isn't announced.
- **WEB-104** (S3) free plan and Pro missing; the pricing answer is outdated.
- Parts of WEB-7 (a line after the demo) and WEB-11 (a strip where the "at a glance" bar was).

**Recommend:** yes, with no price, and without "100 MB" until that's final.
- On dev: 10 dictations a month without Pro (one dictation can hold several tasks), tasks by hand with no limit, and TaskFlow Pro, a monthly subscription, for unlimited dictation and file space.
- The new hero says "say it". Not saying there are 10 a month hides a limit the app shows as soon as they're used.
- Where: the FAQ answer, one line in the closing card and one after the demo, in three languages, with the reports' copy.

Until you answer, the FAQ keeps today's answer, which is still true.

#### WD3 · May the loop edit the legal documents you approved for 16 October?
Review L asked before touching them. All of them are the other session's untracked files, so every change stays uncommitted for your review either way.
- **WEB-113** (S2; merged WEB-201) the privacy policy is behind the app on five points: email-confirmation codes, the first name kept from Google, speech recognised on the phone, phone calendars stay on the phone, «Creada por».
- **WEB-202** (S2) the delete page explains what goes in database and provider terms.
- **WEB-203** (S2) the privacy page's first phone screen has no privacy facts; the H1s are slogans.
- **WEB-206** (S2) Catalan uses «Eliminar», «Elimina» and «Suprimeix» for one action; the app says «Suprimeix el compte».
- **WEB-209** (S2) engineering words: TTL, keyed hashes, endpoint, SDK, APK, staging, Test Store.
- **WEB-211** (S1) the legal notice: a placeholder-sounding line, a mislabelled button, the registry line in Catalan on every page.
- **WEB-212** (S1) internal links carry the "leaves the site" ↗; the support link opens email without saying so.
- **WEB-213** (S1) "Versión 2026-10-16" doesn't read as "in force since".
- Parts of WEB-207 (the demo's facts first in privacy §8), WEB-210 (also WD7) and WEB-109 (§8 quotes the demo's old "Create drafts" button).

**Recommend:** yes.
- The loop moves `company.version` to the day of the edit. Your review of the uncommitted change, before you commit it, is the new sign-off.
- A re-plan puts them into three packages: privacy, the delete page, terms and the legal notice.

Until then, WP7–WP8 rename the demo's button to "Done" while privacy §8 still says "Create drafts".

#### WD4 · Which app screen should the hero show, and the link preview with it?
Reviews H and F disagree. The new images have to come from the app, rendered by the main session as Flutter previews with chosen text; today's `App/build` renders hold test text.
- Part of **WEB-5** (S3; merged WEB-103): the hero image.
- Part of **WEB-302** (S3): an app screen in the preview image.

**Recommend:** the Calendar, with the hero card's example done: "Call the dentist" and "Buy bread" on tomorrow, under the week strip, with the one «Añadir tarea» button.
- One image per language and theme: 6 PNGs at 780 × 1688.
- It proves the H1, shows what the spoken sentence becomes, and shows the one button a newcomer has to find.
- Review H's alternative: the result sheet ("2 things to add", "Add 2 tasks"). Review F's: the Calendar with today's tasks, English only.

Until then, the hero keeps today's screenshot, with the old separate microphone button, three tabs and a moon switch.

#### WD5 · Which language does a first visit to the bare address get?
Today `/` is always English. This plan adds `/es/` and `/ca/`, with a language switch in the header, the phone menu and the footer.
- Part of **WEB-2** (S3; merged WEB-301).

**Recommend:** choose on `/` only, from the browser's language (Spanish → `/es/`, Catalan → `/ca/`), falling back to English.
- Never by IP address.
- Never redirect someone who picked a language in the switch: remember that choice in the browser, as the theme is, and list it in privacy §8 (with WD3).
- Shared links will mostly be the bare address, and on a phone the switch sits inside the menu.
- If you'd rather the site stored nothing more, keep `/` English.

#### WD6 · Keep "A little focus. A little flow." as the brand line in the footer?
After this plan it appears nowhere else: the hero, the link preview and the description drop it.
- Part of **WEB-304** (S2): the footer tagline.

**Recommend:** drop it (review G). It doesn't say what TaskFlow is, and in Spanish and Catalan it either stays English or loses its sound. Review H asked whether you want it as the brand. Until you answer, it stays, in English.

#### WD7 · Say "for Android phones" only, and remove the Apple mentions?
- **WEB-210** (S1) the legal pages mention Apple subscriptions and link to "Manage Apple subscriptions"; there's no iPhone app.

**Recommend:** yes.
- This plan already says "An app for Android phones", which is true today and doesn't rule out an iPhone version.
- Editing the legal pages also needs WD3.
- The app itself says "available in the Android and iOS app" (`App/lib/l10n/app_en.arb:1695`): fix that with `/ux`.

### For later: nothing in this plan waits on these

#### WD8 · How should the live demo compare with the free app?
The demo uses Gemini Flash-Lite on Vertex; the app's dictations use the free AI Studio model by default (UX-616 is open). The demo gives 3 tries a day per browser with no account, up to about 90 a month; the free app gives 10 dictations a month.

**Recommend:** keep the demo as it is for now. This plan labels its tries as the demo's and says nothing there is saved to the app. Once UX-616 settles the app's route, give the demo the same one, so it's never faster or more accurate than the app people install.

#### WD9 · A way to hear when TaskFlow launches?
**Recommend:** not yet; the site says "coming soon to Google Play" and offers the live demo.
- Once the package ID is final, use Google Play pre-registration: the same link, a 90-day window per country.
- A personal developer account created after 13 November 2023 first needs a closed test with 12 testers for 14 days.
- An email list would add a form, consent, stored addresses and a privacy update.

#### WD10 · A section on sharing with family?
With a real screenshot of a shared project («Creada por», the filter by person), in the space the appearance section frees.

**Recommend:** not now; subtract first. This plan rewrites the FAQ's sharing answer (WEB-107).

#### WD11 · The app links to neither the privacy policy nor the terms
Play's User Data policy asks for a privacy-policy link or text inside the app, and Terms §1 says the terms are available before an account is created, but sign-up shows none.

**Recommend:** a "Privacy" and a "Terms" link at sign-up and in the app's settings, opening the site's page in the app's language. It's an app change: run it through `/ux`.

#### WD12 · Two facts only you can give
- How long backups keep deleted data: the pages only promise "the provider's rolling window".
- Whether the app's dictations use a paid Gemini key or the free quota.

**Recommend:** give both when you can.
- With a number, both pages can say "Backups are deleted within N days", which Play asks for.
- With paid or EEA terms, privacy §4 can say Google doesn't use dictations to train its models.
- Both edits go with WD3.

#### WD13 · At release
- Publish the site only with, or after, the app and backend it describes? The site will describe in-app deletion, email codes, several tasks per dictation and voice commands: all on dev, none deployed. Testers' APK 1.0.5 and staging predate them.
- Which deletion URL goes into Play Console?

**Recommend:**
- Publish them together.
- For Play Console, `/delete-account/` (review G), whose first control is the language switch; review L suggested `/es/delete-account/`.
- Decide the URL with the package ID.

### Already open in the app's decisions
No new question here. The legal pages keep today's wording on each of these until you decide:
- the clean-up of completed tasks;
- deleting the RevenueCat customer;
- free dictations after deleting and re-creating an account;
- the package ID (`com.example.agenda`), which blocks any Play link or badge;
- analytics.

## Packages, in run order
Severity 4 first, then 3, then 2; a package's prerequisites run before it, even when they're less severe. Sizes: S, M, L. Each line: finding (severity) problem → fix.

### WP1 · Subtract: the appearance section and unused screenshots go; the live demo moves up · H · M · commits
- **WEB-17** (S2; merged WEB-112) a whole section sells the website's dark mode → it goes, with its "mood" button, CSS and tilted screenshot.
- **WEB-5** (S3; merged WEB-103) the screenshots show the old app → the unused `calendar-*` and `tasks-*` are deleted; the hero image waits on WD4.
- **WEB-10** (S2) the live demo sits 4½ phone screens below the hero → it moves right under the hero.

### WP2 · Spanish and Catalan homes at /es/ and /ca/, and the page's language in the HTML · G · M · commits · after WP1
- **WEB-2** (S3; merged WEB-301) the home exists only in English → `/es/` and `/ca/`, built from one copy table per language; each section gets its words in its own package. The bare `/` waits on WD5.
- **WEB-304** (S2) every page says `lang="en"` and the skip link is English → the page's language is set before the first paint and on the content; the skip link is translated.

### WP3 · Hero and closing card: what TaskFlow is, that it isn't out yet, one button to the live demo · H · L · commits · after WP2
- **WEB-1** (S4) the hero never says what TaskFlow is → H1 "Say it, and it's on your calendar." and a subheadline that names one button, several things at once, reminders and Android. The decorative slogans go.
- **WEB-3** (S3; merged WEB-102, WEB-303) nothing near a button says the app isn't out → "Coming soon to Google Play. You can't download it yet." under the hero button; the closing card becomes "Coming soon to Android."
- **WEB-4** (S3; merged WEB-305) every button loops back to the sample form → one label, "Try it with your voice", one destination, the live demo.
- **WEB-11** (S2) the "at a glance" bar is slogans at 7–8 px → removed.
- **WEB-19** (S1) decorative hero text is read aloud → hidden from screen readers; no labels on plain divs.
- **WEB-308** (S2) keyboard focus vanishes on the closing card in light mode → a pale ring at 7.57:1.

### WP4 · Features: headings and cards say what TaskFlow does, truthfully · F · M · commits · after WP2
- **WEB-101** (S4) the cards say signing in is optional → bodies that say files and tasks are kept in your account.
- **WEB-105** (S3) several tasks in one dictation is never told → the voice card shows the app's own example becoming one task each.
- **WEB-106** (S2) reminders are never told → the calendar card says TaskFlow asks once, at the first dated task.
- **WEB-111** (S2) headings are mood lines → "Say it. See it on your calendar. Get reminded." and plain card headings.
- **WEB-114** (S1) the drawing says "September 2026" → no month or year; the walkthrough's dates wait on WD1.
- **WEB-16** (S2) a 75 px microphone circle looks tappable and does nothing → the drawing goes.

### WP5 · FAQ: answers match today's app, in the app's words · F · M · commits · after WP2
- **WEB-101** (S4) "You can create tasks… without an account" → "Yes. You sign in once: with Google in one tap, or with your email and a 6-digit code…".
- **WEB-3** (S3) the download answer hints at other platforms and old screens → "Not yet. TaskFlow is an app for Android phones, coming soon to Google Play…".
- **WEB-105** (S3) the voice answer misses several tasks and voice changes → "How do I add tasks by voice?" with Add a task, Done, one tap, and Undo.
- **WEB-107** (S2) the sharing answer says "lists" and describes the old invitation → "Can I share tasks with my family?" with projects, Share, «Creada por» and the person filter.
- **WEB-110** (S2) the notes answer describes a Task/Note choice the app removed → the Notes tab and Add a note.
- **WEB-109** (S2) the site names features differently from the app → the offline answer in the app's words, and a check across the page. The pricing answer waits on WD2.

### WP6 · Header: honest labels, a language switch, a worded phone menu · G · L · commits · after WP2
- **WEB-4** (S3) the filled "Explore the app ↗" opens the sample form → removed; one label per destination, in page order.
- **WEB-3** (S3) the menu's "Get TaskFlow" promises a download → "Coming soon to Android".
- **WEB-2** (S3) no page but the legal ones offers another language → "English · Español · Català" in the header and the menu, keeping the page.
- **WEB-304** (S2) the header is English on Spanish and Catalan pages → translated, with the language prefix on every link.
- **WEB-307** (S2) on phones, two unlabelled icon circles → a "Menu" button with a word; the theme switch moves into the menu; 48 px targets.
- **WEB-310** (S2) at 200% text the header scrolls sideways → it fits at 320 px.

### WP7 · Live demo, capture: one tap to talk, Done sends, clear waits and errors · H · L · **stays uncommitted** · after WP1, WP2
- **WEB-9** (S2) twice the app's taps, different words → one tap to talk, "Done" stops and sends, the app's words; no listen-back; the security box shows only when needed.
- **WEB-16** (S2) the real microphone is the palest of four → a solid green "Tap to talk" button.
- **WEB-13** (S2) waiting has no update and no way out → at 10 s, a new line and "Stop waiting"; the timeout goes from 55 s to 40 s.
- **WEB-14** (S2) microphone errors are raw English or dead ends → plain steps in three languages, and the text box opens.
- **WEB-15** (S2) the timer is announced every second → three announcements only.
- **WEB-18** (S1) without JavaScript the button does nothing → disabled, with a line saying why.

### WP8 · Live demo, words and result: plain words, the app's result, an honest hand-over · H · L · **stays uncommitted** · after WP7
- **WEB-7** (S3) the demo ends in a toy list → it ends at the result, then "In the app: tap Add a task, say it and tap Done… Coming soon to Google Play." The free-plan line waits on WD2.
- **WEB-12** (S2) jargon (allowance, rolling 24 hours, drafts) → "Try it with your voice", "3 tries a day · no sign-up", plain fine print.
- **WEB-9** (S2) the result doesn't look or talk like the app's → "2 things to add", the date line, "Say it again", "See what I said".
- **WEB-2** (S3) the demo is English and dates follow the browser → every string, error and date in the page's language.
- **WEB-207** (S2) "How we use your data" opens the app's section → it opens the demo's section; §8's new first sentence waits on WD3.

### WP9 · Titles, link previews and the 404 say what TaskFlow is; a lighter first load · G · M · commits · after WP2, WP3
- **WEB-302** (S3) the WhatsApp preview is a slogan → "TaskFlow — say it, and it's on your calendar", the app's own pitch, and a preview image per language. An app screen in it waits on WD4.
- **WEB-306** (S2) the 404 is an English pun → "Page not found" in three languages, with links home and to account deletion.
- **WEB-311** (S1) the first visit loads a 165 KB font and both screenshots → `next/font` and one image.
- **WEB-313** (S1) dark visitors get a light toolbar and a greyed-out switch → two theme colours; the switch is hidden until it works.

### WP10 · Footer in the page's language · G · M · **stays uncommitted** · after WP2, WP6
- **WEB-304** (S2) the footer is English everywhere and its legal links open English pages → translated; links keep the language («Suprimeix el compte» in Catalan).
- **WEB-2** (S3) no language switch in the footer → the same switch as the header.
- **WEB-4** (S3) "Try the demo" is a fifth name for one place → the header's labels. "Made for a little more headspace." goes; the tagline waits on WD6.

### WP11 · Legal pages and the sitemap keep the visitor's language; legal previews · G · S · **stays uncommitted** · after WP2, WP9
- **WEB-2** (S3) «Volver a TaskFlow» leads to the English home; the sitemap lists only `/` → the page's own home; `/es/` and `/ca/` in the sitemap.
- **WEB-312** (S1) legal pages share without an image, with English X tags → the language's preview image and the document's own titles.

### WP12 · Type you can read: 16 px body in rem, nothing under 12 px · H · M · commits (`voice.css` waits with VoiceDemo) · after WP3–WP8, WP10
- **WEB-8** (S3) text in the hero, demos and closing card goes down to 5 px → body 16 px, subheadline 18 px on phones, nothing under 12 px.
- **WEB-309** (S2) the frame's small print is 8–11 px, in px → rem, so a browser's text-size setting works.

### WP13 · Legal pages: the in-app route first, readable text, a clear language state · L · M · **stays uncommitted**
- **WEB-204** (S2) the instant in-app route looks like small print → "With the app: Settings → Account → Delete account. You'll see what goes before you confirm." in ink at 16 px; "No app, or can't sign in? Email us:" above the button.
- **WEB-205** (S2) legal text is grey 14 px in 130-character lines → 16 px, 68 characters wide, 44 px rows.
- **WEB-208** (S2) the current language is shown by colour only, and the switch can't wrap → a ring, wrapping, breakable H1s.

## How the reports were settled
Say if any of these is wrong; only the package named changes.
- **The button label** is review H's and G's "Try it with your voice" (WP3), not review F's "Try the live demo": the live demo's own start button goes in WP7.
- **The menu item** is "Coming soon to Android" (WP6). That's review G's wording, matching the closing card's heading; review H proposed "Download: coming soon" and review F "How to get TaskFlow".
- **The demo's send button** is the app's "Done" (review H, WP7), not review F's "Make tasks". Its tries are «intentos» / «intents», not «pruebas».
- **Nav order** follows the page once the demo moves up: Try it with your voice, What it does, See an example, Questions (WP6). The hero's secondary link is "What it does" too, so each place has one name.
- **The demo's hand-over line** (WP8) names Done and not "Add to calendar", because the app's last button is «Añadir 2 tareas» when there are several tasks.
- **`<html lang>`** is set before the first paint, and the content, header and footer carry their language in the HTML (WP2). A root layout per language would mean moving the other session's untracked legal pages, which the loop won't do.
- **Removals the organizer added** (strike them if you want any kept):
  - the remaining section eyebrows on the home ("01 / FIND YOUR EVERYDAY FLOW", "04 / A FEW GOOD QUESTIONS", "YOUR WORDS. YOUR NEXT STEP.");
  - the FAQ's intro line and its "Less guesswork. More clarity." doodle;
  - the hero card's "JUST SAY THE WORD" label.
- **Copy the reports didn't give** (labels, error lines, translations of strings nobody rewrote) is the organizer's. Each brief marks it, and its Catalan wants a native read.

## Skipped
- **WEB-102, WEB-303** → duplicates of WEB-3 (WP3, WP5, WP6).
- **WEB-103** → duplicate of WEB-5 (WP1; WD4).
- **WEB-112** → duplicate of WEB-17 (WP1).
- **WEB-201** → duplicate of WEB-113 (WD3).
- **WEB-301** → duplicate of WEB-2 (WP2, WP6, WP8, WP10, WP11).
- **WEB-305** → duplicate of WEB-4 (WP3, WP6, WP10).

## For the main session
- **WD4 needs app renders**: once the owner picks the screen, make them with the app's preview tests (English, Spanish and Catalan; light and dark; chosen text, not test text) before the package that swaps the hero image.
- **Stale records**: the delegation, the Open list of `.claude/ux-review/DECISIONS.md` ("Also for later") and `Backend/docs/ACCOUNT_DELETION.md:66` say the website's delete page has no in-app option. Reviews F and L found the page already describes in-app deletion correctly in all three languages (version 2026-10-16). The loop doesn't edit either file.
- **Committing**:
  - `VoiceDemo.tsx` can't be separated from the other session's line 396, so hold `voice.css` with it, keeping the committed demo and its styles in step.
  - `layout.tsx` stays committable as long as packages keep off lines 5–11, as their briefs say.
