#!/usr/bin/env bash
# Helper for the /ux-web loop. Run it with bash on Windows (Git Bash), never from WSL.
# It finds both repos from its own location: the app repo two folders up, and the website
# at ../TaskFlowWeb next to it (override with TASKFLOW_WEB).
#
#   ux-web.sh changed   user-facing website files changed since the last web review, one per line
#                       (prints NO_SNAPSHOT if no web review has been recorded yet)
#   ux-web.sh app       app-repo files the site's claims rest on, changed since the last web
#                       review (prints NO_SNAPSHOT if none has been recorded yet)
#   ux-web.sh since [--app] [path...]
#                       the changes since the last web review, as a diff: website files, or
#                       with --app the app-side files. Use it rather than git diff against the
#                       ref: untracked files would show as deleted there.
#   ux-web.sh save      record the website and the app-side files as reviewed, now
#   ux-web.sh status    when the snapshots were taken
#
#   ux-web.sh base             record the website's whole working tree as a fix run's start
#   ux-web.sh ran              website files changed since `base`, one per line
#   ux-web.sh diff [path...]   those changes, as a diff: the run's own changes
#   ux-web.sh stage path...    stage only the changes made since `base` to these paths, in the
#                              website's index. A path that held another session's uncommitted
#                              work when the run started gets only the run's hunks
#                              (git apply --cached); one it can't separate is refused, and the
#                              exit code is 1.
#
# Snapshots are commit objects built from a temporary index, so the branch, the real index
# and the working tree are untouched, and uncommitted and new files count:
#   refs/ux-web/last      website repo: the whole working tree at the last web review;
#   refs/ux-web/app-last  app repo: the app-side files at the last web review;
#   refs/ux-web/base      website repo: the whole working tree when the fix run started.
set -euo pipefail
export GIT_LITERAL_PATHSPECS=1 # Next.js folders such as [language] are paths, not globs.

APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB="$(cd "${TASKFLOW_WEB:-$APP/../TaskFlowWeb}" && pwd)"
LAST=refs/ux-web/last
APP_LAST=refs/ux-web/app-last
BASE=refs/ux-web/base

# What a visitor sees. Keep in step with the areas in .claude/skills/ux-web/SKILL.md.
WEB_PATHS=(
  src/app src/components src/content src/styles
  src/lib/voice/policy.ts src/lib/voice/recorder.ts
  public next.config.ts
)
WEB_EXCLUDE='^src/app/(api|health)/'
# What the site's claims rest on, in the app repo.
APP_PATHS=(
  App/docs App/lib/l10n/app_en.arb Backend/docs
  .claude/ux-review/DECISIONS.md .claude/ux-review/voice-commands-plan.md
  .claude/ux-review/free-tier-plan.md .claude/ux-review/free-tier-backend-notes.md
)
APP_EXCLUDE='^Backend/docs/(STAGING|ARCHITECTURE)\.md$'

git -C "$WEB" rev-parse --git-dir >/dev/null

# current_tree <repo> [path...]: write the working tree as a tree object and print its id.
# Without paths, everything git doesn't ignore; with paths, only those (existing or tracked).
# Always called as $(current_tree …), in a subshell: the trap removes the temporary index if
# a step fails, and the end removes it otherwise (bash may exec a last external command in
# place of the subshell, which skips the trap, so the function ends on builtins).
current_tree() {
  local repo="$1" idx tree
  shift
  idx="$(mktemp)"
  trap "rm -f '$idx'" EXIT
  cp "$(git -C "$repo" rev-parse --path-format=absolute --git-path index)" "$idx"
  # stderr is dropped, as in ux.sh: git warns about line endings on every add.
  if [ $# -eq 0 ]; then
    GIT_INDEX_FILE="$idx" git -C "$repo" add -A 2>/dev/null
  else
    local p kept=()
    for p in "$@"; do
      if [ -e "$repo/$p" ] || [ -n "$(git -C "$repo" ls-files -- "$p")" ]; then kept+=("$p"); fi
    done
    [ ${#kept[@]} -eq 0 ] || GIT_INDEX_FILE="$idx" git -C "$repo" add -A -- "${kept[@]}" 2>/dev/null
  fi
  tree="$(GIT_INDEX_FILE="$idx" git -C "$repo" write-tree)"
  rm -f "$idx"
  echo "$tree"
}

need() { # need <repo> <ref> <message> [exit code]
  git -C "$1" rev-parse -q --verify "$2" >/dev/null || { echo "$3"; exit "${4:-0}"; }
}

blob() { # blob <tree-ish> <path>: the blob id, or nothing if the path isn't there
  git -C "$WEB" rev-parse -q --verify "$1:$2" 2>/dev/null || true
}

when() { # when <repo> <ref> <label>
  if git -C "$1" rev-parse -q --verify "$2" >/dev/null; then
    git -C "$1" log -1 --format="$3: %ci (%h)" "$2"
  else
    echo "$3: none yet"
  fi
}

case "${1:-}" in
  changed)
    need "$WEB" "$LAST" NO_SNAPSHOT
    git -C "$WEB" diff --name-only "$LAST" "$(current_tree "$WEB")" -- "${WEB_PATHS[@]}" | grep -vE "$WEB_EXCLUDE" || true
    ;;
  app)
    need "$APP" "$APP_LAST" NO_SNAPSHOT
    git -C "$APP" diff --name-only "$APP_LAST" "$(current_tree "$APP" "${APP_PATHS[@]}")" -- "${APP_PATHS[@]}" | grep -vE "$APP_EXCLUDE" || true
    ;;
  since)
    shift
    app_side=""
    if [ "${1:-}" = "--app" ]; then app_side=1; shift; fi
    if [ "${1:-}" = "--" ]; then shift; fi
    if [ -n "$app_side" ]; then
      need "$APP" "$APP_LAST" NO_SNAPSHOT
      repo="$APP" ref="$APP_LAST" now="$(current_tree "$APP" "${APP_PATHS[@]}")"
      [ $# -gt 0 ] || mapfile -t files < <(git -C "$APP" diff --name-only "$APP_LAST" "$now" -- "${APP_PATHS[@]}" | grep -vE "$APP_EXCLUDE")
    else
      need "$WEB" "$LAST" NO_SNAPSHOT
      repo="$WEB" ref="$LAST" now="$(current_tree "$WEB")"
      [ $# -gt 0 ] || mapfile -t files < <(git -C "$WEB" diff --name-only "$LAST" "$now" -- "${WEB_PATHS[@]}" | grep -vE "$WEB_EXCLUDE")
    fi
    [ $# -gt 0 ] || set -- "${files[@]}"
    [ $# -eq 0 ] || git -C "$repo" diff "$ref" "$now" -- "$@"
    ;;
  save)
    web="$(git -C "$WEB" commit-tree "$(current_tree "$WEB")" -p HEAD -m "UX web review snapshot")"
    git -C "$WEB" update-ref "$LAST" "$web"
    app="$(git -C "$APP" commit-tree "$(current_tree "$APP" "${APP_PATHS[@]}")" -p HEAD -m "UX web review snapshot of the app-side files")"
    git -C "$APP" update-ref "$APP_LAST" "$app"
    echo "Saved UX web review snapshots: website $(git -C "$WEB" rev-parse --short "$web"), app side $(git -C "$APP" rev-parse --short "$app")"
    ;;
  status)
    when "$WEB" "$LAST" "Last UX web review (website)"
    when "$APP" "$APP_LAST" "Last UX web review (app side)"
    when "$WEB" "$BASE" "Last fix-run base (website)"
    ;;
  base)
    commit="$(git -C "$WEB" commit-tree "$(current_tree "$WEB")" -p HEAD -m "UX web fix-run base")"
    git -C "$WEB" update-ref "$BASE" "$commit"
    echo "Saved the fix-run base $(git -C "$WEB" rev-parse --short "$commit"). Website files with uncommitted changes now:"
    git -C "$WEB" status --porcelain=v1 -uall | sed 's/^/  /'
    ;;
  ran)
    need "$WEB" "$BASE" NO_BASE 1
    git -C "$WEB" diff --name-only "$BASE" "$(current_tree "$WEB")"
    ;;
  diff)
    need "$WEB" "$BASE" NO_BASE 1
    shift
    if [ "${1:-}" = "--" ]; then shift; fi
    git -C "$WEB" diff "$BASE" "$(current_tree "$WEB")" -- "$@"
    ;;
  stage)
    need "$WEB" "$BASE" "NO_BASE: run 'ux-web.sh base' before a fix run, so its changes can be told apart." 1
    shift
    if [ "${1:-}" = "--" ]; then shift; fi
    [ $# -gt 0 ] || { echo "usage: ux-web.sh stage <path>..." >&2; exit 2; }
    now="$(current_tree "$WEB")"
    refused=0
    for p in "$@"; do
      b="$(blob "$BASE" "$p")"
      h="$(blob HEAD "$p")"
      c="$(blob "$now" "$p")"
      i="$(git -C "$WEB" ls-files -s -- "$p" | awk 'NR == 1 { print $2 }')"
      if [ "$i" != "$h" ] && [ "$b" = "$h" ] && [ "$i" = "$c" ]; then
        echo "already staged $p"
      elif [ "$i" != "$h" ]; then
        echo "REFUSED $p: the index already holds staged changes to it that aren't committed."
        refused=1
      elif [ "$b" = "$c" ]; then
        echo "unchanged $p: no change since the base."
      elif [ "$b" = "$h" ]; then
        git -C "$WEB" add -A -- "$p"
        echo "staged $p"
      elif [ -z "$h" ]; then
        echo "REFUSED $p: another session's uncommitted new file; the run's change can't be committed without theirs."
        refused=1
      elif git -C "$WEB" diff --binary "$BASE" "$now" -- "$p" | git -C "$WEB" apply --cached --check 2>/dev/null; then
        git -C "$WEB" diff --binary "$BASE" "$now" -- "$p" | git -C "$WEB" apply --cached
        echo "staged the run's hunks only: $p (another session's changes stay unstaged)"
      else
        echo "REFUSED $p: the run's changes touch lines another session changed and hasn't committed."
        refused=1
      fi
    done
    exit "$refused"
    ;;
  *)
    echo "usage: ux-web.sh changed|app|since [--app] [path...]|save|status|base|ran|diff [path...]|stage path..." >&2
    exit 2
    ;;
esac
