---
name: important-rules
description: Project-critical constraints and policies. Use PROACTIVELY to understand: (1) commit/push policies for different repository types, (2) read-only submodule constraints, (3) permission boundaries. Read this before any git operations, file modifications to external dependencies, or build configuration work.
---

# Important Rules & Project Constraints

This skill documents critical constraints and policies for working on this project.

## Key Files
- [CLAUDE-COMMIT-POLICY.md](CLAUDE-COMMIT-POLICY.md) — Git commit/push policies by repository type
- [SUBMODULE-CONSTRAINTS.md](SUBMODULE-CONSTRAINTS.md) — Read-only submodules and configuration guidelines

## Quick Reference

### Git Operations
- ✅ **Auto-commit to**: `~/.claude/skills/` only
- ❌ **Never auto-commit to**: `/home/coder/workspace/peaks/` or any work project
- **For project repos**: Stage changes, show diff, let user commit manually

### Submodule Constraints
- ❌ **DO NOT modify**: `ra/arm/mbedtls-v4/` — read-only submodule
- ❌ **DO NOT modify**: `ra/arm/mbedtls-v4/tf-psa-crypto/` — read-only submodule
- ✅ **DO fix at project level**: e2 studio include paths, build configurations

## When to Use This Skill

1. **Before any git commit/push** — verify you're not auto-committing to a work project
2. **When modifying build configuration** — check for submodule read-only constraints
3. **When adding external dependencies** — confirm permission boundaries
4. **When onboarding new tasks** — review policy files to avoid constraint violations

See the detailed policy files for complete information.
