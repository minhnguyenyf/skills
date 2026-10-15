#!/bin/bash
# Auto-Commit Skills Hook Setup
# Run this script on any device to enable auto-commit for ~/.claude/skills/
# Usage: bash setup.sh

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_NAME="auto-commit-skills"

echo "🔧 Setting up auto-commit for ~/.claude/skills/ folder..."

# Ensure settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating $SETTINGS_FILE..."
    echo '{}' > "$SETTINGS_FILE"
fi

# Check if hook already exists
if grep -q "auto-commit-skills" "$SETTINGS_FILE" 2>/dev/null; then
    echo "✅ Auto-commit hook already installed in $SETTINGS_FILE"
    exit 0
fi

# Create temporary hook configuration
HOOK_CONFIG=$(cat <<'EOF'
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // .tool_response.filePath' | { read -r f; if [[ \"$f\" == *\"/.claude/skills/\"* ]]; then cd \"${f%/*}\" && git add \"$f\" && git commit -m \"Update skill file: $(basename \"$f\")\" && git push origin master 2>/dev/null || true; fi; }",
            "statusMessage": "Committing and pushing skill changes..."
          }
        ]
      }
    ]
  },
EOF
)

# Merge hook into settings using jq
if command -v jq &> /dev/null; then
    # Use jq to merge (preserves existing settings)
    TEMP=$(mktemp)
    jq ".hooks //= {} | .hooks.PostToolUse //= [] | .hooks.PostToolUse += [
      {
        \"matcher\": \"Edit|Write\",
        \"hooks\": [
          {
            \"type\": \"command\",
            \"command\": \"jq -r '.tool_input.file_path // .tool_response.filePath' | { read -r f; if [[ \\\"$f\\\" == *\\\"/.claude/skills/\\\"* ]]; then cd \\\"${f%/*}\\\" && git add \\\"$f\\\" && git commit -m \\\"Update skill file: \$(basename \\\"$f\\\")\\\" && git push origin master 2>/dev/null || true; fi; }\",
            \"statusMessage\": \"Committing and pushing skill changes...\"
          }
        ]
      }
    ]" "$SETTINGS_FILE" > "$TEMP"
    mv "$TEMP" "$SETTINGS_FILE"
    echo "✅ Hook added to $SETTINGS_FILE"
else
    echo "⚠️  jq not found. Please manually add the following to $SETTINGS_FILE:"
    echo ""
    echo "Add this inside the root object:"
    echo "$HOOK_CONFIG"
    exit 1
fi

# Verify hook is in place
if grep -q "auto-commit-skills\|Update skill file" "$SETTINGS_FILE" 2>/dev/null; then
    echo "✅ Hook configuration verified"
else
    # Double-check with a pattern match
    if grep -q "PostToolUse" "$SETTINGS_FILE" 2>/dev/null; then
        echo "⚠️  Settings updated but hook verification inconclusive"
        echo "Please verify $SETTINGS_FILE contains the PostToolUse hook"
    fi
fi

echo ""
echo "📝 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit any file in ~/.claude/skills/"
echo "2. Check: cd ~/.claude/skills && git log --oneline -1"
echo "3. You should see: 'Update skill file: <filename>'"
echo ""
echo "For details, see: ~/.claude/skills/auto-commit-skills/SKILL.md"
