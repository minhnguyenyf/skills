---
name: mbedtls-v4-migration-notes
description: Use for mbedTLS v3 and v4 (TF-PSA-Crypto) differences, build/link errors on mbedtls_*/psa_* symbols or headers, littlefs/psa_its persistent-key issues, and porting tests in rm_psa_crypto or rm_tf_psa_crypto. Record new facts here, in the same turn.
---

# mbedTLS v3 -> v4 (TF-PSA-Crypto) migration notes

Status: compacted 2026-10-30. Keep only status and knowledge. Full older text is in git history.

Where to record:
- v3 to v4 API, header, or macro diff: a numbered section here.
- v3-only finding: `mbedtls-v3-notes.md` (create when first needed).
- littlefs, `psa_its_*`, persistent keys: [psa-storage-littlefs-stack.md](psa-storage-littlefs-stack.md).
- Open bug investigation: its own file, see [ecc-busfault-littlefs-investigation.md](ecc-busfault-littlefs-investigation.md).
- Version changes: [changelog-3.6.6-to-4.1.0.md](changelog-3.6.6-to-4.1.0.md).

Highlights from the changelog (FSPRA-5629 TRNG sync):
- Entropy callback: `mbedtls_hardware_poll()` (`MBEDTLS_ENTROPY_HARDWARE_ALT`) is now `mbedtls_platform_get_entropy(flags, &estimate_bits, output, output_size)` (`MBEDTLS_PSA_DRIVER_GET_ENTROPY`). It fills the whole buffer and `estimate_bits` must be `8 * output_size`.
- `f_rng`/`p_rng` removed from `mbedtls_pk_sign`, `_sign_ext`, `_sign_restartable`, `_check_pair`, `_parse_keyfile`. Drop the trailing RNG args at call sites.
- `MBEDTLS_CIPHER_MODE_XTS` is removed upstream (see section 7).

## 1. Headers moved to `mbedtls/private/`
`aes.h`, `cmac.h`, `poly1305.h`, `chacha20.h`, `chachapoly.h`, `rsa.h`, `ecp.h` are now at `mbedtls/private/<name>.h` (`drivers/builtin/include/mbedtls/private/`). `pk.h` stays in `include/mbedtls/`.
Fix: change the include path. If a macro such as `MBEDTLS_AES_BLOCK_SIZE` is undeclared, add the include explicitly.

## 2. `mbedtls_pk_parse_key()` drops the RNG arguments
- v3: `(ctx, key, keylen, pwd, pwdlen, f_rng, p_rng)`.
- v4 (`include/mbedtls/pk.h:725`): `(ctx, key, keylen, pwd, pwdlen)`.

## 3. `psa_key_handle_t` removed
Use `psa_key_id_t` everywhere. Same semantics.

## 4. `psa_open_key()` / `psa_close_key()` removed
Persistent keys are referenced directly by ID. Verified: only comments mention these names in v4 headers.
- Reopen: `key_handle = (psa_key_id_t) 2;`
- Check for a nonexistent key: `psa_get_key_attributes(...)` returns `PSA_ERROR_INVALID_HANDLE`.
- Files were edited with `\r\n` line endings, which matters for multi-line regex.

## 5. PQC include paths
Test files `psa_crypto_tests_tg9.c`, `tg11.c` and the PQC test data need:
- `ra/renesas/post_quantum_crypto/pqc/PQC-Lib/src` (for `r_pqc_api.h`, `r_pqc_cfg.h`)
- `ra/renesas/post_quantum_crypto/pqc/test/UT/Sim/src/smoke_test` (for `smoke_test_*.h`)
Add both to `<include_dirs>` in `projects/rm_tf_psa_crypto.xml`.

## 6. `PSA_KEY_LIFETIME_IS_PERSISTENT` removed
Use `!PSA_KEY_LIFETIME_IS_VOLATILE(lifetime)`. Warning sign: this appears as a link error (`undefined reference`), not a compile error.

## 7. PSA AES-XTS (`PSA_ALG_XTS`) is disabled in v4
Not a config or header issue. The PSA-level XTS path is `#if 0` in `drivers/builtin/include/mbedtls/private/crypto_adjust_config_enable_builtins.h` (around line 732). The legacy `mbedtls_cipher_*` XTS still works.
Status: open. Needs a team decision: skip the PSA XTS tests, or add a Renesas CCH override. Do not patch around it in test code.

## 8. `MBEDTLS_PSA_KEY_STORE_DYNAMIC` and the calloc leak check
With dynamic key storage, two structural allocations are freed only by `mbedtls_psa_crypto_free()`, not by `psa_destroy_key()`:
- persistent-key cache slice: 108 bytes
- first volatile-key slice: 640 bytes

`rm_psa_test_calloc_leak()` (`!test/psa_crypto_tests_setup.c`) skips one occurrence of each size, and index 0 (entropy accumulator). Do not reorder `mbedtls_psa_crypto_free()` before the leak check. A leak of any other size is reported as `LEAK: slot N, addr, size`.

## 9. Bus fault on persistent ECC keygen (ra4c1, `TC_API_ECCGenerateKeyPairSignVerify256R1Persistent`)
Status: open. The test is skipped on E31A boards in `psa_crypto_tests_tg5.c`. The root cause is not fixed.
- Fault: `lfs_fs_traverse_` at `lfs.c:4694` reads `lfs->mlist`. The `mlist` list holds a stale entry, so `f->next` is garbage.
- Trigger: the v4 key blob grows past littlefs `inline_max`, so `lfs_alloc()` runs and walks `mlist`. v3 kept the blob inline.
- Clean, do not re-audit: `lfs_file_opencfg_`, `lfs_remove_`, `lfs_rename_`, and the `psa_its_file.c` fclose sites.
- Ruled out: `MBEDTLS_PSA_KEY_STORE_DYNAMIC`, heap size, `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE`, `PSA_CRYPTO_MAX_STORAGE_SIZE`, main stack size. Volatile keys are not valid: they return -135.
- Next: set a watchpoint on `g_rm_littlefs_flash0_lfs.mlist`. It should be `NULL` after each ITS operation. The write that leaves it set names the culprit.
- Latent hazard: `ra/fsp/inc/instances/rm_stdio_littlefs.h:69` defines `fclose` as two statements with no `do {} while (0)`.

## 10. Persistent storage: v3 XML macros vs v4 config
- v3 `projects/rm_psa_crypto.xml` enables `MBEDTLS_PSA_ITS_FILE_C`, `MBEDTLS_FS_IO`, `MBEDTLS_PSA_CRYPTO_STORAGE_C` in `<common_macros>`, even though the v3 config files disable them.
- v4 `rm_tf_psa_crypto.xml` relies on `rm_tf_psa_crypto_cfg.h` instead.
Checklist when porting: any `MBEDTLS_PSA_*` macro set in v3 XML must be defined in the v4 config, or it becomes silently inactive.

## 11. Double import into the same key ID
If a conditional `psa_import_key()` is followed by an unconditional one into the same handle, destroy the first key in between. Found in `psa_crypto_tests_tg4.c` (`TC_API_ECCImportVerify521R1`), which leaked about 130 bytes.

## 12. Requirement IDs for ported tests
- Add a `tf_` prefix to requirement IDs in `rm_tf_psa_crypto` tests, so they don't collide with v3. Keep the Jira ID. Apply the same prefix to `@verify`.
- Lowercase, and drop `mbedtls` from names: `tf_sha256_hash_mbedtls` becomes `tf_sha256_hash`.
- Applies to `psa_crypto_tests_tg1.c` through `tg11.c`.

## 13. Anchors match requirement IDs exactly
`@anchor` names in `rm_tf_psa_crypto_usage_notes.md` must be all lowercase and match the test IDs case-sensitively (`k1`, `r1`, `bp`, `pkcs1v15`, `wrapped`).

## 14. `_wrapped` suffix uses an underscore
Examples: `tf_rsa_1024_key_generation_wrapped`, `tf_aes256_key_generation_wrapped`. Applies to generation, export and import IDs. Applied with `([a-z0-9])wrapped` -> `$1_wrapped`.

## 15. Board config in `projects/rm_tf_psa_crypto.xml`
Port a board from `rm_psa_crypto.xml` (v3) with these changes:
- Include dirs: `ra/arm/mbedtls-v4/tf-psa-crypto/{platform,include,core,dispatch,extras}`.
- Config macro: `TF_PSA_CRYPTO_CONFIG_FILE="rm_tf_psa_crypto_cfg.h"` (not `MBEDTLS_CONFIG_FILE`).
- Remove the `MBEDTLS_PSA_*` storage macros from `common_macros`.
- Add `__STDC_WANT_LIB_EXT1__=0` (for IAR).
- Exclude `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_its_file.c`.
- Keep the board's crypto procedure: ra4c1 uses `rsip_e31a`, ra6m3 uses `sce7`, ra6m4 uses `sce9`.

Key support (temporary): v4 boards use `PLAINTEXT_KEY_SUPPORT` during software-only testing. v3 hardware boards use `WRAPPED_AND_PLAINTEXT_KEY_SUPPORT`.

Boards in the v4 project: ra4c1_ek, ra6m3_pk, ra6m4_ek, ra8m1_ek, ra8m2_ek, ra4l1_ek, ra2a2_ek, ra2e1_ek. `ra2a1_tbb` was swapped in for `ra2e1_ek` (section 20). The reason is recorded there.

## 16. XML test templates (v4)
Templates are in `ra/fsp/src/rm_tf_psa_crypto/.xml_tests/`: `tf_psa_crypto_template.yml`, `tf_psa_crypto_availability.yml.j2`, `tf_psa_crypto_littlefs_availability.yml.j2`.

Verified module IDs (grep the real `.module_descriptions` file before using any ID):
- Driver: `module.driver.tf_psa_crypto`. The `rm_tf_psa_crypto` name only appears in `requires` sub-IDs.
- mbedTLS v4 wrapper: `module.arm.mbedtls_v4` (no version suffix).
- Config properties: `config.driver.tf_psa_crypto.*`, `..._alg_*`, `..._key_type_*`. Do not use the legacy `config.driver.psa_crypto.*` in v4. Keep `config.driver.psa_crypto.*` in the v3 tree.
- `__STDC_WANT_LIB_EXT1__` is a build macro only. It has no config property and must not appear in an XML sequence.
- v3 constraint messages ("Disable Platform Memory", "MBEDTLS_THREADING_C must be undefined") still exist verbatim in v4.

Status: `check_constraints_number` is a placeholder (7 in the templates, 6 on-target with No RTOS). Verify it by generating a project.

Naming: write `hyphen` forms (`mbedtls-v4`, `MbedTLS-v4`). Avoid `mbedtls(v4)` and `mbedtls_v4.0`.

## 17. Adding a board breaks the dependency-tree self-test
After adding a board to `rm_tf_psa_crypto.xml`:
1. Add the board to the `rm_tf_psa_crypto` boards list in `projects/pipeline_builds.yml`.
2. Add the module name to the per-MCU `bsp_elc.h` and `bsp_linker.c` entries in `scripts/dependency_tree/test_cases.yml` (only MCUs with dedicated entries).
3. Run `python scripts/dependency_tree/build_tree.py --self-test`. Failure strings: `TEST FAILED` or `Self-test Failed`.

## 18. Missing `hw_sce_hash_private.h` in tg1
`psa_crypto_tests_tg1.c` needs `#include "hw_sce_hash_private.h"` (defines `HW_SCE_LARGE_DATA_VALUE_0/1`). Include it after `psa_crypto_tests_setup.h`.

## 19. Module description paren bug (ECC heap constraint)
Status: fixed. The "Software ECC" heap constraint in `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` had one fewer `)`. An unbalanced expression never resolves, so the constraint stays active. Check each constraint with `count('(') == count(')')`.
Status: open. Build of availability projects reports 17 compile errors. The full compiler log is needed, since `ease.log` has only warnings.

## 20. Gating PSA features by hardware: dead end
Do not gate algorithms by `BSP_FEATURE_RSIP_*` hardware. Every algorithm has a software fallback. Gating broke `mbedtls_aes_cmac_prf_128`.
- The shared `rm_tf_psa_crypto_cfg.h` is one file for every board. Per-board size fixes need a size measurement (map file or `nm --size-sort`) first.
- `PSA_WANT_*` must not be `#define`d to `0`. Use `#if (...) #define PSA_WANT_ALG_x 1 #endif`, or leave it undefined. `crypto_adjust_config_dependencies.h` checks with `defined()`, so a `0` still counts as enabled.
- A `PSA_WANT_ALG_*` gate also needs its `PSA_WANT_KEY_TYPE_*` gate. Otherwise `MBEDTLS_ECP_MAX_BITS` has no curve to size from.
- Unconditional `MBEDTLS_PK_PARSE_EC_EXTENDED` or `_COMPRESSED` forces `MBEDTLS_ECP_LIGHT` on. Gate them with the ECC capability.
- Never gate `PSA_WANT_KEY_TYPE_CHACHA20`. Stream cipher needs it.
- Known follow-up: `PSA_WANT_DH_RFC7919_*` are still `#define`d to `0`. Not yet observed to fail.

## 21. `ra2a1_tbb` RAM overflow
Board overflowed by 2532 bytes. Two fixes in `rm_tf_psa_crypto_cfg.h` and the project XML:
- `MBEDTLS_PSA_KEY_SLOT_COUNT 8` (was 32). Recovers 960 bytes, since each `psa_key_slot_t` is about 40 bytes.
- `RM_PSA_CRYPTO_TESTS_MAX_CALLOC=32` in `ra2a1_tbb`'s `common_macros` only. Recovers about 1344 bytes. It's board-scoped, not the global default.
Status: remaining overflow not yet confirmed after rebuild. If a small amount remains, lower `MAX_CALLOC` further or get a map-file breakdown.

## 22. Board RAM and heap references (FSPRA-5629)
- ra8m2_ek (E50D): RSA 3072/4096 failed with `PSA_ERROR_INSUFFICIENT_MEMORY` at heap 0x4000. Fixed with heap 0xF000.
- ra4m1_ek (SCE5): link overflow of 1104 bytes at heap 0x4400. Fixed with heap 0x3000.
- Checklist when a board overflows: compare the device SRAM with the heap, then match a reference board with the same crypto engine (SCE5 uses ra2a1_ek, E50D uses ra8m1_ek). If still tight, disable test categories with `TEST_PSA_CRYPTO_*=0`.

## 23. Module description checks (after every edit)
1. Each `<constraint>`: `(` count equals `)` count.
2. Each `<property>` with options: option IDs start with the property ID plus `.`. The default is one of the option IDs. No option ID is duplicated.
3. Each `${config.driver.*}` in a constraint or template has a matching `<property id=...>`. Ignore `config.bsp.*` and `config.awsfreertos.*`.
4. Keep CRLF. Use `open(..., newline='')` in Python.

Fixed copy-paste errors: `secp_r1_256`, `secp_r1_521`, `alg_ccm_star_no_tag` (wrong option IDs), and three `*_key_pair_import` defaults missing `.disabled`. Open: `secp_r1_256` default is `.disabled`. v3 and the mbedTLS v4 module expect it enabled. Decide.

## 24. FSP user builds need the complete pack source list
User projects only get the files listed in `ra/arm/!dsn/tf_psa_crypto_module.xml` `<sources>`, and only the `<include_folders>` in that file.
- Include folders must include `tf-psa-crypto/drivers/builtin/include` and `.../mbedtls/private`.
- Sources must include the headers that `build_info.h` and the library need (about 18 headers). They were missing after the submodule moved to 4.1.0.
Method after each submodule bump: run `gcc -M -MG` on the `<sources>` `.c` files with the module include folders. Diff the reported `ra/arm/mbedtls-v4/...` headers against the module list. Add what is missing.

Gotcha: this machine's zsh does not word-split `$VAR` in `gcc $I`. Run gcc through `bash -c`.

Pack rebuild and project regeneration are needed in e2 after any change here. The generated `.cproject` keeps the old list.

## 25. `MBEDTLS_PLATFORM_SETBUF_MACRO = dummy_setbuf` breaks customer projects
`dummy_setbuf` exists only in `rm_tf_psa_crypto.h`, and v4 has no definition. `extras/md.c` and `extras/pkparse.c` then fail with an undeclared function.
Fix: module description default changed to `setbuf`. Status: fixed, uncommitted. Not yet built. Pack rebuild needed.

## 26. `threading_internal.h` not found in user projects
Header is at `tf-psa-crypto/platform/threading_internal.h`, and `core/psa_crypto.c` includes it.
Fix: `platform` added to `<include_folders>`, and the header added to `<sources>`. Status: fixed, uncommitted. Not yet verified with a full preprocess. Pack rebuild needed.

## 27. Caveats (open)
- `mbedtlsv4-tf-psa-crypto-integrated/SKILL.md` has Windows paths from an old session. Verify before use.

## 28. Building the module in e2: missing sources and include folders
e2 copies only what the module lists. A missing header gives `fatal error: X.h: No such file or directory`. Fix the module file, not `-I` flags.

| Error | Fix in module |
|---|---|
| `build_info.h:116 psa/crypto_config.h` | Include folder `ra_cfg/arm/mbedtls-v4/` |
| `psa_crypto_driver_wrappers_no_static.h` | Source `core/psa_crypto_driver_wrappers_no_static.{h,c}`; sources `drivers/builtin/src/psa_crypto_xof.{h,c}` |
| `ssl_misc.h` in `debug.c`, `mps_*.c`, `net_sockets.c`, `timing.c`; `x509_internal.h` in `pkcs7.c` | Remove the files. TLS and X.509 sources are not used by PSA-only builds |
| `pk_wrap.h` in `psa_crypto.c` | Include folder `tf-psa-crypto/extras` |
| `ssl_misc.h` in `version.c` | Remove `library/version.c` |

Before adding a missing header: find it, check whether the module lists it, and check which code uses it.

## 29. e2 values override module defaults
A value saved in e2's `configuration.xml` overrides a changed module default. Also check the generated `ra_cfg/arm/mbedtls-v4/psa/crypto_config.h` for `#if 0` blocks.
Typical symptoms:
- `PSA_WANT_ALG_CCM defined, but not all prerequisites` (`core/check_crypto_config.h:22`). Enable `PSA_WANT_KEY_TYPE_AES`.
- `Missing definition of MBEDTLS_ECP_MAX_BITS` (`ecp.h:330`). Enable a curve such as `PSA_WANT_ECC_SECP_R1_256`, or disable ECDSA.

## 30. Key storage format selectors
`config.driver.tf_psa_crypto.{aes,ecc,rsa}_format` use `<select enum="enum.mcu.psa_crypto.*_format"/>`. The enums are defined per device in the BSP module. The `plaintext` option is the module default.

## 31. tf-psa-crypto 1.1.0 to 1.1.1
Compare the `tf-psa-crypto-1.1.0` and `tf-psa-crypto-1.1.1` tags (the plain `v1.x` tags point to other commits).
- No change needed in `rm_tf_psa_crypto`.
- RSA PKCS#1 v1.5 returns `PSA_ERROR_INVALID_PADDING` and `PSA_ERROR_BUFFER_TOO_SMALL`.
- ChaCha20 adds a counter sentinel and `mbedtls_chacha20_check_counter_wrap()`. ChaCha20-Poly1305 rejects inputs over `UINT32_MAX` blocks.
- `rsa_invasive.h` is new, under `MBEDTLS_TEST_HOOKS` only.
- `core/alignment.h` adds an IAR `__packed` workaround.
- `psa_crypto_rsa.c` uses `mbedtls_rsa_rsaes_pkcs1_v15_decrypt_ext`.
- Hang on ra6m3 (software RSA-2048 keygen, `TC_API_RSAEncryptDecryptPKCS1V15`): the 1.1.1 small-prime check (`bignum.c`, `mbedtls_mpi_is_prime_ext`) uses one GCD against a 1380-bit product per candidate. It came from commit `4fc9e8e02` (a side-channel fix). Slower on Cortex-M4. Not yet measured.

## 32. RSIP-E50D unification (FSPRA-6005)
The E50D devices (RA8P1, RA8M2, RA8D2, RA8T2) follow the E51A code paths in the PSA alt-process, netx and key-injection code. E50D driver signatures are in restricted paths and are not verified. See `code-review/FSPRA-6005_review.md`, item 2.1.

## 33. Device map and stack availability
Source: `BSP_FEATURE_*` in each MCU's `bsp_feature.h`, and `interface.driver.sce` providers under `r_sce/.module_descriptions/`.

| Crypto peripheral | Devices |
|---|---|
| RSIP-E51A | RA8M1, RA8D1, RA8T1, RA8E1, RA8E2 |
| RSIP-E50D | RA8P1, RA8M2, RA8D2, RA8T2 |
| RSIP-E31A | RA4C1 |
| RSIP-E11A | RA4L1 |
| SCE9 | RA6M4, RA4M3, RA4M2, RA6M5, RA4E1, RA6E1 |
| SCE7 | RA6M3, RA6M2, RA6M1, RA6T1 |
| SCE5 | RA4W1, RA4M1 |
| SCE5B | RA6T2 |
| AES Engine | RA2A1, RA2E1, RA2E2, RA2L1 |
| AES Engine 2 | RA2A2 |
| TRNG | RA0E1, RA0E2, RA0L1, RA2L2, RA4E1, RA4E2, RA4T1, RA6E1, RA6E2, RA6T3, RA8E1, RA8E2 |

- RA2L3 is unreleased (only upcoming notes and internal packs). Leave it out of public notes.
- The v3 and v4 modules have no device gating. Each port needs an SCE or RSIP driver. Devices with one can add either stack.
- Not verified: AES Engine devices. `rm_psa_crypto` is listed for `ra2a1_ek` and `ra2a2_ek` in `projects/pipeline_builds.yml`, but they have no SCE or RSIP driver.
