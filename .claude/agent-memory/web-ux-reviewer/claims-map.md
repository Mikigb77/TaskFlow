---
name: claims-map
description: Where the website claims each app feature and the app/backend source that backs it, for tracing app changes to site lines
metadata:
  type: project
---

Snapshot 2026-10-20 after b5 (English lines in `src/content/site/en.ts` / `src/content/legal/en.ts`; ES/CA mirror them). Re-grep before citing.

| Feature claimed | Site (en) | Source of truth |
|---|---|---|
| Android only; not on Google Play yet, can't download | site en.ts hero ~7, status ~52, FAQ ~89, closing ~124, demo hand-over ~184, header `comingSoon` ~23 | ux-web DECISIONS (Play not published) |
| Several tasks in one dictation; reminders asked once on first dated task | en.ts ~49, ~61 | app ARBs, ux-review DECISIONS |
| Phone calendars shown beside tasks, stay on the phone | en.ts ~61; privacy §9 permissions | App device-calendar bridge |
| Notes tab: Add a note, write or dictate, links/checklist | FAQ ~117-119 | ARB `notes`, `addNote`, `notesEmptyHelp`, `noteTitleHint` |
| Files on tasks, backed up, 6 MB each | en.ts ~76 | free-tier plan / backend limits |
| Offline use | features offline card ~78, FAQ ~107 | IMPLEMENTATION_STATUS |
| Sharing with family | FAQ ~112 | sharing docs, ARBs |
| Free: 10 dictations/month; form unlimited after; Pro: unlimited dictation + files, 50/day safety limit, typed sentences to tasks, monthly, price not set | FAQ ~94 | free-tier-plan.md, REVENUECAT_SETUP.md |
| Live demo: 3 tries; recording not kept; quota records only | demo badge; privacy §8 #website | `src/lib/voice/policy.ts` |
| Google sign-in keeps first name only, no photo (NOT "no surname": falls back to full `name`) | privacy §2 #data | `Backend/core/google_auth.py:42-45` |
| 6-digit email code, 30 min | privacy §2 | `Backend/docs/EMAIL_VERIFICATION.md:3` |
| On-device speech | privacy §4 | `App/lib/services/native_speech.dart` |
| AI provider: app uses Google's Gemini API, Vertex AI as fallback; website demo uses Vertex AI; may process outside the EU | privacy §4 (and §EU/transfers) | `Backend/core/ai.py:118-133` |
| Demo privacy line: "What you say or type goes to Google only when you tap Done…recording not kept…text deleted after 24 hours" | site en.ts:148 `voice.privacy` | privacy §8, FAQ ("sent to Google"), `src/lib/voice/policy.ts` |
| Usage limits (not "allowances") collected/applied | privacy §2 #data, terms §2/§3/§6 | free-tier-plan.md |
| Legal effective date 2026-10-20 (pending owner WD3 sign-off) | `company.json:10` version, `docs/LEGAL_RELEASE.md:3` | ux-web DECISIONS WD3 |
| Account deletion; RevenueCat record deleted best-effort; backups expire on their own | privacy §7, delete-account #scope/#timing | `Backend/docs/ACCOUNT_DELETION.md:32` |
| Resend sends automatic email | privacy §5 | CLAUDE.md Email |
| Language cookie up to 1 year, never location | privacy §8 | `LanguageSwitch.tsx:17`, `src/proxy.ts:4-10` |
| No Apple/iOS anywhere in legal | — | removed (WEB-210); re-flag any "Apple" |
| Empty-dictation error = app's `captureEmptyInput` | demo `errors.empty` | app_en.arb ~1530 |

Fixed in b5 (2026-10-20): terms description, privacy §2/§3/§4 and terms §5 heading ("AI suggestions", id `ai` kept) no longer say draft/allowance/transcript/AI Studio; demo privacy line no longer "Google's AI".
Still-leftover wording (unflagged as of 2026-10-20): terms §5 first paragraph (legal en.ts ~239) "AI capture is optional"; demo hand-over (en.ts:184) and status (:52) say "Coming soon to Google Play" while header `comingSoon` (:23) and closing title (:124) say "Coming soon to Android".

Related: [[site-map]].
