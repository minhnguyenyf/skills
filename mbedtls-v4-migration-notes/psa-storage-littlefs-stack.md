# PSA persistent-key storage → littlefs stack (RA / FSP)

How a persistent PSA key actually reaches flash in this repo, and which layers
are FSP's vs. upstream's. Written while debugging a bus fault in
`TC_API_ECCGenerateKeyPairSignVerify256R1Persistent` (see SKILL.md §9), but
the contents here are general architecture notes, not bug-specific.

Everything below was read from source in this repo, not inferred from upstream
docs. Line numbers are as of the FSPRA-5629 branch.

## 1. The layer stack

```
psa_generate_key()                         tf-psa-crypto/core/psa_crypto.c
  └─ (slot filled with key material in EXPORT representation)
     psa_save_persistent_key()             core/psa_crypto_storage.c:317
       └─ psa_crypto_storage_store()       core/psa_crypto_storage.c
            └─ psa_its_set()               core/psa_its_file.c   <-- uses STDIO
                 └─ fopen/fwrite/fclose/rename/remove
                      └─ [MACRO SHIM]      ra/fsp/inc/instances/rm_stdio_littlefs.h
                           └─ lfs_file_open/lfs_file_write/...   ra/arm/littlefs/lfs.c
                                └─ rm_littlefs_flash             ra/fsp/src/rm_littlefs_flash/
                                     └─ Flash HP driver → data flash
```

The key trap: **`psa_its_file.c` is written against stdio** (`fopen`, `fread`,
`fwrite`, `fseek`, `fclose`, `rename`, `remove`). It has no idea littlefs
exists. FSP interposes a **header-only macro shim** that rewrites those stdio
calls into `lfs_*` calls. So a debugger frame labelled `psa_its_file.c` calling
`lfs_file_write` is expected, not a symbol mix-up.

The call at `psa_crypto.c:1888-1895` is what kicks the whole thing off:

```c
#if defined(MBEDTLS_PSA_CRYPTO_STORAGE_C)
    if (!PSA_KEY_LIFETIME_IS_VOLATILE(slot->attr.lifetime)) {
        /* Key material is saved in export representation in the slot, so
         * just pass the slot buffer for storage. */
        status = psa_save_persistent_key(&slot->attr,
                                         slot->key.data,
                                         slot->key.bytes);
    }
#endif
```

Note it is gated on `!PSA_KEY_LIFETIME_IS_VOLATILE` — the v4 idiom, since
`PSA_KEY_LIFETIME_IS_PERSISTENT` was removed (SKILL.md §5).

## 2. Where each file lives

| Layer | Path |
|---|---|
| PSA core | `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_crypto.c` |
| PSA key storage | `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_crypto_storage.c` / `.h` |
| ITS backend (stdio) | `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_its_file.c` |
| ITS interface | `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_crypto_its.h` |
| stdio→littlefs shim | `ra/fsp/inc/instances/rm_stdio_littlefs.h` (header-only, no `.c`) |
| littlefs | `ra/arm/littlefs/lfs.c` / `lfs.h` (LFS_VERSION 0x00020009 = v2.9; disk 0x00020001) |
| littlefs block device | `ra/fsp/src/rm_littlefs_flash/rm_littlefs_flash.c` |
| lfs instance + config | **generated** into `ra_gen/` — NOT in the repo |

The v3 equivalents live under `ra/arm/mbedtls/library/` (`psa_crypto_storage.c`,
`psa_its_file.c`) if you need to diff.

Because the `lfs_t` and `struct lfs_config` are FSP-Configurator-generated, you
cannot read `block_count`, `block_size`, `cache_size`, `lookahead_size`, or
`inline_max` from source — only `extern` declarations are visible, e.g. in
`psa_crypto_tests_setup.c:56-58`:

```c
extern const struct lfs_config g_rm_littlefs_flash0_lfs_cfg;
extern struct lfs              g_rm_littlefs_flash0_lfs;
extern rm_littlefs_instance_t  g_rm_littlefs_flash0;
```

Inspect them in the debugger, or read the generated `ra_gen/` source on the
build machine. Defaults come from the module description template
`ra/fsp/src/rm_littlefs_flash/.module_descriptions/*.xml` (e.g. lookahead size
default 16, "must be a non-negative multiple of 8").

`rm_stdio_littlefs.h:28-29` binds the shim to whichever instance the project
generated:

```c
extern lfs_t RM_STDIO_LITTLEFS_CFG_LFS;
#define MBEDTLS_CONFIG_LFS    &RM_STDIO_LITTLEFS_CFG_LFS
```

## 3. v3 → v4 diffs in this stack (verified by `diff`)

Good news: this stack barely changed. Do not go hunting for storage-layer API
breakage.

- **`psa_its_file.c`: identical** except one include rename:
  `#include "common.h"` → `#include "tf_psa_crypto_common.h"`.
- **`psa_crypto_storage.c`: identical** except v4 **deleted**:
  - the transaction block (`PSA_CRYPTO_STORAGE_HAS_TRANSACTIONS`:
    `psa_crypto_save_transaction` / `_load_` / `_stop_`), and
  - `mbedtls_psa_storage_inject_entropy` (`MBEDTLS_PSA_INJECT_ENTROPY`).

  Neither is used by these tests. `psa_save_persistent_key`,
  `psa_load_persistent_key`, and `psa_format_key_data_for_storage` are
  unchanged.
- The `psa_crypto_its.h` interface (`psa_its_set` / `_get` / `_get_info` /
  `_remove`) is unchanged.

Consequence: if persistent-key storage misbehaves under v4, the cause is
almost certainly **not** in these two files. Look instead at what *drives*
them (blob size, call ordering) or at the FSP layers below.

## 4. The stdio→littlefs macro shim

`ra/fsp/inc/instances/rm_stdio_littlefs.h` — header-only, all macros:

| stdio | maps to |
|---|---|
| `fopen` | `rm_littlefs_fopen()` — `malloc(sizeof(lfs_file_t))` + `lfs_file_open` |
| `fwrite(data,n,len,s)` | `lfs_file_write(lfs, s, data, n*len)` |
| `fread(data,n,len,s)` | `lfs_file_read(lfs, s, data, n*len)` |
| `fseek(s,off,whence)` | `lfs_file_seek(...) >= 0 ? 0 : -1` |
| `fclose(s)` | `lfs_file_close(lfs, s); free(s)` |
| `remove(p)` | `lfs_remove(lfs, p)` |
| `rename(o,n)` | `lfs_rename(lfs, o, n)` |

`rm_littlefs_fopen` derives flags from only the first mode char:

```c
int flags = ('r' == mode[0]) ? LFS_O_RDONLY : LFS_O_WRONLY | LFS_O_CREAT;
```

`psa_its_file.c` only ever uses `"rb"` and `"wb"`, so this is adequate — but
note no append, no read-write, and `mode[1]` is ignored.

### Hazards in this shim

1. **`fclose` is two unbraced statements.** `lfs_file_close(...); free(stream)`
   with no `do {} while (0)`. Any `if (x) fclose(f);` without braces lets
   `free()` escape the conditional — freeing a handle that was never closed and
   is therefore still linked into `lfs->mlist` (see §6). All four call sites in
   today's `psa_its_file.c` happen to be brace-safe, but this will bite any new
   caller. **Worth fixing upstream in FSP.**
2. **Unmapped stdio functions bind to real newlib.** The shim overrides only
   the seven calls above. If a future `psa_its_file.c` used `ftell`, `fflush`,
   `fprintf`, etc., it would link against genuine newlib stdio and be handed an
   `lfs_file_t *` cast to `FILE *` — immediate memory corruption. Check the
   shim's coverage when bumping the crypto library.
3. **Return-value semantics differ.** `fwrite`/`fread` here return the
   `lfs_*` byte count (or a negative `LFS_ERR_*`), not stdio's *item* count.
   `psa_its_file.c` always passes item size 1, so bytes == items and the
   existing checks work. A caller using a real item size would misread results.
4. **Allocator split.** The shim uses libc `malloc`/`free` for file handles,
   while mbedtls goes through `mbedtls_calloc`/`mbedtls_free` (which the test
   harness wraps for leak tracking in `psa_crypto_tests_setup.c`). Same
   underlying newlib heap, but **littlefs file handles are invisible to the
   harness's leak checker**.

## 5. On-disk formats

### ITS file naming (`psa_its_file.c`)

```c
#define PSA_ITS_STORAGE_PREFIX  ""            /* if not overridden */
#define PSA_ITS_STORAGE_FILENAME_PATTERN "%08x%08x"   /* UID hi, UID lo */
#define PSA_ITS_STORAGE_SUFFIX  ".psa_its"
#define PSA_ITS_STORAGE_TEMP    PSA_ITS_STORAGE_PREFIX "tempfile" PSA_ITS_STORAGE_SUFFIX
```

So key UID `0x…` becomes a flat filename like `0000000100000005.psa_its` in the
littlefs root. Per-file header prepended to the payload:

```c
typedef struct {
    uint8_t magic[8];                               /* "PSA\0ITS\0" */
    uint8_t size[sizeof(uint32_t)];
    uint8_t flags[sizeof(psa_storage_create_flags_t)];
} psa_its_file_header_t;
```

`psa_its_set` is write-to-temp-then-rename: write header+data to
`tempfile.psa_its`, `fclose`, `rename()` over the real name, then
`(void) remove(PSA_ITS_STORAGE_TEMP)` — whose failure is **expected and
deliberately ignored** (the temp file is normally gone after the rename).

### PSA key blob format (`psa_crypto_storage.c:225-234`)

```c
typedef struct {
    uint8_t magic[8];                        /* "PSA\0KEY" */
    uint8_t version[4];                      /* must be 0 */
    uint8_t lifetime[sizeof(psa_key_lifetime_t)];
    uint8_t type[2];
    uint8_t bits[2];
    uint8_t policy[sizeof(psa_key_policy_t)];  /* usage, alg, alg2 */
    uint8_t data_len[4];
    uint8_t key_data[];                      /* flexible array member */
} psa_persistent_key_storage_format;
```

Allocation in `psa_save_persistent_key` is
`mbedtls_calloc(1, data_length + sizeof(psa_persistent_key_storage_format))`;
because `key_data[]` is a flexible array member, `sizeof` counts header only,
so the arithmetic is correct and `psa_format_key_data_for_storage` writes
exactly header + `data_length`. No overflow here — verified.

Size ceiling (`psa_crypto_storage.h:23-31`):

```c
#if defined(MBEDTLS_PSA_STATIC_KEY_SLOTS)
#define PSA_CRYPTO_MAX_STORAGE_SIZE (MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE)
#else
#define PSA_CRYPTO_MAX_STORAGE_SIZE (PSA_BITS_TO_BYTES(PSA_MAX_KEY_BITS))
#endif
```

**Gotcha:** with `MBEDTLS_PSA_STATIC_KEY_SLOTS` *not* defined (the default in
`rm_tf_psa_crypto_cfg.h`), `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE` is
**inert** — setting it does nothing at all. In that configuration the ceiling
is `PSA_BITS_TO_BYTES(PSA_MAX_KEY_BITS)` with
`PSA_MAX_KEY_BITS = 0xfff8` (`crypto_struct.h:302`) ≈ **8191 bytes**, far above
any practical key, so the `data_length > PSA_CRYPTO_MAX_STORAGE_SIZE` guard
effectively never trips.

## 6. littlefs concepts that matter here

### `lfs->mlist` — the open-file list

Singly-linked list of all currently-open files/dirs, head at `lfs->mlist`,
initialised `NULL` in `lfs_init` (`lfs.c:4293`). Helpers are dead simple
(`lfs.c:507-519`) and do **no** validation:

```c
static void lfs_mlist_remove(lfs_t *lfs, struct lfs_mlist *mlist) {
    for (struct lfs_mlist **p = &lfs->mlist; *p; p = &(*p)->next) {
        if (*p == mlist) { *p = (*p)->next; break; }
    }
}
static void lfs_mlist_append(lfs_t *lfs, struct lfs_mlist *mlist) {
    mlist->next = lfs->mlist;
    lfs->mlist = mlist;
}
```

Link/unlink points:
- append: `lfs.c:3064` in `lfs_file_opencfg_`
- remove: `lfs.c:3215` in `lfs_file_close_`
- plus **stack-allocated** temporary entries in `lfs_mkdir_` (2653),
  `lfs_remove_` (3890), `lfs_rename_` (4004) — each restored on every exit
  path, and only used in the `LFS_TYPE_DIR` branch (never for regular files).

Every error path in `lfs_file_opencfg_` *after* the append goes
`goto cleanup` → `lfs_file_close_` → `lfs_mlist_remove` (3189-3195). So a
**failed** open unlinks itself, making the `free(file)` in `rm_littlefs_fopen`'s
failure path safe.

**Why this matters:** anything that frees or abandons an `lfs_file_t` without
`lfs_file_close()` leaves a dangling pointer in `mlist`. Nothing notices until
something walks the list — see below. When no files are open, `mlist` should be
`NULL`, which makes it a good watchpoint target.

### When littlefs walks `mlist` (and allocates)

`lfs_fs_traverse_` iterates open files at `lfs.c:4693-4694`:

```c
for (lfs_file_t *f = (lfs_file_t*)lfs->mlist; f; f = f->next) {
    if (f->type != LFS_TYPE_REG) {
```

The only route here during a write is:

```
lfs_alloc()          lfs.c:653   — needs a free block
  └─ lfs_alloc_scan()  lfs.c:628 — refill lookahead bitmap
       └─ lfs_fs_traverse_(lfs, lfs_alloc_lookahead, lfs, true)   lfs.c:642
```

So `mlist` is only walked **when a write must allocate a fresh block**. A
corrupt `mlist` is completely dormant until then.

### Inline vs. outlined files — the threshold that decides whether you allocate

Small files live *inline* inside the metadata block; no block allocation, so no
`lfs_alloc`, so no `mlist` walk. Crossing the limit forces the file
out-of-line. `lfs.c:3538-3539`:

```c
if ((file->flags & LFS_F_INLINE) &&
        lfs_max(file->pos+nsize, file->ctz.size) > lfs->inline_max) {
    /* → lfs_file_outline → lfs_file_relocate → lfs_alloc → ... */
```

Default `inline_max` when `cfg->inline_max == 0` (`lfs.c:4277-4288`):

```c
inline_max = min(cache_size,
                 min(attr_max,
                     (metadata_max ? metadata_max : block_size) / 8))
```

(`cfg->inline_max == (lfs_size_t)-1` disables inlining entirely.) On mount it
may be clamped again against `attr_max` (`lfs.c:4515`).

**Practical consequence:** a payload growing by even a few bytes can cross
`inline_max` and newly execute the entire allocate/relocate/traverse path for
the first time in a project's life. That makes "worked before, faults now after
a library upgrade" entirely possible with **no bug in the new library** — the
larger blob is merely the trigger exposing a latent defect in the block-alloc
path or in `mlist` hygiene. Check the blob size against `inline_max` before
assuming the upgrade broke storage.

### Allocation is invisible until first use

`lfs_alloc_lookahead` (`lfs.c:614-624`) and `lfs_alloc` (653) are the only
users of `lookahead.buffer` / `lookahead.size` / `block_count`. A bad lookahead
or block-count config therefore produces **zero** symptoms until the first real
block allocation — same dormancy property as `mlist`.

## 7. PSA error code values (verified from `crypto_values.h`)

Useful because these show up as bare negative ints in Unity failures:

| Value | Name | line |
|---|---|---|
| -132 | `PSA_ERROR_GENERIC_ERROR` | 65 |
| -134 | `PSA_ERROR_NOT_SUPPORTED` | 74 |
| -135 | `PSA_ERROR_INVALID_ARGUMENT` | 138 |
| -136 | `PSA_ERROR_INVALID_HANDLE` | 290 |
| -137 | `PSA_ERROR_BAD_STATE` | 127 |
| -140 | `PSA_ERROR_DOES_NOT_EXIST` | 111 |
| -141 | `PSA_ERROR_INSUFFICIENT_MEMORY` | 144 |
| -146 | `PSA_ERROR_STORAGE_FAILURE` | 195 |

**`-135` specifically:** `psa_generate_key()` returns
`PSA_ERROR_INVALID_ARGUMENT` if you set a key ID (`psa_set_key_id()`) on a key
whose lifetime is `PSA_KEY_LIFETIME_VOLATILE`. It fails argument validation and
returns *before generating anything*. So "switch the key to volatile to isolate
the persistence path" is a **useless experiment** unless you also clear the key
ID — otherwise the run proves nothing about key generation.

## 8. Test-side setup

`psa_crypto_tests_setup.c:182-189`, under `#ifdef MBEDTLS_PSA_CRYPTO_STORAGE_C`:

```c
if (RM_LITTLEFS_FLASH_OPEN != ((rm_littlefs_flash_instance_ctrl_t *) g_rm_littlefs_flash0.p_ctrl)->open)
{
    TEST_ASSERT_EQUAL(FSP_SUCCESS, RM_LITTLEFS_FLASH_Open(g_rm_littlefs_flash0.p_ctrl, g_rm_littlefs_flash0.p_cfg));
    TEST_ASSERT_EQUAL(lfs_format(&g_rm_littlefs_flash0_lfs, &g_rm_littlefs_flash0_lfs_cfg), 0);
    TEST_ASSERT_EQUAL(lfs_mount(&g_rm_littlefs_flash0_lfs, &g_rm_littlefs_flash0_lfs_cfg), 0);
}
```

Formats + mounts once per session (guarded on the driver's `open` flag), so
filesystem state **persists across tests within a run**. If an earlier test
corrupts the filesystem or leaks an open file, a later test pays for it — worth
remembering when a test only fails as part of the full suite.

Relevant config in `rm_tf_psa_crypto_cfg.h`: `MBEDTLS_PSA_CRYPTO_STORAGE_C`
(line ~1322) enables the storage layer; `MBEDTLS_PSA_ITS_FILE_C` selects the
stdio ITS backend. `rm_littlefs_flash.c:54` documents that the driver requires
Flash **BGO mode disabled** (blocking flash ops), returning
`FSP_ERR_INVALID_ARGUMENT` otherwise — so a read can't overlap an in-progress
write from the same thread.

## 9. Debugging recipes

- **Suspect a dangling open file:** watchpoint the single word
  `g_rm_littlefs_flash0_lfs.mlist`. It should return to `NULL` after every ITS
  operation. A non-`NULL` write with no matching clear is the leak, and its
  backtrace names the function. No rebuild needed.
- **Fault inside `lfs_fs_traverse_` / `lfs_alloc_scan`:** you are in the
  block-allocation path. Check (a) `mlist` integrity, (b) the lookahead
  config, (c) `block_count` vs. actual flash geometry. Note this path may be
  running for the first time ever — see §6 on `inline_max`.
- **Interpreting the fault registers:** `BFSR` bit 1 `PRECISERR` + bit 7
  `BFARVALID` means `BFAR` holds the exact faulting data address. `MMFSR = 0x0`
  with no MPU stack guard configured means a stack overflow *cannot* raise
  MemManage — it silently yields garbage, so don't read `MMFSR = 0` as
  "stack is fine".
- **Identical fault address across runs ⇒ not exhaustion.** Stack/heap
  exhaustion yields *varying* garbage. A byte-identical bad pointer every run
  means a deterministic stale/dangling pointer. Don't waste rebuilds resizing
  the heap or stack in that case.
- Valid RA4C1 address regions for sanity-checking a pointer: code flash
  `0x0000_0000`+ (`BSP_ROM_SIZE_BYTES` 0x80000), data flash `0x0800_0000`+
  (`BSP_DATA_FLASH_SIZE_BYTES` 0x2000 = 8 KB), SRAM `0x2000_0000`+. Anything
  else is unimplemented and will bus-fault on access.
