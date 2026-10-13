#!/usr/bin/env bash
# Helper for the /ux loop. Run it from anywhere inside the repo.
#   ux.sh changed  user-facing files changed since the last UX review, one per line
#                  (prints NO_SNAPSHOT if no review has been recorded yet)
#   ux.sh keys     ARB keys added, changed or removed in app_en.arb since the last review
#   ux.sh save     record the current state of user-facing files as reviewed
#   ux.sh status   when the last review snapshot was taken
#
# The snapshot is a commit object kept at refs/ux-review/last. It is built from a
# temporary index, so the branch, the real index and the working tree are untouched,
# and uncommitted or new files count.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

REF=refs/ux-review/last
# Keep in step with "User-facing" in CLAUDE.md and the reviewer's scope.
CANDIDATES=(
  App/lib/screens App/lib/widgets App/lib/theme App/lib/main.dart App/lib/l10n
  App/lib/services/reminder_copy.dart App/lib/services/notification_service.dart
  App/lib/services/capture_problem.dart App/lib/services/feedback_timeout.dart
  App/assets
  App/android/app/src/main/res App/android/app/src/main/kotlin
  App/ios/Runner/Info.plist App/ios/Runner/en.lproj App/ios/Runner/es.lproj App/ios/Runner/ca.lproj
)
PATHS=()
for p in "${CANDIDATES[@]}"; do [ -e "$p" ] && PATHS+=("$p"); done
GENERATED='^App/lib/l10n/generated/'

current_tree() {
  local idx
  idx="$(mktemp)"
  cp "$(git rev-parse --git-path index)" "$idx"
  GIT_INDEX_FILE="$idx" git add -A -- "${PATHS[@]}" 2>/dev/null
  GIT_INDEX_FILE="$idx" git write-tree
  rm -f "$idx"
}

need_snapshot() {
  git rev-parse -q --verify "$REF" >/dev/null || { echo "NO_SNAPSHOT"; exit 0; }
}

case "${1:-}" in
  changed)
    need_snapshot
    git diff --name-only "$REF" "$(current_tree)" -- "${PATHS[@]}" | grep -vE "$GENERATED" || true
    ;;
  keys)
    need_snapshot
    git diff -U0 "$REF" "$(current_tree)" -- App/lib/l10n/app_en.arb \
      | grep -E '^[+-][[:space:]]*"[A-Za-z0-9_]+"[[:space:]]*:' \
      | sed -E 's/^[+-][[:space:]]*"([A-Za-z0-9_]+)".*/\1/' \
      | sort -u || true
    ;;
  save)
    tree="$(current_tree)"
    commit="$(git commit-tree "$tree" -p HEAD -m "UX review snapshot")"
    git update-ref "$REF" "$commit"
    echo "Saved UX review snapshot $(git rev-parse --short "$commit")"
    ;;
  status)
    git rev-parse -q --verify "$REF" >/dev/null || { echo "No UX review snapshot yet."; exit 0; }
    git log -1 --format='Last UX review snapshot: %ci (%h)' "$REF"
    ;;
  *)
    echo "usage: ux.sh changed|keys|save|status" >&2
    exit 2
    ;;
esac
