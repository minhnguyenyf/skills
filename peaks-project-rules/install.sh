#!/bin/bash
# Install local-only Claude Code rules for the peaks repo on this device.
# Writes CLAUDE.local.md and .claude/settings.local.json, and hides both from git
# via .git/info/exclude (never committed). Safe to re-run.
# Usage: bash ~/.claude/skills/common/peaks-project-rules/install.sh [repo_path]

set -e

REPO="${1:-$HOME/workspace/peaks}"

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
[ -d "$REPO/.git" ] || { echo "$REPO is not a git repository"; exit 1; }

cd "$REPO"

# 1. Local instructions
cat > CLAUDE.local.md <<'EOF'
# Local rules (not committed)

## Git
- Claude does not run `git commit` or `git push` in this repo. Stage or edit, show the diff, and let the user commit and push.

## Preview before editing
- Show the change (file, old -> new, or a diff) and wait for approval before editing any file in this repo.

## Read-only submodules (do not modify)
- `ra/arm/mbedtls-v4/` and `ra/arm/mbedtls-v4/tf-psa-crypto/`: external. If a change there seems required, report it as a blocking issue and ask the user.
- Fix missing includes and build flags at project level (e2 studio settings), not in the submodule.
  Known case: add `${workspace_loc:/${ProjName}/ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include}` to GNU ARM Cross C Compiler > Includes.

## Read restrictions
- Do not read, grep, find, or `git show` these paths: `ra/fsp/src/r_rsip_protected/`, `ra/fsp/src/r_sce_protected/` (including `crypto_procedures` contents), and any `primitive/` folder under `ra/fsp/src/r_sce/`.
- Other `ra/fsp/src/r_sce/` paths are readable. For changes in restricted paths, report the file name and pointer SHA only, and say the contents were not reviewed.
EOF

# 2. Local permissions (merge with any existing settings.local.json)
mkdir -p .claude
SETTINGS=".claude/settings.local.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
TEMP=$(mktemp)
jq '
  .permissions //= {} |
  .permissions.deny = (((.permissions.deny // []) + [
    "Read(./ra/fsp/src/r_rsip_protected/**)",
    "Read(./ra/fsp/src/r_sce_protected/**)",
    "Read(./ra/fsp/src/r_sce/**/primitive/**)",
    "Edit(./ra/arm/mbedtls-v4/**)",
    "Write(./ra/arm/mbedtls-v4/**)",
    "Bash(git commit:*)",
    "Bash(git push:*)"
  ]) | unique)
' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"

# 3. Keep local files out of git
EXCLUDE=".git/info/exclude"
for p in "CLAUDE.local.md" ".claude/settings.local.json"; do
  grep -qxF "$p" "$EXCLUDE" 2>/dev/null || echo "$p" >> "$EXCLUDE"
done

echo "Installed peaks local rules in $REPO"
echo "- CLAUDE.local.md"
echo "- .claude/settings.local.json (deny rules)"
echo "- Excluded from git via .git/info/exclude"
echo "Restart Claude Code in this repo so the rules load."
