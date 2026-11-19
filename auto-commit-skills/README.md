# Auto-Commit Skills

Commit and push changes in `~/.claude/skills/` automatically. Full details are in [SKILL.md](SKILL.md).

## Set up a new device

Needs `git`, `jq`, and access to the skills repo (SSH, or HTTPS with a GitHub login). On Windows, install `jq` with `winget install jqlang.jq`, then make sure `jq.exe` is on the Git Bash PATH.

```bash
git clone git@github.com:minhnguyenyf/skills.git ~/.claude/skills    # or the https:// URL; skip if already cloned
bash ~/.claude/skills/common/auto-commit-skills/setup.sh
```

Setup copies `commit-skills.sh` and `ensure-skills-setup.sh` to `~/.claude/hooks/` and writes three hooks to `~/.claude/settings.json`:
- **PostToolUse** (Edit or Write): commits and pushes the edited skill file.
- **Stop** (end of each turn): commits and pushes any other skill changes, including Bash edits.
- **UserPromptSubmit** (a prompt mentions `claude/skills/common`): runs `ensure-skills-setup.sh`, which reruns `setup.sh` only if a hook or the script is missing.

Setup is safe to re-run. It replaces the old auto-commit hook entries rather than adding duplicates, and it leaves other settings alone. Restart Claude Code afterwards so the hooks load.

## Check it works

```bash
cd ~/.claude/skills && git log --oneline -1          # latest commit
git log origin/master --oneline -1                   # should match
tail ~/.claude/skill-autocommit.log                  # OK or FAILED lines
```

If the hooks do not run in the current session, restart Claude Code or review them with `/hooks`.

## Files

| File | Purpose |
|---|---|
| `commit-skills.sh` | Commit and push logic (POSIX `sh`) |
| `ensure-skills-setup.sh` | UserPromptSubmit check that repairs missing hooks |
| `setup.sh` | Installs the scripts and the hooks |
| `SKILL.md` | Technical details, known problems, and rules |
