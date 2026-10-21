# Bounded source review — completion banner

Configured independent reviewer: gpt-6.1-sol / max. Proceed with WP52. WD17 settles placement; no unresolved owner decision.

## WEB-901 · S2 · H · Completion appears inside one task

Source: `src/components/VoiceDemo.tsx:305-310`, `:1001-1011`; `src/styles/voice.css:476`. `completionAt` selects the final toggled task; its card contains a group reward. The all-clear therefore appears to describe one task, obscuring its group meaning. WD17 controls placement; SC-2 and AX-5 support clear hierarchy and content relationships. This corrects the clarified requirement, not a retrospective failure against WD16.

Reproduction: generate three tasks; check two, then the remaining task. The reward appears under that title. Repeat with any other final task. Source-proven at initially clean web HEAD c888d10237aafd4a2339a89570f3699d063768f1. Historical EN dark desktop, ES light mobile and CA dark mobile captures visibly confirm the old placement. Those captures cannot certify the forthcoming banner.

## Recommendation and acceptance

Render one full-width `.voice-completion` sibling immediately before `.voice-drafts`, after the result heading. Remove task-specific placement state. Preserve native inputs, details, copy and one atomic polite status. No reserved space, no sticky banner covering task details.

Use one conditional pointer/touch reveal on incomplete-to-complete when the banner is outside the unobscured viewport; clear the sticky header. Smooth scrolling only without reduced-motion preference. No undo or repeated completed-render reveal. Keyboard/assistive activation retains checkbox focus/context without explicit scrolling; status announces completion, banner remains above the group. This favors stable keyboard interaction over forcing its focused checkbox offscreen and is an implementation judgment, not owner policy. Allow natural scroll anchoring; fixed scrollY and checkbox coordinates cannot both be required without blank space.

Test one group banner across columns regardless of order; none on initial/partial/empty/loading/error states; immediate undo removal; same native input node/focus/labels; all details; clear/reset paths; no extra network/quota/storage; EN/ES/CA, both themes, desktop/mobile,320px,actual doubled text/spacing, reduced motion. Fresh evidence is required. Native-phone and screen-reader checks remain pending. Existing WEB-801 remains separately open.

Scoped claim check: completion is local React state (VoiceDemo.tsx:229,300); localized nothing-saved disclaimers remain accurate. Completion exists in App/lib/models/task.dart:251 and Backend/core/models.py:221. Existing aspirational reward copy adds no saving/capability promise.

Reviewer ran no tests/builds/captures and changed no files.
