# PSA persistent-key storage: littlefs stack (RA / FSP)

Status: compacted 2026-11-01. Read from source on the FSPRA-5629 branch. Line numbers may drift.

## 1. Layers
```
psa_generate_key()                  tf-psa-crypto/core/psa_crypto.c
  psa_save_persistent_key()         core/psa_crypto_storage.c
    psa_its_set()                   core/psa_its_file.c  (written against stdio)
      fopen/fwrite/fclose/rename/remove
        [macro shim]                ra/fsp/inc/instances/rm_stdio_littlefs.h
          lfs_file_*()              ra/arm/littlefs/lfs.c
            rm_littlefs_flash       ra/fsp/src/rm_littlefs_flash/ -> data flash
```
- Save trigger: `psa_crypto.c` ~1888, gated on `!PSA_KEY_LIFETIME_IS_VOLATILE` (the v4 idiom).
- A `psa_its_file.c` frame calling `lfs_file_write` in a debugger is expected. The shim rewrites stdio calls.
- `lfs_t` and `struct lfs_config` are generated into `ra_gen/` (not in the repo). Read the values in the debugger. Defaults come from `rm_littlefs_flash/.module_descriptions/*.xml` (lookahead default 16).
- `rm_stdio_littlefs.h` binds the shim with `MBEDTLS_CONFIG_LFS` to the generated instance.
- v3 equivalents: `ra/arm/mbedtls/library/psa_crypto_storage.c`, `psa_its_file.c`.

## 2. v3 to v4 diff in this stack: almost none
- `psa_its_file.c`: only the include changes to `tf_psa_crypto_common.h`.
- `psa_crypto_storage.c`: v4 removes the transaction block (`PSA_CRYPTO_STORAGE_HAS_TRANSACTIONS`) and `mbedtls_psa_storage_inject_entropy`. Neither is used by the tests.
- `psa_crypto_its.h` is unchanged.
- If persistent storage misbehaves, look at what drives these files (blob size, call order) and at the FSP layers, not at these two files.

## 3. Macro shim (`rm_stdio_littlefs.h`, header-only)
| stdio | maps to |
|---|---|
| `fopen` | `rm_littlefs_fopen()`: `malloc(sizeof(lfs_file_t))` then `lfs_file_open` |
| `fwrite`/`fread` | `lfs_file_write`/`lfs_file_read` with `n*len` bytes |
| `fseek` | `lfs_file_seek(...) >= 0 ? 0 : -1` |
| `fclose` | `lfs_file_close(lfs, s); free(s)` |
| `remove`/`rename` | `lfs_remove`/`lfs_rename` |

Flags come from `mode[0]` only (`'r'` gives `LFS_O_RDONLY`, else `LFS_O_WRONLY | LFS_O_CREAT`). Only `"rb"` and `"wb"` are used. No append or read-write.

Hazards:
1. `fclose` is two unbraced statements with no `do {} while (0)`. `if (x) fclose(f);` lets `free()` escape the `if`. All four current call sites are brace-safe. Fix upstream in FSP.
2. Unmapped stdio functions (`ftell`, `fflush`, `fprintf`) bind to real newlib and get an `lfs_file_t*` cast to `FILE*`. Check shim coverage on every crypto library bump.
3. `fwrite`/`fread` return bytes, not items. Callers must use item size 1.
4. File handles use libc `malloc`, not `mbedtls_calloc`. The test leak checker does not see them.

## 4. On-disk formats
- ITS file name: `%08x%08x` of the UID, plus `.psa_its`, in the littlefs root. The temp file is `tempfile.psa_its`.
- ITS header: magic `"PSA\0ITS\0"` (8 bytes), size (4 bytes), flags (`psa_storage_create_flags_t`).
- `psa_its_set` writes the temp file, closes it, renames over the real name, then calls `remove(temp)`. That remove may fail and is ignored on purpose.
- Key blob (`psa_crypto_storage.c` ~225): magic `"PSA\0KEY"`, version 0, lifetime, type, bits, policy, `data_len`, then `key_data[]`.
- Allocation: `mbedtls_calloc(1, data_length + sizeof(header))`. `key_data[]` is a flexible array member, so the arithmetic is correct. No overflow.
- Size ceiling: with `MBEDTLS_PSA_STATIC_KEY_SLOTS` off (default in `rm_tf_psa_crypto_cfg.h`), `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE` has no effect. The ceiling is about 8191 bytes, so the guard never trips.

## 5. littlefs behaviour that matters
- `lfs->mlist` is the linked list of open files. It is `NULL` at init. Append is at `lfs.c:3064` (`lfs_file_opencfg_`). Remove is at `lfs.c:3215` (`lfs_file_close_`).
- A failed open unlinks itself through `goto cleanup`. So `free(file)` in `rm_littlefs_fopen`'s failure path is safe.
- Anything that frees an `lfs_file_t` without `lfs_file_close()` leaves a dangling `mlist` entry. When no file is open, `mlist` must be `NULL`. This makes a good watchpoint.
- `mlist` is walked only from `lfs_fs_traverse_` (`lfs.c:4693`). That runs only when a write allocates a block: `lfs_alloc()` (653), `lfs_alloc_scan()` (628), `lfs_fs_traverse_` (642). A corrupt `mlist` is dormant until then.
- Inline vs out-of-line: a file stays inline (no block allocation) until it passes `inline_max`. Crossing it runs `lfs_file_outline` then `lfs_file_relocate` then `lfs_alloc`. Default `inline_max` is `min(cache_size, min(attr_max, (metadata_max or block_size) / 8))`. `-1` disables inlining.
- A small blob growth can cross `inline_max` and run the allocation path for the first time. A fault after a library upgrade may come from a latent defect, not a new bug. Check the blob size against `inline_max` first.
- `lfs_alloc_lookahead` and `lfs_alloc` are the only users of the lookahead buffer and `block_count`. Bad config shows no symptom until the first allocation.

## 6. PSA error codes (from `crypto_values.h`)
| Value | Name |
|---|---|
| -132 | GENERIC_ERROR |
| -134 | NOT_SUPPORTED |
| -135 | INVALID_ARGUMENT |
| -136 | INVALID_HANDLE |
| -137 | BAD_STATE |
| -140 | DOES_NOT_EXIST |
| -141 | INSUFFICIENT_MEMORY |
| -146 | STORAGE_FAILURE |

`-135` from `psa_generate_key()` means a key ID is set on a volatile key. It returns before generating. Switching to volatile to isolate persistence proves nothing unless the key ID is also cleared.

## 7. Test setup
`psa_crypto_tests_setup.c` (~182 to 189), under `MBEDTLS_PSA_CRYPTO_STORAGE_C`: the littlefs instance is opened, formatted and mounted once per session. Filesystem state therefore carries across tests. A test that fails only in the full suite may be inheriting state from an earlier test.

Config: `MBEDTLS_PSA_CRYPTO_STORAGE_C` (around line 1322 of `rm_tf_psa_crypto_cfg.h`) enables storage. `MBEDTLS_PSA_ITS_FILE_C` selects the stdio ITS backend. `rm_littlefs_flash.c:54`: the driver needs Flash BGO mode disabled and returns `FSP_ERR_INVALID_ARGUMENT` otherwise.

## 8. Debugging recipes
- Dangling open file: watchpoint `g_rm_littlefs_flash0_lfs.mlist`. It should be `NULL` after every ITS operation. The write that leaves it non-`NULL` is the leak. No rebuild needed.
- Fault in `lfs_fs_traverse_` or `lfs_alloc_scan`: check `mlist` integrity, lookahead config, and `block_count` against flash geometry.
- Fault registers: `BFSR` bit 1 (PRECISERR) with bit 7 (BFARVALID) means `BFAR` is the exact address. `MMFSR = 0` with no MPU stack guard does not prove the stack is fine.
- Same bad address every run means a deterministic stale pointer, not exhaustion. Do not resize heap or stack for that.
- Valid RA4C1 regions: code flash `0x0000_0000`+ (`BSP_ROM_SIZE_BYTES` 0x80000), data flash `0x0800_0000`+ (8 KB), SRAM `0x2000_0000`+. Anything else bus-faults.
