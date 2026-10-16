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
| 7 | Low | RFP key-install script comments | **Partly fixed.** The ECC copy-paste comment is gone. `flash_with_key_rsa_rsip.sh` still says the ELF is read with `readelf`, but the script takes the address as `$2`. |
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
2. Fix the usage notes RSIP wording and the RFP script comment (sections 3.2 and 3.4).
3. Get sign-off for the `crypto_procedures_protected` pointer (section 3.3).
4. Build `rm_mcuboot_port` for ra8m1_ek: the SCE9 projects and the RSIP projects `ra8m1_ek_rsip_e51a_protected_rsa` and `ra8m1_ek_rsip_e51a_protected_fast_boot` (the `boot_rsa` project type was removed in `9a88f39b796`). Check `.mcuboot_sce9_key` and `.mcuboot_wrapped_key` in each map file.
5. Run the RSIP RSA and ECC tests on hardware.
