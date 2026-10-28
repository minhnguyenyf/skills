# Auto-Commit Skills Folder

Commit and push changes under `~/.claude/skills/` automatically, so skill edits reach `origin/master` without manual git commands.

## FIRST THING IN EVERY NEW SESSION

1. Check that the hook command is installed and runs:
   ```bash
   jq -r '.hooks.PostToolUse[] | select(any(.hooks[]?; (.command // "") | contains("commit-skills.sh"))) | .hooks[0].command' ~/.claude/settings.json
   ```
   If this prints nothing, run `bash ~/.claude/skills/common/auto-commit-skills/setup.sh`.
2. Check for skill changes that were not committed or pushed:
   ```bash
   cd ~/.claude/skills && git status --short && git log origin/master --oneline -1 && git log --oneline -1
   ```
   If anything is uncommitted or unpushed, the Stop hook will commit it at the end of the turn. Check the log at `~/.claude/skill-autocommit.log` for `FAILED` lines.
3. Report the result in one line, then start the task.

## What it does

Two hooks run `~/.claude/hooks/commit-skills.sh`:

| Hook | When | What it commits |
|---|---|---|
| `PostToolUse` (matcher `Edit\|Write`) | After an Edit or Write to a file under `~/.claude/skills/` | Only that file, message `Update skill file: <name>` |
| `Stop` | When Claude finishes a turn | Every tracked change plus new files, except `synced/`, message `Update skill files` |

The Stop hook catches changes the PostToolUse hook misses: Bash commands (`cat >>`, `mv`, `rm`) and edits made outside Edit or Write. Both hooks do nothing when nothing is staged, so repeated runs are safe.

Each run commits, then pulls and rebases on `origin/master`, then pushes. This avoids rejected pushes when a teammate has pushed first. If the rebase hits a conflict, the script aborts it. The commit stays local, and the log shows `FAILED` so you can resolve it by hand.

Successes and failures are appended to `~/.claude/skill-autocommit.log`.

## Files

| File | Purpose |
|---|---|
| `commit-skills.sh` | The commit and push logic (POSIX `sh`). Copied to `~/.claude/hooks/` by setup. |
| `setup.sh` | Copies the script and writes both hooks into `~/.claude/settings.json`. Safe to re-run. |
| `README.md` | Quick start for a new device. |

## Setup on a new device

Prerequisites: `git`, `jq`, SSH access to the skills repo, and `~/.claude/skills/` cloned as a git repo.

```bash
git clone <skills repo URL> ~/.claude/skills        # skip if already present
bash ~/.claude/skills/common/auto-commit-skills/setup.sh
```

`setup.sh` does the following:
1. Copies `commit-skills.sh` to `~/.claude/hooks/` and makes it executable.
2. Replaces any earlier auto-commit entries in `~/.claude/settings.json`, then adds the `PostToolUse` and `Stop` hooks. Other settings are kept.
3. Runs both commands once to check them.

The resulting `settings.json` entries:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty'); [ -n \"$f\" ] && sh \"$HOME/.claude/hooks/commit-skills.sh\" \"$f\"; exit 0",
            "statusMessage": "Committing and pushing skill changes..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh \"$HOME/.claude/hooks/commit-skills.sh\"",
            "statusMessage": "Committing any skill changes..."
          }
        ]
      }
    ]
  }
}
```

Hooks are per device, since they live in `~/.claude/settings.json`. The skill files sync through git.

## Verification

1. Edit a file in `~/.claude/skills/` with the Edit tool, or make a Bash change and end the turn.
2. `cd ~/.claude/skills && git log --oneline -1` should show the new commit.
3. `git log origin/master --oneline -1` should match.
4. `tail ~/.claude/skill-autocommit.log` should show `OK`.

## Known problems fixed

- **`[[ ]]` in the hook**: the old command used bash-only `[[ ]]`. Claude Code runs hooks under `sh` (dash), so the test failed and skill edits were not committed. The current command uses `case` or `[ ]` only.
- **Silent failures**: the old command hid errors with `|| true`. The script now writes `FAILED` to the log.
- **Empty commits**: the old command failed with `nothing to commit` when a file had no changes. The script exits early when nothing is staged.
- **Bash edits not captured**: the old matcher covered only Edit and Write. The Stop hook closes this gap.
- **Repo moved**: the skills repo moved to `github.com/minhnguyenyf/skills`. The old `claude-skill-sync` URL still redirects, but update `origin` on each device: `git -C ~/.claude/skills remote set-url origin git@github.com:minhnguyenyf/skills.git`.

## Not configured

- **SessionStart pull**: skills are not pulled from GitHub at session start. Pull by hand with `git -C ~/.claude/skills pull --ff-only origin master` before working on another device.

## Rules

- Project repos under `/home/coder/workspace/peaks` are never auto-committed. Only `~/.claude/skills` is.
- If a push fails, run `cd ~/.claude/skills && git push origin master` by hand and check the error.
- Before switching devices, confirm the push succeeded: `git log origin/master --oneline -1` should match the local HEAD.
