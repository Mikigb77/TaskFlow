---
name: claims-map
description: Where the website claims each app feature and the app/backend source that backs it, for tracing app changes to site lines
metadata:
  type: project
---

Snapshot 2026-10-22 (after run 2026-10-21-changes b1-b2) (English lines in `src/content/site/en.ts` / `src/content/legal/en.ts`; ES/CA mirror them). Re-grep before citing.

| Feature claimed | Site (en) | Source of truth |
|---|---|---|
| Android only; not on Google Play yet, can't download | site en.ts hero ~7, status ~52, FAQ ~89, closing ~124, demo hand-over ~184, header `comingSoon` ~23 | ux-web DECISIONS (Play not published) |
| Several tasks in one dictation; reminders "asks you once" (not "the first time you add one") | en.ts ~49, ~61 | app ARBs, ux-review DECISIONS |
| Voice finds and changes tasks too, incl. bulk (move yesterday's to tomorrow, complete many at once; one undo) | FAQ "How do I add tasks by voice?" en.ts ~104; calendar/voice card sentence ~71 | ux-review DECISIONS 2026-10-21 "Bulk voice commands"; `Backend/docs/VOICE_COMMANDS.md:400` (no Pro needed) |
| Home-screen shortcut/widget "Dictate a task" / «Dictar una tarea» / «Dicta una tasca»; share text from WhatsApp | FAQ 8th item en.ts ~122-125 | `App/android/app/src/main/res/values{,-es,-ca}/strings.xml:3,11`; `AndroidManifest.xml:46-48` (`text/plain`) |
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
| Privacy: voice text sent "to add, find or change tasks"; returns "suggested tasks and changes" | privacy summary 02, §2 ~33, §4 ~55-56 | same as voice-commands row |
| Legal effective date 2026-10-21 (pending owner WD3 sign-off) | `company.json:10` version, `docs/LEGAL_RELEASE.md:3` | ux-web DECISIONS WD3 |
| Account deletion; RevenueCat record deleted best-effort; backups expire on their own | privacy §7, delete-account #scope/#timing | `Backend/docs/ACCOUNT_DELETION.md:32` |
| Resend sends automatic email | privacy §5 | CLAUDE.md Email |
| Language cookie up to 1 year, never location | privacy §8 | `LanguageSwitch.tsx:17`, `src/proxy.ts:4-10` |
| No Apple/iOS anywhere in legal | — | removed (WEB-210); re-flag any "Apple" |
| Empty-dictation error = app's `captureEmptyInput` | demo `errors.empty` | app_en.arb ~1530 |

Still-leftover wording (unflagged, re-grepped 2026-10-22):
- terms §3 (legal en.ts ~221) "optional dictation that turns what you say into tasks": incomplete now that voice finds/changes tasks; next legal edit (moves version, WD3).
- terms §5 (legal en.ts ~239) "AI capture is optional": jargon.
- demo hand-over (en.ts ~191) and status (~52) "Coming soon to Google Play" vs header `comingSoon` (~23) and closing title (~129) "Coming soon to Android".

Related: [[site-map]].
