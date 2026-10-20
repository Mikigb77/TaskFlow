## UX web verify — run 2026-10-18-site, batch 4 round 2, area H (WP43) — 2026-10-19

**Verdict:** all four findings fixed; no regressions in the changed files.
**Evidence base:** code (`src/components/VoiceDemo.tsx`, `src/content/site/{types,en,es,ca}.ts`), the tests the package changed, renders and AUDIT.md §13 regenerated 2026-10-20 02:32–02:35, after the last code change (00:47). Renders are Chromium with the API stubbed; no real device, no real Turnstile.

### Findings

**WEB-721 (R1H-1) · fixed**
- `VoiceDemo.tsx:314-321` `statusFailed`: anything not `Refused` now gives `t.errors.offlineOpening`; `submit`'s catch (`:506-513`) still uses `t.errors.offline` for a send that fails.
- Copy exact in all three: `en.ts:209`, `es.ts:209-210`, `ca.ts:218-219`; type comment `types.ts:179-180` as briefed.
- Render `voice-connect-offline.en.mobile.light.panel.png`: "No connection. Check Wi-Fi or mobile data and try again." with the filled Try again under it, no "kept". AUDIT §13:965-966: 0 axe violations, announced as alert with that text.
- Tests: `tests/ux-web-voice.spec.ts:1566` (opening → offlineOpening), `:1595` (sending → offline, unchanged), `:1988`, copy table `:1284`.

**WEB-722 (R1H-2) · fixed**
- Badge `VoiceDemo.tsx:711-717`: developer text first, then the count only when `status` is set and stage is neither `off` nor `unverified`, else `t.liveDemo`. No new string.
- Renders: `voice-error-budget-pause.en.mobile.dark.panel.png` and `voice-check-gave-up.en.mobile.light.view.png` read "Live demo"; `voice-stop-waiting…view.png` (capture) still "2 of 3 tries left".
- Tests `:2053`, `:2061`, `:2069` (paused at opening, budget_pause, unverified, three languages).

**WEB-723 (R1H-3) · fixed**
- `shownError` (`:281-286`) gives `t.errors.unverified` in the unverified stage; the top alert is suppressed for `off` and `unverified` (`:734`); the unverified block (`:1025-1031`) renders example → `alertBox` → hand-over inside `.voice-off`. The focus effect (`:376-379`) moves focus to `errorMessage`. The `handOver` ref, its `tabIndex` and fallback are gone (no dead code; grep finds no `handOver.current`).
- Copy exact in EN/ES/CA (`en.ts:217-218`, `es.ts:218-219`, `ca.ts:227-228`).
- Render `voice-check-gave-up.en.mobile.light.view.png`: example, reason box, hand-over starting at the fold. AUDIT §13:980-981: 0 axe, alert announced with the full reason.
- Catalan for a native read: «La comprovació de seguretat no s’ha carregat, així que la demo en directe no pot funcionar aquí. L’exemple de dalt mostra què fa TaskFlow.»

**WEB-724 (R1H-4) · fixed**
- `submit` (`:518-526`): a stopped request gets `t.errors.timeout` for `timeout`, otherwise `t.errors.processing`, with `retry: true`; `close` returns at `:533` before any message. Comment updated.
- Render `voice-stop-waiting.en.mobile.light.view.png`: the processing message at the top of the panel, text kept, badge 2 of 3. AUDIT §13:1023-1024: 0 axe, announced.
- Tests `:1444-1484` (typed, three languages: alert text, focus, same X-Request-Id on Try again, badge after result) and `:1489+` (recording).

### Regressions
None found in the changed files or the demo states they touch (connect-offline, send-offline, off/paused/budget_pause, check gave up, stop waiting, timeout, close while waiting).

### Notes
- The badge reads "Live demo" above "The live demo is off for now" / "…can’t run here": the badge works as the panel's name, not a status; as briefed, not a finding.
- Device checks still open (from the package): native Catalan read above; TalkBack in Spanish for the gave-up and Stop waiting alerts; the deployed site with Cloudflare's script blocked.
