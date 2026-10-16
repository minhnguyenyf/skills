# Review: FSPRA-5831_mcb_protected_ra8_hh vs develop (updated)

**Status:** Draft for review. Not committed to the project repo.
**Written for:** Minh Nguyen (branch author), for review before the branch is merged.
**Base:** `develop` (merge-base `2d3e264b138`) · **Head:** `5e7e8866cad` ("FSPRA-5831 Fix backward compatibility issue", 2026-10-16)
**Size:** 85 commits · 552 files · +2,534 / −625. This replaces the 2026-10-13 review, which covered head `9bb44da1dd2` (56 commits, 75 files).

---

## 1. Verdict

Mostly ready. The previous blocking item and the SCE9 key regression are fixed. Two items are still open before merge: the submodule pointer needs sign-off, and the generated linker files have not been checked against a fresh regeneration.

| # | Severity | Finding | Status at `5e7e8866cad` |
|---|---|---|---|
| 1 | Blocking | Hand-edited ra8m1 linker files fail the collected-file hash check | **Fixed.** 80 of 80 ra8m1 entries match. The generator template now emits `.mcuboot_wrapped_key`, and the hash database was updated in `582559c593e`. Open: confirm a fresh regeneration produces the same files (section 3.1). |
| 2 | High | SCE9 key section no longer kept by ra8m1 linker scripts | **Fixed.** Boot and image scripts keep both `.mcuboot_sce9_key` and `.mcuboot_wrapped_key` for gcc, llvm, iar, and ac6. |
| 3 | Medium | Dead code in `rsip_image_rsa.c` | **Fixed.** `pss_mgf1`, `pss_zeros`, and the unused locals are gone. `PSS_HLEN` is still used. |
| 4 | Medium | Usage notes still describe `mcuboot_sce9_key` for RSIP, and generic VTOR and multi-image sections | **Partly fixed.** The generic sections are removed. The RSIP steps now name `mcuboot_sce9_key or mcuboot_wrapped_key` and should name only `mcuboot_wrapped_key` (section 3.2). |
| 5 | Medium | Submodule pointers move | **Partly fixed.** `ra/mcu-tools/MCUboot` is back at develop's `b839cbc4f84`. `crypto_procedures_protected` is still moved (`4ee8bf03` → `87a17fac`) and needs explicit sign-off. |
| 6 | Low | Stray `\` after `</exclude>` in `projects/rm_mcuboot_port.xml` | **Fixed.** No match remains. |
| 7 | Low | RFP key-install script comments | **Partly fixed.** The ECC copy-paste comment is gone. `flash_with_key_rsa_rsip.sh` still says the ELF is read with `readelf`, but the script takes the address as `$2`. A PM proposal replaces the five scripts with one (section 3.5). |
| 8 | Low | Implicit `MCUBOOT_USE_RSIP_PROTECTED` define | **Withdrawn** in the earlier review. No change needed. |

---

## 2. What changed since the 2026-10-13 review

- **Key section renamed to `.mcuboot_wrapped_key`.** The RSIP stack (`rsip/rsip_keys.c`) uses it. The SCE9 stack still uses `.mcuboot_sce9_key`. Both are kept, so an image built for either engine finds its key.
- **Generator template** `scripts/mcu_xml_gen/templates/linker_policy_template.j2` gets two new lines for `.mcuboot_wrapped_key` with `keep: True`. The generated ra8m1 files now match that output.
- **Collected-file database** `data/collected-files/ddsc-generated.yml` changed by about 950 lines (`582559c593e`). That is the normal flow after a regeneration, but see section 3.1.
- **Module rename finished.** `rm_mcuboot_protected_mode` is kept for the SCE9 stack, and `rm_mcuboot_rsip_protected_mode` is added. No dangling references were found in `ra/`, `projects/`, `scripts/`, or `test_files/`.
- **Last commit** (`5e7e8866cad`, "Fix backward compatibility issue") changes the SCE9 constraints in `r_sce_protected` and `r_sce_protected_cavp`, the `rm_mcuboot_port` module XML, and the protected-mode module description.
- **New RSIP CAVP test tree** `ra/fsp/src/r_rsip_e11a_protected_cavp/!test/`. Only its file list was checked, not its contents.

---

## 3. Open items

### 3.1 Generated linker files must match a fresh regeneration
The hash check passes, but it only proves the committed files match the database. Commit `582559c593e` updated the database to the committed files. The check does not prove that the generator, run again, produces the same files. Before merge, regenerate the ra8m1 linker files through the generator and confirm `git diff` is empty.

### 3.2 Usage notes
`rm_mcuboot_port/!dsn/rm_mcuboot_port_usage_notes.md` lines 597, 624–625, 648–649 still say "mcuboot_sce9_key or mcuboot_wrapped_key". The RSIP steps (lines 648–649) should name `mcuboot_wrapped_key` only.

### 3.3 Submodule pointer
`ra/fsp/src/r_rsip_protected/crypto_procedures_protected` moves from `4ee8bf03ada` to `87a17facd89`. Confirm that commit is intended and reviewed. This review did not diff it.

### 3.4 RFP script comment
`ra/fsp/src/rm_mcuboot_port/!test/flash_with_key_rsa_rsip.sh` line 6 says the ELF is read with `readelf`. The script takes the address as `$2`. Fix the comment or the script.

### 3.5 RFP flash scripts: proposed single script (PM)
**Proposal:** replace the five per-key scripts (`flash_with_key_ecc.sh`, `flash_with_key_ecc_rsip.sh`, `flash_with_key_rsa.sh`, `flash_with_key_rsa_3072.sh`, `flash_with_key_rsa_rsip.sh`) with one `flash_with_key.sh <srec> <key_address_hex> <key_file>`. The key file is a third argument, not hard-coded.

**What the proposal fixes**
- **Exit status.** A failure after 20 attempts now exits 1. The current scripts end with `echo` and exit 0, so a caller sees success.
- **Explicit inputs.** The argument count and the key file's existence are checked. This also removes the risk of a script using the wrong key, such as `ECC_pub_5.rkey` in one script and `ECC_pub_rsip.rkey` in another.
- **Shell safety.** `set -u` catches unset variables.
- **Clearer usage.** A usage line is printed on wrong arguments.

**Problems to fix before adopting it**
1. **Callers break.** The harness (`fsp_test_parallel.py`, around line 507) runs `script <srec> <flash_script_args…>`. Each `flash_script_args` value is looked up as a key in the project dictionary. The current entries are `['g_pub_key']` in `projects/rm_mcuboot_port.xml` at lines 764, 863, 980, 1107, and 1235. The proposed script exits with status 2 when it gets only two arguments. The XML needs the key file for each of those five projects, and the harness must accept it. A literal string such as `'ECC_pub_rsip.rkey'` is not a project key today, so the lookup would fail.
2. **No shebang in the proposal.** The text starts with `# Usage:`. The `for ((…))` loop needs bash. Run with `sh` (dash), it fails. Add `#!/bin/bash` as the first line.
3. **Key address not validated.** If `0x` is passed by mistake, the command becomes `-userkey 0x0x…`, and rfp-cli retries 20 times before failing. Add a hex check, for example `[[ "$key_address" =~ ^[0-9A-Fa-f]+$ ]]`.
4. **SREC not checked.** Add `[ -f "$srec" ]` before the loop.
5. **Retry message.** `Retry - 20` is printed before the final failure message. This is minor, but the message can be skipped on the last attempt.
6. **Comments.** The named person and the ticket reference belong in the ticket or usage notes, not in the script.

**What stays right:** the retry loop for the intermittent libjlinkarm error, `set -u`, the key path check, and the exit codes.

**Recommendation:** adopt the single script after the fixes in items 1–4, and update the five `flash_script_args` entries (or the harness) in the same change. Check that the harness and the RFP version both accept the new arguments. Nothing here has been run against the harness or hardware.

**Status: fix applied, not committed.** The change is on local branch `claude/flash-with-key-single-script`, in worktree `/tmp/claude-5831-flash-fix`, based on `5e7e8866cad`.
- **New script** `ra/fsp/src/rm_mcuboot_port/!test/flash_with_key.sh` (executable). It has the shebang and the argument, SREC, hex, and key-file checks. It exits 1 after 20 failed attempts and prints `Retry` only between attempts. Tested with a fake `rfp-cli`: wrong argument count, `0x` prefix, missing SREC, missing key, success, and 20 failed attempts all return the expected status. `bash -n` passes. Not run against RFP or hardware.
- **Harness unchanged.** `flash_script_args` now reads `['g_pub_key', 'key_file']`, and each entry sets a `key_file` field in `test_info_init`. The harness already reads any field listed in `flash_script_args`, so no harness change is needed.
- **XML** `projects/rm_mcuboot_port.xml`: four active entries updated (lines 764, 863, 980, 1107). Mapping: `RSA_pub.rkey` for `ra6m5_ek_sce9_protected_rsa`, `ECC_pub_5.rkey` for `ra6m4_ek_sce9_protected_fast_boot`, `RSA_pub_rsip.rkey` for `ra8m1_ek_rsip_e51a_protected_rsa`, `ECC_pub_rsip.rkey` for `ra8m1_ek_rsip_e51a_protected_fast_boot`. The fifth line (1235) is in a disabled `<?ignore` block (`ra6e1_fpb_sce9_protected_ecc`) and was updated for consistency only.
- **Old scripts** (`flash_with_key_ecc.sh`, `_ecc_rsip.sh`, `_rsa.sh`, `_rsa_3072.sh`, `_rsa_rsip.sh`) are now thin wrappers. Each keeps its old two-argument call and forwards to `flash_with_key.sh` with its own key (for example, `flash_with_key_ecc_rsip.sh` forwards `ECC_pub_rsip.rkey`). Each wrapper's key file was checked to exist, and `flash_with_key_ecc_rsip.sh` was run with a fake `rfp-cli`. Remove the wrappers after a harness run confirms the new path works. `flash_with_key_rsa_3072.sh` is not referenced by any XML entry on this branch.
- **Not committed.** Review the diff in the worktree, then commit it on the project branch yourself.

---

## 4. Checks that look correct

- All 80 ra8m1 collected-file hashes match the database (checked from a `git archive` of the branch, not the working tree).
- Both key sections are kept in boot and image linker scripts for gcc, llvm, iar, and ac6 (`fsp_gen.ld`, `.lld`, `.icf`, `.scat`).
- No stray backslash after `</exclude>` in `projects/rm_mcuboot_port.xml`.
- The `PSS_HLEN` define in `rsip_image_rsa.c` is still used.

---

## 5. Not verified

- No build was run (gcc, llvm, ac6, or iar). The branch was not checked out. The review used `git show` and `git archive`, so the working tree is unchanged.
- No hardware test was run.
- The 552-file diff was not read line by line. The RSIP CAVP test tree and the large ra8m1 linker change were sampled, not fully reviewed.
- The generated linker files were not compared with regeneration output (section 3.1).
- The `crypto_procedures_protected` commit was not reviewed (section 3.3).

---

## 6. Recommended before merge

1. Regenerate the ra8m1 linker files and confirm no diff (section 3.1).
2. Fix the usage notes RSIP wording and the RFP script comment (sections 3.2 and 3.4). If the PM's single script is adopted, apply the fixes in section 3.5 and update the five `flash_script_args` entries in `projects/rm_mcuboot_port.xml` (lines 764, 863, 980, 1107, 1235) together with the harness.
3. Get sign-off for the `crypto_procedures_protected` pointer (section 3.3).
4. Build `rm_mcuboot_port` for ra8m1_ek: the SCE9 projects and the RSIP projects `ra8m1_ek_rsip_e51a_protected_rsa` and `ra8m1_ek_rsip_e51a_protected_fast_boot` (the `boot_rsa` project type was removed in `9a88f39b796`). Check `.mcuboot_sce9_key` and `.mcuboot_wrapped_key` in each map file.
5. Run the RSIP RSA and ECC tests on hardware.
