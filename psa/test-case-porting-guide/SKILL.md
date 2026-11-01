---
name: test-case-porting-checklist
description: Checklist for porting test cases between mbedTLS v3 and v4 (helper functions, API type changes, runner updates). Use when a ported test fails to link or is missing from the runner.
metadata:
  type: feedback
  compacted: 2026-11-01
---

# Test case porting checklist (v3 <-> v4)

## Steps
1. **Find missing tests.** Compare the TG files with `diff` on the sorted `TEST(` names. Check `wc -l` for both sides.
2. **Copy helpers, not just `TEST()`.** Tests call helpers such as `cipher_example_*`. Find them with `grep -n "^psa_status_t <name>"` and copy the declaration and the definition. Put them before the tests that use them. Search by name, never by position.
3. **Migrate API types while copying:**

| v3 | v4 |
|---|---|
| `psa_key_handle_t` | `psa_key_id_t` |
| `PSA_KEY_LIFETIME_IS_PERSISTENT(l)` | `(!PSA_KEY_LIFETIME_IS_VOLATILE(l))` |
| `psa_open_key()` | `psa_get_key_attributes()` (error `PSA_ERROR_INVALID_HANDLE`) |
| `mbedtls_pk_parse_key()` 7 args | 5 args (drop `f_rng`, `p_rng`) |

4. **Update the runner.** Add `RUN_TEST_CASE()` in `psa_crypto_tests_runner.c` after the related tests, in the file's existing order.
5. **Verify.** Count `TEST(PSA_CRYPTO_TG` and `RUN_TEST_CASE` on both sides. Check that every `^psa_status_t` helper exists.

## Pitfalls
- Copying only `TEST()` leaves link errors (missing helpers).
- Position-based searches miss tests. Search by name.
- Forgetting the type migration compiles but can fail at runtime.
- A test without a runner entry never runs, and nobody notices.

## Reference case
TG2 GCM: v3 had 25 AES tests and v4 had 23. The two missing were `TC_API_AESEncryptDecryptGCM_MultiPart` and `_ShortenedTag`. Their helpers were `cipher_example_encrypt_decrypt_aes_gcm_multipart_known_result` and the shortened-tag equivalent.
