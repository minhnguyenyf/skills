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

### Preview Before Editing
- ✅ **Always show the change first** (file, old → new, or a diff) and wait for the user's go-ahead before editing any file in a project repo such as `/home/coder/workspace/peaks/`.
- Applies to every edit, including one-line fixes to XML, config, or headers. Standing preference set by the user; do not skip it because the change looks small.
- Once approved, make the edit and report what changed.

### Submodule Constraints
- ❌ **DO NOT modify**: `ra/arm/mbedtls-v4/` — read-only submodule
- ❌ **DO NOT modify**: `ra/arm/mbedtls-v4/tf-psa-crypto/` — read-only submodule
- ✅ **DO fix at project level**: e2 studio include paths, build configurations

### Read Restrictions
- ❌ **DO NOT read**: `ra/fsp/src/r_rsip_protected/`, `ra/fsp/src/r_sce_protected/` (including their `crypto_procedures` submodule contents), and any folder named `primitive` under `ra/fsp/src/r_sce/`. Set by the user; do not use `grep`, `find`, `git show`, or `Read` on these paths, even for a review.
- ✅ **`ra/fsp/src/r_sce/` is readable** except for folders named `primitive`. Other `r_sce` paths (for example `crypto_procedures/src/rsip_e51a/plainkey/...`) may be read and reviewed.
- ✅ Changes to these paths in a diff (`git diff develop...HEAD`) may be reported by file name and pointer SHA only. Say that the contents were not reviewed.
- If a review needs something from these paths, say so in the report and ask the user to check it.

### Personal Information
- ❌ **Never write** a personal name or a work email in any skill file. Use "the user" or "the author" instead. This repo is shared publicly.
- ✅ Ticket numbers (FSPRA-xxxx) and project names are fine to keep.

### Compact Skill Files
- ✅ Keep every skill file (`.md`) compact: status and knowledge only. Remove error logs, debugging narratives, resolved issues, and superseded notes. Full details stay in git history.
- Rule details and checklist: [knowledge-capture/SKILL.md](../knowledge-capture/SKILL.md) ("Keep skill files compact").

## When to Use This Skill

1. **Before any git commit/push** — verify you're not auto-committing to a work project
2. **When modifying build configuration** — check for submodule read-only constraints
3. **When adding external dependencies** — confirm permission boundaries
4. **When onboarding new tasks** — review policy files to avoid constraint violations

See the detailed policy files for complete information.
