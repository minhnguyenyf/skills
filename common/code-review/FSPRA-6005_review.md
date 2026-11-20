# Review: FSPRA-6005 (RSA/ECC updates aligned with new security policy) vs develop

**Status:** Draft, not committed to the project repo. Written for the branch author.
**Base:** `develop` `a16a55bdfc4` (branch 0 behind). **Head:** `39de99ecb67`. 17 commits, 14 files, +105 / -241.
**Scope limit:** `r_sce/`, `r_rsip_protected/`, `r_sce_protected/` were not read (user restriction). Items that depend on them are **Not verified**.

## Branch state
- Fast-forward mergeable.
- Other-ticket commits on the branch, to confirm: `d784d843b5b` (FSPRA-5831, PSA TG3/TG4 tests) and `653cf236ad6` (titled FSPRA-6275 "Add RN" but edits `FSPRA-6005.yml`).

## Verdict
Extends the E51A plaintext-key handling to RSIP-E50D across the PSA alt-process code, netx secure crypto, RSIP key-injection tests and PSA tests. Guard pattern is consistent. One preprocessor bug fixed (`rm_netx_secure_crypto/!test/rm_netx_secure_crypto_tests_tg3.c:480`, now `BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED == 0`).

**Not ready to merge until 2.1 is confirmed.**

| # | Severity | Finding | Status |
|---|---|---|---|
| 2.1 | High | E50D now uses the E51A call form (key-mode argument) in ECDSA sign and AES/RSA test calls | Not verified. Compare with E50D driver signatures (restricted path). |
| 2.2 | Medium | Plaintext RSA-2048 keygen (and 3072/4096) now enabled on E50D; develop said E50D does not support it | Behaviour change. Needs hardware test. |
| 2.3 | Medium | Release note (`documents/release_notes/upcoming/FSPRA-6005.yml`) does not mention 2.2. No trailing newline. | Open |
| 2.4 | Low | Commit titles do not match content (see above) | Confirm intent |
| 2.5 | Info | `r_sce/crypto_procedures` pointer `1933c1297f3` to `bed1080ab0f` (commit `2492bbaf788`) | Not verified (restricted) |

## 2.1 details
- `ra/fsp/src/r_rsip_key_injection/!test/hw_sce_ra_ecc.c`: `HW_SCE_EcdsaP256SignatureGenerate` and `HW_SCE_EcdsaP384SignatureGenerate` call `HW_SCE_EcdsaSignatureGenerateSub` / `HW_SCE_EcdsaP384SignatureGenerateSub` with `&indata_key_mode`. Develop had a separate E50D call without it.
- `ra/fsp/src/r_rsip_key_injection/!test/r_rsip_tests.c`: same pattern in `R_RSIP_AES` (ECB, XTS init) and `R_RSIP_RSA` (`HW_SCE_Rsa{2048,3072,4096}ModularExponentDecryptSub`, passes `&in_data_key_mode`).
- Failure: if E50D driver functions keep the develop argument list, the build fails on argument count.

## 2.2 details
- `rm_psa_crypto/rsa_alt_process.c`: `HW_SCE_RSA_2048KeyGenerate` and `mbedtls_rsa_gen_key` run the E50D path.
- `rm_psa_crypto/!test/psa_crypto_tests_tg3.c`: `TC_API_RSAGenerateKeyPairExportImport` no longer ignores E50D.
- `rm_psa_crypto/!dsn/rm_psa_crypto_usage_notes.md`: E50D "Key generation - plaintext" (RSA) changed `--` to `(3)`. Check footnote `(3)` matches the new behaviour.

## Correct as written
- Guard changes in `rm_psa_crypto/*_alt_process.c` and `rm_netx_secure_crypto/*_alt_process.c` add E50D beside E51A.
- ECC-256/384/521 wrap guards in `ecdsa_alt_process.c`; `ecp_alt_process.c` software-path guard `!(SCE7 || SCE9 || E51A || E50D)`.
- `psa_crypto_tests_tg4.c` ECC plaintext guard and ignore message name E50D.
- `in_data_key_mode` in `r_rsip_tests.c` RSA SIGN is declared in the `#if (E51A || E50D)` block that uses it.

## Not verified
- No build for any board; no hardware run. Review used `git diff` and `git show`.
- Restricted paths not read (affects 2.1, 2.5). Footnote `(3)` not read (2.2).

## Before merge
1. Confirm E50D signatures for `HW_SCE_EcdsaSignatureGenerateSub`, `HW_SCE_EcdsaP384SignatureGenerateSub`, AES XTS/ECB init, and RSA `ModularExponentDecryptSub`. Someone with access to restricted paths must do this.
2. Build RSIP-E50D test projects (ra8x2) and run RSA plaintext keygen tests on hardware.
3. Check footnote `(3)`.
4. Update the release note if 2.2 is user-visible; add trailing newline.
5. Confirm the `crypto_procedures` pointer change.
6. Confirm the FSPRA-5831 and FSPRA-6275 commits belong on this branch.
