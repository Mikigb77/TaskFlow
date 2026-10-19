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
- **WEB-2** · S3 · H · open · Home and demos only in English, with no language switch · `src/proxy.ts` · 2026-10-18-site · Escalation answered 2026-10-19 by the main session (owner away): a path-only Location can't work, because Next 16 answers 500 (Invalid URL) when a proxy returns a relative Location. Instead the 307 is built from the forwarded scheme and the Host the edge worker sends, so it starts with env.ORIGIN and `edge/worker.ts` rewrites it to the public host. Checked with curl locally and with Cloud Run's headers; locked by `tests/ux-web-global.spec.ts` (WEB-2: behind the edge worker…). `proxy.ts` and the /es/ and /ca/ routes are still held and get committed with WP20. Done in b1: the /es/ and /ca/ homes, canonical, hreflang, Accept-Language and the cookie. Still planned: WP20, WP22 (held), WP23 (held), WP24 (held), WP28 and WP29 (held). Merged WEB-301. Device: the 307's Location after a deploy
- **WEB-3** · S3 · H · open · Nothing near a button says the app isn't out · `src/components/HomePage.tsx:37` · 2026-10-18-site · b1 verified WP16 (the hero's status line) and WP18 (closing card, download answer). Left: WP20 (the phone-menu row). Merged WEB-102, WEB-303
- **WEB-4** · S3 · H · open · Every call to action loops back to a sample form · `src/components/Header.tsx:48` · 2026-10-18-site · b1 verified WP16–WP18 (hero, voice card, closing button). Left: WP20 (the header's “Explore the app”), WP23 (footer; held), WP26 (the landing, “Try the live demo”; held). Merged WEB-305
- **WEB-6** · S3 · H · open · The sample walkthrough teaches a form, not the app · `src/components/VoiceDemo.tsx:818` · 2026-10-18-site · WD1 decided removal. b1: WP14 removed it (round 1, partly fixed); WP33 (round 2, held) removed the last pointers: footer, tries-used line, privacy §8. Left: WP26's static example (held)
- **WEB-7** · S3 · H · open · The live demo ends in a toy list · `src/components/VoiceDemo.tsx:606` · 2026-10-18-site · WP28; held (VoiceDemo.tsx holds the other session's line 396)
- **WEB-8** · S3 · H · open · Text in hero, demos and closing card is tiny · `src/styles/global.css:59` · 2026-10-18-site · Measured: 39% of characters under 12 px; none grow with text size. WP25 (global.css), WP29 (voice.css; held). Device: a real phone at arm's length
- **WEB-9** · S2 · H · open · Live demo: twice the app's taps, different words · `src/components/VoiceDemo.tsx:483` · 2026-10-18-site · WP27 (capture), WP28 (result); held. Turnstile's real look needs the deployed site
- **WEB-12** · S2 · H · open · Demo copy uses jargon a newcomer can't parse · `src/components/VoiceDemo.tsx:371` · 2026-10-18-site · WP26 (intro, badge, fine print), WP28 (no tasks), WP29 (messages by code); held
- **WEB-13** · S2 · H · open · Waiting for a result: no update, no way out · `src/components/VoiceDemo.tsx:447` · 2026-10-18-site · WP29; held. Real wait times unmeasured
- **WEB-14** · S2 · H · open · Microphone errors are raw English or dead ends · `src/components/VoiceDemo.tsx:254` · 2026-10-18-site · WP27; held. Device: deny the prompt on Android Chrome and iPhone Safari
- **WEB-15** · S2 · H · open · The recording timer is announced every second · `src/components/VoiceDemo.tsx:532` · 2026-10-18-site · WP27; held. Device: TalkBack while recording
- **WEB-16** · S2 · H · open · Four microphones look tappable; three do nothing · `src/components/VoiceDemo.tsx:382` · 2026-10-18-site · b1 verified WP14 (features drawing, walkthrough). Left: WP26 (the intro orb; held), WP27 (the real button; held)
- **WEB-18** · S1 · H · open · Without JavaScript, the live demo's button does nothing · `src/components/VoiceDemo.tsx:390` · 2026-10-18-site · WP26; held
- **WEB-104** · S3 · F · open · Free plan and Pro missing; pricing answer outdated · `src/components/HomePage.tsx:183` · 2026-10-18-site · WD2 decided. b1 verified WP18 (FAQ, closing line, WD14's clause). Left: WP28 (under the demo; held); the demo's “3 free tries · no account” badge contradicts WD2's line (WP26; held)
- **WEB-105** · S3 · F · open · Several tasks in one dictation is never told · `src/content/site/en.ts:28` · 2026-10-18-site · b1 verified WP17 (the voice card's “Say several things at once”). Left: WP19 (FAQ)
- **WEB-107** · S2 · F · open · Sharing FAQ says “lists” and describes the old invite · `src/app/page.tsx:24` · 2026-10-18-site · WP19
- **WEB-108** · S2 · F · open · Both demos show a review step the app lacks · `src/components/TaskDemo.tsx:248` · 2026-10-18-site · WD1 decided: WP14's removal settles the walkthrough's half; WP28 the live demo's (held)
- **WEB-109** · S2 · F · open · The site names features differently from the app · `src/components/VoiceDemo.tsx:373` · 2026-10-18-site · WP19 (offline answer, home check), WP31 (terms, privacy §8; held); the demo's words with WEB-9 and WEB-12
- **WEB-110** · S2 · F · open · Notes FAQ describes a Task/Note choice the app removed · `src/app/page.tsx:28` · 2026-10-18-site · WP19
- **WEB-111** · S2 · F · open · Feature headings are mood lines; a scanner learns nothing · `src/components/HomePage.tsx:68` · 2026-10-18-site · b1 verified WP17 (one h2, four plain h3s). Left: WP19 (the FAQ's “Glad you asked.” and its orphan “04 /” eyebrow)
- **WEB-113** · S2 · F · open · Privacy policy is behind the app on six points · `src/content/legal/en.ts:29` · 2026-10-18-site · WD3 decided: WP31; held (the other session's untracked files). Merged WEB-201
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
- **WEB-309** · S2 · G · open · The frame's small print is 8–11 px, fixed in px · `src/styles/global.css:121` · 2026-10-18-site · WP25 (global.css), WP23 (the operator line in legal.css; held). Carries withdrawn WEB-310's check. Device: Android at its largest font size
- **WEB-311** · S1 · G · open · First view fetches both theme screenshots and a TTF font · `src/app/layout.tsx:45` · 2026-10-18-site · b1 verified WP16: one hero image, 25–27 KB. Left: WP22 (the font; held)
- **WEB-312** · S1 · G · open · Legal pages share without an image; X tags in English · `src/content/legal/index.ts:190` · 2026-10-18-site · WP30; held
- **WEB-313** · S1 · G · open · Dark first visit: a light toolbar and a greyed-out switch · `src/app/layout.tsx:36` · 2026-10-18-site · WP22 (two theme colours; held), WP25 (dark without JavaScript; the switch hidden until it works). Device: a dark-mode phone on a slow network
- **WEB-401** · S2 · H · open · Connection failures show raw developer text · `src/components/VoiceDemo.tsx:153` · 2026-10-18-site · WP29; held
- **WEB-402** · S2 · H · open · The demo's text box has no visible edge · `src/styles/voice.css:278` · 2026-10-18-site · WP27; held
- **WEB-403** · S2 · H · open · Security check: a disabled button, no reason, no retry · `src/components/VoiceDemo.tsx:36` · 2026-10-18-site · WP29; held. Device: the deployed site with a content blocker
- **WEB-501** · S2 · F · open · Privacy and delete pages say RevenueCat's record stays · `src/content/legal/en.ts:375` · 2026-10-18-site · WP31 (privacy §7), WP32 (delete §3); held. Merged WEB-601
- **WEB-502** · S2 · F · open · The demo turns typed sentences into tasks; that's Pro · `src/components/VoiceDemo.tsx:494` · 2026-10-18-site · WP27; held
- **WEB-602** · S2 · L · open · Privacy §8 will describe a site this run removes · `src/content/legal/en.ts:139` · 2026-10-18-site · WP31, after WP14, WP20 and WP27; held
- **WEB-702** · S1 · G · open · Taps on frame links give no visible feedback · `src/styles/global.css:67` · 2026-10-18-site · WP25. Device: a throttled Android phone
- **WEB-703** · S1 · G · open · Logo, footer links and “Back to top” under 44 px · `src/components/Footer.tsx:43` · 2026-10-18-site · WP25 (logos), WP23 (footer; held)
- **WEB-704** · S1 · G · open · No Android trademark line where the site names Android · `src/components/Footer.tsx:17` · 2026-10-18-site · WP23 (the line; held); the ™ comes with WEB-1's hero copy (WP16). Google's brand approval is the owner's, at launch
- **WEB-707** · S2 · G · open · English demo and FAQ marked as Spanish/Catalan · `src/components/HomePage.tsx:62` · 2026-10-18-site · regression of round 1 (b1, WP15). b1 verified WP34: the demo sits in a `lang="en"` wrapper, which WP26 removes. Left: the FAQ half (WP19). Merged R1G-1. Device: TalkBack in Spanish; VoiceOver with `display: contents`

## Decision needed
- **WEB-701** · S2 · G · decision · WebKit draws every weight at Manrope's thinnest · `src/styles/global.css:3` · 2026-10-18-site · WD15: only Safari on the owner's iPhone can tell; probably a Windows-WebKit artifact. The main session can't answer it

## Escalated

## Device check
- **WEB-1** · S4 · H · device-check · The hero never says what TaskFlow is · `src/content/site/en.ts:5` · 2026-10-18-site · b1, 2026-10-19: WP16's H1 and subheadline in EN/ES/CA, in the first viewport at 390 and 320 px. Test: `tests/ux-web-home.spec.ts` (WEB-1). Left: a screen reader on the hero; a native Catalan read of «posa cada una el seu dia» (or «posa cadascuna al seu dia»)
- **WEB-5** · S3 · H · device-check · Hero and appearance screenshots show the old app · `src/components/Phone.tsx:13` · 2026-10-18-site · b1, 2026-10-19: WP16 shows WD4's `hero-calendar-<language>-<theme>.png` upright; WP14 removed the appearance screenshot. Merged WEB-103. Test: `tests/ux-web-home.spec.ts:62`. Left: are the task titles legible at arm's length on a real phone?
- **WEB-19** · S1 · H · device-check · Decorative hero text is read aloud; div labels ignored · `src/content/site/en.ts:5` · 2026-10-18-site · b1, 2026-10-19: WP16 removed the H1's `<br>` and the div's aria-label; the stage and wave are `aria-hidden`; axe is clean. Test: `tests/ux-web-home.spec.ts` (WEB-19). Left: NVDA or TalkBack on the hero
- **WEB-503** · S1 · F · device-check · Opening one FAQ answer closes the one you read · `src/components/HomePage.tsx:161` · 2026-10-18-site · b1, 2026-10-19: WP18, `<details>` has no `name`. Test: `tests/ux-web-features.spec.ts` (WEB-503). Left: Safari on an iPhone, no jump
- **WEB-708** · S2 · F · device-check · Account answer reads as password-free sign-in · `src/content/site/en.ts:61` · 2026-10-18-site · b1, 2026-10-19: WP35 (round 2) names the password, then the 6-digit code; true of the app. Merged R1F-1. Test: `tests/ux-web-features.spec.ts` (WEB-708). Left: a native Catalan read

## Verified
- **WEB-710** · S1 · F · verified · Offline paragraph sits above its own heading · `src/styles/global.css:687` · verified 2026-10-19 by the main session (owner away): `.feature-offline p` moved to row 2 with the heading's 18px top margin. Test: `tests/ux-web-features.spec.ts` (WEB-710, |p.top − h3.top| ≤ 2 px at 1440 in EN, ES, CA). R3F-1
- **WEB-10** · S2 · H · verified · The live demo sits 5.4 phone screens below the hero · `src/components/HomePage.tsx:61` · verified 2026-10-18-site b1, 2026-10-19 · WP14: the demo follows the hero; `#voice` at ≈ y 1271 on the phone (was 3084). Test: `tests/ux-web-home.spec.ts` (WEB-10)
- **WEB-11** · S2 · H · verified · The “at a glance” bar says nothing concrete · `src/components/HomePage.tsx` · verified 2026-10-18-site b1, 2026-10-19 · WP14 removed the bar and its rules. Test: `tests/ux-web-home.spec.ts` (WEB-11)
- **WEB-17** · S2 · H · verified · A whole section sells the website's dark mode · `src/components/ThemeProvider.tsx:75` · verified 2026-10-18-site b1, 2026-10-19 · WP14 removed `#appearance`, the mood toggle and `tasks-*.png`. Merged WEB-112. Test: `tests/ux-web-home.spec.ts` (WEB-17)
- **WEB-101** · S4 · F · verified · The site says TaskFlow works without an account · `src/content/site/en.ts:61` · verified 2026-10-18-site b1, 2026-10-19 · WP17 (cards), WP18 (FAQ); the account answer's missing password was WEB-708, also fixed. Test: `tests/ux-web-features.spec.ts` (WEB-101)
- **WEB-106** · S2 · F · verified · Reminders, the core loop's third step, are never told · `src/content/site/en.ts:20` · verified 2026-10-18-site b1, 2026-10-19 · WP17: the calendar card's reminder sentence, EN/ES/CA. Test: `tests/ux-web-features.spec.ts` (WEB-106)
- **WEB-114** · S1 · F · verified · Sample dates are a month old · `src/content/site/en.ts:21` · verified 2026-10-18-site b1, 2026-10-19 · WP14: the drawing's header says “This week”, no September or 2026; its day numbers went with WEB-706. WD4's hero images show their render date: re-render before publishing. Test: `tests/ux-web-home.spec.ts` (WEB-114)
- **WEB-308** · S2 · G · verified · Keyboard focus vanishes on the closing card in light mode · `src/styles/global.css:797` · verified 2026-10-18-site b1, 2026-10-19 · WP18: lime focus outline, 7.57:1 in light and dark (was 1.58:1). Test: `tests/ux-web-features.spec.ts` (WEB-308)
- **WEB-504** · S2 · F · verified · Comparers never learn their phone calendar comes along · `src/content/site/en.ts:20` · verified 2026-10-18-site b1, 2026-10-19 · WP17: “events from your phone’s calendars”, EN/ES/CA. Test: `tests/ux-web-features.spec.ts` (WEB-504)
- **WEB-705** · S1 · F · verified · Voice feature card is half empty · `src/styles/global.css:531` · verified 2026-10-18-site b1, 2026-10-19 · WP35 (round 2): the calendar card spans two rows, voice over details, ≤ 25% empty height; round 3's tests pass again. Merged R1H-1, R1F-2. Test: `tests/ux-web-features.spec.ts`, `tests/ux-web-home.spec.ts` (WEB-705)
- **WEB-706** · S1 · F · verified · Calendar drawing hard-codes days 21–27 under ‘This week’ · `src/components/HomePage.tsx:85` · verified 2026-10-18-site b1, 2026-10-19 · WP35 (round 2): weekday letters only, no dates. Merged R1H-2, R1F-3. Test: `tests/ux-web-features.spec.ts`, `tests/ux-web-home.spec.ts` (WEB-706)
- **WEB-709** · S1 · F · verified · Full-width offline card is two-thirds blank · `src/styles/global.css:670` · verified 2026-10-18-site b1, 2026-10-19 · WP36 (round 3): two columns above 800 px, under half blank; its follow-on is WEB-710. Merged R2F-1. Test: `tests/ux-web-features.spec.ts` (WEB-709)

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
