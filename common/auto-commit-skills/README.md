# Auto-Commit Skills

Commit and push changes in `~/.claude/skills/` automatically. Full details are in [SKILL.md](SKILL.md).

## Set up a new device

Needs `git`, `jq`, and SSH access to the skills repo.

```bash
git clone git@github.com:minhnguyenyf/skills.git ~/.claude/skills    # skip if already cloned
bash ~/.claude/skills/common/auto-commit-skills/setup.sh
```

Setup copies `commit-skills.sh` to `~/.claude/hooks/` and adds two hooks to `~/.claude/settings.json`:
- **PostToolUse** (Edit or Write): commits and pushes the edited skill file.
- **Stop** (end of each turn): commits and pushes any other skill changes, including Bash edits.

Setup is safe to re-run. It replaces the old hook entries rather than adding duplicates.

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
| `setup.sh` | Installs the script and the hooks |
| `SKILL.md` | Technical details, known problems, and rules |
