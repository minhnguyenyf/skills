# Auto-Commit Skills Folder

Automatically commit and push changes to skill files whenever you edit or create them in `~/.claude/skills/`.

## What it does

When you edit or create any file in `~/.claude/skills/`:
1. The file is automatically staged with `git add`
2. A commit is created with message: `"Update skill file: <filename>"`
3. Changes are pushed to `origin/master`

## Installation

The hook is configured in `~/.claude/settings.json` under the `PostToolUse` event:

```json
{
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
  }
}
```

## How to set up on a new device

Run this command to apply the hook to any new machine:

```bash
# Ensure ~/.claude/settings.json exists
touch ~/.claude/settings.json

# Merge the hook into settings (or manually add the PostToolUse hook block above)
# The hook will automatically fire on the next Edit/Write to ~/.claude/skills/*
```

## Verification

To verify the hook is working:

1. Edit any file in `~/.claude/skills/`
2. Check git log: `cd ~/.claude/skills && git log --oneline -1`
3. You should see your commit message: `"Update skill file: <filename>"`
4. Verify push: `git log origin/master --oneline -1` (should match local)

## Technical Details

- **Trigger**: `PostToolUse` event after `Edit` or `Write` tools complete
- **Command type**: bash via `jq` to extract file path from hook input JSON
- **Path filter**: Only triggers for files with `/.claude/skills/` in their path
- **Safety**: Errors are silenced (`2>/dev/null || true`) to avoid blocking turns
- **Message format**: `"Update skill file: <filename>"` for clarity in commit history

## Tested

✅ Path matching works  
✅ Git add succeeds  
✅ Commit creation works  
✅ Push to origin/master works  

## Notes

- The hook runs silently (won't show output unless it errors)
- Works on any device with git, bash, and jq installed
- Requires `~/.claude/skills/` to be a git repository (initialized automatically by Claude Code)
- The `|| true` at the end ensures the hook never blocks a turn if push fails

## ⚠️ CRITICAL: Always Push-Pull (DO NOT FORGET)

**This is a STRICT rule for maintaining skill sync across devices:**

1. **PostToolUse Hook (Auto-Push)** — Every skill edit triggers auto-commit & push to GitHub
   - If push fails, manually verify: `cd ~/.claude/skills && git push origin master`
   - Never let failed pushes go unnoticed

2. **SessionStart Hook (Auto-Pull)** — Every new session pulls latest skills from GitHub
   - Ensures you always have the latest skills on every device
   - If skills are out of sync, the entire system breaks

3. **Golden Rule** — Before switching to another device, verify the push succeeded on GitHub
   - Check: `git log origin/master --oneline -1` (should match your local HEAD)
   - If out of sync, manually pull: `git pull origin master`

## See Also

- Claude Code settings reference: `~/.claude/settings.json`
- Git hooks documentation in PostToolUse section
