# Review: FSPRA-5831_mcb_protected_ra8_hh vs develop

**Status:** Draft for review. Not committed.
**Written for:** Minh Nguyen (branch author), for review before the branch is merged.
**Base:** `develop` (merge-base `fa0f40d57cd`) · **Head:** `9bb44da1dd2`
**Size:** 56 commits · 75 files · +11,557 / −42. About 10k of the added lines are generated linker scripts under `!linker/`.

---

## 1. Verdict

Not ready to merge as-is. There is one blocking item and two items that will likely fail CI.

| # | Severity | Finding | Where |
|---|----------|---------|-------|
| 1 | **Blocking** | Hand-edited collected files fail the pipeline hash check (5 files). | `ra/fsp/src/bsp/mcu/ra8m1/!linker/{gcc,llvm}/…` vs `data/collected-files/ddsc-generated.yml` |
| 2 | **High** | The SCE9 key section is no longer kept by the ra8m1 gcc/llvm boot and image linker scripts. This is a silent regression for SCE9 devices. | same 5 files |
| 3 | Medium | Unused PSS helper (`pss_mgf1`), unused locals and macros, and a stale comment in `rsip_image_rsa.c`. May break `-Werror`. | `rsip/rsip_image_rsa.c:86-178` |
| 4 | Medium | Usage notes still describe `mcuboot_sce9_key` for the RSIP flow. Two new sections are generic and not tied to this feature. | `rm_mcuboot_port/!dsn/rm_mcuboot_port_usage_notes.md` |
| 5 | Medium | Submodule pointers move (`crypto_procedures_protected`, `ra/mcu-tools/MCUboot`). Needs explicit sign-off. | submodule gitlinks |
| 6 | Low | Stray `\` after two `</exclude>` tags. | `projects/rm_mcuboot_port.xml:1028`, `:1156` |
| 7 | Low | Copy-paste comments in the RFP key-install scripts. | `rm_mcuboot_port/!test/flash_with_key_*_rsip.sh` |
| 8 | Low | RSIP test project relies on an implicit auto-define of `MCUBOOT_USE_RSIP_PROTECTED`. | `projects/rm_mcuboot_port.xml` (`ra8m1_ek_rsip_e51a_protected_rsa`) |

---

## 2. What the branch does

Adds MCUboot protected-mode support for RA8 using the RSIP-E51A engine, alongside the existing SCE9 path.

1. **Crypto stack split.** `custom_crypto_stacks/protected_mode/` becomes `sce9/` (moved, content unchanged). A new `rsip/` directory holds the RSIP implementation: `rsip_image_rsa.c`, `rsip_image_ec256.c`, `rsip_keys.c/.h`, `rsip_sha256.h`, `rsip_ecdsa_p256.h`. Verification calls `R_RSIP_ECDSA_Verify` / `rsassaPssVerify` against keys placed in `.mcuboot_rsip_key`.
2. **Module descriptions.** `rm_mcuboot_protected_mode` is renamed to `rm_mcuboot_sce9_protected_mode`. A new `rm_mcuboot_rsip_protected_mode` is added. Each is gated on the device's RSIP or SCE9 support. The SCE9 test constraints are updated to the new module IDs.
3. **Config.** `mcuboot_config.h` selects `MCUBOOT_USE_RSIP_PROTECTED` or `MCUBOOT_USE_SCE9_PROTECTED` from BSP feature macros. It also sets `MCUBOOT_BYPASS_KEY_MATCH` for RSIP, so plaintext keys are never read.
4. **Build plumbing.** `SConstruct` gets `boot_rsa` and `boot_app_rsa` project types, with `test_files/shared/common_{boot,boot_app}_rsa.xml`. `scripts/dependency_tree/build_tree.py` is updated to match.
5. **Projects.** New `rm_mcuboot_app_protected_rsa.xml`. A new `boot_app` entry in `rm_mcuboot_app_protected.xml`. New RSIP test projects in `rm_mcuboot_port.xml`. One existing project is wrapped in `<?ignore ?>`.
6. **Test support.** RFP key-install scripts and `.rkey` files. Test runner and `rm_mcuboot_port_data.c` updated for RSIP.
7. **Other.** Release note `documents/release_notes/upcoming/FSPRA-5831.yml`, usage-note additions, submodule pointer bumps.

---

## 3. Findings

### 3.1 Blocking: collected-file hashes do not match

`scripts/pipeline/check_collected_files.sh` stage 1 compares every file in `data/collected-files/ddsc-generated.yml` with its stored SHA-256. I ran the same check on the working tree (1,840 entries).

Five files fail:

```
ra/fsp/src/bsp/mcu/ra8m1/!linker/gcc/boot/fsp_gen.ld
ra/fsp/src/bsp/mcu/ra8m1/!linker/gcc/fsp_gen.ld
ra/fsp/src/bsp/mcu/ra8m1/!linker/gcc/image/fsp_gen.ld
ra/fsp/src/bsp/mcu/ra8m1/!linker/llvm/boot/fsp_gen.lld
ra/fsp/src/bsp/mcu/ra8m1/!linker/llvm/image/fsp_gen.lld
```

Each one has a single line changed, `KEEP(*(.mcuboot_sce9_key))` → `KEEP(*(.mcuboot_rsip_key))`. These are generated files that were edited by hand. The pipeline rule is: never hand-edit a collected file. Under the current process, this change needs to come from the generator (`scripts/mcu_xml_gen/templates/linker_policy_template.j2`, which already has the wildcard). The collected-file DB then needs to be updated through the normal collection path.

The pipeline will fail at this stage. This is the same failure mode as the QSPI work in the `mcuboot-port-ospi` skill (2026-10-09 entry).

### 3.2 High: SCE9 key section is dropped from ra8m1 gcc and llvm scripts

The edits above also change behavior. The default `boot` and `image` scripts used to keep `.mcuboot_sce9_key`. Now they keep only `.mcuboot_rsip_key`.

- `sce9/sce9_keys.c:10` still places `g_pub_key` in `.mcuboot_sce9_key`.
- So on SCE9 boot and app builds for gcc and llvm, the key section is not kept. It can be garbage-collected or left unplaced.
- The ac6 `fsp_gen.scat` (`ra8m1/!linker/ac6/image/fsp_gen.scat:507`) still keeps `.mcuboot_sce9_key`. The toolchains are now inconsistent.

**Suggested fix:** keep both sections in the non-RSA scripts, for example with `KEEP(*(.mcuboot_sce9_key)) KEEP(*(.mcuboot_rsip_key))`, or with the wildcard `KEEP(*(.mcuboot_*_key))`. Then regenerate through the generator so the collected-file hashes are updated. Also check the ac6 script. Verify with the `.map` file that `g_pub_key` lands in the expected section for an SCE9 build and for an RSIP build.

### 3.3 Medium: dead code in `rsip_image_rsa.c`

Correction to the earlier draft: the manual PSS code is not present in this file. The function ends at the comment on lines 175-178, which says the manual code "is kept as reference/fallback", but no such code follows. The comment is stale.

What is dead, in `ra/fsp/src/rm_mcuboot_port/custom_crypto_stacks/protected_mode/rsip/rsip_image_rsa.c`:

| Lines | Symbol | Status |
|-------|--------|--------|
| 86 | `static const uint8_t pss_zeros[8]` | Never referenced |
| 96-123 | `static void pss_mgf1(...)` | Never called in this file (`grep` finds only the definition) |
| 135 | `uint8_t em[PSS_EMLEN]` in `rsip_bootutil_cmp_rsasig` | Declared, never used |
| 136 | `uint8_t db_mask[PSS_MASK_LEN]` | Declared, never used |
| 137 | `uint8_t h2[PSS_HLEN]` | Declared, never used |
| 134, 138 | `ctx` and `i` | Declared, never used |
| 66-84 | `PSS_*` macros | Only used by the dead code above |

The SCE9 version (`sce9/sce9_image_rsa.c:216`) does call `pss_mgf1()`, because it does the PSS check in software. The RSIP version delegates the whole check to `g_rsip_on_rsip.rsassaPssVerify`, so the software PSS path is not needed here.

Impact: these are unused locals and unused statics. I did not compile the file, so I cannot say which warnings the toolchain emits. With `-Wall -Werror`, `-Wunused-function` (for `pss_mgf1`) and `-Wunused-variable` (for the locals) would likely fail the build. Compile the file to confirm.

**Suggested fix:** delete `pss_zeros`, `pss_mgf1`, the unused `PSS_*` macros and locals, and the stale comment on lines 175-178. Keep only the RSIP delegation path, so the file matches its actual behavior.

### 3.4 Medium: usage notes

- `rm_mcuboot_port/!dsn/rm_mcuboot_port_usage_notes.md` lines 530, 558, 582, 606 still say "install the key to the `mcuboot_sce9_key` section". For the RSIP flow the section is `mcuboot_rsip_key`.
- The new sections "VTOR Configuration Support" and "Multi-Image Support" are generic text. I did not verify them against code. The multi-image text refers to a "Multi-Image Bootloader Setup section" that I did not find in this file. Either tie them to this feature with real content, or drop them from this branch.

### 3.5 Medium: submodule pointers

- `ra/fsp/src/r_rsip_protected/crypto_procedures_protected`: `4ee8bf03` → `87a17fac`.
- `ra/mcu-tools/MCUboot`: `b839cbc4` → `c87495c8`.

These are outside this branch's own code. Please confirm both target commits are intended and reviewed. I did not diff the MCUboot range, so I cannot say whether its `bootutil` changes affect the RSIP path.

### 3.6 Low: stray backslashes in the XML

`projects/rm_mcuboot_port.xml` lines 1028 and 1156 end with `</exclude>\`. The parser ignores the text, but it is a typo. Remove the backslash.

### 3.7 Low: RFP key-install scripts

- `!test/flash_with_key_rsa_rsip.sh` comment says "ECC_pub_5.rkey". It should say `RSA_pub_rsip.rkey`.
- Both scripts' header comments say the ELF is read with `readelf` to find the key location. They do not do that. The script takes the address as `$2`.

### 3.8 Low: implicit macro in the RSIP test project

The `ra8m1_ek_rsip_e51a_protected_rsa` project does not define `MCUBOOT_USE_RSIP_PROTECTED`. It is auto-defined by `mcuboot_config.h` from the BSP feature macro. That works. Consider adding a comment, or set the macro explicitly as the SCE9 project does.

---

## 4. Checks that look correct

- The `SConstruct` changes for `boot_rsa` and `boot_app_rsa` follow the same pattern as `boot` and `boot_app`. The sign condition is extended correctly.
- The SCE9 rename is applied in both `r_sce_protected/.xml_tests/constraints.yml.j2` and `r_sce_protected_cavp/.xml_tests/constraints.yml.j2`.
- `rsip_ecdsa_p256.h` and `rsip_sha256.h` keep the same unaligned-buffer handling (`MCUBOOT_CHECK_32BIT_UNALIGNED`) as the SCE9 code.
- `rsip_image_ec256.c`: in the RSIP branch, `bootutil_verify_sig` does not read the plaintext `bootutil_keys[]`. The `key_id` selects the wrapped key directly.
- The working tree is clean. The only untracked path is `ra/arm/mbedtls-v4/`, which is not part of this branch.

---

## 5. Not verified

- No build was run (gcc, llvm, or ac6).
- No hardware test was run.
- The `.map` file was not inspected.
- The usage-note VTOR and multi-image text was not checked against code.
- The submodule commits were not reviewed.

Recommended verification before merge:
1. Regenerate the ra8m1 linker scripts through the generator and confirm the collected-file check passes.
2. Build `rm_mcuboot_port` with `ra8m1_ek` for: SCE9 `boot`, SCE9 `boot_app`, RSIP `boot_rsa`, RSIP `boot_app_rsa`.
3. Check `g_pub_key` placement in each `.map` file.
4. Run the RSIP RSA and ECC tests on hardware.

---

## 6. Process notes from the project skills

From `~/.claude/skills/important-rules`:
- Do not auto-commit to `/home/coder/workspace/peaks/`. This report is untracked and has not been committed.
- `ra/arm/mbedtls-v4/` is read-only. This branch does not change it.

From `~/.claude/skills/mcuboot-port-ospi/SKILL.md`:
- The `.module_descriptions/` list there still names `rm_mcuboot_protected_mode`. It is now `rm_mcuboot_sce9_protected_mode` and `rm_mcuboot_rsip_protected_mode`. The skill should be updated after this branch lands.
- The 2026-10-09 entry in that skill records the same collected-file problem from the QSPI work. The rule is to change the generator, not the output files.

Note: `/claude/skills` does not exist on this machine. I read the skills in `/home/coder/.claude/skills`.
