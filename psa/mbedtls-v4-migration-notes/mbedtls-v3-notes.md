# mbedTLS v3 notes (v3-only findings)

Findings for the v3 tree (`ra/arm/mbedtls`, `rm_psa_crypto`). v3<->v4 diffs stay in `SKILL.md`.

## SCE/RSIP adaptor layer used by rm_psa_crypto (all crypto ops, not only ECC)

- `rm_psa_crypto/*_alt_process.c` calls 28 `HW_SCE_*Adaptor` functions: AES-128/192/256 init, RSA 1024–4096 encrypt and decrypt, ECDSA P-384/512/521 sign and verify, ECC random key-index generation, Ecc256/384/512/521 scalar multiplication, Ed25519.
- Each engine provides them in `ra/fsp/src/r_sce/crypto_procedures/src/<engine>/plainkey/adaptors/r_sce_adapt.c`, declared in `.../plainkey/private/inc/hw_sce_ra_private.h`.
- Definitions present per engine (of the 28): rsip_e50d 28, rsip_e51a 28, sce7 19, sce9 19, rsip_e11a 16, rsip_e31a 16, sce5 6, sce5b 6.
- rsip_e11a is missing 12 of the 28: ECDSA P-512 sign and verify, ECC P-512/P-521 random key-index, and RSA 1024–4096 encrypt and decrypt.
- Stub pattern (returns `FSP_ERR_UNSUPPORTED`): each argument gets `FSP_PARAMETER_NOT_USED`, then `return FSP_ERR_UNSUPPORTED;`. The e11a `HW_SCE_Aes192EncryptDecryptInitSub` is a reference stub.
- Dummy domain parameters: `uint32_t const DomainParam_Brainpool_<curve>[ECC_DUMMY_DOMAIN_PARAM_SIZE] = {0};` in the adaptor, `extern` in the private header. The size macro is `(1)` on engines that define it. sce5 and sce5b must use the array form: `&X[0]` does not compile on a scalar, and a scalar definition conflicts with the array `extern`.
- A header may already declare a function with the same signature (sce5b already declares `Ecc256` at line 180). A second identical declaration compiles, but don't add one.
- Status: the gap counts are from definitions in `r_sce_adapt.c` only. They are not verified by a build (the generated BSP headers are not in the repo). Whether these v3 call sites link on rsip_e11a and the SCE5/SCE7/SCE9 parts depends on the build config. Not checked.
