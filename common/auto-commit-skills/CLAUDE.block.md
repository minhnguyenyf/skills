<!-- auto-commit-skills:start -->
## Skills repo commit and push (~/.claude/skills)
- The auto-commit hooks in settings.json may not run in every session (for example the VS Code session). Claude commits and pushes skill changes itself.
- After any change under `~/.claude/skills/`, run `sh ~/.claude/hooks/commit-skills.sh <changed-file>` (or with no argument to sweep all changes), then check that `git -C ~/.claude/skills log origin/master --oneline -1` matches `git -C ~/.claude/skills log --oneline -1`.
- Never commit or push in project repos such as `~/workspace/peaks`.
- Read `common/important-rules` before any git operation.
<!-- auto-commit-skills:end -->
