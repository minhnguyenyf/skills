#!/bin/sh
# Commit and push changes under ~/.claude/skills.
# Usage: commit-skills.sh [file]
#   file given  -> commit only that file (PostToolUse Edit/Write)
#   no argument -> commit every tracked change plus new files, except synced/ (Stop)
# Pushes to the checked-out branch (falls back to master when HEAD is detached). Also pushes local commits
# not yet on origin/<branch> (for example a manual commit or a revert).
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

# 2. Push if HEAD is ahead of origin/<branch>. A branch not yet on origin gets all its commits, and is created on push.
branch=$(git symbolic-ref --short -q HEAD || echo master)
if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
  ahead=$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)
else
  ahead=$(git rev-list --count HEAD 2>/dev/null || echo 0)
fi
[ "$ahead" -gt 0 ] || exit 0

# Pull and rebase on top of the remote branch before pushing, so a teammate's newer commit does not reject the push.
# If the rebase hits a conflict, abort it: the commits stay local, the log shows FAILED, and the next run retries.
# --autostash: in single-file mode other files may still have unstaged edits, which would block the rebase.
if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null \
  && ! git pull -q --rebase --autostash origin "$branch" >> "$LOG" 2>&1; then
  git rebase --abort >/dev/null 2>&1
  echo "$(date) FAILED $label on $branch (pull/rebase; resolve by hand)" >> "$LOG"
  exit 0
fi
if git push -q -u origin "HEAD:refs/heads/$branch" >> "$LOG" 2>&1; then
  echo "$(date) OK $label on $branch ($ahead commit(s) pushed)" >> "$LOG"
else
  echo "$(date) FAILED $label on $branch (push; resolve by hand)" >> "$LOG"
fi
exit 0
