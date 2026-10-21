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
├── 🔍 code-review/   Branch review write-ups
├── 🔄 synced/        Anthropic-managed skills (do not edit)
└── 📄 README.md      This file
```

---

## 🔐 `psa/`: PSA Crypto and TF-PSA-Crypto

| Skill | What it covers |
|---|---|
| `mbedtlsv4-tf-psa-crypto-integrated` | Quick start for the mbedTLS 4.1.0 / TF-PSA-Crypto integration |
| `mbedtls-v4-migration-notes` | v3 ↔ v4 API diffs, littlefs and PSA storage, ECC bus-fault investigation, changelog digest. Section index below |

### 📑 `mbedtls-v4-migration-notes` section index

Ask by number or keyword, e.g. "§21" or "key slot count". Read only the section you need.

| § | Topic | Keywords |
|---|---|---|
| 1 | Headers moved under `mbedtls/private/` | private headers, aes.h, cmac.h |
| 2 | `mbedtls_pk_parse_key()` lost RNG args | pk_parse_key, f_rng |
| 3 | `psa_key_handle_t` removed | key_id, handle |
| 4 | `psa_open_key` / `psa_close_key` removed | open_key, close_key, INVALID_HANDLE |
| 5 | PQC include paths not wired up | pqc, r_pqc_api.h |
| 6 | `PSA_KEY_LIFETIME_IS_PERSISTENT` removed | lifetime, persistent macro |
| 7 | AES-XTS disabled upstream | XTS, PSA_ALG_XTS |
| 8 | `KEY_STORE_DYNAMIC` leak false positives | calloc leak, 108/640 bytes |
| 9 | ECC persistent key bus fault (resolved, test skipped on E31A) | bus fault, mlist, littlefs |
| 10 | Persistent storage macros v3 vs v4 | storage macros, ITS_FILE_C |
| 11 | Double key import leak | import, destroy_key, ra6m3_ek |
| 12 | `tf_` requirement ID prefix | requirement IDs, @req |
| 13 | Design-note anchors all lowercase | anchors, @anchor |
| 14 | `_wrapped` naming convention | wrapped, underscore |
| 15 | Board configuration in project XML | board, ra6m4_ek, ra8m1_ek |
| 16 | XML test templates (v4) | .xml_tests, jinja, availability |
| 17 | New board breaks dependency-tree self-test | build_tree, test_cases.yml |
| 18 | Missing `hw_sce_hash_private.h` include | HW_SCE_LARGE_DATA |
| 19 | Unbalanced parens make ECC heap constraint unsatisfiable | paren, Software ECC, 0x1800 |
| 20 | `ra2e1_ek` overflow (superseded gating approach) | ra2e1_ek, FLASH, gating, PSA_WANT |
| 21 | `ra2a1_tbb` RAM overflow: key slot count | SLOT_COUNT, 2532 bytes |
| 22 | `ra2a1_tbb` second RAM contributor: calloc_size_array | MAX_CALLOC, 1344 bytes |
| 21b | Board RAM overflow fixes (ra8m2_ek, ra4m1_ek) | heap, 0xF000, 0x3000 |
| 23 | Module-description copy/paste bugs | option ids, constraints, default |
| 24 | FSP user build: `private_access.h` not found | pack, include_folders, sources |
| 25 | `dummy_setbuf` breaks customer projects | SETBUF, md.c, pkparse.c |
| 26 | `threading_internal.h` not found | threading, psa_crypto.c:71 |
| 27 | Caveats on the notes file | numbering, status, Windows paths |

Note: there are two sections numbered 21. The first (RAM overflow, `ra2a1_tbb`) is listed as 21 and the second (board heap fixes) as 21b.
| `cch-psa-driver-scaffold` | 4-layer CCH / PSA driver pattern for `rm_tf_psa_crypto` (+ SVG diagrams) |
| `test-case-porting-guide` | Checklist for porting test cases between v3 and v4 |
| `tf-psa-crypto-v4-analysis` | Heap requirement analysis (not yet verified) |
| `mbedtls-to-psa-test-conversion` | How rm_tf_psa_crypto test cases were moved from mbedtls to PSA: patterns, removals, open items, pitfalls |

## 🥾 `mcuboot/`: MCUboot port

| Skill | What it covers |
|---|---|
| `mcuboot-port-ospi` | MCUboot port, external-flash secondary slots (OSPI and QSPI), flash map selection, hardware-run reports |
| `mcuboot-rsip-protected` | MCUboot RSIP protected mode: device gating, instance naming, key sections, include paths, flash-key scripts |

## 🧭 `common/`: rules and tooling

| Skill | What it covers |
|---|---|
| `important-rules` | Commit / push policy by repo type, read-only submodules (`ra/arm/mbedtls-v4/`) |
| `auto-commit-skills` | `PostToolUse` hook that commits and pushes skill edits, plus setup script |
| `budget-optimization` | Keeping token spend down: model choice, context size, subagents |
| `knowledge-capture` | Rule: save MCUboot and mbedTLS findings to the matching skill folder for future sessions |

## 🔍 `code-review/`

Notes from past code reviews, kept so future review work can reuse the findings, the checks that worked, and the open items.

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
