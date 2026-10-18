# Known failures

These checks already failed before the UX web loop started, so the gate doesn't hold them against a round. Remove an entry once it's fixed. Add one only when you're sure the loop didn't cause it.

None. Baseline on 2026-10-18, in WSL (Node 26.8.2, npm 12.0.2, Playwright 1.63.0), on TaskFlowWeb `dev` at e247dd3, with the other session's uncommitted legal work in the working tree:
- `npm run check`: passes.
- `npm run legal:check`: passes.
- `npm run test:unit`: 9 of 9 pass.
- `npm run build`: passes.
- `npm test`: 38 pass (19 tests on 2 projects). `tests/ux-renders.spec.ts` adds one skipped placeholder per project.
- `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts`: 58 pass, 2 skipped (the once-only checks on the mobile project), 113 PNGs.

Not failures, so don't report them:
- `npm run start` warns `"next start" does not work with "output: standalone" configuration`. The production server still serves every page, and the suite passes through it.
- npm 12 prints `npm notice run …` before each script.
