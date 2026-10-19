## UX web verify — run 2026-10-18-site, round 1, area H (WP14, WP16) — 2026-10-19

**Verdict:** Ship after fixes. Both packages do what they were meant to. The hero now says what TaskFlow is, that it's for Android and that it isn't out yet, in all three languages, and the live demo sits under the hero. One of WP14's acceptance checks still fails: the footer's `/#demo` link, which is the other session's file and WP23's fix. One cosmetic regression came in with the removals.

**Evidence base:** I read the run's diff (`ux-web.sh diff`) and the current source. The renders date from 03:33–03:38, after the last code change at 03:15, so they count as current evidence. I also used AUDIT.md §2, §3, §4, §7 and audit.json. I ran nothing and called no API.

**Attention (predicted from the renders, not eye-tracking):**
- `home.es.mobile.light.fold.png`: 1) the H1 ("Dilo y ya está en tu calendario."), 2) the filled "Pruébalo con tu voz" button, 3) the subheadline or the status line. Competing: the quote card at the bottom edge, and the two round header controls (low weight). The primary action is among the first three. The status line ("Todavía no se puede descargar.") sits directly under it.
- `home.en.desktop.light.fold.png` and `home.ca.desktop.dark.fold.png`: 1) the H1, 2) the phone screenshot (large, with a high-contrast green "Add a task"), 3) the filled "Try it with your voice". Competing: the header's second filled button, "Explore the app", which leads to the same `#voice` under another name. That is WEB-4 and WEB-305, and WP20 fixes it.

**Numbers:**
- `#voice` on the phone starts at about y = 1271 CSS px (my crop of `home.en.mobile.light.full.png`; the tester measured < 1400). It was at 3084.
- Home LCP 1.49–1.51 s, CLS 0.000 on mobile (AUDIT §2, lab data). The LCP element is now `p.hero-description`; before, it was the tilted screenshot.
- One hero image is downloaded: 25–27 KB (AUDIT §2).
- Status line contrast is 5.47:1 in light (#5b685f on #f7f8f2) and 8.86:1 in dark (#b0bcb2 on #121c18), at 16 px (audit.json).
- axe reports 0 violations (AUDIT §4). No sideways scroll at 320 px in any language (AUDIT §3).

### Findings

| ID | Result | Evidence |
|---|---|---|
| WEB-6 | partly | **Gone:** the walkthrough itself — `TaskDemo.tsx` deleted, no `#demo` section in `HomePage.tsx`, no `.task-demo`/`.demo-*` rules in `global.css` — and the header's two `#demo` links (`Header.tsx:8-11`, `:47`). **Still pointing at it:** (a) the footer's "Try the demo" → `/#demo` (`Footer.tsx:22`; acceptance check 2 fails; WP23, held); (b) the tries-used line "The sample walkthrough below is always available." (`VoiceDemo.tsx:828`; WP29 deletes it, held); (c) privacy §8 (`src/content/legal/en.ts:139`, and its Spanish and Catalan versions; WEB-602, WP31, held). All three are tracked, so none is a new regression. Until they land, the visitor is promised something that no longer exists. |
| WEB-17 | fixed | No `#appearance` section. `ThemeToggle` has no "mood" variant (`ThemeProvider.tsx:75-92`). No `.appearance-*` or `.button-outline` rules or uses. `tasks-*.png` deleted. |
| WEB-11 | fixed | No promise bar in `HomePage.tsx`, and no `.promise` rules in `global.css`. |
| WEB-10 | fixed | `<VoiceDemo />` follows the hero directly (`HomePage.tsx:61`), and `#features` comes after it. On the phone, `#voice` starts at about y = 1271. |
| WEB-16 | fixed (WP14's share) | `.voice-illustration` is removed from the features card (`HomePage.tsx:114-125`). Two parts belong to other packages and remain: the demo intro's mic orb (WP26) and the real button (WP27), both held. |
| WEB-114 | fixed | The calendar drawing's header is now "This week" / "Esta semana" / "Aquesta setmana" (`en.ts:21`, `es.ts:115`, `ca.ts:188`). No "September" or "2026" in `#features`. See R1H-2 on the day numbers. |
| WEB-1 | fixed | The H1 and the subheadline match the given copy in en, es and ca (`src/content/site/*.ts`). Judged on `home.es.mobile.light.fold.png`, `home.ca.mobile-w320.light.fold.png` and `home.en.desktop.light.fold.png`, these two lines alone answer what TaskFlow is ("say it, it's on your calendar"), what it does for me ("puts each one on its day and can remind you") and which phone ("An app for Android™ phones"). Everything fits the 390 × 664 and 320 px first viewports. |
| WEB-3 | fixed (WP16's share) | The status line under the buttons reads "Coming soon to Google Play. You can’t download it yet." with its Spanish and Catalan versions (`HomePage.tsx:37`). It is 16 px, 5.47:1 in light and 8.86:1 in dark, and sits in the first viewport on every render. The phone-menu row is WP20's. |
| WEB-4 | fixed (WP16's share) | The hero's filled link goes to `#voice` with the primary label, and the secondary link goes to `#features` (`HomePage.tsx:27-35`). No Google Play link anywhere. The header's "Explore the app" (WP20) and the footer (WP23) remain. |
| WEB-5 | fixed | `Phone.tsx` shows `hero-calendar-<language>-<theme>.png` upright, with the given alt text (`en.ts:13`, `es.ts:107`, `ca.ts:180`). The renders show the app's real Calendar in each language, with "Call the dentist" and "Buy bread" on tomorrow. The quote card sits above the phone, not over its screen. Device check: can the task titles in the screenshot be read at arm's length on a real phone? |
| WEB-19 | fixed | The H1 has no `<br>`, and the trailing space sits inside the `title` text node (`en.ts:5`). The `.hero-art` div has no aria-label, the stage and wave are `aria-hidden`, and axe is clean. Device check: NVDA or TalkBack. |
| WEB-311 | fixed | Both images are lazy with `fetchPriority="high"` (`Phone.tsx:13-28`). AUDIT §2 shows exactly one image for the home, `hero-calendar-en-light`, 25 KB. In the no-JS render the light image shows. |

### Regressions (only from this run's changes)

**R1H-1 · Severity 1 · Voice feature card is half empty**
- **Where:** `src/styles/global.css:652-655` (`.feature-voice`, span 5) next to `.feature-calendar` (span 7), and the ≤ 1100 px block (`:1053-1055`, both span 6). Seen on the home, all three languages, desktop 1440 and desktop-zoom200: `crops/home.es.desktop.light.full.s2-3.png` and `crops/home.en.desktop-zoom200.light.full.s5-7.png`.
- **The moment:** "Is something missing here?"
- **What happens:** WP14 removed the drawing, so the card stretches to the calendar card's height. About 60% of it is empty lavender under three lines and a link.
- **Fix (CSS only, no new content):** let the voice and details cards stack beside the calendar. Add `.feature-calendar { grid-row: span 2; }` and `.feature-details { grid-column: span 5; }`, and `.feature-offline { grid-column: span 12; }`. In the 1100 px block, apply the same row span with `.feature-details` at span 6.
- **Verify:** on the 1440 and zoom200 renders, no feature card has more than about 25% empty height below its content.
- **Evidence:** seen in the current renders.

**R1H-2 · Severity 1 · Two calendars on the page disagree on the week**
- **Where:** `src/components/HomePage.tsx:83` (the hard-coded "21"…"27", with 21 under M/L/dl) and the hero image (week of Mon 19 – Sun 25 October, today the 19th).
- **The moment:** a careful reader sees the hero's "Mon 19" and then the drawing's "Monday 21".
- **What happens:** WP16's real calendar now sits one scroll above a drawing whose fixed numbers start the week on the 21st. The conventions ask that anything date-dependent be relative to today.
- **Fix (subtract):** remove the `<strong>{date}</strong>` day numbers from `.mini-day` and keep the weekday letters. The other option is to compute them from this week's Monday with `Intl` in the page's language. The WP14 brief said to keep the numbers, so the organizer decides.
- **Verify:** `#features` has no hard-coded day numbers, or they equal the current week's dates.
- **Evidence:** verified in code and the renders.

### Not regressions (already tracked)
- The header's links and its "Explore the app" button go to the English home (`/#voice`) from `/es/` and `/ca/`. That is WEB-2 and WEB-4 (WP20). Before this run they went to `/#demo`, which was also English.
- On `/es/` and `/ca/`, the "Pruébalo con tu voz" button now lands, one screen down, on an English demo ("Say it. See it take shape.", "Try the live demo"). That is WEB-2 (WP29, held). Moving the demo up makes it more visible, so WP29 matters more.
- The FAQ's orphan "04 /" eyebrow (01–03 are gone). WP19 deletes it.

### Catalan to have read by a native speaker (organizer's copy shown in the hero)
- "Toca un botó i digues el que has de fer, encara que siguin diverses coses alhora. TaskFlow posa cada una el seu dia i et pot avisar abans." Is "posa cada una el seu dia" natural, or should it be "posa cadascuna al seu dia"?
