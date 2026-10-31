## UX verify — b7 round 3, area D (P99) — 2026-10-14
**Verdict:** Ship. UX-512 is fixed. Every file-size message now says "6 MB", and this round caused no regressions.
**Evidence:** I checked the code with grep, a word-diff against HEAD and a script that compares the `requestError` line before and after. ux-tester's four tests in App/test/attachment_panel_test.dart pass. No preview shows the file help or the too-big snackbar, so I read no render; the change only edits text and doesn't touch any layout.

### UX-512 · fixed
- `fileLocalHelp`, `fileLimit` and the `fileLimit` branch of `requestError` now say "6 MB" in all three languages:
  - EN: App/lib/l10n/app_en.arb:921, :922 and :43
  - ES: App/lib/l10n/app_es.arb:551, :552 and :24
  - CA: App/lib/l10n/app_ca.arb:530, :531 and :25
- The new copy matches the brief exactly. `fileLimit` still says 20 files per task.
- The script showed that in each language the new `requestError` line equals the old one with "6 MiB" replaced by "6 MB". No other branch of `requestError` changed.
- 'MiB' now appears 0 times in the three ARB files. The regenerated Dart files carry the new text: app_localizations_en.dart:139, :1860 and :1864; the matching lines in the es and ca files.
- The three spots that still say "6 MiB" are internal and nobody sees them, as the brief said:
  - request_locale.dart:98 matches on the text '6 mib';
  - attachment_files.dart:45 throws a FormatException, and task_editor.dart:410 shows `fileLimit` in its place;
  - attachment_store.dart:230 is a code comment.
- Where people see it in the task editor:
  - the help line at task_editor.dart:367-369 and :816-817 (`fileLocalHelp` or `fileUploadHelp`);
  - the too-big snackbar at :351 and :410 (`fileLimit`).

  All of them now use the same unit, and it's the one people know.
- Hidden effect: the real limit is 6 MiB (6,291,456 bytes), so the "6 MB" label slightly understates it. A file the phone lists as "6.2 MB" is still accepted. That errs on the generous side, so no user harm.

### Regressions
None.
- The storage-usage strings that format sizes (attachment_panel.dart:146-175, subscription_screen.dart:16 and :64) already said "MB", so the units now agree everywhere.
- The new strings are one character shorter, so there's no new clipping risk at 2× text.
