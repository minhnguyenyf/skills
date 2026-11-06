#!/bin/bash
# Auto-commit setup for ~/.claude/skills/
# Installs commit-skills.sh into ~/.claude/hooks and wires two hooks into ~/.claude/settings.json:
#   PostToolUse (Edit|Write) -> commit and push the edited skill file
#   Stop                     -> commit and push any other skill changes (Bash edits, mv, rm)
#   UserPromptSubmit         -> when a prompt mentions claude/skills/common, install these hooks if missing
# Safe to re-run: old auto-commit entries are replaced, not duplicated.
# Usage: bash ~/.claude/skills/common/auto-commit-skills/setup.sh

set -e

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
HOOK_SCRIPT="$HOOK_DIR/commit-skills.sh"
ENSURE_SCRIPT="$HOOK_DIR/ensure-skills-setup.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "jq is required (install it first, e.g. sudo apt install jq)"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required"; exit 1; }

if [ ! -d "$HOME/.claude/skills/.git" ]; then
    echo "~/.claude/skills is not a git repository. Clone the skills repo there first."
    exit 1
fi

echo "Installing hook script to $HOOK_SCRIPT"
mkdir -p "$HOOK_DIR"
cp "$SRC_DIR/commit-skills.sh" "$HOOK_SCRIPT"
cp "$SRC_DIR/ensure-skills-setup.sh" "$ENSURE_SCRIPT"
chmod +x "$HOOK_SCRIPT" "$ENSURE_SCRIPT"

[ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"

POST_CMD='f=$(jq -r '"'"'.tool_input.file_path // .tool_response.filePath // empty'"'"'); [ -n "$f" ] && sh "$HOME/.claude/hooks/commit-skills.sh" "$f"; exit 0'
STOP_CMD='sh "$HOME/.claude/hooks/commit-skills.sh"'
ENSURE_CMD='sh "$HOME/.claude/hooks/ensure-skills-setup.sh"'

TEMP=$(mktemp)
# Drop any earlier auto-commit entries (match on the script name or the old inline message), then add the current ones.
jq --arg post "$POST_CMD" --arg stop "$STOP_CMD" --arg ensure "$ENSURE_CMD" '
  def is_autocommit: any(.hooks[]?; (.command // "") | (contains("commit-skills.sh") or contains("ensure-skills-setup.sh") or contains("Update skill file")));
  .hooks //= {} |
  .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(is_autocommit | not))) + [
    {matcher: "Edit|Write", hooks: [{type: "command", command: $post, statusMessage: "Committing and pushing skill changes..."}]}
  ] |
  .hooks.Stop = ((.hooks.Stop // []) | map(select(is_autocommit | not))) + [
    {hooks: [{type: "command", command: $stop, statusMessage: "Committing any skill changes..."}]}
  ] |
  .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) | map(select(is_autocommit | not))) + [
    {hooks: [{type: "command", command: $ensure, statusMessage: "Checking skill auto-commit hooks..."}]}
  ]
' "$SETTINGS_FILE" > "$TEMP"
mv "$TEMP" "$SETTINGS_FILE"

echo "Hooks written to $SETTINGS_FILE"

# Quick check: the PostToolUse command must extract the path and run the script without errors.
echo '{"tool_input":{"file_path":"'"$HOME"'/.claude/skills/README.md"}}' | sh -c "$POST_CMD" && echo "PostToolUse check passed"
sh "$HOOK_SCRIPT" && echo "Stop check passed"

cat <<EOF

Setup complete.
- Log: $HOME/.claude/skill-autocommit.log
- Verify after an edit: cd ~/.claude/skills && git log --oneline -1
- Restart Claude Code or review /hooks if the hooks do not run in the current session.
EOF
