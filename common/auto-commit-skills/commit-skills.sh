#!/bin/sh
# Commit and push changes under ~/.claude/skills.
# Usage: commit-skills.sh [file]
#   file given  -> commit only that file (PostToolUse Edit/Write)
#   no argument -> commit every tracked change plus new files, except synced/ (Stop)
# Does nothing when there is nothing staged, so it is safe to run on every turn.

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

if git diff --cached --quiet; then
  exit 0
fi

if [ -n "$f" ]; then
  msg="Update skill file: $(basename "$f")"
  label="$f"
else
  msg="Update skill files"
  label="sweep"
fi

if git commit -q -m "$msg" && git push -q origin master >> "$LOG" 2>&1; then
  echo "$(date) OK $label" >> "$LOG"
else
  echo "$(date) FAILED $label" >> "$LOG"
fi
exit 0
