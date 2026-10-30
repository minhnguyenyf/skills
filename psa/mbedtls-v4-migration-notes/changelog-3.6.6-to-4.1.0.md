# mbedtls 3.6.6 -> 4.1.0 + TF-PSA-Crypto 1.1.0: changelog digest

Reference for [SKILL.md](SKILL.md). Status: compacted 2026-10-30. Source: `ra/arm/mbedtls-v4/ChangeLog`, `tf-psa-crypto/ChangeLog`, `tf-psa-crypto/docs/1.0-migration-guide.md`. Old tree = mbedtls 3.6.6 (`ra/arm/mbedtls`). New tree = mbedtls 4.1.0 + TF-PSA-Crypto 1.1.0 (now 1.1.1 in this repo, see SKILL.md section 31). TLS, X.509 and DTLS changes are out of scope.

## Entropy and RNG (TRNG sync)
- `f_rng`/`p_rng` removed everywhere. Use `psa_generate_random()`. Call `psa_crypto_init()` first.
- `mbedtls/entropy.h` is private. No app-facing entropy API.
- Custom entropy: `mbedtls_hardware_poll()` (`MBEDTLS_ENTROPY_HARDWARE_ALT`, `<entropy_poll.h>`) becomes `mbedtls_platform_get_entropy(flags, &estimate_bits, output, output_size)` (`MBEDTLS_PSA_DRIVER_GET_ENTROPY`, `<mbedtls/platform.h>`). The callback fills the whole buffer. `estimate_bits` must be `8 * output_size`. Unknown flags return `PSA_ERROR_NOT_SUPPORTED`.
- Built-in entropy is opt-in: define `MBEDTLS_PSA_BUILTIN_GET_ENTROPY`. `MBEDTLS_NO_PLATFORM_ENTROPY` is removed.
- Removed config: `MBEDTLS_ENTROPY_*`, `MBEDTLS_CTR_DRBG_*` sizing, `MBEDTLS_HMAC_DRBG_*` sizing, `MBEDTLS_PSA_HMAC_DRBG_MD_TYPE`, `MBEDTLS_PSA_INJECT_ENTROPY`.
- New config: `MBEDTLS_PSA_CRYPTO_RNG_HASH`, `MBEDTLS_PSA_RNG_RESEED_INTERVAL`, `MBEDTLS_PSA_CRYPTO_RNG_STRENGTH` (default 256; 128 emulates the old 128-bit key).
- Error: `MBEDTLS_ERR_ENTROPY_SOURCE_FAILED` becomes `PSA_ERROR_INSUFFICIENT_ENTROPY`.
- 1.1.0: `psa_random_reseed()`, `psa_random_deplete()`, `psa_random_set_prediction_resistance()`.
- `MBEDTLS_THREADING_ALT` must also provide condition variables. `mutex_init` returns a status.

## Keys
- Removed: `psa_open_key`, `psa_close_key`, `PSA_KEY_HANDLE_INIT`, `psa_key_handle_t` (SKILL.md sections 3 and 4).
- Removed: `psa_get/set_key_domain_parameters`, `PSA_DH_FAMILY_CUSTOM`, `psa_generate_key_ext`, `psa_key_derivation_output_key_ext` (use `_custom` versions).
- Removed: `psa_can_do_hash`, `psa_can_do_cipher`.
- New: `MBEDTLS_PSA_STATIC_KEY_SLOTS` (with `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE`), `MBEDTLS_PSA_KEY_STORE_DYNAMIC`.
- New iop functions: `psa_generate_key_iop_setup`, `psa_key_agreement_iop_setup`, `psa_export_public_key_iop_setup`, and one-shot `psa_key_agreement()`.

## Cipher, AEAD, MAC, hash
- Only `PSA_WANT_*` enables algorithms. Removed: `MBEDTLS_AES_C`, `_ARIA_C`, `_CAMELLIA_C`, `_CCM_C`, `_CHACHA20_C`, `_CHACHAPOLY_C`, `_CIPHER_C`, `_CMAC_C`, `_DES_C`, `_GCM_C`, `_POLY1305_C`, `_MD5_C`, `_RIPEMD160_C`, `_SHA{1,224,256,384,512}_C`, `_SHA3_C`, and all `MBEDTLS_CIPHER_MODE_*` (including XTS).
- CBC supports PKCS7 padding only.
- DES and 3DES are removed. PKCS12 is removed with them.
- Headers now private: `cipher.h`, `aes.h`, `aria.h`, `camellia.h`, `ccm.h`, `chacha20.h`, `chachapoly.h`, `cmac.h`, `gcm.h`, `poly1305.h`, `block_cipher.h`, `des.h`. They still exist under `drivers/builtin/include/mbedtls/private/` (SKILL.md section 1).
- `mbedtls/hkdf.h` removed. Use `PSA_ALG_HKDF`.
- `mbedtls_md_setup()` requires `hmac == 0`. MD HMAC functions are removed. Use `psa_mac_*`.
- New: SHAKE128 and SHAKE256 (`PSA_ALG_SHAKE*`, 1.1.0).
- 1.1.0 fixes: `mbedtls_ccm_finish()` validates tag length; GCM tag bug on GCC 10.0 to 14.2 at -O3 without AES hardware (host builds only).

## Public key (PK), RSA, ECC
- `mbedtls_pk_type_t` becomes `mbedtls_pk_sigalg_t` (`MBEDTLS_PK_SIGALG_RSA_PKCS1V15`, `_RSA_PSS`, `_ECDSA`, `_NONE`).
- Removed from the PK API: `mbedtls_pk_setup`, `pk_get_len`, `pk_can_do`, `pk_debug`, `pk_get_name`, `pk_get_type`, `pk_rsa()`, `pk_ec()`, `pk_parse_subpubkey`, `pk_write_pubkey`, `pk_verify_new`, `pk_encrypt`, `pk_decrypt` (use `psa_asymmetric_*`), `MBEDTLS_PK_RSA_ALT`.
- Renamed: `mbedtls_pk_can_do_ext` becomes `mbedtls_pk_can_do_psa`. `mbedtls_pk_setup_opaque` becomes `mbedtls_pk_wrap_psa`. `mbedtls_pk_parse_subpubkey` becomes `mbedtls_pk_parse_public_key`. `mbedtls_pk_write_pubkey` becomes `mbedtls_pk_write_pubkey_der`.
- RNG args removed from `pk_sign`, `pk_sign_ext`, `pk_sign_restartable`, `pk_check_pair`, `pk_parse_key`, `pk_parse_keyfile`, and `mbedtls_pk_rsa_alt_sign_func` (SKILL.md section 2).
- `pk_verify_ext` ignores the PSS salt-length option. Use `psa_verify_hash()` with `PSA_ALG_RSA_PSS` to enforce salt length.
- `MBEDTLS_ERR_PK_SIG_LEN_MISMATCH` is gone. Trailing data is just an invalid signature.
- New: `MBEDTLS_PK_ALG_ECDSA(hash)`, `mbedtls_pk_get_key_type()`, `mbedtls_pk_write_pubkey_psa()` (1.1.0).
- Removed headers: `bignum.h`, `rsa.h`, `ecp.h`, `ecdh.h`, `ecdsa.h`, `ecjpake.h`, `dhm.h`. Removed config: `MBEDTLS_GENPRIME`, `MBEDTLS_PKCS1_V15`, `MBEDTLS_PKCS1_V21`, `MBEDTLS_RSA_C`, `MBEDTLS_ECDH_C`, `MBEDTLS_ECDSA_C`, `MBEDTLS_ECDSA_DETERMINISTIC`, `MBEDTLS_ECJPAKE_C`, `MBEDTLS_ECP_C`, `MBEDTLS_ECP_DP_*_ENABLED`, `MBEDTLS_BIGNUM_C`. Use `PSA_WANT_*`.
- Curves up to 224 bits are removed (secp192r1, secp192k1, secp224r1, secp224k1).
- Removed: `mbedtls_ecc_group_to_psa()` and `mbedtls_ecc_group_from_psa()`.
- 1.1.0 fixes: FFDH export buffer overflow, FFDH peer-key validation. Perf: RSA private key regression (partial fix).
- `pk.c` moves PSA stack buffers over 2 KB to heap (1.1.0).

## PQC and LMS
- No ML-KEM or ML-DSA entries upstream. Renesas PQC library is separate (SKILL.md section 5).
- LMS stays. `mbedtls_lms_generate_private_key()` and `mbedtls_lms_sign()` lost the RNG args.

## NIST KW
- `mbedtls_nist_kw_wrap/unwrap` take a PSA key ID and return `psa_status_t`. The context type and init/free/setkey/self_test functions are removed.

## Build and headers
- Crypto moved to TF-PSA-Crypto: `core/`, `drivers/builtin/src/`, `drivers/builtin/include/mbedtls/private/`, `include/psa/`. New dirs: `extras/`, `platform/`, `utilities/`, `dispatch/`.
- Config file: `TF_PSA_CRYPTO_CONFIG_FILE` and `TF_PSA_CRYPTO_USER_CONFIG_FILE`. `MBEDTLS_PSA_CRYPTO_CONFIG_FILE` and `MBEDTLS_PSA_CRYPTO_USER_CONFIG_FILE` are not recognized. The project already uses the v4 name.
- Removed options: `MBEDTLS_PSA_CRYPTO_CONFIG`, `MBEDTLS_USE_PSA_CRYPTO` (both always on), `MBEDTLS_OID_C`, `MBEDTLS_PADLOCK_C`, `MBEDTLS_PSA_CRYPTO_SE_C`, `mbedtls/check_config.h`.
- Removed: all crypto `MBEDTLS_*_ALT` (platform, threading and timing ALT remain). Use PSA drivers.
- Removed PSA config: `PSA_WANT_KEY_TYPE_{ECC,RSA}_KEY_PAIR`, and the `MBEDTLS_PSA_{BUILTIN,ACCEL}_KEY_TYPE_*_KEY_PAIR` forms.
- `mbedtls_version_get_string()` and `_full()` take no args and return `const char*`. New `<tf-psa-crypto/version.h>`.

## Errors
- Unified space: `mbedtls_*` can return `PSA_ERROR_*` directly. `mbedtls_low_level_strerr` and `mbedtls_high_level_strerr` are removed. Use `mbedtls_strerror`.
- Common mappings: `*_BAD_INPUT[_DATA]` becomes `PSA_ERROR_INVALID_ARGUMENT`. `*_ALLOC_FAILED` becomes `PSA_ERROR_INSUFFICIENT_MEMORY`. `*_[AUTH|VERIFY]_FAILED` becomes `PSA_ERROR_INVALID_SIGNATURE`. `*_BUFFER_TOO_SMALL` and `*_OUTPUT_TOO_LARGE` become `PSA_ERROR_BUFFER_TOO_SMALL`. `*_INVALID_PADDING` becomes `PSA_ERROR_INVALID_PADDING`.
- `MBEDTLS_ERR_ECP_IN_PROGRESS` becomes `PSA_OPERATION_INCOMPLETE`. `MBEDTLS_ERR_RSA_VERIFY_FAILED` becomes `PSA_ERROR_INVALID_SIGNATURE`.
- Full table: migration guide (about lines 384 to 436).

## Already true in 3.6.6 (not a v4 change)
- CVE-2024-45157/45158/45159 and CVE-2024-49195 are fixed.
- CCM* message length check and zero-length AEAD AD fix.
- `psa_import_key()` accepts only PSA-standard RSA formats (since 3.6.0).
