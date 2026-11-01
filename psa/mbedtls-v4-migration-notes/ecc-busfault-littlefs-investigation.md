---
name: ecc-busfault-littlefs-investigation
description: TC_API_ECCGenerateKeyPairSignVerify256R1Persistent hard fault in v4 caused by a stale littlefs mlist pointer. Status is OPEN (test skipped on E31A only).
metadata:
  type: project
  compacted: 2026-11-01
---

# ECC persistent-key bus fault (open)

## Status
- Open. The root cause is not fixed.
- Workaround: `TC_API_ECCGenerateKeyPairSignVerify256R1Persistent` is skipped on E31A boards (`ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg5.c`, `#if BSP_FEATURE_RSIP_RSIP_E31A_SUPPORTED`). The test still runs on other boards and still faults on RA4C1 as far as known. Re-check before relying on it.
- An earlier note called this resolved. That was wrong: only the test skip was added.

## Symptom
- FORCED [30] hard fault on the first `psa_generate_key()` of a persistent ECC P-256 key. v3 passes the same test with the same config.
- BFSR 0x82 (PRECISERR and BFARVALID). BFAR is the same bad address on every run, so it is a deterministic stale pointer. It is not heap or stack exhaustion.

## Cause (source-verified)
- `lfs_fs_traverse_` at `lfs.c:4694` walks `lfs->mlist` (the open-file list). A stale entry has its `f->next` set to garbage.
- The walk runs only from `lfs_alloc()`, so the fault needs a block allocation. The larger v4 key blob crosses littlefs `inline_max` and triggers that allocation. v3 kept the blob inline.
- The defect is a dangling `mlist` entry, which some code path leaves behind. That code path is not yet identified.

## Ruled out
- `MBEDTLS_PSA_KEY_STORE_DYNAMIC` (no effect), heap size (no effect), main stack size (no effect), `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE` (inert without static slots).
- Volatile keys as a probe: -135 before generation, so the probe proves nothing.

## Next step
Set a watchpoint on `g_rm_littlefs_flash0_lfs.mlist`. It should be `NULL` after each ITS call. The write that leaves it non-NULL names the function. Details in `psa-storage-littlefs-stack.md`.

## Related hazard
`rm_stdio_littlefs.h` `fclose` is not wrapped in `do {} while (0)`. It can free a file handle that is still linked into `mlist`.
