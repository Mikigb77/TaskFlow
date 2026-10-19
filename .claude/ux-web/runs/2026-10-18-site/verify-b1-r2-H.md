## UX web verify — run 2026-10-18-site, round 2, area H (WP33) — 2026-10-19

**Verdict:** WEB-6 (WP33's part) is fixed. I found no regressions.

**Evidence base:**
- I read the run's own diff (`ux-web.sh diff`) of all five held files.
- I grepped `src/` and `public/` for `walkthrough|recorrido|recorregut|#demo|Try the demo|en vivo independiente|separate live demo|simulation|simulaci`. Nothing matches.
- I checked the `voice-tries-used.en.mobile.light.panel.png` render (04:45) and the AUDIT.md rows (04:48). Both are newer than the code (03:52).
- The tester's passing WEB-6 tests back this up (listed in the delegation).

### WEB-6 · fixed (WP33 scope)
- **Footer** (`src/components/Footer.tsx:22`): it now reads `<a href={`/#voice`}>Try it with your voice</a>`.
  - The target `id="voice"` exists at `src/components/VoiceDemo.tsx:363`.
  - Nothing else in the file changed. The other session's lines 2, 18, 26–32 and 34–36 are untouched.
- **Tries-used line** (`src/components/VoiceDemo.tsx:818-830`): it now ends `… : "tomorrow"}` followed by `.`.
  - JSX trims the newline, so the line reads "Your allowance returns Mon 9:45 AM." In the render it has no stray space and no walkthrough promise (`voice-tries-used.en.mobile.light.panel.png`).
- **Privacy §8, first paragraph** (`src/content/legal/{en,es,ca}.ts:139`): the paragraph matches the brief's EN, ES and CA text character for character.
  - The second and later paragraphs, the section title and the version and date are untouched.
- **No pointers left:** no `#demo` and no walkthrough wording remains anywhere in `src/`.
- **Not part of WP33:** WEB-6's static example (WD1's stand-in for the walkthrough) belongs to WP26. It isn't in the code yet: there is no `VoiceExample`, and no "dentist" string. It stays tracked under WP26 and isn't counted against WP33.

### Regressions
None. These are things I checked and ruled out:
- The footer label "Try it with your voice" is in English on `/es/`, `/ca/` and the legal pages. The whole footer is English today, and WP23 (held) translates it. This was there before (WEB-304), not a regression.
- The footer links stay at 13 px / 12 px under 200% text (`AUDIT.md` line 242). This was there before (WEB-8 / WEB-703, footer type is in px). The link is longer but doesn't overflow: `AUDIT.md` §3 shows no overflow at w320 for home and privacy in EN, ES and CA.
- The tries-used state no longer offers any next step. It used to point at the walkthrough, which no longer exists, so that pointer was false. Removing it is correct. The dead end and the "allowance" jargon belong to WEB-7 / WEB-12 (WP28 rewrites lines 818–830, and WP29 shows the static example when the demo can't run).
- "Explore the app" (`Header.tsx:48`) and "Try the live demo" (`VoiceDemo.tsx:391`) are other labels for the demo. They belong to WP20 and WP26 (WEB-4), not to this change.

### Catalan for a native read
- §8 CA: «La demo en viu envia àudio/text a Google només amb Create drafts (Crear esborranys), sense sincronitzar-los amb un compte.»
- This is the existing sentence with words removed. WP31 rewrites it later.
