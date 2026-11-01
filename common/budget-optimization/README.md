# Budget optimization

## Cost drivers
- **Model:** larger models cost several times more per token than Haiku. Check current rates on the pricing page.
- **Context length:** every turn re-sends the conversation. Cached reads are cheap, but bloat still costs and degrades quality.
- **Tool output:** big file reads and noisy command output stay in context.
- **Retries:** a wrong fix that needs a rebuild or test cycle costs far more than careful thinking once.

## Settings (merge, do not copy over)
```json
{
  "model": "sonnet",
  "alwaysThinkingEnabled": false,
  "autoCompactEnabled": true
}
```
`budget-settings.json` in this folder holds these keys as a reference. Switch model in session with `/model haiku` or `/model sonnet`.

## Measuring
Use `/cost` or `/usage` in a session. Do not estimate from word counts.

## Trade-offs
- A cheaper model or lower effort can cost more overall if it fails and the work is redone. For this repo that applies to littlefs, PSA config gating, and build-size investigations.
- Turn extended thinking back on for hard debugging sessions.
