#!/bin/sh
# Commit and push changes under ~/.claude/skills.
# Usage: commit-skills.sh [file]
#   file given  -> commit only that file (PostToolUse Edit/Write)
#   no argument -> commit every tracked change plus new files, except synced/ (Stop)
# Also pushes local commits that are not on origin/master yet (for example a manual commit or a revert).
# Does nothing when there is nothing to commit or push, so it is safe to run on every turn.

REPO="$HOME/.claude/skills"
LOG="$HOME/.claude/skill-autocommit.log"
f="$1"

cd "$REPO" || exit 0

if [ -n "$f" ]; then
  case "$f" in
    "$REPO"/*) git add -- "$f" 2>/dev/null || exit 0 ;;
    *) exit 0 ;;
  esac
else
  git add -u
  git ls-files --others --exclude-standard -- . ':!synced' | xargs -r git add --
fi

if [ -n "$f" ]; then
  msg="Update skill file: $(basename "$f")"
  label="$f"
else
  msg="Update skill files"
  label="sweep"
fi

# 1. Commit whatever is staged.
if ! git diff --cached --quiet; then
  if ! git commit -q -m "$msg" >> "$LOG" 2>&1; then
    echo "$(date) FAILED $label (commit)" >> "$LOG"
    exit 0
  fi
else
  label="pending"
fi

# 2. Push if HEAD is ahead of the last known origin/master. No network call when there is nothing to push.
ahead=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo 0)
[ "$ahead" -gt 0 ] || exit 0

# Pull and rebase on top of the remote before pushing, so a teammate's newer commit does not reject the push.
# If the rebase hits a conflict, abort it: the commits stay local, the log shows FAILED, and the next run retries.
if git pull -q --rebase origin master >> "$LOG" 2>&1 \
  && git push -q origin master >> "$LOG" 2>&1; then
  echo "$(date) OK $label ($ahead commit(s) pushed)" >> "$LOG"
else
  git rebase --abort >/dev/null 2>&1
  echo "$(date) FAILED $label (pull/rebase/push; resolve by hand)" >> "$LOG"
fi
exit 0
