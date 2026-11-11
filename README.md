# 🧰 Claude Skills

Skill library for the **peaks** repository (Renesas RA / FSP, mbedTLS and TF-PSA-Crypto, MCUboot), shared by the RA FSP Security team. Contributions are welcome.

Each skill is a folder with a `SKILL.md` (and optional notes, scripts, or diagrams). Claude loads a skill when its description matches the task.

---

## 🚀 Tutorial: set up on a new machine

### 1. Clone the skills repo into `~/.claude/skills`

Clone the repo into `~/.claude/skills`, the path Claude reads skills from:

macOS / Linux:

```bash
git clone git@github.com:minhnguyenyf/skills.git ~/.claude/skills
```

Windows 11 (PowerShell):

```powershell
git clone git@github.com:minhnguyenyf/skills.git $env:USERPROFILE\.claude\skills
```

Windows needs SSH access to GitHub (`ssh -T git@github.com` should greet you). If SSH is not set up, clone over HTTPS instead: `git clone https://github.com/minhnguyenyf/skills.git ~/.claude/skills`. Pushes then need your GitHub login through Git Credential Manager. Run the auto-commit setup in Git Bash, because `setup.sh` is a bash script.

Set your git identity first, so your commits carry your name:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-github-email"
```

If `~/.claude/skills` already exists as an empty folder, remove it first with `rmdir ~/.claude/skills` (PowerShell: `Remove-Item $env:USERPROFILE\.claude\skills`), then run the clone.

### 2. Ask Claude to set up the rules and auto-commit

Open Claude Code in the project folder (for example `peaks`) and paste this prompt:

```text
Read the skills in ~/.claude/skills/common/ (important-rules, auto-commit-skills, knowledge-capture).
Then run the auto-commit setup: bash ~/.claude/skills/common/auto-commit-skills/setup.sh
Confirm the hooks are installed in ~/.claude/settings.json and that the test in setup.sh passes.
Apply the commit, submodule, and read-restriction rules from important-rules to this project.
Summarize what you set up and anything you could not verify.
```

Restart Claude Code after setup so the hooks load. After that, any prompt that mentions `claude/skills/common` checks the hooks and repairs them if they are missing (this needs `jq`).

See [common/auto-commit-skills/SKILL.md](common/auto-commit-skills/SKILL.md) for details and troubleshooting.

---

## 📂 Layout

```
~/.claude/skills/
├── 🔐 psa/           PSA Crypto / mbedTLS v3 → v4 / TF-PSA-Crypto
├── 🥾 mcuboot/       MCUboot port and protected mode
├── 🧭 common/        Project rules, commit policy, tooling
├── 🔧 ocrypto/       Oberon Ocrypto library and rm_ocrypto_port build
├── 🔍 code-review/   Review session knowledge
└── 📄 README.md      This file
```

---

## 🔐 `psa/`: PSA Crypto and TF-PSA-Crypto

| Skill | What it covers |
|---|---|
| `mbedtlsv4-tf-psa-crypto-integrated` | mbedTLS 4.x and TF-PSA-Crypto integration |
| `mbedtls-v4-migration-notes` | mbedTLS v3 to v4 migration and PSA storage |
| `cch-psa-driver-scaffold` | PSA driver pattern for `rm_tf_psa_crypto` |
| `test-case-porting-guide` | Porting test cases between v3 and v4 |
| `tf-psa-crypto-v4-analysis` | TF-PSA-Crypto v4 heap analysis (not yet verified) |
| `mbedtls-to-psa-test-conversion` | Converting `rm_tf_psa_crypto` tests from mbedTLS to PSA |

## 🥾 `mcuboot/`: MCUboot port

| Skill | What it covers |
|---|---|
| `mcuboot-port-ospi` | MCUboot port with external flash slots |
| `mcuboot-rsip-protected` | MCUboot RSIP protected mode |

## 🔧 `ocrypto/`: Oberon Ocrypto

| Skill | What it covers |
|---|---|
| `ocrypto` | Ocrypto library and `rm_ocrypto_port` build |

## 🧭 `common/`: rules and tooling

| Skill | What it covers |
|---|---|
| `important-rules` | Commit policy and read-only submodules |
| `auto-commit-skills` | Auto-commit hook for skill edits |
| `budget-optimization` | Token spend and model choice |
| `knowledge-capture` | Saving MCUboot and mbedTLS findings |

## 🔍 `code-review/`

This folder records the knowledge from each review session.

---

## ⚡ How it works

1. **Load:** a skill's description decides when it's used. Keep descriptions specific, since they drive matching.
2. **Edit:** changes made with the `Edit` or `Write` tools under `~/.claude/skills/` are committed and pushed to `origin/master` by the `PostToolUse` hook in `~/.claude/settings.json`.
3. **Other changes:** changes made in Bash, such as `mv` or `rm`, are committed and pushed by the `Stop` hook at the end of each turn.
4. **Self-check:** a `UserPromptSubmit` hook runs when a prompt mentions `claude/skills/common`. It reruns `setup.sh` only if the auto-commit hooks are missing.
5. **Sync:** `settings.json` has a `SessionStart` hook that runs `git pull origin master` in `~/.claude/skills`. `setup.sh` does not write it, so it stays on machines that had it before.

---

## 🛡️ Rules to remember

- Project repos (`/home/coder/workspace/peaks/`) are **never** auto-committed. Stage, show the diff, and let the user commit.
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
