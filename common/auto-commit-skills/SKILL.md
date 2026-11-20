# Auto-Commit Skills Folder

Commits and pushes changes under `~/.claude/skills/` to the checked-out branch (`origin/<branch>`; falls back to `master` when detached). Project repos (`/home/coder/workspace/peaks` and others) are never auto-committed.

## Start of every session (required)
1. Check both hooks and the script are installed. Expect `2` (PostToolUse and Stop) and `OK`:
   ```bash
   jq '[.hooks.PostToolUse[]?, .hooks.Stop[]?] | map(.hooks[]?.command) | map(select(contains("commit-skills.sh"))) | length' ~/.claude/settings.json
   test -x ~/.claude/hooks/commit-skills.sh && echo OK
   ```
   Anything else: run `bash ~/.claude/skills/common/auto-commit-skills/setup.sh` (needs `jq`; on this machine it is in `~/bin/jq.exe`, copied from winget `jqlang.jq`).
2. Check for uncommitted or unpushed skill changes:
   ```bash
   cd ~/.claude/skills && git status --short && git fetch -q origin && git log origin/$(git branch --show-current) --oneline -1 && git log --oneline -1
   ```
3. Check `~/.claude/skill-autocommit.log` for `FAILED` lines. The file appears only after the first commit by the hook, so its absence is not an error by itself.
4. Report the result to the user in one line before starting other work.

## How it works
| Hook | When | Commits |
|---|---|---|
| `PostToolUse` (`Edit\|Write`) | After Edit or Write under `~/.claude/skills/` | That file, `Update skill file: <name>` |
| `Stop` | End of each turn | All tracked and new changes except `synced/`, `Update skill files` |
| `UserPromptSubmit` | A prompt mentions `claude/skills/common` | Nothing. Runs `ensure-skills-setup.sh`, which runs `setup.sh` only if a hook or the script is missing |

- The Stop hook covers Bash edits (`cat >>`, `mv`, `rm`). Both hooks do nothing when there is nothing to commit or push.
- Each run commits what is staged, then, if HEAD is ahead of `origin/<branch>` (including older unpushed commits such as a revert), runs `pull --rebase --autostash` and pushes. On a rebase conflict the script aborts it; the commits stay local, the log shows `FAILED`, and the next run retries.
- Known: in the VS Code session the user-level hooks are not loaded (`/hooks` lists none). Claude runs `commit-skills.sh` by hand instead (rule block in `~/.claude/CLAUDE.md`). A session started in `peaks` also denies direct `git commit`/`git push` (`peaks/.claude/settings.local.json`), so push skill commits through `commit-skills.sh`, not `git push`.
- Project-scoped copy of the hooks: `~/.claude/skills/.claude/settings.json`. It loads only when Claude Code runs with `~/.claude/skills` as its working folder. Not yet verified.
- Log: `~/.claude/skill-autocommit.log` (`OK` or `FAILED` per run).

## Files
| File | Purpose |
|---|---|
| `commit-skills.sh` | Commit and push logic, POSIX `sh`. Copied to `~/.claude/hooks/`. |
| `ensure-skills-setup.sh` | UserPromptSubmit check: repairs missing hooks by running `setup.sh`. Copied to `~/.claude/hooks/`. |
| `setup.sh` | Copies the scripts, writes the three hooks into `~/.claude/settings.json` (keeps other settings), runs the checks once. Safe to re-run. |
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
- Not configured: no SessionStart pull. Pull by hand (`git -C ~/.claude/skills pull --ff-only`) before working on another device.
- If a push fails: `cd ~/.claude/skills && git push origin HEAD` by hand, read the error.
- Before switching devices, `git log origin/<branch> --oneline -1` must match local HEAD.

## Verification
Edit a skill file, end the turn, then `git -C ~/.claude/skills log --oneline -1` shows the new commit and `tail ~/.claude/skill-autocommit.log` shows `OK`.
