# Reply: single flash-with-key script (FSPRA-5831)

**Written for:** the project manager, as a reply to the review comment on the RFP key-install scripts.
**Branch:** `FSPRA-5831_mcb_protected_ra8_hh`, base `5e7e8866cad`.
**Status:** Changes are in the working tree, not yet committed.

---

## 1. Your suggestion

Replace the five key-install scripts in `rm_mcuboot_port/!test/` with one script:

```
flash_with_key.sh <srec> <key_address_hex> <key_file>
```

The key file becomes an argument instead of being hard-coded in each script.

## 2. Why it was suggested

The five scripts were copy-pasted. Each one is about 20 lines and differs only in its key file name. Two problems follow from that:

- **Silent failure.** If RFP fails 20 times, each script ends without an error code, so it exits with 0. A test run or CI job reads that as success, even though the key was never installed. This is the most important problem.
- **Copy-paste errors.** Comments name the wrong key (for example, the RSA script says `ECC_pub_5.rkey`). Each script also trusts its arguments without checking them.

One script with an explicit key file fixes both problems in one place.

## 3. What we changed

| Item | Change |
|---|---|
| `flash_with_key.sh` (new) | Checks the argument count, the SREC file, the key address (hex, no `0x`), and the key file. Retries RFP up to 20 times. Exits 1 if all attempts fail. |
| Five old scripts | Now thin wrappers. Each keeps its old two-argument call and forwards to `flash_with_key.sh` with its own key. Existing callers keep working. |
| `projects/rm_mcuboot_port.xml` | Four active test entries call `flash_with_key.sh` and pass the key file name through the existing `test_info_init` mechanism. The harness code does not change. |

Key mapping:

| Test project | Key file |
|---|---|
| `ra6m5_ek_sce9_protected_rsa` | `RSA_pub.rkey` |
| `ra6m4_ek_sce9_protected_fast_boot` | `ECC_pub_5.rkey` |
| `ra8m1_ek_rsip_e51a_protected_rsa` | `RSA_pub_rsip.rkey` |
| `ra8m1_ek_rsip_e51a_protected_fast_boot` | `ECC_pub_rsip.rkey` |

## 4. Changes to your draft

The draft was a good base. We made these changes before adopting it:

1. **Missing shebang.** The draft has no `#!/bin/bash` line. The loop uses bash syntax, so under `sh` it would fail. Added.
2. **Callers would break.** The test harness passes two arguments (the SREC and the key address). The draft requires three, so every test entry would fail. We pass the key file through the existing `test_info_init` field, so the harness doesn't change.
3. **No SREC check.** Added a file-exists check.
4. **No address check.** A `0x` prefix would become `0x0x…` and be retried 20 times. Added a hex check.
5. **Retry message.** The last attempt no longer prints `Retry`.

## 5. Testing so far

- Syntax check passes for every script.
- The new script was run with a fake `rfp-cli` (a stub that logs its arguments) in a scratch folder, covering:
  - wrong argument count
  - `0x` prefix
  - missing SREC
  - missing key
  - success
  - 20 failed attempts (exit 1)
- The XML parses. The four active entries resolve to the right arguments.
- Each wrapper names a key file that exists.

## 6. Not yet done

- Not run against the real RFP tool.
- Not run through the test harness on a board.
- No hardware test.

## 7. Questions for you

1. Should we delete the five old wrapper scripts now, or after one harness run? I suggest after a harness run.
2. `flash_with_key_rsa_3072.sh` is not used by any test entry on this branch. Keep it as a wrapper, or delete it?
3. Is the 20-attempt limit and the one-second wait right for the libjlinkarm error?

## 8. Summary for your reply

We adopted the single script, with the fixes above. It stops reporting success when the key install fails, and the test entries pass the key file explicitly. The old scripts remain as wrappers until a harness run confirms the new path. The changes are in the working tree of `FSPRA-5831_mcb_protected_ra8_hh`, and the author will commit them after review.
