---
name: cch-psa-driver-scaffold
description: Use when adding a new CCH/PSA transparent driver algorithm or category to ra/fsp/src/rm_tf_psa_crypto (e.g. AES cipher, AES-GCM/CCM AEAD, MAC, RSA/ECDSA sign-verify, ECDH key agreement, entropy/TRNG, key management) so it follows the same 4-layer pattern as the existing rsip_cm_sha256 / rsip_cm_sha512 / rsip_cm_hash drivers. Triggers on "add a new PSA driver", "implement <algorithm> for rm_tf_psa_crypto", "wire up CCH for <algorithm>", "follow the SHA256/SHA512 pattern", or PRD entry points from Common FSP Crypto HAL / mbedTLS 4.0 TF-PSA-Crypto integration (Section 5.4.1).
---

# CCH / PSA driver scaffold (rm_tf_psa_crypto)

Layer diagrams (open with an SVG viewer for the full picture, not just the
text below):
- `cch_layer_model.svg` — the 4-layer stack (L4 Application → L3 TF-PSA-Crypto
  → L2.5 PSA Driver Shim → L2 CCH → L1 Engine Adapter [Protected /
  Compatibility / RL78 plaintext] → L0 Hardware Driver → Hardware), including
  the ultra-constrained direct-CCH bypass path.
- `cch_call_flow.svg` — worked example (`psa_sign_hash`) showing how
  `psa_driver_wrapper_sign_hash` in the L2.5 shim branches by algorithm: RSA/
  ECDSA → `cch_sign_hash` → L1 `rsip_cm_sign_hash`; ML-DSA/ML-KEM → PQC module
  (`pqc_sign_hash` → `R_PQC_MldsaSign*`, SW in v1); unsupported/no-HW → SW
  fallback via the TF-PSA-Crypto built-in library. Use this as the template
  for how a new category's `psa_driver_wrapper_<category>_<op>` should branch
  between CCH and SW fallback.

Reference implementation: SHA-256/SHA-384/SHA-512 hashing in
`ra/fsp/src/rm_tf_psa_crypto/`:
- `inc/rsip_cm_sha256.h`, `rsip_cm_sha256.c`
- `inc/rsip_cm_sha512.h`, `rsip_cm_sha512.c`
- `inc/rsip_cm_hash.h`, `rsip_cm_hash.c` (category dispatcher)
- `cch_crypto.h` (`cch_hash_*` inline wrappers)
- `tf_psa_crypto_driver_wrappers.h` (`psa_driver_wrapper_hash_*`)

Every PSA operation category (cipher, AEAD, MAC, hash, asymmetric sign/verify,
key agreement, key management, entropy) is implemented as **4 layers**. When
asked to add a new algorithm or category, read the matching reference file(s)
above first, then reproduce the same shape — do not invent a different
structure.

## Layer 1a — algorithm driver: `inc/rsip_cm_<algo>.h` + `rsip_cm_<algo>.c`

- File/struct/function names: `rsip_cm_<algo>_context`, `rsip_cm_<algo>_init`,
  `_free`, `_clone`, `_starts(...)`, `_update(ctx, input, ilen)`,
  `_finish(ctx, output)`, plus an internal `_process_ext` block-processing
  helper if the engine works in fixed-size blocks.
- All public functions except `init`/`free`/`clone` return `fsp_err_t`
  (`FSP_SUCCESS` / `FSP_ERR_CRYPTO_*`), never `psa_status_t` — mapping to PSA
  happens in the CCH layer.
- Wrap the whole `.c` body in `#if defined(PSA_WANT_ALG_<ALGO>) ... #endif`
  (or the relevant combination, see how sha256.c guards SHA-224/256 together).
- Branch on device capability with
  `BSP_FEATURE_RSIP_RSIP_E51A_SUPPORTED || BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED
  || BSP_FEATURE_RSIP_RSIP_E31A_SUPPORTED` when RSIP devices need extra state
  (e.g. `rsip_internal_state`, `rsip_buffer`) vs. the plain SCE path — mirror
  the `#else` branch in `rsip_cm_sha256.c` for SCE-only devices.
- Call the low-level engine primitives (`HW_SCE_*`) from
  `hw_sce_hash_private.h`-equivalent headers for the category; never call
  `mbedtls_internal_*` APIs (forbidden per PRD §5.4).
- Header includes `tf_psa_crypto_common.h` and `r_sce_if.h`, is wrapped in
  `#ifndef/#define <NAME>_H` and `extern "C"`, per `rsip_cm_sha256.h`.

## Layer 1b — category dispatcher: `inc/rsip_cm_<category>.h` + `rsip_cm_<category>.c`

Only create/extend this when the category doesn't already exist (`hash`
exists; `cipher`, `aead`, `mac`, `asymmetric`, `key_agreement`, `entropy`,
`key_management` do not yet).

- `rsip_cm_<category>_operation_t` holds `psa_algorithm_t alg` plus a
  `union { unsigned dummy; rsip_cm_<algo1>_context <algo1>; ... }` guarded per
  member by the same `PSA_WANT_ALG_*` macros as the member's own driver file
  (see `rsip_cm_hash.h`).
- Dispatcher functions (`_setup`, `_update`, `_finish`, `_abort`, `_clone`,
  and a one-shot `_compute` where the category has one, e.g. hash/mac/cipher)
  `switch (alg)` and call into the matching `rsip_cm_<algo>_*` function,
  `default: return FSP_ERR_CRYPTO_INVALID_SIZE`. Mirror `rsip_cm_hash.c`
  exactly for control flow and error codes.

## Layer 2 — CCH wrapper: add to `cch_crypto.h`

- Add `static inline fsp_err_t cch_<category>_<op>(...)` functions that call
  the Layer 1b dispatcher, following `cch_hash_setup/_update/_finish/_abort/
  _clone/_compute` verbatim as the template:
  - `_setup` rejects re-setup (`operation->alg != 0` guard), sets
    `operation->alg = alg` on success, calls `_abort` on failure.
  - `_finish` pre-fills the output buffer with `'!'` and validates
    `hash_size`/output-size against the PSA macro for the algorithm before
    calling the dispatcher (see `PSA_HASH_LENGTH` usage) — use the equivalent
    PSA size macro for the category (e.g. `PSA_MAC_LENGTH`,
    `PSA_AEAD_TAG_LENGTH`, `PSA_CIPHER_IV_LENGTH`).
  - `_compute` (when present) does setup→update→finish→abort with an
    `exit:` label, matching `cch_hash_compute`.

## Layer 3 — PSA driver wrapper: add to `tf_psa_crypto_driver_wrappers.h`

- Add `static inline psa_status_t psa_driver_wrapper_<category>_<op>(...)`
  functions matching the real TF-PSA-Crypto driver entry point signature
  (check PRD §5.4.1 for the exact entry point list/names, e.g.
  `cipher_encrypt_setup`, `aead_encrypt`, `mac_compute`, `sign_hash`,
  `key_agreement`).
- Structure exactly like `psa_driver_wrapper_hash_setup`:
  1. `#if defined(PSA_CRYPTO_TRANSPARENT_DRIVER)` — cast the operation's
     `ctx.mbedtls_ctx` to `rsip_cm_<category>_operation_t *`, call
     `cch_<category>_<op>`. On `FSP_SUCCESS` set `operation->id =
     MBEDTLS_TEST_TRANSPARENT_DRIVER_ID` and `return PSA_SUCCESS`. On
     anything other than `FSP_ERR_UNSUPPORTED`, `return
     PSA_ERROR_HARDWARE_FAILURE` (hardware-required ops must fail, not
     silently fall back — PRD §5.3).
  2. Fall through to the existing `mbedtls_psa_<category>_<op>` SW path,
     tagging `operation->id = PSA_CRYPTO_MBED_TLS_DRIVER_ID` on success.
- Add the new `#include "rsip_cm_<category>.h"` near the top alongside the
  existing `#include "rsip_cm_hash.h"`.

## Checklist for a new algorithm inside an existing category

(e.g. adding AES-CTR to a future `rsip_cm_cipher`)
1. `inc/rsip_cm_<algo>.h` + `rsip_cm_<algo>.c` (Layer 1a).
2. Add the union member + `case PSA_ALG_<ALGO>:` arms to
   `rsip_cm_<category>.h`/`.c` (Layer 1b) — no Layer 2/3 changes needed if the
   category dispatcher already routes generically by `operation->alg`.

## Checklist for a brand-new category

1. Layer 1a driver file(s) for each algorithm in the category.
2. Layer 1b dispatcher header/source (new files).
3. Layer 2 `cch_<category>_*` inline functions in `cch_crypto.h`, plus its
   `#include "rsip_cm_<category>.h"`.
4. Layer 3 `psa_driver_wrapper_<category>_*` functions in
   `tf_psa_crypto_driver_wrappers.h`, plus its include.
5. Cross-check entry point names/scope (Required vs Optional vs Out of Scope
   for v1) against PRD §5.4.1 before implementing — don't implement
   Out-of-Scope entry points, don't skip Required ones.
6. Add/extend the unit test suite under `!test/` (PRD §6.4 requires a suite
   per CCH functional group) and register it if `!test/psa_crypto_tests_setup.c`
   needs it.

## Conventions to preserve everywhere

- File header starts with `/* ${REA_DISCLAIMER_PLACEHOLDER} */`.
- Uses `fsp_err_t` below the CCH boundary, `psa_status_t` at/above the PSA
  wrapper boundary — never mix them.
- No `mbedtls_internal_*` symbols referenced from Layer 1/1b/2 (PRD §5.4).
- Guard every algorithm-specific block with its `PSA_WANT_ALG_*` (or
  `MBEDTLS_PSA_ACCEL_ALG_*`) macro so unused algorithms compile out.
- Engine adapters are plain translation units selected at build time — do
  **not** introduce function-pointer dispatch tables (PRD §7.2).
