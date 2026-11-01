# Auto-Commit Skills Folder

Commits and pushes changes under `~/.claude/skills/` to `origin/master`. Project repos (`/home/coder/workspace/peaks` and others) are never auto-committed.

## Start of every session
1. Check the hooks are installed:
   ```bash
   jq -r '.hooks.PostToolUse[] | select(any(.hooks[]?; (.command // "") | contains("commit-skills.sh"))) | .hooks[0].command' ~/.claude/settings.json
   ```
   Empty output: run `bash ~/.claude/skills/common/auto-commit-skills/setup.sh`.
2. Check for uncommitted or unpushed skill changes:
   ```bash
   cd ~/.claude/skills && git status --short && git log origin/master --oneline -1 && git log --oneline -1
   ```
3. Check `~/.claude/skill-autocommit.log` for `FAILED` lines.

## How it works
| Hook | When | Commits |
|---|---|---|
| `PostToolUse` (`Edit\|Write`) | After Edit or Write under `~/.claude/skills/` | That file, `Update skill file: <name>` |
| `Stop` | End of each turn | All tracked and new changes except `synced/`, `Update skill files` |

- The Stop hook covers Bash edits (`cat >>`, `mv`, `rm`). Both hooks do nothing when nothing is staged.
- Each run commits, then `pull --rebase` on `origin/master`, then pushes. On a rebase conflict the script aborts it; the commit stays local and the log shows `FAILED`.
- Log: `~/.claude/skill-autocommit.log` (`OK` or `FAILED` per run).

## Files
| File | Purpose |
|---|---|
| `commit-skills.sh` | Commit and push logic, POSIX `sh`. Copied to `~/.claude/hooks/`. |
| `setup.sh` | Copies the script, writes both hooks into `~/.claude/settings.json` (keeps other settings), runs both once. Safe to re-run. |
| `README.md` | Quick start for a new device. |

## Setup on a new device
Prerequisites: `git`, `jq`, SSH access, `~/.claude/skills/` cloned.
```bash
git clone <skills repo URL> ~/.claude/skills        # skip if present
bash ~/.claude/skills/common/auto-commit-skills/setup.sh
```
Hooks are per device (`~/.claude/settings.json`). Skill files sync through git.

## Rules
- Hooks run under `sh` (dash). Use `[ ]` or `case`, not `[[ ]]`.
- Remote: `origin` is `git@github.com:minhnguyenyf/skills.git`. Update the old URL on each device: `git -C ~/.claude/skills remote set-url origin git@github.com:minhnguyenyf/skills.git`.
- Not configured: no SessionStart pull. Pull by hand (`git -C ~/.claude/skills pull --ff-only origin master`) before working on another device.
- If a push fails: `cd ~/.claude/skills && git push origin master` by hand, read the error.
- Before switching devices, `git log origin/master --oneline -1` must match local HEAD.

## Verification
Edit a skill file, end the turn, then `git -C ~/.claude/skills log --oneline -1` shows the new commit and `tail ~/.claude/skill-autocommit.log` shows `OK`.
