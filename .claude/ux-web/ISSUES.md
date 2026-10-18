# UX web issues

The UX web loop maintains this file (`/ux-web`). There is one line per issue, and the line moves to the section for its current status.

- **Line format:** ID · severity (S1–S4) · area · status · title · main `path:line` · the run that last changed it, then a short note.
- **Paths:** website paths are relative to the TaskFlowWeb root; app-repo paths start with `App/`, `Backend/` or `.claude/`.
- **Areas:**
  - H — home and hero, the value proposition, demos and calls to action;
  - F — features and faithfulness to the app, the funnel to download and Pro, pricing;
  - L — legal, privacy, terms, delete-account and trust;
  - G — global: navigation, header and footer, language switching, performance, accessibility, SEO and meta, light and dark.
- **Notes:** WP# and WD# are the packages and decisions in that run's `plan.md`. "Merged" lists the duplicates folded into a line.

## Open
- **WEB-1** · S4 · H · open · The hero never says what TaskFlow is · `src/app/page.tsx:46` · 2026-10-18-site · WP3. New H1 and subheadline in EN/ES/CA; the slogans go
- **WEB-2** · S3 · H · open · Home and demos only in English, with no language switch · `src/app/page.tsx:38` · 2026-10-18-site · WP2 (routes, lang), WP6 (header switch), WP8 (demo), WP10 (footer) and WP11 (legal back link, sitemap); WP8, WP10 and WP11 stay uncommitted. Merged WEB-301. The bare `/` waits on WD5; the walkthrough stays English until WD1
- **WEB-3** · S3 · H · open · Nothing near a button says the app isn't out · `src/app/page.tsx:422` · 2026-10-18-site · WP3 (hero line, closing card), WP5 (FAQ), WP6 (menu item). Merged WEB-102, WEB-303
- **WEB-4** · S3 · H · open · Every call to action loops back to a sample form · `src/components/Header.tsx:48` · 2026-10-18-site · WP3 (hero, closing), WP6 (header), WP10 (footer, uncommitted); the landing fix is in WP7. Merged WEB-305. The `#demo` item waits on WD1
- **WEB-5** · S3 · H · open · Hero and appearance screenshots show the old app · `src/components/Phone.tsx:24` · 2026-10-18-site · WP1 deletes `calendar-*` and `tasks-*`; the hero image waits on WD4 and on new app renders from the main session. Merged WEB-103
- **WEB-7** · S3 · H · open · The live demo ends in a toy list · `src/components/VoiceDemo.tsx:606` · 2026-10-18-site · WP8; stays uncommitted (VoiceDemo.tsx holds the other session's line 396). The free-plan line waits on WD2
- **WEB-8** · S3 · H · open · Text in hero, demos and closing card is tiny · `src/styles/global.css:59` · 2026-10-18-site · WP12. Device: a real phone at arm's length
- **WEB-9** · S2 · H · open · Live demo: twice the app's taps, different words · `src/components/VoiceDemo.tsx:483` · 2026-10-18-site · WP7 (capture), WP8 (result); stays uncommitted. Turnstile's look needs a browser check
- **WEB-10** · S2 · H · open · The proof sits 4½ phone screens below the hero · `src/app/page.tsx:286` · 2026-10-18-site · WP1
- **WEB-11** · S2 · H · open · The “at a glance” bar says nothing concrete · `src/app/page.tsx:129` · 2026-10-18-site · WP3 removes it; a free-plan strip in its place waits on WD2
- **WEB-12** · S2 · H · open · Demo copy uses jargon a newcomer can't parse · `src/components/VoiceDemo.tsx:371` · 2026-10-18-site · WP8; stays uncommitted. The server messages that name the walkthrough wait on WD1
- **WEB-13** · S2 · H · open · Waiting for a result: no update, no way out · `src/components/VoiceDemo.tsx:447` · 2026-10-18-site · WP7; stays uncommitted. Real wait times weren't measured
- **WEB-14** · S2 · H · open · Microphone errors are raw English or dead ends · `src/components/VoiceDemo.tsx:254` · 2026-10-18-site · WP7; stays uncommitted. Device: deny the prompt in Chrome on Android
- **WEB-15** · S2 · H · open · The recording timer is announced every second · `src/components/VoiceDemo.tsx:532` · 2026-10-18-site · WP7; stays uncommitted. Device: TalkBack while recording
- **WEB-16** · S2 · H · open · Four microphones look tappable; three do nothing · `src/components/VoiceDemo.tsx:382` · 2026-10-18-site · WP7 (the real button; uncommitted), WP4 (the features drawing goes). The walkthrough's microphone waits on WD1
- **WEB-17** · S2 · H · open · A whole section sells the website's dark mode · `src/app/page.tsx:320` · 2026-10-18-site · WP1. Merged WEB-112
- **WEB-18** · S1 · H · open · Without JavaScript, the live demo's button does nothing · `src/components/VoiceDemo.tsx:390` · 2026-10-18-site · WP7; stays uncommitted. A static example waits on WD1
- **WEB-19** · S1 · H · open · Decorative hero text is read aloud; div labels ignored · `src/app/page.tsx:87` · 2026-10-18-site · WP3. Device: the hero with NVDA or TalkBack
- **WEB-101** · S4 · F · open · The site says TaskFlow works without an account · `src/app/page.tsx:20` · 2026-10-18-site · WP4 (cards), WP5 (FAQ)
- **WEB-105** · S3 · F · open · Several tasks in one dictation is never told · `src/app/page.tsx:232` · 2026-10-18-site · WP4 (voice card), WP5 (FAQ)
- **WEB-106** · S2 · F · open · Reminders, the core loop's third step, are never told · `src/app/page.tsx:174` · 2026-10-18-site · WP4
- **WEB-107** · S2 · F · open · Sharing FAQ says “lists” and describes the old invite · `src/app/page.tsx:24` · 2026-10-18-site · WP5
- **WEB-109** · S2 · F · open · The site names features differently from the app · `src/components/VoiceDemo.tsx:373` · 2026-10-18-site · WP5 (offline answer, page-wide check); the demo's rows with WEB-9 and WEB-12 (WP7, WP8), metadata with WEB-302 (WP9). Privacy §8 quoting “Create drafts” waits on WD3
- **WEB-110** · S2 · F · open · Notes FAQ describes a Task/Note choice the app removed · `src/app/page.tsx:28` · 2026-10-18-site · WP5
- **WEB-111** · S2 · F · open · Feature headings are mood lines; a scanner learns nothing · `src/app/page.tsx:154` · 2026-10-18-site · WP4
- **WEB-114** · S1 · F · open · Sample dates are a month old · `src/app/page.tsx:182` · 2026-10-18-site · WP4 (the drawing); the walkthrough's dates wait on WD1
- **WEB-204** · S2 · L · open · Delete page: the quicker in-app route looks like small print · `src/content/legal/index.ts:47` · 2026-10-18-site · WP13; stays uncommitted (the other session's untracked files)
- **WEB-205** · S2 · L · open · Legal text is small, in lines of ≈130 characters · `src/styles/legal.css:217` · 2026-10-18-site · WP13; stays uncommitted. The sidebar's focus clipping is inferred; browser check
- **WEB-207** · S2 · L · open · The demo's privacy link lands on the app's section · `src/components/VoiceDemo.tsx:396` · 2026-10-18-site · WP8 changes the link, the other session's line; stays uncommitted. Privacy §8's new first sentence waits on WD3
- **WEB-208** · S2 · L · open · Language switcher: state by colour only; overflows with large text · `src/styles/legal.css:12` · 2026-10-18-site · WP13; stays uncommitted. The overflow is inferred; device: Android at the largest font size
- **WEB-302** · S3 · G · open · The link preview doesn't say what TaskFlow is · `src/app/opengraph-image.tsx:71` · 2026-10-18-site · WP9. An app screen in the image waits on WD4. Device: WhatsApp after the owner deploys
- **WEB-304** · S2 · G · open · Spanish and Catalan pages keep an English frame · `src/app/layout.tsx:43` · 2026-10-18-site · WP2 (lang, skip link), WP6 (header), WP10 (footer; uncommitted). The footer tagline waits on WD6
- **WEB-306** · S2 · G · open · The 404 page is an English idiom hiding “not found” · `src/app/not-found.tsx:5` · 2026-10-18-site · WP9
- **WEB-307** · S2 · G · open · Phone header: two unlabelled icons; theme outranks the menu · `src/components/Header.tsx:51` · 2026-10-18-site · WP6. Forced colours inferred; browser check
- **WEB-308** · S2 · G · open · Keyboard focus vanishes on the closing card in light mode · `src/styles/global.css:99` · 2026-10-18-site · WP3
- **WEB-309** · S2 · G · open · The frame's small print is 8–11 px, fixed in px · `src/styles/global.css:121` · 2026-10-18-site · WP12; the footer's operator line in `legal.css` is WP10's (uncommitted)
- **WEB-310** · S2 · G · open · At 200% text, header and language switcher overflow on phones · `src/styles/global.css:262` · 2026-10-18-site · WP6 (header); the legal switcher's wrap is WEB-208's (WP13). Inferred from code; device check
- **WEB-311** · S1 · G · open · First view downloads a 165 KB font and both screenshots · `src/app/layout.tsx:45` · 2026-10-18-site · WP9. Impact inferred; a lab Lighthouse run
- **WEB-312** · S1 · G · open · Legal pages share without an image; X tags in English · `src/content/legal/index.ts:190` · 2026-10-18-site · WP11; stays uncommitted (the other session's untracked file)
- **WEB-313** · S1 · G · open · Dark first visit: a light toolbar and a greyed-out switch · `src/app/layout.tsx:36` · 2026-10-18-site · WP9. Device: a dark-mode phone on a slow network

## Decision needed
- **WEB-6** · S3 · H · decision · The sample walkthrough teaches a form, not the app · `src/app/page.tsx:287` · 2026-10-18-site · WD1: removing a demo is the owner's call. Recommendation: remove it, with a static example of the app's result in the live demo's intro
- **WEB-104** · S3 · F · decision · Free plan and Pro missing; pricing answer outdated · `src/app/page.tsx:32` · 2026-10-18-site · WD2: publishing what's free. Recommendation: yes, with no price and no “100 MB” until it's final
- **WEB-108** · S2 · F · decision · Both demos show a review step the app lacks · `src/components/TaskDemo.tsx:248` · 2026-10-18-site · WD1 (the walkthrough's form); its live-demo half (“Task N”, the priority chip) is fixed with WEB-9 (WP8)
- **WEB-113** · S2 · F · decision · Privacy policy is behind the app on five points · `src/content/legal/en.ts:29` · 2026-10-18-site · WD3: editing the legal text the owner approved for 16 October. Merged WEB-201. The other session's untracked files, so it would stay uncommitted
- **WEB-202** · S2 · L · decision · Delete page explains what goes in jargon · `src/content/legal/en.ts:373` · 2026-10-18-site · WD3
- **WEB-203** · S2 · L · decision · The privacy page's first screen has no privacy facts · `src/components/LegalPage.tsx:128` · 2026-10-18-site · WD3
- **WEB-206** · S2 · L · decision · Catalan pages use three verbs; the app says «Suprimeix» · `src/content/legal/index.ts:156` · 2026-10-18-site · WD3
- **WEB-209** · S2 · L · decision · Privacy, terms and legal notice use engineering words · `src/content/legal/en.ts:140` · 2026-10-18-site · WD3
- **WEB-210** · S1 · L · decision · Apple subscriptions mentioned on an Android-only product · `src/content/legal/en.ts:248` · 2026-10-18-site · WD7 (platforms), and WD3 for the edit
- **WEB-211** · S1 · L · decision · Legal notice: placeholder line, mislabelled button, Catalan-only registry · `src/content/legal/en.ts:311` · 2026-10-18-site · WD3; the registry line's translation needs the owner's confirmation
- **WEB-212** · S1 · L · decision · Internal links carry the “leaves the site” arrow · `src/components/LegalPage.tsx:139` · 2026-10-18-site · WD3
- **WEB-213** · S1 · L · decision · “Versión 2026-10-16” doesn't read as “in force since” · `src/content/legal/index.ts:35` · 2026-10-18-site · WD3

## Escalated

## Device check

## Verified

## Won't fix
- **WEB-102** · S3 · F · wontfix · “Get TaskFlow” loops back; “not yet” hides at the bottom · `src/components/Header.tsx:62` · 2026-10-18-site · duplicate, merged into WEB-3 (WP3, WP5, WP6)
- **WEB-103** · S3 · F · wontfix · App screenshots show a TaskFlow that no longer exists · `src/components/Phone.tsx:24` · 2026-10-18-site · duplicate, merged into WEB-5 (WP1; WD4)
- **WEB-112** · S2 · F · wontfix · A whole section sells the theme switch · `src/app/page.tsx:320` · 2026-10-18-site · duplicate, merged into WEB-17 (WP1)
- **WEB-201** · S2 · L · wontfix · Privacy policy is behind the app on five points · `src/content/legal/en.ts:21` · 2026-10-18-site · duplicate, merged into WEB-113 (WD3)
- **WEB-301** · S3 · G · wontfix · No Spanish or Catalan home, and no way to switch · `src/components/Header.tsx:28` · 2026-10-18-site · duplicate, merged into WEB-2 (WP2, WP6, WP8, WP10, WP11)
- **WEB-303** · S3 · G · wontfix · “Get TaskFlow” promises a download that doesn't exist · `src/components/Header.tsx:63` · 2026-10-18-site · duplicate, merged into WEB-3 (WP6)
- **WEB-305** · S2 · G · wontfix · The header button misnames the demo; one place, five names · `src/components/Header.tsx:48` · 2026-10-18-site · duplicate, merged into WEB-4 (WP3, WP6, WP10)
