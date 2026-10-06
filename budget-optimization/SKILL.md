---
name: budget-optimization
description: Practical habits for keeping Claude Code token spend down on a monthly budget. Use when the user asks about cost, token usage, model choice for cost, or says a session is getting expensive.
---

# Budget optimization

Guidance for lowering token spend without hurting results. See [README.md](README.md) for the details and the settings caveats.

## Rules of thumb

1. **Match model to task.** Use a smaller model (Haiku) for mechanical work: renames, doc edits, simple greps, boilerplate. Use Sonnet/Opus for debugging root causes, architecture, and anything where a wrong answer costs a rebuild or a hardware test.
2. **Keep context small.** Start a fresh session when the topic changes. Use `/compact` or `/clear` instead of letting a long session grow. Long contexts are re-read on every turn.
3. **Delegate noisy searches** to a subagent (Explore) so raw output stays out of the main context.
4. **Read narrowly.** Grep, then read the needed line range, not whole large files (the migration notes SKILL.md is over 1300 lines).
5. **Write complete prompts.** File, symptom, exact error text up front avoids clarification round trips.
6. **Lean on skills** instead of re-explaining recurring context.
7. **Do not cut effort for hard problems.** Low effort on a hard debugging task usually costs more in retries than it saves.

## Do NOT

- Do not `cp budget-settings.json ~/.claude/settings.json`. That overwrites the existing `hooks` block (the skills auto-commit hook). Merge keys by hand instead.
- Do not set `permissions.defaultMode` to `dontAsk` as a cost measure; it is a safety setting, not a cost one.
- Do not quote dollar savings as facts. Check current pricing at https://www.anthropic.com/pricing and use `/cost` (or `/usage`) in the session for real numbers.
