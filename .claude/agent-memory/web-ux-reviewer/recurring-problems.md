---
name: recurring-problems
description: Problem types and verified review techniques from the shared TaskFlow web UX runs
metadata:
  type: feedback
---

Regressions that fixes kept introducing; check for them in every verify.

- **Copy promising more than is true in that state**: an error reused in the wrong moment ("what you said is kept" before anything was said); a tries badge in a state with nothing to try; a privacy sentence the backend doesn't guarantee ("no surname"). **Why:** strings get reused across states. **How to apply:** for each new/reused string, ask "true at this exact moment, and true in the backend code?"
- **Silent state changes**: a form disappears or a try is used with nothing on screen or announced. Check AUDIT §13 announcement column ("—" = nothing announced).
- **Larger text breaks layout downstream**: px→rem or 0.875→1rem pushed a CTA below the 320 × 568 fold, broke an email mid-domain, wrapped a meta line with a dangling "·". After any size change, crop the w320 and text200 renders.
- **Lost spaces when replacing a sentence** in content files. Grep `[a-zà-ú]\.[A-ZÀ-Ú][a-zà-ú]` over `src/content/**`.
- **Empty or half-empty cards** after removing copy (desktop feature cards, offline card).
- **Dates/weeks disagreeing** between two calendars on the page; weekday clipping in ES/CA («el mar», «dt.»).
- **English leaking into ES/CA** and `lang` mismatches on passages.
- **Focus ring contrast** dropping on held/disabled buttons.

- **Old jargon surviving in one corner** after a word sweep (terms §5 "AI capture is optional"; "Google Play" vs "Android" availability lines). After a terminology fix, grep the whole of `src/content/` in all three languages, not just the brief's lines.

- **Native focus can finish after a synchronous completion reveal** (WEB-903, `2026-10-21-codex-completion-banner`): a React effect ran before native input/change, then browser movement hid the group banner. A single cancellable frame with current geometry and instant scrolling passes the original natural-focus cases and 54 current regions. Keep native focus, keyboard/assistive context, undo-before-frame and undo-after-start coverage. A passing isolated repeat does not invalidate an earlier failing matrix case.
- **Ignored evidence can still be compiler input** (same run): source snapshots ending in `.tsx` under `artifacts/` were included by TypeScript and failed the production build. Preserve provenance snapshots as `.tsx.txt`; do not alter product tsconfig to accommodate evidence files.
- **Engine tap focus is not keyboard focus** (same run): Windows WebKit moves native checkbox focus to BODY on both partial and final taps before input/change. Preserve that native behavior and input identity; verify explicit keyboard focus separately instead of adding product focus calls for a harness assumption.
- **Requested English URL is not locale proof** (same run): Windows WebKit inherited Spanish Accept-Language and `/` redirected to `/es/`. Pin the intended browser locale and verify actual URL, document lang and heading before labeling a capture or asserting localized status. Preserve mislabeled evidence, then replace only affected states.

- **An app feature grows and the site's verbs lag** (2026-10-21-changes: voice gained find/change/bulk commands): "turns what you say into tasks" survived in the FAQ, privacy summary and terms. After any app capability change, grep home, privacy summary/§2/§4 and terms §3/§5 in all three languages for the old verb phrase; a legal edit moves the version (WD3).
- **Absolute words go false when the app grows** (2026-10-22-changes, reminder plans): "never sends anything to the AI" and "asks you once" broke because a new Pro sheet calls the AI and a new per-task question appeared. Grep the site for never/only/once/always/una sola vez/nunca/mai/només in all three languages after any app change; prefer narrowing the sentence (add "Without Pro", drop the clause) over adding new copy.
- **Longer copy leaves a widow on phones** (2026-10-22-changes, WEB-1105): adding a clause in ES/CA left «día.» alone at 390 px. After any copy lengthening, check es/ca mobile full renders; fix with `text-wrap: pretty`, never by trimming the claim. `pretty` is unsupported in older Safari (device check).
- **FAQ answers beyond the first aren't rendered open**: changes to later FAQ answers rest on the tester's 320 px / text-200 / axe tests; name that as the evidence level.
- **Raster screenshots hide text from the site's audit**: axe and AUDIT §7 can't see text inside `hero-calendar-*.png` (e.g. «2 pendientes» 3.00:1, ~9 px in the desktop hero). Use the app's own audit for in-image contrast and treat legibility as a device check; a property the old image also had isn't a regression.

Evidence gaps to name, not paper over: when WSL won't start (`Wsl/Service/CreateInstance/E_UNEXPECTED`), crop.mjs and the tester's specs can't run; say the verdict rests on code + existing renders/AUDIT, and list the unrun tests as pending evidence, not as failures. Files held because another session's uncommitted work shares them can't be committed; that's a loop status, not a finding. `voice-*.panel.png` can be cut at the viewport edge (render-tool artifact): read the `view.png` too. Language of parts (`lang`) isn't in renders or AUDIT: verify by nearest `[lang]` in code and spec.

Techniques that worked: compare render mtimes with source mtimes first; crop full-page renders with `crop.mjs` at the screen in question; width arithmetic from the render (chars × px vs box padding); cite AUDIT row line numbers; check the tester's spec line numbers so a fix is protected by a test; list new Catalan strings for a native read rather than judging them.

Related: [[site-patterns]].
