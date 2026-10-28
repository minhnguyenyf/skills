# 🚨 CRITICAL: Claude Commit Policy

**Date Set**: 2026-10-01  
**User**: the user

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
5. **User commits MANUALLY** (the user will do this themselves)
6. **User pushes MANUALLY** (the user will do this themselves)

**CRITICAL**: Only the user manually commits and pushes to work project repos. Claude NEVER touches git commit/push for project work.

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

## Submodule Read-Only Constraint

### DO NOT modify these submodules:
- ❌ `ra/arm/mbedtls-v4/` - No write permissions
- ❌ `ra/arm/mbedtls-v4/tf-psa-crypto/` - No write permissions

These are external dependencies managed as git submodules. Any fixes or configurations must be done at the project level (e.g., include path configurations in e2 studio project settings), not by modifying submodule files.

**Related Issue**: TF-PSA-Crypto v4 requires include path `ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include` for `mbedtls/private_access.h` - this must be configured in e2 studio C/C++ compiler include paths, not by copying files into the submodule.

---

## Last Updated

- **2026-10-01**: Initial rule set after constraint fix incident
- User: the user
- Context: Fixed XML constraint but learned not to auto-commit to project repos
- **2026-10-01**: Added submodule read-only constraint
- Context: Cannot modify mbedtls-v4 and tf-psa-crypto submodules
