# mbedtls 3.6.6 -> mbedtls 4.1.0 + TF-PSA-Crypto 1.1.0: full changelog digest

Reference material for [SKILL.md](SKILL.md). Compiled from:
- `ra/arm/mbedtls-v4/ChangeLog` (lines 1-337: the 4.1.0 and 4.0.0 branch
  sections only, before it hits the old "3.6.0 branch" header)
- `ra/arm/mbedtls-v4/tf-psa-crypto/ChangeLog` (full — covers TF-PSA-Crypto
  1.1.0 and 1.0.0; this library didn't exist separately in the v3/mbedtls
  3.6.6 tree, it was split out of mbedtls in v4)
- `ra/arm/mbedtls-v4/tf-psa-crypto/docs/1.0-migration-guide.md` (full)
- `ra/arm/mbedtls/ChangeLog` (old tree, 3.6.1/3.6.2 sections) — used only to
  sanity-check the 3.6.6 baseline, so changes already present by 3.6.2 aren't
  misattributed to the v4 port.

Scope: PSA Crypto API surface only (`psa_*`, `mbedtls_*` driver/test-facing
APIs, build config symbols, header relocations). TLS/SSL record-layer,
X.509/certificate and DTLS-only changes are excluded — this codebase only
consumes the crypto library, not the TLS stack.

Versions confirmed in this repo: old tree `ra/arm/mbedtls` = 3.6.6
(`include/mbedtls/build_info.h`); new tree `ra/arm/mbedtls-v4` = mbedtls
4.1.0 + TF-PSA-Crypto 1.1.0 (`include/mbedtls/version.h`,
`tf-psa-crypto/include/tf-psa-crypto/build_info.h`).

## Entropy / RNG (high priority — this branch is the "TRNG Sync" task)

1. **RNG callbacks eliminated everywhere.** No more `f_rng`/`p_rng` params on
   `mbedtls_*()`/`psa_*()` functions — everything uses `psa_generate_random()`
   internally. `psa_crypto_init()` must be called before any crypto op.
   (TF-PSA-Crypto ChangeLog 1.0.0 "API changes"; migration guide ~L244-250,
   L475-477.)
2. **`mbedtls/entropy.h` removed from the public API entirely** — the
   entropy module is now fully internal/private. No app-facing entropy
   interface. (migration guide L294.)
3. **Custom entropy collector callback replaced.**
   - Old (v3): `MBEDTLS_ENTROPY_HARDWARE_ALT` +
     `int mbedtls_hardware_poll(void *data, unsigned char *output, size_t len, size_t *olen)`
     from `<entropy_poll.h>`.
   - New (v4): `MBEDTLS_PSA_DRIVER_GET_ENTROPY` +
     `int mbedtls_platform_get_entropy(psa_driver_get_entropy_flags_t flags, size_t *estimate_bits, unsigned char *output, size_t output_size)`
     from `<mbedtls/platform.h>`.
   - Differences: `data` param gone (was always NULL anyway); no `olen`
     output — the callback must fill the *entire* `output` buffer; new
     `flags` param (always 0 in 1.0/1.1 — driver must return
     `PSA_ERROR_NOT_SUPPORTED` for any unrecognized flag bit); new
     `estimate_bits` out-param which, as of TF-PSA-Crypto 1.0, **must equal
     `8 * output_size`** (full entropy required — partial-entropy reporting
     isn't supported yet).
   - (migration guide L776-801 has both prototypes verbatim; TF-PSA-Crypto
     ChangeLog 1.0.0 "API changes" ~L163-167.)
   - **This is almost certainly the core rename needed for the
     FSPRA-5629 TRNG sync work** — search this codebase's TRNG/entropy glue
     for `mbedtls_hardware_poll` and replace with
     `mbedtls_platform_get_entropy` using the new signature.
4. **Built-in entropy source is now opt-in via a positive macro.** Old:
   default entropy source included unless `MBEDTLS_NO_PLATFORM_ENTROPY` was
   defined. New: must explicitly `#define MBEDTLS_PSA_BUILTIN_GET_ENTROPY`
   (on by default for common OSes; a from-scratch custom config must define
   it explicitly). `MBEDTLS_NO_PLATFORM_ENTROPY` is removed entirely.
   (migration guide L675-677, L693; TF-PSA-Crypto ChangeLog 1.0.0
   "Removals".)
5. **"No entropy source at all" mode removed.** Old
   `MBEDTLS_NO_DEFAULT_ENTROPY_SOURCES` has no direct 1.0 counterpart. If
   only an NV seed is used, must additionally enable the new
   `MBEDTLS_ENTROPY_NO_SOURCES_OK`. (migration guide table L746-773,
   L683-687, L809.)
6. **Config-option renames/removals for entropy/DRBG**
   (TF-PSA-Crypto ChangeLog 1.0.0 "API changes"/"Removals"):
   - Removed: `MBEDTLS_ENTROPY_C`, `MBEDTLS_ENTROPY_FORCE_SHA256`,
     `MBEDTLS_ENTROPY_MAX_GATHER`, `MBEDTLS_ENTROPY_MAX_SOURCES`,
     `MBEDTLS_ENTROPY_MIN_HARDWARE`, `MBEDTLS_ENTROPY_HARDWARE_ALT`,
     `MBEDTLS_NO_PLATFORM_ENTROPY`, `MBEDTLS_NO_DEFAULT_ENTROPY_SOURCES`,
     `MBEDTLS_CTR_DRBG_ENTROPY_LEN`, `MBEDTLS_CTR_DRBG_MAX_INPUT`,
     `MBEDTLS_CTR_DRBG_MAX_REQUEST`, `MBEDTLS_CTR_DRBG_MAX_SEED_INPUT`,
     `MBEDTLS_CTR_DRBG_USE_128_BIT_KEY`, `MBEDTLS_CTR_DRBG_RESEED_INTERVAL`,
     `MBEDTLS_HMAC_DRBG_MAX_INPUT`, `MBEDTLS_HMAC_DRBG_MAX_REQUEST`,
     `MBEDTLS_HMAC_DRBG_MAX_SEED_INPUT`,
     `MBEDTLS_HMAC_DRBG_RESEED_INTERVAL`, `MBEDTLS_PSA_HMAC_DRBG_MD_TYPE`.
   - New unified options: `MBEDTLS_PSA_CRYPTO_RNG_HASH` (replaces
     `MBEDTLS_PSA_HMAC_DRBG_MD_TYPE` + `MBEDTLS_ENTROPY_FORCE_SHA256`),
     `MBEDTLS_PSA_RNG_RESEED_INTERVAL` (replaces both DRBG reseed-interval
     options), `MBEDTLS_PSA_CRYPTO_RNG_STRENGTH` (security strength in bits,
     default 256; set to 128 to emulate old
     `MBEDTLS_CTR_DRBG_USE_128_BIT_KEY`).
   - CTR_DRBG (`MBEDTLS_CTR_DRBG_C`) is still used internally if enabled,
     else HMAC_DRBG (`MBEDTLS_HMAC_DRBG_C`); neither module is exposed
     directly anymore — `ctr_drbg.h`/`hmac_drbg.h` removed from the public
     API. (migration guide L815-819.)
7. **`MBEDTLS_PSA_INJECT_ENTROPY` removed** (NV-seed injection into the key
   store; to be reimplemented later upstream). (migration guide L811-813.)
8. **Error code rename:** `MBEDTLS_ERR_ENTROPY_SOURCE_FAILED` ->
   `PSA_ERROR_INSUFFICIENT_ENTROPY`. (migration guide L803.)
9. **New in 1.1.0:** the device path for reading entropy on platforms
   without a dedicated syscall is now configurable via
   `MBEDTLS_PLATFORM_DEV_RANDOM` / `mbedtls_platform_dev_random` (default
   changed from `/dev/urandom` to `/dev/random` for security). Not relevant
   to bare-metal RA MCU targets, but relevant if any host-side/simulator
   test build reads this path.
10. **New reseed/prediction-resistance control functions (1.1.0):**
    `psa_random_reseed()` (force immediate reseed), `psa_random_deplete()`
    (force reseed on next call), `psa_random_set_prediction_resistance()`
    (toggle prediction resistance). Called out re: CVE-2026-25835 (fork()
    duplicating RNG state) — recommend calling these after cloning
    application/VM state; likely not applicable to this embedded target but
    worth knowing the functions exist.
11. `MBEDTLS_PLATFORM_GET_ENTROPY_ALT` (a transient 1.0.0-beta name) was
    removed in favor of the final `MBEDTLS_PSA_DRIVER_GET_ENTROPY` name
    before 1.0.0 GA — don't confuse the two if an old beta doc/example
    mentions it.
12. Threading requirement: `MBEDTLS_THREADING_ALT` implementations must now
    also provide condition variables
    (`mbedtls_platform_condition_variable_t`), not just mutexes;
    `mutex_init` now returns a status code. (migration guide L634-657.)
    Only relevant if this codebase provides a custom `MBEDTLS_THREADING_ALT`.

## Key management / PSA key handles

13. `psa_open_key()`/`psa_close_key()`/`PSA_KEY_HANDLE_INIT`/
    `psa_key_handle_t` fully removed — **already handled**, see section 4 in
    [SKILL.md](SKILL.md).
14. Custom-DH-group/domain-parameter APIs removed:
    `psa_get_key_domain_parameters()`, `psa_set_key_domain_parameters()`,
    `PSA_DH_FAMILY_CUSTOM`, `PSA_KEY_DOMAIN_PARAMETERS_SIZE`.
15. `psa_generate_key_ext()`/`psa_key_derivation_output_key_ext()` removed
    (already deprecated since old-tree 3.6.1) — use
    `psa_generate_key_custom()`/`psa_key_derivation_output_key_custom()`
    (same shape, but variable-length data is a separate parameter instead of
    a flexible array member).
16. Undocumented ability to load persistent keys outside the user key ID
    range removed in 1.1.0 (doesn't affect
    `MBEDTLS_PSA_CRYPTO_BUILTIN_KEYS`).
17. `MBEDTLS_PSA_STATIC_KEY_SLOTS` (new) — static/malloc-less key slot
    storage, sized by `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE`; auto-sizing
    improved in 1.1.0 to account for asymmetric keys, ciphers, AEADs, CMAC,
    HMAC.
18. `MBEDTLS_PSA_KEY_STORE_DYNAMIC` (new, already existed as of old-tree
    3.6.1 too) — virtually unlimited volatile PSA keys at code-size cost;
    off by default but enabled in the reference `mbedtls_config.h`.
19. New interruptible ops: `psa_generate_key_iop_setup()` (+family),
    `psa_key_agreement_iop_setup()` (+family),
    `psa_export_public_key_iop_setup()` (+family), plus a new one-shot
    `psa_key_agreement()` that creates a key directly from an agreement.
20. Security: `psa_key_derivation_output_key()` when deriving an ECC key
    pair now zeroizes its temp heap buffer (PSA ops generally zeroize temp
    heap buffers now).
21. `psa_can_do_hash()`/`psa_can_do_cipher()` removed (legacy-fallback
    dispatch hooks before PSA fully initialized).

## Cipher / AEAD / MAC / Hash

22. **All cipher/AEAD/hash/MAC "legacy" config macros removed; only
    `PSA_WANT_*` enables algorithms now** (`MBEDTLS_PSA_CRYPTO_CONFIG` is
    always effectively "on"). Removed: `MBEDTLS_AES_C`, `MBEDTLS_ARIA_C`,
    `MBEDTLS_CAMELLIA_C`, `MBEDTLS_CCM_C`, `MBEDTLS_CHACHA20_C`,
    `MBEDTLS_CHACHAPOLY_C`, `MBEDTLS_CIPHER_C`,
    `MBEDTLS_CIPHER_MODE_{CBC,CFB,CTR,OFB,XTS}`,
    `MBEDTLS_CIPHER_NULL_CIPHER`,
    `MBEDTLS_CIPHER_PADDING_{PKCS7,ONE_AND_ZEROS,ZEROS_AND_LEN,ZEROS}` (only
    PKCS7 padding remains for CBC), `MBEDTLS_CMAC_C`, `MBEDTLS_DES_C`,
    `MBEDTLS_GCM_C`, `MBEDTLS_POLY1305_C`, `MBEDTLS_MD5_C`,
    `MBEDTLS_RIPEMD160_C`, `MBEDTLS_SHA{1,224,256,384,512}_C`,
    `MBEDTLS_SHA3_C`.
    - Note `MBEDTLS_CIPHER_MODE_XTS` is in this removed list too — matches
      SKILL.md section 7 (PSA-level XTS support disabled via `#if 0`).
23. **DES/3DES removed entirely** (all supported block ciphers now
    128-bit). PKCS12 module (DES-based PBE) removed as a consequence.
24. **`mbedtls/cipher.h` removed from the public API entirely**, along with
    `aes.h`, `aria.h`, `camellia.h`, `ccm.h`, `chacha20.h`, `chachapoly.h`,
    `cmac.h`, `gcm.h`, `poly1305.h`, `block_cipher.h`, `des.h`. Types like
    `mbedtls_aes_context` still exist internally (needed to define
    `psa_cipher_operation_t`) but must not be used directly outside the
    library — semantics may change without notice. This matches what we
    already found (section 1 in SKILL.md): these headers still exist on
    disk under `drivers/builtin/include/mbedtls/private/`, which is why the
    `#include "mbedtls/private/<name>.h"` fix works — they're "private",
    not actually deleted.
25. Legacy HKDF module removed (`mbedtls/hkdf.h`, `MBEDTLS_HKDF_C`); use
    `psa_key_derivation_xxx` with `PSA_ALG_HKDF` (`PSA_WANT_ALG_HKDF`).
26. `mbedtls_md_setup()` now requires `hmac == 0` (HMAC no longer supported
    via MD; use `psa_mac_*`). MD metadata/HMAC functions removed:
    `mbedtls_md_list()`, `mbedtls_md_info_from_string()`,
    `mbedtls_md_get_name()`, `mbedtls_md_info_from_ctx()`,
    `mbedtls_md_file()`, `mbedtls_md_hmac_{starts,update,finish,reset}()`,
    `mbedtls_md_hmac()`. `mbedtls/md.h` remains but is hash-computation-only
    now.
27. SHAKE implemented (`PSA_ALG_SHAKE128`, `PSA_ALG_SHAKE256`) — new in
    1.1.0.
28. Bugfix (1.1.0): GCM tag calculation bug on GCC 10.0-14.2 at `-O3`
    without AESNI/AESCE — data encrypted correctly but the auth tag was
    broken. Relevant if any AES-GCM test runs on an affected host toolchain
    (not RA hardware, but worth knowing for any x86 simulator/CI build of
    this test suite).
29. Security (1.1.0): `mbedtls_ccm_finish()` now validates tag length to
    prevent OOB reads/buffer overflow — relevant for AES-CCM users.
30. Security (1.0.0, CVE-2025-52496): AESNI/software-AES dispatch race on
    x86/amd64 under multithreading could force software AES to run even
    when AESNI is available (also affects GCM acceleration -> forgeries).
    x86-only, not RA-relevant, but worth knowing if host-side crypto tests
    run on x86.
31. Interruptible ECDH key agreement / ECC key generation: fixed a bug
    where these weren't actually interruptible (always completed in one
    go) when ECDSA disabled. (1.1.0 Bugfix.)
32. Only PKCS7 padding mode is supported for CBC now (other pad modes'
    config macros removed) — re-emphasizing item 22 as a behavior change
    for any AES-CBC test using a non-PKCS7 padding mode.

Already-fixed-by-3.6.2, NOT new-tree diffs (sanity-checked against the old
ChangeLog, don't misattribute if seen in old test comments): the
zero-length-AEAD-additional-data NULL-pointer-increment UB fix, and the
`psa_cipher_decrypt()` CCM* <3-byte-message rejection fix — both were
already present in the 3.6.6 baseline.

## PK / RSA / ECC / Asymmetric

33. **`mbedtls_pk_type_t` removed from the public API**, replaced by
    `mbedtls_pk_sigalg_t` for signature-algorithm selection:
    `MBEDTLS_PK_NONE` -> `MBEDTLS_PK_SIGALG_NONE`,
    `MBEDTLS_PK_RSA` -> `MBEDTLS_PK_SIGALG_RSA_PKCS1V15`,
    `MBEDTLS_PK_RSASSA_PSS` -> `MBEDTLS_PK_SIGALG_RSA_PSS`,
    `MBEDTLS_PK_ECDSA`/`MBEDTLS_PK_ECKEY` -> `MBEDTLS_PK_SIGALG_ECDSA`.
34. PK functions made private/removed: `mbedtls_pk_type_t`,
    `mbedtls_pk_debug_type`, `mbedtls_pk_debug_item`,
    `MBEDTLS_PK_DEBUG_MAX_ITEMS`, `mbedtls_pk_info_from_type()`,
    `mbedtls_pk_setup()`, `mbedtls_pk_get_len()`, `mbedtls_pk_can_do()`,
    `mbedtls_pk_can_do_ext()`, `mbedtls_pk_debug()`,
    `mbedtls_pk_get_name()`, `mbedtls_pk_get_type()`, `mbedtls_pk_rsa()`,
    `mbedtls_pk_ec()`, `mbedtls_pk_parse_subpubkey()`,
    `mbedtls_pk_write_pubkey()`, `mbedtls_pk_verify_new()`.
35. `mbedtls_pk_can_do_ext()` renamed -> `mbedtls_pk_can_do_psa()` (now also
    supports public-key ops, not just private-key).
36. `mbedtls_pk_setup_opaque()` renamed -> `mbedtls_pk_wrap_psa()`.
37. **RNG params dropped from PK functions** (matches SKILL.md section 2 —
    same pattern, more functions affected than just `mbedtls_pk_parse_key`):
    `mbedtls_pk_sign_restartable()`, `mbedtls_pk_check_pair()`,
    `mbedtls_pk_sign()`, `mbedtls_pk_sign_ext()`, `mbedtls_pk_parse_key()`,
    `mbedtls_pk_parse_keyfile()`, and the callback typedef
    `mbedtls_pk_rsa_alt_sign_func` all drop `f_rng`/`p_rng` params.
    **If any test file calls `mbedtls_pk_sign()`, `mbedtls_pk_sign_ext()`,
    `mbedtls_pk_check_pair()`, or `mbedtls_pk_sign_restartable()` with
    trailing RNG args, apply the same fix as section 2 in SKILL.md.**
38. `mbedtls_pk_encrypt()`/`mbedtls_pk_decrypt()` removed — use
    `psa_asymmetric_encrypt()`/`psa_asymmetric_decrypt()` instead.
39. `MBEDTLS_PK_RSA_ALT` removed (no more opaque RSA-ALT PK contexts); use
    PSA opaque drivers instead.
40. `mbedtls_pk_verify_ext()` no longer honors a custom RSA-PSS salt length
    via the `options` param when ctx is `MBEDTLS_PK_RSASSA_PSS` — assumes
    "any" salt length, and the hash used for message/encoding/MGF1 must
    match, else it errors. Use `psa_verify_hash()` with `PSA_ALG_RSA_PSS`
    for salt-length enforcement.
41. `MBEDTLS_ERR_PK_SIG_LEN_MISMATCH` no longer a distinct error code —
    trailing garbage after a valid signature is now just "invalid
    signature" uniformly.
42. PK objects lose "policy" memory: `mbedtls_pk_copy_from_psa()`/
    `mbedtls_pk_copy_public_from_psa()` are now equivalent to
    export+reimport (loses PSS-only-policy info; a subsequent
    `mbedtls_pk_sign()` defaults to PKCS#1v1.5). Use
    `mbedtls_pk_sign_ext()`/`mbedtls_pk_verify_ext()` for explicit algorithm
    choice.
43. New macro `MBEDTLS_PK_ALG_ECDSA(hash_alg)` in `pk.h` (deterministic-vs-
    randomized ECDSA choice, equiv to `PSA_ALG_DETERMINISTIC_ECDSA(hash_alg)`
    or `PSA_ALG_ECDSA(hash_alg)`).
44. New helpers: `mbedtls_pk_can_do_psa()`, `mbedtls_pk_get_key_type()`
    (returns PSA key type for a PK object), `mbedtls_pk_write_pubkey_psa()`
    (new in 1.1.0 — export a PK's public key into a PSA-importable format).
45. PK context internal representation changed: public key now stored in a
    fixed-size buffer directly inside `mbedtls_pk_context`; private key (if
    any) lives in the PSA key store. Memory-layout-only, no functional API
    change.
46. `mbedtls_pk_parse_subpubkey()`/`mbedtls_pk_write_pubkey()` removed — use
    `mbedtls_pk_parse_public_key()`/`mbedtls_pk_write_pubkey_der()`.
47. `mbedtls_pk_debug()` and related types removed entirely, no
    replacement.
48. Legacy RSA/ECC/bignum headers removed from the public API:
    `mbedtls/bignum.h`, `mbedtls/rsa.h`, `mbedtls/ecp.h`, `mbedtls/ecdh.h`,
    `mbedtls/ecdsa.h`, `mbedtls/ecjpake.h`, `mbedtls/dhm.h`. Config macros
    removed: `MBEDTLS_GENPRIME`, `MBEDTLS_PKCS1_V15`, `MBEDTLS_PKCS1_V21`,
    `MBEDTLS_RSA_C`, `MBEDTLS_ECDH_C`, `MBEDTLS_ECDSA_C`,
    `MBEDTLS_ECDSA_DETERMINISTIC`, `MBEDTLS_ECJPAKE_C`, `MBEDTLS_ECP_C`,
    `MBEDTLS_ECP_DP_*_ENABLED`, `MBEDTLS_BIGNUM_C` — use PSA `PSA_WANT_*`
    RSA/ECC symbols instead.
49. **EC curves <=224 bits removed:** secp192r1, secp192k1, secp224k1,
    secp224r1 no longer supported (use secp256r1+).
50. `mbedtls_ecc_group_to_psa()`/`mbedtls_ecc_group_from_psa()` removed.
51. `psa_export_public_key()` for FFDH keys: fixed buffer overflow when the
    output buffer is too small (1.1.0 security fix).
52. FFDH key-agreement: fixed missing peer-key validation — low-order
    elements weren't rejected, breaking contributory-behavior guarantees
    for FFDH-based protocols (1.1.0 security fix).
53. RSA private-key perf: partial fix for a regression (when
    `MBEDTLS_RSA_NO_CRT` disabled, i.e. default) introduced by an earlier
    1.0 security fix — perf-only.
54. Security (1.0.0, CVE-2025-54764): local timing side-channel in modular
    inversion/GCD exploitable in RSA key generation/operations fixed.
55. `mbedtls_pk_rsassa_pss_options` removed from the interface.
56. `pk.c` PSA-related stack buffers >2KB moved to heap (except pure-ECC-
    only PK configs) — reduces stack usage; 1.1.0 bugfix. Worth knowing if
    debugging a stack-overflow-shaped failure in PK-using tests.

## PQC (ML-KEM / ML-DSA / LMS)

57. **No ML-KEM/ML-DSA changelog entries at all** in mbedtls-v4 4.1.0 or
    TF-PSA-Crypto 1.1.0 — not introduced there. (The ML-KEM/ML-DSA support
    used by `psa_crypto_tests_tg9.c`/`tg11.c` in this codebase comes from
    Renesas's own PQC library under `ra/renesas/post_quantum_crypto/pqc/`,
    per SKILL.md section 5 — not from upstream mbedtls/TF-PSA-Crypto.)
58. LMS module remains (`mbedtls/lms.h`) as one of the few non-PSA-covered
    mechanisms retained. RNG params removed from
    `mbedtls_lms_generate_private_key()` and `mbedtls_lms_sign()`.
59. LMS security fixes (1.0.0): buffer overread in
    `mbedtls_lms_import_public_key()` on <3-byte input (CVE-2025-49601);
    verification vulnerability allowing invalid-signature acceptance if a
    hash accelerator is forced to fail (CVE-2025-49600); sloppy
    public-key-import check allowing mismatched LMS/LM-OTS types on
    platforms with small enum types + optimization.

## Key wrapping (NIST_KW)

60. `mbedtls_nist_kw_wrap()`/`mbedtls_nist_kw_unwrap()` re-signatured to
    take a PSA key ID (`mbedtls_svc_key_id_t`) instead of a plaintext
    key/context, return `psa_status_t` instead of `int`, and swap the
    output-size/output-length parameter order. `mbedtls_nist_kw_context`
    type and `_init()/_free()/_setkey()/_self_test()` functions all removed.
    Only relevant if this codebase uses NIST key-wrap anywhere (grep for
    `nist_kw` before assuming it's unused).

## Build configuration / header relocation

61. **Repository split**: crypto code moved from `library/` +
    `include/mbedtls/*` (old tree) into TF-PSA-Crypto's `core/`,
    `drivers/builtin/src/`, `drivers/builtin/include/private/`;
    `include/psa/*` consolidated into TF-PSA-Crypto; third-party
    (`3rdparty/everest`, `3rdparty/p256-m`) moved to `drivers/everest`,
    `drivers/p256-m`.
62. In 1.1.0, non-driver files were further reorganized out of
    `drivers/builtin/src` into new top-level `extras/` (LMS etc.),
    `platform/`, `utilities/` dirs; new `dispatch/` dir added for
    driver-wrapper dispatch code.
63. **Config file split**: crypto/platform config now lives in
    `include/psa/crypto_config.h` (TF-PSA-Crypto's own config file), not
    `mbedtls_config.h`. `MBEDTLS_PSA_CRYPTO_CONFIG_FILE`/
    `MBEDTLS_PSA_CRYPTO_USER_CONFIG_FILE` are no longer recognized — use
    `TF_PSA_CRYPTO_CONFIG_FILE`/`TF_PSA_CRYPTO_USER_CONFIG_FILE`.
    **Note:** this project's `rm_tf_psa_crypto.xml` test macro is
    `TF_PSA_CRYPTO_CONFIG_FILE=\"rm_tf_psa_crypto_cfg.h\"` — already using
    the correct v4 macro name, nothing to fix there.
64. `MBEDTLS_PSA_CRYPTO_CONFIG` option removed — behavior is now always-on
    (PSA_WANT_*-driven).
65. `MBEDTLS_USE_PSA_CRYPTO` option removed — now always-on.
66. `mbedtls/check_config.h` removed entirely.
67. `MBEDTLS_OID_C` config option removed — OID tables auto-included as
    needed; `mbedtls/oid.h` now lives in Mbed TLS proper (not TF-PSA-Crypto)
    and only supports binary<->string OID conversion, no more
    lookup-by-enum.
68. `MBEDTLS_PADLOCK_C` (VIA Padlock accel) removed.
69. `MBEDTLS_PSA_CRYPTO_SE_C` (dynamic secure element registration) removed
    (already deprecated) — use compile-time SE drivers.
70. **All `MBEDTLS_XXX_ALT` crypto-module/function-level alt
    implementations removed** (crypto-only; platform/threading/timing ALT
    unaffected). Must migrate to PSA transparent/opaque drivers — this is
    the mechanism the Renesas CCH driver layer already replaces, so likely
    not new work, but worth confirming no lingering `MBEDTLS_xxx_ALT`
    defines remain in `rm_tf_psa_crypto_cfg.h`.
71. Deprecated-and-now-removed PSA config symbols:
    `PSA_WANT_KEY_TYPE_ECC_KEY_PAIR`, `PSA_WANT_KEY_TYPE_RSA_KEY_PAIR`,
    `MBEDTLS_PSA_BUILTIN_KEY_TYPE_{RSA,ECC}_KEY_PAIR`,
    `MBEDTLS_PSA_ACCEL_KEY_TYPE_{RSA,ECC}_KEY_PAIR`,
    `MBEDTLS_SHA256_USE_A64_CRYPTO_IF_PRESENT`,
    `MBEDTLS_SHA256_USE_A64_CRYPTO_ONLY` (already renamed to
    `..._ARMV8_A_CRYPTO_...` variants back in 3.6.0 — old names just fully
    gone now).
72. `MBEDTLS_SELF_TEST` no longer provides a direct library self-test
    benefit in TF-PSA-Crypto; still gates `programs/test/selftest.c` in
    Mbed TLS proper.
73. Version API changed: `mbedtls_version_get_string()`/
    `mbedtls_version_get_string_full()` now take zero args and return
    `const char*` (previously took a `char*` buffer arg). New
    `<tf-psa-crypto/version.h>` for TF-PSA-Crypto's own version
    macros/functions.

## Error codes (cross-cutting)

74. **Unified error space**: `mbedtls_xxx()` functions can now return
    `PSA_ERROR_xxx` values directly; no more separate "low-level"/
    "high-level" error code composition. `mbedtls_low_level_strerr()`/
    `mbedtls_high_level_strerr()` removed — only `mbedtls_strerror()`
    remains.
75. Generic error-code aliasing pattern applied broadly:
    `MBEDTLS_ERR_xxx_BAD_INPUT[_DATA]` -> `PSA_ERROR_INVALID_ARGUMENT`,
    `..._ALLOC_FAILED` -> `PSA_ERROR_INSUFFICIENT_MEMORY`,
    `..._[AUTH/VERIFY]_FAILED` -> `PSA_ERROR_INVALID_SIGNATURE`,
    `..._BUFFER_TOO_SMALL` -> `PSA_ERROR_BUFFER_TOO_SMALL`,
    `..._OUTPUT_TOO_LARGE` -> `PSA_ERROR_BUFFER_TOO_SMALL`,
    `..._INVALID_PADDING` -> `PSA_ERROR_INVALID_PADDING`. Full
    name-by-name table (AES/ARIA/ASN1/Base64/Camellia/CCM/ChaCha20/
    ChaChaPoly/Cipher/ECP/Error/GCM/LMS/MD/MPI/OID/PEM/PK/PKCS5/Platform/
    Poly1305/RSA/SHA1/SHA256/SHA3/SHA512) is in the migration guide
    ~L384-436 — check there if a test file references a removed
    `MBEDTLS_ERR_*` constant directly (as opposed to a `PSA_ERROR_*` one).
76. Specific aliases: `MBEDTLS_ERR_ECP_IN_PROGRESS` ->
    `PSA_OPERATION_INCOMPLETE`, `MBEDTLS_ERR_RSA_VERIFY_FAILED` ->
    `PSA_ERROR_INVALID_SIGNATURE`.

## Baseline sanity-check (already true by old-tree 3.6.6, NOT new in v4)

Don't misattribute these to the v4 port if seen while debugging —
confirmed already present/fixed by 3.6.1/3.6.2 in the old tree:
- CVE-2024-45157/45158/45159, CVE-2024-49195 — all fixed pre-3.6.6.
- `psa_cipher_decrypt()` CCM* <3-byte-message rejection, and the
  zero-length-AEAD-additional-data NULL-pointer-increment UB fix.
- `psa_import_key()` RSA-format restriction (PKCS#8/SubjectPublicKey/PEM
  import no longer implicitly accepted) — already in 3.6.0.
- `mbedtls_pk_wrap_as_opaque()` already removed pre-3.6.6 (superseded by
  `mbedtls_pk_setup_opaque()`, itself since renamed to
  `mbedtls_pk_wrap_psa()` in v4 — see item 36 above).
- The old tree's 3.6.1 "New deprecations" section already telegraphed
  almost exactly what TF-PSA-Crypto 1.0.0 went on to remove (DES, PKCS#1v1.5
  encrypt/decrypt, custom-group FFDH, curves <=225 bits, and the
  `hkdf.h`/`md5.h`/.../`rsa.h` public headers, `MBEDTLS_xxx_ALT`,
  `MBEDTLS_PK_RSA_ALT`, `MBEDTLS_PSA_CRYPTO_SE_C`) — these are intentional,
  well-telegraphed 4.0 removals, not accidental regressions.

## Out of scope / not investigated further

- PAKE interface reshaping (JPAKE/SPAKE2+) — migration guide
  "Changes to the PAKE interface" ~L938-1077 — this codebase doesn't use
  PAKE, skipped.
- TLS/SSL, X.509, DTLS, PKCS7 record/certificate-layer changes — this
  codebase only consumes the crypto library.
