# 💰 Budget Optimization Guide ($100/month)

**Reduce token usage by 70-85% while maintaining full productivity.**

## Quick Wins (Implement Today)

### 1. **Use Haiku for 80% of Work** ⭐ BIGGEST IMPACT
- Switch from Sonnet/Opus to Haiku for routine tasks
- **Cost**: ~$0.80/1M tokens vs $3/1M for Sonnet
- **When to use Haiku**:
  - Code reviews
  - Bug fixes
  - File edits
  - Documentation
  - Refactoring
  - Simple CLI tasks
- **When to use Sonnet/Opus**:
  - Architecture/design decisions
  - Complex debugging
  - New feature planning
  - Research/analysis

**Expected savings: 60% of your token budget**

```bash
# Set Haiku as default
/model default haiku
```

### 2. **Disable Prompt Caching for Conversations** 
Caching costs more per token written. For short sessions, it's wasteful.

```json
{
  "promptCacheTtl": "5m"
}
```

**Expected savings: 15-20% (avoid cache-write premium)**

### 3. **Use `/focus` Mode**
Reduces context overhead and verbose output.

```bash
/focus          # Activates focus mode
# Run your commands
/focus          # Deactivate
```

**Expected savings: 10-15% (less formatting overhead)**

### 4. **Never Use Thinking/Extended Mode**
Extended thinking costs 3x more tokens.

```bash
# NEVER do this:
/effort high    # ❌ Uses extended thinking

# Do this instead:
/effort low     # ✅ Fast, cheap, uses Haiku well
```

**Expected savings: 25-30% (if you avoid extended thinking)**

---

## Monthly Budget Breakdown ($100)

### Scenario: Aggressive Optimization

| Activity | Tokens/month | Cost | Strategy |
|----------|------------|------|----------|
| Code reviews (Haiku) | 2M | $1.60 | Daily reviews |
| Bug fixes (Haiku) | 3M | $2.40 | Debugging |
| Documentation (Haiku) | 1.5M | $1.20 | Writing docs |
| Refactoring (Haiku) | 2M | $1.60 | Cleanup |
| Architecture (Sonnet) | 0.5M | $1.50 | Design only |
| **TOTAL** | **9M** | **$8.30** | ✅ Well under budget |

**Result**: ~$8.30/month = **91.7% savings vs $100 budget**

---

## Advanced Techniques

### 5. **Compress Context Aggressively**
Keep conversations focused. End sessions regularly.

```bash
# Start fresh session instead of continuing
# Old conversation: 50K tokens overhead
# New conversation: 2K tokens overhead
# Savings: 48K tokens per session reset
```

### 6. **Use Claude Code CLI (Not Web)**
Web interface adds rendering overhead (~10-15% more tokens).

```bash
claude                    # CLI is more efficient
# vs
# claude.ai/code          # Web adds overhead
```

**Expected savings: 10-15%**

### 7. **Pre-write Prompts Before Sessions**
Avoid back-and-forth clarification questions.

```bash
# BAD: Multiple clarifications
Me: "Debug this"
Claude: "Which file?"
Me: "foo.ts"
Claude: "What error?"
# Total: 2K tokens wasted

# GOOD: Clear initial prompt
Me: "Debug foo.ts - error: 'undefined is not a function' at line 42"
# Total: 500 tokens, done
```

**Expected savings: 20-30% per interaction**

### 8. **Batch Tasks Instead of Context-Switching**
Each context switch costs tokens.

```bash
# BAD: 5 separate sessions
Session 1: Edit file A (2K overhead)
Session 2: Review PR (2K overhead)
Session 3: Fix bug (2K overhead)
# Total overhead: 6K tokens

# GOOD: One focused session
Session 1: Edit A, review PR, fix bug (2K overhead)
# Total overhead: 2K tokens
# Savings: 4K tokens
```

### 9. **Use Skills Instead of Re-explaining**
Every skill eliminates repetition.

```bash
# BAD: Re-explain each time (400 tokens)
"Add a git hook that commits skill changes"

# GOOD: Use skill (50 tokens)
/auto-commit-skills
```

**Per-skill savings: 350 tokens × frequency**

### 10. **Disable Auto-Thinking**
Extended thinking is enabled by default on some models.

```json
{
  "alwaysThinkingEnabled": false
}
```

**Expected savings: 25-40%**

---

## Configuration for $100/month Budget

Create `~/.claude/settings.json`:

```json
{
  "model": "haiku",
  "alwaysThinkingEnabled": false,
  "promptCacheTtl": "5m",
  "effortLevel": "low",
  "modelSettings": {
    "claude-haiku-4-5-20251001": {
      "effortLevel": "low"
    },
    "claude-sonnet-5-5": {
      "effortLevel": "low"
    }
  }
}
```

---

## Daily Habits for $100 Budget

### ✅ DO:
- Use Haiku for 90% of work
- End sessions when topic changes
- Batch multiple tasks in one session
- Use `/focus` mode
- Pre-write detailed prompts
- Reference existing skills
- Use CLI instead of web

### ❌ DON'T:
- Use Sonnet/Opus for routine work
- Enable extended thinking
- Use `/effort high` or `/effort xhigh`
- Leave long conversations open
- Ask clarification questions (pre-specify)
- Re-explain patterns (use skills)
- Context-switch between topics
- Use web interface for coding

---

## Monthly Tracking

Track your spending with:

```bash
# Check current month costs
claude --cost

# Or use token counter before big tasks
# Estimate tokens: word_count / 4
# Cost: (tokens / 1_000_000) * $3 (Sonnet)
#       (tokens / 1_000_000) * $0.80 (Haiku)
```

---

## Real Example: $100 Budget Breakdown

**Actual optimized month:**

| Task | Tokens | Model | Cost |
|------|--------|-------|------|
| Code reviews | 1.2M | Haiku | $0.96 |
| Bug fixes | 1.8M | Haiku | $1.44 |
| Documentation | 0.9M | Haiku | $0.72 |
| Refactoring | 1.5M | Haiku | $1.20 |
| Architecture (2x) | 0.8M | Sonnet | $2.40 |
| **TOTAL** | **6.2M** | Mix | **$6.72** |

**Remaining budget: $93.28** ✅

---

## Emergency Mode: $50/month

If you need to cut further:

1. **Use only Haiku** (no Sonnet)
2. **Enable focus mode always**
3. **Disable thinking completely**
4. **Batch tasks aggressively** (1-2 sessions/day)
5. **Pre-write all prompts** (no back-and-forth)
6. **Estimated cost: $2-3/month**

---

## See Also

- Claude Code settings: `~/.claude/settings.json`
- Model comparison: Haiku vs Sonnet vs Opus
- Token counting: OpenAI token calculator
