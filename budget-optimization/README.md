# Budget optimization

Keeping Claude Code spend predictable on a monthly budget. This replaces an earlier version whose pricing tables and savings percentages were unsourced and whose setup step would have overwritten `~/.claude/settings.json`.

## What actually drives cost

- **Model**: larger models cost several times more per token than Haiku. Look up current input/output rates on the pricing page; they differ between input and output and change over time.
- **Context length**: every turn re-sends the conversation. Cached reads are cheap, but a bloated context still costs more and degrades quality.
- **Tool output**: big file reads and noisy command output land in context and stay there.
- **Retries**: a wrong fix that needs a rebuild/test cycle costs far more than thinking carefully once.

## Habits that help

| Habit | Why |
|-------|-----|
| Pick the model per task (Haiku for mechanical edits, Sonnet/Opus for debugging and design) | Biggest lever, but only where quality is unaffected |
| New session per topic, or `/compact` | Shrinks per-turn context |
| Subagents for broad searches | Keeps raw results out of the main context |
| Grep then read a line range | Avoids loading huge files |
| Full prompts (file, error, expected result) | Fewer round trips |
| Skills for recurring context | No re-explaining |

## Settings

Do not copy a settings file over `~/.claude/settings.json`; it holds the auto-commit `hooks` block. Merge only what you want. Options with a real effect:

```json
{
  "model": "sonnet",
  "alwaysThinkingEnabled": false,
  "autoCompactEnabled": true
}
```

`budget-settings.json` in this folder contains exactly these keys as a reference. Switching model in-session: `/model haiku` or `/model sonnet`.

## Measuring

Use `/cost` (or `/usage`) in a session to see real spend instead of estimating from word counts.

## Trade-offs

- A cheaper model or lower effort can cost more overall if it fails and you redo the work. For this repo that applies to anything involving littlefs, PSA config gating, or build-size investigations.
- Disabling extended thinking saves tokens but weakens hard debugging; turn it back on for those sessions.
