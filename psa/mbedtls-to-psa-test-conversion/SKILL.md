---
name: mbedtls-to-psa-test-conversion
description: How the rm_tf_psa_crypto test cases were converted from mbedtls_* calls to the PSA API (ChaCha20, ChaCha20-Poly1305, AES-CMAC-PRF, AES-ECB), what was removed, what is still open, and the pitfalls hit. Use when converting or removing mbedtls calls in ra/fsp/src/rm_tf_psa_crypto/!test.
metadata:
  type: reference
  branch: FSPRA-5629_MbedTLS_v4.1.0_TRNG_Sync
  recorded: 2026-10-20
---

# mbedtls_* to PSA conversion in rm_tf_psa_crypto/!test

Work done on the v4 test tree only. The v3 tree `ra/fsp/src/rm_psa_crypto/!test` must keep mbedtls and must not be converted.

## 1. Status

Converted to PSA (compile-checked with stubs, not run on hardware):
- `psa_crypto_tests_tg2.c`: `TC_API_AESEncryptDecryptCMACPRF128` (RFC 4615 AES-CMAC-PRF-128)
- `psa_crypto_tests_tg6.c`: `TC_API_AESForCTRDRBG` (AES-ECB single block)
- `psa_crypto_tests_tg10.c`: `TC_API_CHACHA20`, `TC_API_CHACHA20_stream_unaligned_data`, `TC_API_CHACHA20_stream`, `TC_API_CHACHAPOLY`, `TC_API_CHACHAPOLY_state_check`, `TC_API_CHACHAPOLY_Stream_EncryptDecrypt`

Removed (test, requirement comment, `RUN_TEST_CASE` line, and usage-note `@anchor`):
- `TC_API_SHA256MbedTLSCommonSelfTest` (tg1, requirement `tf_sha256_hash`)
- `TC_API_AESEncryptDecryptCMACPRF128` (tg2, requirement `tf_aes_cmac_prf_128`). Re-added later as a PSA conversion.
- `TC_API_POLY1305` (tg10, requirement `tf_poly1305_mac`). Removed because PSA has no standalone Poly1305 API.

Still on mbedtls (open):
- `TC_API_RSAEncryptDecryptPKCS1V15`, `TC_API_RSAEncryptDecryptOAEP` (tg3): key is PEM text. `psa_import_key` needs binary PKCS#1 DER. Tried a DER array copy of the key, then reverted to mbedtls on the user's decision.
- `TC_API_GenerateRandom`, `TC_API_ImportRawData` (tg1): `mbedtls_platform_get_entropy`, `mbedtls_psa_crypto_free`.
- Helper `import_sign_verify_rsa` and public-key import (tg3, about lines 560-614) used by the `RSAImportKeyPair*` tests.
- PQC helpers in tg9 and tg11 (`mbedtls_mlkem_*`, `mbedtls_mldsa_*`).
- `MBEDTLS_PUT_UINT32_BE` macro (from `tf-psa-crypto/core/alignment.h`) in several tg10 tests. A macro, not an API call; left as is.

## 2. Conversion patterns

- **ChaCha20 (`psa_cipher_*`, `PSA_ALG_STREAM_CIPHER`, `PSA_KEY_TYPE_CHACHA20`, 256-bit key):** PSA cannot set the initial block counter. For counter N, call `psa_cipher_update` on N x 64 zero bytes and discard the output, then encrypt. Set the 12-byte nonce with `psa_cipher_set_iv`. Verified in Python (cryptography) that this matches the RFC 7539 counter-1 vectors.
- **ChaCha20-Poly1305 one-shot:** `psa_aead_encrypt` writes ciphertext then the 16-byte tag. For decrypt, `psa_aead_decrypt` needs ciphertext and tag in one contiguous buffer (copy them together).
- **ChaCha20-Poly1305 multipart and state checks:** `psa_aead_encrypt_setup` / `psa_aead_set_nonce` / `psa_aead_update_ad` / `psa_aead_update` / `psa_aead_finish`. The mbedTLS `MBEDTLS_ERR_CHACHAPOLY_BAD_STATE` checks map to `PSA_ERROR_BAD_STATE`. Use `PSA_AEAD_OPERATION_INIT` and `psa_aead_abort` between sub-cases.
- **AES-CMAC-PRF-128 (RFC 4615):** if the key is not 16 bytes, `K' = AES-CMAC(0^128, K)`, then `CMAC(K', M)`. Both steps use `psa_mac_compute(PSA_ALG_CMAC)`. Verified in Python against the three test vectors. Key usage: `PSA_KEY_USAGE_SIGN_MESSAGE`.
- **AES-ECB single block:** `psa_cipher_encrypt` with `PSA_ALG_ECB_NO_PADDING`, usage `PSA_KEY_USAGE_ENCRYPT`.
- **Key attributes:** use `PSA_KEY_ATTRIBUTES_INIT` at declaration. To reset inside a loop, use `attributes = (psa_key_attributes_t) PSA_KEY_ATTRIBUTES_INIT;` (a brace initializer cannot be assigned directly).

## 3. Pitfalls hit

- **Missing `psa_crypto_init()` gives `-137` (`PSA_ERROR_BAD_STATE`) on `psa_import_key`**, not a heap or stack issue. The mbedTLS tests didn't need it. The fix, matching commit `1272559d41c`: call `TEST_ASSERT_EQUAL(PSA_SUCCESS, psa_crypto_init());` after the key attributes are set and before the first `psa_import_key`. This was seen on ra2a1_ek and ra2a2_ek.
- **PEM is not PSA input.** The default RSA keys in `ra/fsp/src/!test/crypto/test_data_rsa.c` are PEM strings. PSA needs PKCS#1 DER. A DER copy duplicates the key bytes; the team chose to keep mbedTLS for these tests.
- **Raw RSA components are not a key.** `private_e_2048` / `public_e` are numbers, not an importable format.
- **Standalone Poly1305 has no PSA API.** Remove the test (and its requirement and anchor), or keep mbedTLS. Removing leaves the requirement untraced.
- **Removing a test** means four edits: the test with its requirement comment, the `RUN_TEST_CASE` line in `psa_crypto_tests_runner.c`, the `@anchor` in `!dsn/rm_tf_psa_crypto_usage_notes.md`, and any now-unused `#include`.
- **Scanner pitfalls.** A scanner that reads until the next `TEST(` counts helper functions defined between tests, which gives false positives (e.g. `RSAGenerateKeyPairExportImportWrapped`). Use the rule "body ends at the next line that is exactly `}`" instead.
- **Line endings.** The files are CRLF. Python insertions with `\n` produced lines with a bare LF or a `\r\r\n`. After editing, check with `grep -c $'\r$'` against `wc -l`, and normalize if needed.
- **zsh and `$VAR:`.** In zsh, `"$R:path"` is parsed as a modifier. Use `"${R}:path"`. Bash-only heredocs inside `bash -c` also break zsh quoting; write the script to a file and run it with bash.

## 4. Verification method (no full build here)

The full `psa_crypto_tests_*.c` files need generated BSP headers (`bsp_cfg.h`, `bsp_mcu_ofs_cfg.h`) that are not in the repo, so they cannot be compiled on the host. Instead:
1. Extract the converted test body into a file.
2. Replace `TEST(...)` with a `void` function, and add stubs for `TEST_ASSERT_EQUAL`, `TEST_IGNORE_MESSAGE`, the `BSP_FEATURE_*` macros, and the test data arrays.
3. `gcc -std=c99 -Wall -Wextra -fsyntax-only -I ra/arm/mbedtls-v4/tf-psa-crypto/include -I ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include`.

Algorithm correctness can be checked in Python with `cryptography` (ChaCha20, ChaCha20-Poly1305, CMAC) against the test vectors.

## 5. Rules followed

- Don't touch `rm_psa_crypto` (v3), which needs mbedTLS.
- Commit only when the user asks. Project repo changes are committed by the user.
- Keep the test names and requirement IDs unless the test is removed.
