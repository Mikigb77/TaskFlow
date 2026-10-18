# UX web issues

The UX web loop maintains this file (`/ux-web`). There is one line per issue, and the line moves to the section for its current status.

- **Line format:** ID · severity (S1–S4) · area · status · title · main `path:line` · the run that last changed it, then a short note.
- **Paths:** website paths are relative to the TaskFlowWeb root; app-repo paths start with `App/`, `Backend/` or `.claude/`.
- **Areas:**
  - H — home and hero, the value proposition, demos and calls to action;
  - F — features and faithfulness to the app, the funnel to download and Pro, pricing;
  - L — legal, privacy, terms, delete-account and trust;
  - G — global: navigation, header and footer, language switching, performance, accessibility, SEO and meta, light and dark.
- **Notes:** WP# and WD# are the packages and decisions in that run's `plan.md`. "Merged" lists the duplicates folded into a line. "Held" means the fix changes the other session's files, so it stays uncommitted for the owner. Run 2026-10-18-site's packages are WP14–WP32 (the recheck plan); its first plan's WP1–WP13 are history in `plan-first.md`.

## Open
- **WEB-1** · S4 · H · open · The hero never says what TaskFlow is · `src/app/page.tsx:46` · 2026-10-18-site · WP16. Device: a screen reader on the hero
- **WEB-2** · S3 · H · open · Home and demos only in English, with no language switch · `src/app/page.tsx:38` · 2026-10-18-site · WP15 (routes; bare `/` per WD5), WP20 (header switch), WP22 (`<html lang>`; held), WP23 (footer; held), WP24 (legal back link, sitemap; held), WP28 and WP29 (demo dates and strings; held). Merged WEB-301
- **WEB-3** · S3 · H · open · Nothing near a button says the app isn't out · `src/app/page.tsx:422` · 2026-10-18-site · WP16 (hero line), WP18 (closing card, download answer), WP20 (menu row). Merged WEB-102, WEB-303
- **WEB-4** · S3 · H · open · Every call to action loops back to a sample form · `src/components/Header.tsx:48` · 2026-10-18-site · WP16, WP17, WP18, WP20, WP23 (footer; held), WP26 (the landing; held). Merged WEB-305
- **WEB-5** · S3 · H · open · Hero and appearance screenshots show the old app · `src/components/Phone.tsx:24` · 2026-10-18-site · WP16: WD4's `hero-calendar-<language>-<theme>.png`, upright and legible; WP14 removes the appearance screenshot. Merged WEB-103
- **WEB-6** · S3 · H · open · The sample walkthrough teaches a form, not the app · `src/app/page.tsx:287` · 2026-10-18-site · WD1 decided removal: WP14 removes it; WP26 adds the static example (held)
- **WEB-7** · S3 · H · open · The live demo ends in a toy list · `src/components/VoiceDemo.tsx:606` · 2026-10-18-site · WP28; held (VoiceDemo.tsx holds the other session's line 396)
- **WEB-8** · S3 · H · open · Text in hero, demos and closing card is tiny · `src/styles/global.css:59` · 2026-10-18-site · Measured: 39% of characters under 12 px; none grow with text size. WP25 (global.css), WP29 (voice.css; held). Device: a real phone at arm's length
- **WEB-9** · S2 · H · open · Live demo: twice the app's taps, different words · `src/components/VoiceDemo.tsx:483` · 2026-10-18-site · WP27 (capture), WP28 (result); held. Turnstile's real look needs the deployed site
- **WEB-10** · S2 · H · open · The live demo sits 5.4 phone screens below the hero · `src/app/page.tsx:286` · 2026-10-18-site · WP14
- **WEB-11** · S2 · H · open · The “at a glance” bar says nothing concrete · `src/app/page.tsx:129` · 2026-10-18-site · WP14 removes it (WD2 puts the free plan elsewhere)
- **WEB-12** · S2 · H · open · Demo copy uses jargon a newcomer can't parse · `src/components/VoiceDemo.tsx:371` · 2026-10-18-site · WP26 (intro, badge, fine print), WP28 (no tasks), WP29 (messages by code); held
- **WEB-13** · S2 · H · open · Waiting for a result: no update, no way out · `src/components/VoiceDemo.tsx:447` · 2026-10-18-site · WP29; held. Real wait times unmeasured
- **WEB-14** · S2 · H · open · Microphone errors are raw English or dead ends · `src/components/VoiceDemo.tsx:254` · 2026-10-18-site · WP27; held. Device: deny the prompt on Android Chrome and iPhone Safari
- **WEB-15** · S2 · H · open · The recording timer is announced every second · `src/components/VoiceDemo.tsx:532` · 2026-10-18-site · WP27; held. Device: TalkBack while recording
- **WEB-16** · S2 · H · open · Four microphones look tappable; three do nothing · `src/components/VoiceDemo.tsx:382` · 2026-10-18-site · WP14 (features drawing, walkthrough), WP26 (intro orb; held), WP27 (the real button; held)
- **WEB-17** · S2 · H · open · A whole section sells the website's dark mode · `src/app/page.tsx:320` · 2026-10-18-site · WP14. Merged WEB-112
- **WEB-18** · S1 · H · open · Without JavaScript, the live demo's button does nothing · `src/components/VoiceDemo.tsx:390` · 2026-10-18-site · WP26; held
- **WEB-19** · S1 · H · open · Decorative hero text is read aloud; div labels ignored · `src/app/page.tsx:87` · 2026-10-18-site · WP16. Device: a screen reader on the hero
- **WEB-101** · S4 · F · open · The site says TaskFlow works without an account · `src/app/page.tsx:20` · 2026-10-18-site · WP17 (cards), WP18 (FAQ)
- **WEB-104** · S3 · F · open · Free plan and Pro missing; pricing answer outdated · `src/app/page.tsx:32` · 2026-10-18-site · WD2 decided: WP18 (FAQ, closing line), WP28 (under the demo; held). The FAQ's safety-limit clause waits on WD14
- **WEB-105** · S3 · F · open · Several tasks in one dictation is never told · `src/app/page.tsx:232` · 2026-10-18-site · WP17 (voice card), WP19 (FAQ)
- **WEB-106** · S2 · F · open · Reminders, the core loop's third step, are never told · `src/app/page.tsx:174` · 2026-10-18-site · WP17
- **WEB-107** · S2 · F · open · Sharing FAQ says “lists” and describes the old invite · `src/app/page.tsx:24` · 2026-10-18-site · WP19
- **WEB-108** · S2 · F · open · Both demos show a review step the app lacks · `src/components/TaskDemo.tsx:248` · 2026-10-18-site · WD1 decided: WP14's removal settles the walkthrough's half; WP28 the live demo's (held)
- **WEB-109** · S2 · F · open · The site names features differently from the app · `src/components/VoiceDemo.tsx:373` · 2026-10-18-site · WP19 (offline answer, home check), WP31 (terms, privacy §8; held); the demo's words with WEB-9 and WEB-12
- **WEB-110** · S2 · F · open · Notes FAQ describes a Task/Note choice the app removed · `src/app/page.tsx:28` · 2026-10-18-site · WP19
- **WEB-111** · S2 · F · open · Feature headings are mood lines; a scanner learns nothing · `src/app/page.tsx:154` · 2026-10-18-site · WP17 (features), WP19 (FAQ heading)
- **WEB-113** · S2 · F · open · Privacy policy is behind the app on six points · `src/content/legal/en.ts:29` · 2026-10-18-site · WD3 decided: WP31; held (the other session's untracked files). Merged WEB-201
- **WEB-114** · S1 · F · open · Sample dates are a month old · `src/app/page.tsx:182` · 2026-10-18-site · WP14 (the drawing; the walkthrough's dates go with it). WD4's images show their render date: re-render before publishing
- **WEB-202** · S2 · L · open · Delete page explains what goes in jargon · `src/content/legal/en.ts:373` · 2026-10-18-site · WD3 decided: WP32; held
- **WEB-203** · S2 · L · open · The privacy page's first screen has no privacy facts · `src/components/LegalPage.tsx:128` · 2026-10-18-site · WD3 decided: WP30; held
- **WEB-204** · S2 · L · open · Delete page: the quicker in-app route looks like small print · `src/content/legal/index.ts:47` · 2026-10-18-site · WP32; held
- **WEB-205** · S2 · L · open · Legal text: 14 px grey, ≈140-character lines, doesn't grow · `src/styles/legal.css:217` · 2026-10-18-site · WP30; held. Focus clipping now measured. Device: Android Chrome's text-size setting
- **WEB-206** · S2 · L · open · Catalan pages use three verbs; the app says «Suprimeix» · `src/content/legal/index.ts:156` · 2026-10-18-site · WD3 decided: WP32; held. Catalan wants a native read
- **WEB-207** · S2 · L · open · The demo's privacy link lands on the app's section · `src/components/VoiceDemo.tsx:396` · 2026-10-18-site · WP26 (the link, the other session's line), WP31 (§8's first sentence); held
- **WEB-208** · S1 · L · open · Language switch: the current language shown by colour only · `src/styles/legal.css:24` · 2026-10-18-site · WP24; held. Was S2: review L withdrew the overflow half (measured, nothing scrolls sideways at 320 px, 200% zoom or doubled text, AUDIT §3); WEB-205's wrap rules carry it
- **WEB-209** · S2 · L · open · Privacy, terms and legal notice use engineering words · `src/content/legal/en.ts:140` · 2026-10-18-site · WD3 decided: WP31; held
- **WEB-210** · S1 · L · open · Apple subscriptions mentioned on an Android-only product · `src/content/legal/en.ts:248` · 2026-10-18-site · WD7 and WD3 decided: WP31 (privacy, terms), WP32 (delete page); held
- **WEB-211** · S1 · L · open · Legal notice: placeholder line, mislabelled button, Catalan-only registry · `src/content/legal/en.ts:311` · 2026-10-18-site · WD3 decided: WP30; held. The owner confirms the registry translation when he signs off
- **WEB-212** · S1 · L · open · Internal links carry the “leaves the site” arrow · `src/components/LegalPage.tsx:139` · 2026-10-18-site · WD3 decided: WP30; held
- **WEB-213** · S1 · L · open · “Versión 2026-10-16” doesn't read as “in force since” · `src/content/legal/index.ts:35` · 2026-10-18-site · WD3 decided: WP30; held
- **WEB-302** · S3 · G · open · The link preview doesn't say what TaskFlow is · `src/app/opengraph-image.tsx:71` · 2026-10-18-site · WP21 (titles, previews per language with WD4's image), WP22 (layout defaults; held). Device: WhatsApp after a deploy
- **WEB-304** · S2 · G · open · Spanish and Catalan pages keep an English frame · `src/app/layout.tsx:43` · 2026-10-18-site · WP20 (header), WP22 (`<html lang>`, skip link; held), WP23 (footer; held). Device: TalkBack on a Spanish title
- **WEB-306** · S2 · G · open · The 404 page is an English idiom hiding “not found” · `src/app/not-found.tsx:5` · 2026-10-18-site · WP21
- **WEB-307** · S2 · G · open · Phone header: two unlabelled icons; theme outranks the menu · `src/components/Header.tsx:51` · 2026-10-18-site · WP20. Forced colours checked by emulation
- **WEB-308** · S2 · G · open · Keyboard focus vanishes on the closing card in light mode · `src/styles/global.css:99` · 2026-10-18-site · WP18. Measured 1.58:1
- **WEB-309** · S2 · G · open · The frame's small print is 8–11 px, fixed in px · `src/styles/global.css:121` · 2026-10-18-site · WP25 (global.css), WP23 (the operator line in legal.css; held). Carries withdrawn WEB-310's check. Device: Android at its largest font size
- **WEB-311** · S1 · G · open · First view fetches both theme screenshots and a TTF font · `src/app/layout.tsx:45` · 2026-10-18-site · WP16 (one hero image), WP22 (the font; held). Corrected by review G: 68 KB over the wire, CLS 0
- **WEB-312** · S1 · G · open · Legal pages share without an image; X tags in English · `src/content/legal/index.ts:190` · 2026-10-18-site · WP30; held
- **WEB-313** · S1 · G · open · Dark first visit: a light toolbar and a greyed-out switch · `src/app/layout.tsx:36` · 2026-10-18-site · WP22 (two theme colours; held), WP25 (dark without JavaScript; the switch hidden until it works). Device: a dark-mode phone on a slow network
- **WEB-401** · S2 · H · open · Connection failures show raw developer text · `src/components/VoiceDemo.tsx:153` · 2026-10-18-site · WP29; held
- **WEB-402** · S2 · H · open · The demo's text box has no visible edge · `src/styles/voice.css:278` · 2026-10-18-site · WP27; held
- **WEB-403** · S2 · H · open · Security check: a disabled button, no reason, no retry · `src/components/VoiceDemo.tsx:36` · 2026-10-18-site · WP29; held. Device: the deployed site with a content blocker
- **WEB-501** · S2 · F · open · Privacy and delete pages say RevenueCat's record stays · `src/content/legal/en.ts:375` · 2026-10-18-site · WP31 (privacy §7), WP32 (delete §3); held. Merged WEB-601
- **WEB-502** · S2 · F · open · The demo turns typed sentences into tasks; that's Pro · `src/components/VoiceDemo.tsx:494` · 2026-10-18-site · WP27; held
- **WEB-503** · S1 · F · open · Opening one FAQ answer closes the one you read · `src/app/page.tsx:386` · 2026-10-18-site · WP18. Device: Safari on an iPhone
- **WEB-504** · S2 · F · open · Comparers never learn their phone calendar comes along · `src/app/page.tsx:172` · 2026-10-18-site · WP17
- **WEB-602** · S2 · L · open · Privacy §8 will describe a site this run removes · `src/content/legal/en.ts:139` · 2026-10-18-site · WP31, after WP14, WP20 and WP27; held
- **WEB-702** · S1 · G · open · Taps on frame links give no visible feedback · `src/styles/global.css:67` · 2026-10-18-site · WP25. Device: a throttled Android phone
- **WEB-703** · S1 · G · open · Logo, footer links and “Back to top” under 44 px · `src/components/Footer.tsx:43` · 2026-10-18-site · WP25 (logos), WP23 (footer; held)
- **WEB-704** · S1 · G · open · No Android trademark line where the site names Android · `src/components/Footer.tsx:17` · 2026-10-18-site · WP23 (the line; held); the ™ comes with WEB-1's hero copy (WP16). Google's brand approval is the owner's, at launch

## Decision needed
- **WEB-701** · S2 · G · decision · WebKit draws every weight at Manrope's thinnest · `src/styles/global.css:3` · 2026-10-18-site · WD15: only Safari on the owner's iPhone can tell; probably a Windows-WebKit artifact. The main session can't answer it

## Escalated

## Device check

## Verified

## Won't fix
- **WEB-102** · S3 · F · wontfix · “Get TaskFlow” loops back; “not yet” hides at the bottom · `src/components/Header.tsx:62` · 2026-10-18-site · duplicate, merged into WEB-3 (WP16, WP18, WP20)
- **WEB-103** · S3 · F · wontfix · App screenshots show a TaskFlow that no longer exists · `src/components/Phone.tsx:24` · 2026-10-18-site · duplicate, merged into WEB-5 (WP16)
- **WEB-112** · S2 · F · wontfix · A whole section sells the theme switch · `src/app/page.tsx:320` · 2026-10-18-site · duplicate, merged into WEB-17 (WP14)
- **WEB-201** · S2 · L · wontfix · Privacy policy is behind the app on five points · `src/content/legal/en.ts:21` · 2026-10-18-site · duplicate, merged into WEB-113 (WP31)
- **WEB-301** · S3 · G · wontfix · No Spanish or Catalan home, and no way to switch · `src/components/Header.tsx:28` · 2026-10-18-site · duplicate, merged into WEB-2 (WP15, WP20, WP22–WP24, WP28, WP29)
- **WEB-303** · S3 · G · wontfix · “Get TaskFlow” promises a download that doesn't exist · `src/components/Header.tsx:63` · 2026-10-18-site · duplicate, merged into WEB-3 (WP20)
- **WEB-305** · S2 · G · wontfix · The header button misnames the demo; one place, five names · `src/components/Header.tsx:48` · 2026-10-18-site · duplicate, merged into WEB-4 (WP16–WP18, WP20, WP23, WP26)
- **WEB-310** · S2 · G · wontfix · At 200% text, header and language switcher overflow on phones · `src/styles/global.css:262` · 2026-10-18-site · withdrawn by review G: measured, nothing scrolls sideways or clips at 320 px, 200% zoom or doubled text (AUDIT §3), because no text grows yet; its check moves into WEB-309 (WP25)
- **WEB-601** · S2 · L · wontfix · Site says RevenueCat keeps your record; the server deletes it · `src/content/legal/en.ts:375` · 2026-10-18-site · duplicate: reviews F and L found the same sentence; merged into WEB-501 (WP31, WP32), with review L's wording
