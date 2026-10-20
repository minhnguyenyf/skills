# 🧰 Claude Skills

Personal skill library for Minh Nguyen's work on the **peaks** repository (Renesas RA / FSP, mbedTLS v4 and TF-PSA-Crypto, MCUboot ports).

Each skill is a folder with a `SKILL.md` (and optional notes, scripts, or diagrams). Claude loads a skill when its description matches the task.

---

## 📂 Layout

```
~/.claude/skills/
├── 🔐 psa/           PSA Crypto / mbedTLS v3 → v4 / TF-PSA-Crypto
├── 🥾 mcuboot/       MCUboot port, QSPI / OSPI external flash, reviews
├── 🧭 common/        Project rules, commit policy, cost, auto-sync
├── 🔍 code-review/   Branch review write-ups
├── 🔄 synced/        Anthropic-managed skills (do not edit)
└── 📄 README.md      This file
```

---

## 🔐 `psa/`: PSA Crypto and TF-PSA-Crypto

| Skill | What it covers |
|---|---|
| `mbedtlsv4-tf-psa-crypto-integrated` | Quick start for FSPRA-5629 (mbedTLS 4.1.0 / TF-PSA-Crypto integration) |
| `mbedtls-v4-migration-notes` | v3 ↔ v4 API diffs, littlefs and PSA storage, ECC bus-fault investigation, changelog digest |
| `cch-psa-driver-scaffold` | 4-layer CCH / PSA driver pattern for `rm_tf_psa_crypto` (+ SVG diagrams) |
| `test-case-porting-guide` | Checklist for porting test cases between v3 and v4 |
| `tf-psa-crypto-v4-analysis` | Heap requirement analysis (values still unverified for v4) |

## 🥾 `mcuboot/`: MCUboot port

| Skill | What it covers |
|---|---|
| `mcuboot-port-ospi` | `rm_mcuboot_port`, OSPI_B (RA8D1) and QSPI (RA6M5) secondary slots, flash map selection, hardware-run reports |
| `mcuboot-rsip-protected` | FSPRA-5831 RSIP protected mode: device gating (RA8M1/RA8D1), `g_mcuboot_rsip_ctrl` naming, `.mcuboot_wrapped_key`, `r_rsip.h` include paths, flash-key scripts, build failures seen |

## 🧭 `common/`: rules and tooling

| Skill | What it covers |
|---|---|
| `important-rules` | Commit / push policy by repo type, read-only submodules (`ra/arm/mbedtls-v4/`) |
| `auto-commit-skills` | `PostToolUse` hook that commits and pushes skill edits, plus setup script |
| `budget-optimization` | Keeping token spend down: model choice, context size, subagents |
| `knowledge-capture` | Rule: save MCUboot and mbedTLS v3/v4 findings to the matching skill folder, so future sessions don't re-investigate |

## 🔍 `code-review/`

- `FSPRA-5831_branch_review.md`: review of the `FSPRA-5831_mcb_protected_ra8_hh` branch against `develop`, with status of earlier findings and open items.
- `FSPRA-5831_flash_script_reply_to_PM.md`: reply to the PM on the single key-install script (`flash_with_key.sh`), with the reasons, changes, and open questions.

---

## ⚡ How it works

1. **Load:** a skill's description decides when it's used. Keep descriptions specific, since they drive matching.
2. **Edit:** changes made with the `Edit` or `Write` tools under `~/.claude/skills/` are committed and pushed to `origin/master` by the hook in `~/.claude/settings.json`.
3. **Move or delete:** `mv` and `rm` in Bash bypass the hook, so commit those changes by hand.
4. **Sync:** a `SessionStart` pull is described in the docs but is **not** configured in `settings.json`, so skills do not sync from GitHub at session start yet.

---

## 🛡️ Rules to remember

- Project repos (`/home/coder/workspace/peaks/`) are **never** auto-committed. Stage, show the diff, and let Minh commit.
- `ra/arm/mbedtls-v4/` and its `tf-psa-crypto/` are read-only submodules. Fix problems in project config instead.
- Never hand-edit files listed in `data/collected-files/ddsc-generated.yml`. Change the generator template.
- Read `common/important-rules` before any git operation.

---

## 🧪 Verify a skill loads

```bash
cd ~/.claude/skills && git log --oneline -3          # recent skill commits
git status --short                                    # uncommitted skill changes
git log origin/master --oneline -1                    # should match local HEAD after a push
```

---

## 📝 Adding a skill

1. Create `psa/<name>/`, `mcuboot/<name>/`, `common/<name>/`, or a new top-level folder.
2. Write `SKILL.md` with frontmatter:

   ```markdown
   ---
   name: <name>
   description: One line saying when to use it. Be specific.
   ---
   ```

3. Put long reference material in sibling `.md` files and link them from `SKILL.md`.
4. Update the table above.

> ⚠️ Skill loading may only look one folder deep. If a grouped skill doesn't appear in a new session, see whether it needs to move back to the top level.
