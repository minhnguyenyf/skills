---
name: budget-optimization
description: Practical habits for keeping Claude Code token spend down on a monthly budget. Use when the user asks about cost, token usage, model choice for cost, or says a session is getting expensive.
---

# Budget optimization

Details and settings: [README.md](README.md).

## Rules of thumb
1. **Match model to task.** Haiku for mechanical work (renames, doc edits, greps, boilerplate). Sonnet or Opus for root-cause debugging, architecture, and anything where a wrong answer costs a rebuild or hardware test.
2. **Keep context small.** New session per topic; `/compact` or `/clear`. Every turn re-sends the context.
3. **Delegate noisy searches** to a subagent (Explore) so raw output stays out of the main context.
4. **Read narrowly.** Grep, then read a line range. Large notes files (the migration notes) are over 1300 lines.
5. **Write complete prompts**: file, symptom, exact error text.
6. **Lean on skills** instead of re-explaining context.
7. **Do not cut effort on hard problems.** Low effort there costs more in retries.

## Do not
- Do not copy a settings file over `~/.claude/settings.json`. It holds the auto-commit `hooks` block; merge keys by hand.
- Do not set `permissions.defaultMode` to `dontAsk` to save cost. It is a safety setting.
- Do not quote dollar savings as facts. Check https://www.anthropic.com/pricing and use `/cost` or `/usage`.
