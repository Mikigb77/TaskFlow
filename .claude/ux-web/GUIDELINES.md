# TaskFlow website UX guidelines

The evidence base for `web-ux-reviewer`. It turns research, standards and platform rules into short rules you can check on a render or in the website's code (`../TaskFlowWeb`). The app's equivalent is `.claude/ux-review/GUIDELINES.md`; where both cite the same source, the keys match.

- **Verified:** 2026-10-18. Sources were fetched that day unless an entry is marked. Platform rules and laws change; re-check one before quoting it in a policy or legal question.
- **The bar:** the Newcomer — 60 or older, Spanish or Catalan, on an Android phone, arriving from a link shared on WhatsApp, non-technical, wary of being tricked into paying or giving data away. In October 2026 the owner's father couldn't create a task in the app.
- **What the site is for:** teach what TaskFlow does and make people want it; never replicate the app. Every claim is true of the app today. Google Play isn't published yet, so calls to action stay honest.
- **Owner decisions win.** `.claude/ux-web/DECISIONS.md` and `.claude/ux-review/DECISIONS.md` override this guide. When a rule conflicts with one, raise it under "Questions for the owner" with the rule ID; don't file it as a finding.
- **Not legal advice.** Rules marked *(legal check)* go to the owner as questions, not findings.
- **Cite by ID** in findings, e.g. "Why it fails: AT-2 (Lagun 2014)".
- **Verification pass, 2026-10-18 (second).** The first pass ran into the research's shared search cap, so every source marked †, ‡ or ~, the old "Not verified" list and the research reports' open items were re-checked on primary sources: Google Play and Android pages, Chrome's docs and Platform Status, EUR-Lex, BOE, the AEPD, the Council and Parliament registers, ETSI, and publishers' or authors' copies of papers.
  - Corrected: PV-6 and FN-9 (the AEPD's January 2024 analytics exemption); PV-7 (Play's deletion rules); AP-1, AP-3 and AP-5 to AP-7 (badges, referrer links, package names, brand rules); PR-4 and AX-1 (facts behind the legal checks); AX-11 (the FTC's final order); FN-7 (Bailey's own first-click data); FN-8; HE-12, EY-1, EY-7, RD-4 and RD-5; §0 and §18.
  - A remaining ‡ means the abstract confirmed the claim and the full text was paywalled or blocked to automated readers. Still open, with reasons: the list at the end of [Sources](#20-sources).

**Rule format.** **Do** says what good looks like. **Check** says how to test it on a render or in code, then gives the key evidence. Each rule ends with its evidence strength and source keys; every key has a full entry (title, authors or organisation, year, URL) under [Sources](#20-sources).

**Evidence strength**, strongest first. The brief asks for three levels — study/data, expert guideline, convention/opinion. As in the app's guide, expert guidance is split three ways so the reviewer knows what binds:
- *study/data* — measured: experiment, eye-tracking, field log, survey or meta-analysis (sample sizes in the rule);
- *standard/law* — WCAG, GDPR, EU and Spanish law: normative text (a kind of expert guideline);
- *platform guideline* — Google (Play, Android, Search, web.dev, Chrome), Apple, Next.js (a kind of expert guideline);
- *expert guideline* — NN/g, Baymard, W3C notes, regulators' guidance: synthesised from research and practice;
- *convention/opinion* — practitioner essays, vendor material, design convention.

**Source markers** (in the source list): † known only second-hand; ‡ abstract, summary or metadata only; ~ search snippet only. Unmarked entries were fetched and read.

**Reviewer lenses → rules** (`.claude/agents/web-ux-reviewer.md`, checklist A–O):

| Lens | Rules |
|---|---|
| A First impression | AT-1–AT-7, HE-1–HE-12, EY-1–EY-6 |
| B Desire | HE-1, HE-4, HE-5, HE-11, AP-11, AP-13, TR-4 |
| C Calls to action | CT-1–CT-12, AP-1–AP-5 |
| D Funnel continuity | FN-1–FN-9, AP-3, AP-6, AP-10 |
| E Faithfulness | FN-1–FN-4, FN-6, AP-12, TR-4 |
| F Scanning and hierarchy | SC-1–SC-8, EY-1–EY-7 |
| G Copy and language | RD-1–RD-3, RD-7, HE-2, HE-3, HE-10, ML-5–ML-7 |
| H Navigation and wayfinding | NV-1–NV-8, ML-1, ML-4 |
| I Trust and legal | TR-1–TR-7, PV-1–PV-7, PR-1–PR-8, FQ-1–FQ-3 |
| J Phone and touch | CT-6–CT-9, AT-2, AX-3 |
| K Accessibility | AX-1–AX-12, OL-1–OL-4, RD-4–RD-6 |
| L Speed and feedback | PF-1–PF-8 |
| M Search and sharing | ML-1–ML-3, ML-8, ML-9 |
| N Light and dark | AX-2, HE-5 |
| O Demos | AP-13, FN-4, PF-8, AX-9, AX-10, PV-3 |

## 0. Numbers at a glance

| Topic | Number | Source |
|---|---|---|
| Fold, desktop | 57% of viewing time above the fold, 74% in 2 screenfuls, 81% in 3 (120 people, 1920 × 1080, 2018); 80% above the fold in 2010 (1024 × 768) | Fessenden 2018; Nielsen 2010s |
| Fold gap | The 100 px just above the fold viewed 102% more than the 100 px below; NN/g's estimate of the fold effect: 84% | Schade 2015 |
| Phone screen | ≈ 70% of gaze on the top half, 14% on the bottom third (24 people, search tasks, 2014) | Lagun 2014 |
| Left bias, desktop | 80% of fixations on the left half (2017; 69% in 2010); the right side's first look after ≈ 2–3 s | Fessenden 2017h; Nielsen 2010h; Buscher 2009 |
| Right rail | 1 of 132 content fixations (2018) | Pernice 2018 |
| Reading | 79% scan, 16% read word by word (1997); ≈ 20% of a page's words read, 28% at most (2008) | Nielsen 1997; Nielsen 2008 |
| First words | ≈ 2 words / 11 characters seen per line; 35% of 20 links unclear from them (2009) | Nielsen 2009w |
| Writing | Concise +58%, scannable +47%, objective +27%, all three +124% usability (51 users, 1997) | Morkes 1997 |
| Leaving | Chance of leaving highest at the start on 98.5% of pages (205,873 URLs, 2010); NN/g: the first 10 s are critical | Liu 2010; Nielsen 2011d |
| First impression | Appeal ratings at 50 ms track those at 500 ms (r = .97, as Tuch 2012 reports it); simple, typical pages win at 17–50 ms — looks only | Lindgaard 2006; Tuch 2012 |
| Weak signifiers | Flat targets: +22% time, +25% fixations to find (71 people, 2017) | Moran 2017f |
| Faces | 16.6× more fixations than equal regions; text 11.1× (2009) | Cerf 2009 |
| Hidden navigation | Used 27% vs 48–50% visible (desktop); 57% vs 86% combined (phone); ≥ 39% slower on desktop (179 people, 2016) | Pernice 2016a |
| Centred logo | 6× more failures to reach home in one click (50 people, 2016) | Whitenton 2016 |
| Targets | 24 × 24 CSS px (2.5.8, AA, with exceptions); 44 × 44 (2.5.5, AAA); Apple 44 × 44 pt; Android 48 × 48 dp, ≥ 8 dp apart; NN/g ≥ 1 × 1 cm; one thumb 9.2 / 9.6 mm | WCAG 2.2; Apple Buttons; Android Touch targets; M3 Structure; Harley 2019; Parhi 2006 |
| Touch | Accuracy ≈ 7 mm at the centre, ≈ 12 mm at corners; 49% one-handed, 36% cradled, 15% two-handed (780 touches, 2013) | Hoober 2017a; Hoober 2013 |
| Contrast | Text 4.5:1; large text (≥ 24 px, or ≥ 18.5 px bold) 3:1; controls and focus 3:1; never rounded | WCAG 2.2 |
| Zoom and spacing | Text to 200%; reflow at 320 CSS px; spacing 1.5 / 2 / 0.12 / 0.16 | WCAG 2.2 |
| Motion | Auto-moving content > 5 s needs pause, stop or hide; ≤ 3 flashes a second | WCAG 2.2 |
| Line length | 50–75 characters (Baymard); 45–75, 66 ideal (web.dev, citing Bringhurst); AAA ≤ 80 | Baymard 2022; web.dev Typography; WCAG 2.2 |
| Core Web Vitals (p75, mobile and desktop separately) | LCP ≤ 2.5 s good, > 4 s poor; INP ≤ 200 ms, > 500 ms; CLS ≤ 0.1, > 0.25; supporting: TTFB ≤ 0.8 s, FCP ≤ 1.8 s. INP replaced FID on 12 Mar 2024; unchanged as of Oct 2026 | web.dev Vitals; web.dev LCP; web.dev INP; web.dev CLS; Search CWV |
| Speed and outcomes | +100–400 ms → 0.2–0.6% fewer searches (experiment, 2009); LCP −31% → +8% sales (Vodafone A/B, 2021); 0.1 s faster mobile → +8.4% retail conversions (37 brands, observational, 2020) | Brutlag 2009; Vodafone 2021; Deloitte 2020 |
| Response limits | 0.1 s instant · 1 s keeps flow · 10 s keeps attention (rules of thumb) | Nielsen 1993 |
| Microphone prompt | Allowed 12% of the time without a user gesture vs 30% after one (Chrome desktop) | web.dev Permissions |
| Older users | Success 55.3% vs 74.5%; 43% slower; 2.4 vs 1.1 errors; self-blame 90% vs 58% (2013) | Nielsen 2013 |
| Automated accessibility checks | Best of 10 tools found 41% of 143 barriers (2017); 95.9% of the top 1M home pages fail detectable checks, low contrast on 83.9% (2026) | GOV.UK 2017; WebAIM Million 2026 |
| Text expansion from English | ≤ 10 chars 200–300%; 11–20: 180–200%; 21–30: 160–180%; 31–50: 140–160%; > 70: ≈ 130% | W3C Text size |
| Own language | 76% prefer product information in their language; 40% never buy in other languages (8,709 people, 29 countries, 2020, self-reported) | CSA 2020 |
| Dark patterns | At least one on 97% of popular EU sites and apps (73 of 75 checked, 2022); on 148 of 399 shops (2023 sweep) | EC Dark patterns 2022; EC Sweep 2023 |
| A/B tests | ≈ 1 in 3 ideas improves its metric at Microsoft (Bing 15%, others 8–10%); n ≈ 16σ²/δ² per variant (≈ 3,600 to detect 10% → 12%) | Kohavi 2013; Kohavi 2022 |
| Install interstitial | 69% of visits abandoned; with a banner instead, mobile-web 1-day actives +17% (Google+, 2015) | Morell 2015 |
| Usability tests | 5 users ≈ 85% of problems (a model of one group); real 5-user sets found 55–99% | Nielsen 2000; Faulkner 2003 |
| Play badge | ≥ 28 px tall; clear space ¼ of its height; at least as large as other store badges; "Get it on Google Play" in 75 languages, Catalan and Spanish included; "Pre-register" in Spanish but not Catalan | Google PMH Badges |
| Play launch gates | Pre-registration: a 90-day campaign timed from each country's start, ending everywhere if the app launches in none of them; personal accounts created after 13 Nov 2023: a closed test with ≥ 12 testers opted in for 14 consecutive days, then an application for production access (usually reviewed within 7 days) | Play Pre-registration; Play Testing req |
| Play links | Campaign tags go URL-encoded inside `referrer`, ≤ 512 characters; the app can read them for 90 days after install | Play Games UA; Play Install Referrer |
| QR code | ≥ 2 × 2 cm, plus about 1 cm per 10 cm of scanning distance | Kohler 2024 |
| GIF vs video | 3.7 MB GIF → 551 KB MP4 / 341 KB WebM (one example) | web.dev GIFs |

## 1. How people scan pages (SC)

- **SC-1 Write for scanners.** Do: assume a first-time visitor scans; every section must make sense from its heading, the first words of its lines, bold phrases and links.
  Check: the headings-only test — read only the H1, the H2/H3s and the button labels; the story (what it is, what it does for me, how to get it, what it costs) still holds. 79% of test users scanned and 16% read word by word (1997); people read about 20% of a page's words, at most 28% (2008). — *study/data* · [Nielsen 1997] [Nielsen 2008] [Moran 2020r]
- **SC-2 Make layer-cake scanning possible.** Do: one descriptive heading per section that stands out from body text without looking like an ad, sits right above its text, summarises it and leads with the key words.
  Check: every section has an H2 or H3 in the markup that differs in size or weight in the CSS; no run of more than about 4 lines without a heading, list or bold cue (threshold: convention). NN/g calls layer-cake scanning by far the most effective pattern. — *study/data* · [Pernice 2019l] [Pernice 2019s]
- **SC-3 Don't leave text to the F-pattern.** Do: the key point in the first sentence of each block, bullets for parallel items, a few bold key phrases, descriptive links, fewer words.
  Check: no unformatted block of text, on desktop or phone. The F-pattern appears when text lacks formatting cues and the reader wants efficiency without commitment; people then miss content, most of all on the right. It happens on phones too; comprehension on phones matched desktop, but hard text was read more slowly. — *study/data* · [Nielsen 2006f] [Pernice 2017] [Moran 2016]
- **SC-4 Front-load every line.** Do: headings, buttons, FAQ questions, list items and links start with the words that carry the meaning, in all three languages.
  Check: the first two words (about 11 characters) alone identify the topic; no openers such as "Welcome", "Introducing", "Discover", «Bienvenido», «Descubre», «Descobreix». For 35% of 20 tested links, people couldn't tell the destination from the first 11 characters. — *study/data* · [Nielsen 2009w] [Pernice 2017]
- **SC-5 Vary how list items start.** Do: begin each bullet with a different, meaningful word.
  Check: no list where 3 or more items start with the same words ("You can…", «Puedes…», «Pots…»); readers skip such items (the bypassing pattern). — *study/data* · [Pernice 2019s]
- **SC-6 Facts as digits; bold used sparingly.** Do: write counts, limits and prices as numerals ("10 dictations", "60 s") and bold only the phrase that matters.
  Check: numerals in ES, CA and EN; about 1–2 bold phrases per section (convention). Digits and visually distinct words draw the eye (the spotted pattern). — *study/data* · [Pernice 2019s]
- **SC-7 Align feature rows consistently.** Do: keep image–text rows on a consistent side; a zigzag only for 2–3 rows; the first row's left side carries the key message.
  Check: a section of more than 3 rows that swaps sides on every row is a finding. Zigzags made decorative images harder to skip and scanning less efficient (4 sites, about 30–35 people per version). — *study/data* · [Flaherty 2017z]
- **SC-8 Name the visitor's task before predicting behaviour.** Do: judge each page for a stated task — Newcomer "what is this, and how do I get it?", Comparer "what's free, what does Pro cost?", Leaver "how do I delete my account?".
  Check: findings name the task. The same page drew 228 fixations when read with motivation vs 28–38 when scanned for a task; reading nearly everything (the commitment pattern) needs high motivation and is rare. — *study/data* · [Pernice 2017t] [Pernice 2019s]

## 2. Attention and the fold (AT)

- **AT-1 The first viewport holds the promise and the next step.** Do: what TaskFlow is, what it does for the visitor, and the one next step are all visible without scrolling, on desktop and phone.
  Check: on the fold renders (1440 × 1000 and 390 × 664) the H1, a one-line explanation and the primary action are fully visible. Desktop eye-tracking found 57% of viewing time above the fold, 74% in the first two screenfuls and 81% in three (120 people, 1920 × 1080, 2018; 80% above the fold in 2010). These are desktop figures. — *study/data* · [Fessenden 2018] [Nielsen 2010s] [Nielsen 2001h]
- **AT-2 On a phone, the top half matters most.** Do: the H1 starts in the upper half of the phone screen and the primary action sits within the first screen.
  Check: on the 390 × 664 render the H1 starts above y ≈ 330 and nothing that must be seen sits only in the bottom third (y > 443). In phone eye-tracking about 70% of gaze fell on the top half and 14% on the bottom third (24 people, search tasks, 2014). — *study/data* · [Lagun 2014]
- **AT-3 No false floors.** Do: let the start of the next section show at the bottom of the first viewport.
  Check: no full-screen hero (100vh/100svh) with nothing below it, and no full-width line or wide empty band at the fold; a scroll arrow alone doesn't pass. In one test 6 of 8 users didn't realise the page scrolled. — *study/data (n = 8)* + *expert guideline* · [Flaherty 2016] [Schade 2015]
- **AT-4 Earn every scroll.** Do: each screenful promises something useful; people scroll when what they see looks promising.
  Check: no screenful of decoration only (a big image, empty space, a logo strip) between the hero and the first proof. — *expert guideline* · [Schade 2015] [Budiu 2023]
- **AT-5 Prioritise; don't cram.** Do: put a few essentials at the top and lead people down; don't move everything above the fold.
  Check: the first viewport has one headline, one subheadline, one primary action and one product image. The fold gap is large (the 100 px just above it got 102% more viewing than the 100 px below), but crowding the top raises visual complexity, which lowers appeal. — *study/data* + *expert guideline* · [Schade 2015] [Tuch 2012]
- **AT-6 The basics within two phone screens.** Do: by the end of the second phone screen the visitor has read what TaskFlow does, that it's for Android, what's free (10 dictations a month) and that Pro exists, and how to get it.
  Check: on the full mobile render, scroll 2 × 664 px; each item appears as text, not only inside an image or the demo. — *study/data* + *expert guideline* · [Fessenden 2018] [Nielsen 2011d]
- **AT-7 The value lands without interaction.** Do: the static hero explains the product without a click, an animation, a carousel, a video or the demo.
  Check: mentally remove all motion and interactive parts; the value is still clear. Time on page follows a Weibull curve whose chance of leaving is highest at the start on 98.5% of pages; NN/g reads this as "the first 10 seconds decide". — *study/data* + *expert guideline* · [Liu 2010] [Nielsen 2011d]

## 3. What draws the eye: eye-tracking and heatmaps (EY)

- **EY-1 The headline is the entry point.** Do: the H1 is the largest, highest-contrast text, at the top-left or top-centre.
  Check: on the fold render nothing (logo, badge, text inside an illustration) is larger or more contrasted than the H1. On news sites the dominant headline, not the photo, was usually the entry point; on interfaces, text drew attention more than images and the top-left drew the most fixations. — *study/data* · [Poynter 2004] [Jiang 2023] [Leiva 2020]
- **EY-2 On desktop, essentials start on the left.** Do: the H1, key facts and the primary action start in the left half of the content area.
  Check: on the 1440-px render the primary action starts left of the centre line; the right third holds only secondary items. 80% of desktop fixations fell on the left half (2017; 69% in 2010); the right side took about 2–3 s to get a first look, and element size was the strongest predictor of attention. — *study/data* · [Fessenden 2017h] [Nielsen 2010h] [Buscher 2009]
- **EY-3 Images carry information.** Do: show real app screens with a real result (a spoken sentence and the dated task it became), not stock people, abstract art or decoration.
  Check: every image shows the product or a result; text inside screenshots is legible at its displayed size. People study informative images and skip feel-good stock photos; literal product screenshots help understanding, but words are still needed. — *study/data* + *expert guideline* · [Nielsen 2010p] [Flaherty 2017z] [Paul 2024]
- **EY-4 Faces compete for attention.** Do: if a face appears, make it look at the headline, the button or the phone; never put a face that looks at the viewer beside the primary action.
  Check: each face's position and gaze direction. Faces drew 16.6× more fixations than equal regions. In one study a face looking at the ad's content raised recognised items to 1.50 (0.54 with no face), while a face looking at the viewer held attention on itself; a replication found gaze raised looks at the product but not time on it. — *study/data (modest effect)* · [Cerf 2009] [Frischen 2007] [Sajjacholapunt 2014] [Palcu 2017]
- **EY-5 Nothing essential looks like an ad.** Do: keep the free limit, the price, the Play badge and the way into the demo out of banner-shaped strips, right-rail boxes, bright promo tiles and animated badges.
  Check: no essential content in ad-like shapes or positions; announcement and cookie bars carry nothing essential. Only 1 of 132 fixations landed in a right rail, and phone users swiped past bright graphics, taking them for ads. — *study/data* · [Pernice 2018] [Nielsen 2007b] [Burke 2005]
- **EY-6 Motion doesn't grab attention.** Do: no autoplaying loops, rotating headlines or carousels next to text or the primary action; motion starts on the visitor's action.
  Check: nothing animates by itself for more than 5 s without a pause control. Animated banners slowed visual search and were recognised no better than chance. — *study/data* + *standard/law* · [Burke 2005] [WCAG 2.2] (2.2.2)
- **EY-7 Treat heatmaps as hypotheses.** Do: label any predicted, AI or cursor heatmap "predicted"; draw conclusions only from tests with people.
  Check: any heatmap cited names its source. Real eye-tracking heatmaps need about 30 users (R² ≈ 0.47 with 10 or fewer vs ≈ 0.85 with 30); the cursor trails gaze by about 700 ms and 130–280 px; classic saliency models fit interfaces weakly and don't generalise; vendor "90%+" accuracy figures come from general-image benchmarks. — *study/data* · [Pernice 2009] [Huang 2012] [Leiva 2020] [Jiang 2023]

## 4. Value proposition and hero (HE)

- **HE-1 Say what it does, in everyday words.** Do: the H1 and subheadline say what TaskFlow does for the visitor — you say or type a thought and it becomes tasks on your calendar, with reminders, on Android — in the app's own words.
  Check: from the H1 and subheadline alone, write one sentence the Newcomer would understand. Competitor test: put a rival's name in it; if it still fits, it fails. Opposite test: if no company would ever claim the reverse, it says little. — *expert guideline* · [Nielsen 2001t] [Nielsen 2001h] [Wang 2024]
- **HE-2 Outcome, not technology.** Do: lead with the result the visitor gets, not the technique behind it.
  Check: the H1's main claim isn't "AI", "smart", "powered by", "easier" or "more powerful", nor their ES or CA equivalents. "Powered by AI" is not a value proposition. — *expert guideline* · [Samsonov 2025]
- **HE-3 Clear beats clever.** Do: plain, literal words with the keywords first; no puns, idioms or trendy words.
  Check: the H1 and H2s carry no wordplay that fails in translation or for a non-native reader. Removing promotional language measured 27% better usability. — *study/data* + *expert guideline* · [Morkes 1997] [Loranger 2017m] [Loranger 2015h]
- **HE-4 One concrete example.** Do: show one real input and the task it becomes, with its day and time.
  Check: the hero or the next section shows a spoken sentence and the dated task it produced. Concretely worded statements were judged more likely true, and concrete service language raised satisfaction and purchases; no study has tested hero headlines directly. — *study/data* · [Hansen 2010] [Packard 2021]
- **HE-5 The visual is the app at work.** Do: the hero image is a real, current Android screen showing the result, in the page's language and theme.
  Check: real UI, not a mock-up or an empty phone frame; legible at phone width; alt text says what the screen shows; it matches the app's current renders (FN-3). — *study/data* + *expert guideline* · [Nielsen 2010p] [Paul 2024] [Nielsen 2001h]
- **HE-6 Headline, subheadline and visual divide the work.** Do: headline = what it does for me; subheadline = how, and for whom, in one sentence; visual = the proof.
  Check: each part adds something the others don't. NN/g says what the top must achieve (what it is, why it's valuable, informative imagery); this particular split is convention. — *convention/opinion* · [Wang 2024] [Nielsen 2001h]
- **HE-7 Simple and typical.** Do: a hero that reads as an app landing page at a glance: one headline, one subheadline, one primary action, one product image.
  Check: at most 2 typefaces; no grids of features, badges or logos in the hero. Simple, typical pages were rated most appealing even at 17–50 ms exposures (59 + 82 people, 2012). — *study/data* + *expert guideline* · [Tuch 2012] [Fessenden 2017f]
- **HE-8 Nothing in the hero moves by itself.** Do: no auto-advancing carousel, rotating or typed-out headline, or autoplaying video.
  Check: no `autoplay` on hero video; the value proposition is never only inside a carousel; any motion over 5 s can be paused. A test user missed an offer that rotated every 5 s; when video autoplays, many users first mute or pause it. — *study/data (qualitative)* + *standard/law* · [Nielsen 2013c] [Schade 2014v] [WCAG 2.2] (2.2.2)
- **HE-9 Give before asking.** Do: no sign-up, email or microphone request before the page has explained the product; the demo is optional.
  Check: nothing asks for the microphone, plays audio or opens a modal on load. Vague "Get Started" buttons pulled people into funnels before they knew the offer (6 of 8 users on one site). — *study/data (qualitative)* + *expert guideline* · [Harley 2017] [Budiu 2014] [Budiu 2014l]
- **HE-10 Words the Newcomer knows.** Do: no technical terms on the main path (AI, sync, capture, extraction, transcription, allowance) unless explained in plain words.
  Check: list every technical term in the first two screens of each language. Many people over 65 were unsure of basic web terms. — *expert guideline* · [NNg Techy terms] [Kane 2019]
- **HE-11 The core loop first; extras later.** Do: the top of the page teaches one loop — say it, see it on your calendar, get reminded; projects, sharing and attachments come later, briefly.
  Check: section order; an advanced feature above the core loop is a finding. Showing the core options first helps novices learn and make fewer errors. — *expert guideline* · [Nielsen 2006]
- **HE-12 Polish is not proof.** Do: walk the page even when the render looks beautiful.
  Check: never downgrade a finding because the page is attractive; how easy a design looks tracks its beauty more than most of its usability properties (252 people rating 26 layouts), and good looks forgive small problems, not big ones. — *study/data* · [Kurosu 1995] [Moran 2024a]

## 5. Calls to action (CT)

- **CT-1 One primary action per view.** Do: one control styled as primary in each viewport; everything else looks secondary.
  Check: count accent-filled buttons and store badges in each viewport render; more than one competing is a finding; the primary style isn't reused for the theme or language controls. Apple: one or two prominent buttons per view; GOV.UK: avoid more than one main button; competing calls to action dilute each other. — *platform guideline* + *expert guideline* · [Apple Buttons] [GOV.UK Button] [Laubheimer 2023ia] [Baymard 2021]
- **CT-2 Above the fold, then again where people decide.** Do: the primary action in the first viewport, repeated after the proof (screenshots, demo, pricing) and in the last screenful, never twice in one view.
  Check: mark every call to action on the full render; the last screenful has one; no two identical ones share a viewport. Repeating the same item in one place weakens it, and readers are receptive at the end of content. No rigorous study tests repetition itself. — *expert guideline* · [Nielsen 2001h] [Loranger 2014r] [Schade 2015]
- **CT-3 Labels name what happens.** Do: specific, verb-first labels that say where the visitor goes or what they get.
  Check: no "Get started", "Learn more", "Explore", "Click here" or "More", nor «Empezar», «Más información», «Descubre», «Comença», «Més informació», «Descobreix»; each label makes sense alone. Generic buttons pulled people into funnels, and analytics counted those misled clicks as conversions. — *study/data (qualitative)* + *expert guideline* + *standard/law* · [Harley 2017] [Sherwin 2015] [Moran 2019] [WCAG 2.2] (2.4.4)
- **CT-4 The destination keeps the label's promise.** Do: the first view after a click matches the label.
  Check: follow every call to action in the code: "Try the demo" lands with the demo in view; a store link opens the right listing. — *expert guideline* · [Pernice 2014] [Budiu 2020]
- **CT-5 Buttons look like buttons.** Do: a solid fill for the primary action; never an outline-only ("ghost") primary; links look like links.
  Check: the primary has a fill; a secondary outline has ≥ 3:1 contrast and never sits on a photo. Weak signifiers took 22% longer to find and drew 25% more fixations (71 people); ghost buttons were among them, and a ghost button can pass WCAG and still fail here. — *study/data* + *expert guideline* · [Moran 2017f] [Moran 2017b] [Loranger 2015c]
- **CT-6 Generous targets.** Do: primary action ≥ 48 CSS px tall; every tap target ≥ 44 × 44 CSS px; ≥ 8 px between neighbours.
  Check: measure rendered boxes at 390 px, and in code at 320 px. WCAG's AA floor is 24 × 24 CSS px with exceptions (spacing, inline links in text); 44 × 44 is AAA and Apple's size; Android and Material 3 ask 48 × 48 dp, 8 dp apart; NN/g ≥ 1 × 1 cm; one-thumb tests found 9.2–9.6 mm. — *standard/law* + *platform guideline* + *study/data* · [WCAG 2.2] (2.5.8, 2.5.5) [Apple Buttons] [Android Touch targets] [M3 Structure] [Harley 2019] [Parhi 2006]
- **CT-7 Bigger for older hands and large text.** Do: give the primary action about 20% more than the minimums (≈ 56 CSS px tall) and keep its whole label at 200% text in ES and CA.
  Check: no clipped or truncated label at 200% text or at 320 px. Hoober advises designing about 20% larger to allow for scaling and poor eyesight; small targets and tiny type remain older adults' recurring problems. — *expert guideline* + *study/data* · [Hoober 2017c] [Kane 2019]
- **CT-8 Where the thumb is accurate.** Do: on phones, never put the primary action in a top corner; in view, it sits in the middle band; a bottom-edge button stands alone.
  Check: its position on the mobile render. Taps are accurate to about 7 mm at the centre and 12 mm at the corners, and people prefer to look at and touch the centre; 49% held phones one-handed, 36% cradled, 15% two-handed; on touchscreens edge targets were slower. Thumb-zone maps are opinion. — *study/data* + *convention/opinion* · [Hoober 2017a] [Hoober 2013] [Budiu 2022] [Clark 2015]
- **CT-9 A sticky button only if it earns its space.** Do: if a sticky bar is used on phones: only the primary action, not full-bleed, hidden while the in-page button is visible, never covering footer or legal links.
  Check: scroll with touch and with the keyboard; the bar never fully hides the focused element. — *expert guideline* + *standard/law* · [Laubheimer 2021s] [Baymard 2021] [WCAG 2.2] (2.4.11)
- **CT-10 The cost next to the button.** Do: within one line of the primary action, a true terms line ("Free · 10 dictations a month · Pro optional") whose numbers match the FAQ, the Play listing and the app.
  Check: present, consistent and true. "Free" pulls disproportionately (the zero-price effect), so it must be accurate; not seeing the total cost up front was a reason 12% of surveyed shoppers abandoned checkouts. — *study/data* + *standard/law* · [Shampanier 2007] [Baymard Abandonment] [EC UCPD Guidance 2021]
- **CT-11 Few options where newcomers decide.** Do: at each decision point, one obvious next step and at most one alternative.
  Check: count equal-weight options in each view. Across 50 experiments choice overload averaged about zero, but it appears when people are unsure what they want, the choice is complex and they want minimal effort — the Newcomer's situation. The jam study alone doesn't justify the rule. — *study/data* · [Scheibehenne 2010] [Chernev 2015] [Iyengar 2000] [Moser 2017]
- **CT-12 Don't trust small A/B tests or colour folklore.** Do: don't justify a call to action with an A/B "win" the traffic can't support, or with button-colour stories.
  Check: a cited test has n ≥ 16σ²/δ² per variant (≈ 3,600 visitors per variant to detect 10% → 12%); a surprising lift is a Twyman's-law suspect. About a third of ideas improved their metric at Microsoft (Bing 15%, others 8–10%); at low power, most "significant" wins are false or inflated. — *study/data* · [Kohavi 2013] [Kohavi 2022] [Kohavi 2020]

## 6. App landing page: store badge, desktop, banners, showing the app (AP)

- **AP-1 The official Play badge, unmodified, in the page's language.** Do: use the current badge artwork from Google's Partner Marketing Hub, localized to the page's language.
  Check: the artwork matches the official file — no recolouring, rearranged or rescaled parts, animation or low-resolution copy — and its language matches `<html lang>`. Downloads are driven with the badge, not the Play logo or lockup. The current set (updated 17 Nov 2025) has "Get it on Google Play" in 75 languages, Catalan and Spanish included. — *platform guideline* · [Google PMH Badges]
- **AP-2 Badge size and space.** Do: at least 28 px tall (Google's floor), and in practice as tall as a primary button for touch; clear space of a quarter of its height on every side; at least as large as any other store badge; a plain background.
  Check: the computed height at 320–390 px widths and the space around it. — *platform guideline* · [Google PMH Badges] [WCAG 2.2] (2.5.8)
- **AP-3 The badge links straight to the listing.** Do: link to `https://play.google.com/store/apps/details?id=<applicationId>`; any campaign tags go URL-encoded inside `referrer` (`&referrer=utm_source%3D<source>%26utm_campaign%3D<campaign>`), at most 512 characters, never personal data.
  Check: the `href`; the listing exists for that package; no names, emails or IDs in URLs. Google's Play Games guide gives this format and the 512-character limit; Play Console reports `utm_source` and `utm_campaign`, and the app can read the referrer for 90 days after install. Google's badge page doesn't itself say the badge must link to Play; going straight to the listing is what the badge promises (CT-4). — *platform guideline* · [Play Linking] [Play Install Referrer] [Play Games UA] [Play Acquisition]
- **AP-4 Badge alt text names the action.** Do: the badge image's alt text is the badge's own wording in the page's language, not a description of the picture.
  Check: `<img alt>` present and localized; no file names. — *standard/law* · [WCAG 2.2] (1.1.1)
- **AP-5 Before launch, no badge that goes nowhere.** Do: only two badges exist — "Get it on Google Play" (live apps) and "Pre-register on Google Play" (open pre-registration). Before either applies, say it in plain text ("Coming soon to Android"), without Google artwork.
  Check: the badge type matches the listing's state; no store link returns a 404. The text-only pre-launch line is convention. The pre-register badge exists in Spanish but not in Catalan (Google's set of 49 files, Feb 2024), so a Catalan page during pre-registration needs an owner decision: the Spanish badge, or plain text. — *platform guideline* + *convention/opinion* · [Google PMH Badges] [Play Pre-registration]
- **AP-6 Pre-registration and testers are owner decisions.** Do: raise them as questions. Facts for the owner: pre-registration uses the standard `details?id=<package>` listing URL, runs 90 days from each country's start, ends everywhere if the app launches in none of them, and allows two apps at once; personal developer accounts created after 13 Nov 2023 must first run a closed test with at least 12 testers opted in for 14 consecutive days, then apply for production access (usually reviewed within 7 days); testers join by email list or Google Group. The package name is permanent: Play never deletes or reuses one, and a changed ID uploads as a different app; package names must also be registered under Android developer verification (Play removes unregistered apps from 30 Sep 2026). No Google page says Play rejects `com.example` names, but Google's and Flutter's docs use `com.example` only as a placeholder to replace; the app's ID is `com.example.agenda` (`App/android/app/build.gradle`), so settle it before the first upload.
  Check: not a page check. — *platform guideline* · [Play Pre-registration] [Play Testing req] [Play Closed tests] [Play App setup] [Android App ID] [Flutter Android release] [Play Package names]
- **AP-7 Android only, said plainly.** Do: "for Android" near the primary action; no App Store badge and no `apple-itunes-app` tag.
  Check: present and absent respectively; "Android" never inside the product's name ("TaskFlow for Android" is the allowed form); a page that uses the Android name carries "Android is a trademark of Google LLC." and marks its first "Android" with ™. Google's brand page also asks that creatives using Android or Google trademarks be approved by its Android brand team before use: an owner action, not a page finding. Google's current badge page gives no trademark line for Google Play; "Google Play and the Google Play logo are trademarks of Google LLC" survives only in copies of the retired badge page. — *platform guideline* · [Android Brand] [Google PMH Badges] [Apple Smart Banners]
- **AP-8 Desktop visitors: the badge already reaches the phone.** Do: on desktop, the badge link plus, optionally, a labelled QR code to the same listing; no "text me the link" form.
  Check: any QR code is hidden at phone widths, dark on light in both themes, at least 2 × 2 cm, labelled with where it goes plus a short URL, and decodes to the listing. A signed-in visitor can install from play.google.com straight to their phone; a phone-number form collects personal data. — *platform guideline* + *expert guideline* + *standard/law* · [Play Desktop install] [Kohler 2024] [GDPR]
- **AP-9 No install interstitials.** Do: promote the app inline or with a small banner the visitor can close; never a full-screen overlay or a separate "get the app" page.
  Check: nothing covers the content on load on a phone. Google's search guidance covers app-install prompts; Google+'s interstitial made 69% of visits abandon the page, and a banner in its place raised mobile-web 1-day actives 17% with installs about flat. — *platform guideline* + *study/data* · [Search Interstitials] [Morell 2015]
- **AP-10 Banners and deep links as they are today.** Do: know the limits: Smart App Banners are Safari-on-iOS only (no use to an Android-only app); Firebase Dynamic Links shut down on 25 Aug 2025; the Play Install Referrer is Google's own way to carry context through an install; App Links open an installed app from a link.
  Check: no `page.link` URLs and no Apple banner tag; adding "open in the app" or a native-app install prompt is an owner decision. Chrome's docs still describe that prompt: with `related_applications` naming the Play app and `prefer_related_applications: true`, Android users are sent to Play instead of being offered the web app; Chrome Platform Status lists web/native install banners as enabled, with no deprecation entry (checked Oct 2026). It hasn't been tried on a current phone. — *platform guideline* · [Apple Smart Banners] [Firebase FDL FAQ] [Play Install Referrer] [Android App Links] [Chrome Related apps] [web.dev Install criteria] [Chrome Status Banners]
- **AP-11 Show the app in action, lightly.** Do: real screens; for motion, a short, muted, looping video (MP4 or WebM) rather than a GIF; captions for any narration; key points also in text.
  Check: no large animated GIFs (Google's example: 3.7 MB as GIF vs 551 KB as MP4); `muted playsinline`; a pause control for motion over 5 s; captions (1.2.2). Autoplaying video ads tied for the most disliked ad format on desktop (452 people). — *study/data* + *standard/law* + *expert guideline* · [web.dev GIFs] [Schade 2014v] [Fessenden 2017a] [WCAG 2.2] (2.2.2, 1.2.2)
- **AP-12 Hold the site to the store listing's rules.** Do: real in-app screens in the page's language; no "#1", "best", award or ranking claims; no unattributed testimonials.
  Check: every screenshot is real UI; quotes are attributed. Play requires screenshots of the actual in-app experience and bans ranking claims and unattributed testimonials; applying that to the site is convention, but site and listing must tell one story. — *platform guideline* · [Play Preview assets] [Play Metadata] [Play Listing practices]
- **AP-13 A demo is a taste, not the meal.** Do: the demo teaches one thing quickly (say a thought → see the dated task) and ends with the next step in view; it never replaces the app.
  Check: after a result, the call to action (or the honest "not yet") is visible without scrolling; the demo's limit is stated before use. Rigorous evidence that interactive demos raise installs is thin, so judge the demo by whether it leads to the app. — *expert guideline* · [Budiu 2014] [Kendrick 2020o]

## 7. Trust and proof (TR)

- **TR-1 A real company, one click away.** Do: every footer links to a legal notice with the company's name, address, email, registry details and tax ID (NIF), and to a contact address.
  Check: the link works on every page in all three languages, and the details match `src/content/legal/company.json`. Spain's LSSI requires permanent, easy, direct and free access to this information *(legal check)*; showing a real organisation and making contact easy are credibility guidelines. — *standard/law* + *expert guideline* · [LSSI] (art. 10) [Stanford Guidelines] [Harley 2016]
- **TR-2 Disclose up front.** Do: what's free, what costs, how renewal and cancelling work and what happens to data are on the page, before any commitment.
  Check: each appears outside the Terms. Upfront disclosure is one of NN/g's four trust factors, with design quality, complete and current content, and links to the wider web. — *expert guideline* · [Harley 2016]
- **TR-3 Errors are trust bugs.** Do: no typos, broken links, outdated screenshots or untranslated strings, in any language.
  Check: links, screenshot freshness against the app's renders, and untranslated text on `/es/` and `/ca/`. In a study of 2,684 people, "design look" came up in 46.1% of credibility comments (2002); removing errors and keeping content fresh are credibility guidelines. — *study/data* + *expert guideline* · [Fogg 2002] [Stanford Guidelines]
- **TR-4 Claims you can show.** Do: every claim can be proved by a screenshot or the demo next to it; no superlatives.
  Check: no "best", "#1", "revolutionary" or "the smartest", nor their ES or CA equivalents. Objective wording measured 27% better usability than promotional wording. — *study/data* + *platform guideline* · [Morkes 1997] [Play Metadata]
- **TR-5 Testimonials: real, attributed, or none.** Do: only genuine quotes, each with a name or role and context, and any relationship disclosed; before launch, none rather than a handful.
  Check: no stars, user counts or logos without a source. Users discount a company's own testimonials and trust outside reviews more; small numbers backfire (a participant judged 1,000 shares unpopular). — *expert guideline* · [Harley 2016] [Cardello 2014]
- **TR-6 Reviews: say how they're checked.** Do: anything presented as reviews or ratings says beside it whether and how they're verified; never fake, commissioned or only-positive reviews.
  Check: a verification note or link where reviews appear. EU law requires this information (UCPD art. 7(6)) and blacklists fake reviews (Annex I 23b–23c, from 28 May 2022); publishing only positive reviews counts as misrepresentation. Whether hand-picked testimonials count as reviews is a *(legal check)*. — *standard/law* · [EU 2019/2161] [EC UCPD Guidance 2021]
- **TR-7 Point to independent proof when it exists.** Do: once the app is live, link to the Play listing and its ratings rather than self-hosted praise.
  Check: an owner decision before launch; afterwards, the link is present. Connection to the rest of the web is one of the four trust factors. — *expert guideline* · [Harley 2016]

## 8. Privacy and consent (PV)

- **PV-1 Privacy in plain words, in layers.** Do: the privacy page opens with a short summary — who we are, what we collect and why, people's rights, and anything surprising (voice recordings, the AI provider) — then the detail.
  Check: the summary exists in each language; no vague "may", "might", "some", "often", "possible" («puede», «podría», «algunos», «a menudo», «posible»; «pot», «podria», «alguns», «sovint», «possible»). — *standard/law* + *expert guideline* · [GDPR] (art. 12) [WP260 2018]
- **PV-2 A privacy link on every page.** Do: a "Privacy" link in every footer, named the same everywhere, at normal contrast.
  Check: present on home, legal and 404 pages, and not shrunk, faded or buried. A link made hard to see by its position or colour doesn't count as easily accessible. — *expert guideline* · [WP260 2018]
- **PV-3 A just-in-time note before the microphone.** Do: before the demo opens the microphone, one line: up to 60 s, where the audio goes (including the AI provider), how long it's kept, that typing works too, and a link to details.
  Check: `getUserMedia` runs only after a tap next to that note, and the typing option is visible there. Keep it short: in one survey experiment, making privacy salient, even favourably, made people more reluctant to share data. — *standard/law* + *expert guideline* + *study/data* · [GDPR] (art. 13) [WP260 2018] [Marreiros 2017]
- **PV-4 Stay banner-free by design.** Do: store only what's strictly necessary plus preferences the visitor chooses (theme, language); no third-party trackers.
  Check: in a fresh browser profile, no third-party requests and no storage keys beyond essential and preference ones. Spain's AEPD: preferences the user picks are exempt, and if everything is exempt no consent or cookie notice is needed; the ePrivacy rule covers scripts, pixels and IP-based tracking, not only cookies. — *standard/law* + *expert guideline* · [AEPD Cookies 2023] [LSSI] (art. 22.2) [EDPB 2/2023]
- **PV-5 If consent is ever needed, Reject is as easy as Accept.** Do: Accept all and Reject all on the first layer, with the same size, style and contrast; no pre-ticked boxes; a permanent way to change the choice; nothing loads before consent.
  Check: the banner and a footer "Cookie settings" link. — *standard/law* + *expert guideline* · [EDPB Cookie 2023] [AEPD Cookies 2023] [CNIL FAQ]
- **PV-6 "Cookieless" isn't automatically consent-free in Spain.** Do: treat any analytics as an owner decision backed by a written legal assessment.
  Check: no analytics script or beacon fires in a fresh session unless that decision is recorded. Spain's rule covers cookies, similar technologies and fingerprinting. Since January 2024 the AEPD lets audience measurement skip consent only under strict conditions: the site's own audience only, anonymous statistics, a set list of measures, no cross-site tracking or sharing, visitors told (the privacy policy will do), cookies kept ≤ 13 months and data ≤ 25 months, and an art. 28 contract with any provider. Its 2023 guidance for public-sector sites also describes analytics from server logs with truncated IPs. CNIL's exemption is French law, and vendors' "no banner needed" claims settle nothing; whether a tool meets the AEPD's terms is a *(legal check)*. — *standard/law* + *expert guideline* · [AEPD Audience 2024] [AEPD Cookies 2023] [AEPD AAPP 2023] [CNIL Audience] [EDPB 2/2023]
- **PV-7 Account deletion in one step.** Do: a deletion page linked from every footer in each language that names the app as Google Play shows it, gives the steps, says what's deleted and kept and for how long, and takes a request without reinstalling the app.
  Check: the links work in all three languages, and the page matches the app and the privacy policy. Google Play requires such a web link for apps that let people create accounts (extended deadline 31 May 2024): it must load, name the app or developer as the listing does, make the request path prominent, take a request without the app, and spell out any extra step such as cancelling a subscription. Play asks only that retention be disclosed, and the privacy policy will do; saying on the page what's deleted and kept, and for how long, is TaskFlow's bar, in line with GDPR art. 13. — *platform guideline* + *standard/law* · [Play Deletion] [Play User Data] [GDPR] (art. 13)

## 9. Pricing and fairness (PR)

- **PR-1 The full price, as Google Play shows it.** Do: Pro's price with currency, billing period and tax included, matching Play; a yearly plan leads with its yearly total.
  Check: each price shows amount, currency, period and a VAT note in ES, CA and EN; no yearly plan is presented mainly as a monthly price, which Play lists as a violation. — *standard/law* + *platform guideline* · [CRD] (art. 6) [UCPD] (art. 7(4)) [Play Subscriptions] [LSSI] (art. 10)
- **PR-2 What Free includes, and what happens at the limit.** Do: say "10 dictations a month", what still works after the limit (as the app does it) and when it resets, wherever Free or Pro is mentioned.
  Check: the difference between Free and Pro is readable without expanding anything. Play forbids hiding that an app is usable without subscribing; no study tests how to word a usage cap. — *platform guideline* + *expert guideline* · [Play Subscriptions] [Nielsen 2006p]
- **PR-3 "Free" only when it's free.** Do: qualify every "free", «gratis», «gratuït»; any trial states its length, the price afterwards, automatic renewal and how to cancel.
  Check: every "free" on the page. The Commission's guidance reports national authorities' view that "free" fits only apps whose in-app purchases are optional. — *standard/law* + *platform guideline* · [EC UCPD Guidance 2021] [Play Subscriptions]
- **PR-4 Renewal and cancelling beside the price.** Do: say that Pro renews automatically and is cancelled in Google Play, in the pricing block itself.
  Check: renewal and the cancel path appear beside the price, not only in the Terms; cancelling should be as easy as subscribing. Who owes the EU withdrawal function and the "order with obligation to pay" button for subscriptions billed by Play is a *(legal check)*. Facts for the owner: from 19 June 2026, CRD art. 11a requires the trader that concludes a contract online to offer a function labelled "withdraw from contract here"; no Spanish transposition was found by 18 Oct 2026 (EUR-Lex lists none; the BOE consumer law consolidated on 28 Feb 2026 lacks it); the button rule is CRD art. 8(2), in Spain TRLGDCU art. 98.2 («pedido con obligación de pago»); and in the EEA, Play's terms make Google Commerce Limited the contracting party for Play purchases, with Google the merchant of record in Spain. — *standard/law* + *platform guideline* · [CRD] [EU 2023/2673] [EU 2023/2673 NIM] [BOE TRLGDCU] [Play ToS 2025] [Play Merchant of Record] [EC UCPD Guidance 2021]
- **PR-5 Compare plans in a small, static table.** Do: if Free and Pro are compared, a static table of 5 rows or fewer with the same attributes for each, check and cross marks, and plain words.
  Check: legible at 390 px; "not included" marks readable in both themes. — *expert guideline* · [Moran 2024c]
- **PR-6 No pressure tactics.** Do: no countdowns, "today only", stock or seat counts, pop-ups that come back after closing, guilt-tripping decline text or pre-ticked options.
  Check: none present. 97% of popular EU websites and apps had at least one dark pattern (73 of 75 checked, 2022); a 2023 sweep found fake timers, steering or hidden information on 148 of 399 shops. — *standard/law* + *study/data* · [EC UCPD Guidance 2021] [EC Dark patterns 2022] [EC Sweep 2023]
- **PR-7 Every alternative gets equal weight.** Do: Decline, "Not now" and Reject are buttons with the same size, style and readable contrast as Accept, in neutral words.
  Check: compare styles and wording side by side. — *standard/law* + *expert guideline* · [EC UCPD Guidance 2021] [EDPB Cookie 2023] [Rosala 2023]
- **PR-8 Cite the right law.** Do: judge the site under the UCPD and consumer law. DSA art. 25 binds online platforms only and exempts micro and small enterprises; the Digital Fairness Act is only announced (indicative Q4 2026).
  Check: findings cite the instrument that applies; legal questions go to the owner. — *standard/law* · [UCPD] [DSA] [EP DFA 2026]

## 10. FAQs (FQ)

- **FQ-1 Real questions, candid answers.** Do: questions in the visitor's words; answers that start with the answer and admit limits (Android only, the free limit).
  Check: each answer's first sentence answers it; a question that keeps recurring should prompt a fix elsewhere on the page. — *expert guideline* · [Farrell 2014]
- **FQ-2 Essentials outside the accordion.** Do: the price, the free limit, cancelling and voice privacy are readable without opening anything.
  Check: with every FAQ item closed, those facts still appear on the page. Accordions suit independent questions people need only a few of, and hurt when people need most of the content. — *expert guideline* · [Farrell 2014] [Wang 2023]
- **FQ-3 Accordions that work for everyone.** Do: native `<details>`/`<summary>` or the APG accordion pattern; several items open at once; a caret; on phones the open item's heading stays visible, with no disorienting jump.
  Check: if not `<details>`, a `<button aria-expanded aria-controls>` inside a heading, toggled by Enter and Space. — *standard/law* + *expert guideline* · [WCAG 2.2] (4.1.2) [APG Accordion] [Wang 2023] [Budiu 2015a]

## 11. Reading and legibility (RD)

- **RD-1 Conclusion first.** Do: each section and FAQ answer starts with its point (the inverted pyramid); one idea per paragraph.
  Check: the first sentence under each heading states the section's point; no paragraph covers two features. — *study/data* + *expert guideline* · [Morkes 1997] [Schade 2018]
- **RD-2 Half the words.** Do: cut copy to about half of what a brochure would use.
  Check: report the word count of the first viewport and of the whole page, before → after; on phones keep paragraphs to about 3 lines (convention). Concise text measured 58% better usability (51 users, 1997); each extra 100 words buys only about 4.4 s of reading. — *study/data* · [Morkes 1997] [Nielsen 2008]
- **RD-3 Plain language.** Do: sentences of about 15–20 words, a reading level around grades 6–8 for a general audience, jargon defined or avoided, and no idioms or puns in any language.
  Check: average sentence length ≤ 20 words; no unexplained jargon. — *expert guideline* · [Loranger 2017p] [COGA 2021]
- **RD-4 Comfortable line length.** Do: body text of about 50–75 characters per line, left-aligned, never justified.
  Check: text containers have a max-width of about 60–70ch; no line passes 80 characters at 1440 px in any language; no `text-align: justify`. The research is mixed: in a study Dyson's review reports, the longest lines (about 100 characters) were read fastest but 55 characters was rated easiest; in Dyson and Haselgrove's test (36 people), 55 characters gave better comprehension than 100 and was read as fast or faster. — *study/data* + *expert guideline* · [Dyson 2004] [Dyson 2001] [Baymard 2022] [WCAG 2.2] (1.4.8)
- **RD-5 Body text large enough.** Do: body text ≥ 16 CSS px in rem or em; small print ≥ 12 px. For the Newcomer, 17–18 px body text is a judgement call, not a sourced figure.
  Check: computed sizes of `p`, `li` and captions. No official minimum exists: the browser default is usually 16 px; Lighthouse's legible-font-size audit was removed in Lighthouse 13; Apple's default body text is 17 pt and Material's largest body style 16 sp; NN/g asks sites for seniors to use at least 12-point text by default. Studies of older readers give no figure that transfers to today's screens: 14-point text beat 12-point on a 2001 desktop, and on a 2005 handheld 61–78-year-olds read as well at any size above 6 point and preferred 9–12 point (24 people). — *expert guideline* + *convention/opinion* + *study/data* · [MDN font-size] [Lighthouse font-size] [Apple Typography] [Material Type scale] [Nielsen 2013] [Bernard 2001] [Darroch 2005]
- **RD-6 Spacing that survives overrides.** Do: body line height about 1.5, unitless; nothing breaks when people increase spacing.
  Check: computed line-height ÷ font-size ≥ 1.5 (convention); with WCAG's text-spacing values injected (1.5 line height, 2× paragraph spacing, 0.12 letter spacing, 0.16 word spacing) nothing clips, especially Spanish and Catalan buttons. — *standard/law* + *expert guideline* · [WCAG 2.2] (1.4.12) [web.dev Typography]
- **RD-7 Links that say where they go.** Do: every link and button is specific, sincere, substantial and succinct, with the keywords first.
  Check: list every link and button text; each makes sense alone; no bare "Learn more", "More" or "Click here". People estimate a link's value from its label and surroundings (information scent). — *standard/law* + *expert guideline* · [WCAG 2.2] (2.4.4) [Moran 2019] [Budiu 2020] [Pirolli 1999]

## 12. Navigation and footer (NV)

- **NV-1 Navigation people can see.** Do: on desktop, top-level links stay visible (no hamburger at 1024 px and wider); on phones, about 4 visible items at most, and the primary action is never only inside a menu.
  Check: the desktop and mobile renders, menu closed. Hidden navigation was used 27% of the time on desktop vs 48–50% when visible, and 57% on phones vs 86% for visible-plus-menu; tasks took at least 39% longer on desktop (179 people, 2016). — *study/data* · [Pernice 2016a]
- **NV-2 Logo at the top left, linking home.** Do: the logo sits at the top left and links to the home page in the current language.
  Check: its position and `href`. With a centred logo, people were 6 times as likely to fail to reach the home page in one click (50 people, 2016). — *study/data* · [Whitenton 2016]
- **NV-3 A small, opaque sticky header.** Do: if the header is sticky, keep it small and opaque, and never let it cover anchor targets or the focused element.
  Check: `scroll-margin-top` or `scroll-padding-top` at least the header's height; after an anchor jump the section heading shows; focus is never fully hidden. — *expert guideline* + *standard/law* · [Laubheimer 2021s] [Schade 2017a] [WCAG 2.2] (2.4.11)
- **NV-4 In-page links look in-page.** Do: anchor links read as "on this page", their text matches the target heading, and Back returns the visitor to where they were.
  Check: header anchors look different from links to other pages; NN/g advises against mixing in-page links into the main navigation area. In a later small study most people understood in-page links (2 of 11 didn't use them). — *expert guideline* · [Schade 2017a] [Wang 2023i]
- **NV-5 Back to top only on very long pages.** Do: add one only when a page runs past about 4 screens; label it in words ("Back to top"), lower right.
  Check: full-page height ÷ viewport height > 4; the 4-screen threshold isn't backed by data. — *expert guideline* · [Loranger 2017b]
- **NV-6 Same tab by default.** Do: open links in the same tab; where a new tab is justified, say so visibly and in the accessible name.
  Check: each `target="_blank"`. Mobile users were more annoyed by new tabs, and 45% of seniors struggled with tabs and windows (2013). — *expert guideline* + *study/data* · [Nielsen 2020t] [Nielsen 2013]
- **NV-7 One complete footer everywhere.** Do: the same footer on every page: contact, privacy, terms, legal notice, account deletion, the language switcher and the company name.
  Check: present and working on home, legal and 404 pages in all three languages; help and contact links keep the same relative order on every page (3.2.6). People look in footers for contact, company and legal information. — *expert guideline* + *standard/law* · [Fessenden 2019f] [WCAG 2.2] (3.2.6)
- **NV-8 Familiar patterns in familiar places.** Do: logo top left, navigation and language switcher at the top, legal links in the footer.
  Check: each unconventional pattern needs a stated reason; people expect a site to work like the ones they already use (Jakob's law). — *expert guideline* · [Nielsen 2017j] [Laubheimer 2024]

## 13. Performance (PF)

- **PF-1 Pass Core Web Vitals at p75 on mobile.** Do: LCP ≤ 2.5 s, INP ≤ 200 ms and CLS ≤ 0.1 at the 75th percentile of page loads, with mobile and desktop judged separately (poor: > 4 s, > 500 ms, > 0.25).
  Check: PageSpeed Insights field data (CrUX: the previous 28 days, Chrome only) if it exists; new or low-traffic pages may have none, so use lab LCP, TBT and CLS and say so. The thresholds are unchanged as of Oct 2026; INP replaced FID on 12 Mar 2024. — *platform guideline* · [web.dev Vitals] [web.dev LCP] [web.dev INP] [web.dev CLS] [PSI About] [Search CWV]
- **PF-2 Say which evidence you have.** Do: label every speed finding as field (CrUX or real-user monitoring) or lab (Lighthouse simulating a mid-tier phone).
  Check: the finding names its source. A lab run is one device, one network and one run, and can't predict interaction timing; TBT stands in for INP. LCP and INP became measurable in all major browsers in Dec 2025, but CrUX stays Chrome-only. — *platform guideline* · [web.dev Lab vs field] [PSI About] [web.dev Baseline 2025]
- **PF-3 The hero element is in the HTML and loads first.** Do: the LCP element is server-rendered; if it's an image, it isn't lazy-loaded, carries `fetchPriority="high"` or `loading="eager"`, has a correct `sizes`, and is AVIF or WebP.
  Check: name the LCP element and read its attributes in code. In Next.js 16 `priority` is deprecated, and `preload` is advised against when different images are the LCP at different widths. — *platform guideline* · [web.dev Optimize LCP] [Next.js Image]
- **PF-4 Reserve space for everything that loads.** Do: `width` and `height` (or `fill` in a sized parent) on every image and video; space reserved for demo results and banners.
  Check: lab CLS ≤ 0.1; nothing is inserted above existing content. Shifts within 500 ms of a tap or keypress don't count. — *platform guideline* · [web.dev CLS] [Next.js Image]
- **PF-5 Fonts that don't move the page.** Do: self-hosted fonts loaded so text doesn't reflow; Next.js recommends `next/font`, variable fonts and subsets.
  Check: no requests to fonts.googleapis.com; no visible reflow when the font arrives. — *platform guideline* · [Next.js Fonts]
- **PF-6 Little client JavaScript.** Do: `'use client'` only on interactive leaf components; third-party scripts only on the pages that need them, loaded late.
  Check: no `'use client'` at layout or page level; no needless scripts in the root layout; low lab TBT. An interaction's delay is input delay + processing + presentation, mostly main-thread work. — *platform guideline* · [Next.js Server/Client] [Next.js Scripts] [web.dev Optimize INP]
- **PF-7 Speed is part of the first impression.** Do: rate slow loading and sluggish interactions as UX findings, judged for the Newcomer on a mid-range Android phone on mobile data.
  Check: severity reflects the main path. Evidence, strongest first: Google's delay experiments (100–400 ms more cut searches by 0.2–0.6%, 2009); Vodafone's A/B test (LCP 31% faster → 8% more sales, 2021); Google and Deloitte's observational study of 37 brands (0.1 s faster on mobile → +8.4% retail conversions, +10.1% travel, 2020); Chrome's analysis (sites meeting the thresholds saw 24% fewer loads abandoned before first paint, 2020). — *study/data* · [Brutlag 2009] [Vodafone 2021] [Deloitte 2020] [Chromium 2020]
- **PF-8 The demos answer at once and explain waits.** Do: every tap answers within 0.1 s; after about 1 s a moving indicator that names the step; after about 10 s an explanation and a way forward (typing) that keeps what was said.
  Check: each demo state and its timers. These are rules of thumb, not measured limits. — *expert guideline* · [Nielsen 1993]

## 14. Accessibility (AX)

- **AX-1 Target WCAG 2.2 AA.** Do: review against WCAG 2.2 (W3C Recommendation of 5 Oct 2023; edition of 12 Dec 2024; ISO/IEC 40500:2025); never raise 4.1.1 Parsing, which is obsolete.
  Check: findings cite each criterion's number and level correctly. Whether the European Accessibility Act or Spain's Ley 11/2023 covers TaskFlow is a *(legal check)*. Facts for the owner: both apply from 28 June 2025 and cover e-commerce services; both exempt microenterprises that provide services (fewer than 10 staff, and turnover or balance sheet ≤ €2 M; EAA art. 4(5), Ley 11/2023 art. 3.3); Google is the merchant of record for Play sales in Spain (PR-4). The EAA's standard EN 301 549 V4.1.1 (Sept 2026, aligned with WCAG 2.2) gives a presumption of conformity only once it's cited in the Official Journal, and no citation was found by 18 Oct 2026. — *standard/law* · [WCAG 2.2] [EAA] [Ley 11/2023] [EN 301 549 V4.1.1] [Play Merchant of Record]
- **AX-2 Contrast, measured, in both themes.** Do: text 4.5:1, or 3:1 only for large text (≥ 24 CSS px, or ≥ 18.5 px bold); controls, focus rings and meaningful graphics 3:1; light and dark alike; ratios are never rounded.
  Check: measure body, muted, placeholder and caption text, footer links, text over screenshots and the theme switch. Low-contrast text was the most common failure on the top million home pages (83.9%, 2026), and it hurts legibility and credibility most for older eyes. — *standard/law* + *study/data* · [WCAG 2.2] (1.4.3, 1.4.11) [WebAIM Million 2026] [Sherwin 2015l]
- **AX-3 Zoom, reflow and spacing.** Do: nothing lost at 200% text; no two-direction scrolling at 320 CSS px wide; WCAG's text spacing survives.
  Check: 320 px and 200% in code or renders; Spanish and Catalan labels not clipped. — *standard/law* · [WCAG 2.2] (1.4.4, 1.4.10, 1.4.12)
- **AX-4 Focus visible, never hidden.** Do: a visible focus indicator (aim for a 2 px outline at 3:1) that sticky headers, sticky buttons and banners never fully cover.
  Check: tab through the page in both themes. — *standard/law* · [WCAG 2.2] (2.4.7, 2.4.11, 2.4.13)
- **AX-5 Structure in the markup.** Do: landmarks, a skip link, descriptive headings in order, one descriptive `h1` (a convention, not a WCAG requirement), and a unique, translated `<title>` per page.
  Check: the heading outline; the skip link appears on focus. — *standard/law* + *convention/opinion* · [WCAG 2.2] (1.3.1, 2.4.1, 2.4.2, 2.4.6)
- **AX-6 Alt text says what the screen shows.** Do: each screenshot's alt text gives what it shows and why it's there; decorative images get `alt=""`.
  Check: no missing alt, no file names, alt translated. Missing alt text was found on 53.1% of the top million home pages (2026). — *standard/law* + *study/data* · [WCAG 2.2] (1.1.1) [WAI Images] [WebAIM Million 2026]
- **AX-7 Motion the visitor controls.** Do: nothing moves by itself for more than 5 s without a pause; nothing flashes more than 3 times a second; honour `prefers-reduced-motion` (2.3.3 is AAA: TaskFlow policy, not an AA requirement).
  Check: a `@media (prefers-reduced-motion: reduce)` block that stops decorative and demo animation. — *standard/law* · [WCAG 2.2] (2.2.2, 2.3.1, 2.3.3) [WCAG C39]
- **AX-8 Words on controls.** Do: the theme, microphone, language and menu controls show text; accessible names contain the visible label; tooltips can be dismissed and hovered; nothing works only by hover or drag.
  Check: accessible names in code. Only a few icons are universally understood. — *standard/law* + *expert guideline* · [WCAG 2.2] (2.5.3, 4.1.2, 1.4.13, 2.5.7) [Harley 2014]
- **AX-9 Announce what the demo does.** Do: recording, progress, results and errors that appear without moving focus are announced.
  Check: `role="status"` (or `alert`, `log`) on the demo's changing text. — *standard/law* · [WCAG 2.2] (4.1.3)
- **AX-10 The microphone: ask on a tap, explain first, recover from "no".** Do: ask for the microphone only after a labelled tap, with one line on why; always offer typing; show recording clearly, with a visible 60 s countdown and a Stop button.
  Check: no `getUserMedia` on load; plain recovery steps for `NotAllowedError`, `NotFoundError` and `NotReadableError` in three languages. Chrome data: prompts without a user gesture were allowed 12% of the time vs 30% after one. — *platform guideline* · [web.dev Permissions] [MDN getUserMedia]
- **AX-11 Automated checks are only the start.** Do: run axe or Lighthouse, then check by keyboard, screen reader and zoom.
  Check: the report separates automated from manual evidence. The best of 10 tools found 41% of 143 planted barriers; overlay widgets don't make a site compliant (the FTC made a $1 M order against such claims final in April 2025). — *study/data* · [GOV.UK 2017] [FTC 2025]
- **AX-12 Forms: labels, paste, nothing asked twice.** Do: the demo's text box and any future form have visible labels, accept paste and autofill, and never ask twice for what was given.
  Check: a `<label>` for each input; no paste blocking; no one-box-per-digit code fields if sign-in ever comes to the web. — *standard/law* · [WCAG 2.2] (3.3.2, 3.3.7, 3.3.8)

## 15. Older and non-technical visitors (OL)

- **OL-1 Expect slower, error-prone visits.** Do: every step can be undone or retried; nothing depends on one exact action.
  Check: what follows a wrong tap at each step. In 2013 users aged 65+ succeeded 55.3% of the time vs 74.5% for ages 21–55, were 43% slower and made 2.4 vs 1.1 errors per task; the 2019 round found more confidence but the same trouble with tiny type, pale text and small targets. — *study/data* · [Nielsen 2013] [Kane 2019]
- **OL-2 Never imply fault.** Do: limits and errors say what happened and what to do next, never "invalid", "wrong" or "not allowed".
  Check: every demo error and limit string in three languages. Seniors blamed themselves for problems 90% of the time (younger users 58%) and were almost twice as likely to give up. — *study/data* · [Nielsen 2013]
- **OL-3 Visible choices, not dropdowns or sliders.** Do: language and plan choices as visible links or buttons, not `<select>` menus or sliders.
  Check: no `<select>` language switcher; W3C prefers plain links when there are only a few languages, and older users struggle with pull-down menus. — *expert guideline* · [WAI-AGE 2008] [W3C Select nav]
- **OL-4 Use COGA as the cognitive lens.** Do: a clear page purpose, familiar design, clear words, labelled icons and few interruptions.
  Check: tag cognitive findings with the COGA objective they break; ageing reduces contrast sensitivity, dexterity, memory and attention, and WCAG covers most older users' needs. — *expert guideline* · [COGA 2021] [W3C Older users]

## 16. Languages, search and link previews (ML)

- **ML-1 One URL per language; never a forced redirect.** Do: stable `/es/`, `/ca/` and English URLs; only the bare root may choose a language, from `Accept-Language` (never IP), and the visitor can always switch.
  Check: a page requested with another browser language still serves its own language, status 200. — *platform guideline* + *expert guideline* · [Google Multi-regional] [W3C Conneg]
- **ML-2 `lang` right everywhere.** Do: `<html lang>` matches the route (`es`, `ca`, `en`); passages in another language are marked; each language name in the switcher carries its own `lang`.
  Check: the page source; never `es-CA` (Spanish for Canada) or `cat`. In 2026, 13.5% of the top million home pages declared no page language. — *standard/law* + *expert guideline* · [WCAG 2.2] (3.1.1, 3.1.2) [W3C Lang decl] [LoC ISO 639] [WebAIM Million 2026]
- **ML-3 hreflang complete and reciprocal.** Do: on every version, `<link rel="alternate" hreflang>` for `es`, `ca`, `en` and `x-default` in `<head>`, with absolute https URLs, including the page itself.
  Check: identical sets on each version. Google ignores tags that aren't reciprocal, and detects a page's language from its visible content, not from `lang` or hreflang. — *platform guideline* · [Google Localized versions]
- **ML-4 A language switcher people find.** Do: in the header of every page (on phones in the header or menu, not only the footer), each language named in itself (Español, Català, English), no flags, keeping the visitor on the same page and remembering the choice.
  Check: the renders and the switcher's link targets. — *expert guideline* · [W3C Conneg] [Liu 2022]
- **ML-5 Translate everything.** Do: nothing in English on `/es/` or `/ca/`: alt text, aria-labels, titles, meta and Open Graph tags, consent text, demo output, screenshots and legal pages.
  Check: render and source review per language. 76% of consumers prefer product information in their language and 40% never buy from sites in other languages (self-reported, 8,709 people, 29 countries, 2020). — *study/data* + *platform guideline* · [CSA 2020] [Play Listing practices]
- **ML-6 Written for each language.** Do: copy adapted by a fluent speaker (examples, idioms, one form of address), not translated word for word; machine translation only with native review; features named as the app names them in that language.
  Check: each version reads naturally and uses the app's terms from its ARB files. Localization means adapting to a market, beyond translation; Google Play says translation by native speakers is best. — *expert guideline* + *platform guideline* · [W3C i18n def] [Play Translation]
- **ML-7 Room to grow.** Do: layouts that flex for Spanish and Catalan; no fixed widths around text.
  Check: buttons, the badge row and navigation at 320 px and 200% text in ES and CA. Short strings grow most: up to 10 characters, 200–300% of the English length. — *expert guideline* · [W3C Text size]
- **ML-8 A title per page and language.** Do: each page and language has its own descriptive `<title>` and description, with the brand at the start or end of inner-page titles.
  Check: no duplicated or "Home" titles; each translated. — *platform guideline* + *standard/law* · [Google Title links] [WCAG 2.2] (2.4.2)
- **ML-9 A link preview that sells, in the page's language.** Do: `og:title`, `og:description` (1–2 sentences), `og:image` and `og:url` per page and language, with `og:locale` and its alternates; the image shows the product and the promise, legible as a small thumbnail.
  Check: the page `<head>` and the `opengraph-image` render. The Newcomer often meets TaskFlow first as a shared-link preview. — *convention/opinion* · [OGP]

## 17. The funnel: promise kept, continuity, measurement (FN)

- **FN-1 Every claim is true today.** Do: each statement about what TaskFlow does, costs, supports or stores maps to the app as it is now, in the app's words; Pro-only features say so.
  Check: the reviewer's claims inventory, claim by claim. EU law bans misleading claims about a product's main characteristics, and Play requires accurate, current descriptions and imagery. — *standard/law* + *platform guideline* · [UCPD] (art. 6) [Play Deceptive] [Play Metadata]
- **FN-2 The app's names for things.** Do: name features as the app does in each language, so visitors recognise them after installing.
  Check: compare each feature name with the app's ARB strings. People predict where a link leads from its words, and a link is a promise. — *expert guideline* · [Budiu 2020] [Pernice 2014]
- **FN-3 What the site shows first, the app shows first.** Do: the hero screenshot and the demo's steps match the app's first run and main loop.
  Check: compare them with the app's current first-run renders. — *expert guideline* · [Pernice 2014] [Kendrick 2020o]
- **FN-4 The demo sets honest expectations.** Do: the demo's timing, accuracy, limits and failures reflect the app; it's never faster, smarter or more forgiving than the app.
  Check: compare the demo's states with the app's capture flow. A demo that answers instantly and never fails makes the real app feel broken (the owner's critique, `../CRITIQUE.md` P6). — *expert guideline* + *standard/law* · [Pernice 2014] [UCPD] (art. 6)
- **FN-5 The site teaches, so the app's first run can stay short.** Do: explain features on the site; don't propose site content that copies in-app onboarding.
  Check: per NN/g, most apps need no instructional onboarding and features are better promoted on the store page or in context; in a 70-person test a tutorial didn't improve success. — *study/data* + *expert guideline* · [Kendrick 2020o] [Kendrick 2020t] [Laubheimer 2023]
- **FN-6 Free and Pro, described as the app describes them.** Do: limits, prices and plan names match the app's paywall and the Play product.
  Check: compare with the app's strings and Play's offer terms. — *platform guideline* · [Play Subscriptions]
- **FN-7 Learn without analytics first.** Do: recommend small test rounds (about 5 people per distinct group, including people over 65), 5-second and first-click tests, and reading support email.
  Check: a recommendation that needs data names its method. "Five users find about 85% of problems" is a model of one homogeneous group; real 5-user sets found 55–99%; across 12 usability studies of different websites, tasks succeeded 87% of the time when the first click was right vs 46% when it was wrong (Bailey's practitioner data, about 2009, not peer-reviewed). — *study/data* · [Nielsen 2000t] [Faulkner 2003] [Bailey 2009] [Perfetti 2007]
- **FN-8 Play Console is the first funnel data.** Do: once the app is live, use Play Console's acquisition reports (store listing visitors → clicks → acquisitions, by traffic source, with `utm_source` and `utm_campaign` for tagged links) and store listing experiments.
  Check: Play links carry campaign names only. — *platform guideline* · [Play Acquisition] [Play Experiments]
- **FN-9 Analytics is the owner's decision.** Do: never add analytics in a review; raise it as a question with the options: none (rely on tests, support email and Play Console); server logs (nothing runs in the browser; the AEPD's public-sector guidance describes log analytics with IPs truncated on import); an audience-measurement tool that meets the AEPD's January 2024 exemption (strict conditions, PV-6); consent-based analytics (a banner adds friction for older visitors). The EU's Digital Omnibus would add an audience-measurement exemption to EU law, but it's still in negotiation: the Council's June 2026 draft mandate moves the cookie rules back into the ePrivacy Directive, and Parliament's committee vote was still pending in Oct 2026.
  Check: not a page check. *(legal check)* — *expert guideline* + *standard/law* · [AEPD Audience 2024] [AEPD AAPP 2023] [AEPD Cookies 2023] [EDPB 2/2023] [CNIL Audience] [Digital Omnibus 2025] [Council 10729/26]

## 18. Myths to avoid

- **"Nobody scrolls."** 43% of desktop viewing time fell below the first screen (2018); people scroll when what they see promises value. [Fessenden 2018] [Budiu 2023]
- **"The fold is dead" and "put everything above the fold."** The drop at the fold held from 2010 to 2018; prioritise the top and lead down, because crowding raises complexity and lowers appeal. [Nielsen 2010s] [Schade 2015] [Tuch 2012]
- **"57% and 74% are phone figures."** They're desktop (1920 × 1080). [Fessenden 2018] [Lagun 2014]
- **"Users decide in 50 ms, so content doesn't matter."** Those studies rated the looks of still screenshots; visitors screen a page over roughly its first 10–30 s. [Lindgaard 2006] [Tuch 2012] [Liu 2010]
- **"You have exactly 10 seconds" and "five seconds is a scientific window."** The first is NN/g's reading of an averaged curve, the second a test convention. [Nielsen 2011d] [Kuric 2024]
- **"Attention spans are 8 seconds, shorter than a goldfish's."** It traces to a 2015 Microsoft Canada report citing a source nobody could find. [BBC 2017]
- **"People read in a Z-pattern" and "the Gutenberg diagram applies to web pages."** Newspaper and design-blog lore with no web eye-tracking behind it; web data show a top-left entry and attention on the left half. [Faulkes 2016] [Holsanova 2006] [Fessenden 2017h]
- **"Design for the F-pattern."** It's the symptom of unformatted text, bad for users and business. [Pernice 2017]
- **"People look at pictures first."** On web pages headlines and text often lead; faces are the exception. [Poynter 2004] [Jiang 2023] [Cerf 2009]
- **"A face always helps; the baby-ad heatmap proves it."** A face looking at the viewer takes attention from the message; the baby heatmap is an unpublished 2009 blog demo. [Sajjacholapunt 2014] [Palcu 2017]
- **"Bigger, brighter or animated means noticed" and "banner blindness means ads are never seen."** Ad-like salience gets dodged, yet most people do fixate an ad at least once; animated banners were then recognised no better than chance, though text ads matching the page were remembered better. [Pernice 2018] [Burke 2005] [Hervet 2011]
- **"Mouse heatmaps show gaze" and "AI heatmaps are over 90% accurate."** The cursor trails the eyes by about 700 ms; vendor accuracy comes from general-image benchmarks; classic models fit interfaces poorly. [Huang 2012] [Leiva 2020] [Jiang 2023]
- **"The 3-click rule."** No data supports it; users didn't quit more after 3 clicks than after 12. [Porter 2003] [Laubheimer 2019]
- **"Seven, plus or minus two, so menus need ≤ 7 items."** Menus rely on recognition, not recall; working memory holds about 4 chunks anyway. [Nielsen 2009m] [Cowan 2001]
- **"Fewer choices always convert better" (the jam study).** The meta-analytic average is about zero; it depends on conditions. [Scheibehenne 2010] [Chernev 2015] [Moser 2017]
- **"Red, orange or green buttons convert better."** The famous test survives only in reposts; contrast and salience matter, not hue. [Kohavi 2013]
- **"Just A/B test it."** That needs thousands to tens of thousands of users; underpowered wins are often false or inflated. [Kohavi 2022]
- **"More calls to action, more conversions" and "Get Started clicks mean success."** Repetition in one place weakens each; misled clicks count as conversions. [Nielsen 2001h] [Harley 2017]
- **"Ghost buttons are fine if they pass WCAG."** They're weak signifiers. [Moran 2017f]
- **"Bottom-edge buttons are always easiest" and "thumb-zone maps are proof."** Edges are less accurate on touchscreens; the maps are opinion. [Budiu 2022] [Hoober 2017a]
- **"Install interstitials raise installs."** 69% abandoned the page; installs held steady after a banner replaced it. [Morell 2015]
- **"GIFs are light."** 3.7 MB as a GIF, 551 KB as MP4. [web.dev GIFs]
- **"Flags are fine for languages" and "redirect by IP."** Flags stand for countries; guessing from IP isn't helpful; always let people switch. [W3C Conneg] [Google Multi-regional]
- **"`lang` and hreflang tell Google the language" and "machine translation is penalised as such."** Google reads the visible content; its spam policy targets mass-produced low-value pages, however made. [Google Localized versions] [Google Spam]
- **"No cookies, no consent question" and "CNIL's exemption applies in Spain."** Spain's rule covers similar technologies and fingerprinting; CNIL's exemption is French, and the AEPD's own (January 2024) is narrow, with conditions to meet. [AEPD Cookies 2023] [AEPD Audience 2024] [EDPB 2/2023] [CNIL Audience]
- **"DSA art. 25 bans dark patterns everywhere" and "the Digital Fairness Act applies."** Art. 25 binds platforms; the DFA is only announced; the UCPD is what applies. [DSA] [EP DFA 2026] [EC UCPD Guidance 2021]
- **"Testimonials always help" and "46% of people judge credibility by design."** Users discount self-hosted praise, and fake reviews are illegal; 46.1% was a share of comments in 2002, not of people. [Harley 2016] [EU 2019/2161] [Fogg 2002]
- **"Five users find 85% of problems."** Only in a model of one homogeneous group; real 5-user sets found 55–99%. [Nielsen 2000t] [Faulkner 2003]
- **"Speed only matters on slow networks" and "the thresholds tightened in 2026."** 100–400 ms already cut searches; INP is main-thread work; the thresholds are unchanged. [Brutlag 2009] [Search CWV]
- **"Bounce rises 32% from 1 to 3 s" and "53% leave after 3 s" as measured facts.** The first is a model's output, the second 2016 analytics. [An 2017]
- **"Use `priority` on the hero image."** Deprecated in Next.js 16. [Next.js Image]
- **"Overlays make a site compliant" and "Lighthouse 100 means accessible."** The FTC made a $1 M order over such claims final in April 2025; the best automated tool found 41% of barriers. [FTC 2025] [GOV.UK 2017]
- **"Every image needs descriptive alt text."** Decorative images get `alt=""`. [WAI Images]
- **"Ask for the microphone on load so the demo is ready."** 12% allowed without a gesture vs 30% after one. [web.dev Permissions]
- **"Mobile users are always on the go."** 77% of mobile searches happened at home or work (2013, industry diary study), though phone sessions are often interrupted. [Google Mobile Moments 2013]
- **"Long pages don't convert."** No rigorous study either way; don't cite it.

## 19. Corrections to the reviewer's current citations

Read with `.claude/agents/web-ux-reviewer.md`, "Checklist" lenses A–O.
- **Lens J: "targets at least 44–48 px, never under 24 px (WCAG 2.2, 2.5.8)".** 2.5.8 (AA) asks for 24 × 24 CSS px and allows smaller targets under its spacing, equivalent, inline, user-agent and essential exceptions; 44 × 44 is 2.5.5 (AAA) and Apple's size; 48 is Android's dp. Keep 44–48 px as TaskFlow's bar, cite it to those sources, and don't report links inside sentences as 2.5.8 failures. (CT-6)
- **Lens J: "within thumb reach".** Thumb-zone maps are opinion; Hoober's 2017 data show taps are most accurate at the centre (≈ 7 mm) and least at the corners (≈ 12 mm). (CT-8)
- **Lens K: "one `h1`".** A convention, not a WCAG criterion; WCAG asks for structure in the markup (1.3.1) and descriptive headings (2.4.6). (AX-5)
- **Lens K: "reduced motion respected" under WCAG 2.2 AA.** 2.3.3 Animation from Interactions is AAA. The level-A motion criteria are 2.2.2 (pause, stop or hide motion over 5 s) and 2.3.1 (flashes). Keep reduced motion as TaskFlow's policy, cited as AAA. (AX-7)
- **Lens K: "3:1 for large text and controls".** Large text is ≥ 18 pt (≈ 24 CSS px) or ≥ 14 pt bold (≈ 18.5 CSS px), and ratios aren't rounded. 1.4.11 asks 3:1 only for what identifies a control or its state, so a ghost button can pass WCAG and still be a weak signifier. (AX-2, CT-5)
- **Lens A: "gets it in about five seconds".** The 5-second test is a practitioner convention (Perfetti, about 2005), not a measured threshold; dwell-time data put the critical window at about 10 s. Use it as a test, not a law. (AT-7, §21 step 5)
- **Lens F: "above the fold".** The 57% / 74% figures are desktop data (1920 × 1080, 2018). For phones cite Lagun 2014 (≈ 70% of gaze on the top half, search tasks). (AT-1, AT-2)
- **Lens L: "progress beyond about 1 s, an explanation beyond about 10 s".** Nielsen's rules of thumb (1993): right for the demos. Page loading is judged by Core Web Vitals at p75 (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1). (PF-1, PF-8)
- **Lens I: "Google Play requires a deletion link".** Correct. Play also requires that the page load, name the app or developer as on the listing, make the request path prominent and work without reinstalling the app. Retention must be disclosed, but the privacy policy will do; saying on the page what is deleted and kept is TaskFlow's bar (GDPR art. 13), not Play's. (PV-7)
- **Lens M: "hreflang alternates and `lang`".** Add `x-default`. Google detects a page's language from its visible content, not from `lang` or hreflang, so tags can't fix untranslated text; `lang` is for assistive technology (3.1.1). (ML-2, ML-3, ML-5)

## 20. Sources

Keys are alphabetical. Entries shared with the app's guide use the same key and wording. "Updated" gives the date shown on the page.

- [AEPD AAPP 2023] Orientaciones sobre cookies y analítica web en portales de las Administraciones Públicas (v. Feb 2023; log-based analytics with truncated IPs) — Agencia Española de Protección de Datos — 2023 — https://www.aepd.es/guias/orientaciones-analitica-web-aapp.pdf
- [AEPD Audience 2024] Uso de cookies para herramientas de medición de audiencia (v. Jan 2024; conditions for a consent exemption) — Agencia Española de Protección de Datos — 2024 — https://www.aepd.es/guias/guia-cookies-analiticas-externas.pdf
- [AEPD Cookies 2023] Guía sobre el uso de las cookies (July 2023 update, applicable from 11 Jan 2024; re-issued May 2024 with the same text on these points and an annex pointing to the audience-measurement guide: https://www.aepd.es/guias/guia-cookies.pdf) — Agencia Española de Protección de Datos — 2023 — https://www.aepd.es/sites/default/files/2020-07/guia-cookies.pdf
- [An 2017] Find Out How You Stack Up to New Industry Benchmarks for Mobile Page Speed — Daniel An, Think with Google (Google/SOASTA model; the "53%" figure is 2016 analytics) — 2017 — https://thinkwithgoogle.com/_qs/documents/57/mobile-page-speed-new-industry-benchmarks.pdf
- [Android App ID] Configure the app module: set the application ID (never change it after publishing) — Android Developers — current — https://developer.android.com/build/configure-app-module
- [Android App Links] Android App Links: overview and Digital Asset Links setup — Android Developers — updated 2026 — https://developer.android.com/training/app-links (and https://developer.android.com/training/app-links/configure-assetlinks)
- [Android Brand] Brand guidelines (the "for Android" form, the Android trademark line, brand-team approval) — Android Developers — updated 2026 — https://developer.android.com/distribute/marketing-tools/brand-guidelines
- [Android Touch targets] Touch target size — Google Android Accessibility Help — undated — https://support.google.com/accessibility/android/answer/7101858
- [APG Accordion] Accordion Pattern — W3C WAI ARIA Authoring Practices Guide — current — https://www.w3.org/WAI/ARIA/apg/patterns/accordion/
- [Apple Buttons] Buttons — Apple Human Interface Guidelines — updated 2025 — https://developer.apple.com/design/human-interface-guidelines/buttons
- [Apple Smart Banners] Promoting Apps with Smart App Banners — Apple Developer Documentation — current — https://developer.apple.com/documentation/webkit/promoting-apps-with-smart-app-banners
- [Apple Typography] Typography — Apple Human Interface Guidelines (read through its data file) — current — https://developer.apple.com/design/human-interface-guidelines/typography
- [Bailey 2009] FirstClick Usability Testing — Bob Bailey, Computer Psychology (webusability.com; practitioner data from 12 usability studies, not peer-reviewed; also cited by Sauro, MeasuringU, 2011: https://measuringu.com/first-click/) — about 2009 (first archived 25 Apr 2009) — http://webusability.com/article_first_click_usability_testing.html (read via the Internet Archive: https://web.archive.org/web/20090705212946/http://webusability.com/article_first_click_usability_testing.html)
- [Baymard 2021] 35 Data-Driven Ecommerce Best Practices — Christian Holst, Baymard Institute — 2021 — https://baymard.com/blog/ecommerce-ux-best-practices
- [Baymard 2022] Readability: The Optimal Line Length — Edward Scott, Baymard Institute — 2022 — https://baymard.com/blog/line-length-readability
- [Baymard Abandonment] Cart Abandonment Rate Statistics — Baymard Institute (survey of US online shoppers; sample, year and base not published on the page; the 2023 version gave 21% for the cost reason) — updated 22 Sep 2025 — https://baymard.com/lists/cart-abandonment-rate
- [BBC 2017] Busting the attention span myth — Simon Maybin, BBC News (*More or Less*, 10 Mar 2017) — 2017 — https://www.bbc.com/news/health-38896790
- [Bernard 2001] The effects of font type and size on the legibility and reading time of online text by older adults — Bernard, Liao & Mills, CHI '01 Extended Abstracts — 2001 — https://doi.org/10.1145/634067.634173 ‡
- [BOE TRLGDCU] Real Decreto Legislativo 1/2007 (consumer law; arts. 62, 97, 98) — BOE, consolidated 28 Feb 2026 — 2007 — https://www.boe.es/buscar/act.php?id=BOE-A-2007-20555
- [Brutlag 2009] Speed Matters for Google Web Search — Jake Brutlag, Google (randomised delay experiments; technical report) — 2009 — https://services.google.com/fh/files/blogs/google_delayexp.pdf
- [Budiu 2014] The Reciprocity Principle: Give Before You Take in Web Design — Raluca Budiu, NN/g — 2014 — https://www.nngroup.com/articles/reciprocity-principle/
- [Budiu 2014l] Login Walls Stop Users in Their Tracks — Raluca Budiu, NN/g — 2014 — https://www.nngroup.com/articles/login-walls/
- [Budiu 2015a] Accordions on Mobile — Raluca Budiu, NN/g — 2015 — https://www.nngroup.com/articles/mobile-accordions/
- [Budiu 2020] Information Scent: How Users Decide Where to Go Next — Raluca Budiu, NN/g — 2020 — https://www.nngroup.com/articles/information-scent/
- [Budiu 2022] Fitts's Law and Its Applications in UX — Raluca Budiu, NN/g — 2022 — https://www.nngroup.com/articles/fitts-law/
- [Budiu 2023] The State of Mobile User Experience — Raluca Budiu, NN/g — 2023 — https://www.nngroup.com/articles/state-mobile-ux/
- [Burke 2005] High-cost banner blindness: Ads increase perceived workload, hinder visual search, and are forgotten — Burke, Hornof, Nilsen & Gorman, ACM TOCHI 12(4) — 2005 — https://doi.org/10.1145/1121112.1121116 (figures from the authors' manuscript: https://thoughtcrumbs.com/publications/ToCHI04.pdf)
- [Buscher 2009] What Do You See When You're Surfing? Using Eye Tracking to Predict Salient Regions of Web Pages — Buscher, Cutrell & Morris, CHI — 2009 — https://www.microsoft.com/en-us/research/publication/what-do-you-see-when-youre-surfing-using-eye-tracking-to-predict-salient-regions-of-web-pages/
- [Cardello 2014] Social Proof in the User Experience — Jen Cardello, NN/g — 2014 — https://www.nngroup.com/articles/social-proof-ux/
- [Cerf 2009] Faces and text attract gaze independent of the task: Experimental data and computer model — Cerf, Frady & Koch, Journal of Vision 9(12) — 2009 — https://authors.library.caltech.edu/40670
- [Chernev 2015] Choice overload: a conceptual review and meta-analysis — Chernev, Böckenholt & Goodman, Journal of Consumer Psychology 25(2):333–358 (99 observations, N = 7,202) — 2015 — https://doi.org/10.1016/j.jcps.2014.08.002 ‡
- [Chrome Related apps] getInstalledRelatedApps() (Chrome capabilities documentation) — Chrome for Developers — updated 2026 — https://developer.chrome.com/docs/capabilities/get-installed-related-apps
- [Chrome Status Banners] Web/native app install banners; beforeinstallprompt event for web/native app install banners — Chrome Platform Status (both "Enabled by default", no deprecation entry; checked 18 Oct 2026) — current — https://chromestatus.com/feature/4540065577435136 (and https://chromestatus.com/feature/6560913322672128)
- [Chromium 2020] The Science Behind Web Vitals — Sagoo, Sullivan & Sekhar, Chromium Blog — 2020 — https://blog.chromium.org/2020/05/the-science-behind-web-vitals.html (read through the blog's feed)
- [Clark 2015] How We Hold Our Gadgets (excerpt from *Designing for Touch*) — Josh Clark, A List Apart — 2015 — https://alistapart.com/article/how-we-hold-our-gadgets/
- [CNIL Audience] Cookies : solutions pour les outils de mesure d'audience — CNIL — 2025 — https://www.cnil.fr/fr/cookies-solutions-pour-les-outils-de-mesure-daudience
- [CNIL FAQ] Cookies and other trackers: FAQ (Q37–38; in French) — CNIL — updated 2026 — https://www.cnil.fr/fr/cookies-et-autres-traceurs/regles/cookies/FAQ
- [COGA 2021] Making Content Usable for People with Cognitive and Learning Disabilities — W3C COGA Task Force, Working Group Note — 2021 — https://www.w3.org/TR/coga-usable/
- [Council 10729/26] Digital Omnibus: mandate for negotiations with the European Parliament (note to Coreper, 22 June 2026; deletes the proposed GDPR art. 88a and amends ePrivacy art. 5(3)) — Council of the European Union — 2026 — https://data.consilium.europa.eu/doc/document/ST-10729-2026-INIT/en/pdf
- [Cowan 2001] The magical number 4 in short-term memory: a reconsideration of mental storage capacity — Nelson Cowan, Behavioral and Brain Sciences 24(1):87–114 — 2001 — https://doi.org/10.1017/S0140525X01003922 (read via Cambridge's free copy: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/44023F1147D4A1D44BDC0AD226838496/S0140525X01003922a.pdf/div-class-title-the-magical-number-4-in-short-term-memory-a-reconsideration-of-mental-storage-capacity-div.pdf)
- [CRD] Directive 2011/83/EU on consumer rights (arts. 6, 8) — EU — 2011 — https://eur-lex.europa.eu/eli/dir/2011/83/oj/eng
- [CSA 2020] Consumers Prefer their Own Language (press release on *Can't Read, Won't Buy – B2C*) — CSA Research (survey fielded by Kantar) — 2020 — https://csa-research.com/Blogs-Events/CSA-in-the-Media/Press-Releases/Consumers-Prefer-their-Own-Language
- [Darroch 2005] The Effect of Age and Font Size on Reading Text on Handheld Computers — Darroch, Goodman, Brewster & Gray, INTERACT (LNCS 3585) — 2005 — https://doi.org/10.1007/11555261_23
- [Deloitte 2020] Milliseconds Make Millions (summary) — Google, 55 and Deloitte, on web.dev — 2020 — https://web.dev/case-studies/milliseconds-make-millions
- [Digital Omnibus 2025] Proposal for a Digital Omnibus, COM(2025) 837 (proposed GDPR art. 88a) — European Commission — 2025 — https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=celex:52025PC0837 (procedure 2025/0360(COD), "Awaiting committee decision" in Parliament on 18 Oct 2026: https://oeil.europarl.europa.eu/oeil/en/procedure-file?reference=2025/0360(COD))
- [DSA] Regulation (EU) 2022/2065, Digital Services Act (arts. 3, 19, 25) — EU — 2022 — https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32022R2065
- [Dyson 2001] The influence of reading speed and line length on the effectiveness of reading from screen — Dyson & Haselgrove, International Journal of Human-Computer Studies 54(4):585–612 — 2001 — https://doi.org/10.1006/ijhc.2001.0458 (read via an Internet Archive capture of the authors' copy: https://web.archive.org/web/20230330022557/https://psychology.nottingham.ac.uk/staff/mxh/Papers/Dyson%20&%20Haselgrove%20(2001).pdf)
- [Dyson 2004] How physical text layout affects reading from screen — Mary C. Dyson, Behaviour & Information Technology 23(6) — 2004 — https://doi.org/10.1080/01449290410001715714 (read via https://stu.westga.edu/~ssynan1/literacy/Dyson.pdf)
- [EAA] Directive (EU) 2019/882, European Accessibility Act — EU — 2019 — https://eur-lex.europa.eu/eli/dir/2019/882/oj/eng
- [EC Dark patterns 2022] Behavioural study on unfair commercial practices in the digital environment: dark patterns and manipulative personalisation — Lupiáñez-Villanueva et al., European Commission (mystery shopping of 75 sites and apps; experiment with 7,430 people) — 2022 — https://op.europa.eu/en/publication-detail/-/publication/606365bc-d58b-11ec-a95f-01aa75ed71a1/language-en
- [EC Sweep 2023] Manipulative online practices found on 148 out of 399 online shops screened (IP/23/418) — European Commission — 2023 — https://ec.europa.eu/commission/presscorner/detail/en/ip_23_418
- [EC UCPD Guidance 2021] Guidance on the interpretation and application of Directive 2005/29/EC (Notice 2021/C 526/01; §§ 2.9.6, 4.2.4, 4.2.7, 4.2.9) — European Commission — 2021 — https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52021XC1229(05)
- [EDPB 2/2023] Guidelines 2/2023 on Technical Scope of Art. 5(3) of ePrivacy Directive, v2.0 — EDPB — 2024 — https://www.edpb.europa.eu/system/files/documents/2024-10/edpb_guidelines_202302_technical_scope_art_53_eprivacydirective_v2_en_0.pdf
- [EDPB Cookie 2023] Report of the work undertaken by the Cookie Banner Taskforce — EDPB — 2023 — https://www.edpb.europa.eu/system/files/2023-01/edpb_20230118_report_cookie_banner_taskforce_en.pdf
- [EN 301 549 V4.1.1] Accessibility requirements for ICT products and services, EN 301 549 V4.1.1 (2026-09; adopted 24 Aug 2026) — ETSI, CEN and CENELEC — 2026 — https://www.etsi.org/deliver/etsi_en/301500_301599/301549/04.01.01_60/en_301549v040101p.pdf
- [EP DFA 2026] Legislative Train: Digital Fairness Act — European Parliament — 2026 — https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act
- [EU 2019/2161] Directive (EU) 2019/2161, the "Omnibus" Directive (UCPD art. 7(6); Annex I 23b–23c) — EU — 2019 — https://eur-lex.europa.eu/eli/dir/2019/2161/oj/eng
- [EU 2023/2673] Directive (EU) 2023/2673 (new art. 11a of the Consumer Rights Directive) — EU — 2023 — https://eur-lex.europa.eu/eli/dir/2023/2673/oj/eng
- [EU 2023/2673 NIM] National transposition measures for Directive (EU) 2023/2673 (none listed for Spain) — EUR-Lex — checked 18 Oct 2026 — https://eur-lex.europa.eu/legal-content/EN/NIM/?uri=CELEX:32023L2673
- [Farrell 2014] FAQs Still Deliver Great Value — Susan Farrell, NN/g — 2014 — https://www.nngroup.com/articles/faqs-deliver-value/
- [Faulkes 2016] Reading gravity (blog post on the Gutenberg diagram) — Zen Faulkes, Better Posters — 2016 — https://betterposters.substack.com/p/reading-gravity-16-09-08 (also a 1999 W3C mailing-list post: https://lists.w3.org/Archives/Public/www-style/1999Nov/0114.html)
- [Faulkner 2003] Beyond the five-user assumption: Benefits of increased sample sizes in usability testing — Laura Faulkner, Behavior Research Methods, Instruments & Computers 35(3) — 2003 — https://link.springer.com/article/10.3758/BF03195514
- [Fessenden 2017a] The Most Hated Online Advertising Techniques — Therese Fessenden, NN/g — 2017 — https://www.nngroup.com/articles/most-hated-advertising-techniques/
- [Fessenden 2017f] First Impressions Matter — Therese Fessenden, NN/g — 2017 — https://www.nngroup.com/articles/first-impressions-human-automaticity/
- [Fessenden 2017h] Horizontal Attention Leans Left — Therese Fessenden, NN/g — 2017 (22 Oct 2017; no later update as of Oct 2026) — https://www.nngroup.com/articles/horizontal-attention-leans-left/
- [Fessenden 2018] Scrolling and Attention — Therese Fessenden, NN/g — 2018 — https://www.nngroup.com/articles/scrolling-and-attention/
- [Fessenden 2019f] Footers 101: Design Patterns and When to Use Each — Therese Fessenden, NN/g — 2019 — https://www.nngroup.com/articles/footers/
- [Firebase FDL FAQ] Dynamic Links deprecation FAQ — Firebase (Google) — updated 2026 — https://firebase.google.com/support/dynamic-links-faq
- [Flaherty 2016] The Illusion of Completeness — Kim Flaherty, NN/g — 2016 — https://www.nngroup.com/articles/illusion-of-completeness/
- [Flaherty 2017z] Zigzag Image–Text Layouts Make Scanning Less Efficient — Kim Flaherty, NN/g — 2017 — https://www.nngroup.com/articles/zigzag-page-layout/
- [Flutter Android release] Build and release an Android app (the application ID can't change after the first Play upload) — Flutter docs — current — https://docs.flutter.dev/deployment/android
- [Fogg 2002] How Do People Evaluate a Web Site's Credibility? — Fogg, Soohoo, Danielson, Marable, Stanford & Tauber, Consumer WebWatch and Stanford — 2002 — https://advocacy.consumerreports.org/research/how-do-people-evaluate-a-web-sites-credibility
- [Frischen 2007] Gaze cueing of attention: visual attention, social cognition, and individual differences — Frischen, Bayliss & Tipper, Psychological Bulletin 133(4) — 2007 — https://pmc.ncbi.nlm.nih.gov/articles/PMC1950440
- [FTC 2025] accessiBe to pay $1 million over claims that its AI tool makes websites accessibility-compliant: proposed order (3 Jan 2025) and final order approved 22 Apr 2025 — US Federal Trade Commission — 2025 — https://www.ftc.gov/legal-library/browse/cases-proceedings/2223156-accessibe-inc (Jan 2025 press release: https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-order-requires-online-marketer-pay-1-million-deceptive-claims-its-ai-product-could-make-websites)
- [GDPR] Regulation (EU) 2016/679 (arts. 4, 12, 13) — EU — 2016 — https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng
- [Google Localized versions] Tell Google about localized versions of your page — Google Search Central — updated 2026 — https://developers.google.com/search/docs/specialty/international/localized-versions
- [Google Mobile Moments 2013] Mobile Search Moments — Google/Nielsen (industry diary study, 416 people) — 2013 — https://services.google.com/fh/files/misc/mobile-search-ppt.pdf
- [Google Multi-regional] Managing multi-regional and multilingual sites — Google Search Central — updated 2025 — https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites
- [Google PMH Badges] Lockups, icons & badges (Google Play) — Google Partner Marketing Hub — undated; "Get it on Google Play" files updated 17 Nov 2025 (75 languages), "Pre-register" files 15 Feb 2024 (49 files, no Catalan) — https://partnermarketinghub.withgoogle.com/brands/google-play/google-play/lockups-icons-badges/ (play.google.com/intl/en_us/badges/ redirects here)
- [Google Spam] Spam policies for Google web search (scaled content abuse) — Google Search Central — updated 2026 — https://developers.google.com/search/docs/essentials/spam-policies
- [Google Title links] Influencing your title links in search results — Google Search Central — updated 2025 — https://developers.google.com/search/docs/appearance/title-link
- [GOV.UK 2017] What we found when we tested tools on the world's least-accessible webpage — Mehmet Duran, GOV.UK Accessibility blog — 2017 — https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/
- [GOV.UK Button] Button — GOV.UK Design System — current — https://design-system.service.gov.uk/components/button/
- [Hansen 2010] Truth From Language and Truth From Fit: The Impact of Linguistic Concreteness and Level of Construal on Subjective Truth — Hansen & Wänke, Personality and Social Psychology Bulletin 36(11) — 2010 — https://doi.org/10.1177/0146167210386238
- [Harley 2014] Icon Usability — Aurora Harley, NN/g — 2014 — https://www.nngroup.com/articles/icon-usability/
- [Harley 2016] Trustworthiness in Web Design: 4 Credibility Factors — Aurora Harley, NN/g — 2016 — https://www.nngroup.com/articles/trustworthy-design/
- [Harley 2017] "Get Started" Stops Users — Aurora Harley & Kim Flaherty, NN/g — 2017 — https://www.nngroup.com/articles/get-started/
- [Harley 2019] Touch Targets on Touchscreens — Aurora Harley, NN/g — 2019 — https://www.nngroup.com/articles/touch-target-size/
- [Hervet 2011] Is banner blindness genuine? Eye tracking internet text advertising — Hervet, Guérard, Tremblay & Chtourou, Applied Cognitive Psychology 25(5):708–716 — 2011 — https://doi.org/10.1002/acp.1742 ‡
- [Holsanova 2006] Entry points and reading paths on newspaper spreads: comparing a semiotic analysis with eye-tracking measurements — Holsanova, Rahm & Holmqvist, Visual Communication 5(1) — 2006 — https://lup.lub.lu.se/record/793207
- [Hoober 2013] How Do Users Really Hold Mobile Devices? — Steven Hoober, UXmatters — 2013 — https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
- [Hoober 2017a] Design for Fingers, Touch, and People, Part 1 — Steven Hoober, UXmatters — 2017 — https://www.uxmatters.com/mt/archives/2017/03/design-for-fingers-touch-and-people-part-1.php
- [Hoober 2017c] Design for Fingers, Touch, and People, Part 3 — Steven Hoober, UXmatters — 2017 — https://www.uxmatters.com/mt/archives/2017/07/design-for-fingers-touch-and-people-part-3.php
- [Huang 2012] User see, user point: gaze and cursor alignment in web search — Huang, White & Buscher, CHI — 2012 — https://microsoft.com/en-us/research/wp-content/uploads/2012/01/Final_GazeCursor_CHI12.pdf
- [Iyengar 2000] When choice is demotivating: can one desire too much of a good thing? — Iyengar & Lepper, Journal of Personality and Social Psychology 79(6) — 2000 — https://faculty.washington.edu/jdb/345/345%20Articles/Iyengar%20&%20Lepper%20(2000).pdf
- [Jiang 2023] UEyes: Understanding Visual Saliency across User Interface Types — Jiang, Leiva, Rezazadegan Tavakoli et al., CHI — 2023 — https://doi.org/10.1145/3544548.3581096 (read via https://arxiv.org/html/2402.05202v1)
- [Kane 2019] Usability for Older Adults: Challenges and Changes — Lexie Kane, NN/g — 2019 — https://www.nngroup.com/articles/usability-for-senior-citizens/
- [Kendrick 2020o] Mobile-App Onboarding: An Analysis of Components and Techniques — Alita Kendrick, NN/g — 2020 — https://www.nngroup.com/articles/mobile-app-onboarding/
- [Kendrick 2020t] Mobile Tutorials: Wasted Effort or Efficiency Boost? — Alita Kendrick, NN/g — 2020 — https://www.nngroup.com/articles/mobile-tutorials/
- [Kohavi 2013] Online Controlled Experiments at Large Scale — Kohavi, Deng, Frasca, Walker, Xu & Pohlmann, KDD — 2013 — https://exp-platform.com/Documents/2013%20controlledExperimentsAtScale.pdf
- [Kohavi 2020] Trustworthy Online Controlled Experiments: A Practical Guide to A/B Testing — Kohavi, Tang & Xu, Cambridge University Press — 2020 — https://experimentguide.com/
- [Kohavi 2022] A/B Testing Intuition Busters: Common Misunderstandings in Online Controlled Experiments — Kohavi, Deng & Vermeer, KDD — 2022 — https://airbnb.tech/wp-content/uploads/sites/19/2025/10/ABTestingIntuitionBusters.pdf
- [Kohler 2024] 13 QR-Code Usability Guidelines — Tanner Kohler, NN/g — 2024 — https://www.nngroup.com/articles/qr-code-guidelines/
- [Kuric 2024] Cognitive abilities and visual complexity impact first impressions in five-second testing — Kuric, Demcak, Krajcovic & Nguyen, Behaviour & Information Technology 43(13):3209–3236 (120 people; open access) — 2024 (online 2023) — https://doi.org/10.1080/0144929X.2023.2272747
- [Kurosu 1995] Apparent usability vs. inherent usability: experimental analysis on the determinants of the apparent usability — Kurosu & Kashimura, CHI '95 Conference Companion, pp. 292–293 — 1995 — https://doi.org/10.1145/223355.223680 (read via https://chi1995.acm.org/proceedings/shortppr/mk_bdy.htm)
- [Lagun 2014] Towards Better Measurement of Attention and Satisfaction in Mobile Search — Lagun, Hsieh, Webster & Navalpakkam, SIGIR — 2014 — https://research.google.com/pubs/archive/43224.pdf
- [Laubheimer 2019] The 3-Click Rule for Navigation Is False — Page Laubheimer, NN/g — 2019 — https://www.nngroup.com/articles/3-click-rule/
- [Laubheimer 2021s] Sticky Headers: 5 Ways to Make Them Better — Page Laubheimer, NN/g — 2021 — https://www.nngroup.com/articles/sticky-headers/
- [Laubheimer 2023] Onboarding Tutorials vs. Contextual Help — Page Laubheimer, NN/g — 2023 — https://www.nngroup.com/articles/onboarding-tutorials/
- [Laubheimer 2023ia] 3 Common IA Mistakes — Page Laubheimer, NN/g — 2023 — https://www.nngroup.com/articles/3-ia-mistakes/
- [Laubheimer 2024] Menu-Design Checklist: 17 UX Guidelines — Page Laubheimer, NN/g — 2024 — https://www.nngroup.com/articles/menu-design/
- [Leiva 2020] Understanding Visual Saliency in Mobile User Interfaces — Leiva, Xue, Bansal, Tavakoli, Köroğlu, Du, Dayama & Oulasvirta, MobileHCI, pp. 1–12 — 2020 — https://doi.org/10.1145/3379503.3403557 (read via arXiv: https://arxiv.org/abs/2101.09176)
- [Ley 11/2023] Ley 11/2023, de 8 de mayo (Title I transposes the European Accessibility Act) — BOE — 2023 — https://www.boe.es/buscar/act.php?id=BOE-A-2023-11022
- [Lighthouse font-size] Document doesn't use legible font sizes (audit removed in Lighthouse 13) — Chrome for Developers — current — https://developer.chrome.com/docs/lighthouse/seo/font-size
- [Lindgaard 2006] Attention web designers: You have 50 milliseconds to make a good first impression! — Lindgaard, Fernandes, Dudek & Brown, Behaviour & Information Technology 25(2) — 2006 — https://doi.org/10.1080/01449290500330448 (abstract read; the correlations come from Tuch 2012; sample sizes not found, no open full text) ‡
- [Liu 2010] Understanding Web Browsing Behaviors through Weibull Analysis of Dwell Time — Liu, White & Dumais, SIGIR — 2010 — https://www.microsoft.com/en-us/research/wp-content/uploads/2010/10/dwelltime.pdf
- [Liu 2022] 6 Tips for Improving Language Switchers on Ecommerce Sites — Feifei Liu, NN/g — 2022 — https://www.nngroup.com/articles/language-switching-ecommerce/
- [LoC ISO 639] ISO 639-2 code list (ca, es) — Library of Congress — current — https://www.loc.gov/standards/iso639-2/php/code_list.php
- [Loranger 2014r] Related Content Boosts Pageviews, When Done Right — Hoa Loranger, NN/g — 2014 — https://www.nngroup.com/articles/related-content-pageviews/
- [Loranger 2015c] Beyond Blue Links — Hoa Loranger, NN/g — 2015 — https://www.nngroup.com/articles/clickable-elements/
- [Loranger 2015h] Headings Are Pick-Up Lines: 5 Tips for Writing Headlines That Convert — Hoa Loranger, NN/g — 2015 — https://www.nngroup.com/articles/headings-pickup-lines/
- [Loranger 2017b] Back-to-Top Button Design Guidelines — Hoa Loranger, NN/g — 2017 — https://www.nngroup.com/articles/back-to-top/
- [Loranger 2017m] Microcontent: A Few Small Words Have a Mega Impact on Business — Hoa Loranger & Jakob Nielsen, NN/g — 2017 — https://www.nngroup.com/articles/microcontent-how-to-write-headlines-page-titles-and-subject-lines/
- [Loranger 2017p] Plain Language Is for Everyone, Even Experts — Hoa Loranger, NN/g — 2017 — https://www.nngroup.com/articles/plain-language-experts/
- [LSSI] Ley 34/2002, de servicios de la sociedad de la información y de comercio electrónico (arts. 10, 22) — BOE, consolidated 2025 — 2002 — https://www.boe.es/buscar/act.php?id=BOE-A-2002-13758
- [Lyssna 2023] Five second testing guide — Lyssna (vendor; formerly UsabilityHub) — 2023 — https://www.lyssna.com/guides/five-second-testing/
- [M3 Structure] Accessibility designing: structure (touch targets ≥ 48 × 48 dp, 8 dp apart) — Material Design 3 — current — https://m3.material.io/foundations/designing/structure
- [Marreiros 2017] "Now that you mention it": a survey experiment on information, inattention and online privacy — Marreiros, Tonin, Vlassopoulos & schraefel, Journal of Economic Behavior & Organization 140:1–17 — 2017 — https://doi.org/10.1016/j.jebo.2017.03.024 (abstract: https://eprints.soton.ac.uk/id/eprint/410764/) ‡
- [Material Type scale] Typography (Material Components for Android documentation) — Google — current — https://raw.githubusercontent.com/material-components/material-components-android/master/docs/theming/Typography.md
- [MDN font-size] font-size — MDN Web Docs — current — https://developer.mozilla.org/en-US/docs/Web/CSS/font-size
- [MDN getUserMedia] MediaDevices: getUserMedia() method — MDN Web Docs — updated 2025 — https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia
- [Moran 2016] Reading Content on Mobile Devices — Kate Moran, NN/g — 2016 — https://www.nngroup.com/articles/mobile-content/
- [Moran 2017b] Flat-Design Best Practices — Kate Moran, NN/g — 2017 — https://www.nngroup.com/articles/flat-design-best-practices/
- [Moran 2017f] Flat UI Elements Attract Less Attention and Cause Uncertainty — Kate Moran, NN/g — 2017 — https://www.nngroup.com/articles/flat-ui-less-attention-cause-uncertainty/
- [Moran 2019] Better Link Labels: 4Ss for Encouraging Clicks — Kate Moran, NN/g — 2019 — https://www.nngroup.com/articles/better-link-labels/
- [Moran 2020r] How People Read Online: New and Old Findings — Kate Moran, NN/g — 2020 — https://www.nngroup.com/articles/how-people-read-online/
- [Moran 2024a] The Aesthetic-Usability Effect — Kate Moran, NN/g — 2024 (reviewed 2026) — https://www.nngroup.com/articles/aesthetic-usability-effect/
- [Moran 2024c] Comparison Tables for Products, Services, and Features — Kate Moran & Taylor Dykes, NN/g — 2024 — https://www.nngroup.com/articles/comparison-tables/
- [Morell 2015] Google+: A case study on App Download Interstitials — David Morell, Google Search Central Blog — 2015 — https://developers.google.com/search/blog/2015/07/google-case-study-on-app-download-interstitials
- [Morkes 1997] Concise, SCANNABLE, and Objective: How to Write for the Web — John Morkes & Jakob Nielsen, NN/g — 1997 — https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/
- [Moser 2017] No Such Thing as Too Much Chocolate: Evidence Against Choice Overload in E-Commerce — Moser, Phelan, Resnick, Schoenebeck & Reinecke, CHI — 2017 — https://wildlab.cs.washington.edu/Publications_files/Moser_CHI2017.pdf
- [Next.js Fonts] Fonts (Getting Started) — Next.js documentation — 2026 — https://nextjs.org/docs/app/getting-started/fonts
- [Next.js Image] Image component (`next/image`) API reference — Next.js documentation — updated 2026 — https://nextjs.org/docs/app/api-reference/components/image
- [Next.js Scripts] Scripts guide — Next.js documentation — 2026 — https://nextjs.org/docs/app/guides/scripts
- [Next.js Server/Client] Server and Client Components — Next.js documentation — 2026 — https://nextjs.org/docs/app/getting-started/server-and-client-components
- [Nielsen 1993] Response Times: The 3 Important Limits — Jakob Nielsen, NN/g (from *Usability Engineering*) — 1993, updated 2014 — https://www.nngroup.com/articles/response-times-3-important-limits/
- [Nielsen 1994s] Severity Ratings for Usability Problems — Jakob Nielsen, NN/g — 1994 — https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/
- [Nielsen 1997] How Users Read on the Web — Jakob Nielsen, NN/g — 1997 — https://www.nngroup.com/articles/how-users-read-on-the-web/
- [Nielsen 2000t] Why You Only Need to Test with 5 Users — Jakob Nielsen, NN/g — 2000 — https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/
- [Nielsen 2001h] 113 Design Guidelines for Homepage Usability — Jakob Nielsen, NN/g — 2001 — https://www.nngroup.com/articles/113-design-guidelines-homepage-usability/
- [Nielsen 2001t] Tagline Blues: What's the Site About? — Jakob Nielsen, NN/g — 2001 — https://www.nngroup.com/articles/tagline-blues-whats-the-site-about/
- [Nielsen 2006] Progressive Disclosure — Jakob Nielsen, NN/g — 2006 — https://www.nngroup.com/articles/progressive-disclosure/
- [Nielsen 2006f] F-Shaped Pattern For Reading Web Content (original study) — Jakob Nielsen, NN/g — 2006 — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content-discovered/
- [Nielsen 2006p] Show Prices for Common Scenarios — Jakob Nielsen, NN/g — 2006 — https://www.nngroup.com/articles/show-prices-for-common-scenarios/
- [Nielsen 2007b] Banner Blindness: The Original Eyetracking Research — Jakob Nielsen, NN/g — 2007 — https://www.nngroup.com/articles/banner-blindness-original-eyetracking/
- [Nielsen 2008] How Little Do Users Read? — Jakob Nielsen, NN/g (data from Weinreich et al., ACM TWeb 2008) — 2008 — https://www.nngroup.com/articles/how-little-do-users-read/
- [Nielsen 2009m] Short-Term Memory and Web Usability — Jakob Nielsen, NN/g — 2009 — https://www.nngroup.com/articles/short-term-memory-and-web-usability/
- [Nielsen 2009w] First 2 Words: A Signal for the Scanning Eye — Jakob Nielsen, NN/g — 2009 — https://www.nngroup.com/articles/first-2-words-a-signal-for-scanning/
- [Nielsen 2010h] Horizontal Attention Leans Left (early research) — Jakob Nielsen, NN/g — 2010 — https://www.nngroup.com/articles/horizontal-attention-original-research/
- [Nielsen 2010p] Photos as Web Content — Jakob Nielsen, NN/g — 2010 (reviewed 2026) — https://www.nngroup.com/articles/photos-as-web-content/
- [Nielsen 2010s] Scrolling and Attention (original research study) — Jakob Nielsen, NN/g — 2010 — https://www.nngroup.com/articles/scrolling-and-attention-original-research/
- [Nielsen 2011d] How Long Do Users Stay on Web Pages? — Jakob Nielsen, NN/g — 2011 — https://www.nngroup.com/articles/how-long-do-users-stay-on-web-pages/
- [Nielsen 2013] Usability for Senior Citizens: Improved, But Still Lacking — Jakob Nielsen, NN/g — 2013 — https://www.nngroup.com/articles/usability-seniors-improvements/
- [Nielsen 2013c] Auto-Forwarding Carousels and Accordions Annoy Users and Reduce Visibility — Jakob Nielsen, NN/g — 2013 — https://www.nngroup.com/articles/auto-forwarding/
- [Nielsen 2017j] Jakob's Law of Internet User Experience (video) — Jakob Nielsen, NN/g — 2017 — https://www.nngroup.com/videos/jakobs-law-internet-ux/
- [Nielsen 2020t] Opening Links in New Browser Windows and Tabs — Jakob Nielsen & Anna Kaley, NN/g — 2020 — https://www.nngroup.com/articles/new-browser-windows-and-tabs/
- [NNg Techy terms] Define Techy Terms for Older Users — Nielsen Norman Group (no byline; page metadata: published 24 May 2013, modified 5 Dec 2024) — 2013 — https://www.nngroup.com/articles/define-techy-words-old-users/
- [OGP] The Open Graph protocol — ogp.me — undated — https://ogp.me/
- [Packard 2021] How Concrete Language Shapes Customer Satisfaction — Packard & Berger, Journal of Consumer Research 47(5) — 2021 (online 2020) — https://doi.org/10.1093/jcr/ucaa038
- [Palcu 2017] Judgments at Gaze Value: Gaze Cuing in Banner Advertisements, Its Effect on Attention Allocation and Product Judgments — Palcu, Sudkamp & Florack, Frontiers in Psychology 8:881 — 2017 — https://www.frontiersin.org/articles/10.3389/fpsyg.2017.00881/full
- [Parhi 2006] Target size study for one-handed thumb use on small touchscreen devices — Parhi, Karlson & Bederson, MobileHCI, pp. 203–210 — 2006 — https://doi.org/10.1145/1152215.1152260 (read via the HCIL tech report: https://www.cs.umd.edu/hcil/trs/2006-11/2006-11.pdf)
- [Paul 2024] The Picture-Superiority Effect — Sara Paul, NN/g — 2024 — https://www.nngroup.com/articles/picture-superiority-effect/
- [Perfetti 2007] 5-Second Tests: Measuring Your Site's Content Pages — Christine Perfetti, UIE (the method dates from about 2005) — 2007 copy — https://articles.centercentre.com/?p=85
- [Pernice 2009] How to Conduct Eyetracking Studies — Kara Pernice & Jakob Nielsen, NN/g report — 2009 — https://media.nngroup.com/media/reports/free/How_to_Conduct_Eyetracking_Studies.pdf
- [Pernice 2014] A Link Is a Promise — Kara Pernice, NN/g — 2014 — https://www.nngroup.com/articles/link-promise/
- [Pernice 2016a] Hamburger Menus and Hidden Navigation Hurt UX Metrics — Pernice & Budiu, NN/g — 2016 — https://www.nngroup.com/articles/hamburger-menus/
- [Pernice 2017] F-Shaped Pattern of Reading on the Web: Misunderstood, But Still Relevant (Even on Mobile) — Kara Pernice, NN/g — 2017 (reviewed 2026) — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/
- [Pernice 2017t] Scanning Patterns on the Web Are Optimized for the Current Task — Kara Pernice, NN/g — 2017 — https://www.nngroup.com/articles/eyetracking-tasks-efficient-scanning/
- [Pernice 2018] Banner Blindness Revisited: Users Dodge Ads on Mobile and Desktop — Kara Pernice, NN/g — 2018 — https://www.nngroup.com/articles/banner-blindness-old-and-new-findings/
- [Pernice 2019l] The Layer-Cake Pattern of Scanning Content on the Web — Kara Pernice, NN/g — 2019 — https://www.nngroup.com/articles/layer-cake-pattern-scanning/
- [Pernice 2019s] Text Scanning Patterns: Eyetracking Evidence — Kara Pernice, NN/g — 2019 — https://www.nngroup.com/articles/text-scanning-patterns-eyetracking/
- [Pirolli 1999] Information foraging — Pirolli & Card, Psychological Review 106(4):643–675 — 1999 — https://doi.org/10.1037/0033-295X.106.4.643 ‡
- [Play Acquisition] Understand and grow your app's user base (acquisition reports) — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9859173 (answer 6263332 describes the older report, retired on 2 Nov 2020)
- [Play App setup] Create and set up your app (package names are unique and permanent) — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9859152
- [Play Closed tests] Set up an open, closed or internal test — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9845334
- [Play Deceptive] Deceptive Behavior policy — Google Play Developer Policy Center — current — https://support.google.com/googleplay/android-developer/answer/17006354
- [Play Deletion] Understanding Google Play's app account deletion requirements — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/13327111
- [Play Desktop install] Installing apps from a computer (Google Play Help, Computer tab) — Google — current — https://support.google.com/googleplay/answer/16671014?co=GENIE.Platform%3DDesktop
- [Play Experiments] Store listing experiments — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/6227309
- [Play Games UA] User acquisition guide (Google Play Games on PC; the `referrer` format and its 512-character limit) — Android Developers — updated 2026 — https://developer.android.com/games/playgames/user-acquisition
- [Play Install Referrer] Play Install Referrer API and library (referrer details available for 90 days after install) — Android Developers — updated 2025–2026 — https://developer.android.com/google/play/installreferrer (and https://developer.android.com/google/play/installreferrer/library)
- [Play Linking] Linking to Google Play — Android Developers — updated 2026 — https://developer.android.com/distribute/marketing-tools/linking-to-google-play
- [Play Listing practices] Store listing best practices — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/13393723
- [Play Merchant of Record] Merchant of Record (Google is merchant of record in Spain and the rest of the EEA) — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/7645364 (applied by the Developer Distribution Agreement §3.4, effective 15 Sep 2025: https://play.google/developer-distribution-agreement.html)
- [Play Metadata] Metadata policy — Google Play Developer Policy Center — current — https://support.google.com/googleplay/android-developer/answer/9898842
- [Play Package names] Registering Play package names (Android developer verification) — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/16984799
- [Play Pre-registration] Pre-registration — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9859047
- [Play Preview assets] Add preview assets to showcase your app — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9866151
- [Play Subscriptions] Subscriptions policy — Google Play Developer Policy Center — undated — https://support.google.com/googleplay/android-developer/answer/9900533
- [Play Testing req] App testing requirements for new personal developer accounts — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/14151465
- [Play ToS 2025] Google Play Terms of Service (EEA version, read in Spanish, dated 5 Nov 2025: Google Commerce Limited provides Play content and is the contracting party) — Google — 2025 — https://play.google.com/about/play-terms/index.html
- [Play Translation] Translate and localize your app — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/9844778
- [Play User Data] User Data policy — Google Play Developer Policy Center — undated — https://support.google.com/googleplay/android-developer/answer/10144311
- [Porter 2003] Testing the Three-Click Rule — Joshua Porter, UIE — 2003 — https://articles.centercentre.com/three_click_rule/
- [Poynter 2004] Eyetrack III: What News Websites Look Like Through Readers' Eyes — Outing, Poynter Institute with the Estlow Center and Eyetools — 2004 — https://www.poynter.org/archive/2004/eyetrack-iii-what-news-websites-look-like-through-readers-eyes/
- [PSI About] About PageSpeed Insights — Google for Developers — updated 2024 — https://developers.google.com/speed/docs/insights/v5/about
- [Rosala 2023] Deceptive Patterns in UX — Maria Rosala, NN/g — 2023 — https://www.nngroup.com/articles/deceptive-patterns/
- [Sajjacholapunt 2014] The influence of banner advertisements on attention and memory: human faces with averted gaze can enhance advertising effectiveness — Sajjacholapunt & Ball, Frontiers in Psychology 5:166 — 2014 — https://pmc.ncbi.nlm.nih.gov/articles/PMC3941030
- [Samsonov 2025] "Powered By AI" Is Not a Value Proposition — Pavel Samsonov, NN/g — 2025 — https://www.nngroup.com/articles/powered-by-ai-is-not-a-value-proposition/
- [Schade 2014v] Video Usability — Amy Schade, NN/g — 2014 — https://www.nngroup.com/articles/video-usability/
- [Schade 2015] The Fold Manifesto: Why the Page Fold Still Matters — Amy Schade, NN/g — 2015 — https://www.nngroup.com/articles/page-fold-manifesto/
- [Schade 2017a] Anchors OK? Re-Assessing In-Page Links — Amy Schade, NN/g — 2017 — https://www.nngroup.com/articles/in-page-links/
- [Schade 2018] Inverted Pyramid — Amy Schade, NN/g — 2018 — https://www.nngroup.com/articles/inverted-pyramid/
- [Scheibehenne 2010] Can There Ever Be Too Many Options? A Meta-Analytic Review of Choice Overload — Scheibehenne, Greifeneder & Todd, Journal of Consumer Research 37(3) (63 conditions from 50 experiments, N = 5,036; mean D = 0.02) — 2010 — https://doi.org/10.1086/651235 (read via https://archive-ouverte.unige.ch/unige:76440)
- [Search CWV] Understanding Core Web Vitals and Google search results — Google Search Central — updated 2025 — https://developers.google.com/search/docs/appearance/core-web-vitals
- [Search Interstitials] Avoid intrusive interstitials and dialogs — Google Search Central — updated 2025 — https://developers.google.com/search/docs/appearance/avoid-intrusive-interstitials
- [Shampanier 2007] Zero as a Special Price: The True Value of Free Products — Shampanier, Mazar & Ariely, Marketing Science 26(6) — 2007 — https://people.duke.edu/~dandan/webfiles/PapersPI/Zero%20as%20a%20Special%20Price.pdf
- [Sherwin 2015] "Learn More" Links: You Can Do Better — Katie Sherwin, NN/g — 2015 — https://www.nngroup.com/articles/learn-more-links/
- [Sherwin 2015l] Low-Contrast Text Is Not the Answer — Katie Sherwin, NN/g — 2015 — https://www.nngroup.com/articles/low-contrast/
- [Spencer 2000] The streamlined cognitive walkthrough method, working around social constraints encountered in a software development company — Rick Spencer, CHI, pp. 353–359 — 2000 — https://doi.org/10.1145/332040.332456 (read via a course copy of the ACM PDF: http://facweb.cs.depaul.edu/cmiller/eval/p353-spencer.pdf)
- [Stanford Guidelines] Stanford Guidelines for Web Credibility — B. J. Fogg, Stanford Persuasive Technology Lab — 2002 — https://credibility.stanford.edu/guidelines/index.html
- [Tuch 2012] The role of visual complexity and prototypicality regarding first impression of websites: Working towards understanding aesthetic judgments — Tuch, Presslaber, Stöcklin, Opwis & Bargas-Avila, International Journal of Human-Computer Studies 70(11) — 2012 — https://doi.org/10.1016/j.ijhcs.2012.06.003 (preprint: https://research.google.com/pubs/archive/38315.pdf)
- [UCPD] Directive 2005/29/EC on unfair commercial practices (consolidated 2022; arts. 6, 7) — EU — 2005 — https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02005L0029-20220528
- [Vodafone 2021] Vodafone: A 31% improvement in LCP increased sales by 8% — web.dev case study — 2021 — https://web.dev/case-studies/vodafone
- [W3C Conneg] Guiding users to translated pages — W3C Internationalization — undated — https://www.w3.org/International/questions/qa-site-conneg
- [W3C i18n def] Localization vs. Internationalization — W3C Internationalization — undated — https://www.w3.org/International/questions/qa-i18n
- [W3C Lang decl] Declaring language in HTML — W3C Internationalization — undated — https://www.w3.org/International/questions/qa-html-language-declarations
- [W3C Older users] Older Users and Web Accessibility: Meeting the Needs of Ageing Web Users — W3C WAI — 2010, updated 2025 — https://www.w3.org/WAI/older-users/
- [W3C Select nav] Using select to link to localized content — W3C Internationalization — undated — https://www.w3.org/International/questions/qa-navigation-select
- [W3C Text size] Text size in translation — W3C Internationalization (IBM data) — undated — https://www.w3.org/International/articles/article-text-size.en
- [WAI Images] Images Tutorial: Decorative Images — W3C WAI — 2019 — https://www.w3.org/WAI/tutorials/images/decorative/
- [WAI-AGE 2008] Web Accessibility for Older Users: A Literature Review — Andrew Arch, W3C Working Draft — 2008 — https://www.w3.org/TR/wai-age-literature/
- [Wang 2023] Accordions on Desktop: When and How to Use — Huei-Hsin Wang, NN/g — 2023 — https://www.nngroup.com/articles/accordions-on-desktop/
- [Wang 2023i] In-Page Links for Content Navigation — Huei-Hsin Wang, NN/g — 2023 — https://www.nngroup.com/articles/in-page-links-content-navigation/
- [Wang 2024] Homepage Design: 5 Fundamental Principles — Huei-Hsin Wang, NN/g — 2024 — https://www.nngroup.com/articles/homepage-design-principles/
- [WCAG 2.2] Web Content Accessibility Guidelines 2.2 — W3C Recommendation (5 Oct 2023; edition of 12 Dec 2024; also ISO/IEC 40500:2025), with its Understanding documents — 2024 — https://www.w3.org/TR/WCAG22/
- [WCAG C39] Technique C39: Using the CSS prefers-reduced-motion query to prevent motion — W3C — current — https://www.w3.org/WAI/WCAG22/Techniques/css/C39
- [web.dev Baseline 2025] LCP and INP are now Baseline Newly available — Pollard & Mocny, web.dev — 2025 — https://web.dev/blog/lcp-and-inp-are-now-baseline-newly-available
- [web.dev CLS] Cumulative Layout Shift (CLS) — web.dev — updated 2023 — https://web.dev/articles/cls
- [web.dev GIFs] Replace animated GIFs with video for faster page loads — Djirdeh & Wagner, web.dev — 2018 — https://web.dev/articles/replace-gifs-with-videos
- [web.dev INP] Interaction to Next Paint (INP) — web.dev — updated 2025 — https://web.dev/articles/inp (the switch from FID on 12 Mar 2024: https://web.dev/blog/inp-cwv-march-12)
- [web.dev Install criteria] What does it take to be installable? (native-app prompt via `prefer_related_applications`) — web.dev — updated 2024 — https://web.dev/articles/install-criteria
- [web.dev Lab vs field] Why lab and field data can be different (and what to do about it) — Philip Walton, web.dev — 2022 — https://web.dev/articles/lab-and-field-data-differences
- [web.dev LCP] Largest Contentful Paint (LCP) — web.dev — updated 2025 — https://web.dev/articles/lcp
- [web.dev Optimize INP] Optimize Interaction to Next Paint — Wagner, Walton & Pollard, web.dev — updated 2025 — https://web.dev/articles/optimize-inp
- [web.dev Optimize LCP] Optimize Largest Contentful Paint — Walton & Pollard, web.dev — updated 2025 — https://web.dev/articles/optimize-lcp
- [web.dev Permissions] Web permissions best practices — Harbach & Steiner, web.dev — updated 2024 — https://web.dev/articles/permissions-best-practices
- [web.dev Typography] Typography (Learn Design) — web.dev — 2021 — https://web.dev/learn/design/typography
- [web.dev Vitals] Web Vitals — web.dev — 2020, updated 2024 — https://web.dev/articles/vitals
- [WebAIM Million 2026] The WebAIM Million (2026 report) — WebAIM — 2026 — https://webaim.org/projects/million/
- [Wharton 1994] The cognitive walkthrough method: a practitioner's guide — Wharton, Rieman, Lewis & Polson, in Nielsen & Mack (eds.), *Usability Inspection Methods* (Wiley), pp. 105–140 — 1994 — book chapter; the four questions are known through Spencer 2000, Table 1 †
- [Whitenton 2016] Centered Logos Hurt Website Navigation — Kathryn Whitenton, NN/g — 2016 — https://www.nngroup.com/articles/centered-logos/
- [WP260 2018] Guidelines on transparency under Regulation 2016/679 (WP260 rev.01; adopted 29 Nov 2017, revised 11 Apr 2018) — Article 29 Working Party, endorsed by the EDPB on 25 May 2018 — 2018 — https://www.edpb.europa.eu/system/files/documents/2023-09/wp260rev01_en.pdf

**Still open after the second verification pass (18 Oct 2026) — don't cite these as facts.** Resolved items moved into the rules (see the note at the top). Each line says why it's open:
- Whether Play's upload rejects `com.example` names: no Google page says so; only developers' reports do (not found). The ID still has to be settled before the first upload (AP-6).
- Who owes the withdrawal function and the "order with obligation to pay" button when Play bills the subscription, whether the EAA or Ley 11/2023 covers TaskFlow, and whether a given analytics setup meets the AEPD's exemption: the primary sources are now in PR-4, AX-1, PV-6 and FN-9, but these are *(legal check)* questions for the owner.
- EN 301 549 V4.1.1's citation in the Official Journal: published by ETSI in Sept 2026, but no citation found by 18 Oct 2026.
- The native-app install prompt on a current phone: Chrome documents it and lists it as enabled, but nobody has tried it (AP-10).
- The Digital Omnibus: still in negotiation, so neither the Council's draft mandate nor Parliament's position is final (FN-9).
- Lindgaard et al. 2006's sample sizes and own correlations: paywalled, with no open copy; r = .97 comes from Tuch 2012.
- Arapakis et al. 2014's latency thresholds: paywalled; no rule uses them.
- Baymard's sample, survey year and base for the 12% figure (CT-10): behind a login.
- NN/g attention data by screenful on phones, and rigorous evidence that people scroll more on phones: not found (the Fold Manifesto only asserts it).
- Spanish- or Catalan-specific text-expansion figures: not found; vendors estimate Spanish at about 15–30% longer and give no Catalan figure.
- Rigorous evidence that interactive demos, phone-frame mock-ups or "text me the link" forms raise installs, or on how to word a usage cap: not found; only demo vendors' own figures exist.

## 21. How to review a page with this guide

This follows the reviewer's method (scope → context → map → look → predict → walk → faithfulness → lenses → count → report) and adds the measurable checks. Run it for every page in scope.

**1. Frame it.**
- Name the page, the way in (a WhatsApp preview, a search result, the Play listing, a link from the app, a typed or wrong URL), the language, the viewport, the theme and the person: Newcomer first, then Comparer, assistive-technology user and Leaver.
- Write the page's one job in ≤ 5 words, and the visitor's task (SC-8). If you can't, that's the first finding.

**2. Name your evidence.**
- A render counts only if it's newer than the code it shows; otherwise reason from the code and say so. A real phone is a third, separate level.
- Renders are Chromium: desktop 1440 × 1000, phone 390 × 664. Neither matches the eye-tracking studies' screens (1920 × 1080 desktops; a 2014 Nexus 4), so treat fold percentages as direction, not measurement.
- The Newcomer's phone may be narrower than 390 px: check 360 px and 320 px in the code (AX-3, ML-7).

**3. Start before the page.** The link preview (`opengraph-image.png`, the `og:` tags) and the `<title>` are what the Newcomer sees first. Do they say what TaskFlow is, in the page's language (ML-8, ML-9)?

**4. Predict attention on each fold render.** Label the result "predicted from the render, not measured".
1. Assume a first-time, low-motivation visitor who scans (SC-1, SC-8).
2. Draw the zones.
   - Desktop: lay a 3 × 3 grid over the viewport. The four upper-left cells get the first looks; the right third gets little in the first second (Buscher 2009); the left half gets about 80% of fixations (Fessenden 2017h).
   - Phone: the top half gets about 70% of gaze, the bottom third about 14% (Lagun 2014).
   - Below the fold line, expect a steep drop (AT-1).
3. List the visible elements and rank them by salience:
   1. faces;
   2. the largest high-contrast text, usually the H1;
   3. large images that carry information, such as app screens;
   4. filled, high-contrast buttons;
   5. digits, bold words and links inside text.

   Larger beats smaller at every step (Buscher 2009); on interfaces, text and the top-left beat colour (Leiva 2020; Jiang 2023).
4. Discount: anything ad-like — banner strips, right-rail boxes, bright promo tiles, stock photos (EY-5); flat or low-contrast controls (CT-5); small or pale text; the far-left 10% of a desktop screen; anything moving or inside a carousel, which a still render can't show.
5. Follow gaze: what a face looks at gets a modest boost; a face looking out of the screen holds attention itself (EY-4).
6. Text blocks: with clear headings, expect the layer-cake pattern (headings and first words); without them, the F (first lines, the left edge, the first two words) (SC-2, SC-3).
7. Write down fixations 1, 2 and 3 and what competes with each. Flag every must-see item — what TaskFlow is, the one next step, "for Android", what's free — that falls outside the first three or in a discounted zone. The primary action should be among the first three because of its label, position and isolation, not colour alone.
8. Limits: the task reshapes the pattern and people vary widely; the data are mostly desktop, from left-to-right languages (fine for ES, CA and EN) and from adults younger than the Newcomer; a prediction says nothing about understanding or desire. Recommend 5–6 real sessions with older, non-technical people to confirm (FN-7).

**5. Five-second simulation on each fold render.**
- Before reading anything, make a glance list: the largest, highest-contrast text; the main picture; the most prominent button; the name. Treat small text, the bottom third of the phone screen, and anything moving or in a carousel as unseen.
- From that list alone, answer:
  - Q1. What is this, in one sentence?
  - Q2. What would it do for me?
  - Q3. Who is it for, and on which phone?
  - Q4. What would I tap, and what happens next?
  - Q5. What did I notice first?
  - Q6. Which word wouldn't a 70-year-old non-technical person know?
- Pass: Q1–Q4 are right and specific; Q1 passes the competitor test (HE-1); Q5 is the headline or the product picture; Q6 finds nothing; something shows that the page continues (AT-3).
- Fail: understanding needs small print, motion, video, the demo or a second screen; two buttons compete; the answer would fit any to-do app. A fail in one language is a fail.
- Five seconds is a convention, and people with lower working memory recall less at 5 s, so simpler pages pass more people (Perfetti 2007; Lyssna 2023; Kuric 2024).

**6. Scroll it** on the full renders: a false floor at the fold (AT-3); the basics within two phone screens (AT-6); a call to action after the proof and in the last screenful, never two in one view (CT-1, CT-2); the number of scrolls to the first call to action on the phone.

**7. Walk each journey as each person.** Use Wharton et al.'s four questions [Wharton 1994], or Spencer's two for a fast pass [Spencer 2000].
- The main journey: shared link → home → the demo → the honest next step (download, or "not yet") → later, the Play listing, the app's first run and Pro.
- The Leaver: any page → account deletion in one step (PV-7).
- At every claim ask: "Is this true of the app today, in these words?" (FN-1, FN-2).

**8. Section pass.** Run the rules for what the page contains: hero (HE), scanning (SC), calls to action (CT), app specifics (AP), trust, privacy, pricing and FAQs (TR, PV, PR, FQ), reading and navigation (RD, NV), languages (ML).

**9. Code pass** (`src/app/`, `src/components/`, `src/styles/`):
- `<html lang>`, hreflang, `<title>` and `og:` tags per language (ML-2, ML-3, ML-8, ML-9);
- the heading outline, landmarks and skip link (AX-5);
- `alt` on every image (AX-6, AP-4);
- target sizes and spacing (CT-6);
- contrast in the light and dark tokens (AX-2);
- focus styles, and `scroll-padding` under sticky elements (AX-4, NV-3);
- `prefers-reduced-motion` and anything that autoplays (AX-7, HE-8);
- image `width`/`height`, the LCP element and its loading attributes, where `'use client'` sits, and scripts in the root layout (PF-3 to PF-6);
- `getUserMedia` only after a tap, its error handling, and live regions (AX-9, AX-10, PV-3);
- browser storage keys and third-party requests (PV-4).

**10. Language pass**, for ES, CA and EN: everything translated (ML-5); natural copy and the app's names (ML-6, FN-2); room to grow at 320 px and 200% text (ML-7); the switcher (ML-4).

**11. Count.** Words and calls to action in the first viewport; scrolls to the first call to action on the phone; steps from landing to the download (or the honest "not yet"); steps from any page to account deletion; claims checked, false and outdated. Give before → after.

**12. Rate and report.** Rate severity by frequency, impact and persistence on Nielsen's scale (Nielsen 1994s). In "Why it fails", cite the rule ID and its source; in "Evidence", say whether the finding rests on code, a current render or a device. Owner decisions and *(legal check)* items go to "Questions for the owner".
