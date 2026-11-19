# Claude Commit Policy

**Set:** 2026-10-01. Applies to all sessions.

## Rule
- **Auto-commit and push only to `~/.claude/skills/`** (hooks: see `common/auto-commit-skills/SKILL.md`).
- **Never auto-commit or push** to project or work repos, such as `/home/coder/workspace/peaks/`, customer code, or any repo outside `~/.claude/skills/`.
- For project repos: stage or edit, show the diff, and let the user commit and push. Claude does not run `git commit` or `git push` on project work.

## Emergency override
If the user explicitly asks to auto-commit to a non-skills repo: check the path, then confirm with the user first (for example, "This will commit to `~/workspace/peaks/`. Proceed?").

## Verification
```bash
pwd && git remote -v
# ~/.claude/skills/ -> OK to auto-commit
# anything else -> ask first
```
