# TaskFlow mobile UX guidelines

The evidence base for `frontend-ux-reviewer`. It turns research and platform rules into short rules you can check on a screen, a render or Flutter code.

- **Verified:** 2026-10-18. Web sources were fetched that day unless a date is given. Platform numbers change; re-check one before quoting it in a policy question.
- **The bar:** a first-time, non-technical user aged 60+, Spanish interface, large text, often one-handed (the reviewer's Newcomer). Capture must be super quick.
- **Owner decisions win.** `.claude/ux-review/DECISIONS.md` and `../UX_REVIEW.md` override this guide. When a rule here conflicts with one, raise it under "Questions for the owner" with the rule ID; don't file it as a finding.
- **Cite by ID** in findings, e.g. "Why it fails: RE-2 (Hoober 2017a; Parhi 2006)".
- **Verification pass, 2026-10-18 (second).** The first pass ran into the research's shared search cap, so every source marked †, ‡ or ~, the §19 notes and the research reports' open items were re-checked on primary sources: publishers' pages, authors' and repository copies of papers, Android and Play pages, EUR-Lex and BOE.
  - Corrected: CO-6, SC-3, SC-6, SC-12, RE-5, VO-6, VO-10, VO-14, VO-15, ON-6, TA-4, TA-7, NO-7, SH-2, SH-3, OL-7, FO-9, PR-1 and SU-10, plus §0, §18 and §19. Oviatt's 1999 "Ten myths" was dropped from VO-16, which it didn't support.
  - A remaining ‡ means the abstract confirmed the claim and the full text was paywalled or blocked to automated readers.
  - Still open (each entry says why): the keystroke-level operator times in CO-10 [Card 1980], [Karat 1999], Gray's five strategies [Gray 2018], [Markey 2000], [Wohl 2010], [Carroll 1987], [Raskin 2000], [von Restorff 1933] and [Wharton 1994]; SU-10's legal questions stay with the owner.

**Rule format.** **Do** says what good looks like. **Check** says how to test it, then gives the key evidence. Each rule ends with its evidence strength and source keys; every key has a full entry (title, authors or organisation, year, URL) under [Sources](#sources).

**Evidence strength**, strongest first:
- *study/data* — measured: experiment, field log, survey or meta-analysis (sample sizes in the rule);
- *standard/law* — WCAG, GDPR, EU and Spanish law: normative text;
- *platform guideline* — Google (Android, Material 3, Play policy), Apple, Flutter docs and source;
- *expert guideline* — NN/g articles, W3C notes, regulators' guidance: synthesised from research and practice;
- *convention/opinion* — style guides, vendor data, practitioner essays.

**Source markers** (in the source list): † known only second-hand; ‡ abstract or summary only; ~ search snippet only. Unmarked entries were fetched and read, often as an extract.

## 0. Numbers at a glance

| Topic | Number | Source |
|---|---|---|
| Touch target floor | 48 × 48 dp hit area (padding counts), ≥ 8 dp apart | Android Touch targets; M3 Structure |
| WCAG target size | 24 × 24 CSS px ≈ dp (2.5.8, AA); 44 × 44 (2.5.5, AAA) | WCAG 2.2; WCAG2ICT 2025 |
| Apple | 44 × 44 pt default control size; 28 × 28 pt minimum | Apple A11y |
| Physical size | 1 dp ≈ 1/160 in ≈ 0.16 mm; 48 dp ≈ 7.6 mm (Material 3 rounds it to about 9 mm); real phones vary ≈ ±20% | Android dp; M3 Structure; Hoober 2017a |
| Touch accuracy | ≈ 7 mm at the centre, ≈ 12 mm at corners; rows with edge targets 9–10 mm | Hoober 2017a; Hoober 2017c |
| One-handed thumb | 9.2 mm for single taps, 9.6 mm for tap sequences (20 people) | Parhi 2006 |
| Older adults' targets | 39% errors at ≈ 4.6 mm vs 6.5% at ≈ 7.7 mm (adults in their 60s–70s); 13 mm smallest reliable and 15 mm most comfortable (7 adults 60+) | Kobayashi 2011; Franz 2019 |
| Grip | 49% one-handed, 36% cradled, 15% two-handed (780 touch observations, 2012–13) | Hoober 2013 |
| Text contrast | 4.5:1; 3:1 for large text = ≥ 18 pt (≈ 24 px) or ≥ 14 pt bold (≈ 18.5 px); 7:1 for AAA; never rounded | WCAG 2.2 |
| Non-text contrast | 3:1 for borders, states and icons | WCAG 2.2 |
| Text size | Resizable to 200%; Android 14 font scale up to 200%, non-linear | WCAG 2.2; Android 14 features |
| Reflow | 320 CSS px (≈ dp) wide | WCAG 2.2 |
| Response limits | 0.1 s instant · 1 s keeps flow · 10 s holds attention (rules of thumb); delay noticeable from ≈ 60 ms | Nielsen 1993; Forch 2017 |
| Waiting UI | < 1 s nothing; 2–10 s moving indicator; > 10 s percent-done or explanation, plus cancel | Sherwin 2014pr; Tankala 2023 |
| Turn-taking | ≈ 200 ms gap between turns (mean 208 ms, 10 languages) | Stivers 2009 |
| Speech vs typing | 2.9× faster (153 vs 52 wpm), young adults copying set phrases | Ruan 2017 |
| Fixing by re-speaking | 35% of errors fixed, vs 75–87% by handwriting, spelling or typing | Suhm 2001 |
| Older voices | ≈ 9–10 points higher word error rate | Vipperla 2010 |
| Android vitals, bad behaviour | User-perceived crash rate ≥ 1.09% (≥ 8% on one phone model); ANR rate ≥ 0.47% (≥ 8%); excessive partial wake locks in > 5% of sessions (enforced from 1 Mar 2026) | Android Vitals; Android Wake locks 2026 |
| Slow start-up | Cold ≥ 5 s, warm ≥ 2 s, hot ≥ 1.5 s (Play Console Help says 1 s for hot) | Android Launch time; Play Vitals help |
| Rendering | Slow session: > 50% of frames over 16 ms; frozen: > 0.1% of frames over 700 ms | Play Vitals help |
| ANR | No response to input within 5 s | Android ANR |
| Alarms | Inexact alarms up to 1 h late (Android 12+); exact alarms denied by default to most new installs (Android 14); restricted bucket gets 1 alarm a day (Android 13: after 8 days unused) | Android Alarms; Android 14 Exact alarms; Android Standby |
| Notification text | Title ≤ 30 characters, text ≤ 40; ≤ 3 action buttons; Android groups 4+ | Android Notif design; Android Build notification; Android Notif group |
| Notification load | Mean 63.5 a day (15 users, 2014); median 56 a day (278 users, 2018) | Pielot 2014; Pielot 2018 |
| Notification opt-in | Android 85% → 67% after Android 13's prompt (vendor, Europe, 2024–25) | Batch 2025 |
| Snackbars | M3: 4–10 s without an action; with one, stays until used or dismissed. Flutter: 4 s default; since 3.38 snackbars with an action persist (`persist`). Android Views 1.5 / 2.75 s; Compose 4 / 10 s | M3 Snackbar; Flutter SnackBar persist; MDC Snackbar |
| "Time to take action" | Default, 10 s, 30 s, 1 min, 2 min (Android 10+) | Android Timeout help |
| Launcher shortcuts | ≤ 4 shown; short label ≈ 10 characters, long ≈ 25 | Android Shortcuts |
| Text expansion from English | ≤ 10 chars: 200–300%; 11–20: 180–200%; 21–30: 160–180%; > 70: ≈ 130% | W3C Text size |
| Reminders | Text reminders: attendance 67.8% → 78.6% (RR 1.14); reminders 3 days + 1 day before: no-shows 4.4% vs 5.3–5.8% for one | Cochrane 2013; Steiner 2018 |
| Plans | When-and-where plans: d = .65 across 94 tests | Gollwitzer 2006 |
| Older adults online | Success 55% vs 75%; ≈ 43% slower; 2.4 vs 1.1 errors per task; self-blame 90% vs 58% (2013) | Nielsen 2013 |
| Adoption | 78% of US adults 65+ own a smartphone (2025); Spain 2025: 83.6% of 65–74s use the internet on a phone, 49.2% of 75–89s used the internet in the last 3 months | Pew 2025; Eurostat 2025 |
| Dark patterns | ≥ 1 in 95% of 240 popular apps (2020) and in 97% of popular EU sites and apps (73 of 75 checked, 2022) | Di Geronimo 2020; EC Dark patterns 2022 |
| Play target API | New apps and updates must target API 36 from 31 Aug 2026 | Play Target API |

## 1. Load, choice and memory (CO)

- **CO-1 One job per screen.** Do: give each screen one purpose a newcomer can name, stated in its heading.
  Check: from the render alone, name the job in ≤ 5 words; then ask Spencer's two questions for its first step. — *expert guideline* · [Spencer 2000] [COGA 2021]
- **CO-2 Few options per decision.** Do: keep each decision on the default path to a few equally weighted options; move the rest behind one "More…" control.
  Check: count options per decision point; more than 3 equal options before the first action is a finding (threshold: convention). Decision time grows with the number of options (Hick–Hyman), and people who don't know the options yet scan them one by one, so for newcomers the cost grows faster than for experts. — *study/data* · [Hick 1952] [Hyman 1953] [Cockburn 2007]
- **CO-3 Nothing to remember.** Do: repeat on each screen what the user needs there: the task, the day, the person, the address a code went to.
  Check: no step relies on memory of an earlier screen, email or notification. Working memory holds about 4 chunks; people with impaired working memory may hold 1–3. — *study/data* · [Cowan 2001] [COGA 2021]
- **CO-4 A default plus "Other…", not a full list.** Do: when the user has no preference yet (project, lead time, repeat), offer the likely default and one way to choose otherwise.
  Check: pickers shown before the user knows what they want. Across 50 experiments choice overload averaged about zero, but it appears reliably when the task is hard, the set complex, preferences uncertain and the goal is minimal effort: the newcomer's situation. — *study/data* · [Scheibehenne 2010] [Chernev 2015]
- **CO-5 Cut extraneous load.** Do: remove decoration, repeated explanations and technical options from action screens.
  Check: every word and control helps the current decision; no text explains a control that could explain itself. — *study/data* · [Sweller 1988]
- **CO-6 Defaults decide.** Do: pre-fill the value most people want (day, time, project, reminder).
  Check: list each default the flow applies and ask whether it suits the newcomer. People who never customised their task tools never changed the default reminder; a top search result kept 34% of clicks even when secretly swapped. Default effects can be large (opt-out gave 82% donor consent vs 42% for opt-in in a 161-person online experiment), but a framing effect seen in hypothetical choices (yes/no vs opt-in) didn't hold for 1,043 real organ-donor registrations, where opt-out wasn't tested. — *study/data* · [Haraty 2016] [Nielsen 2005] [Johnson 2003] [Kessler 2025]
- **CO-7 Progressive disclosure, two levels at most.** Do: show what most people need; put the rest behind one clearly labelled control that says what's inside; never a third level.
  Check: "Más detalles" names or shows its contents; a filled field stays visible when its section is collapsed. — *expert guideline* · [Nielsen 2006] [COGA 2021]
- **CO-8 Recognition over recall.** Do: show what can be done — visible controls, an example sentence, recent items — instead of relying on remembered commands or gestures.
  Check: list features reachable only by a remembered phrase, a gesture or a hidden menu. — *expert guideline* · [Budiu 2024] [Nielsen 1994h]
- **CO-9 Subtract before adding.** Do: a new control on the default path replaces something or is essential for the flow.
  Check: count controls before → after. People choose feature-rich products before use but value ease of use once they've used them ("feature fatigue", three studies). — *study/data* · [Thompson 2005]
- **CO-10 Price each step.** Do: compare designs by the operations they ask for.
  Check: before → after, each extra decision ≈ 1.35 s and each extra point-and-tap ≈ 1.1 s in the keystroke-level model (practised desktop users, 1980; newcomers are slower). Use it for comparisons, not predictions. — *study/data* · [Card 1980]

## 2. Attention, scanning and hierarchy (SC)

- **SC-1 Front-load every line.** Do: start rows, labels and messages with the word that distinguishes them: "Fri 17 Oct · 5:00 PM · Doctor", not "Your task has been scheduled for…".
  Check: the first two words of each line carry its information. 79% of test users scanned rather than read; eyetracking found F-shaped scanning that favours the first words of lines, on phones too. — *study/data* · [Nielsen 1997] [Nielsen 2006f] [Pernice 2017]
- **SC-2 One or two lines where people decide.** Do: short lines on action screens, one point per sentence, no paragraphs.
  Check: count words at each decision point. Concise, scannable, objective rewrites measured 124% better usability; short text is understood as well on phones as on desktop, but hard text reads slower. — *study/data* · [Nielsen 1997] [Moran 2016] [COGA 2021]
- **SC-3 Name and day at the top-left.** Do: put the screen's name, or the day it shows, as text at the top-left.
  Check: cover the rest of the render; the top-left block still says where you are. Across 193 app screens viewed by 30 participants (Chinese-language screens and viewers), most fixations fell on the top-left, on text and on images; colour brightness had no effect and element size mattered little. — *study/data* · [Leiva 2020]
- **SC-4 One primary action, set apart by label, position and isolation.** Do: one filled button or one extended FAB per screen or group, labelled with a verb that names the result.
  Check: count filled buttons and accent-coloured elements in view; two competing is a finding. Material's filled button is the strongest emphasis after the FAB, meant for final actions that complete a flow, used sparingly and ideally for one action per page. — *platform guideline* · [M3 Buttons] [M3 FAB] [von Restorff 1933]
- **SC-5 Key content and action on the first screen.** Do: what the user came for, and the button that completes it, show without scrolling at 2× text on a small phone; otherwise pin the button.
  Check: render at 2× on 360 dp. People scroll, but attention falls off fast below the first screen (desktop data: 57% of viewing time above the fold, 74% within two screenfuls). — *study/data* + *expert guideline* · [Fessenden 2018] [COGA 2021]
- **SC-6 Label icons on the default path.** Do: put a word with every icon the newcomer needs; tooltips don't count on touch.
  Check: list icon-only controls (app bar, chips, row buttons). Only a few icons are universally understood; older adults had more trouble with icons; pictures that plainly match their meaning, and concrete pictures, helped them more; labels helped every age, older adults no more than others (36 people). — *expert guideline* + *study/data* · [Harley 2014] [Leung 2011]
- **SC-7 Don't hide core destinations.** Do: frequent destinations stay visible; any overflow menu carries a word ("Más").
  Check: what sits behind ⋮, the avatar or a drawer. On phones hidden navigation was used in 57% of cases vs 86% with visible plus hidden, and discoverability fell by more than 20%; a tiny unlabelled menu icon got 44% use vs 89% for a prominent one. — *study/data* · [Pernice 2016a] [Pernice 2016b]
- **SC-8 Don't make guidance look like an ad.** Do: put essential guidance beside the control it explains, in plain styling.
  Check: tips, promos or upgrade prompts styled as banners or cards at the top; repeated info boxes. People skip anything with ad-like placement or styling, on phones too. — *study/data* · [Pernice 2018]
- **SC-9 Same thing, same word, same place.** Do: one name per concept; the same action keeps its word, icon and position on every screen and in every language.
  Check: compare labels for the same function across screens and across ES, CA and EN. — *standard/law* + *expert guideline* · [WCAG 2.2] (3.2.3, 3.2.4) [W3C Mobile 2015] [COGA 2021]
- **SC-10 Show a change where the user is looking.** Do: after save, move, complete or delete, bring the item into view and mark it briefly; one change at a time; keep the rest still.
  Check: flows whose only confirmation is a message at the screen edge. People miss even large changes outside their focus; NN/g advises one change at a time, grouped, animated and near the focus. — *study/data* + *expert guideline* · [Rensink 1997] [Budiu 2018cb]
- **SC-11 End on visible success.** Do: add, move, complete and delete end with the result in view.
  Check: the last frame of each flow. People judge an experience largely by its most intense moment and its end. — *study/data* · [Kahneman 1993]
- **SC-12 Polish is not proof.** Do: walk the flow even when the render looks good.
  Check: don't downgrade a finding because the screen is attractive; when 252 people rated 26 cash-machine layouts, how easy a layout looked tracked its beauty more than most of its usability properties (actual use wasn't tested). — *study/data* · [Kurosu 1995]

## 3. Android and Material 3 conventions (PL)

- **PL-1 Use the patterns people already know.** Do: standard Android and Material components in their usual places; nothing custom where a standard one fits.
  Check: each custom control with a standard equivalent needs a reason. People spend most of their time in other products and expect yours to work the same way (Jakob's law); older users rely on stable, familiar navigation. — *expert guideline* · [Nielsen 2000] [Nielsen 2017j] [Nielsen 2013] [COGA 2021]
- **PL-2 Navigation bar: 3–5 labelled destinations.** Do: each destination has a 1–2-word label that never wraps, truncates or shrinks. For fewer than 3 destinations Material points to tabs, not a navigation bar (relevant to the pending two-tab plan, U13).
  Check: count destinations; check labels in Catalan at 2× on 320 dp. Flutter's `NavigationBar` caps label scaling at 1.3× and stays 80 dp high, so long labels clip instead of growing. — *platform guideline* · [M3 Navigation bar] [Flutter NavigationBar src]
- **PL-3 One FAB, for the main constructive action.** Do: at most one FAB, for create or start, never destructive; an extended FAB (icon + label) when the action needs words; above the navigation bar.
  Check: count FABs; the FAB's TalkBack label names the action. — *platform guideline* · [M3 FAB] [Flutter FAB]
- **PL-4 Bottom sheets for focused tasks, with a visible way out.** Do: a modal sheet for a short task over the current screen, starting no taller than half the screen; besides Back, scrim tap and swipe, a visible close or cancel control; every drag has a one-finger alternative.
  Check: the sheet closes with Back and a visible control. If it holds the user's words, a scrim tap or swipe never discards them silently — Flutter's `showModalBottomSheet` allows both by default. Older adults hesitated to tap the background to close menus. — *platform guideline* + *study/data* · [M3 Bottom sheets] [Flutter showModalBottomSheet] [Harada 2013]
- **PL-5 Dialogs only for decisions worth an interruption.** Do: at most two actions; the confirming one is a specific verb at the trailing edge; the dismissive one is never disabled; no "Are you sure?", no apology.
  Check: list every dialog in the flow; informational or routine ones become inline text or a snackbar. — *platform guideline* · [M3 Dialogs] [Apple Alerts]
- **PL-6 Snackbars are brief, low-priority and have one action.** Do: one at a time; at most one action, never "Dismiss"; above the FAB and the navigation; ≤ 2 lines on phones; never the only place for an error or for anything the user must act on.
  Check: snackbar text in Catalan at 2×. — *platform guideline* + *expert guideline* · [M3 Snackbar] [Flutter SnackBar src] [Flaherty 2024]
- **PL-7 Back goes one step and keeps work.** Do: Back and Up do the same thing inside the app; no Up arrow on the start screen; Back there leaves the app; Back never discards input.
  Check: press Back on every screen and sheet. For apps targeting Android 16 (API 36) `onBackPressed` is no longer called, so back handling must go through `PopScope`/`canPop`. — *platform guideline* · [Android Navigation principles] [Android 16 changes] [Flutter PopScope]
- **PL-8 Gestures are shortcuts, never the only way.** Do: every swipe, long press or drag also has a visible button or menu item and a TalkBack custom action.
  Check: list gesture handlers (`Dismissible`, `onLongPress`, drags) and find each one's visible twin. Gestures have no signifier; swipe actions are hard to discover; older adults perform gestures well but rarely find gesture-only functions. — *standard/law* + *platform guideline* + *study/data* · [WCAG 2.2] (2.5.1, 2.5.7) [Android A11y principles] [Norman 2010] [Li 2017s] [Kobayashi 2011]
- **PL-9 Launcher shortcuts: few and short.** Do: at most 4 shortcuts; short label ≈ 10 characters, long label ≈ 25.
  Check: `res/xml/capture_shortcuts.xml` and its ES and CA strings against those lengths. — *platform guideline* · [Android Shortcuts]
- **PL-10 The home-screen widget meets Android's widget bar.** Do: 48 × 48 dp targets, enough contrast, light and dark palettes, an update right after any action in the widget or the app, and an intentional empty or signed-out state with a call to action.
  Check: widget layouts, strings and refresh triggers. — *platform guideline* · [Android Widget quality]
- **PL-11 Edge to edge, inside the insets.** Do: draw behind the system bars but keep text and controls inside the safe insets.
  Check: `SafeArea`/`MediaQuery.paddingOf` on screens and sheets; bottom buttons sit above the gesture area. Edge-to-edge is enforced for apps targeting API 35; the opt-out stops working for apps targeting API 36 on Android 16; Play requires API 36 for updates from 31 Aug 2026. — *platform guideline* · [Android 16 changes] [Play Target API]

## 4. Reach, touch and placement (RE)

- **RE-1 Primary actions low and central; rare ones high.** Do: put primary and frequent actions in the middle half to two-thirds of the screen height, low-centre for capture; secondary paths along the top and bottom edges; rare actions in a corner menu.
  Check: mark the primary action on the render. People look at and touch the centre most and are most accurate there; Material puts important actions at the top or bottom, where they are easiest to reach — one-handed, that means the bottom. — *study/data* + *platform guideline* · [Hoober 2017a] [Hoober 2017c] [M3 Structure]
- **RE-2 Size targets by position; 48 dp is the floor.** Do: centre targets ≥ 7 mm (≈ 44 dp), corner targets ≈ 12 mm (≈ 76 dp), rows with targets at the screen edge 9–10 mm (≈ 57–63 dp) tall, and nothing under 48 dp (≈ 7.6 mm).
  Check: measure hit areas (semantics bounds), not icons; a primary action in a bottom corner needs more than 48 dp — an extended FAB or a wide button. One-handed thumb tests (20 people) found 9.2 mm (single taps) and 9.6 mm (sequences) enough. — *study/data* + *platform guideline* · [Hoober 2017a] [Hoober 2017c] [Parhi 2006] [Android Touch targets]
- **RE-3 Bigger, and spaced, for older hands.** Do: make primary and frequent controls clearly larger than 48 dp (aim for ≥ 10 mm ≈ 63 dp — a synthesis, not a tested number) and keep visible gaps between adjacent buttons such as chip rows.
  Check: chip rows with no gap; small trailing icons on rows. Adults in their 60s–70s made 39% errors on ≈ 4.6 mm targets vs 6.5% on ≈ 7.7 mm, and a week's practice didn't help tapping; a small study found 13 mm the smallest reliable and 15 mm the most comfortable size for adults 60+; zero spacing gave older adults the worst accuracy on a kiosk; NN/g recommends at least 1 × 1 cm. — *study/data* + *expert guideline* · [Kobayashi 2011] [Franz 2019] [Jin 2007] [Harley 2019]
- **RE-4 Work for either hand and changing grips.** Do: the key action is reachable by a left or a right thumb.
  Check: mirror the layout; a bottom-right-only key action suits one grip. Of 780 observed touch interactions (public places, 2012–13, no demographics, phones up to a Galaxy Note 2), 49% were one-handed, 36% cradled and 15% two-handed, and people changed grip often. — *study/data* · [Hoober 2013]
- **RE-5 Large phones force grip shifts.** Do: no step of capture needs a tap in the top band of the screen.
  Check: on a 6.7" frame (≈ 70 × 155 mm), list taps above the top third during capture. Reach depends on hand size, phone size and grip (a model fitted to 20 people), and phone size and reach distance change how much people tilt and turn the phone, with grips shifting by task. — *study/data* · [Bergstrom-Lehtovirta 2014] [Eardley 2017]
- **RE-6 Keep destructive actions apart.** Do: keep Delete or Discard away from Save, Add and other frequent targets, never in one group with equal weight.
  Check: adjacent destructive and frequent buttons. Older adults hit neighbouring buttons by mistake (for example 0 and Call). — *expert guideline* + *study/data* · [Hoober 2017c] [Harada 2013]
- **RE-7 Leave the edges to the system.** Do: no swipe that must start at the left or right edge; no control under the bottom gesture area.
  Check: week-strip swipes, carousels and bottom bars. Android 10+ uses an inward edge swipe for Back and reserves the bottom edge for Home; apps can't opt out of the Home gesture. — *platform guideline* · [Android Gesture nav]
- **RE-8 Feedback beside the finger.** Do: pressed states and confirmations show where the finger isn't covering them.
  Check: tooltips or labels directly under the tapped control. — *expert guideline* · [Hoober 2017c]
- **RE-9 Actions fire on release.** Do: taps complete on release, so sliding away cancels; hold-to-talk ends on release.
  Check: `onTapDown` or `onPanStart` handlers that save, delete or send. — *standard/law* · [WCAG 2.2] (2.5.2) [W3C Mobile 2015]

## 5. Voice capture and AI results (VO)

- **VO-1 Listening is unmistakable.** Do: distinct, labelled states — listening (live words, level indicator), understanding, result — clear at a glance and announced to TalkBack; the microphone is open only while the listening state shows.
  Check: render each state; no two look alike. Users couldn't tell whether a silent system was working or hadn't heard them; EDPB asks that every state change be shown. — *study/data* + *expert guideline* · [Yankelovich 1995] [Harley 2018] [Microsoft Speech] [EDPB VVA 2021]
- **VO-2 Only the user ends listening.** Do: pauses never end listening; Done does, and any time cap acts like Done.
  Check: no silence timeout; speech-timeout and no-match errors don't end the session (device check). Assistants took pauses as the end of a request; older first-time users were cut off mid-sentence; pressure to fill silence raised errors; Android's silence-length extras may be ignored by the recogniser. — *study/data* + *platform guideline* · [Budiu 2018ia] [Kim 2021] [Yankelovich 1995] [AOSP RecognizerIntent]
- **VO-3 Live words, without lag.** Do: show words as they're recognised, with committed text distinct from the in-progress guess.
  Check: on a device, words appear within about a second of speaking. When a transcript lagged, a test user assumed she hadn't been heard and repeated herself, which caused a misunderstanding. — *study/data* · [Budiu 2018ia]
- **VO-4 Show what to say.** Do: one example sentence with the right shape (what + when) on the first listening screen and after a failed attempt.
  Check: the empty and failed states each show an example in the user's language. People don't know what to say; sample phrases help and get reused; newcomers struggle more with sentence structure than with keywords and mostly guess their way forward. — *study/data* + *platform guideline* · [Yankelovich 1995] [Microsoft Speech] [Myers 2021] [Myers 2018]
- **VO-5 Show the interpretation, date first.** Do: each result shows what and when as its largest lines, with weekday and full date ("Fri 17 Oct · 5:00 PM"); the transcript is one tap away.
  Check: on the result render, the date line is the most prominent after the title. Users distrusted results they couldn't check and wanted visual confirmation of complex or precise tasks; 80% of Baymard's test users weren't sure which date "this Friday" meant. — *study/data* · [Budiu 2018ia] [Luger 2016] [Baymard 2015f]
- **VO-6 Fix by touch, not by saying it again.** Do: tapping any field of a result (title, day, time, project, person) edits it in place; typing is one tap away; "say it again" is secondary.
  Check: a wrong day is fixed in ≤ 2 taps without the keyboard. Re-speaking fixed 35% of errors vs 75–87% for handwriting, spelling or typing, and a second try in the same mode did worse; users prefer speech at first and learn only with experience to avoid it for fixes, and over-enunciating lowers accuracy. — *study/data* · [Suhm 2001] [Karat 1999] [Microsoft Speech]
- **VO-7 Several tasks: a count, then one row each.** Do: "3 tasks", then one row per task, each editable and removable alone; details that belong to one task (a note, a checklist) attach only to it.
  Check: fixing one task never means re-dictating the others; a shared time lands on the right task. Users split multi-clause requests because they expect assistants to fail, while older first-time users speak in long, nested sentences; one detail can belong to several intents. — *study/data* · [Budiu 2018ia] [Kim 2021] [Gangadharaiah 2019] [Cowan 2017]
- **VO-8 Match the confirmation to the cost.** Do: for new tasks, show the result and confirm with one tap; for changes and deletions, show before → after, name the affected tasks on the button ("Delete 3 tasks"), and offer Undo afterwards.
  Check: no command changes or deletes data without a visible, named confirmation; no Yes/No buttons. Google and Amazon keep explicit confirmation for hard-to-undo or costly actions and use implicit confirmation otherwise; spoken yes/no questions were ignored in SpeechActs; Apple's confirmation API puts the action's name on its button. On the open owner decision UX-615 (auto-saving one unambiguous task): platform guidance allows implicit confirmation for low-cost, likely-correct results if the date shows and Undo is easy, but users wanted visual confirmation of complex or precise tasks. — *platform guideline* + *study/data* · [Google Confirmations] [Alexa Trustworthy] [Apple App Intents] [Yankelovich 1995] [Nielsen 2018c] [Luger 2016]
- **VO-9 Ask only real questions, with tappable answers.** Do: when a value is truly ambiguous (5:00 or 17:00?), ask one plain question on the card with the answers as buttons.
  Check: questions look like questions, not footnotes; nothing is asked that the context settles. Platform guides confirm explicitly when confidence is low or a mistake costly, implicitly otherwise. — *platform guideline* · [Google Confirmations] [Nuance Confirm] [Microsoft Speech]
- **VO-10 Don't flag "uncertain" words.** Do: rely on the date-first card and easy edits, not on confidence shading.
  Check: underlined or coloured low-confidence words. Shading didn't improve error finding overall (84% vs 81% found, 16 people); errors left unshaded were found less often (71% vs 82%, not significant), which the authors put down to trust in the shading; highlighting slowed correction in Suhm's study. — *study/data* · [Vertanen 2008] [Suhm 2001]
- **VO-11 Failures say what was heard and what's missing.** Do: name the problem and the next step; never "speak louder" or "speak more clearly"; after two failed tries, offer typing or the form.
  Check: every failure string in three languages. Failures with no visible reason frustrated more than misrecognitions (4.4 vs 2.7 on a 5-point scale, 30 people, a preprint); Google's guide ends repeated no-match loops with another way to finish. — *study/data* + *platform guideline* · [Goetsu 2020] [Google Errors] [Suhm 2001]
- **VO-12 Design the wait.** Do: acknowledge Done within 0.1 s; while understanding, keep the words on screen with a moving indicator that names the step; after about 8–10 s explain and offer a way on that keeps the words.
  Check: the slow-AI state and its timers. Gaps between turns in conversation average about 200 ms, so a silent wait feels long; Alexa's interim ("progressive") responses all have to come within about 8 s. — *study/data* + *expert guideline* · [Stivers 2009] [Nielsen 1993] [Alexa Progressive] [Sherwin 2014pr]
- **VO-13 Detect a silent microphone.** Do: if the audio is silent — the phone's microphone toggle is off, a call holds the mic, another app records — say so plainly and offer typing, instead of "I didn't catch that".
  Check: the empty-audio path. Android 12+ delivers silent audio when the global microphone toggle is off; since Android 10 a call or a foreground app can silence capture. — *platform guideline* · [Android Sensitive access] [Android Audio sharing]
- **VO-14 Expect more errors from older voices.** Do: make recovery cheap (VO-6) and test with older Spanish and Catalan speakers.
  Check: accuracy claims based on the developers' own voices. Word error rates were about 9–10 points higher for older speakers (12 aged 60–85 vs 27 aged 30–45); in 1995 recognition varied widely between speaker groups and predicted satisfaction poorly. — *study/data* · [Vipperla 2010] [Yankelovich 1995]
- **VO-15 The first dictation must visibly succeed.** Do: the first result lands on the calendar with its day; a reminder, if set, says when it will fire.
  Check: walk the first-run capture end to end. Expectations of voice assistants far exceed experience, most for less technical users; older adults given a smart speaker for 3 weeks found reminders useful at first but used them little, doubting their reliability (7 people); most of 36 older long-term owners in another study had stopped using theirs. — *study/data* · [Luger 2016] [Pradhan 2020] [Trajkova 2020]
- **VO-16 Voice is never required.** Do: typing, or the form, is always one tap away, including when the microphone is denied.
  Check: the mic-denied, offline and no-dictations-left paths each reach a working way to add a task. Users go back to touch when voice saves no time; Android says text input must stay usable when the microphone is refused. — *study/data* + *platform guideline* · [Luger 2016] [Android Permissions]
- **VO-17 Measure time to a correct task, not speaking speed.** Do: judge capture speed by the total time including review and fixes.
  Check: the basis of any speed claim. Speech was 2.9× faster than typing for young adults copying set phrases; the advantage shrank when composing (total time 29% shorter vs 45% when transcribing, 28 people); corrections can cancel it. — *study/data* · [Ruan 2017] [Foley 2020] [Suhm 2001]
- **VO-18 Show results; don't make people hold spoken ones.** Do: anything said aloud also appears on screen, shorter; never read a list aloud.
  Check: spoken read-backs and their on-screen version. Speaking and listening compete with working memory, and spoken output is fleeting. — *expert guideline* + *platform guideline* · [Shneiderman 2000] [Google Scale]

## 6. First run, permissions and empty states (ON)

- **ON-1 No tour.** Do: no carousel, walkthrough or feature tour before first use.
  Check: count screens between install and the calendar; each needs a reason the user would accept. In a 70-person test a swipe-through tutorial didn't improve success (91% vs 94%) or time, and made tasks feel harder. — *study/data* + *expert guideline* · [Kendrick 2020t] [Kendrick 2020o] [Apple Onboarding]
- **ON-2 Teach at the moment of need, one tip at a time.** Do: a single short tip where the user is about to act; it never covers the control or looks tappable, and can be found again.
  Check: tip placement on renders. Help shown when needed works better than up-front tutorials; test users tried to tap coach-mark overlays. — *expert guideline* · [Laubheimer 2023] [Harley 2014c]
- **ON-3 The first task is the user's own.** Do: first run gets the user adding a real task straight away, with easy recovery from mistakes.
  Check: no practice demo or sample data to clear away. People start doing instead of reading; task-based minimal instruction taught more efficiently than a standard manual. — *study/data* · [Carroll 1987] [Carroll 1987m]
- **ON-4 Empty states teach the next step.** Do: once loading has finished, say what goes here and offer the action in place; never "nothing here" while still loading; illustrations never look tappable.
  Check: an empty day, project and search. — *expert guideline* + *platform guideline* · [Kaplan 2021] [M1 Empty states]
- **ON-5 Ask for a permission when its feature is used.** Do: the microphone on the first tap of the mic; notifications after the first dated task (owner decision D2); calendar access only when the user turns on device calendars.
  Check: count system dialogs before the first saved task; the target is zero. — *platform guideline* · [Android Permissions] [Android Permission practices] [Android Notif permission] [Apple Privacy] [Play Permissions]
- **ON-6 Give the benefit first, in one sentence.** Do: before the system dialog, one sentence on what the user gains, with a single "Continue" button (Apple: never "Allow"); if the user dismisses it, don't show the system dialog.
  Check: the explainer's copy and buttons in three languages. In a CHI survey study of 772 people, requests that gave a reason were approved 74% of the time vs 66% without (the 12% NN/g cites is that relative rise), but what the reason said made no measurable difference. — *platform guideline* + *expert guideline* + *study/data* · [Apple Privacy] [Android Notif design] [Rosala 2019] [Tan 2014]
- **ON-7 A denial is not a dead end.** Do: keep the app working; where the missing feature would be, say what's unavailable and offer the alternative (typing, the form); offer Settings when the user tries the feature again.
  Check: the denied and denied-twice states; from Android 11 a second denial stops the system dialog for good. — *platform guideline* · [Android Permissions] [Android 11 Permissions] [Rosala 2019]
- **ON-8 Ask for notifications with the reason attached.** Do: tie the request to the action that needs it and say what will arrive ("a reminder before each task").
  Check: request timing and copy; swiping the system dialog away leaves the state unchanged, so plan for asking again. Asking at first launch and not saying what notifications will contain are two of NN/g's five push mistakes. — *platform guideline* + *expert guideline* · [Android Notif permission] [Kendrick 2018]
- **ON-9 Give before you take.** Do: every step between install and the first saved task is justified to the user.
  Check: account, email-code and permission steps on the first-run path. The login wall is an owner decision; raise evidence about it only as a question. — *expert guideline* · [Budiu 2014]
- **ON-10 Make safety visible.** Do: show that nothing is lost and that changes can be undone (Undo after changes, words kept after failures).
  Check: first-run copy and failure states. Only 33% of older respondents named trial and error among their top ways to learn a device (86% of younger ones), many feared damaging the phone, and 77% of US adults 65+ said they'd need help to learn a new device. — *study/data* · [Leung 2012] [Pew 2014]

## 7. Tasks, calendar and reminders (TA)

- **TA-1 Show a task among its day.** Do: after placing a task, show it in its day alongside that day's other items.
  Check: the landing view after save. People use calendars to remember what to do later, and re-read their plans by browsing them. — *study/data* · [Payne 1993] [Tungare 2008]
- **TA-2 Date-only tasks live on their day.** Do: tasks with a day but no time appear in that day's views, not only in a list.
  Check: a date-only task in the day and week views. A participant who hid his separate list of untimed tasks forgot them completely. — *study/data* · [Haraty 2012]
- **TA-3 Accept terse tasks; never block saving on details.** Do: a title alone, or a vague cue with a day, saves; durations, assignees and checklists are optional or inferred.
  Check: required fields in create flows. People disliked entering extra details; remembered durations matched estimates in only 25% of cases; students took 55.5 days for theses they expected to finish in 33.9. — *study/data* · [Bellotti 2004] [Buehler 1994]
- **TA-4 The day is the part that works.** Do: make attaching a day (and a time, for appointments) the most prominent part of creating a task.
  Check: the date line on cards and forms. If-then plans saying when and where to act had a medium-to-large effect on reaching goals (d = .65, 94 tests, 8,461 people), helped people get started (d = .61), and helped most those with self-regulation problems (d = 1.10 vs .66). — *study/data* · [Gollwitzer 2006] [Gollwitzer 1999]
- **TA-5 Choose the reminder default deliberately.** Do: one sensible, editable default — minutes before a timed task, a morning time for a date-only task (D2b uses 9:00).
  Check: the default and where it shows. People who didn't customise their tools never changed the default reminder yet complained about it; 15 minutes was the most common lead time; reminders to prepare came the evening before or that morning. — *study/data* · [Haraty 2016] [Tungare 2008]
- **TA-6 Reminders fire on time, or the app says why not.** Do: when exact alarms or notifications aren't allowed, say so where reminders are set, with one tap to the right setting, and re-check on return.
  Check: the denied paths in code and copy. On Android 12+ inexact alarms can arrive up to an hour late; Android 14 denies exact alarms by default to most new installs; on Android 13 an app unused for about 8 days may get one alarm a day. Plain timed reminders measurably help people with memory problems: with a reminder pager, over 80% of those who finished a 143-person trial did better at everyday tasks, and a meta-analysis found large benefits from memory-aid technology (d = 1.27 across 7 group studies). — *platform guideline* + *study/data* · [Android Alarms] [Android 14 Exact alarms] [Android Standby] [Wilson 2001] [Jamieson 2014]
- **TA-7 A reminder carries everything.** Do: what, when and with whom in the notification itself, with "Done" and "Move" actions.
  Check: reminder text and actions. People rarely open the app from calendar-type notifications; reminders about tasks already done waste time and frustrate, which a "Done" action on the reminder prevents. — *study/data* · [Pielot 2018] [White 2019]
- **TA-8 Postpone to times of day.** Do: offer "this evening", "tomorrow morning" or "pick a day" rather than "+3 h".
  Check: snooze and move options. In a year-long study 79% of snoozes were to later the same day; people thought in times of day, and durations made them calculate. — *study/data* · [Weber 2018]
- **TA-9 Overdue: calm, forgiving, one step.** Do: neutral wording and styling (no alarm red), one concrete action per item (move to a day, done, delete), and a calm way to let old items go.
  Check: colours, icons and copy of the overdue group (its name is owner decision D1). Unfinished tasks feed rumination; self-forgiveness went with less procrastination later; tasks undone after about two weeks rarely got done. No study tests overdue sections in to-do apps directly. — *study/data* · [Syrek 2017] [Wohl 2010] [Bellotti 2004]
- **TA-10 Capture is the bottleneck.** Do: adding a task is one obvious control from every entry point (button, widget, shortcut, share).
  Check: steps to a saved task from each entry point. The most common scheduling failure was never writing the item down; 93% enter events as soon as they hear of them. — *study/data* · [Brush 2005] [Tungare 2008]
- **TA-11 Near-term is the common case.** Do: "today", "later today" and "tomorrow" are the fastest days to set and to read; relative times ("in 20 minutes") work.
  Check: the first options in day pickers and the parser. About a quarter of 576,080 assistant reminders were due within the hour and about 80% within a day. — *study/data* · [Graus 2016]
- **TA-12 More reminder options are a product decision.** Do: don't add reminder options in a review; if the owner asks, evidence favours two reminders for appointments days ahead.
  Check: route it to "Questions for the owner". Text reminders raised clinic attendance from 67.8% to 78.6%; in a 54,066-patient trial, reminders 3 days and 1 day before cut no-shows to 4.4% vs 5.3–5.8% for a single one; across studies, more than one notification raised attendance more than one did (RR 1.49 vs 1.09). — *study/data* · [Cochrane 2013] [Steiner 2018] [Robotham 2016]

## 8. Notifications (NO)

- **NO-1 One channel per kind, named in plain words.** Do: separate channels for reminders and for anything else (for example shared-project activity), so muting one never mutes the other; reminders at high importance, the rest lower.
  Check: channel IDs, names and importance in code. Once a channel exists the user owns its settings and the app can't change its importance, so decide before release. — *platform guideline* · [Android Channels] [Android Notif design]
- **NO-2 Mark reminders as reminders.** Do: set the Android notification category (reminder, or event for timed items) so Do Not Disturb's priority settings treat them as the user expects.
  Check: the Android notification details in code set a category. — *platform guideline* · [Android Notifications]
- **NO-3 Short, front-loaded text.** Do: title ≤ 30 characters, task first, no app name; text ≤ 40 characters that doesn't repeat the title.
  Check: reminder strings in ES, CA and EN. — *platform guideline* · [Android Notif design]
- **NO-4 Tap opens the task; at most three actions.** Do: tapping opens that task, not just the home screen; actions don't repeat what the tap does.
  Check: the notification's tap intent and actions; Android 12+ forbids opening screens through a service or receiver "trampoline". — *platform guideline* · [Android Build notification] [Android 12 changes]
- **NO-5 Every notification costs attention.** Do: notify only for what the user asked for (reminders) or what concerns them personally; no promotions, re-engagement, greetings or sync status.
  Check: list every notification type the app can send. Just receiving a notification disrupted an attention task; a week with alerts on raised inattention; people get a median of about 56 notifications a day; a day with none left people less distracted but more anxious, so cut noise, not reminders. — *study/data* + *platform guideline* · [Stothart 2015] [Kushlev 2016] [Pielot 2018] [Pielot 2017] [Android Notif design]
- **NO-6 Bundle bursts.** Do: group reminders that fire together, or update one notification instead of posting many.
  Check: five tasks due at 9:00 read well as a group and one by one; Android groups four or more automatically. — *platform guideline* + *expert guideline* · [Android Notif group] [Kendrick 2018]
- **NO-7 Defer what isn't urgent.** Do: shared-project activity can wait or be summarised; reminders fire on time.
  Check: which notification types are time-critical. Holding desktop notifications until a natural break cut frustration and reaction time; with over 680,000 phone users, delivering at predicted breaks cut response time by 49.7% and more notifications were opened; digests were the most popular option for shared-document updates. — *study/data* · [Iqbal 2008] [Okoshi 2017] [Brush 2001]
- **NO-8 Notification controls inside the app.** Do: reminder settings are reachable in the app and say whether reminders will actually arrive.
  Check: the notification settings screen states the permission and exact-alarm status in words. Hard-to-find controls are one of NN/g's five push mistakes. — *expert guideline* · [Kendrick 2018]
- **NO-9 Lock-screen privacy is the owner's call.** Do: whether task titles show on the lock screen (public, private or secret visibility) is a product decision.
  Check: the visibility set in code; raise a question if personal titles show by default. — *platform guideline* · [Android Build notification]

## 9. Feedback, undo and destructive actions (UN)

- **UN-1 Answer every tap within 0.1 s.** Do: show a pressed or changed state at once, even when the work takes longer.
  Check: buttons that start slow work change state immediately. — *expert guideline* · [Nielsen 1993] [Harley 2018]
- **UN-2 Confirm in place, not only in a snackbar.** Do: show the result where it happened (the task on its day, the row ticked); a snackbar adds Undo, it isn't the proof of success.
  Check: flows whose only success signal is a snackbar. Toasts and snackbars disappear before people notice them, and changes outside the focus get missed. — *expert guideline* · [Flaherty 2024] [Budiu 2018cb]
- **UN-3 Undo beats "Are you sure?".** Do: perform reversible actions at once and offer Undo; confirm only what can't be undone or affects other people.
  Check: confirmation dialogs on routine actions. Routine confirmations get clicked through by habit; Google's design guides skip confirmation when an action is reversible or negligible; WCAG accepts "reversible" as one of three safeguards. — *expert guideline* + *platform guideline* + *standard/law* · [Nielsen 2018c] [Raskin 2000] [Android 2013 Confirming] [M2 Confirmation] [WCAG 2.2] (3.3.4)
- **UN-4 When you must confirm, name the outcome.** Do: say what will happen to which item; buttons name outcomes ("Delete series" / "Keep task"); the destructive one is never the default.
  Check: no Yes/No or OK/Cancel pairs; no "Are you sure?". — *expert guideline* + *platform guideline* · [Nielsen 2018c] [M3 Dialogs] [Apple Alerts]
- **UN-5 Undo lasts long enough to use.** Do: a snackbar carrying Undo stays until used or dismissed (Material's guidance, and Flutter's default since 3.38); if it times out instead, its duration follows Android's accessibility timeout and there is a second way back.
  Check: `persist: false` and the duration on every snackbar with an action; a persistent one can be dismissed and doesn't cover the primary action. A time limit must be removable, extendable or adjustable to 10× (WCAG 2.2.1); Android's docs warn an Undo snackbar can be missed; Flutter's snackbar code shows no sign of reading Android's accessibility timeout, so the app must pass it in. — *platform guideline* + *standard/law* · [M3 Snackbar] [Flutter SnackBar persist] [WCAG 2.2] (2.2.1) [Android Snackbar action] [Rosala 2020]
- **UN-6 One message at a time, without losing an Undo.** Do: a new message must not silently replace an Undo the user still needs.
  Check: two deletes or completes in quick succession. — *platform guideline* · [M3 Snackbar] [MDC Snackbar]
- **UN-7 Errors: what happened, what to do, nothing lost.** Do: plain words, a next step, no blame and no jokes, next to the cause; the user's words are kept.
  Check: every error string and where it shows; none appears only as a toast. Older adults blamed themselves for problems 90% of the time. — *expert guideline* + *study/data* · [Neusesser 2023] [Flaherty 2024] [Nielsen 2013]
- **UN-8 "Nothing found" isn't a dead end.** Do: make it obvious nothing matched, restate what was looked for (editable), and offer a way forward.
  Check: voice find, change and delete with no match. — *expert guideline* · [Whitenton 2014]
- **UN-9 Never lose input.** Do: Back, a dismissed sheet, a call, backgrounding or the app being killed keep what the user said or typed.
  Check: each interruption path, with Android's "Don't keep activities" as a device check. — *expert guideline* + *standard/law* · [COGA 2021] [WCAG 2.2] (2.2.6)
- **UN-10 Saved on the phone first, honest about sync.** Do: a confirmed task appears at once and survives having no network; a later sync failure is shown calmly where it matters.
  Check: save offline, then fail the sync. Android's architecture guide uses a to-do app as its example of local-first data; "optimistic UI" has no rigorous evidence base, so judge it by honest status. — *platform guideline* · [Android Offline-first] [Harley 2018]

## 10. Forms (FO)

- **FO-1 Ask the minimum.** Do: title first, then day and time; everything else under one "More details" that names or shows what's inside.
  Check: ask of each field whether it's needed at all. — *expert guideline* · [Budiu 2015] [Nielsen 2006] [COGA 2021]
- **FO-2 Labels stay visible.** Do: every field has a label outside it that stays after typing.
  Check: fields whose only label is placeholder text. Placeholders vanish while typing, get mistaken for values and are often low-contrast. — *expert guideline* · [Sherwin 2014pl] [COGA 2021]
- **FO-3 Dates: today first, a calendar for the rest, typing allowed.** Do: one-tap Today and Tomorrow, a calendar with today marked for other days, typing accepted, and the chosen day shown with its weekday.
  Check: the day control and its confirmation. Pickers suit dates near today; 80% of Baymard's test users weren't sure which date "this Friday" meant. — *expert guideline* + *study/data* · [Li 2017d] [Baymard 2015f]
- **FO-4 Times: typing as well as the dial.** Do: accept typed times and treat "10", "10:00" and "10h" alike; choose the time picker's starting mode on purpose.
  Check: `showTimePicker`'s `initialEntryMode` and the time parser. An older participant asked to type a time instead of using a picker. — *study/data* + *expert guideline* · [Kane 2019] [Laubheimer 2015] [Flutter showTimePicker]
- **FO-5 The right keyboard.** Do: number pad for codes and typed times; email keyboard without autocorrect or capitals for addresses; sentence capitals for task titles.
  Check: `keyboardType`, `autocorrect` and `textCapitalization`. 54% of 48 leading mobile sites showed the wrong keyboard for phone, postcode or card fields. — *study/data* · [Baymard 2015k] [Budiu 2015]
- **FO-6 Validate after the field, not during typing.** Do: check a field when the user leaves it (a fixed-length code when complete); clear the error on the keystroke that fixes it; never mark a field the user hasn't touched.
  Check: what triggers each validator. In a 22-person test, validating after leaving a field gave 22% more success and 42% less time than validating on submit; validating while typing did worst. — *study/data* · [Wroblewski 2009] [Baymard 2024] [Krause 2019]
- **FO-7 Errors under the field, in words.** Do: text plus an icon below the field — not colour alone, not a tooltip, not a toast.
  Check: how errors render. — *expert guideline* + *standard/law* · [Krause 2019] [WCAG 2.2] (1.4.1, 3.3.1, 3.3.3)
- **FO-8 The keyboard never hides the field, its error or the main button.** Do: scroll the focused field and its message into view above the keyboard, and keep the main button reachable.
  Check: render with the keyboard open at 2× on 360 dp; the keyboard can cover half the screen. — *study/data* + *standard/law* · [Baymard 2015f] [WCAG 2.2] (2.4.11)
- **FO-9 Codes paste and autofill.** Do: one-time codes accept paste and autofill (`AutofillHints.oneTimeCode`) and use the number pad; submitting as soon as the code is complete is optional.
  Check: the code field. Typing a code by hand counts as a cognitive test under WCAG 3.3.8 unless paste or autofill works; Visa's pattern also supports paste and autofill from SMS or notifications, and keeps a submit button. — *standard/law* + *convention/opinion* · [WCAG 2.2] (3.3.8) [Visa OTP] [Baymard 2015k]
- **FO-10 Don't ask twice.** Do: carry what the user already said or typed into the next step (dictated words into the form, the email onto the code screen).
  Check: steps that ask again for known information. — *standard/law* · [WCAG 2.2] (3.3.7)
- **FO-11 One screen for everyday creation.** Do: daily task creation is a single screen, not a wizard.
  Check: steps in the form. Wizards suit rare, unfamiliar tasks and become tedious when repeated. — *expert guideline* · [Budiu 2017]

## 11. Accessibility on Android (AC)

- **AC-1 Text contrast, measured, in both themes.** Do: 4.5:1 for text below 24 px (below ≈ 18.5 px if bold), 3:1 above; aim higher for body text; never round (4.49:1 fails).
  Check: measure secondary greys and text on tinted chips and calendar blocks, in light and dark. Android's and Flutter's "large text" cut-off (18 sp / 18 logical px) is more lenient than WCAG's 18 pt ≈ 24 px, so a passing `textContrastGuideline` doesn't prove WCAG for 18–23 px text. — *standard/law* + *platform guideline* · [WCAG 2.2] (1.4.3) [Android A11y apps] [Flutter a11y src]
- **AC-2 Non-text contrast 3:1.** Do: field borders, chip outlines, selected states, the today marker and icon-only controls reach 3:1 against their neighbours; use Material's `outline` (not `outlineVariant`) for the edges of tappable things.
  Check: chip and field borders in both themes. — *standard/law* + *platform guideline* · [WCAG 2.2] (1.4.11) [M3 Color roles]
- **AC-3 Works at 200% text.** Do: nothing clips, overlaps or stops working at Android's 200% font scale; no `TextScaler.noScaling` or scale clamps on essential text; no fixed heights around text.
  Check: render key screens at 2.0 in ES and CA; grep for `noScaling`, `maxScaleFactor`, fixed heights on text containers, and `maxLines: 1` with ellipsis on essential labels. Android 14 scales non-linearly, so titles grow less than body text. — *standard/law* + *platform guideline* · [WCAG 2.2] (1.4.4) [Android 14 features] [Flutter nonlinear]
- **AC-4 Reflow at 320 dp.** Do: at 320 dp and 2× text no text needs sideways scrolling; a grid such as the calendar may scroll, but its labels aren't cut.
  Check: 320 dp renders. — *standard/law* · [WCAG 2.2] (1.4.10) [WCAG2ICT 2025]
- **AC-5 Never colour alone.** Do: overdue, priority, project, selection and errors also use text, an icon or a shape.
  Check: view the render in greyscale. About 1 in 12 men have a colour vision deficiency. — *standard/law* + *study/data* · [WCAG 2.2] (1.4.1) [NEI 2025]
- **AC-6 Every control has a name, role and value.** Do: labels say what the control does, contain its visible words, don't add "button", and are unique in lists; decorative images are excluded; related parts merge into one node.
  Check: custom `GestureDetector`/`InkWell` widgets carry `Semantics(button: true, label: …)`; run `labeledTapTargetGuideline`. — *standard/law* + *platform guideline* · [WCAG 2.2] (4.1.2, 2.5.3) [Android A11y apps] [Android A11y principles]
- **AC-7 Announce what changes.** Do: results, saves and errors are announced politely without moving focus; each screen's title is announced on arrival.
  Check: live regions (`Semantics(liveRegion: true)`) on status text; headings marked as headers. — *platform guideline* · [Android A11y testing] [M3 Snackbar]
- **AC-8 Focus is never hidden.** Do: sticky bars, the FAB and sheets never fully cover the focused item.
  Check: bottom padding of lists under a FAB or bottom bar. — *standard/law* · [WCAG 2.2] (2.4.11)
- **AC-9 Gestures have accessibility actions.** Do: swipe, long-press and drag actions also appear as TalkBack custom actions.
  Check: a `CustomSemanticsAction` (or `Semantics` callback) for each gesture. — *platform guideline* + *standard/law* · [Android A11y principles] [Flutter CustomSemanticsAction] [WCAG 2.2] (2.5.1, 2.5.7)
- **AC-10 Respect "Remove animations".** Do: when `MediaQuery.disableAnimationsOf` is true, use fades instead of slides and scales, and stop decorative loops such as a pulsing mic.
  Check: custom `AnimationController`s and `repeat()` calls; framework animations shorten, repeating ones keep running unless the code checks. — *platform guideline* + *standard/law* · [M3 Transitions] [Flutter disableAnimations] [Flutter AnimationBehavior] [WCAG 2.2] (2.3.3)
- **AC-11 No silent time limits.** Do: anything that disappears or expires (messages, codes, listening caps) can be turned off, extended or adjusted, or isn't the only way to act.
  Check: timers in UI code. Android offers 10 s to 2 min of "time to take action", but Flutter shows no sign of reading it on its own; Apple asks for as few time-limited elements as possible. — *standard/law* + *platform guideline* · [WCAG 2.2] (2.2.1) [Android Timeout help] [Apple A11y]
- **AC-12 Don't lock orientation without need.** Do: support landscape unless an orientation is essential.
  Check: `SystemChrome.setPreferredOrientations` and `android:screenOrientation`. — *standard/law* · [WCAG 2.2] (1.3.4)
- **AC-13 Automated checks first, then a person.** Do: widget tests with `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`; then TalkBack, Switch Access, Voice Access and Accessibility Scanner on a phone.
  Check: say which you used: tests are code evidence, TalkBack is device evidence. — *platform guideline* · [Flutter a11y testing] [Android A11y testing]
- **AC-14 Measure hit areas, not icons.** Do: 48 × 48 dp hit areas including padding; custom tappables, and anything using `shrinkWrap`, `VisualDensity.compact` or `padding: EdgeInsets.zero`, get an explicit minimum size.
  Check: grep for those patterns. — *platform guideline* · [Flutter MaterialTapTargetSize] [Android Touch targets]
- **AC-15 Use COGA as the cognitive lens.** Do: test each screen against COGA's eight objectives: understand what things are and how to use them; find what's needed; clear content; avoid and fix mistakes; help focus; don't rely on memory; help and support; adaptation and personalisation.
  Check: tag cognitive findings with the objective broken. — *expert guideline* · [COGA 2021]

## 12. Older adults and non-technical users (OL)

- **OL-1 Design for recovery, not only for speed.** Do: assume twice the errors and slower completion; every step can be undone or retried.
  Check: what follows a wrong tap at each step. Seniors' task success was 55% vs 75% for 21–55-year-olds, about 43% slower, with 2.4 vs 1.1 errors per task (2013); NN/g's 2019 round found older users more confident but still hurt by small text, small targets and rigid input. — *study/data* · [Nielsen 2013] [Kane 2019]
- **OL-2 Never imply fault.** Do: errors and limits say what happened and what to do; never "invalid", "wrong" or "not allowed".
  Check: error and limit strings. Seniors blamed themselves for problems 90% of the time (younger users 58%) and were almost twice as likely to give up. — *study/data* · [Nielsen 2013]
- **OL-3 A visible control for everything.** Do: no feature reachable only by gesture, long press or a hidden mode.
  Check: as PL-8. Older adults did gestures fine but couldn't find gesture-only functions without guidance; long-press pop-ups faded before they could choose. — *study/data* · [Kobayashi 2011] [Harada 2013]
- **OL-4 Words on icons, words for modes.** Do: label icons and keys; show modes (listening, editing, selecting) with large, persistent indicators in words.
  Check: unlabelled icons and unannounced mode changes; older adults missed both. — *study/data* · [Kobayashi 2011] [Leung 2011]
- **OL-5 An explicit way out.** Do: menus and sheets have a visible Close or Cancel; tapping outside is never the only exit.
  Check: each sheet and menu. — *study/data* · [Harada 2013]
- **OL-6 Keep what works where it is.** Do: avoid moving or renaming working controls between versions.
  Check: changes to stable navigation in the diff. Older users keep their own written instructions. — *study/data* + *expert guideline* · [Nielsen 2013] [COGA 2021]
- **OL-7 Fewer words.** Do: cut copy; NN/g's own estimate is about 11% fewer words for readers over 50.
  Check: word counts at decision points. Reading speed fell about 1.5 words a minute per year of age among 352 readers aged 18–71 (only 26 were over 50). — *study/data* + *expert guideline* · [Wallace 2022] [Nielsen 2022]
- **OL-8 Help inside the app, when needed.** Do: short, repeatable help where the question arises, not a manual or a one-off tutorial.
  Check: where help lives and whether it can be found again. Half of older respondents preferred the device's built-in help; later work (42 people aged 65–83 surveyed, 27 interviewed) found older adults value self-paced, flexible learning and rely less on manuals. — *study/data* · [Leung 2012] [Pang 2021]
- **OL-9 Dark mode is not an accessibility aid.** Do: follow the system theme (D5) and make the light theme as strong as the dark one.
  Check: contrast in both themes. Dark text on a light background gave better proofreading and acuity results for younger and older adults alike. — *study/data* · [Piepenbrock 2013]
- **OL-10 Taps over drags.** Do: make a tap the main way to do everything; dragging and pinching are optional.
  Check: drag-only reschedule or reorder. Touch narrowed the age gap compared with a mouse, but dragging and pinching stayed slow for older adults. — *study/data* · [Findlater 2013]
- **OL-11 First run without a helper.** Do: assume WhatsApp-level skills and nobody to ask.
  Check: the Newcomer's walkthrough of first run. In Spain 84% of 65–74-year-olds use the internet on a phone, but only about half of 75–89-year-olds used the internet in the last three months (2025); in the US, 77% of people 65+ said they'd need help to learn a new device (2014). — *study/data* · [Eurostat 2025] [Pew 2014] [Pew 2025]
- **OL-12 Honour the phone's settings.** Do: respect system text size, display size, bold text and contrast settings; never override them.
  Check: overrides of text scaling or fonts. Interfaces adapted to users' measured abilities made 11 motor-impaired users 26% faster, with 73% fewer errors. — *study/data* · [Gajos 2008]

## 13. Subscriptions, limits and paywalls (SU)

- **SU-1 Price, period and renewal beside the button.** Do: price, billing period and automatic renewal next to Subscribe, with no extra tap, fully translated.
  Check: the Pro screen in ES, CA and EN. — *platform guideline* · [Play Subscriptions]
- **SU-2 Say the free path exists.** Do: the paywall says what stays free (the monthly dictations and the form).
  Check: paywall and limit copy. Play lists hiding that an app is usable without subscribing as a violation; hidden information was the most common manipulative practice in the EU's 2023 sweep. — *platform guideline* + *study/data* · [Play Subscriptions] [EC Sweep 2023]
- **SU-3 Trials, if ever, spelled out.** Do: length, price afterwards, when it converts and how to cancel before then.
  Check: any trial copy. — *platform guideline* · [Play Subscriptions]
- **SU-4 Cancelling as easy as subscribing.** Do: subscribers see "Manage subscription" in Settings, opening Play's subscription page (the product deep link while active); after cancelling, "Pro until <date>".
  Check: taps from Settings to Play's cancel screen (EU authorities got Amazon Prime down to two clicks in 2022). Spain's consumer law lets people end a contract "en la misma forma en que lo celebró". — *platform guideline* + *standard/law* · [Play Subscriptions] [Play Billing subscriptions] [BOE TRLGDCU] [EC Fitness 2024]
- **SU-5 Prices come from the store.** Do: prices are the localized Play product (via RevenueCat), never hard-coded.
  Check: price strings in code and ARB files. — *platform guideline* · [Play Payments]
- **SU-6 No deceptive patterns.** Do: no countdowns, false scarcity or alarm styling on limits; the decline option is as visible as accept and worded neutrally (no confirmshaming); nothing preselected; no repeated nagging.
  Check: each paywall and upsell against Gray's five strategies — nagging, obstruction, sneaking, interface interference, forced action. 95% of 240 popular apps had at least one dark pattern and most users didn't notice; in EU experiments with 7,430 people, dark patterns pushed choices against people's own preferences, most among older and less-educated consumers. — *study/data* + *expert guideline* · [Gray 2018] [Di Geronimo 2020] [Mathur 2019] [EC Fitness 2024] [Rosala 2023]
- **SU-7 Explain a limit when it bites.** Do: when the free dictations run out, one short message: what's used up, what still works, the reset date, one next step — never an error, never blame.
  Check: the out-of-dictations path from every entry point (button, widget, shortcut, share). — *expert guideline* + *convention/opinion* · [Kane 2019] [RevenueCat Paywalls]
- **SU-8 Walk upsells as the most vulnerable user.** Do: run the cognitive walkthrough of every paywall as the Newcomer; don't rely on testers to spot manipulation.
  Check: the walkthrough appears in the report. — *expert guideline* · [Rosala 2023] [Di Geronimo 2020]
- **SU-9 Payment problems never block the free path.** Do: grace-period and account-hold messages explain and link to Play while free features keep working.
  Check: those states. — *platform guideline* · [Play Billing subscriptions]
- **SU-10 Legal points go to the owner.** Do: report these as questions, not findings: Spain's 15-day notice before a renewal deadline (TRLGDCU art. 97.1 p); the EU withdrawal function that applies from 19 June 2026 (a "withdraw from contract here" function for the 14-day withdrawal right, not a cancel button), for which no Spanish transposition was found by 18 Oct 2026; the "order with obligation to pay" button (TRLGDCU art. 98.2, «pedido con obligación de pago»); who owes them when Google sells the subscription — in the EEA, Play's terms make Google Commerce Limited the contracting party, and Google is the merchant of record in Spain; Catalan versions of offers and terms. The EU Digital Fairness Act isn't proposed yet (indicative Q4 2026).
  Check: not a screen check. — *standard/law* + *platform guideline* · [BOE TRLGDCU] [EU 2023/2673] [EU 2023/2673 NIM] [Play ToS 2025] [Play Merchant of Record] [Catalan Code 22/2010] [EP DFA 2026]
- **SU-11 Read vendor benchmarks as context only.** Do: never use conversion benchmarks to justify blocking the bar user.
  Check: not a screen check. Median download-to-paid by day 35 was 10.7% with hard paywalls vs 2.1% for freemium (2025 data) — vendor correlations, not causes. — *convention/opinion* · [RevenueCat 2026]

## 14. Performance as felt (PE)

- **PE-1 Instant means under 0.1 s.** Do: every tap answers within 0.1 s; drags keep up with the finger.
  Check: in a release build on a mid-range phone, tap the mic, Done and save (device check); delays of about 60 ms are already noticeable. — *expert guideline* + *study/data* · [Nielsen 1993] [Forch 2017]
- **PE-2 Progress after a second, an explanation after ten.** Do: over 1 s a busy indicator; 2–10 s a moving indicator that names the step; over 10 s percent-done or an explanation, plus cancel or an alternative.
  Check: each waiting state and its timers. — *expert guideline* · [Nielsen 1993] [Sherwin 2014pr] [Tankala 2023]
- **PE-3 Skeletons only for whole-screen first loads.** Do: nothing under 1 s; a skeleton only when a full screen takes longer; never flash one.
  Check: the calendar's first load. The evidence that skeletons feel faster is mixed; one non-peer-reviewed test found them worst. — *expert guideline* + *convention/opinion* · [Tankala 2023] [Viget 2017]
- **PE-4 Don't stall near the end.** Do: no progress that hangs at "almost done".
  Check: the last step of capture (saving). Progress that paused near the end felt slowest. — *study/data* · [Harrison 2007]
- **PE-5 Deliver results complete.** Do: show a result when its key content is ready, not piece by piece.
  Check: cards whose date or count pops in late. Content that loaded late got 1% of viewing time vs 20% when present at once. — *expert guideline* · [Nielsen 2010]
- **PE-6 Never block the UI thread.** Do: no input left unanswered for 5 s; microphone, saving and reminder work stay off the UI thread.
  Check: report frozen screens as user-visible symptoms. An app that doesn't answer input in 5 s shows an ANR dialog, and a user-perceived ANR rate ≥ 0.47% is bad behaviour on Play. — *platform guideline* · [Android ANR] [Android Vitals]
- **PE-7 Start into the calendar fast.** Do: draw the calendar from local data first; don't wait for the network.
  Check: the start-up path. Play flags cold starts ≥ 5 s, warm ≥ 2 s and hot ≥ 1.5 s (Play Console Help says 1 s for hot). — *platform guideline* · [Android Launch time] [Play Vitals help] [Android Offline-first]
- **PE-8 Smooth frames.** Do: scrolling and swiping stay smooth (≈ 16 ms per frame at 60 Hz).
  Check: report stutter as a device check. Play counts a session as slow when over 50% of frames take more than 16 ms, and frozen when over 0.1% take more than 700 ms. — *platform guideline* · [Play Vitals help] [Android Slow rendering]

## 15. Shared projects (SH)

- **SH-1 Viewers need no training.** Do: a shared project reads correctly to someone who only looks.
  Check: a member's view of a project they didn't create. Families usually have one main organiser and mostly passive viewers. — *study/data* · [Neustaedter 2006]
- **SH-2 Awareness in place, not by ping.** Do: show who created, assigned or changed something on the item itself.
  Check: "Created by", assignee and "changed by" lines. Awareness picked up from the shared workspace beat explicit update messages; families read each other's whereabouts off the shared calendar at a glance, but feared unnoticed changes and wanted to see what changed and who changed it (20 mothers). — *study/data* · [Dourish 1992] [Neustaedter 2006b]
- **SH-3 One named person.** Do: assignment names one person, and messages to others name them.
  Check: "everyone" assignments and project-wide pings. Help came later as groups grew, unless one person was named; tasks someone was expecting got done more often (77% vs 53%). — *study/data* · [Darley 1968] [Markey 2000] [Bellotti 2004]
- **SH-4 Don't notify the actor; say who did what.** Do: never notify the person who made a change; each notification names who and what; non-urgent activity is bundled.
  Check: the triggers for shared-change notifications. Group messages were seen and read later than one-to-one ones. — *study/data* · [Brush 2001] [Pielot 2018]
- **SH-5 Minimal roles, changed in place.** Do: owner and member at most, changeable on the person's row (D15b).
  Check: role choices shown during invites. People rarely set permissions, so defaults became the permission model. — *study/data* · [Smetters 2009] [Dourish 1992]
- **SH-6 Voice changes to shared tasks say whose they are.** Do: the before → after of a voice change or delete names the project and the assignee.
  Check: command cards on shared tasks. EDPB warns that without safeguards anyone near a voice assistant could delete other people's data. — *expert guideline* · [EDPB VVA 2021]

## 16. Localization: Spanish, Catalan, English (LO)

- **LO-1 Budget for the longest language.** Do: layouts flex for 2–3 times the English length on short labels; no fixed widths; no abbreviations to fit.
  Check: buttons, chips and tabs in CA and ES at 2×. Short strings grow most: up to 10 characters 200–300%, 11–20 characters 180–200%, over 70 characters about 130% (IBM figures). — *expert guideline* · [W3C Text size]
- **LO-2 Plurals and selects in ICU, as whole sentences.** Do: every count uses an ICU plural with an `other` case; each case is a full sentence; nothing is concatenated.
  Check: grep for `'$count '` plus a noun and for joined strings. Spanish and Catalan also have a "many" category (millions) that falls back to `other`, so omitting it is safe; don't write both `=1` and `one`. — *convention/opinion* + *platform guideline* · [CLDR Plurals] [ICU Messages] [Flutter i18n]
- **LO-3 Dates through locale formats.** Do: build dates from intl patterns; day and month names are lowercase in ES and CA mid-sentence; Catalan month names in dates carry "de"/"d’" (U+2019) themselves ("19 d’octubre").
  Check: no `'de ' + month`, no hand capitalisation; tests compare with U+2019. — *convention/opinion* · [intl CLDR data]
- **LO-4 Honour the 12/24-hour setting.** Do: format user-visible times with `TimeOfDay.format`/`formatTimeOfDay` and `MediaQuery.alwaysUse24HourFormat`.
  Check: `DateFormat.Hm`/`jm` on user-visible times; intl ignores the user's Android setting. — *platform guideline* · [Flutter MediaQuery src]
- **LO-5 Week start from the locale.** Do: read `MaterialLocalizations.firstDayOfWeekIndex` from the global localizations: Monday for es, ca and en-GB, Sunday for en-US.
  Check: hard-coded Monday or Sunday. Android 14's user setting for the first day of the week isn't passed to Flutter. — *platform guideline* · [Flutter MaterialLocalizations src] [Android 14 features]
- **LO-6 Expect special spaces in times.** Do: allow for CLDR's narrow no-break space (U+202F) in formatted times.
  Check: string matches in tests and golden files. — *convention/opinion* · [intl CLDR data]
- **LO-7 Catalan l·l and apostrophes.** Do: write the ela geminada as l + U+00B7 (never "l.l" or U+0140); keep one apostrophe style.
  Check: grep the CA ARB file. — *convention/opinion* · [IEC 2017] [Unicode UCD]
- **LO-8 Catalan buttons in the imperative.** Do: button verbs in the singular imperative («Desa», «Obre»), not the infinitive.
  Check: CA button strings. — *convention/opinion* · [Softcatalà]
- **LO-9 One form of address per language.** Do: choose tú or usted (ES) and tu or vós (CA), record it in `App/docs/LOCALIZATION.md` and use it everywhere; avoid gendered address such as «Bienvenido».
  Check: mixed forms across screens. Style guides disagree (Mozilla's two Spanish guides differ; Softcatalà addresses users as vós), so consistency is the rule. — *convention/opinion* · [Mozilla es] [Softcatalà] [Android 14 features]
- **LO-10 Sentence case.** Do: capitalise only the first word of buttons, titles and menu items in ES and CA.
  Check: Title Case carried over from English. — *convention/opinion* · [Softcatalà] [Mozilla es]
- **LO-11 Native strings complete and annotated.** Do: every Android string exists in the default resources and in all three languages, with translator comments on space limits; the app language and the speech-recognition language follow the same setting (per-app language, Android 13).
  Check: `res/values*/strings.xml`, the locale config and `EXTRA_LANGUAGE`. — *platform guideline* · [Android Localization] [Android App languages]
- **LO-12 Catalan is a consumer right.** Do: paywall terms, receipts and cancellation text exist in Catalan.
  Check: English or Spanish fallbacks in the CA catalog. Catalonia's consumer code entitles consumers to Catalan versions of offers and contract documents. — *standard/law* · [Catalan Code 22/2010]

## 17. Privacy in the app (PR)

- **PR-1 Explain at the moment of use.** Do: at the first dictation, one sentence on where the audio goes, what it's for and how long it's kept, with a link to more; the same text stays findable in Settings.
  Check: first microphone use and the voice settings. Information must be concise and plain when it's collected; regulators recommend layered notices and describe just-in-time ("push") notices as another option, and privacy-notice research pairs an app's first access to recording with a just-in-time notice. — *standard/law* + *expert guideline* · [GDPR] (arts. 12, 13) [WP260 2018] [Schaub 2015] [EDPB VVA 2021]
- **PR-2 Disclosure before the microphone prompt, where Play requires one.** Do: if audio leaves the phone in ways users might not expect, show an in-app disclosure naming the data and its use, then a deliberate "Continue", then the system prompt; Back or leaving isn't consent; never imitate the system dialog.
  Check: wording and order. Whether TaskFlow needs it is a policy call for the owner. — *platform guideline* · [Play User Data] [Play Disclosure practices]
- **PR-3 Minimal by default.** Do: keeping recordings, human review and training use are off unless needed and chosen, each with its own explanation.
  Check: privacy defaults and their copy. — *standard/law* + *expert guideline* · [GDPR] (art. 25) [EDPB VVA 2021]
- **PR-4 Withdrawing is as easy as agreeing.** Do: every consent has an equally simple, findable way to turn it off.
  Check: taps to turn each one off. — *standard/law* · [GDPR] (art. 7(3))
- **PR-5 Say plainly whether audio is kept.** Do: state in plain words whether the recording and the transcript are kept, and for how long.
  Check: the in-app line matches what the server really does (if not, the cause is likely server-side). Almost half of smart-speaker owners didn't know their recordings were kept. — *study/data* · [Malkin 2019]
- **PR-6 The microphone is on only while listening.** Do: capture starts on the user's tap and stops when the listening state ends; no background or wake-word listening.
  Check: when recording starts and stops (device check with Android's microphone indicator). Fear of "always listening" is common, though a study of 17,260 Android apps found none sending recorded audio out (with caveats). — *study/data* + *platform guideline* · [Laubheimer 2018a] [Pan 2018] [Android Sensitive access]
- **PR-7 No deceptive privacy design.** Do: no buried off switches, emotional nudges or overloaded choices.
  Check: privacy settings against EDPB's six categories: overloading, skipping, stirring, obstructing, fickle, left in the dark. — *expert guideline* · [EDPB 03/2022]

## 18. Myths to avoid

- **"Keep everything in the thumb zone; the top is unreachable."** Hoober withdrew his 2013 reach drawings: people touch and look at the centre most, and still use a top-corner Back. [Hoober 2013] [Hoober 2017a]
- **"48 dp means the button must look 48 dp."** The target includes padding; a 24 dp icon can have a 48 dp target. [Android Touch targets]
- **"WCAG AA needs 44 × 44."** AA is 24 × 24 (2.5.8); 44 × 44 is AAA (2.5.5). For 60+ users even 48 dp is a floor. [WCAG 2.2] [Kobayashi 2011] [Franz 2019]
- **"Large text starts at 18 px" and "4.47:1 rounds to 4.5:1."** Large is 18 pt ≈ 24 px (14 pt bold ≈ 18.5 px), and ratios aren't rounded. [WCAG 2.2]
- **"The three-click rule."** No data supports it; Porter's 2003 test found no extra drop-off after three clicks. [Laubheimer 2019]
- **"Seven, plus or minus two."** Miller's figure was a rough estimate about recall; working memory holds about four chunks, and choosing from a visible menu is recognition, not recall. [Cowan 2001] [Laubheimer 2019]
- **"Choice overload always strikes."** Its average effect across studies is about zero; it depends on the conditions in CO-4. [Scheibehenne 2010] [Chernev 2015]
- **"A short tutorial helps first-time users."** It didn't improve success or speed and made tasks feel harder. [Kendrick 2020t]
- **"'Are you sure?' prevents mistakes."** Only when rare; routine confirmations are clicked through. [Nielsen 2018c] [Raskin 2000]
- **"An Undo snackbar is enough."** It can vanish before the user knows they need it. [Rosala 2020] [Android Snackbar action]
- **"Speech is three times faster, so voice always wins."** That figure is young adults copying phrases; composing and correcting shrink or erase the gain. [Ruan 2017] [Foley 2020] [Suhm 2001]
- **"If it misheard, just say it again."** Re-speaking fixed 35% of errors and got worse on each retry. [Suhm 2001]
- **"Voice is naturally easy for older adults."** First impressions turned negative, most long-term owners stopped using their speaker, and older voices are misrecognised more. [Kim 2021] [Trajkova 2020] [Vipperla 2010]
- **"Older people don't use smartphones."** 78% of US adults 65+ own one, and 84% of Spanish 65–74-year-olds use the internet on a phone; the drop comes after 75. [Pew 2025] [Eurostat 2025]
- **"Older adults can't do gestures."** They can; they can't discover them. [Kobayashi 2011] [Findlater 2013]
- **"Dark mode is easier on older eyes."** Dark text on light performed better at all ages. [Piepenbrock 2013]
- **"Bigger, brighter elements always catch the eye first."** On phone screens, fixations favoured the top-left, text and images; brightness had no effect and size mattered little. [Leiva 2020]
- **"People don't scroll" and "the fold doesn't matter."** Both are wrong: people scroll, but attention concentrates at the top. [Fessenden 2018]
- **"Design for the F-pattern."** It's a symptom of poorly formatted text. [Pernice 2017]
- **"Everyone understands the hamburger menu."** Hidden navigation is used far less. [Pernice 2016a]
- **"Translations are about 30% longer."** Short labels can grow 200–300%. [W3C Text size]
- **"0.1 / 1 / 10 s and 400 ms are measured human limits."** 0.1 / 1 / 10 s are rules of thumb from an essay; the 400 ms "Doherty threshold" doesn't appear in the 1982 IBM brochure it's named after, which argued for sub-second responses from productivity data. [Nielsen 1993] [Dubuc 2018] [Doherty 1982]
- **"Skeleton screens always feel faster."** The evidence is mixed. [Tankala 2023] [Viget 2017]
- **"Ask for every permission at first launch."** Android says not to, and from Android 11 two denials end the conversation. [Android Permission practices] [Android 11 Permissions]
- **"An inexact reminder is only a few minutes late."** It can be up to an hour on Android 12+, more under Doze. [Android Alarms]
- **"Deadlines make people finish."** In Bellotti's study a deadline didn't predict completion; someone waiting on the task did. [Bellotti 2004]
- **"Dark patterns are rare, and testing will catch them."** 95% of popular apps had one, and most users didn't notice. [Di Geronimo 2020]
- **"The EU already requires a cancel button."** Article 11a is a 14-day withdrawal function; the Digital Fairness Act isn't proposed yet. [EU 2023/2673] [EP DFA 2026]

## 19. Corrections to the reviewer's current citations

Read with `.claude/agents/frontend-ux-reviewer.md`, "What the research says".
- **Choice overload.** Scheibehenne et al. 2010 found a mean effect of about zero (50 experiments, N = 5,036). The moderators the reviewer describes come from Chernev, Böckenholt & Goodman 2015. (CO-4)
- **Thumb zone.** Cite Hoober 2017's accuracy data (≈ 7 mm centre, ≈ 12 mm corners; people prefer the centre), not thumb-sweep maps; Hoober asks readers to ignore his 2013 reach drawings. Bergstrom-Lehtovirta & Oulasvirta 2014 is a reach model, not a zone map. (RE-1, RE-2)
- **Older adults.** "Nielsen 2013" is *Usability for Senior Citizens: Improved, But Still Lacking*; NN/g has replaced it with Kane 2019. (OL-1)
- **Error messages.** Nielsen's 2001 article is no longer retrievable; cite Neusesser & Sunwall 2023. (UN-7)
- **Banner blindness.** Benway & Lane 1998 is now verified through the Internet Archive: 6 experienced users found links placed in banners about 58% of the time vs 94% for menu links. It's old desktop data, so cite Pernice 2018 for current evidence. [Benway 1998] (SC-8)
- **Speech correction.** Karat et al. 1999 is still second-hand: its abstract gives only the design (24 first-time and 4 extended users of three dictation products), and its correction figures appear only in other papers. Suhm, Myers & Waibel 2001 carries the verified numbers. (VO-6)
- **Snackbar timing.** Flutter's snackbar code shows no sign of reading Android's accessibility timeout (source check, not device-tested); TaskFlow bridges it in `App/lib/services/feedback_timeout.dart` (4 s base). Since Flutter 3.38 a snackbar with an action persists unless `persist: false`, and Material says such snackbars should stay until used or dismissed. (UN-5)
- **Apple targets.** The HIG now lists 44 × 44 pt as the default control size and 28 × 28 pt as the minimum. (§0)
- **Response times.** 0.1 / 1 / 10 s are Nielsen's rules of thumb built on Miller's 1968 essay; delays near 60 ms are already noticeable. (PE-1)
- **Fessenden 2018** is desktop data (1920 × 1080); don't apply its percentages to phones. (SC-5)
- **WCAG 2.2** is now the 12 Dec 2024 edition; 4.1.1 Parsing is obsolete, so never raise it.
- **Material navigation.** A navigation bar is for 3–5 destinations, and Material points to tabs below 3: relevant to U13. (PL-2)
- **Hick–Hyman.** "It grows faster for unfamiliar options" holds: novices search menus linearly, experts follow Hick–Hyman (Cockburn et al. 2007). (CO-2)
- **ISO 24495-1:2023.** Its four governing principles are relevant, findable, understandable and usable, confirmed in ISO's preview of the contents; the text itself is paywalled. [ISO 24495-1]

## 20. How to review a screen with this guide

This follows the reviewer's method (scope → context → map → look → walk → lenses → count → report) and adds the measurable checks.

**1. Frame it.**
- Name the screen, how the user got there (tab, button, notification, widget, shortcut, share), the state, and the persona: Newcomer first, then Daily user, then assistive-technology user.
- Write the screen's one job in ≤ 5 words (CO-1). If you can't, that's the first finding.

**2. Name your evidence.** A render counts only if it is newer than the code it shows. Otherwise reason from widget code and say so. A device check is a third, separate level (AC-13).

**3. Five-second look: where the eye goes.**
- Cover all but the top-left of the render: it alone should say which screen and which day this is (SC-3).
- Squint or blur the render (a convention, not a tested method) and list the first three things you notice. The primary action should be among them because of its label, position and isolation, not colour alone (SC-4).
- Count filled buttons and accent-coloured elements; more than one competing is a finding (SC-4).
- Banner-styled boxes get skipped (SC-8); icon-only controls are guesses for the Newcomer (SC-6).

**4. Reach on a 6.1–6.7-inch phone, one-handed.**
- Frame: such screens are about 64–71 mm wide and 141–155 mm tall (19.5:9 to 20:9). At nominal density 1 dp ≈ 0.16 mm, so 48 dp ≈ 7.6 mm; real phones vary by about ±20%.
- Split the render into thirds. Capture and other frequent actions sit low-centre, within the middle half to two-thirds; rare actions high or in a corner menu; destructive ones apart (RE-1, RE-6). On a 6.7" phone, any capture step in the top band is a finding (RE-5).
- Sizes: corner targets ≈ 12 mm (≈ 76 dp), centre targets ≥ 7 mm (≈ 44 dp), never below 48 dp; for the 60+ Newcomer aim for ≥ 10 mm (≈ 63 dp) on primary and frequent controls, with gaps between them (RE-2, RE-3).
- Mirror the layout for a left thumb (RE-4). Nothing to swipe from the side edges, and nothing to tap under the bottom gesture area (RE-7).
- Don't use thumb-zone heat-map overlays as proof (§18).

**5. Count.** Tap targets in view, decisions, steps to finish, and words at each decision point. Price each extra decision at ≈ 1.35 s and each extra point-and-tap at ≈ 1.1 s (practised users; newcomers are slower), and report before → after (CO-2, CO-10).

**6. Walk it as each persona.**
- At every step ask Wharton et al.'s four questions: will they try to do the right thing; will they notice the control; will they connect it with their goal; will they see that it worked?
- For a fast pass use Spencer's two: will they know what to do here, and after doing it, will they know they made progress?
- After anything is created or moved: "Where did it go, and can they see it?" (SC-10, SC-11).
- Newcomer extras: no gesture-only action (PL-8, OL-3), no unlabelled icon (SC-6), nothing to remember (CO-3), no fault implied (OL-2).

**7. Run the states.** First use or empty (ON-4); loading and slow AI past 1 s and 10 s (PE-2, VO-12); success (SC-11); partial; error (UN-7); nothing found (UN-8); offline (UN-10); permission denied or revoked (ON-7, VO-13); interrupted by a call, backgrounding or the app being killed (UN-9); many items; very long text; keyboard open (FO-8); 320 dp; 2× text; ES and CA; dark mode.

**8. At 2× text and 320 dp, check:**
- body text and titles separately, since Android 14 scales titles less (AC-3);
- truncation or ellipsis on buttons, chips, tabs and navigation labels — a cut verb is a broken button; Flutter's navigation labels stop growing at 1.3× (PL-2);
- words broken mid-word, and a day split from its date or time;
- fixed-height containers clipping text or overlapping their neighbours (AC-3);
- the primary button visible without scrolling in sheets and dialogs, or pinned (SC-5);
- the focused field, its error and the main button above the keyboard (FO-8);
- Catalan and Spanish, usually the longest strings; short labels grow most (LO-1);
- hit areas still ≥ 48 dp and labels still next to their controls (AC-14);
- no sideways scrolling for text at 320 dp (AC-4).

**9. Accessibility pass.** Name, role, value and reading order for every control (AC-6); announcements for results and saves (AC-7); contrast measured in light and dark (AC-1, AC-2); no meaning carried by colour alone (AC-5); reduced motion (AC-10); time limits (AC-11, UN-5); accessibility actions for gestures (AC-9); COGA objectives (AC-15).

**10. Voice and AI pass (capture screens).** States (VO-1); listening ends only on Done (VO-2); live words (VO-3); an example (VO-4); a date-first result (VO-5); fixes by touch (VO-6); several tasks (VO-7); confirmation scaled to cost (VO-8); failures (VO-11); the wait (VO-12); a silent mic (VO-13); typing always available (VO-16).

**11. Copy pass, in three languages.** Verb buttons that name the outcome (UN-4); front-loaded rows (SC-1); one name per concept (SC-9); errors with a next step and no blame (UN-7, OL-2); plurals, dates and times through the locale tools (LO-2 to LO-5); Catalan imperatives, l·l and one form of address (LO-7 to LO-9).

**12. Rate and report.** Rate severity by frequency, impact and persistence (Nielsen 1994s). In "Why it fails", cite the rule ID and its source; in "Evidence", say whether the finding rests on code, a current render or a device. Owner decisions go to "Questions for the owner".

## Sources

Keys are listed alphabetically. m3.material.io pages render only in a browser, so they were read through a text renderer. Flutter and intl source marked "read locally" was checked in the SDK and packages the app uses (Flutter 3.44.5, intl 0.20.2).

- [Alexa Progressive] Send the User a Progressive Response — Amazon Alexa Skills Kit docs — undated — https://developer.amazon.com/en-US/docs/alexa/custom-skills/send-the-user-a-progressive-response.html
- [Alexa Trustworthy] Be trustworthy (Alexa design principles) — Amazon — undated — https://developer.amazon.com/en-US/alexa/alexa-haus/design-principles/be-trustworthy
- [Android 11 Permissions] Permissions updates in Android 11 — Android Developers — updated 2026 — https://developer.android.com/about/versions/11/privacy/permissions
- [Android 12 changes] Behavior changes: apps targeting Android 12 — Android Developers — updated 2026 — https://developer.android.com/about/versions/12/behavior-changes-12
- [Android 14 Exact alarms] Schedule exact alarms are denied by default — Android Developers — updated 2026 — https://developer.android.com/about/versions/14/changes/schedule-exact-alarms
- [Android 14 features] Android 14 features and APIs — Android Developers — 2023 — https://developer.android.com/about/versions/14/features
- [Android 16 changes] Behavior changes: apps targeting Android 16 or higher — Android Developers — 2025 — https://developer.android.com/about/versions/16/behavior-changes-16
- [Android 2013 Confirming] Confirming & Acknowledging (Android Design patterns, archived) — Google — 2013 — https://webarchive.library.unt.edu/web/20130128030219mp_/http://developer.android.com/design/patterns/confirming-acknowledging.html
- [Android A11y apps] Make apps more accessible — Android Developers — updated 2026 — https://developer.android.com/guide/topics/ui/accessibility/apps
- [Android A11y principles] Principles for improving app accessibility — Android Developers — updated 2026 — https://developer.android.com/guide/topics/ui/accessibility/principles
- [Android A11y testing] Test your app's accessibility — Android Developers — updated 2026 — https://developer.android.com/guide/topics/ui/accessibility/testing
- [Android Alarms] Schedule alarms — Android Developers — updated 2026 — https://developer.android.com/develop/background-work/services/alarms/schedule
- [Android ANR] ANRs — Android Developers — updated 2026 — https://developer.android.com/topic/performance/vitals/anr
- [Android App languages] Per-app language preferences — Android Developers — updated 2026 — https://developer.android.com/guide/topics/resources/app-languages
- [Android Audio sharing] Sharing audio input — Android Developers — updated 2026 — https://developer.android.com/media/platform/sharing-audio-input
- [Android Build notification] Create a notification — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/notifications/build-notification
- [Android Channels] Create and manage notification channels — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/notifications/channels
- [Android dp] Support different pixel densities — Android Developers — updated 2026 — https://developer.android.com/training/multiscreen/screendensities
- [Android Gesture nav] Ensure compatibility with gesture navigation — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/touch-and-input/gestures/gesturenav
- [Android Launch time] App startup time — Android Developers — updated 2026 — https://developer.android.com/topic/performance/vitals/launch-time
- [Android Localization] Localize your app — Android Developers — updated 2026 — https://developer.android.com/guide/topics/resources/localization
- [Android Navigation principles] Principles of navigation — Android Developers — updated 2026 — https://developer.android.com/guide/navigation/principles
- [Android Notif design] Notifications (mobile design guidance) — Android Developers — updated 2026 — https://developer.android.com/design/ui/mobile/guides/home-screen/notifications
- [Android Notif group] Create a group of notifications — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/notifications/group
- [Android Notif permission] Notification runtime permission — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/notifications/notification-permission
- [Android Notifications] About notifications — Android Developers — updated 2026 — https://developer.android.com/develop/ui/compose/notifications
- [Android Offline-first] Build an offline-first app — Android Developers — current — https://developer.android.com/topic/architecture/data-layer/offline-first
- [Android Permission practices] App permissions best practices — Android Developers — updated 2026 — https://developer.android.com/training/permissions/usage-notes
- [Android Permissions] Request runtime permissions — Android Developers — updated 2026 — https://developer.android.com/training/permissions/requesting
- [Android Sensitive access] Explain access to more sensitive information — Android Developers — updated 2026 — https://developer.android.com/training/permissions/explaining-access
- [Android Shortcuts] Create shortcuts: best practices — Android Developers — updated 2026 — https://developer.android.com/develop/ui/views/launch/shortcuts/best-practices
- [Android Slow rendering] Slow rendering — Android Developers — updated 2026 — https://developer.android.com/topic/performance/vitals/render
- [Android Snackbar action] Add an action to a message — Android Developers — current — https://developer.android.com/develop/ui/views/notifications/snackbar/action
- [Android Standby] App Standby Buckets — Android Developers — updated 2026 — https://developer.android.com/topic/performance/appstandby
- [Android Timeout help] Change time to take action (Accessibility timeout) — Google Android Accessibility Help — undated — https://support.google.com/accessibility/android/answer/9426889
- [Android Touch targets] Touch target size — Google Android Accessibility Help — undated — https://support.google.com/accessibility/android/answer/7101858
- [Android Vitals] Android vitals; Crashes; ANRs — Android Developers — updated 2026 — https://developer.android.com/topic/performance/vitals (also /google/play/vitals/crash and /google/play/vitals/anr)
- [Android Wake locks 2026] Battery technical quality enforcement is here — Alice Yuan, Android Developers Blog — 2026 — https://android-developers.googleblog.com/2026/03/battery-technical-quality-enforcement.html
- [Android Widget quality] Widget quality guidelines — Android Developers — updated 2026 — https://developer.android.com/docs/quality-guidelines/widget-quality
- [AOSP RecognizerIntent] RecognizerIntent.java — Android Open Source Project — current — https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/main/core/java/android/speech/RecognizerIntent.java
- [Apple A11y] Accessibility — Apple Human Interface Guidelines — 2025 — https://developer.apple.com/design/human-interface-guidelines/accessibility
- [Apple Alerts] Alerts — Apple Human Interface Guidelines — 2024 — https://developer.apple.com/design/human-interface-guidelines/alerts
- [Apple App Intents] requestConfirmation(conditions:actionName:dialog:…) — Apple Developer Documentation — current — https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:showdialogasprompt:snippetintent:)-3vewj
- [Apple Onboarding] Onboarding — Apple Human Interface Guidelines — 2024 — https://developer.apple.com/design/human-interface-guidelines/onboarding
- [Apple Privacy] Privacy — Apple Human Interface Guidelines — 2023 — https://developer.apple.com/design/human-interface-guidelines/privacy
- [Batch 2025] The Great Push Notifications & Mobile Engagement Benchmark 2025 — Batch (vendor) — 2025 — https://batch.com/blog/case-studies/benchmark-notifications-push-crm-mobile
- [Baymard 2015f] The State of Mobile Checkout & Form Usability — Jamie Holst, Baymard Institute — 2015 — https://baymard.com/research-articles/mobile-ecommerce-checkout-forms
- [Baymard 2015k] 'Touch Keyboard' Implementations Have Improved Just 9% Since 2013 — Christian Holst, Baymard Institute — 2015 — https://baymard.com/blog/mobile-touch-keyboards
- [Baymard 2024] Usability Testing of Inline Form Validation: 31% Don't Have It, 4% Get It Wrong — Edward Scott, Baymard Institute — 2024 — https://baymard.com/blog/inline-form-validation
- [Bellotti 2004] What a to-do: studies of task management towards the design of a personal task list manager — Bellotti, Dalal, Good, Flynn, Bobrow & Ducheneaut, CHI — 2004 — https://hci.rwth-aachen.de/materials/conferences/CHI2004/1p735.pdf
- [Benway 1998] Banner blindness: Web searchers often miss "obvious" links — Jan Panero Benway & David M. Lane, Internetworking (ITG newsletter) 1.3 — 1998 — http://www.internettg.org/newsletter/dec98/banner_blindness.html (read via the Internet Archive: https://web.archive.org/web/20010223220039/http://www.internettg.org/newsletter/dec98/banner_blindness.html)
- [Bergstrom-Lehtovirta 2014] Modeling the functional area of the thumb on mobile touchscreen surfaces — Bergstrom-Lehtovirta & Oulasvirta, CHI, pp. 1991–2000 — 2014 — https://doi.org/10.1145/2556288.2557354 ‡
- [BOE TRLGDCU] Real Decreto Legislativo 1/2007 (consumer law; arts. 62, 97, 98) — BOE, consolidated 28 Feb 2026 — 2007 — https://www.boe.es/buscar/act.php?id=BOE-A-2007-20555
- [Brush 2001] Notification for shared annotation of digital documents — Brush, Bargeron, Gupta & Grudin, Microsoft Research MSR-TR-2001-87 — 2001 — https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-2001-87.pdf
- [Brush 2005] A survey of personal and household scheduling — Brush & Combs Turner, GROUP — 2005 — https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/pp17brush.pdf
- [Budiu 2014] The Reciprocity Principle: Give Before You Take in Web Design — Raluca Budiu, NN/g — 2014 — https://www.nngroup.com/articles/reciprocity-principle/
- [Budiu 2015] A Checklist for Designing Mobile Input Fields — Raluca Budiu, NN/g — 2015 — https://www.nngroup.com/articles/mobile-input-checklist/
- [Budiu 2017] Wizards: Definition and Design Recommendations — Raluca Budiu, NN/g — 2017 — https://www.nngroup.com/articles/wizards/
- [Budiu 2018cb] Change Blindness in UX: Definition — Raluca Budiu, NN/g — 2018 — https://www.nngroup.com/articles/change-blindness-definition/
- [Budiu 2018ia] Intelligent Assistants Have Poor Usability: A User Study of Alexa, Google Assistant, and Siri — Budiu & Laubheimer, NN/g — 2018 — https://www.nngroup.com/articles/intelligent-assistant-usability/
- [Budiu 2024] Memory Recognition and Recall in User Interfaces — Raluca Budiu, NN/g — page dated 2024 — https://www.nngroup.com/articles/recognition-and-recall/
- [Buehler 1994] Exploring the "planning fallacy": why people underestimate their task completion times — Buehler, Griffin & Ross, JPSP 67(3) — 1994 — https://bear.warrington.ufl.edu/brenner/mar7588/Papers/buehler-et-al-1994.pdf
- [Card 1980] The keystroke-level model for user performance time with interactive systems — Card, Moran & Newell, CACM 23(7):396–410 — 1980 — https://doi.org/10.1145/358886.358895 (paywalled; the operator times are known through secondary sources, and the 1979 Xerox PARC report SSL-79-1 isn't online) †
- [Carroll 1987] The paradox of the active user — Carroll & Rosson, in *Interfacing Thought* (ed. J. M. Carroll, MIT Press) — 1987 — https://www.nngroup.com/articles/paradox-of-the-active-user/ (NN/g's summary by Jakob Nielsen, 1998; the chapter itself wasn't reachable) †
- [Carroll 1987m] The Minimal Manual — Carroll, Smith-Kerker, Ford & Mazur-Rimetz, Human–Computer Interaction 3(2):123–153 — 1987 — https://doi.org/10.1207/s15327051hci0302_2 ‡
- [Catalan Code 22/2010] Llei 22/2010, Codi de consum de Catalunya (art. 128-1) — BOE, consolidated 2025 — 2010 — https://www.boe.es/buscar/act.php?id=BOE-A-2010-13115
- [Chernev 2015] Choice overload: a conceptual review and meta-analysis — Chernev, Böckenholt & Goodman, Journal of Consumer Psychology 25(2):333–358 (99 observations, N = 7,202) — 2015 — https://doi.org/10.1016/j.jcps.2014.08.002 ‡
- [CLDR Plurals] Language Plural Rules — Unicode CLDR — current — https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
- [Cochrane 2013] Mobile phone messaging reminders for attendance at healthcare appointments — Gurol-Urganci, de Jongh, Vodopivec-Jamsek, Atun & Car, Cochrane — 2013 — https://www.cochrane.org/evidence/CD007458_mobile-phone-messaging-reminders-attendance-healthcare-appointments
- [Cockburn 2007] A predictive model of menu performance — Cockburn, Gutwin & Greenberg, CHI, pp. 627–636 — 2007 — https://doi.org/10.1145/1240624.1240723 (read via https://grouplab.cpsc.ucalgary.ca/grouplab/uploads/Publications/Publications/2007-PredictiveModelMenus.CHI.pdf)
- [COGA 2021] Making Content Usable for People with Cognitive and Learning Disabilities — W3C COGA Task Force, Working Group Note — 2021 — https://www.w3.org/TR/coga-usable/
- [Cowan 2001] The magical number 4 in short-term memory: a reconsideration of mental storage capacity — Nelson Cowan, Behavioral and Brain Sciences 24(1):87–114 — 2001 — https://doi.org/10.1017/S0140525X01003922 (read via Cambridge's free copy: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/44023F1147D4A1D44BDC0AD226838496/S0140525X01003922a.pdf/div-class-title-the-magical-number-4-in-short-term-memory-a-reconsideration-of-mental-storage-capacity-div.pdf)
- [Cowan 2017] "What can I help you with?": infrequent users' experiences of intelligent personal assistants — Cowan et al., MobileHCI — 2017 — https://doi.org/10.1145/3098279.3098539
- [Darley 1968] Bystander intervention in emergencies: diffusion of responsibility — Darley & Latané, JPSP 8(4):377–383 — 1968 — https://doi.org/10.1037/h0025589 ‡
- [Di Geronimo 2020] UI Dark Patterns and Where to Find Them: A Study on Mobile Applications and User Perception — Di Geronimo, Braz, Fregnan, Palomba & Bacchelli, CHI, pp. 1–14 — 2020 — https://doi.org/10.1145/3313831.3376600 ‡
- [Doherty 1982] The Economic Value of Rapid Response Time — Doherty & Thadhani, IBM — 1982 — https://archive.computerhistory.org/resources/access/text/2024/03/102751398-05-01-acc.pdf (Computer History Museum scan, read through its OCR text; the IBM form number GE20-0752 and the 1982 date come only from search snippets)
- [Dourish 1992] Awareness and coordination in shared workspaces — Dourish & Bellotti, CSCW — 1992 — https://www.dourish.com/publications/1992/cscw92-awareness.pdf
- [Dubuc 2018] Magic numbers — Gilles Dubuc, Web Performance Calendar — 2018 — https://calendar.perfplanet.com/2018/magic-numbers/
- [Eardley 2017] Understanding Grip Shifts: How Form Factors Impact Hand Movements on Mobile Phones — Eardley, Roudaut, Gill & Thompson, CHI, pp. 4680–4691 — 2017 — https://doi.org/10.1145/3025453.3025835 ‡
- [EC Dark patterns 2022] Behavioural study on unfair commercial practices in the digital environment: dark patterns and manipulative personalisation — Lupiáñez-Villanueva et al., European Commission (mystery shopping of 75 sites and apps; experiment with 7,430 people) — 2022 — https://op.europa.eu/en/publication-detail/-/publication/606365bc-d58b-11ec-a95f-01aa75ed71a1/language-en
- [EC Fitness 2024] Fitness Check of EU consumer law on digital fairness, SWD(2024) 230 — European Commission — 2024 — https://commission.europa.eu/document/download/707d7404-78e5-4aef-acfa-82b4cf639f55_en
- [EC Sweep 2023] Manipulative online practices found on 148 out of 399 online shops screened — European Commission — 2023 — https://cyprus.representation.ec.europa.eu/news/consumer-protection-manipulative-online-practices-found-148-out-399-online-shops-screened-2023-01-30_en
- [EDPB 03/2022] Guidelines 03/2022 on deceptive design patterns in social media platform interfaces, v2.0 — EDPB — 2023 — https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-032022-deceptive-design-patterns-social-media_en
- [EDPB VVA 2021] Guidelines 02/2021 on virtual voice assistants, v2.0 — EDPB — 2021 — https://www.edpb.europa.eu/system/files/2021-07/edpb_guidelines_202102_on_vva_v2.0_adopted_en.pdf
- [EP DFA 2026] Legislative Train: Digital Fairness Act — European Parliament — 2026 — https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act
- [EU 2023/2673] Directive (EU) 2023/2673 (new art. 11a of the Consumer Rights Directive) — EU — 2023 — https://eur-lex.europa.eu/eli/dir/2023/2673/oj/eng
- [EU 2023/2673 NIM] National transposition measures for Directive (EU) 2023/2673 (none listed for Spain) — EUR-Lex — checked 18 Oct 2026 — https://eur-lex.europa.eu/legal-content/EN/NIM/?uri=CELEX:32023L2673
- [Eurostat 2025] Individuals' internet use (isoc_ci_ifp_iu, isoc_ci_dev_i) — Eurostat — 2025 — https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/isoc_ci_ifp_iu
- [Fessenden 2018] Scrolling and Attention — Therese Fessenden, NN/g — 2018 — https://www.nngroup.com/articles/scrolling-and-attention/
- [Findlater 2013] Age-related differences in performance with touchscreens compared to traditional mouse input — Findlater, Froehlich, Fattal, Wobbrock & Dastyar, CHI — 2013 — https://doi.org/10.1145/2470654.2470703
- [Flaherty 2024] Indicators, Validations, and Notifications: Pick the Correct Communication Option — Kim Flaherty, NN/g — page dated 2024 — https://www.nngroup.com/articles/indicators-validations-notifications/
- [Flutter a11y src] accessibility.dart (flutter_test accessibility guidelines) — Flutter — current — https://github.com/flutter/flutter/blob/master/packages/flutter_test/lib/src/accessibility.dart
- [Flutter a11y testing] Accessibility testing — Flutter docs — 2026 — https://docs.flutter.dev/ui/accessibility/accessibility-testing
- [Flutter AnimationBehavior] AnimationBehavior — Flutter API — current — https://api.flutter.dev/flutter/animation/AnimationBehavior.html
- [Flutter CustomSemanticsAction] CustomSemanticsAction — Flutter API — current — https://api.flutter.dev/flutter/semantics/CustomSemanticsAction-class.html
- [Flutter disableAnimations] MediaQueryData.disableAnimations — Flutter API — current — https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- [Flutter FAB] FloatingActionButton — Flutter API — current — https://api.flutter.dev/flutter/material/FloatingActionButton-class.html
- [Flutter i18n] Internationalizing Flutter apps — Flutter docs — 2026 — https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- [Flutter MaterialLocalizations src] material_localizations.dart (firstDayOfWeekIndex) — Flutter, read locally — 2026 — https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/material_localizations.dart
- [Flutter MaterialTapTargetSize] MaterialTapTargetSize — Flutter API — current — https://api.flutter.dev/flutter/material/MaterialTapTargetSize.html
- [Flutter MediaQuery src] media_query.dart and time.dart (alwaysUse24HourFormat) — Flutter, read locally — 2026 — https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/widgets/media_query.dart
- [Flutter NavigationBar src] navigation_bar.dart — Flutter — current — https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/navigation_bar.dart
- [Flutter nonlinear] Android 14 nonlinear font scaling enabled — Flutter docs — current — https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration
- [Flutter PopScope] Android predictive back — Flutter docs — current — https://docs.flutter.dev/release/breaking-changes/android-predictive-back
- [Flutter showModalBottomSheet] showModalBottomSheet — Flutter API — current — https://api.flutter.dev/flutter/material/showModalBottomSheet.html
- [Flutter showTimePicker] showTimePicker and showDatePicker — Flutter API — current — https://api.flutter.dev/flutter/material/showTimePicker.html
- [Flutter SnackBar persist] SnackBar with action no longer auto-dismisses — Flutter docs — 2026 — https://docs.flutter.dev/release/breaking-changes/snackbar-with-action-behavior-update
- [Flutter SnackBar src] snack_bar.dart — Flutter — current — https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/snack_bar.dart
- [Foley 2020] Comparing Smartphone Speech Recognition and Touchscreen Typing for Composition and Transcription — Foley, Casiez & Vogel, CHI — 2020 — https://doi.org/10.1145/3313831.3376861 (abstract read; the figures come from the first author's thesis, which extends the paper: https://uwspace.uwaterloo.ca/handle/10012/16184) ‡
- [Forch 2017] Are 100 ms Fast Enough? Characterizing Latency Perception Thresholds in Mouse-Based Interaction — Forch, Franke, Rauh & Krems, EPCE (LNCS 10276), pp. 45–56 — 2017 — https://doi.org/10.1007/978-3-319-58475-1_4 (abstract: https://research.uni-luebeck.de/en/publications/are-100-ms-fast-enough-characterizing-latency-perception-threshol/) ‡
- [Franz 2019] Just Ask Me: Comparing Older and Younger Individuals' Knowledge of Their Optimal Touchscreen Target Sizes — Franz, Findlater & Wobbrock, ASSETS poster — 2019 — https://faculty.washington.edu/wobbrock/pubs/assets-19.06.pdf
- [Gajos 2008] Improving the performance of motor-impaired users with automatically-generated, ability-based interfaces — Gajos, Wobbrock & Weld, CHI, pp. 1257–1266 — 2008 — https://doi.org/10.1145/1357054.1357250 (read via https://faculty.washington.edu/wobbrock/pubs/chi-08.02.pdf)
- [Gangadharaiah 2019] Joint Multiple Intent Detection and Slot Labeling for Goal-Oriented Dialog — Gangadharaiah & Narayanaswamy, NAACL — 2019 — https://doi.org/10.18653/v1/N19-1055
- [GDPR] Regulation (EU) 2016/679 (arts. 7, 12, 13, 25) — EU — 2016 — https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng
- [Goetsu 2020] Different Types of Voice User Interface Failures May Cause Different Degrees of Frustration — Goetsu & Sakai, arXiv preprint (v1, 10 Feb 2020; not peer-reviewed) — 2020 — https://arxiv.org/abs/2002.03582
- [Gollwitzer 1999] Implementation intentions: strong effects of simple plans — Peter Gollwitzer, American Psychologist 54(7) — 1999 — https://www.socmot.uni-konstanz.de/sites/default/files/99_Gollwitzer_Implementation_Intentions.pdf
- [Gollwitzer 2006] Implementation intentions and goal achievement: a meta-analysis of effects and processes — Gollwitzer & Sheeran, Advances in Experimental Social Psychology 38:69–119 — 2006 — https://doi.org/10.1016/S0065-2601(06)38002-1 (read via the Konstanz repository copy: https://kops.uni-konstanz.de/bitstreams/d4f710b4-a505-49ef-a831-5b8d7675100b/download)
- [Google Confirmations] Confirmations (conversation design, archived; platform retired 2023) — Google — page updated 2024 — https://developers.google.com/assistant/conversation-design/confirmations
- [Google Errors] Errors (conversation design, archived) — Google — current — https://developers.google.com/assistant/conversation-design/errors
- [Google Scale] Scale your design (conversation design, archived) — Google — current — https://developers.google.com/assistant/conversation-design/scale-your-design
- [Graus 2016] Analyzing and predicting task reminders — Graus, Bennett, White & Horvitz, UMAP — 2016 — https://www.erichorvitz.com/Cortana-reminders_UM_2016.pdf
- [Gray 2018] The Dark (Patterns) Side of UX Design — Gray, Kou, Battles, Hoggatt & Toombs, CHI, Paper 534 — 2018 — https://doi.org/10.1145/3173574.3174108 (abstract read; the five strategies and the 118-artifact corpus are known only through deceptive.design, as the full text was blocked) †
- [Harada 2013] Characteristics of Elderly User Behavior on Mobile Multi-touch Devices — Harada, Sato, Takagi & Asakawa, INTERACT — 2013 — https://doi.org/10.1007/978-3-642-40498-6_25
- [Haraty 2012] Individual differences in personal task management — Haraty, Tam, Haddad, McGrenere & Tang, Graphics Interface — 2012 — https://www.cs.ubc.ca/~joanna/papers/GI2012_Haraty.pdf
- [Haraty 2016] How personal task management differs across individuals — Haraty, McGrenere & Tang, IJHCS 88 — 2016 — https://doi.org/10.1016/j.ijhcs.2015.11.006
- [Harley 2014] Icon Usability — Aurora Harley, NN/g — 2014 — https://www.nngroup.com/articles/icon-usability/
- [Harley 2014c] Instructional Overlays and Coach Marks for Mobile Apps — Aurora Harley, NN/g — 2014 — https://www.nngroup.com/articles/mobile-instructional-overlay/
- [Harley 2018] Visibility of System Status (Usability Heuristic #1) — Aurora Harley, NN/g — 2018 — https://www.nngroup.com/articles/visibility-system-status/
- [Harley 2019] Touch Targets on Touchscreens — Aurora Harley, NN/g — 2019 — https://www.nngroup.com/articles/touch-target-size/
- [Harrison 2007] Rethinking the Progress Bar — Harrison, Amento, Kuznetsov & Bell, UIST — 2007 — https://www.chrisharrison.net/projects/progressbars/ProgBarHarrison.pdf
- [Hick 1952] On the rate of gain of information — W. E. Hick, Quarterly Journal of Experimental Psychology 4(1):11–26 — 1952 — https://doi.org/10.1080/17470215208416600 ‡
- [Hoober 2013] How Do Users Really Hold Mobile Devices? — Steven Hoober, UXmatters — 2013 — https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
- [Hoober 2017a] Design for Fingers, Touch, and People, Part 1 — Steven Hoober, UXmatters — 2017 — https://www.uxmatters.com/mt/archives/2017/03/design-for-fingers-touch-and-people-part-1.php
- [Hoober 2017c] Design for Fingers, Touch, and People, Part 3 — Steven Hoober, UXmatters — 2017 — https://www.uxmatters.com/mt/archives/2017/07/design-for-fingers-touch-and-people-part-3.php
- [Hyman 1953] Stimulus information as a determinant of reaction time — Ray Hyman, Journal of Experimental Psychology 45(3):188–196 — 1953 — https://doi.org/10.1037/h0056940 ‡
- [ICU Messages] Formatting Messages — ICU User Guide, Unicode — current — https://unicode-org.github.io/icu/userguide/format_parse/messages/
- [IEC 2017] Ortografia catalana — Institut d'Estudis Catalans — 2017 — https://www.iec.cat/llengua/documents/ortografia_catalana_versio_digital.pdf
- [intl CLDR data] intl 0.20.2 date symbols and patterns (es, ca, en), derived from CLDR — Dart team, read locally — 2025 — https://pub.dev/packages/intl
- [Iqbal 2008] Effects of intelligent notification management on users and their tasks — Iqbal & Bailey, CHI — 2008 — https://www.interruptions.net/literature/Iqbal-CHI08.pdf
- [ISO 24495-1] Plain language — Part 1: Governing principles and guidelines (ISO 24495-1:2023; contents read in ISO's preview, text paywalled) — ISO/TC 37 — 2023 — https://www.iso.org/standard/78907.html
- [Jamieson 2014] The efficacy of cognitive prosthetic technology for people with memory impairments — Jamieson, Cullen, McGee-Lennon, Brewster & Evans, Neuropsychological Rehabilitation 24(3–4):419–444 — 2014 — https://doi.org/10.1080/09602011.2013.825632 (abstract: https://strathprints.strath.ac.uk/53584/) ‡
- [Jin 2007] Touch Screen User Interfaces for Older Adults: Button Size and Spacing — Jin, Plocher & Kiff, UAHCI (LNCS 4554) — 2007 — https://doi.org/10.1007/978-3-540-73279-2_104
- [Johnson 2003] Do Defaults Save Lives? — Johnson & Goldstein, Science 302(5649):1338–1339 — 2003 — https://doi.org/10.1126/science.1091721 (read via the author's copy: http://www.dangoldstein.com/papers/DefaultsScience.pdf)
- [Kahneman 1993] When more pain is preferred to less: adding a better end — Kahneman, Fredrickson, Schreiber & Redelmeier, Psychological Science 4(6):401–405 — 1993 — https://doi.org/10.1111/j.1467-9280.1993.tb00589.x ‡
- [Kane 2019] Usability for Older Adults: Challenges and Changes — Lexie Kane, NN/g — 2019 — https://www.nngroup.com/articles/usability-for-senior-citizens/
- [Kaplan 2021] Designing Empty States in Complex Applications: 3 Guidelines — Kate Kaplan, NN/g — 2021 — https://www.nngroup.com/articles/empty-state-interface-design/
- [Karat 1999] Patterns of entry and correction in large vocabulary continuous speech recognition systems — Karat, Halverson, Horn & Karat, CHI, pp. 568–575 — 1999 — https://doi.org/10.1145/302979.303160 (abstract read; its findings are known only through Suhm 2001, Shneiderman 2000 and Ruan 2017) †
- [Kendrick 2018] Five Mistakes in Designing Mobile Push Notifications — Alita Kendrick, NN/g — 2018 — https://www.nngroup.com/articles/push-notification/
- [Kendrick 2020o] Mobile-App Onboarding: An Analysis of Components and Techniques — Alita Kendrick, NN/g — 2020 — https://www.nngroup.com/articles/mobile-app-onboarding/
- [Kendrick 2020t] Mobile Tutorials: Wasted Effort or Efficiency Boost? — Alita Kendrick, NN/g — 2020 — https://www.nngroup.com/articles/mobile-tutorials/
- [Kessler 2025] Increasing Organ Donor Registration as a Means to Increase Transplantation: An Experiment with Actual Organ Donor Registrations — Kessler & Roth, American Economic Journal: Economic Policy 17(2):60–83 — 2025 — https://doi.org/10.1257/pol.20220760 (read via https://users.nber.org/~kesslerj/papers/KesslerRoth_2025.pdf)
- [Kim 2021] Exploring How Older Adults Use a Smart Speaker–Based Voice Assistant in Their First Interactions — Sunyoung Kim, JMIR mHealth and uHealth 9(1) — 2021 — https://doi.org/10.2196/20427
- [Kobayashi 2011] Elderly User Evaluation of Mobile Touchscreen Interactions — Kobayashi, Hiyama, Miura, Asakawa, Hirose & Ifukube, INTERACT (LNCS 6946) — 2011 — https://doi.org/10.1007/978-3-642-23774-4_9
- [Krause 2019] 10 Design Guidelines for Reporting Errors in Forms — Rachel Krause, NN/g — 2019 — https://www.nngroup.com/articles/errors-forms-design-guidelines/
- [Kurosu 1995] Apparent usability vs. inherent usability: experimental analysis on the determinants of the apparent usability — Kurosu & Kashimura, CHI '95 Conference Companion, pp. 292–293 — 1995 — https://doi.org/10.1145/223355.223680 (read via https://chi1995.acm.org/proceedings/shortppr/mk_bdy.htm)
- [Kushlev 2016] "Silence your phones": smartphone notifications increase inattention and hyperactivity symptoms — Kushlev, Proulx & Dunn, CHI — 2016 — https://www.interruptions.net/literature/Kushlev-CHI16.pdf
- [Laubheimer 2015] Preventing User Errors: Avoiding Unconscious Slips — Page Laubheimer, NN/g — 2015 — https://www.nngroup.com/articles/slips/
- [Laubheimer 2018a] Intelligent Assistants: Creepy, Childish, or a Tool? Users' Attitudes Toward Alexa, Google Assistant, and Siri — Laubheimer & Budiu, NN/g — 2018 — https://www.nngroup.com/articles/voice-assistant-attitudes/
- [Laubheimer 2019] The 3-Click Rule for Navigation Is False — Page Laubheimer, NN/g — 2019 — https://www.nngroup.com/articles/3-click-rule/
- [Laubheimer 2023] Onboarding Tutorials vs. Contextual Help — Page Laubheimer, NN/g — page dated 2023 — https://www.nngroup.com/articles/onboarding-tutorials/
- [Leiva 2020] Understanding Visual Saliency in Mobile User Interfaces — Leiva, Xue, Bansal, Tavakoli, Köroğlu, Du, Dayama & Oulasvirta, MobileHCI, pp. 1–12 — 2020 — https://doi.org/10.1145/3379503.3403557 (read via arXiv: https://arxiv.org/abs/2101.09176)
- [Leung 2011] Age-related differences in the initial usability of mobile device icons — Leung, McGrenere & Graf, Behaviour & Information Technology 30(5):629–642 — 2011 — https://doi.org/10.1080/01449290903171308 (read via the lab's copy: https://www.cs.ubc.ca/labs/edapt/papers/leung2011.pdf)
- [Leung 2012] How Older Adults Learn to Use Mobile Devices: Survey and Field Investigations — Leung, Tang, Haddad, McGrenere, Graf & Ingriany, ACM TACCESS 4(3) — 2012 — https://doi.org/10.1145/2399193.2399195
- [Li 2017d] Date-Input Form Fields: UX Design Guidelines — Angie Li, NN/g — 2017 — https://www.nngroup.com/articles/date-input/
- [Li 2017s] Using Swipe to Trigger Contextual Actions — Angie Li, NN/g — 2017 — https://www.nngroup.com/articles/contextual-swipe/
- [Luger 2016] "Like Having a Really Bad PA": The Gulf between User Expectation and Experience of Conversational Agents — Luger & Sellen, CHI — 2016 — https://doi.org/10.1145/2858036.2858288
- [M1 Empty states] Empty states (patterns) — Material Design v1, legacy — undated — https://m1.material.io/patterns/empty-states.html
- [M2 Confirmation] Confirmation & acknowledgement — Material Design 2 — undated — https://m2.material.io/design/communication/confirmation-acknowledgement.html (the live page no longer shows its content; read via the Internet Archive capture of 18 Nov 2019: https://web.archive.org/web/20191118144210/https://material.io/design/communication/confirmation-acknowledgement.html)
- [M3 Bottom sheets] Bottom sheets: guidelines and accessibility — Material Design 3 — current — https://m3.material.io/components/bottom-sheets/guidelines
- [M3 Buttons] Button (Material Web docs for Material 3) — Google — current — https://github.com/material-components/material-web/blob/main/docs/components/button.md (and the guidelines page, read in a browser: https://m3.material.io/components/buttons/guidelines)
- [M3 Color roles] Color roles — Material Design 3 — current — https://m3.material.io/styles/color/roles
- [M3 Dialogs] Dialogs: guidelines and accessibility — Material Design 3 — current — https://m3.material.io/components/dialogs/guidelines
- [M3 FAB] Floating action button: guidelines and accessibility — Material Design 3 — current — https://m3.material.io/components/floating-action-button/guidelines
- [M3 Navigation bar] Navigation bar: guidelines — Material Design 3 — current — https://m3.material.io/components/navigation-bar/guidelines
- [M3 Snackbar] Snackbar: guidelines and accessibility — Material Design 3 — current — https://m3.material.io/components/snackbar/guidelines
- [M3 Structure] Accessibility designing: structure (touch targets ≥ 48 × 48 dp, 8 dp apart) — Material Design 3 — current — https://m3.material.io/foundations/designing/structure
- [M3 Transitions] Applying transitions — Material Design 3 — current — https://m3.material.io/styles/motion/transitions/applying-transitions
- [Malkin 2019] Privacy Attitudes of Smart Speaker Users — Malkin et al., PoPETs 2019(4) — 2019 — https://doi.org/10.2478/popets-2019-0068
- [Markey 2000] Bystander intervention in computer-mediated communication — P. M. Markey, Computers in Human Behavior 16(2):183–188 — 2000 — https://doi.org/10.1016/S0747-5632(99)00056-4 (paywalled; known through secondary sources and a search snippet of the abstract) †
- [Mathur 2019] Dark Patterns at Scale: Findings from a Crawl of 11K Shopping Websites — Mathur et al., PACM HCI (CSCW) — 2019 — https://arxiv.org/abs/1907.07032
- [MDC Snackbar] Snackbar (Material Components for Android docs) — Google — current — https://github.com/material-components/material-components-android/blob/master/docs/components/Snackbar.md
- [Microsoft Speech] Speech interactions (Windows app design) — Microsoft Learn — 2017 — https://learn.microsoft.com/en-us/windows/apps/design/input/speech-interactions
- [Moran 2016] Reading Content on Mobile Devices — Kate Moran, NN/g — 2016 — https://www.nngroup.com/articles/mobile-content/
- [Mozilla es] Spanish style guides (es and es-ES) — Mozilla l10n — current — https://github.com/mozilla-l10n/styleguides
- [Myers 2018] Patterns for How Users Overcome Obstacles in Voice User Interfaces — Myers, Furqan, Nebolsky, Caro & Zhu, CHI, pp. 1–7 — 2018 — https://doi.org/10.1145/3173574.3173580 ‡
- [Myers 2021] "Try, Try, Try Again": Sequence Analysis of User Interaction Data with a Voice User Interface — Myers, Laris Pardo, Acosta-Ruiz, Canossa & Zhu, CUI, pp. 1–8 — 2021 — https://doi.org/10.1145/3469595.3469613 ‡
- [NEI 2025] Color Blindness — National Eye Institute (NIH) — 2025 — https://www.nei.nih.gov/learn-about-eye-health/eye-conditions-and-diseases/color-blindness
- [Neusesser 2023] Error-Message Guidelines — Neusesser & Sunwall, NN/g — 2023 — https://www.nngroup.com/articles/error-message-guidelines/
- [Neustaedter 2006] "The calendar is crucial": coordination and awareness through the family calendar — Neustaedter, Brush & Greenberg, MSR-TR-2006-107 (later ACM TOCHI 2009) — 2006 — https://www.microsoft.com/en-us/research/wp-content/uploads/2006/07/tr-2006-107.pdf
- [Neustaedter 2006b] "LINC-ing" the family: the participatory design of an inkable family calendar — Neustaedter & Brush, CHI, pp. 141–150 — 2006 — https://doi.org/10.1145/1124772.1124796 (read via https://www.microsoft.com/en-us/research/wp-content/uploads/2006/04/lincchi2006.pdf)
- [Nielsen 1993] Response Times: The 3 Important Limits — Jakob Nielsen, NN/g (from *Usability Engineering*) — 1993, updated 2014 — https://www.nngroup.com/articles/response-times-3-important-limits/
- [Nielsen 1994h] 10 Usability Heuristics for User Interface Design — Jakob Nielsen, NN/g — 1994, wording updated 2020 — https://www.nngroup.com/articles/ten-usability-heuristics/
- [Nielsen 1994s] Severity Ratings for Usability Problems — Jakob Nielsen, NN/g — 1994 — https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/
- [Nielsen 1997] How Users Read on the Web — Jakob Nielsen, NN/g — 1997 — https://www.nngroup.com/articles/how-users-read-on-the-web/
- [Nielsen 2000] End of Web Design (origin of Jakob's law) — Jakob Nielsen, NN/g — 2000 — https://www.nngroup.com/articles/end-of-web-design/
- [Nielsen 2005] The Power of Defaults — Jakob Nielsen, NN/g — 2005 — https://www.nngroup.com/articles/the-power-of-defaults/
- [Nielsen 2006] Progressive Disclosure — Jakob Nielsen, NN/g — 2006 — https://www.nngroup.com/articles/progressive-disclosure/
- [Nielsen 2006f] F-Shaped Pattern For Reading Web Content (original study) — Jakob Nielsen, NN/g — 2006 — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content-discovered/
- [Nielsen 2010] Website Response Times — Jakob Nielsen, NN/g — 2010 — https://www.nngroup.com/articles/website-response-times/
- [Nielsen 2013] Usability for Senior Citizens: Improved, But Still Lacking — Jakob Nielsen, NN/g — 2013 — https://www.nngroup.com/articles/usability-seniors-improvements/
- [Nielsen 2017j] Jakob's Law of Internet User Experience (video) — Jakob Nielsen, NN/g — 2017 — https://www.nngroup.com/videos/jakobs-law-internet-ux/
- [Nielsen 2018c] Confirmation Dialogs Can Prevent User Errors — If Not Overused — Jakob Nielsen, NN/g — 2018 — https://www.nngroup.com/articles/confirmation-dialog/
- [Nielsen 2022] Best Font for Online Reading: No Single Answer (summarising Wallace 2022; the 11% estimate is NN/g's own) — Jakob Nielsen, NN/g — 2022 — https://www.nngroup.com/articles/best-font-for-online-reading/
- [Norman 2010] Gestural interfaces: a step backwards in usability — Norman & Nielsen, ACM Interactions 17(5):46–49 — 2010 — https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/ (DOI: https://doi.org/10.1145/1836216.1836228)
- [Nuance Confirm] Requesting confirmation — Nuance Mix best practices (vendor) — undated — https://docs.nuance.com/mix/best-practices/dialog-planning/confirm/
- [Okoshi 2017] Attention and engagement-awareness in the wild — Okoshi, Tsubouchi, Taji, Ichikawa & Tokuda, IEEE PerCom, pp. 100–110 — 2017 — https://doi.org/10.1109/PERCOM.2017.7917856 ‡
- [Pan 2018] Panoptispy: Characterizing Audio and Video Exfiltration from Android Applications — Pan et al., PoPETs 2018(4) — 2018 — https://doi.org/10.1515/popets-2018-0030
- [Pang 2021] Technology Adoption and Learning Preferences for Older Adults: Evolving Perceptions, Ongoing Challenges, and Emerging Design Opportunities — Pang, Wang, McGrenere, Leung, Dai & Moffatt, CHI — 2021 — https://doi.org/10.1145/3411764.3445702 (read via the lab's copy: https://www.cs.ubc.ca/labs/edapt/papers/pang2021.pdf)
- [Parhi 2006] Target size study for one-handed thumb use on small touchscreen devices — Parhi, Karlson & Bederson, MobileHCI, pp. 203–210 — 2006 — https://doi.org/10.1145/1152215.1152260 (read via the HCIL tech report: https://www.cs.umd.edu/hcil/trs/2006-11/2006-11.pdf)
- [Payne 1993] Understanding calendar use — S. J. Payne, Human–Computer Interaction 8(2):83–100 — 1993 — https://doi.org/10.1207/s15327051hci0802_1 (abstract; its sample size is known only through Tungare 2008) ‡
- [Pernice 2016a] Hamburger Menus and Hidden Navigation Hurt UX Metrics — Pernice & Budiu, NN/g — 2016 — https://www.nngroup.com/articles/hamburger-menus/
- [Pernice 2016b] How to Make Navigation (Even a Hamburger) Discoverable on Mobile — Pernice & Budiu, NN/g — 2016 — https://www.nngroup.com/articles/find-navigation-mobile-even-hamburger/
- [Pernice 2017] F-Shaped Pattern of Reading on the Web: Misunderstood, But Still Relevant (Even on Mobile) — Kara Pernice, NN/g — 2017 — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/
- [Pernice 2018] Banner Blindness Revisited: Users Dodge Ads on Mobile and Desktop — Kara Pernice, NN/g — 2018 — https://www.nngroup.com/articles/banner-blindness-old-and-new-findings/
- [Pew 2014] Older Adults and Technology Use — Aaron Smith, Pew Research Center — 2014 — https://www.pewresearch.org/internet/2014/04/03/older-adults-and-technology-use/
- [Pew 2025] Mobile Fact Sheet — Pew Research Center — 2025 — https://www.pewresearch.org/internet/fact-sheet/mobile/
- [Pielot 2014] An in-situ study of mobile phone notifications — Pielot, Church & de Oliveira, MobileHCI — 2014 — https://ic.unicamp.br/~oliveira/doc/MHCI2014_An-in-situ-study-of-mobile-phone-notifications.pdf
- [Pielot 2017] Productive, anxious, lonely: 24 hours without push notifications — Pielot & Rello, MobileHCI — 2017 — https://arxiv.org/abs/1612.02314
- [Pielot 2018] Dismissed! A detailed exploration of how mobile phone users handle push notifications — Pielot, Vradi & Park, MobileHCI — 2018 — https://www.interruptions.net/literature/Pielot-MobileHCI18.pdf
- [Piepenbrock 2013] Positive display polarity is advantageous for both younger and older adults — Piepenbrock, Mayr, Mund & Buchner, Ergonomics 56(7):1116–1124 — 2013 — https://doi.org/10.1080/00140139.2013.790485 ‡
- [Play Billing subscriptions] About subscriptions (Google Play Billing) — Android Developers — 2026 — https://developer.android.com/google/play/billing/subscriptions
- [Play Disclosure practices] Best practices for prominent disclosure and consent — Google Play Console Help — undated — https://support.google.com/googleplay/android-developer/answer/11150561
- [Play Merchant of Record] Merchant of Record (Google is merchant of record in Spain and the rest of the EEA) — Google Play Console Help — current — https://support.google.com/googleplay/android-developer/answer/7645364 (applied by the Developer Distribution Agreement §3.4, effective 15 Sep 2025: https://play.google/developer-distribution-agreement.html)
- [Play Payments] Payments policy — Google Play Developer Policy Center — undated — https://support.google.com/googleplay/android-developer/answer/9858738
- [Play Permissions] Permissions and APIs that Access Sensitive Information — Google Play Console Help — undated — https://support.google.com/googleplay/android-developer/answer/9888170
- [Play Subscriptions] Subscriptions policy — Google Play Developer Policy Center — undated — https://support.google.com/googleplay/android-developer/answer/9900533
- [Play Target API] Target API level requirements for Google Play apps — Google Play Console Help — undated — https://support.google.com/googleplay/android-developer/answer/11926878
- [Play ToS 2025] Google Play Terms of Service (EEA version, read in Spanish, dated 5 Nov 2025: Google Commerce Limited provides Play content and is the contracting party) — Google — 2025 — https://play.google.com/about/play-terms/index.html
- [Play User Data] User Data policy — Google Play Developer Policy Center — undated — https://support.google.com/googleplay/android-developer/answer/10144311
- [Play Vitals help] Monitor your app's technical quality with Android vitals — Google Play Console Help — undated — https://support.google.com/googleplay/android-developer/answer/7385505
- [Pradhan 2020] Use of Intelligent Voice Assistants by Older Adults with Low Technology Use — Pradhan, Lazar & Findlater, ACM TOCHI 27(4):1–27 — 2020 — https://doi.org/10.1145/3373759 ‡
- [Raskin 2000] The Humane Interface — Jef Raskin, Addison-Wesley — 2000 — book with no open copy; known through summaries †
- [Rensink 1997] To See or Not to See: The Need for Attention to Perceive Changes in Scenes — Rensink, O'Regan & Clark, Psychological Science 8(5):368–373 — 1997 — https://doi.org/10.1111/j.1467-9280.1997.tb00427.x ‡
- [RevenueCat 2026] State of Subscription Apps 2026 — RevenueCat (vendor) — 2026 — https://www.revenuecat.com/state-of-subscription-apps/
- [RevenueCat Paywalls] Hard paywall vs soft paywall — Peter Meinertzhagen, RevenueCat (vendor) — 2023 — https://www.revenuecat.com/blog/growth/hard-paywall-vs-soft-paywall/
- [Robotham 2016] Using digital notifications to improve attendance in clinic: systematic review and meta-analysis — Robotham, Satkunanathan, Reynolds, Stahl & Wykes, BMJ Open 6(10):e012116 — 2016 — https://doi.org/10.1136/bmjopen-2016-012116 (full text via Europe PMC: https://europepmc.org/article/MED/27798006)
- [Rosala 2019] 3 Design Considerations for Effective Mobile-App Permission Requests — Maria Rosala, NN/g — 2019 — https://www.nngroup.com/articles/permission-requests/
- [Rosala 2020] User Control and Freedom (Usability Heuristic #3) — Maria Rosala, NN/g — 2020 — https://www.nngroup.com/articles/user-control-and-freedom/
- [Rosala 2023] Deceptive Patterns in UX — Maria Rosala, NN/g — 2023 — https://www.nngroup.com/articles/deceptive-patterns/
- [Ruan 2017] Comparing Speech and Keyboard Text Entry for Short Messages in Two Languages on Touchscreen Phones — Ruan, Wobbrock, Liou, Ng & Landay, PACM IMWUT 1(4) — 2017 — https://doi.org/10.1145/3161187
- [Schaub 2015] A Design Space for Effective Privacy Notices — Schaub, Balebako, Durity & Cranor, SOUPS, pp. 1–17 — 2015 — https://www.usenix.org/system/files/conference/soups2015/soups15-paper-schaub.pdf
- [Scheibehenne 2010] Can There Ever Be Too Many Options? A Meta-Analytic Review of Choice Overload — Scheibehenne, Greifeneder & Todd, Journal of Consumer Research 37(3) (63 conditions from 50 experiments, N = 5,036; mean D = 0.02) — 2010 — https://doi.org/10.1086/651235 (read via https://archive-ouverte.unige.ch/unige:76440)
- [Sherwin 2014pl] Placeholders in Form Fields Are Harmful — Katie Sherwin, NN/g — 2014 — https://www.nngroup.com/articles/form-design-placeholders/
- [Sherwin 2014pr] Progress Indicators Make a Slow System Less Insufferable — Katie Sherwin, NN/g — 2014 — https://www.nngroup.com/articles/progress-indicators/
- [Shneiderman 2000] The Limits of Speech Recognition — Ben Shneiderman, CACM 43(9) — 2000 — https://doi.org/10.1145/348941.348990
- [Smetters 2009] How users use access control — Smetters & Good, SOUPS — 2009 — https://cups.cs.cmu.edu/soups/2009/proceedings/a15-smetters.pdf
- [Softcatalà] Guia d'estil — Softcatalà — undated — https://www.softcatala.org/guia-estil-de-softcatala/tota-la-guia/
- [Spencer 2000] The streamlined cognitive walkthrough method, working around social constraints encountered in a software development company — Rick Spencer, CHI, pp. 353–359 — 2000 — https://doi.org/10.1145/332040.332456 (read via a course copy of the ACM PDF: http://facweb.cs.depaul.edu/cmiller/eval/p353-spencer.pdf)
- [Steiner 2018] Optimizing number and timing of appointment reminders: a randomized trial — Steiner, Shainline, Dahlgren, Kroll & Xu, American Journal of Managed Care 24(8):377–384 — 2018 — https://www.ajmc.com/view/optimizing-number-and-timing-of-appointment-reminders-a-randomized-trial
- [Stivers 2009] Universals and cultural variation in turn-taking in conversation — Stivers et al., PNAS 106(26) — 2009 — https://doi.org/10.1073/pnas.0903616106
- [Stothart 2015] The attentional cost of receiving a cell phone notification — Stothart, Mitchum & Yehnert, J. Exp. Psychology: HPP 41(4):893–897 — 2015 — https://doi.org/10.1037/xhp0000100 (abstract: https://europepmc.org/article/MED/26121498) ‡
- [Suhm 2001] Multimodal error correction for speech user interfaces — Suhm, Myers & Waibel, ACM TOCHI 8(1):60–98 — 2001 — https://doi.org/10.1145/371127.371166
- [Sweller 1988] Cognitive load during problem solving: effects on learning — John Sweller, Cognitive Science 12(2):257–285 — 1988 — https://doi.org/10.1207/s15516709cog1202_4 ‡
- [Syrek 2017] Zeigarnik's sleepless nights — Syrek, Weigelt, Peifer & Antoni, Journal of Occupational Health Psychology 22(2):225–238 — 2017 — https://doi.org/10.1037/ocp0000031 (abstract: https://research.uni-luebeck.de/en/publications/zeigarniks-sleepless-nights-how-unfinished-tasks-at-the-end-of-th/) ‡
- [Tan 2014] The effect of developer-specified explanations for permission requests on smartphone user behavior — Tan et al., CHI, pp. 91–100 — 2014 — https://doi.org/10.1145/2556288.2557400 (read via the authors' copy: https://people.eecs.berkeley.edu/~daw/papers/perm-chi14.pdf)
- [Tankala 2023] Skeleton Screens 101 — Samhita Tankala, NN/g — 2023 — https://www.nngroup.com/articles/skeleton-screens/
- [Thompson 2005] Feature Fatigue: When Product Capabilities Become Too Much of a Good Thing — Thompson, Hamilton & Rust, Journal of Marketing Research 42(4):431–442 — 2005 — https://doi.org/10.1509/jmkr.2005.42.4.431 ‡
- [Trajkova 2020] "Alexa is a Toy": Exploring Older Adults' Reasons for Using, Limiting, and Abandoning Echo — Trajkova & Martin-Hammond, CHI, pp. 1–13 — 2020 — https://doi.org/10.1145/3313831.3376760 ‡
- [Tungare 2008] An Exploratory Study of Calendar Use — Tungare, Pérez-Quiñones & Sams, arXiv — 2008 — https://arxiv.org/abs/0809.3447
- [Unicode UCD] Unicode Character Database 15.1 (U+0140, U+00B7) — Unicode, read locally — 2023 — https://www.unicode.org/ucd/
- [Vertanen 2008] On the benefits of confidence visualization in speech recognition — Vertanen & Kristensson, CHI, pp. 1497–1500 — 2008 — https://doi.org/10.1145/1357054.1357288 (read via https://keithv.com/pub/confshade/conf_vis_speech_rec.pdf)
- [Viget 2017] A Bone to Pick with Skeleton Screens — Faulkner & Olvera, Viget (agency; not peer-reviewed) — 2017 — https://viget.com/articles/a-bone-to-pick-with-skeleton-screens
- [Vipperla 2010] Ageing voices: the effect of changes in voice parameters on ASR performance — Vipperla, Renals & Frankel, EURASIP Journal on Audio, Speech, and Music Processing, article 525783 — 2010 — https://doi.org/10.1155/2010/525783 (the published abstract gives 10 points; the authors' preprint, read in full, gives 9.3: https://era.ed.ac.uk/handle/1842/4658)
- [Visa OTP] One-time passcode pattern (supports paste and autofill; keeps a submit button) — Visa Design System (vendor) — undated — https://design.visa.com/patterns/one-time-passcode/
- [von Restorff 1933] Über die Wirkung von Bereichsbildungen im Spurenfeld — Hedwig von Restorff, Psychologische Forschung 18(1):299–342 — 1933 — https://doi.org/10.1007/BF02409636 (bibliographic details checked; the content is known second-hand) †
- [W3C Mobile 2015] Mobile Accessibility: How WCAG 2.0 and Other W3C/WAI Guidelines Apply to Mobile (First Public Working Draft) — W3C — 2015 — https://www.w3.org/TR/mobile-accessibility-mapping/
- [W3C Text size] Text size in translation — W3C Internationalization — undated — https://www.w3.org/International/articles/article-text-size.en
- [Wallace 2022] Towards Individuated Reading Experiences: Different Fonts Increase Reading Speed for Different Individuals — Wallace et al., ACM TOCHI 29(4), Article 38 — 2022 — https://doi.org/10.1145/3502222 (read via the author copy: https://jeffhuang.com/papers/Readability_TOCHI22.pdf)
- [WCAG 2.2] Web Content Accessibility Guidelines 2.2 — W3C Recommendation (2023; edition of 12 Dec 2024), with its Understanding documents — 2024 — https://www.w3.org/TR/WCAG22/
- [WCAG2ICT 2025] Guidance on Applying WCAG 2 to Non-Web Information and Communications Technologies — W3C Group Note — 2025 — https://www.w3.org/TR/wcag2ict-22/
- [Weber 2018] Snooze! Investigating the user-defined deferral of mobile notifications — Weber, Voit, Auda, Schneegass & Henze, MobileHCI — 2018 — https://www.interruptions.net/literature/Weber-MobileHCI18.pdf
- [Wharton 1994] The cognitive walkthrough method: a practitioner's guide — Wharton, Rieman, Lewis & Polson, in Nielsen & Mack (eds.), *Usability Inspection Methods* (Wiley), pp. 105–140 — 1994 — book chapter; the four questions are known through Spencer 2000, Table 1 †
- [White 2019] Task Completion Detection: A Study in the Context of Intelligent Systems — White, Hassan Awadallah & Sim, SIGIR, pp. 405–414 — 2019 — https://doi.org/10.1145/3331184.3331187 (summary: https://www.microsoft.com/en-us/research/publication/task-completion-detection/) ‡
- [Whitenton 2014] 3 Guidelines for Search Engine "No Results" Pages — Kathryn Whitenton, NN/g — 2014 — https://www.nngroup.com/articles/search-no-results-serp/
- [Wilson 2001] Reducing everyday memory and planning problems by means of a paging system — Wilson, Emslie, Quirk & Evans, J. Neurol. Neurosurg. Psychiatry 70(4):477–482 — 2001 — https://doi.org/10.1136/jnnp.70.4.477 (PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC1737307) ‡
- [Wohl 2010] I forgive myself, now I can study — Wohl, Pychyl & Bennett, Personality and Individual Differences 48(7):803–808 — 2010 — https://doi.org/10.1016/j.paid.2010.01.029 (paywalled; known through the BPS Research Digest: https://bps.org.uk/research-digest/cure-procrastination-forgive-yourself) †
- [WP260 2018] Guidelines on transparency under Regulation 2016/679 (WP260 rev.01; adopted 29 Nov 2017, revised 11 Apr 2018) — Article 29 Working Party, endorsed by the EDPB on 25 May 2018 — 2018 — https://ec.europa.eu/newsroom/article29/items/622227/en
- [Wroblewski 2009] Inline Validation in Web Forms — Luke Wroblewski, A List Apart — 2009 — https://alistapart.com/article/inline-validation-in-web-forms/
- [Yankelovich 1995] Designing SpeechActs: issues in speech user interfaces — Yankelovich, Levow & Marx, CHI — 1995 — https://doi.org/10.1145/223904.223952
