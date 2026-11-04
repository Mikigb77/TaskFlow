# Known failures

These checks already failed before the UX loop started, so the gate doesn't hold them against a round. Remove an entry once it's fixed. Add one only when you're sure the loop didn't cause it.

Baseline on 2026-10-13: `flutter test --no-pub` passes all 325 tests.

## 2026-11-03: two analyzer warnings under Flutter 3.47.9 (cloud sessions)

The cloud session installs Flutter 3.47.9, whose newer lint `unawaited_return_in_try_block` warns at two places that the loop didn't write and doesn't touch: `App/lib/services/capture_processor.dart:211` and `:291` (a third, in `task_editor.dart`, was fixed in run 2026-11-03-screens).

`flutter analyze --no-pub` then ends with "2 issues found". These two, and only these, are not a round's failure. Fixing them (an `await` inside the `try`) changes which errors the `catch` sees, so it's a separate change.
