---
name: netx
description: NetX secure crypto (rm_netx_secure_crypto) calling the SCE/RSIP adaptor layer. Use for undefined-reference or undeclared errors on HW_SCE_Ecc*ScalarMultiplicationSubAdaptor or DomainParam_Brainpool_* in rm_netx_secure_crypto, and for adding a per-engine adaptor stub.
---

# NetX secure crypto: adaptor layer

## Where the calls come from
- `ra/fsp/src/rm_netx_secure_crypto/*_alt_process.c` and `rm_netx_secure_crypto.c` call:
  - `HW_SCE_Ecc256ScalarMultiplicationSubAdaptor` (2 call sites)
  - `HW_SCE_Ecc384ScalarMultiplicationSubAdaptor` (1)
  - `HW_SCE_Ecc512ScalarMultiplicationSubAdaptor` (1)
  - `&DomainParam_Brainpool_512r1[0]` (ECDH, ECDSA, and the NetX driver)
- Every engine that builds NetX ECC must define all of these.

## Where they are defined
- Adaptor: `ra/fsp/src/r_sce/crypto_procedures/src/<engine>/plainkey/adaptors/r_sce_adapt.c`
- Declaration: `.../<engine>/plainkey/private/inc/hw_sce_ra_private.h`

## Per-engine status (512-bit ECC)
| Engine | Status |
|---|---|
| rsip_e50d, rsip_e51a | Real implementation |
| rsip_e11a, rsip_e31a, sce7, sce9 | Stub (`FSP_ERR_UNSUPPORTED`) added |
| sce5, sce5b | Stub added. Scalar `DomainParam` changed to array form |

## Stub pattern
- Same parameter list as the 384-bit adaptor.
- `FSP_PARAMETER_NOT_USED` on each argument, then `return FSP_ERR_UNSUPPORTED;`.
- The e11a `HW_SCE_Aes192EncryptDecryptInitSub` is the reference stub.
- Runtime effect: 512-bit ECDH returns `FSP_ERR_UNSUPPORTED` on stubbed engines.

## Dummy domain parameters
- Adaptor: `uint32_t const DomainParam_Brainpool_512r1[ECC_DUMMY_DOMAIN_PARAM_SIZE] = {0};`
- Header: `extern uint32_t const DomainParam_Brainpool_512r1[ECC_DUMMY_DOMAIN_PARAM_SIZE];`
- Size macro is `(1)`. sce5 and sce5b define it in their headers.
- Use the array form. `&X[0]` does not compile on a scalar, and a scalar definition conflicts with the array `extern`.

## Gotchas
- A header may already declare a function with the same signature (sce5b declares `Ecc256` at line 180). Don't add a second copy.
- Not verified by a build. Generated BSP headers are not in the repo.
- Related: `psa/mbedtls-v4-migration-notes/mbedtls-v3-notes.md` has the full adaptor coverage table for `rm_psa_crypto`.

## Branch FSPRA-5013_Support_ECC_bp512r1_PSA_NetX (status)
- Goal: Brainpool P-512 (bp512r1) ECDH and ECDSA in `rm_netx_secure_crypto`. Real support only on RSIP-E51A and RSIP-E50D. Other engines use the stubs above.
- Macros (`inc/rm_netx_secure_crypto.h`): `P512_CURVE_SIZE_BYTES` = 64. `LARGEST_FORMATTED_ECC_PUBLIC_KEY_WORDS` = 37 on E51A/E50D, else 32. `LARGEST_CURVE_SIZE_BYTES` follows the same split. `ECC_WRAPPED_KEY_SIZE(bits)` maps curves under 256 bits to the 256-bit wrapped size.
- Public key format: E11A, E31A, E51A and E50D return a plain X||Y key. SCE7 and SCE9 return a formatted key. Branch on `BSP_FEATURE_RSIP_RSIP_E51A/E50D_SUPPORTED`.
- Key generation for P-512 (`rm_netx_secure_crypto.c`) calls `HW_SCE_GenerateEccP512RandomKeyIndexSubAdaptor` on E51A and E50D only.
- Tests: `!test/rm_netx_secure_crypto_tests_tg3.c` changed. `!example/rm_netx_secure_crypto_example.c` added (about 187 lines).
- History (key commits): "Disable bp512r1 for NetX sw since library didn't support", "Modify ECDH max key size for NetX", "Add missing NetX bp512r1 ECDH implement".
- Uncommitted in the working tree: `nx_crypto_ecdh_alt_process.c` (not part of this note).
- Open: the link error for `HW_SCE_Ecc512ScalarMultiplicationSubAdaptor` is covered by the stubs. Check the sce5 and sce5b builds before relying on them.
