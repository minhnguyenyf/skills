---
name: mbedtls-to-psa-test-conversion
description: Converting or removing mbedtls_* calls in ra/fsp/src/rm_tf_psa_crypto/!test to the PSA API (ChaCha20, ChaCha20-Poly1305, AES-CMAC-PRF, AES-ECB), the open items, and the conversion pitfalls. Use when editing those test files.
metadata:
  type: reference
  branch: FSPRA-5629_MbedTLS_v4.1.0_TRNG_Sync
  compacted: 2026-11-01
---

# mbedtls_* to PSA conversion in rm_tf_psa_crypto/!test

Scope: the v4 test tree only. `ra/fsp/src/rm_psa_crypto/!test` (v3) keeps mbedTLS.

## Status (as of 2026-10-20; compile-checked with stubs, not run on hardware)
Converted:
- tg2: `TC_API_AESEncryptDecryptCMACPRF128` (RFC 4615)
- tg6: `TC_API_AESForCTRDRBG` (AES-ECB, one block)
- tg10: `TC_API_CHACHA20`, `_CHACHA20_stream_unaligned_data`, `_CHACHA20_stream`, `TC_API_CHACHAPOLY`, `_CHACHAPOLY_state_check`, `_CHACHAPOLY_Stream_EncryptDecrypt`

Removed (test, requirement comment, `RUN_TEST_CASE`, usage-note `@anchor`):
- tg1 `TC_API_SHA256MbedTLSCommonSelfTest` (`tf_sha256_hash`)
- tg10 `TC_API_POLY1305` (`tf_poly1305_mac`): PSA has no standalone Poly1305

Open, still mbedtls:
- tg3 `TC_API_RSAEncryptDecryptPKCS1V15` and `_OAEP`: the key is PEM. `psa_import_key` needs DER. Kept on mbedtls by decision.
- tg1 `TC_API_GenerateRandom`, `TC_API_ImportRawData`: `mbedtls_platform_get_entropy`, `mbedtls_psa_crypto_free`.
- tg3 helper `import_sign_verify_rsa` and the `RSAImportKeyPair*` tests.
- tg9 and tg11 PQC helpers (`mbedtls_mlkem_*`, `mbedtls_mldsa_*`).
- `MBEDTLS_PUT_UINT32_BE` (a macro from `core/alignment.h`). Left as is.

## Conversion patterns
- **ChaCha20:** PSA cannot set the initial counter. For counter N, call `psa_cipher_update` on N x 64 zero bytes and discard the output, then encrypt. Set the 12-byte nonce with `psa_cipher_set_iv`. Matches RFC 7539 vectors (checked in Python).
- **ChaCha20-Poly1305 one-shot:** `psa_aead_encrypt` writes ciphertext then a 16-byte tag. `psa_aead_decrypt` needs ciphertext and tag in one buffer.
- **Multipart and state checks:** `psa_aead_encrypt_setup`, `_set_nonce`, `_update_ad`, `_update`, `_finish`. `MBEDTLS_ERR_CHACHAPOLY_BAD_STATE` maps to `PSA_ERROR_BAD_STATE`. Use `PSA_AEAD_OPERATION_INIT` and `psa_aead_abort` between sub-cases.
- **AES-CMAC-PRF-128:** if the key is not 16 bytes, `K' = CMAC(0^128, K)`, then `CMAC(K', M)`. Both use `psa_mac_compute(PSA_ALG_CMAC)`. Usage `PSA_KEY_USAGE_SIGN_MESSAGE`. Checked against the three RFC vectors.
- **AES-ECB one block:** `psa_cipher_encrypt` with `PSA_ALG_ECB_NO_PADDING`, usage `PSA_KEY_USAGE_ENCRYPT`.
- **Key attributes:** declare with `PSA_KEY_ATTRIBUTES_INIT`. To reset in a loop: `attributes = (psa_key_attributes_t) PSA_KEY_ATTRIBUTES_INIT;`.

## Pitfalls
- Missing `psa_crypto_init()` gives -137 (`PSA_ERROR_BAD_STATE`) on `psa_import_key`. Call it after setting the attributes and before the first import (seen on ra2a1_ek and ra2a2_ek).
- PEM is not PSA input. Test keys in `ra/fsp/src/!test/crypto/test_data_rsa.c` are PEM. PSA needs PKCS#1 DER.
- Raw RSA components (`private_e_2048`, `public_e`) are numbers, not an importable key.
- Removing a test needs four edits: the test with its requirement comment, the `RUN_TEST_CASE` line in `psa_crypto_tests_runner.c`, the `@anchor` in `!dsn/rm_tf_psa_crypto_usage_notes.md`, and any unused `#include`.
- A scanner that reads to the next `TEST(` counts helpers as tests. Use "body ends at the next line that is exactly `}`".
- Files are CRLF. Python writes must keep `\r\n`. Check with `grep -c $'\r$'` against `wc -l`.
- zsh: write `"${VAR}:path"`, not `"$VAR:path"`. Run multi-line bash through a file.

## Verification without a full build
Generated BSP headers (`bsp_cfg.h`, `bsp_mcu_ofs_cfg.h`) are not in the repo, so the test files cannot compile on the host. Extract the test body, replace `TEST()` with a `void` function, add stubs for the `TEST_*` macros and `BSP_FEATURE_*`, then:
`gcc -std=c99 -Wall -Wextra -fsyntax-only -I ra/arm/mbedtls-v4/tf-psa-crypto/include -I ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include`
Algorithm correctness: check against vectors with Python `cryptography`.

## Rules
- Do not touch the v3 tree.
- Keep test names and requirement IDs unless the test is removed.
