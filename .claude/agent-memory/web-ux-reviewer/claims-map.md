---
name: claims-map
description: Where the website claims each app feature and the app/backend source that backs it, for tracing app changes to site lines
metadata:
  type: project
---

Snapshot 2026-10-20 (English lines in `src/content/site/en.ts` / `src/content/legal/en.ts`; ES/CA mirror them). Re-grep before citing.

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
| Account deletion; RevenueCat record deleted best-effort; backups expire on their own | privacy §7, delete-account #scope/#timing | `Backend/docs/ACCOUNT_DELETION.md:32` |
| Resend sends automatic email | privacy §5 | CLAUDE.md Email |
| Language cookie up to 1 year, never location | privacy §8 | `LanguageSwitch.tsx:17`, `src/proxy.ts:4-10` |
| No Apple/iOS anywhere in legal | — | removed (WEB-210); re-flag any "Apple" |
| Empty-dictation error = app's `captureEmptyInput` | demo `errors.empty` | app_en.arb ~1530 |

Known leftover wording (not yet fixed when last checked): terms meta description says "AI drafts"; privacy §2/§4 still use "drafts", "allowances", "transcript", "AI Studio/Gemini API route"; hand-over "Coming soon to Google Play" vs header "Coming soon to Android"; demo privacy line "Google's AI".

Related: [[site-map]].
