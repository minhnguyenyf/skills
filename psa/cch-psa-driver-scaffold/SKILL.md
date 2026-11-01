---
name: cch-psa-driver-scaffold
description: Use when adding a PSA transparent driver algorithm or category (cipher, AEAD, MAC, sign/verify, key agreement, entropy, key management) to ra/fsp/src/rm_tf_psa_crypto through the 4-layer CCH pattern. Triggers on "add a new PSA driver", "wire up CCH for <algorithm>", or "follow the SHA pattern".
---

# CCH / PSA driver scaffold (rm_tf_psa_crypto)

Status: compacted 2026-11-01. Checked: `cch_crypto.h` and `tf_psa_crypto_driver_wrappers.h` exist in `ra/fsp/src/rm_tf_psa_crypto/`. The `rsip_cm_*` reference files named in the older version of this note are NOT in the repo. The pattern below is a design template, not existing code. Confirm the file names with `git ls-files` before you copy them.

Diagrams: `cch_layer_model.svg` (4-layer stack) and `cch_call_flow.svg` (`psa_sign_hash` branching) in this folder.

## Layers
- **L1a algorithm driver** (`inc/rsip_cm_<algo>.h/.c`): `_context`, `_init`, `_free`, `_clone`, `_starts`, `_update`, `_finish`. Returns `fsp_err_t`, never `psa_status_t`. Guard the file with `#if defined(PSA_WANT_ALG_<ALGO>)`. Branch on RSIP capability (`BSP_FEATURE_RSIP_RSIP_E51A/E50D/E31A_SUPPORTED`) only when the engine needs extra state. Call only `HW_SCE_*` primitives, never `mbedtls_internal_*`.
- **L1b category dispatcher** (`inc/rsip_cm_<category>.h/.c`): an operation struct holding `psa_algorithm_t alg` and a union of per-algorithm contexts. `switch (alg)` in `_setup`, `_update`, `_finish`, `_abort`, `_clone`, and optionally `_compute`. `default:` returns `FSP_ERR_CRYPTO_INVALID_SIZE`. Create only for new categories. Hash is the existing one, and the others are not yet written.
- **L2 CCH** (`cch_crypto.h`): `static inline cch_<category>_<op>()`. `_setup` rejects re-setup (`alg != 0`). `_finish` checks output size with the PSA size macro (`PSA_HASH_LENGTH`, `PSA_MAC_LENGTH`, `PSA_AEAD_TAG_LENGTH`, `PSA_CIPHER_IV_LENGTH`).
- **L3 PSA wrapper** (`tf_psa_crypto_driver_wrappers.h`): `psa_driver_wrapper_<category>_<op>()`.
  1. Under `PSA_CRYPTO_TRANSPARENT_DRIVER`: call the CCH function. On `FSP_SUCCESS`, set the driver ID and return `PSA_SUCCESS`. Any error other than `FSP_ERR_UNSUPPORTED` returns `PSA_ERROR_HARDWARE_FAILURE`. Hardware-required ops must not fall back silently.
  2. Otherwise fall through to the `mbedtls_psa_<category>_<op>` software path.

## Adding an algorithm to an existing category
1. Layer 1a file for the algorithm.
2. Add the union member and `case PSA_ALG_<ALGO>:` to the category dispatcher. No L2 or L3 change if dispatch is by `alg`.

## Adding a new category
1. Layer 1a files for each algorithm.
2. Layer 1b dispatcher.
3. Layer 2 `cch_<category>_*` in `cch_crypto.h`.
4. Layer 3 `psa_driver_wrapper_<category>_*` in `tf_psa_crypto_driver_wrappers.h`.
5. Check the required and optional entry points against the PRD before coding. Do not implement out-of-scope ones.
6. Add a unit test suite in `!test/` and register it in `psa_crypto_tests_setup.c` if needed.

## Conventions
- File header: `/* ${REA_DISCLAIMER_PLACEHOLDER} */`.
- `fsp_err_t` below the CCH boundary, `psa_status_t` at and above the PSA wrapper. Never mix.
- No `mbedtls_internal_*` in layers 1, 1b or 2.
- Guard each algorithm with `PSA_WANT_ALG_*` (or `MBEDTLS_PSA_ACCEL_ALG_*`).
- Engine adapters are selected at build time. No function-pointer dispatch tables.
