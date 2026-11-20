# Reply: single flash-with-key script (FSPRA-5831)

**Written for:** the project manager, as a reply to the review comment on the RFP key-install scripts.
**Branch:** `FSPRA-5831_mcb_protected_ra8_hh`, base `5e7e8866cad`.
**Status:** Changes are in the working tree, not committed. The author commits after review.

## Proposal
Replace the five key-install scripts in `rm_mcuboot_port/!test/` with `flash_with_key.sh <srec> <key_address_hex> <key_file>`.

Why: the five copies end with exit 0 even when RFP fails 20 times (a CI job reads that as success), and their comments name the wrong key in places.

## What changed
| Item | Change |
|---|---|
| `flash_with_key.sh` (new) | Checks argument count, SREC file, key address (hex, no `0x`), key file. Retries RFP up to 20 times. Exits 1 if all attempts fail. |
| Five old scripts | Thin wrappers. Keep the old two-argument call and forward to `flash_with_key.sh` with their own key. |
| `projects/rm_mcuboot_port.xml` | Four active entries pass the key file through `test_info_init` as `pub_key_file`. `flash_script_args` = `['g_pub_key', 'pub_key_file']`. Harness code unchanged. |

| Test project | Key file |
|---|---|
| `ra6m5_ek_sce9_protected_rsa` | `RSA_pub.rkey` |
| `ra6m4_ek_sce9_protected_fast_boot` | `ECC_pub_5.rkey` |
| `ra8m1_ek_rsip_e51a_protected_rsa` | `RSA_pub_rsip.rkey` |
| `ra8m1_ek_rsip_e51a_protected_fast_boot` | `ECC_pub_rsip.rkey` |

## Changes to the draft
1. Added `#!/bin/bash` (the draft used bash syntax with no shebang).
2. Kept the harness's two-argument call working by passing the key file through `test_info_init`.
3. Added an SREC existence check.
4. Added a hex check on the address (a `0x` prefix would be retried 20 times).
5. The last attempt no longer prints `Retry`.

## Testing so far
- Syntax check passes. Fake `rfp-cli` covered: wrong argument count, `0x` prefix, missing SREC, missing key, success, 20 failures (exit 1).
- XML parses; the four active entries resolve correctly. Each wrapper's key file exists.

## Not done
- Not run against the real RFP tool, the test harness, or hardware.

## Open questions
1. Delete the five wrappers now, or after one harness run? Suggested: after a harness run.
2. `flash_with_key_rsa_3072.sh` is not used by any entry on this branch. Keep or delete?
3. Is 20 attempts with a 1 s wait right for the libjlinkarm error?
