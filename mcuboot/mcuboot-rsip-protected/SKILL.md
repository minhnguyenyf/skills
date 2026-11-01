---
name: mcuboot-rsip-protected
description: MCUboot RSIP protected-mode work for RA8M1/RA8D1 (RSIP-E51A): module gating, key sections, include paths, flash-key scripts, and known build failures. Use when touching rm_mcuboot_port custom_crypto_stacks/protected_mode/rsip, rm_mcuboot_rsip_protected_mode, ra8m1 linker key sections, or flash_with_key*.sh.
metadata:
  type: reference
  branch: FSPRA-5831_mcb_protected_ra8_hh
  compacted: 2026-11-01
---

# MCUboot RSIP protected mode (FSPRA-5831)

Status: compacted 2026-11-01. Verify line numbers on the branch before use. Resolved issues are removed. Open items are at the end.

## Devices
- `MCUBOOT_USE_RSIP_PROTECTED` is set only when `BSP_FEATURE_RSIP_RSIP_E51A_SUPPORTED` is 1 (`test_files/ra_cfg/mcu-tools/include/mcuboot_config/mcuboot_config.h`).
- E51A: RA8M1, RA8D1, RA8E1, RA8E2. RA8M2 is E50D only.
- Module gate (`rm_mcuboot_port/.module_descriptions/Renesas##Middleware##all##rm_mcuboot_rsip_protected_mode####x.xx.xx.xml`, line 6): `("${interface.mcu.rsip.sce9}" !== "1") && ("${interface.mcu.rsip.rsip_e51a_protected}" === "1")`. In HEAD (`be04a355f99`).

## Code state
- `rsip/rsip_sha256.h`: protected-only. `bootutil_sha_context` is `uint32_t`, and calls pass `&rsip_ctrl`.
- `rsip/rsip_image_ec256.c` and `rsip/rsip_ecdsa_p256.h`: non-protected branches removed (`be04a355f99`). The old software ECDSA used a plaintext key table that RSIP builds do not link. Old code is in `5e7e8866cad`.
- `rsip/rsip_keys.c`: `rsip_ctrl`, `rsip_cfg` and the `rsip_sha256.h` include must stay inside `#if defined(MCUBOOT_USE_RSIP_PROTECTED)`. Removing the guard breaks every project that compiles the whole `rm_mcuboot_port` folder.
- Unused: `BOOTUTIL_CRYPTO_SHA256_BLOCK_SIZE` in `rsip_sha256.h`.

## Key sections and linker
- RSIP key section: `.mcuboot_wrapped_key`. SCE9 uses `.mcuboot_sce9_key`.
- ra8m1 boot and image linker scripts keep both sections for gcc, llvm, iar and ac6 (`ra/fsp/src/bsp/mcu/ra8m1/!linker/`).
- Generator: `scripts/mcu_xml_gen/templates/linker_policy_template.j2` (two `keep: True` entries).
- Collected-file hashes: `data/collected-files/ddsc-generated.yml`. All 80 ra8m1 entries matched at `5e7e8866cad`. Never hand-edit these files. Regeneration is not yet verified.

## Include paths
- `rsip_sha256.h` includes `r_rsip.h` from `ra/fsp/src/r_rsip_protected/crypto_procedures_protected/src/rsip/ra/inc/instances/`. It also needs `r_rsip_api.h` and `r_rsip_cfg.h` from the common folders.
- The protected driver's pack declares the folders. `rm_mcuboot_port/!dsn/module.xml` (RSIP section) declares only `rsip/`. Builds without the driver folders fail.
- Projects `ra8m1_ek_rsip_e51a_protected_rsa` and `_fast_boot` add the folders by hand in `projects/rm_mcuboot_port.xml`.
- Submodule pointer in HEAD: `50f0ce54`. Init on build machines with `git submodule update --init --recursive ra/fsp/src/r_rsip_protected/crypto_procedures_protected`.

## Build failures (causes and fixes)
- `rsip_sha256.h: fatal error: r_rsip.h` in the default `rm_mcuboot_port` project: that project compiles the whole port folder with software crypto. Fix: keep the guard in `rsip_keys.c`. Optional: exclude `protected_mode/rsip` in that project.
- Same error in `ra8m1_ek_rsip_e51a_protected_fast_boot_typical`: include folders missing on that machine. Init the submodule.

## Flash-key scripts
- `rm_mcuboot_port/!test/flash_with_key.sh <srec> <key_address_hex> <key_file>`. Checks arguments, SREC, hex address (no `0x`) and key file. Retries `rfp-cli` 20 times, 1 s apart. Exits 1 on failure.
- The five old scripts (`flash_with_key_{ecc,ecc_rsip,rsa,rsa_3072,rsa_rsip}.sh`) are thin wrappers that forward to the new script.
- Harness (`fsp_test_parallel.py`, around line 506) runs `script <srec> <flash_script_args values>`. Entries in `projects/rm_mcuboot_port.xml` use `'flash_script_args': ['g_pub_key', 'pub_key_file']`.
- Key mapping: `RSA_pub.rkey` (ra6m5 SCE9 RSA), `ECC_pub_5.rkey` (ra6m4 SCE9 fast boot), `RSA_pub_rsip.rkey` and `ECC_pub_rsip.rkey` (ra8m1 RSIP).
- Not yet run against RFP or hardware.

## Process
- Review reports: `~/.claude/skills/code-review/` (`FSPRA-5831_review.md`, `FSPRA-5831_flash_script_reply_to_PM.md`).
- Project repo commits are made by the user. Skills repo edits are committed by the hooks.
- The `boot_rsa` project type was removed in `9a88f39b796`. Use the `ra8m1_ek_rsip_e51a_protected_*` projects.

## Open items
1. Confirm the `rsip_keys.c` guard restore is committed, and rebuild the four failing ra8m1 projects.
2. Decide whether to exclude `protected_mode/rsip` from the default project, and/or add the driver include folders to the RSIP module.
3. Regenerate the ra8m1 linker files and confirm no diff.
4. Reply to the review comment on `rsip_sha256.h`.
5. Remove the five old flash scripts after a harness run.
6. Remove `BOOTUTIL_CRYPTO_SHA256_BLOCK_SIZE`.
