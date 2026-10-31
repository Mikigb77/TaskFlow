# Run 2026-10-19-app: D12 measured on the review emulator (2026-10-20)

**What D12 asked** (`plan.md`, Round 2 (b3)): before deciding anything, capture Tareas on the emulator at Android's real 2.0 text on a 393 dp phone. If a whole task shows and «Tus tareas» / «Les teves tasques» is on one line, UX-1403 closes as fixed. If not, it joins U13's evidence.

**Evidence level: emulator.** TaskFlow_Review: Android 16, Pixel 4 profile at about 393 dp, Android's own non-linear 2.0 font size. The APK is a42b56c, built from a clean worktree; its app code is batch b3's, including P176.

| Language | Capture | Title on one line | A whole task row above the button |
|---|---|---|---|
| ES | `App/build/ux/device/screen-tasks.list.es.light.2.0.png` | yes: «Tus tareas» | yes: «Comprar fruta · Hoy» and «Reunión con Laura · Hoy · 20:00», with a third row starting below |
| CA | `App/build/ux/device/screen-tasks.list.ca.light.2.0.png` | yes: «Les teves tasques» | yes: «Comprar fruita · Avui», with «Reunió amb la Laura · Avui · 20:00» nearly whole above «Sense desar · 2» |

**Result: both conditions hold, so UX-1403 closes as fixed by D12's own rule.**
- The ledger moves it once batch b4 has finished writing `ISSUES.md`.
- The linear-2× test in `App/test/home_screen_test.dart` stays skipped. The preview's linear 2× is harsher than Android's non-linear 2.0, and D12 named the emulator as the judge.

**Caveat for U13:** the review account has no shared project, so the project filter is absent; on its own it adds two rows. In the preview at 360 dp and linear 2× with a shared project, only part of the first task shows. That case stays with U13's evidence for the owner's test with his father.

Also visible in the same captures: «Configuració», the Catalan Settings tab label, is whole at 2.0 on 393 dp (`screen-tasks.list.ca.light.2.0`), which bears on D9 and P196.
