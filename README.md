# 🧰 Claude Skills

Personal skill library for the **peaks** repository (Renesas RA / FSP, mbedTLS and TF-PSA-Crypto, MCUboot).

Each skill is a folder with a `SKILL.md` (and optional notes, scripts, or diagrams). Claude loads a skill when its description matches the task.

---

## 📂 Layout

```
~/.claude/skills/
├── 🔐 psa/           PSA Crypto / mbedTLS v3 → v4 / TF-PSA-Crypto
├── 🥾 mcuboot/       MCUboot port and protected mode
├── 🧭 common/        Project rules, commit policy, tooling
├── 🔧 ocrypto/       Oberon Ocrypto library and rm_ocrypto_port build (top level)
├── 🔍 code-review/   Code and branch review reports
├── 🔄 synced/        Anthropic-managed skills (do not edit)
└── 📄 README.md      This file
```

---

## 🔐 `psa/`: PSA Crypto and TF-PSA-Crypto

| Skill | What it covers |
|---|---|
| `mbedtlsv4-tf-psa-crypto-integrated` | Quick start for the mbedTLS 4.1.0 / TF-PSA-Crypto integration |
| `mbedtls-v4-migration-notes` | v3 ↔ v4 API diffs, littlefs and PSA storage, ECC bus-fault investigation, changelog digest |
| `cch-psa-driver-scaffold` | 4-layer CCH / PSA driver pattern for `rm_tf_psa_crypto` (+ SVG diagrams) |
| `test-case-porting-guide` | Checklist for porting test cases between v3 and v4 |
| `tf-psa-crypto-v4-analysis` | Heap requirement analysis (not yet verified) |
| `mbedtls-to-psa-test-conversion` | How rm_tf_psa_crypto test cases were moved from mbedtls to PSA: patterns, removals, open items, pitfalls |

## 🥾 `mcuboot/`: MCUboot port

| Skill | What it covers |
|---|---|
| `mcuboot-port-ospi` | MCUboot port, external-flash secondary slots (OSPI and QSPI), flash map selection, hardware-run reports |
| `mcuboot-rsip-protected` | MCUboot RSIP protected mode: device gating, instance naming, key sections, include paths, flash-key scripts |

## 🔧 `ocrypto/`: Oberon Ocrypto and rm_ocrypto_port (top level)

Build knowledge for the `rm_ocrypto_port` module and the `ocrypto` library it links. The skill sits at the top level so it loads without a group folder.

| Skill | What it covers |
|---|---|
| `ocrypto` | `rm_ocrypto_port` build order (build `ocrypto` for ra2e1_ek first, then `rm_ocrypto_port` for ra2l1_ek), why `libocrypto.a` goes missing (board filter in `SConstruct`), the `cannot find -locrypto` error, rebuild triggers per compiler, and the ocrypto_licensed link |

## 🧭 `common/`: rules and tooling

| Skill | What it covers |
|---|---|
| `important-rules` | Commit / push policy by repo type, read-only submodules (`ra/arm/mbedtls-v4/`) |
| `auto-commit-skills` | `PostToolUse` hook that commits and pushes skill edits, plus setup script |
| `budget-optimization` | Keeping token spend down: model choice, context size, subagents |
| `knowledge-capture` | Rule: save MCUboot and mbedTLS findings to the matching skill folder for future sessions |

## 🔍 `code-review/`

Reports from past code and branch reviews. Each one records the verdict, the findings with severity, what was not verified, and a merge checklist. Reuse them for later reviews.

| File | What it covers |
|---|---|
| `FSPRA-5831_review.md` | FSPRA-5831 `mcb_protected_ra8_hh` vs develop: RSIP protected mode, merge status, linker and flash-key items |
| `FSPRA-6005_review.md` | FSPRA-6005 RSA/ECC update vs develop: unifying RSIP-E50D with the E51A code paths, release note, submodule pointer |
| `FSPRA-5831_flash_script_reply_to_PM.md` | Reply to the PM on consolidating the flash-key scripts |

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
