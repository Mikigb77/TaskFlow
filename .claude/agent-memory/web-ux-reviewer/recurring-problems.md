---
name: recurring-problems
description: Problem types that recur on the TaskFlow site and review techniques that caught them in run 2026-10-18-site
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

Techniques that worked: compare render mtimes with source mtimes first; crop full-page renders with `crop.mjs` at the screen in question; width arithmetic from the render (chars × px vs box padding); cite AUDIT row line numbers; check the tester's spec line numbers so a fix is protected by a test; list new Catalan strings for a native read rather than judging them.

Related: [[site-patterns]].
