---
name: mcuboot-rsip-protected
description: MCUboot RSIP protected-mode work on FSPRA-5831 (RA8M1/RA8D1 RSIP-E51A): module gating, key sections, include paths, flash-key scripts, and the build failures seen. Use when touching rm_mcuboot_port custom_crypto_stacks/protected_mode/rsip, rm_mcuboot_rsip_protected_mode, ra8m1 linker key sections, or flash_with_key*.sh.
metadata:
  type: reference
  branch: FSPRA-5831_mcb_protected_ra8_hh
  recorded: 2026-10-16
---

# MCUboot RSIP protected mode (FSPRA-5831)

Knowledge from the FSPRA-5831 review and fix session. Verify line numbers against the branch before relying on them.

## 1. Which devices can use it
- `test_files/ra_cfg/mcu-tools/include/mcuboot_config/mcuboot_config.h` sets `MCUBOOT_USE_RSIP_PROTECTED` only when `BSP_FEATURE_RSIP_RSIP_E51A_SUPPORTED` is 1, inside `MCUBOOT_USE_USER_DEFINED_CRYPTO_STACK`.
- E51A is defined on RA8M1, RA8D1, RA8E1, RA8E2. RA8M2 is E50D only (`ra/fsp/src/bsp/mcu/<mcu>/bsp_feature.h`).
- Device data (`scripts/mcu_xml_gen/data/device/RA8*.yml`): the `rsip_e51a_protected` interface exists only on RA8M1 and RA8D1.
- The protected E51A driver (`r_rsip_e51a_protected`) gates on `interface.mcu.rsip.rsip_e51a === "1"`.
- The MCUboot module gate (`rm_mcuboot_port/.module_descriptions/Renesas##Middleware##all##rm_mcuboot_rsip_protected_mode####x.xx.xx.xml`, line 6) is now:
  `("${interface.mcu.rsip.sce9}" !== "1") &amp;&amp; ("${interface.mcu.rsip.rsip_e51a_protected}" === "1")`
  Before this change it only excluded SCE9, so RA8M2 could select the module and fall into the non-protected branch. This is in HEAD (`be04a355f99`).

## 2. Code state
- `rsip/rsip_sha256.h`: protected-only. `bootutil_sha_context` is `uint32_t` and the calls pass `&rsip_ctrl` directly. The old `MCUBOOT_RSIP_SHA_CTRL` macro was removed.
- `rsip/rsip_image_ec256.c` and `rsip/rsip_ecdsa_p256.h`: the non-protected branches were removed (154 + 14 lines, commit `be04a355f99`). They were software ECDSA with mbedTLS and used the plaintext `bootutil_keys[]`, which is not linked in RSIP builds. The old code is in `5e7e8866cad` if a software fallback is ever needed.
- `rsip/rsip_keys.c`: `rsip_ctrl`/`rsip_cfg` definitions and the `rsip_sha256.h` include must stay inside `#if defined(MCUBOOT_USE_RSIP_PROTECTED)`. Removing that guard broke every project that compiles the whole `rm_mcuboot_port` folder (see section 5). The guard was restored in the working tree; check that it is committed.
- Remaining cleanup candidates: `BOOTUTIL_CRYPTO_SHA256_BLOCK_SIZE` in `rsip_sha256.h` is unused (`sce9_sha256.h` has the same unused macro). `MCUBOOT_USE_RSIP_PROTECTED` is still checked in `!test/rm_mcuboot_port_data.c` line 25 and defined in the shared `mcuboot_config.h`.

## 3. Key sections and linker
- RSIP key section is `.mcuboot_wrapped_key` (`rsip/rsip_keys.c`). SCE9 uses `.mcuboot_sce9_key` (`sce9/sce9_keys.c`).
- ra8m1 boot and image linker scripts keep both sections for gcc, llvm, iar, ac6 (`ra/fsp/src/bsp/mcu/ra8m1/!linker/`).
- Generator source: `scripts/mcu_xml_gen/templates/linker_policy_template.j2` (two `keep: True` entries added).
- Collected-file hashes: `data/collected-files/ddsc-generated.yml`. All 80 ra8m1 entries matched at `5e7e8866cad`. Never hand-edit those files. Regenerate, then confirm no diff. Regeneration has not been verified yet.

## 4. Include paths for RSIP
- `rsip_sha256.h` includes `r_rsip.h`. The header is in the submodule `ra/fsp/src/r_rsip_protected/crypto_procedures_protected/src/rsip/ra/inc/instances/r_rsip.h`. It also needs `r_rsip_api.h` and `r_rsip_cfg.h` from the common folders.
- The protected driver's pack (`r_rsip_protected/!dsn/module.xml`, lines 17–23 and 41–47) declares these folders: `common/inc/api`, `common/primitive`, `common/private`, `common/public`, `ra/inc/instances`, `ra/primitive/<variant>`, `ra/private/<variant>`, `ra/public`, plus the lib folders for E5xx.
- `rm_mcuboot_port/!dsn/module.xml` (RSIP module section, lines 35–39) declares only `rsip/`. Builds without the driver's folders fail. Adding the driver folders to that module is an open option.
- Projects `ra8m1_ek_rsip_e51a_protected_rsa` and `…_fast_boot` in `projects/rm_mcuboot_port.xml` add the folders by hand (around lines 975 and 1101).
- The submodule pointer is `50f0ce54` in HEAD. The checkout may be `87a17fac`. Both contain `r_rsip.h`. Run `git submodule update --init --recursive ra/fsp/src/r_rsip_protected/crypto_procedures_protected` on build machines.

## 5. Build failures seen and their causes
| Error | Cause | Fix |
|---|---|---|
| `rsip_sha256.h:6 fatal error: r_rsip.h` in the unnamed default project (`rm_mcuboot_port_typical/overwrite/overwrite_fast`, ra8m1_ek) | That project compiles the whole `ra/fsp/src/rm_mcuboot_port` folder (`projects/rm_mcuboot_port.xml` line ~3102) with software crypto. The guard in `rsip_keys.c` had been removed. | Restore the guard in `rsip_keys.c`. Optional: exclude `protected_mode/rsip` in that project. |
| Same error in `ra8m1_ek_rsip_e51a_protected_fast_boot_typical` | Include folders not on the build path on that machine | Init the submodule; check the folder list above. |

## 6. Flash-key scripts
- New: `rm_mcuboot_port/!test/flash_with_key.sh <srec> <key_address_hex> <key_file>`. Checks arguments, SREC, hex address (no `0x`), and key file. Retries `rfp-cli` 20 times (1 s apart). Exits 1 if all fail.
- Old five scripts (`flash_with_key_{ecc,ecc_rsip,rsa,rsa_3072,rsa_rsip}.sh`) are thin wrappers. Each keeps its two-argument call and forwards to the new script with its key.
- Test harness (`fsp_test_parallel.py`, around line 506) runs `script <srec> <values of flash_script_args>`. Values are read from the project dict.
- `projects/rm_mcuboot_port.xml` test entries use `'flash_script_args': ['g_pub_key', 'pub_key_file']` and `'pub_key_file' : '<key>.rkey'` inside `test_info_init`. `g_pub_key` comes from `store_symbol_address` (ELF).
- Key mapping: RSA_pub.rkey (ra6m5 SCE9 RSA), ECC_pub_5.rkey (ra6m4 SCE9 fast boot), RSA_pub_rsip.rkey and ECC_pub_rsip.rkey (ra8m1 RSIP).
- The ra6e1 entry (`ra6e1_fpb_sce9_protected_ecc`) sits inside a disabled `<?ignore` block.
- Not yet run against RFP or hardware.

## 7. Process notes
- Reports for review live in `~/.claude/skills/code-review/`. Branch review: `branch_review.md`. PM reply: `flash_script_reply_to_PM.md`.
- Project repo commits are made by the user (commit policy in `common/important-rules`). Claude does not commit or push there.
- Skills repo edits are auto-committed by the PostToolUse hook when it fires. A log is written to `~/.claude/skill-autocommit.log`. When it doesn't fire, commit and push by hand.
- `rm_mcuboot_port.xml` project types: `boot_rsa` was removed in `9a88f39b796`. Use the `ra8m1_ek_rsip_e51a_protected_*` projects.

## 8. Open items
1. Confirm the `rsip_keys.c` guard restore is committed, then rebuild the four failing ra8m1 projects.
2. Decide: exclude `protected_mode/rsip` in the default project, and/or add driver include folders to the RSIP module.
3. Regenerate the ra8m1 linker files and confirm no diff.
4. Reply to Michael's review on `rsip_sha256.h` (section 2 explains the design).
5. Remove the five old flash scripts after a harness run.
6. Remove unused `BOOTUTIL_CRYPTO_SHA256_BLOCK_SIZE`.
