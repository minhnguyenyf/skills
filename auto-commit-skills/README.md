# 🚀 Auto-Commit Skills

**Automatically commit and push skill folder changes across all devices and sessions.**

---

## 🤖 STANDING INSTRUCTION FOR CLAUDE

**Every time you pull updated skills (SessionStart hook or manual `git pull`):**
1. ✅ **Read the changed files** — Check what was updated
2. ✅ **Review commit messages** — Understand why changes were made
3. ✅ **Learn new patterns** — Integrate updates into your knowledge
4. ✅ **Never use stale skills** — Always verify freshness

**Never assume skills haven't changed. Always check and read.**

---

## Overview

This skill folder setup ensures that whenever you edit or create any file in `~/.claude/skills/`, the changes are automatically:
1. ✅ Staged with `git add`
2. ✅ Committed with a descriptive message
3. ✅ Pushed to `origin/master`

This means your skills are synchronized across all machines without manual git commands.

## Installation

### Option 1: Automatic Setup (Recommended)

Run the setup script:

```bash
bash ~/.claude/skills/auto-commit-skills/setup.sh
```

This will automatically add the hook to your `~/.claude/settings.json`.

### Option 2: Manual Setup

1. Open `~/.claude/settings.json`
2. Add or merge this hook configuration:

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
    ],
    "SessionStart": [
      {
        "type": "command",
        "command": "cd ~/.claude/skills && git pull origin master 2>/dev/null || true",
        "statusMessage": "Syncing skills from GitHub..."
      }
    ]
  }
}
```

## How It Works

### The Hook Trigger
- **Event**: `PostToolUse` — fires after any Edit or Write tool completes
- **Matcher**: `Edit|Write` — only triggers for file edits/creates
- **Scope**: Only files in `~/.claude/skills/` are affected

### The Command Breakdown

**Auto-Push (PostToolUse):**
```bash
jq -r '.tool_input.file_path // .tool_response.filePath' | { 
  read -r f
  if [[ "$f" == *"/.claude/skills/"* ]]; then
    cd "${f%/*}"                        # cd to the file's directory
    git add "$f"                        # stage the file
    git commit -m "Update skill file: $(basename "$f")"  # create commit
    git push origin master 2>/dev/null || true  # push (silent on error)
  fi
}
```

**Auto-Pull (SessionStart):**
```bash
cd ~/.claude/skills && git pull origin master 2>/dev/null || true
```

## Testing & Verification

### Test 1: Verify Hook is Installed
Check your settings file:
```bash
grep -A 10 "PostToolUse" ~/.claude/settings.json
```

### Test 2: Create a Test File
Edit or create any file in `~/.claude/skills/`, e.g.:
```bash
echo "test content" > ~/.claude/skills/test-file.txt
```

### Test 3: Verify Commit
```bash
cd ~/.claude/skills
git log --oneline -1
```

You should see: `Update skill file: test-file.txt`

### Test 4: Verify Push
```bash
cd ~/.claude/skills
git log origin/master --oneline -1
```

Should match your local commit.

## Multi-Device Sync

Since the hook is stored in `~/.claude/settings.json` (which is per-device):

1. **Device A**: Run `bash ~/.claude/skills/auto-commit-skills/setup.sh`
2. **Device B**: Run the same setup script
3. **Result**: Both devices will auto-commit/push skill changes

The skill files themselves sync via git (stored in `~/.claude/skills/.git`), so:
- Changes made on Device A are pushed automatically
- Device B can `git pull` to fetch them
- Or rely on the auto-push from this hook

## Files in This Skill

| File | Purpose |
|------|---------|
| `SKILL.md` | Detailed technical documentation |
| `setup.sh` | Automated installation script |
| `README.md` | This overview and quick-start guide |

## Troubleshooting

### Hook not triggering?
- Verify the hook is in `~/.claude/settings.json` using: `grep PostToolUse ~/.claude/settings.json`
- Ensure you're editing files with the `Edit` or `Write` tools (not command-line `nano` or `vim`)
- Check that the file path contains `/.claude/skills/`

### Git push failing?
- This is intentional—errors are silenced to avoid blocking turns
- Check manually: `cd ~/.claude/skills && git push origin master`
- Verify your SSH key or git credentials are configured

### Duplicate hooks?
- If you ran the setup multiple times, you might have duplicates
- Fix by manually editing `~/.claude/settings.json` to have only one `PostToolUse` hook block

## Safety & Performance

✅ **Safe**: The hook silences errors (`|| true`) so push failures won't block your work  
✅ **Efficient**: Only runs on skills folder files  
✅ **Non-blocking**: Errors are suppressed; the turn continues regardless  
✅ **Scoped**: Only files matching `*/.claude/skills/*` trigger the hook  

## See Also

- [Claude Code Settings Documentation](https://claude.com/docs/claude-code/settings)
- [PostToolUse Hooks Guide](https://claude.com/docs/claude-code/hooks#posttooluse)
- Git documentation: https://git-scm.com/

## Questions?

See `SKILL.md` for more technical details.
