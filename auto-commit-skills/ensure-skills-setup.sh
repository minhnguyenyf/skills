#!/bin/sh
# UserPromptSubmit hook: when a prompt mentions claude/skills/common, make sure the
# auto-commit hooks are installed. Runs setup.sh only if something is missing.
# Idempotent and never blocks the prompt: always exits 0. Its output is shown to Claude.
# Installed and wired by setup.sh (command: sh "$HOME/.claude/hooks/ensure-skills-setup.sh").

SETTINGS="$HOME/.claude/settings.json"
HOOK="$HOME/.claude/hooks/commit-skills.sh"
SETUP="$HOME/.claude/skills/common/auto-commit-skills/setup.sh"
LOG="$HOME/.claude/skill-autocommit.log"

input=$(cat)

command -v jq >/dev/null 2>&1 || { echo "ensure-skills-setup: jq not found, auto-setup skipped. Install jq and run setup.sh."; exit 0; }

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
case "$prompt" in
  *claude/skills/common*) ;;
  *) exit 0 ;;
esac

count=$(jq '[.hooks.PostToolUse[]?, .hooks.Stop[]?] | map(.hooks[]?.command) | map(select(contains("commit-skills.sh"))) | length' "$SETTINGS" 2>/dev/null)
if [ "$count" = "2" ] && [ -x "$HOOK" ]; then
  echo "auto-commit hooks: OK"
  exit 0
fi

if [ ! -f "$SETUP" ]; then
  echo "auto-commit setup missing. Clone the skills repo to ~/.claude/skills first."
  exit 0
fi

if bash "$SETUP" >> "$LOG" 2>&1; then
  echo "auto-commit hooks were missing and are now installed. Restart Claude Code to load them."
else
  echo "auto-commit setup failed. See $LOG, then run setup.sh by hand."
fi
exit 0
