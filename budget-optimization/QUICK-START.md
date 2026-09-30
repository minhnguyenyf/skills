# 🚀 Quick Start: $100/month Budget

## 30-Second Setup

```bash
# Copy budget settings
cp ~/.claude/skills/budget-optimization/budget-settings.json ~/.claude/settings.json

# Verify
grep "model" ~/.claude/settings.json
```

Expected output: `"model": "haiku"`

---

## Daily Commands

```bash
# Default to Haiku (cheap, fast)
/model haiku

# For architecture/design only (use sparingly)
/model sonnet

# Disable thinking (saves 25-40%)
/effort low

# Use focus mode (saves 10-15%)
/focus
```

---

## The Rule: 90% Haiku, 10% Sonnet

| Task | Model | Reason |
|------|-------|--------|
| Code reviews | Haiku | Fast enough |
| Bug fixes | Haiku | Pattern matching |
| Refactoring | Haiku | Routine edits |
| Documentation | Haiku | Writing assistance |
| Architecture | Sonnet | Complex reasoning |
| Design decisions | Sonnet | Critical thinking |

---

## Monthly Estimate

✅ **Expected cost: $5-8/month**
- 6M tokens at Haiku prices
- Budget remaining: $92-95

---

## What You're Giving Up

❌ Fast thinking (extended reasoning)  
❌ Opus model access  
❌ Web interface (stick to CLI)  

What you're keeping:  
✅ Full code editing  
✅ Bug fixing  
✅ Reviews  
✅ Documentation  
✅ All skills  

---

## If You Go Over Budget

```bash
# Check spending
claude --cost

# Emergency: Use only Haiku, batch tasks
/model haiku
/effort low
/focus
```

**Cost drops to $2-3/month in emergency mode**

---

## Pro Tips

1. **Pre-write prompts** — Copy-paste doesn't cost extra tokens
2. **Batch tasks** — 3 tasks in 1 session saves context overhead
3. **End sessions** — Don't leave conversations open
4. **Use CLI** — Web adds 10-15% overhead
5. **Reference skills** — Don't re-explain patterns

---

## Spending Tracker

```bash
# Rough estimate
# Haiku: 1M tokens = $0.80
# Sonnet: 1M tokens = $3.00
# Opus: 1M tokens = $15.00

# If you spend 6M tokens Haiku/month:
# 6 × $0.80 = $4.80 ✅ Way under budget
```

---

Questions? See `README.md` for details.
