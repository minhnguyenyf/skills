# Review: FSPRA-5831_mcb_protected_ra8_hh vs develop

**Status:** Draft, not committed to the project repo. Written for the branch author.
**Base:** `develop` (merge-base `2d3e264b138`). **Head reviewed:** `5e7e8866cad` (2026-10-16). Branch head has since moved to `b7503c7aa0f` (about 30 commits later, not reviewed).

## Merge status (checked 2026-10-20)
- develop has head `236c7b25d83` merged via `c81c1342031`. That line is not an ancestor of `5e7e8866cad`.
- develop: `rsip_keys.c` includes `r_rsip_wrapper.h` inside the `MCUBOOT_USE_RSIP_PROTECTED` guard, defines `rsip_ctrl`/`rsip_cfg`, sets `g_pub_key_len_bytes` from `RSIP_OEM_KEY_SIZE_ECC_SECP256R1_PUBLIC_KEY_INST_DATA_WORD`. RSA 4096 not supported.
- Branch: RSA 4096 in `rsip_image_rsa.c` and `rsip_keys.h`; `g_pub_key_len_bytes` = `20 * 4U`; no `r_rsip_wrapper.h` include; protected-only cleanup; `MCUBOOT_RSIP_SHA_CTRL` removed; device gate on `interface.mcu.rsip.rsip_e51a_protected`.
- Open: which `rsip_keys.c` variant (include and length) is intended before the next merge.

## Findings at `5e7e8866cad`
| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | Blocking | ra8m1 linker files vs collected-file hashes | Fixed. 80/80 match (`ddsc-generated.yml` updated in `582559c593e`). Regeneration not yet confirmed. |
| 2 | High | SCE9 key section kept by ra8m1 linker scripts | Fixed. Boot and image scripts keep `.mcuboot_sce9_key` and `.mcuboot_wrapped_key` (gcc, llvm, iar, ac6). |
| 3 | Medium | Dead code in `rsip_image_rsa.c` | Fixed. `PSS_HLEN` still used. |
| 4 | Medium | Usage notes RSIP wording | Partly fixed. `rm_mcuboot_port/!dsn/rm_mcuboot_port_usage_notes.md` lines 597, 624-625, 648-649 still say "mcuboot_sce9_key or mcuboot_wrapped_key". RSIP steps should name `mcuboot_wrapped_key` only. |
| 5 | Medium | Submodule pointers | `ra/mcu-tools/MCUboot` back at develop `b839cbc4f84`. `crypto_procedures_protected` moved `4ee8bf03ada` to `87a17facd89`: needs sign-off, not diffed. |
| 6 | Low | Stray `\` after `</exclude>` in `projects/rm_mcuboot_port.xml` | Fixed. |
| 7 | Low | RFP script comments | `flash_with_key_rsa_rsip.sh` line 6 says `readelf`; the script takes the address as `$2`. Fix comment or script. |
| 8 | Low | Implicit `MCUBOOT_USE_RSIP_PROTECTED` define | Withdrawn. |

## Open items
1. Regenerate ra8m1 linker files through the generator; `git diff` must be empty.
2. Fix usage-note wording (item 4) and the RFP script comment (item 7).
3. Sign off the `crypto_procedures_protected` pointer.
4. Build `rm_mcuboot_port` for ra8m1_ek: SCE9 projects and `ra8m1_ek_rsip_e51a_protected_rsa` / `_fast_boot`. Check `.mcuboot_sce9_key` and `.mcuboot_wrapped_key` in the map files.
5. Run RSIP RSA and ECC tests on hardware.

## Single flash script (proposal)
- Replace the five per-key scripts with `flash_with_key.sh <srec> <key_address_hex> <key_file>`. Status: applied in a local worktree on branch `claude/flash-with-key-single-script`, not committed. The worktree may no longer exist.
- Applied fixes: shebang `#!/bin/bash` (the loop needs bash), SREC existence check, hex check on the address (rejects `0x`), key file check, exit 1 after 20 failed attempts, usage line.
- Harness: `flash_script_args` is now `['g_pub_key', 'key_file']` for the four active `rm_mcuboot_port.xml` entries (lines 764, 863, 980, 1107). The fifth entry (line 1235) is in a disabled `<?ignore` block.
- Mapping: `RSA_pub.rkey` (ra6m5 SCE9 RSA), `ECC_pub_5.rkey` (ra6m4 SCE9 fast boot), `RSA_pub_rsip.rkey` (ra8m1 RSIP RSA), `ECC_pub_rsip.rkey` (ra8m1 RSIP fast boot).
- Old scripts are thin wrappers that forward to the new script. Remove them after a harness run.
- Not run against RFP or hardware.

## Checks that look correct
- All 80 ra8m1 collected-file hashes match (checked from `git archive`).
- Both key sections kept in boot and image linker scripts for gcc, llvm, iar and ac6.
- No stray backslash in `rm_mcuboot_port.xml`.

## Not verified
- No build (gcc, llvm, ac6, iar), no hardware run.
- The 552-file diff was not read line by line. The RSIP CAVP tree (`ra/fsp/src/r_rsip_e11a_protected_cavp/!test/`) was only listed.
- `crypto_procedures_protected` commit not reviewed.
- Per the read restrictions in `common/important-rules`, `r_sce*` and `r_rsip_protected` contents were not read. Ask the user to check them.
