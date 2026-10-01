# 🚨 CRITICAL: Claude Commit Policy

**Date Set**: 2026-10-01  
**User**: Minh Nguyen (minh.nguyen.yf@renesas.com)

---

## ⚠️ THE RULE

### ONLY auto-commit and push to: `~/.claude/skills/`

### DO NOT auto-commit to:
- ❌ Project repositories (e.g., `/home/coder/workspace/peaks/`)
- ❌ Work repositories
- ❌ Customer/client codebases
- ❌ Any repository NOT in `~/.claude/skills/`

---

## Workflow for Non-Skills Repositories

### For Project Repos (peaks, etc.):
1. **Stage changes** (git add)
2. **Show diff** to user
3. **NEVER commit** ❌
4. **NEVER push** ❌
5. **User commits MANUALLY** (Minh will do this themselves)
6. **User pushes MANUALLY** (Minh will do this themselves)

**CRITICAL**: Only Minh manually commits and pushes to work project repos. Claude NEVER touches git commit/push for project work.

### For Skills Repos (`~/.claude/skills/`):
1. **Stage changes**
2. **Commit automatically** ✅
3. **Push automatically** ✅
4. **Report success**

---

## Why This Matters

- **Project repos**: May have review processes, CI/CD pipelines, team workflows
- **Skills repos**: Personal automation, safe to auto-commit
- **Auto-committing project work**: Violates team processes, bypasses code review, creates misleading commit history

---

## Verification

**To verify this is working:**

```bash
# Check what repo you're in
pwd
git remote -v

# If in ~/.claude/skills/ → OK to auto-commit
# If in ~/workspace/peaks or other project → MUST ASK FIRST
```

---

## Examples

### ✅ CORRECT: Auto-commit to skills

```
User: "Update the budget-optimization skill"
Claude: *edits /home/coder/.claude/skills/budget-optimization/README.md*
Claude: *auto-commits & pushes to ~/.claude/skills/*
Claude: "✅ Skill updated and synced!"
```

### ❌ WRONG: Auto-commit to project repo

```
User: "Fix line 3389 in the TF-PSA-Crypto module"
Claude: *edits ra/arm/.module_descriptions/...xml*
Claude: *STAGES changes but does NOT commit*
Claude: "✅ Fix staged. Ready for you to commit when approved."
```

---

## Emergency Override

If user explicitly says: "Auto-commit this to [any repo]"
- Still check the repo path
- If NOT ~/.claude/skills/, confirm with user first
- Example: "This will commit to `~/workspace/peaks/`. Proceed? (y/n)"

---

## Remembered By

- All Claude Code sessions from: 2026-10-01 onwards
- Rule enforced across all skills and workflows
- This file serves as permanent documentation

---

## Last Updated

- **2026-10-01**: Initial rule set after constraint fix incident
- User: Minh Nguyen
- Context: Fixed XML constraint but learned not to auto-commit to project repos
