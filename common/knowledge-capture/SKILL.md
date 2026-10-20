---
name: knowledge-capture
description: Rule for saving what you learn about MCUboot, mbedTLS v3/v4, or TF-PSA-Crypto into the matching skill folder, so future sessions don't re-investigate. Use whenever you read source, debug, or verify something about these libraries in this repo.
metadata:
  type: feedback
---

# Knowledge capture for MCUboot and mbedTLS work

When you look into MCUboot, mbedTLS v3, mbedTLS v4, or TF-PSA-Crypto in this repo, write what you learned to the matching skill folder in the same turn. Don't leave it for a summary at the end.

## Where to write

| Topic | Folder |
|---|---|
| MCUboot port, RSIP or SCE9 protected mode, flash map, OSPI or QSPI, key install | `~/.claude/skills/mcuboot/` (use an existing skill folder, or create `mcuboot/<topic>/SKILL.md`) |
| mbedTLS v3 to v4 diffs, TF-PSA-Crypto, PSA storage, littlefs | `~/.claude/skills/psa/` (use `mbedtls-v4-migration-notes/` or create `psa/<topic>/SKILL.md`) |
| Repo-wide rules, commit policy, tooling | `~/.claude/skills/common/` |

Check the folder for an existing note on the topic before you write a new one. Update that note instead of making a duplicate.

## What to record

- The fact, in one or two lines, and where it was verified (file path and line).
- Which configuration or build it applies to (device, board, project, toolchain).
- Dead ends you ruled out, with the reason, so nobody repeats them.
- Open questions and the command or file that would settle them.

Keep notes short. Use exact file paths and symbol names, so a future session can check the claim quickly.

## Before you investigate again

Read the matching skill folder first. If the answer is there, use it, and check the cited file only if the note looks stale.

## Keeping it current

- If the source changed since the note was written, update the note.
- If a note turns out to be wrong, correct it and say what changed.

## Saving

Skills repo edits are committed and pushed to `origin/master`. If the auto-commit hook did not fire, commit and push by hand, as described in `common/auto-commit-skills/SKILL.md`.
