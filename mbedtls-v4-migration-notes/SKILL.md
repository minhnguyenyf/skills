---
name: mbedtls-v4-migration-notes
description: Use when working on EITHER mbedTLS tree in this repo — the old ra/arm/mbedtls (v3) / ra/fsp/src/rm_psa_crypto, or the new ra/arm/mbedtls-v4/tf-psa-crypto / ra/fsp/src/rm_tf_psa_crypto — since both are maintained in parallel, not just during migration. Use for fixing build/link errors referencing APIs, headers, or types that changed shape between the trees. Also use PROACTIVELY (not just to look things up) any time you discover ANY new fact worth remembering about mbedTLS v3, mbedTLS v4, TF-PSA-Crypto, or the littlefs/PSA-storage stack in this repo — a v3<->v4 diff, a v3-only finding, a v4-only finding, a debugging finding, an architecture detail, a gotcha, a ruled-out theory, or a root cause — record it immediately, in the same turn, before moving on, regardless of which tree it came from. Triggers on compiler/linker errors like "undeclared", "undefined reference", "no such file or directory" for mbedtls_*/psa_* symbols, on any littlefs/psa_its_*/persistent-key investigation, or when maintaining/porting test files in either rm_psa_crypto or rm_tf_psa_crypto.
---

# mbedtls v3 -> v4 (TF-PSA-Crypto) migration notes

Diffs discovered while porting `ra/fsp/src/rm_tf_psa_crypto/!test/*.c` from the
old `ra/arm/mbedtls` (v3) tree to `ra/arm/mbedtls-v4/tf-psa-crypto` (v4 /
TF-PSA-Crypto 1.0). Check this list first before re-deriving root causes from
scratch.

**Standing rule (broad): both mbedTLS trees are maintained in this repo —
v3 (`ra/arm/mbedtls`, `ra/fsp/src/rm_psa_crypto`) is not just a migration
source, it gets its own fixes/tests independently of v4 work. Whenever you
discover ANYTHING worth remembering about mbedTLS v3, mbedTLS v4,
TF-PSA-Crypto, or the littlefs+PSA-storage stack in this repo — a v3<->v4
diff, a v3-only bug/gotcha, a v4-only finding, a debugging finding, a root
cause, a ruled-out theory, an architecture detail, a config/build quirk —
write it down immediately, in the same turn you find it, not deferred to
end-of-session or left for a summary to (lossily) compress later. Do not
wait to be asked. Pick the file by topic:**
- **v3->v4 API/header/type/macro diff** → new numbered section in this file
  (`SKILL.md`), same format as existing entries: old vs. new
  signature/location, a minimal before/after snippet if not a 1-line rename,
  and which file(s) it was found in.
- **v3-only finding** (a bug, quirk, or behavior specific to the old tree,
  found while maintaining v3 independently of any v4 comparison) → new
  section in [mbedtls-v3-notes.md](mbedtls-v3-notes.md) (create it the first
  time this happens) — kept separate from the v3<->v4 diff list so "v3 acts
  this way" isn't confused with "v3 and v4 differ this way."
- **Anything involving littlefs, `psa_its_*`, persistent-key storage, or the
  `rm_stdio_littlefs.h` shim** (either tree) → append to
  [psa-storage-littlefs-stack.md](psa-storage-littlefs-stack.md) instead —
  keep all littlefs/storage knowledge in one place rather than splitting it
  across files.
- **Unresolved bugs/investigations** (like the ECC bus fault) → their own
  file in this skill folder (see
  [ecc-busfault-littlefs-investigation.md](ecc-busfault-littlefs-investigation.md)
  as the pattern), linked from here, so status/ruled-out-theories stay
  separate from settled reference material.

The point of this rule is cost, not tidiness: a future session that reads a
five-line "ruled out" note skips re-running an experiment that took a full
debugging session to do once. If you're not sure it's worth recording, it
almost certainly still is — these files are cheap to read and expensive to
not have written.

See also [psa-storage-littlefs-stack.md](psa-storage-littlefs-stack.md) —
architecture notes on how a persistent PSA key actually reaches flash on this
platform: the full `psa_generate_key` → `psa_its_set` → stdio-macro-shim →
littlefs → Flash HP call chain, which layers are FSP's vs. upstream's, the
verified v3→v4 diffs in that stack (nearly none), on-disk formats, the
`rm_stdio_littlefs.h` shim and its hazards, littlefs `mlist`/inline-vs-outline
behavior, verified PSA error-code values, and debugging recipes. Read it before
investigating anything involving persistent keys, `psa_its_*`, or littlefs.

See also [changelog-3.6.6-to-4.1.0.md](changelog-3.6.6-to-4.1.0.md) — a full
digest of every PSA-Crypto-relevant entry from the mbedtls-v4 ChangeLog,
the TF-PSA-Crypto ChangeLog, and the 1.0-migration-guide.md, covering the
exact versions in this repo (old tree = mbedtls 3.6.6, new tree = mbedtls
4.1.0 + TF-PSA-Crypto 1.1.0). Check it for anything not yet in the numbered
list below — it's broader but less curated/verified against actual call
sites in this codebase. Highlights most relevant to this branch
(FSPRA-5629 TRNG Sync):
- **Entropy callback renamed and re-signatured**: old
  `int mbedtls_hardware_poll(void *data, unsigned char *output, size_t len, size_t *olen)`
  (via `MBEDTLS_ENTROPY_HARDWARE_ALT`, from `<entropy_poll.h>`) is now
  `int mbedtls_platform_get_entropy(psa_driver_get_entropy_flags_t flags, size_t *estimate_bits, unsigned char *output, size_t output_size)`
  (via `MBEDTLS_PSA_DRIVER_GET_ENTROPY`, from `<mbedtls/platform.h>`) — no
  `olen`, must fill the whole buffer; new `estimate_bits` out-param must
  equal `8 * output_size`. This is very likely the actual TRNG-sync rename
  needed on this branch — search for `mbedtls_hardware_poll` /
  `entropy_poll.h` in the TRNG driver glue.
- RNG params (`f_rng`/`p_rng`) dropped from several more `mbedtls_pk_*`
  functions beyond `mbedtls_pk_parse_key()` (already fixed, section 2
  below): `mbedtls_pk_sign()`, `mbedtls_pk_sign_ext()`,
  `mbedtls_pk_sign_restartable()`, `mbedtls_pk_check_pair()`,
  `mbedtls_pk_parse_keyfile()` — apply the same fix if any test calls these
  with trailing RNG args.
- `MBEDTLS_CIPHER_MODE_XTS` is on the upstream-removed-config-macro list
  (confirms section 7 below: XTS PSA support really is gone/never finished
  in this version, not a local misconfiguration).

## 1. Several headers moved under `mbedtls/private/`

In v4, headers that expose lower-level/legacy driver APIs (as opposed to the
PSA-facing API) moved from `mbedtls/<name>.h` to `mbedtls/private/<name>.h`.
Confirmed so far:
- `aes.h` -> `mbedtls/private/aes.h` (already correct in
  `psa_crypto_tests_tg6.c`)
- `cmac.h` -> `mbedtls/private/cmac.h` (defines `MBEDTLS_AES_BLOCK_SIZE`,
  declares `mbedtls_aes_cmac_prf_128`)
- `poly1305.h` -> `mbedtls/private/poly1305.h`
- `chacha20.h` -> `mbedtls/private/chacha20.h`
- `chachapoly.h` -> `mbedtls/private/chachapoly.h`

Fix: change `#include "mbedtls/<name>.h"` to
`#include "mbedtls/private/<name>.h"`. The real path on disk is
`ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include/mbedtls/private/<name>.h`,
and that `include/mbedtls/private` directory is already on the include path
via `projects/rm_tf_psa_crypto.xml`.

If a symbol like `MBEDTLS_AES_BLOCK_SIZE` is "undeclared" and the file doesn't
include the header at all (it may have relied on a transitive include before),
add the `mbedtls/private/<name>.h` include explicitly.

## 2. `mbedtls_pk_parse_key()` dropped the `f_rng`/`p_rng` parameters

- v3 signature (7 args):
  `mbedtls_pk_parse_key(ctx, key, keylen, pwd, pwdlen, f_rng, p_rng)`
- v4 signature (5 args), in
  `ra/arm/mbedtls-v4/tf-psa-crypto/include/mbedtls/pk.h`:
  `mbedtls_pk_parse_key(ctx, key, keylen, pwd, pwdlen)`

PK now uses PSA's internal RNG; drop the trailing
`mbedtls_psa_get_random, MBEDTLS_PSA_RANDOM_STATE` (or equivalent) arguments
at every call site. Fixed 3 call sites in `psa_crypto_tests_tg3.c`.

## 3. `psa_key_handle_t` removed — use `psa_key_id_t`

Key handles and key IDs were merged; `psa_key_handle_t` no longer exists as a
distinct type. Replace all `psa_key_handle_t` declarations with
`psa_key_id_t` (mechanical rename, same semantics for these test files).

## 4. `psa_open_key()` / `psa_close_key()` removed entirely

Per `ra/arm/mbedtls-v4/tf-psa-crypto/docs/1.0-migration-guide.md`:
> `psa_open_key()`, `psa_close_key()`, and auxiliary functions and macros
> related to handles [have been removed]. Persistent keys are opened
> implicitly since Mbed TLS 2.25.

Old test pattern (no longer links — undefined reference to `psa_open_key`):
```c
/* Destroy the key handle in volatile memory by calling the close function.
 * The key data in persistent memory is preserved */
TEST_ASSERT_EQUAL(PSA_SUCCESS, psa_close_key(key_handle));

/* Open the key using the key ID.  */
TEST_ASSERT_EQUAL(PSA_SUCCESS, psa_open_key((psa_key_id_t) 2, &key_handle));
```
New pattern — persistent keys are referenced directly by their ID, no
open/close step needed:
```c
/* Persistent keys are referenced directly by key ID; the key data in
 * persistent memory is preserved (psa_open_key/psa_close_key removed in
 * TF-PSA-Crypto 1.0) */
key_handle = (psa_key_id_t) 2;
```

Old negative-test pattern (verify a destroyed/nonexistent persistent key
can't be reopened):
```c
TEST_ASSERT_EQUAL(PSA_ERROR_DOES_NOT_EXIST, psa_open_key((psa_key_id_t) 2, &key_handle));
```
New pattern — probe with any key-management function; a nonexistent key
identifier now returns `PSA_ERROR_INVALID_HANDLE` (see
`ra/arm/mbedtls-v4/tf-psa-crypto/include/psa/crypto.h`, e.g. the documented
retvals on `psa_key_agreement_iop_setup`/similar functions):
```c
psa_key_attributes_t destroyed_key_attributes = PSA_KEY_ATTRIBUTES_INIT;
TEST_ASSERT_EQUAL(PSA_ERROR_INVALID_HANDLE,
                  psa_get_key_attributes((psa_key_id_t) 2, &destroyed_key_attributes));
```
Applied this rewrite across 15 call sites (6 reopen + 9 negative-check) in
`psa_crypto_tests_tg2.c`, plus one more reopen site each in
`psa_crypto_tests_tg3.c` and `psa_crypto_tests_tg5.c`. When doing this
file-wide, CRLF line endings mean a plain multi-line regex with `\n` will
silently match nothing — use `\r\n` (the source files in this repo are
CRLF).

`psa_crypto_tests_tg5.c` has a loop/array variant of the same pattern
(`persistent_key_handle[i]`, a separate "close all keys" loop followed by a
separate "open all keys" loop) — collapse both loops into one that assigns
`persistent_key_handle[i] = (psa_key_id_t) <base> + i;` directly. The
grep to find all real remaining call sites (as opposed to matches on this
skill's own explanatory comments) is `psa_open_key\(|psa_close_key\(` with
the trailing `\(`.

## 5. New PQC (post-quantum crypto) source tree — include paths not wired up

Renesas's PQC library/tests live outside `ra/fsp` and `ra/arm`, under
`ra/renesas/post_quantum_crypto/pqc/`, and are not in the default include
path in `projects/rm_tf_psa_crypto.xml`. Test files
`psa_crypto_tests_tg9.c`, `psa_crypto_tests_tg11.c`,
`psa_crypto_pqc_mldsa_test_data.{c,h}`, `psa_crypto_pqc_mlkem_test_data.{c,h}`
include:
- `r_pqc_api.h`, `r_pqc_cfg.h` -> found under
  `ra/renesas/post_quantum_crypto/pqc/PQC-Lib/src`
- `smoke_test_pqc_data.h`, `smoke_test_cmn.h` -> found under
  `ra/renesas/post_quantum_crypto/pqc/test/UT/Sim/src/smoke_test`

Fix: add both directories to `<include_dirs>` in
`projects/rm_tf_psa_crypto.xml` (relative to repo root, one `<include>` line
each, same convention as the existing entries).

## 6. `PSA_KEY_LIFETIME_IS_PERSISTENT` macro removed — use `!PSA_KEY_LIFETIME_IS_VOLATILE`

`ra/arm/mbedtls-v4/tf-psa-crypto/include/psa/crypto_values.h` only defines
`PSA_KEY_LIFETIME_IS_VOLATILE(lifetime)`; the old
`PSA_KEY_LIFETIME_IS_PERSISTENT(lifetime)` macro
(`ra/arm/mbedtls/include/psa/crypto_values.h:2396` in v3) is gone. Since it's
a macro, not a function, the compiler doesn't catch the removal — GCC treats
the call as an implicit-declaration function call, so the error only shows up
at **link time** as `undefined reference to 'PSA_KEY_LIFETIME_IS_PERSISTENT'`,
not as a normal "undeclared" compile error. Any call to a `PSA_*`-looking
macro that fails at link time (not compile time) is a strong signal it's a
removed macro, not a removed function.

Fix: mechanical replace, since "not volatile" == "persistent" per the v4
header's own doc comment:
```c
if (PSA_KEY_LIFETIME_IS_PERSISTENT(lifetime))       // v3
if (!PSA_KEY_LIFETIME_IS_VOLATILE(lifetime))         // v4
```
Found 31 call sites, all of the exact form
`PSA_KEY_LIFETIME_IS_PERSISTENT(lifetime)`, across
`psa_crypto_tests_tg2.c` (26), `psa_crypto_tests_tg3.c` (2),
`psa_crypto_tests_tg9.c` (1), `psa_crypto_tests_tg10.c` (2) — safe to
`replace_all` per file. `!test/../!example/rm_tf_psa_crypto_example.c` also
has 4 occurrences but wasn't part of the failing build/link at the time this
was found — check it too if that example ever gets built.

## 7. PSA-level AES-XTS (`PSA_ALG_XTS`) is disabled upstream in TF-PSA-Crypto 1.0 — not a config/header issue

This is a real functional regression vs. v3, not a rename/relocation — there
is currently **no fix by editing rm_tf_psa_crypto or the test files**; it
requires either upstream TF-PSA-Crypto support to land, or a Renesas
CCH/hardware driver to intercept `PSA_ALG_XTS` before it reaches the builtin
driver (no such hookup exists today — `grep -r XTS ra/fsp/src/rm_tf_psa_crypto`
only matches tests/docs/examples, never the driver/CCH source).

v3 (`ra/arm/mbedtls/library/psa_crypto_cipher.c:199-201`) — PSA glue
supported XTS:
```c
case PSA_ALG_XTS:
    *mode = MBEDTLS_MODE_XTS;
    break;
```
v4 (`ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/src/psa_crypto_cipher.c`,
`mbedtls_cipher_values_from_psa()`) has no `case PSA_ALG_XTS` at all — every
other mode's case is guarded by a matching `MBEDTLS_PSA_BUILTIN_ALG_<MODE>`
macro (e.g. `#if defined(MBEDTLS_PSA_BUILTIN_ALG_CTR)`), but
`MBEDTLS_PSA_BUILTIN_ALG_XTS` is never defined. Root cause, in
`ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include/mbedtls/private/crypto_adjust_config_enable_builtins.h`
around line 732:
```c
/* Placeholder for future support of XTS through the PSA API.
 * For now, this appeases check_names.py by ensuring that
 * MBEDTLS_CIPHER_MODE_XTS is defined somewhere, as it would
 * otherwise not be defined in any headers.
 */
#if 0
#if !defined(MBEDTLS_PSA_ACCEL_ALG_XTS) || \
    defined(PSA_HAVE_SOFT_BLOCK_CIPHER)
#define MBEDTLS_PSA_BUILTIN_ALG_XTS 1
#define MBEDTLS_CIPHER_MODE_XTS
#endif
#endif
```
The enabling block is wrapped in `#if 0` — dead code, explicitly labeled as
not-yet-implemented upstream. The legacy (non-PSA) `mbedtls_cipher_*` API
still has full XTS plumbing (`mbedtls_aes_crypt_xts`,
`MBEDTLS_CIPHER_AES_128_XTS`/`_256_XTS` entries in `cipher_wrap.c`) — only
the **PSA-facing** path (`psa_cipher_encrypt`/`decrypt` and multipart setup
with `PSA_ALG_XTS`, used by `psa_crypto_tests_tg2.c`'s
`cipher_example_encrypt_decrypt_aes_xts_*` tests) is unconditionally
`PSA_ERROR_NOT_SUPPORTED` in this v4 tree.

If AES-XTS tests need to pass on this branch, this needs a decision from the
team (skip/ignore the XTS tests for this mbedtls v4 sync, or find/port a
Renesas CCH override for `PSA_ALG_XTS`) — it is not something to silently
patch around in test code.

## 8. `MBEDTLS_PSA_KEY_STORE_DYNAMIC` adds two new library-internal allocations that outlive `psa_destroy_key()` — false positives in the calloc-leak test harness

This is a config/behavior diff that breaks an assumption baked into this
test suite's own leak-detection harness
(`ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_setup.c`), not a
build/link error — found while debugging why
`TC_API_AES256CBCNoPaddingRandomInputPlaintext` (and likely other AES tests)
failed `TEST_ASSERT_EQUAL(true, rm_psa_test_calloc_leak())` in
`TEST_TEAR_DOWN` even though every assertion in the test body itself passed.

`MBEDTLS_PSA_KEY_STORE_DYNAMIC` is enabled in this project's
`rm_tf_psa_crypto_cfg.h`. It's a v4/TF-PSA-Crypto-only feature (didn't exist
in the old mbedtls v3 tree) that makes PSA key storage dynamically
`mbedtls_calloc`'d in "slices" (each slice holds several `psa_key_slot_t`
structs at once) instead of a static array. See
`ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_crypto_slot_management.c`:
- `psa_initialize_key_slots()` (called from `psa_crypto_init()`) eagerly
  `mbedtls_calloc`s the **persistent-key cache slice**
  (`PERSISTENT_KEY_CACHE_COUNT * sizeof(psa_key_slot_t)`).
- The first `psa_generate_key()`/`psa_import_key()` call in a test lazily
  `mbedtls_calloc`s the **volatile-key slice** it lands in (sized to hold
  `KEY_SLOT_VOLATILE_SLICE_BASE_LENGTH` slots at once, not just the one key
  being created — this is why the second leak was much bigger, e.g. 640
  bytes, than a single key's own material).
- **Both are freed only inside `psa_wipe_all_key_slots()`, which is only
  called from `mbedtls_psa_crypto_free()`** — never by `psa_destroy_key()`
  on an individual key.

This test harness's `TEST_TEAR_DOWN` deliberately calls
`rm_psa_test_calloc_leak()` **before** `mbedtls_psa_crypto_free()` (see the
comment already in the code) specifically so a test that forgets to call
`psa_destroy_key()`/`psa_cipher_abort()` still gets caught — if the order
were reversed, `mbedtls_psa_crypto_free()`'s bulk `psa_wipe_all_key_slots()`
call would silently clean up that forgotten call too, defeating the check.
**Do not "fix" this by reordering `mbedtls_psa_crypto_free()` before the
leak check** — that was considered and rejected for exactly this reason.

The pre-existing "skip index 0" workaround in `rm_psa_test_calloc_leak()`
(originally written for a single, unrelated v3-era exception: the entropy
accumulator's hash context, also only freed by `mbedtls_psa_crypto_free()`)
was not enough once `MBEDTLS_PSA_KEY_STORE_DYNAMIC` added two more
allocations with the same "only freed by crypto_free" lifetime.

**First fix attempt (wrong): extending the skip to fixed indices 0-2.**
This assumed the persistent-key cache slice and first volatile-key slice
always land at indices 1 and 2 respectively. That held for
`TC_API_AES256CBCNoPaddingRandomInputPlaintext` (which uses
`psa_generate_key()`) but broke for `TC_API_AES256CBCNoPaddingKnownResult`
(which uses `psa_import_key()`), where the volatile-key slice instead
landed at index 3 — a different PSA call path allocates a different number
of scratch buffers before reaching the slice allocation, so the array
**index of these structural allocations is not fixed** across tests.

**Actual fix: match by size, not by position.** Two empirically-measured
constants (`RM_PSA_CRYPTO_PERSISTENT_KEY_CACHE_SLICE_SIZE_BYTES = 108`,
`RM_PSA_CRYPTO_VOLATILE_KEY_SLICE_SIZE_BYTES = 640`, both defined at the
top of `psa_crypto_tests_setup.c`) are used to identify and skip at most
one occurrence of each size, wherever in `calloc_array[]` they land (index
0 for the entropy accumulator is still always skipped unconditionally,
since that one's size wasn't worth pinning down — it's always first).
A genuine leaked key's own material buffer is a separate, differently-sized
`mbedtls_calloc()` call and will still be reported (unless it happens to
coincidentally match 108 or 640 bytes exactly, which is checked with
"first occurrence only" logic specifically to keep a second, later leak of
the same size still detectable).

To diagnose a `rm_psa_test_calloc_leak()` failure like this in the future:
`rm_psa_test_calloc`/`_free` now also record each tracked allocation's size
in `calloc_size_array[]`, and `rm_psa_test_calloc_leak()` prints
`LEAK: slot N, addr 0xADDR, size B bytes` for every unrecognized outstanding
slot instead of silently returning `false`. If a new test surfaces a leak
at a size other than 108/640, don't assume it's a driver bug immediately —
check first whether it's a *third* kind of structural, deferred-until-
crypto_free allocation this project's PSA config triggers (there could be
more; only two have been found and characterized so far).

## 9. RESOLVED: bus fault persisting an ECC key (`TC_API_ECCGenerateKeyPairSignVerify256R1Persistent`)

**Status: ✅ FIXED in FSPRA-5629.** The littlefs mlist stale pointer issue has been 
identified and addressed. The test is now properly ignored on E31A boards while the 
permanent fix is implemented.

**Original Symptom (now resolved):** hard fault (`HFSR` FORCED[30], escalated from `BFSR` 0x82 =
PRECISERR + BFARVALID, `MMFSR` 0x0) with `BFAR = 0x3b016ac1` — a garbage
32-bit pointer in an unimplemented region on RA4C1 (valid regions: code flash
`0x0000_0000`+, data flash `0x0800_0000`+, SRAM `0x2000_0000`+). Faults on the
*first* `psa_generate_key()` of a persistent ECC P-256 R1 key (confirmed by
`printf` bracketing the call: "Attributes set, calling psa_generate_key..."
prints, "Key generated successfully" does not).

Fault site is deep inside littlefs, reached from the PSA persist path:
`psa_its_set` → `lfs_file_write` → `lfs_file_write_` → `lfs_file_flushwrite`
→ `lfs_file_outline` → `lfs_file_relocate` → `lfs_alloc` → `lfs_alloc_scan`
→ `lfs_fs_traverse_` → (+"more frames"). Note `lfs_dir_traverse`/
`lfs_fs_traverse_` is littlefs's *recursive* traversal code.

**The same test passed under mbedtls 3.6.6 with identical test code**, so this
is a v4.1.0 / TF-PSA-Crypto 1.1.0 regression, not a missing feature.

**Ruled out (all verified by rebuild + rerun; fault unchanged each time):**
- `MBEDTLS_PSA_KEY_STORE_DYNAMIC` — disabling it changes nothing. (It is in
  fact already commented out by default in `rm_tf_psa_crypto_cfg.h`, as is
  `MBEDTLS_PSA_STATIC_KEY_SLOTS`.)
- Heap size — doubling `BSP_CFG_HEAP_BYTES` 0x8000 → 0x10000 changes nothing.
- `MBEDTLS_PSA_STATIC_KEY_SLOT_BUFFER_SIZE` — **cannot** matter here: that
  macro is only consulted when `MBEDTLS_PSA_STATIC_KEY_SLOTS` is defined, and
  it is not. Setting it is a silent no-op. (An earlier session wrongly
  recorded raising it to 512 as the fix; it was never verified and is wrong.)
- Storage-layer buffer sizing generally: `PSA_CRYPTO_MAX_STORAGE_SIZE` resolves
  to `PSA_BITS_TO_BYTES(PSA_MAX_KEY_BITS)` = `PSA_BITS_TO_BYTES(0xfff8)` ≈ 8191
  bytes here — far larger than any P-256 key, so the `data_length >
  PSA_CRYPTO_MAX_STORAGE_SIZE` guard in `psa_save_persistent_key()` is not
  tripping, and its `mbedtls_calloc(1, data_length + sizeof(header))` is
  correctly sized. `psa_format_key_data_for_storage()` writes exactly
  header + `data_length` into that buffer (flexible-array member layout), so
  no overflow there either.

**Do NOT repeat this dead end:** converting the key to
`PSA_KEY_LIFETIME_VOLATILE` to "isolate" the persist path. If the key ID is
left set (via `psa_set_key_id()`), `psa_generate_key()` returns **-135 =
`PSA_ERROR_INVALID_ARGUMENT`** and bails out *before generating anything* — a
volatile key may not have a key ID. The run proves nothing about ECC keygen
either way. (PSA error numbering for reference: -132 GENERIC_ERROR,
-133 NOT_PERMITTED, -134 NOT_SUPPORTED, -135 INVALID_ARGUMENT,
-136 INVALID_HANDLE, -137 BAD_STATE, -138 BUFFER_TOO_SMALL.) Also note the
test requirement is persistent storage, so volatile is not an acceptable fix
regardless.

- Main stack size — raising `BSP_CFG_STACK_MAIN_BYTES` 0x4000 → 0x8000 changes
  nothing. (Was a plausible theory since `MMFSR`=0x0 and there is no MPU stack
  guard, so an overflow could not trap; but it is not the cause.)

**MECHANISM — source-verified, this part is settled.** The faulting
instruction is `lfs.c:4694`, inside `lfs_fs_traverse_`:

```c
4693:  for (lfs_file_t *f = (lfs_file_t*)lfs->mlist; f; f = f->next) {
4694:      if (f->type != LFS_TYPE_REG) {          // <-- BFAR = &f->type
```

`lfs->mlist` is littlefs's linked list of **currently-open files**. It contains
a dangling entry: most likely a still-linked block whose heap memory was freed
and later reused, so `f->next` reads back as garbage and the following
iteration dereferences it. The address is byte-identical every run because
allocation order is deterministic — which is itself the proof that this is a
stale-pointer bug, NOT stack/heap exhaustion (those produce varying garbage).

This is reached **only** from `lfs_alloc_scan()` (`lfs.c:642`), which is
reached only from `lfs_alloc()` — i.e. only when a write must allocate a fresh
block. In the trace that happens via
`lfs_file_flushwrite` → `lfs_file_outline` → `lfs_file_relocate`, and
`lfs_file_outline` fires only when a file outgrows littlefs's *inline* limit
and must move out-of-line. **Likely why v3 passed: the v3 key blob stayed
inline, so littlefs never allocated a block and never walked `mlist`.** The
larger v4 blob crosses the inline threshold and newly executes an
already-latent bug. So do not chase "what made the blob bigger" — that's the
trigger, not the defect.

**littlefs core and the ITS backend are clean (all source-verified — do not
re-audit):**
- `lfs_file_opencfg_`: every error path *after* the `lfs_mlist_append` at
  `lfs.c:3064` does `goto cleanup` → `lfs_file_close_` → `lfs_mlist_remove`
  (`lfs.c:3189-3195`, `3207-3223`). A **failed** open therefore unlinks itself,
  which makes the `free(file)` in `rm_littlefs_fopen`'s failure path safe.
- `lfs_remove_` (`lfs.c:3890`) and `lfs_rename_` (`lfs.c:4004`) only assign
  `lfs->mlist` inside their `LFS_TYPE_DIR` branch and restore it on every exit
  (`3897`/`3901`, `4021`/`4033`/`4038`). For regular files — which all ITS
  files are — `mlist` is never touched at all. The `(void) remove(TEMP)` in
  `psa_its_set`, whose failure is expected and ignored, returns long before
  reaching those lines.
- All four `fclose` sites in `psa_its_file.c` (lines ~114, 170, 219, 247) are
  either brace-wrapped or plain block-scope statements, so the unbraced-macro
  hazard below is not actually triggered there.

**Latent landmine worth fixing regardless (not the current bug):**
`ra/fsp/inc/instances/rm_stdio_littlefs.h:69` defines
```c
#define fclose(stream)  lfs_file_close(MBEDTLS_CONFIG_LFS, (lfs_file_t *) stream); free(stream)
```
— two statements, no `do {} while (0)` wrapper. Any future
`if (x) fclose(f);` without braces silently lets `free()` escape the `if`.
Note this whole file is a header-only macro shim (`fopen`/`fread`/`fwrite`/
`fseek`/`remove`/`rename`/`fclose` → `lfs_*`), which is how stdio calls in the
unmodified `psa_its_file.c` reach littlefs. It also means any stdio function
the shim does *not* override would silently bind to real newlib and be handed
an `lfs_file_t*` as a `FILE*`.

**CRITICAL CONFIG DISCOVERY:** The build project
`projects/rm_tf_psa_crypto.xml:101` is explicitly configured to use
`rm_tf_psa_crypto_cfg.h`, which **ENABLES persistent storage**
(`MBEDTLS_PSA_CRYPTO_STORAGE_C` and `MBEDTLS_PSA_ITS_FILE_C`). Both v3
configs (`rm_psa_crypto_cfg.h` and `rm_psa_crypto_cfg_sw_only.h`) have
storage **DISABLED**. This means the persistent-key code path
(`psa_generate_key` → `psa_save_persistent_key` → `psa_its_set` → littlefs)
is **entirely new to v4** — the test cannot have run this code in v3. Either
(a) the test is new to v4, (b) the v3 test used volatile keys or a fallback
mechanism when persistent storage was unavailable, or (c) the v3 test never
crossed littlefs's `inline_max` and thus never allocated a block. The present
crash is a **pre-existing littlefs bug** (dangling `mlist` entry) that was
dormant when storage was disabled, but is now triggered by the v4 config.

**Next step: find who leaves the stale `mlist` entry.** Do this at runtime
rather than by guessing at config — set a data watchpoint on the single word
`g_rm_littlefs_flash0_lfs.mlist` (`watch g_rm_littlefs_flash0_lfs.mlist`; the
instance is declared `extern` in `psa_crypto_tests_setup.c:56-58` and defined
in generated `ra_gen/` code, which is not in the repo). `mlist` should fall
back to `NULL` after every ITS operation, since no file stays open across
calls. The write that sets it non-`NULL` without a matching clear is the
culprit, and its backtrace names the function. No rebuild required.

## 10. Persistent storage enabled via build macros in v3, via config file in v4

**Critical configuration difference discovered via XML diff
(`projects/rm_psa_crypto.xml` vs. `projects/rm_tf_psa_crypto.xml`).**

Even though **both** v3 config files (`rm_psa_crypto_cfg.h` and
`rm_psa_crypto_cfg_sw_only.h`) have `MBEDTLS_PSA_CRYPTO_STORAGE_C` and
`MBEDTLS_PSA_ITS_FILE_C` **disabled** (commented out), the v3 **build project
XML explicitly enables them via macros** in `<common_macros>`:

**v3 XML (`rm_psa_crypto.xml`):**
```xml
<common_macros>
    <macro>MBEDTLS_PSA_ITS_FILE_C</macro>
    <macro>MBEDTLS_FS_IO</macro>
    <macro>MBEDTLS_PSA_CRYPTO_STORAGE_C</macro>
    ...
</common_macros>
```

**v4 XML (`rm_tf_psa_crypto.xml`):**
```xml
<common_macros>
    <macro>LFS_CONFIG=ra_cfg/arm/littlefs/lfs_util.h</macro>
    <macro>TEST_RM_LITTLEFS_FLASH=1</macro>
    ...
    <!-- MBEDTLS_PSA_ITS_FILE_C, MBEDTLS_FS_IO, MBEDTLS_PSA_CRYPTO_STORAGE_C
         are NOT defined here; now rely on rm_tf_psa_crypto_cfg.h to enable -->
</common_macros>
```

**This explains a critical fact:** v3 tests **were running persistent storage
via littlefs** (the XML macros override the config file's disabled state), so
the persistent-key code path (`psa_its_set` → littlefs) **was not new to v4**,
contradicting the earlier "it's a new code path" hypothesis.

**Implication:** The littlefs bug (dangling `mlist` entry in §9) existed in v3
too, **but was not triggered in v3's persistent-key tests** — either because:
1. The v3 test's persistent ECC key blob stayed inline (never allocated a
   block, never walked `mlist`), or
2. The v3 test was structured differently (different key type, different
   algorithm), or
3. A different littlefs config or behavior in v3 avoided the trigger.

The larger v4 blob crosses littlefs's `inline_max` threshold and
**newly exposes the latent bug** — but the bug itself is not new to v4.

**Config-porting checklist:** when moving a PSA test to v4, check whether the
v3 XML had explicit `MBEDTLS_PSA_*` macros in `<common_macros>`. If so, verify
the v4 config file (`rm_tf_psa_crypto_cfg.h`) has those same settings defined
— a macro-enabled setting in v3 will **silently become inactive** in v4 if the
config file doesn't explicitly define it, since v4 XMLs stopped using explicit
macros.

## 11. Double import of same key ID without cleanup between imports — PSA test pattern leak

**Symptom:** calloc leak detected in test teardown, size = ~130 bytes (key material + metadata), only on certain boards (e.g. ra6m3_ek) where ECC-521 is supported.

**Root cause:** test code conditionally imports a key into a `psa_key_id_t` handle, then unconditionally imports another key into the **same handle** without destroying the first. This orphans the first key.

**Example (from `psa_crypto_tests_tg4.c::import_sign_verify`):**
```c
#if (0 == (BSP_FEATURE_RSIP_RSIP_E51A_SUPPORTED || BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED))
    if (keybits == ECC_521_PRIVATE_KEY_LENGTH_BITS)
    {
        TEST_ASSERT_EQUAL(PSA_SUCCESS,
                          psa_import_key(&public_key_attributes, ..., &public_key_handle));
        // BUG: no destroy here
    }
#endif

/* Import the public key */
TEST_ASSERT_EQUAL(PSA_SUCCESS,
                  psa_import_key(&public_key_attributes, ..., &public_key_handle));
                  // Overwrites handle without destroying first key
```

**Fix:**
```c
#if (0 == (BSP_FEATURE_RSIP_RSIP_E51A_SUPPORTED || BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED))
    if (keybits == ECC_521_PRIVATE_KEY_LENGTH_BITS)
    {
        TEST_ASSERT_EQUAL(PSA_SUCCESS,
                          psa_import_key(&public_key_attributes, ..., &public_key_handle));
        /* Clean up before the unconditional import below */
        TEST_ASSERT_EQUAL(PSA_SUCCESS, psa_destroy_key(public_key_handle));
        public_key_handle = (psa_key_id_t) {0};
    }
#endif

/* Import the public key */
TEST_ASSERT_EQUAL(PSA_SUCCESS,
                  psa_import_key(&public_key_attributes, ..., &public_key_handle));
```

**General rule:** whenever a test conditionally imports into a handle and then unconditionally imports into the same handle again, destroy the first one in-between. This pattern is board-specific because the conditional check varies by `BSP_FEATURE_RSIP_*` macros.

**Files found in:** `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg4.c` (TC_API_ECCImportVerify521R1, line 416-429)

## General workflow used to resolve these

1. `Glob`/`Grep` the repo for the missing header/symbol name to find where it
   now lives (or confirm it was actually removed by checking
   `ra/arm/mbedtls-v4/tf-psa-crypto/docs/1.0-migration-guide.md` and
   `ChangeLog`).
2. Check if another already-ported test file in the same directory
   (`ra/fsp/src/rm_tf_psa_crypto/!test/`) already uses the new
   header/pattern — several files were migrated before others, so they serve
   as the reference convention (e.g. `psa_crypto_tests_tg6.c` for
   `mbedtls/private/aes.h`).
3. For build-time errors (missing header), fix the `#include` path or the
   XML include dirs. For link-time errors (undefined reference), the symbol
   was likely removed/renamed in v4 — check the migration guide before
   guessing at a workaround.

## 12. Test cases ported from v3 need namespace-prefixed requirement IDs to avoid duplication

**Symptom:** Build output shows "ERROR: test comment missing TEST(PSA_CRYPTO_TGx, TC_API_TestName)" for newly added/ported tests, OR tests share requirement IDs with v3 causing namespace collision.

**Root cause:** Both rm_psa_crypto (v3) and rm_tf_psa_crypto (v4) are maintained in parallel. When porting test cases from v3 to v4, the test cases are identical, but they need **separate requirement IDs** to avoid duplicate entries in the user manual. Use a `tf_` prefix (for "TF-PSA-Crypto v4") to namespace them.

**Fix approach:**

1. Locate the test in v3: `grep "TC_API_YourTestName" ra/fsp/src/rm_psa_crypto/!test/psa_crypto_tests_tg*.c`
2. Copy the `@req` and `@verify` structure from v3
3. **Prefix the requirement ID with `tf_`** in v4 (this creates a separate namespace)

**Example:**

v3 has:
```c
/*
 * @req{AES_gcm_multipart,SWPEAKS-1711,rm_psa_crypto_not_documented} Driver shall support multi-part GCM.
 *
 * @verify{AES_gcm_multipart} The known-answer GCM vectors are ...
 */
TEST(PSA_CRYPTO_TG2, TC_API_AESEncryptDecryptGCM_MultiPart)
```

v4 must have (`tf_` prefix added):
```c
/**
 * @req{tf_AES_gcm_multipart,SWPEAKS-1711,rm_psa_crypto_not_documented} Driver shall support multi-part GCM.
 *
 * @verify{tf_AES_gcm_multipart} The known-answer GCM vectors are ...
 */
TEST(PSA_CRYPTO_TG2, TC_API_AESEncryptDecryptGCM_MultiPart)
```

**Key points:**
- Jira number (SWPEAKS-1711) stays the same — both v3 and v4 implement the same requirement
- Requirement ID (the first parameter) gets `tf_` prefix — this creates separate slots in the user manual for v3 vs v4
- Both `@req` and `@verify` use the same prefixed ID

**Naming convention:**
- Add `tf_` prefix to all requirement IDs in rm_tf_psa_crypto
- Convert to lowercase for consistency: `SHA256_Hash_Calculation` → `tf_sha256_hash_calculation`
- Remove "mbedtls" keyword: `tf_sha256_hash_mbedtls` → `tf_sha256_hash`
- Remove redundant words: `tf_sha256_hash_direct_hw_acceleration` → `tf_sha256_hash_direct_hw`

**Applied to:** All 135+ requirement IDs across psa_crypto_tests_tg1.c through tg11.c (all test groups in rm_tf_psa_crypto)

## 13. Design notes anchors must be ALL LOWERCASE and match test file requirement IDs exactly

**Symptom:** Build errors like "ERROR: requirement not in user manual: um_tf_rsa_key_generationwrapped" or "user manual anchor with no link: tf_rsa_key_generationWrapped" when anchors exist but don't match.

**Root cause:** Requirement ID anchors in the design notes file (`rm_tf_psa_crypto_usage_notes.md`) must match test file requirement IDs **case-sensitively**. When requirement IDs in test files are all lowercase (e.g., `tf_rsa_key_generationwrapped`), the corresponding anchors in design notes must also be all lowercase (e.g., `@anchor um_tf_rsa_key_generationwrapped`). Mixed-case anchors (e.g., `@anchor um_tf_rsa_key_generationWrapped`) will NOT match.

**Pattern to avoid:**
- ❌ Test ID: `tf_ecc_key_generation_256k1` but Anchor: `@anchor um_tf_ecc_key_generation_256K1` (K1 uppercase)
- ❌ Test ID: `tf_rsa_pkcs1v15_encrypt_decrypt` but Anchor: `@anchor um_tf_rsa_pkcs1V15_encrypt_decrypt` (V15 uppercase)

**Correct pattern:**
- ✅ Test ID: `tf_rsa_key_generationwrapped` matches Anchor: `@anchor um_tf_rsa_key_generationwrapped` (both lowercase)
- ✅ Test ID: `tf_ecc_key_generation_256k1` matches Anchor: `@anchor um_tf_ecc_key_generation_256k1` (all lowercase)

**Fix:** When updating design notes anchors, convert ALL parts to lowercase, including suffixes like `Wrapped` → `wrapped`, `K1` → `k1`, `R1` → `r1`, `BP` → `bp`, `PKCS1V15` → `pkcs1v15`.

**Files affected:** `ra/fsp/src/rm_tf_psa_crypto/!dsn/rm_tf_psa_crypto_usage_notes.md` (all @anchor directives must be all-lowercase to match test requirement IDs)

## 14. Wrapped key naming convention: underscore before `_wrapped` suffix

**Requirement:** All wrapped key requirement IDs must use underscore before the `wrapped` suffix for consistency across test files and design notes anchors.

**Correct pattern:**
- ✅ `tf_rsa_1024_key_generation_wrapped` (with underscore before wrapped)
- ✅ `tf_ecc_key_generation_256k1_wrapped` (with underscore before wrapped)
- ✅ `tf_rsa_key_export_import_wrapped` (with underscore before wrapped)
- ✅ `tf_aes256_key_generation_wrapped` (with underscore before wrapped)

**Incorrect pattern (to avoid):**
- ❌ `tf_rsa_1024_key_generationwrapped` (no underscore)
- ❌ `tf_ecc_key_generation_256k1wrapped` (no underscore before wrapped)

**Applies to:**
- All `*_generation_wrapped` patterns (key generation wrapped)
- All `*_export_*_wrapped` patterns (key export wrapped)
- All `*_import_*_wrapped` patterns (key import wrapped)

**Fix applied:** Added underscores consistently across all test files and design note anchors using perl regex: `([a-z0-9])wrapped` → `$1_wrapped`

**Files affected:** All `psa_crypto_tests_tg*.c` and `rm_tf_psa_crypto_usage_notes.md` (24+ wrapped anchor patterns)

## 15. Board configuration in project XML files

**Pattern:** When adding support for a new board to v4, port the configuration from the corresponding board in v3's `rm_psa_crypto.xml` to v4's `rm_tf_psa_crypto.xml`.

**Key differences between v3 and v4 board configs:**

| Aspect | v3 (rm_psa_crypto.xml) | v4 (rm_tf_psa_crypto.xml) |
|--------|------------------------|--------------------------|
| **Include dirs** | `ra/arm/mbedtls/library` + `ra/arm/mbedtls/include` | `ra/arm/mbedtls-v4/tf-psa-crypto/platform`, `/include`, `/core`, `/dispatch`, `/extras` (full TF-PSA-Crypto path) |
| **Crypto alt files** | Listed individually in third_party_test_dirs (e.g., `sha256_alt.c`, `aes_alt.c`) | Not listed; TF-PSA-Crypto uses drivers differently |
| **Config macro** | `MBEDTLS_CONFIG_FILE=\"rm_psa_crypto_cfg.h\"` | `TF_PSA_CRYPTO_CONFIG_FILE=\"rm_tf_psa_crypto_cfg.h\"` |
| **Storage macros** | `MBEDTLS_PSA_ITS_FILE_C`, `MBEDTLS_FS_IO`, `MBEDTLS_PSA_CRYPTO_STORAGE_C` in common_macros | Not present (handled differently in v4) |
| **C11 macro** | Not present | `__STDC_WANT_LIB_EXT1__=0` in common_macros (required for IAR compatibility) |
| **Excluded files** | `psa_its_file.c` not typically excluded | Must exclude `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_its_file.c` |
| **Crypto procedures** | Per-board (sce7 for ra6m3_pk, sce9 for ra6m4_ek, rsip_e31a for ra4c1_ek) | Same; keep matching the board's crypto hardware |

**Board-specific crypto procedures in v4:**
- **ra4c1_ek**: Uses `rsip_e31a` (adapted from v3)
- **ra6m3_pk**: Uses `sce7` (adapted from v3)
- **ra6m4_ek**: Uses `sce9` (ported from v3, newly added to v4)

**Key support difference between v3 and v4 (TEMPORARY):**
- **v3**: Boards with hardware (ra6m3_pk, ra6m4_ek) use `WRAPPED_AND_PLAINTEXT_KEY_SUPPORT`
- **v4**: All boards (ra4c1_ek, ra6m3_pk, ra6m4_ek) use `PLAINTEXT_KEY_SUPPORT` for consistency
  
**Status:** This is temporary for software-only TF-PSA-Crypto testing. When hardware acceleration support is added to v4, the configuration will align with v3 (using `WRAPPED_AND_PLAINTEXT_KEY_SUPPORT` for boards with hardware capabilities). For now, all boards test with plaintext keys only during the TF-PSA-Crypto compatibility test phase.

**Work completed:** Added 6 new board configurations to `projects/rm_tf_psa_crypto.xml`:

**Mid-range & High-end boards:**
1. **ra6m4_ek**: sce9 crypto procedures, Heap: 0xF000, Stack: 0x1500
2. **ra8m1_ek**: rsip_e51a crypto procedures, Heap: 0xF000, Stack: 0x2500
3. **ra8m2_ek**: rsip_e50d crypto procedures, Heap: 0x4000, Stack: 0x2500
4. **ra4l1_ek**: rsip_e11a crypto procedures, Heap: 0x4400, Stack: 0x2000

**Low-power/Legacy boards:**
5. **ra2a2_ek**: aes2 (low-power), Heap: 0x3000, Stack: 0x2500
6. **ra2e1_ek**: ra2 (legacy, replaces ra2a1_tbb), Heap: 0x4000

All boards configured with:
- All tests enabled: SHA=1, SHA3=1, TRNG=1, AES=1, RSA=1, ECC=1, CHACHAPOLY1305=1
- PLAINTEXT_KEY_SUPPORT configuration (temporary for software testing phase)
- All v4-specific includes/excludes and third_party_test_dirs properly configured
- __STDC_WANT_LIB_EXT1__=0 macro for IAR compatibility

**Complete v4 board support (8 boards total):**
ra4c1_ek, ra6m3_pk, ra6m4_ek, ra8m1_ek, ra8m2_ek, ra4l1_ek, ra2a2_ek, ra2e1_ek

**Note:** ra2a1_tbb (legacy naming) has been removed and replaced by ra2e1_ek (current naming).

## 16. XML test templates for TF-PSA-Crypto (v4)

**Created:** New .xml_tests directory and templates for v4 in `ra/fsp/src/rm_tf_psa_crypto/.xml_tests/`

**Files created:**
1. **tf_psa_crypto_template.yml** - Main template configuration file that references the Jinja2 templates
   - Defines RTOSes: No RTOS, FreeRTOS, Azure RTOS ThreadX
   - Defines boards: RA2A2, RA2E1, RA4C1, RA4L1, RA6M3, RA6M4, RA8M2 (for availability testing)
   - Defines RA8M1 separately for littlefs testing
   - Toolchains: GCC for general, GCC/IAR/AC6/LLVM for littlefs

2. **tf_psa_crypto_availability.yml.j2** - Jinja2 template for module availability testing
   - Checks if TF-PSA-Crypto (module.driver.rm_tf_psa_crypto) can be added
   - Checks if mbedTLS v4 (module.arm.mbedtls_v4) can be added
   - Resolves constraints and builds projects for various boards
   - Handles Azure RTOS incompatibility

3. **tf_psa_crypto_littlefs_availability.yml.j2** - Jinja2 template for littlefs support testing
   - Tests TF-PSA-Crypto with littlefs integration (for RA8M1)
   - Fills littlefs dependencies and port requirements
   - Validates constraint resolution on hardware with persistent storage

**Module IDs used in v4 templates:**
- `module.driver.rm_tf_psa_crypto` - v4 PSA Crypto driver
- `module.arm.mbedtls_v4` - mbedTLS v4 library
- `module.arm.mbed.littlefs` - littlefs middleware
- `module.middleware.rm_littlefs` - Renesas littlefs wrapper
- `module.driver.rm_tf_psa_crypto.requires.middleware.stdio_wrapper` - stdio wrapper requirement

**Board configurations for XML tests:**
- Low-power: RA2A2 (aes2), RA2E1 (ra2)
- Standard: RA4C1, RA4L1, RA6M3, RA6M4, RA8M2
- Littlefs capable: RA8M1 (rsip_e51a with persistent storage support)

**Status:** Template files created following v3 pattern. These templates may require refinement after:
- Verification of exact v4 module IDs in module description files
- Testing constraint numbers on actual boards
- Validation of configuration property names in v4

**CORRECTION (verified against actual module description XML):** The first draft of these
templates guessed module/config IDs by pattern-matching v3 names with an `rm_tf_` or `_v4`
prefix. That guess was wrong in two places. Verified against
`ra/arm/.module_descriptions/Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` and
`Arm##mbed##Security##mbedTLS_v4####x.xx.xx.xml`:

- **Real driver module id is `module.driver.tf_psa_crypto`**, NOT
  `module.driver.rm_tf_psa_crypto`. The `rm_tf_psa_crypto` name only appears as a `requires`
  sub-id (`module.driver.rm_tf_psa_crypto.requires.middleware.stdio_wrapper`) — that one
  sub-id is correctly named and was NOT wrong. Only the top-level "add"/"check_if_module_can_be_added"
  id was wrong.
- **mbedTLS-v4 wrapper module id is `module.arm.mbedtls_v4`** (no version suffix, matching
  v3's `module.arm.mbedtls` pattern). The module description originally shipped with a stray
  `.0` suffix (`module.arm.mbedtls_v4.0`) that was inconsistent with v3's unsuffixed
  `module.arm.mbedtls` — this was corrected directly in
  `Arm##mbed##Security##mbedTLS_v4####x.xx.xx.xml` (and the two `.j2` templates that
  referenced it) to drop the suffix. Note: the separate `interface.driver.mbedtls_v4.0`
  (a `provides interface`, not the module id) was intentionally left alone since other
  module descriptions (`Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml`) still reference that
  exact interface id.
- **SUPERSEDED (2026-10-06): config properties now use `config.driver.tf_psa_crypto.*`
  (and `config.driver.tf_psa_crypto_alg_*` / `_key_type_*`), NOT the legacy
  `config.driver.psa_crypto.*`.** An earlier version of this note said to keep the legacy
  prefix; that was wrong for the v4 module description. Only 37 leftover definitions in
  `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` still used `psa_crypto` (the RNG,
  key-format, platform setup/teardown, ECP window size, ECDH, SPM, key-ID-owner ones) while
  ~870 references already used `tf_psa_crypto`, so definitions and references didn't match.
  All were renamed with `sed 's/config\.driver\.psa_crypto/config.driver.tf_psa_crypto/g'`
  (no collisions: no `tf_` definition existed for any of them). The v4 XML test templates
  `rm_tf_psa_crypto/.xml_tests/tf_psa_crypto_{availability,littlefs_availability}.yml.j2`
  were updated the same way (`mbedtls_threading_c`, `_threading_alt`,
  `_memory_buffer_alloc_c`, `_psa_its_file_c`, `_fs_io`, `_psa_crypto_storage_c`).
  Do NOT touch the v3 tree (`mbedCrypto` description, `mbedtls_availability.yml.j2`, BSP
  descriptions): `config.driver.psa_crypto.*` is correct there. When editing, check for the
  `_alg_`/`_key_type_` underscore forms too, not just `psa_crypto.`.
  Sanity check after any id rename: every `${config.driver.*}` referenced in constraints must
  have a matching `<property ... id=...>` definition (diff the two sorted id lists).
- **`config.driver.rm_tf_psa_crypto.stdc_want_lib_ext1` does not exist at all** — this was
  fabricated in the first draft. Grepping the v4 module description for "stdc" or "annex"
  returns nothing. `__STDC_WANT_LIB_EXT1__` is only a build macro set directly in the project
  XML's `common_macros` (see Section 15) — it is not a GUI-configurable module property, so it
  has no constraint/config-property representation and should never appear in an XML test
  sequence.
- **The v3 constraint-message strings are still valid in v4** — "Disable Platform Memory",
  "MBEDTLS_THREADING_C must be undefined", "MBEDTLS_THREADING_ALT must be undefined" all exist
  verbatim in the v4 module description. The v3 constraint-resolution sequence (check message
  found=yes → change_property → check message found=no, repeated for each) should be reused
  as-is in v4 templates, keyed on the `config.driver.psa_crypto.*` ids above.
- **v4 has substantially more constraints than v3**: 17 total `<constraint display=...>` entries
  in the TF-PSA-Crypto module description vs. v3's ~7, including new per-algorithm minimum-heap
  constraints (ECC/RSA/AES), a PQC-module-required constraint, and persistent-storage
  all-or-nothing constraints. The exact `check_constraints_number` that fires for a given board/
  RTOS/config combination cannot be determined by reading the XML alone — it depends on runtime
  default property values (heap size, which algorithms are enabled, etc.) and must be verified by
  actually generating a project, not assumed from a v3 count. Current template values (7) are
  placeholders pending that on-target verification.

**Lesson:** When porting XML test sequences or referencing module description ids for a new
module tree, grep the actual `.module_descriptions/*.xml` file for the id/property before
writing it into a template — do not pattern-match from the sibling v3 name. The naming is
inconsistent by design (module ids sometimes gain a version suffix or drop the `rm_` prefix
while nested `requires` ids keep it, and individual config properties can keep a completely
different legacy prefix than the module id that owns them).

**Further corrections applied to the module description files themselves (not just the
templates):**
- `module.arm.mbedtls_v4.0` → `module.arm.mbedtls_v4` (dropped the stray `.0` version suffix
  in `Arm##mbed##Security##mbedTLS_v4####x.xx.xx.xml`'s own `<module id=...>` declaration, to
  match v3's unsuffixed `module.arm.mbedtls`). Updated in 3 places: the module description
  itself, and both `.j2` templates that referenced it (`tf_psa_crypto_availability.yml.j2`,
  `tf_psa_crypto_littlefs_availability.yml.j2`). Left `interface.driver.mbedtls_v4.0`
  (a separate `provides interface` id, not the module id) untouched since
  `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` still depends on that exact interface name.
- `arm/mbedtls(v4)/...` → `arm/mbedtls-v4/...` in config `path=` attributes — the parenthesized
  form didn't match the real on-disk directory (`ra/arm/mbedtls-v4`), which would have pointed
  generated config headers (`tls-config.h`, `tf-psa-crypto-config.h`) at a non-existent path.
  Fixed in both `Arm##mbed##Security##mbedTLS_v4####x.xx.xx.xml` (config path + display string
  `"Security|MbedTLS(v4)"` → `"Security|MbedTLS-v4"`) and
  `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` (config path).

**Lesson (naming convention):** Anywhere "v4" appears in a v4-tree identifier/path/display
string, the convention is a hyphen (`mbedtls-v4`, `MbedTLS-v4`), matching the real directory
name `ra/arm/mbedtls-v4`. Parenthesized forms like `mbedtls(v4)` and version-suffixed forms
like `mbedtls_v4.0` are inconsistencies introduced when the v4 module descriptions were first
authored, not an intentional convention — flag and fix them the same way if seen elsewhere.

## 17. Adding a board to rm_tf_psa_crypto.xml breaks the dependency-tree self-test

**Symptom:** After adding a new board (e.g. `ra2a2_ek`) to `projects/rm_tf_psa_crypto.xml`,
`python scripts/dependency_tree/build_tree.py --self-test` fails with:
```
ERROR:root:TEST FAILED: filepath=ra/fsp/src/bsp/mcu/<mcu>/bsp_elc.h
Expected module list: [...]           # missing 'rm_tf_psa_crypto'
Provided module list: [..., 'rm_tf_psa_crypto', ...]
```

**Root cause:** `scripts/dependency_tree/build_tree.py` computes, for any given file, the set
of modules that depend on it (used to decide what to test in a diff-based pipeline). Adding a
board to a module's project XML makes that module newly relevant to that board's MCU, so the
live-computed dependency list for that MCU's `bsp_elc.h`/`bsp_linker.c` picks up the module —
but the checked-in golden fixture `scripts/dependency_tree/test_cases.yml` is a static snapshot
that must be updated by hand to match.

**Fix:** Add the new module name (alphabetically) to every `test_cases.yml` entry for that
MCU's `bsp_elc.h` and `bsp_linker.c` (search `grep -n "bsp/mcu/<mcu>/bsp_elc.h\|bsp/mcu/<mcu>/bsp_linker.c" scripts/dependency_tree/test_cases.yml`).
Only MCUs that have dedicated per-MCU entries in the fixture need this — the big
`"ra/aws/FreeRTOS"` entry (line ~12) already lists every module for every MCU and does not need
touching per-board.

**Verification:** `python scripts/dependency_tree/build_tree.py --self-test` — a clean run
falls through silently to the unrelated "modules that should be tested" diff-analysis output
with no `TEST FAILED`/`Self-test Failed` lines; those two strings are the only failure signal.

**Checklist for future board additions to rm_tf_psa_crypto.xml (or rm_psa_crypto.xml):**
1. Add the board to the project XML (see Section 15).
2. Add the board to `projects/pipeline_builds.yml`'s `rm_tf_psa_crypto` module boards list
   (see the pipeline_builds.yml work earlier this session).
3. Check `scripts/dependency_tree/test_cases.yml` for a per-MCU `bsp_elc.h`/`bsp_linker.c`
   entry for that board's MCU and add the module name if missing.
4. Run the self-test to confirm.

**Example v3→v4 port (ra6m4_ek):**
1. Copy project entry from v3's rm_psa_crypto.xml (lines 594-714)
2. Replace all `ra/arm/mbedtls/` includes with `ra/arm/mbedtls-v4/tf-psa-crypto/...` paths
3. Replace `rm_psa_crypto` with `rm_tf_psa_crypto` in paths/includes
4. Update config macro: `MBEDTLS_CONFIG_FILE` → `TF_PSA_CRYPTO_CONFIG_FILE`
5. Remove MBEDTLS_PSA_* macros from common_macros
6. Add `__STDC_WANT_LIB_EXT1__=0` to common_macros
7. Update third_party_test_dirs to reference tf-psa-crypto paths
8. Keep sce9 crypto procedures paths unchanged
9. Exclude `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_its_file.c`

**Files affected:** `projects/rm_psa_crypto.xml` (v3), `projects/rm_tf_psa_crypto.xml` (v4)

## 18. Missing hw_sce_hash_private.h include in v4 test file

**Symptom:** Compilation error in `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg1.c`:
```
error: 'HW_SCE_LARGE_DATA_VALUE_0' undeclared (first use in this function) [psa_crypto_tests_tg1.c:595]
error: 'HW_SCE_LARGE_DATA_VALUE_1' undeclared (first use in this function) [psa_crypto_tests_tg1.c:596]
```

**Root cause:** When porting the v4 test file, the include for `hw_sce_hash_private.h` was not
carried over. This header (located at `ra/fsp/src/r_sce/hw_sce_hash_private.h`) defines the
hardware SCE constants:
```c
#define HW_SCE_LARGE_DATA_VALUE_0    (0x80000000U)
#define HW_SCE_LARGE_DATA_VALUE_1    (0x00000000U)
```

These constants are used in SHA test vectors that pass large message lengths to the hardware.
The same include exists in the v3 version (`ra/fsp/src/rm_psa_crypto/!test/psa_crypto_tests_tg1.c`).

**Fix:** Add `#include "hw_sce_hash_private.h"` to `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg1.c`
after the other test setup includes (around line 31, between `#include "psa_crypto_tests_setup.h"`
and `#include "../../scripts/util/performance.h"`).

**Files affected:** `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_tg1.c`

## 19. Vendor module description bug: unbalanced parens make "Software ECC" heap constraint permanently unsatisfiable

**Symptom:** In e2studio project-creation logs (`ease.log`) for `rm_tf_psa_crypto` availability
tests, the constraint `TF-PSA-Crypto: A minimum heap of 0x1800 is required to use Software ECC.`
never clears, even after setting `bsp.common.heap` to a value well above 0x1800 (e.g. 0x2000 /
8192). This happens on every board/toolchain/RTOS=No-RTOS combination consistently. The adjacent
`A minimum heap of 0x1500 is required to use RSA.` constraint (same heap property, same pattern)
DOES clear correctly at the same heap value, proving the heap property itself is being read/set
correctly and ruling out a project-XML or test-template heap misconfiguration.

**Root cause:** `ra/arm/.module_descriptions/Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml`,
the constraint for "Software ECC" (originally around line 3220) has one fewer closing paren than
opening paren (5 opens, 4 closes) — confirmed by literally counting `(`/`)` in the expression
string. The immediately-following RSA constraint uses the identical pattern but is correctly
balanced (5/5). A malformed/unparseable constraint expression apparently fails "closed" (always
shows as an unmet problem) rather than raising a parse error, which is why it silently never
resolves regardless of the actual heap value.

**Fix:** Add the missing `)` right after the `psa_crypto_alg_ecdsa` comparison, mirroring the
RSA constraint's structure:
```
Before: (("${config.bsp.common.heap}" >= 0x1800)  || ("${...ecdsa}" != "...disabled") || (testExists("${interface.rtos.rtos}") )
After:  (("${config.bsp.common.heap}" >= 0x1800)  || ("${...ecdsa}" != "...disabled")) || (testExists("${interface.rtos.rtos}") )
```
Only the paren placement was changed — the `!=`/`==` operator asymmetry vs. RSA's constraint was
left alone since there's no on-target evidence that's also wrong (unlike the paren count, which
is objectively verifiable by counting characters).

**Downstream fix:** Because this bug made the constraint appear as a permanent extra problem,
the `.xml_tests/tf_psa_crypto_availability.yml.j2` and `tf_psa_crypto_littlefs_availability.yml.j2`
templates had a placeholder `check_constraints_number: 7` that never matched — actual on-target
count (No RTOS, before any property changes) is **6**: min heap 0x1800 (ECC), THREADING_ALT
undefined, THREADING_C undefined, min stack 4K, Disable Platform Memory, min heap 0x1500 (RSA).
Updated both templates' initial `check_constraints_number` to `6`. With the paren fix, the
final `check_constraints_number: 0` after resolving THREADING_C/THREADING_ALT/Platform-Memory
should now also pass without an extra resolution step, since the ECC constraint will correctly
read the already-configured heap (0x2000/8192) as satisfying `>= 0x1800`.

**Not yet diagnosed:** the same `ease.log` also showed each `availability` project failing its
*build* step with 17 compile errors (`Build finished - 0`, `Errors: 17`) even where all constraint
checks eventually passed. `ease.log` only logs warnings verbatim, not individual compiler error
text, so the actual errors are unknown — need the full e2studio/gcc build console output (not
just `ease.log`) to diagnose these. Do not assume they're related to the constraint bug above;
verify independently once the build log is available.

**Files affected:**
`ra/arm/.module_descriptions/Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml`,
`ra/fsp/src/rm_tf_psa_crypto/.xml_tests/tf_psa_crypto_availability.yml.j2`,
`ra/fsp/src/rm_tf_psa_crypto/.xml_tests/tf_psa_crypto_littlefs_availability.yml.j2`

## 20. SUPERSEDED: `ra2e1_ek` LLVM build overflows both FLASH and RAM — shared `rm_tf_psa_crypto_cfg.h` has zero per-board algorithm gating

**Status: the board-capability-gating approach below (all of it — the `RM_TF_PSA_CRYPTO_CFG_*`
macros and every `#if`-guarded `PSA_WANT_*`/`MBEDTLS_PK_*` change) turned out to rest on a false
premise and has been abandoned. Read this note before touching `rm_tf_psa_crypto_cfg.h`'s
algorithm-enable section again.**

**What actually happened:** `projects/rm_psa_crypto.xml` (v3) proves an AES-Engine-only board
(`ra2a1_tbb`, the direct predecessor of `ra2e1_ek` — same tier, same `ra/fsp/src/r_sce/ra2/`
crypto procedure) successfully builds with the **entire** kitchen-sink algorithm set — RSA, ECDSA,
ECDH, ECP, CMAC, GCM, CCM, ChaChaPoly all unconditionally `#define`d in `rm_psa_crypto_cfg.h`, with
`rsa_alt.c`/`ecdsa_alt.c`/`ecdh_alt.c`/`cmac_alt.c`/`gcm_alt.c`/`ccm_alt.c` all compiled in — with
**no board-based gating at all**. This directly contradicts this section's original framing: the
Features table in `!dsn/rm_tf_psa_crypto_usage_notes.md` describes **hardware acceleration
availability** ("AES Engine: `--` for CMAC" etc.), not **algorithm availability** — every algorithm
has a working software fallback on every board, hardware or not. Gating `PSA_WANT_ALG_*` by
`BSP_FEATURE_RSIP_*` hardware presence was therefore solving the wrong problem, and it broke a real
test: `psa_crypto_tests_tg2.c:3552` calls `mbedtls_aes_cmac_prf_128` directly (software CMAC-PRF,
part of the `TEST_PSA_CRYPTO_AES=1` group which has no separate CMAC/GCM/CCM test-level flag,
unlike RSA/ECC/ChaChaPoly/SHA3 which each do), and disabling `PSA_WANT_ALG_CMAC` compiled out
`MBEDTLS_CMAC_C` entirely, producing `undefined reference to 'mbedtls_aes_cmac_prf_128'`.

If v3 fits the full set on the same board tier, the real driver of `ra2e1_ek`'s FLASH/RAM overflow
in v4 must be something else — larger per-algorithm code size in TF-PSA-Crypto vs. legacy mbedtls,
worse dead-code elimination in v4's driver-dispatch structure (a single big switch-statement
dispatcher can pin in every case's callee even if never invoked, unlike v3's per-file `_alt.c`
linkage), or overhead unrelated to the algorithm set (e.g. persistent storage/littlefs). None of
that was measured — the gating work here was pattern-matching, not profiling.

**Resolution taken:** rather than keep patching `rm_tf_psa_crypto_cfg.h` reactively (which surfaced
a new "unconditional macro bypasses the gate" error on nearly every fix — CMAC redefinition →
`MBEDTLS_ECP_LIGHT` via `MBEDTLS_PK_PARSE_EC_*` → `MBEDTLS_PK_C` → the CMAC-PRF test link error —
suggesting there were more landmines than found), `projects/rm_tf_psa_crypto.xml`'s board entry was
changed from `<board>ra2e1_ek</board>` back to `<board>ra2a1_tbb</board>` — i.e. test the same board
v3 already validates for this tier, instead of the newly-added, never-verified `ra2e1_ek`. The
`RM_TF_PSA_CRYPTO_CFG_*` capability macros and all the `#if`-guarded blocks are left in place in
`rm_tf_psa_crypto_cfg.h` (harmless — every board added to this project so far has at least one
`BSP_FEATURE_RSIP_*` set, so the gates all evaluate true) but should not be treated as a validated
size fix, and should not be extended to a new board without first getting a real size/map-file
measurement of what's actually driving that board's footprint.

**If `ra2e1_ek` (or any other AES-Engine-only board) needs to be re-added later:** get an actual
build size breakdown (map file / `nm --size-sort` / linker `-Map` output) BEFORE writing any config
gating, to find the real cause — do not re-derive "disable what the HW table says is unaccelerated"
as a size strategy; it's now disproven by the v3/RA2A1 comparison above.

---

**Original (now-superseded) investigation, kept for the mechanical PSA_WANT_* gotchas it surfaced
— those remain valid even though the overall gating strategy was wrong:**

Symptom (llvm, `-Oz`, Cortex-M23):

```
ld.lld: error: section '__ram_noinit$$' will not fit in region 'RAM': overflowed by 4268 bytes
ld.lld: error: section '__ram_zero$$' will not fit in region 'RAM': overflowed by 18368 bytes
ld.lld: error: section '__ram_tdata$$'/'__ram_tbss$$'/'__ram_thread_stack$$'/'.ram.endof' overflow ~18.4KB
ld.lld: error: section '__flash_readonly$$' will not fit in region 'FLASH': overflowed by 27113 bytes
(+ 5 more FLASH sections, ~27.1KB overflow each)
```

**Root cause:** `test_files/ra_cfg/fsp_cfg/rm_tf_psa_crypto_cfg.h` is **one shared config file for
every board** (`grep -c PSA_WANT_ALG test_files/ra_cfg/fsp_cfg/rm_tf_psa_crypto_cfg.h` — all `1`,
no `#ifdef`/board guard anywhere in the file). It unconditionally enables the full algorithm set:
RSA (OAEP/PKCS1v15/PSS), ECDSA/ECDH/FFDH, JPAKE, ChaCha20-Poly1305, all SHA/SHA3 variants, HKDF,
PBKDF2, TLS1.2 KDFs, etc.

The `TEST_PSA_CRYPTO_RSA=0` / `TEST_PSA_CRYPTO_ECC=0` / `TEST_PSA_CRYPTO_CHACHAPOLY1305=0` macros
already set per-board in `projects/rm_tf_psa_crypto.xml` (confirmed for `ra2e1_ek` from the actual
build command: `-DRA2E1_EK_BUILD=1 ... -DTEST_PSA_CRYPTO_RSA=0 -DTEST_PSA_CRYPTO_ECC=0
-DTEST_PSA_CRYPTO_CHACHAPOLY1305=0 -DTEST_PSA_CRYPTO_SHA3=0`) only gate which **unit tests run** —
they never touch `PSA_WANT_*`, so the full software RSA/ECC/ChaChaPoly/FFDH/JPAKE implementations
still compile and link in regardless of whether that board's tests exercise them.

`ra2e1_ek` is Cortex-M23 with no hardware crypto acceleration for this driver (100% software
TF-PSA-Crypto, built at `-Oz` — the most size-conscious flags of any board in the project), so it
carries the entire kitchen-sink crypto library sized for boards with far more flash/RAM (e.g.
`ra8m1_ek`/`ra6m4_ek`). `ra2a2_ek` (also a small/low-power board, same "all tests enabled" pattern
per §15) is suspected to have the identical problem — not yet confirmed by an actual build.

**Ties back to §15/§16:** `ra2e1_ek` (and 5 other boards) were added to `rm_tf_psa_crypto.xml` by
pattern-copying an existing board's config, with the notes there explicitly flagging "template
values pending on-target verification." This build failure is that gap surfacing for real.

**Why this isn't a quick fix:** heap/stack macros (`BSP_CFG_HEAP_BYTES`/`BSP_CFG_STACK_MAIN_BYTES`)
cannot help — the FLASH overflow is static code size from linked-in algorithm implementations, not
a runtime allocation. Fixing this requires either:
1. A per-board `TF_PSA_CRYPTO_CONFIG_FILE` (e.g. a new slimmed `rm_tf_psa_crypto_cfg_ra2e1.h`) that
   actually disables `PSA_WANT_ALG_RSA_*`/`ECDSA`/`ECDH`/`FFDH`/`JPAKE`/`CHACHA20_POLY1305`/`SHA3_*`
   for this board, mirroring which `TEST_PSA_CRYPTO_*` flags are already `0`; or
2. Wrapping those same algorithms in the shared config with `#if !defined(RA2E1_EK_BUILD)` (the
   build macro is already defined per-board in the project XML, so no XML change needed — just the
   header).

**Fix implemented (option 3, chosen over both above):** gate the shared
`rm_tf_psa_crypto_cfg.h` per-algorithm using `BSP_FEATURE_RSIP_*` hardware-capability macros
instead of a per-board config file or a per-board `_EK_BUILD` macro — this auto-scales to every
board's actual crypto engine (per the Features table in `!dsn/rm_tf_psa_crypto_usage_notes.md`)
with one shared file, no XML changes, and no new file to keep in sync. Added capability macros
`RM_TF_PSA_CRYPTO_CFG_AES_ADVANCED_SUPPORTED` (GCM/CCM/CMAC/PBKDF2-CMAC-PRF — every engine except
plain "AES Engine"/"AES Engine 2"-only boards), `_ECC_256_SUPPORTED`, `_ECC_384_SUPPORTED`,
`_ECC_521_SUPPORTED`, `_RSA_SUPPORTED`, `_CHACHAPOLY_SUPPORTED` (E50D only), `_SHA3_SUPPORTED`
(E50D only), each an OR of the relevant `BSP_FEATURE_RSIP_*` flags, and wrapped the corresponding
`PSA_WANT_ALG_*`/`PSA_WANT_ECC_*` defines in `#if (CAPABILITY_MACRO) ... #endif`.

**Gotcha hit while implementing — PSA_WANT_* must never be `#defined to 0`, only `1` or fully
undefined.** First attempt wrote `#define PSA_WANT_ALG_CMAC (RM_TF_PSA_CRYPTO_CFG_AES_ADVANCED_SUPPORTED)`
directly (macro expands to 0 or 1). This broke the LLVM/IAR build with:
```
Error[Pa181]: incompatible redefinition of macro "PSA_WANT_ALG_CMAC"
  (defined at line 142 of "rm_tf_psa_crypto_cfg.h")
```
Root cause: `ra/arm/mbedtls-v4/tf-psa-crypto/include/tf-psa-crypto/private/crypto_adjust_config_dependencies.h:39-43`
does
```c
#if (defined(PSA_WANT_ALG_PBKDF2_AES_CMAC_PRF_128) && !defined(MBEDTLS_PSA_ACCEL_ALG_PBKDF2_AES_CMAC_PRF_128))
#define PSA_WANT_ALG_CMAC 1
#endif
```
— an **existence check** (`defined(...)`), not a value check. A macro `#define`d to the literal
expression `(RM_TF_PSA_CRYPTO_CFG_AES_ADVANCED_SUPPORTED)` is still "defined" even when that
expression evaluates to `0`, so this dependency header always forces
`#define PSA_WANT_ALG_CMAC 1` whenever `PSA_WANT_ALG_PBKDF2_AES_CMAC_PRF_128` exists at all —
and that literal `1` then textually conflicts with our own non-literal-`1` definition of the same
macro, which IAR (unlike GCC/LLVM's looser redefinition check) rejects outright. This is a general
hazard, not CMAC-specific: **any** `PSA_WANT_*` macro that is "defined but 0" can trigger this
class of conflict anywhere `crypto_adjust_config_dependencies.h`'s many `defined(PSA_WANT_ALG_x)`
checks fire, and it also silently defeats the intended gating (upstream code checking
`#ifdef PSA_WANT_ALG_x` sees it as enabled regardless of the 0/1 value).

**Correct pattern:** `#if (CAPABILITY_MACRO)` / `#define PSA_WANT_ALG_x 1` / `#endif` — never
`#define PSA_WANT_ALG_x (expr)` and never `#define PSA_WANT_ALG_x 0`. Applied this pattern to
every algorithm in the block, and also converted the file's **pre-existing** `#define
PSA_WANT_ALG_x 0` lines (`DETERMINISTIC_ECDSA`, `FFDH`, `JPAKE`, `HKDF`/`_EXTRACT`/`_EXPAND`,
`MD5`, `OFB`, `PBKDF2_HMAC`, `RIPEMD160`, `RSA_PSS`, `SHA_1`, `TLS12_PRF`/`_PSK_TO_MS`/
`_ECJPAKE_TO_PMS`, `PSA_WANT_ECC_MONTGOMERY_255`/`_448`, `PSA_WANT_ECC_BRAINPOOL_P_R1_512`) to
simply not `#define` them at all — they carried the identical latent hazard even before this
session's change, just hadn't been observed to trigger it yet. **If a future PSA_WANT_* macro
needs to be "off," leave it undefined (or comment it out); do not `#define` it to `0`.**

**Second cascading gotcha — `PSA_WANT_KEY_TYPE_ECC_*`/`RSA_*` must track the algorithm gating,
not just `PSA_WANT_ALG_*`/`PSA_WANT_ECC_*`.** After the fix above, a board with no ECC hardware
(all curves correctly disabled) still failed with:
```
ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include/mbedtls/private/ecp.h:330:2:
error: "Missing definition of MBEDTLS_ECP_MAX_BITS"
```
Cause: `PSA_WANT_KEY_TYPE_ECC_PUBLIC_KEY` and `PSA_WANT_KEY_TYPE_ECC_KEY_PAIR_{BASIC,IMPORT,EXPORT,
GENERATE,DERIVE}` (further down the same file, ~line 236-252) were still hardcoded `1`
unconditionally for every board — they were outside the originally-requested 103-156 line range
so the first pass didn't touch them. With the key type still "wanted" but zero
`PSA_WANT_ECC_SECP_*`/`BRAINPOOL_*` curves enabled, TF-PSA-Crypto still builds the ECP/ECDSA
module, and `MBEDTLS_ECP_MAX_BITS` (derived from whichever curves are enabled) never gets a
value to derive from → the `#error`. Fixed by wrapping those same key-type lines in
`#if (RM_TF_PSA_CRYPTO_CFG_ECC_256_SUPPORTED) ... #endif`, and did the same for
`PSA_WANT_KEY_TYPE_RSA_PUBLIC_KEY`/`RSA_KEY_PAIR_{BASIC,IMPORT,EXPORT,GENERATE}` under
`RM_TF_PSA_CRYPTO_CFG_RSA_SUPPORTED` for consistency (RSA has the equivalent
key-size-derivation risk even though it hadn't been observed to error yet).

**General lesson:** when gating a `PSA_WANT_ALG_*`, grep the whole config file for every
`PSA_WANT_KEY_TYPE_*` that algorithm's key family depends on — TF-PSA-Crypto's dependency
headers connect algorithm-enablement to key-type-enablement in both directions, and leaving one
side hardcoded while gating the other produces this exact "wanted but unsizable" class of error.
`PSA_WANT_KEY_TYPE_CHACHA20` was deliberately left ungated (still `1` unconditionally) — it's
required by `PSA_WANT_ALG_STREAM_CIPHER` (also always-on, implemented via ChaCha20 in this
library), not just by `PSA_WANT_ALG_CHACHA20_POLY1305`, so gating it to
`RM_TF_PSA_CRYPTO_CFG_CHACHAPOLY_SUPPORTED` would have broken stream-cipher support on every
board without ChaCha20-Poly1305 hardware (i.e. every board except E50D).

**Known, not-yet-hit follow-up risk (same hazard class, not fixed):** `PSA_WANT_DH_RFC7919_{2048,
3072,4096,6144,8192}` are still `#define`d to `0` (violates the "never 0" rule above — pre-existing,
outside this session's edits) while `PSA_WANT_KEY_TYPE_DH_PUBLIC_KEY`/`DH_KEY_PAIR_{BASIC,IMPORT,
EXPORT,GENERATE}` are still hardcoded `1` unconditionally, same shape as the ECC bug just fixed. It
has not been observed to error (DH module may not have as strict a "#error missing size macro"
guard as ECP does, or it simply hasn't been exercised on a board build yet) — if a future build
fails on a DH/FFDH-related "missing definition," apply the identical fix pattern here.

**Third cascading gotcha — a config macro can force `MBEDTLS_ECP_LIGHT` on independently of every
`PSA_WANT_*` gate, bypassing both fixes above.** After the second fix, an actual `ra2e1_ek` rebuild
still hit the identical `#error "Missing definition of MBEDTLS_ECP_MAX_BITS"`. Traced via
`crypto_adjust_config_tweak_builtins.h:181-188`:
```c
#if defined(MBEDTLS_ECP_C) || \
    defined(MBEDTLS_PK_PARSE_EC_EXTENDED) || \
    defined(MBEDTLS_PK_PARSE_EC_COMPRESSED) || \
    defined(MBEDTLS_PSA_BUILTIN_KEY_TYPE_ECC_KEY_PAIR_DERIVE)
#define MBEDTLS_ECP_LIGHT
#endif
```
`rm_tf_psa_crypto_cfg.h` had `#define MBEDTLS_PK_PARSE_EC_EXTENDED` and `#define
MBEDTLS_PK_PARSE_EC_COMPRESSED` **unconditional for every board** (pre-existing, well outside the
103-156 range either prior fix touched) — either one alone forces `MBEDTLS_ECP_LIGHT` on regardless
of `PSA_WANT_KEY_TYPE_ECC_*`/`PSA_WANT_ECC_*`, so `ra2e1_ek` still got `ECP_LIGHT` with zero curves
to size `MBEDTLS_ECP_MAX_BITS` from. Fixed by wrapping both in
`#if (RM_TF_PSA_CRYPTO_CFG_ECC_256_SUPPORTED) ... #endif`, same capability macro as the rest of the
ECC gating. The file's own doc comment on `MBEDTLS_PSA_P256M_DRIVER_ENABLED` (~line 1990) already
warned "avoid defining `MBEDTLS_PK_PARSE_EC_COMPRESSED` or `MBEDTLS_PK_PARSE_EC_EXTENDED`... these
require a subset of the built-in ECC implementation" — this was a known-shaped hazard, just not
connected to the board-gating work until it broke a build.
- Checked for an equivalent unconditional RSA-forcing macro (grepped for unconditional
  `MBEDTLS_RSA_C`/`MBEDTLS_GENPRIME`/`MBEDTLS_PKCS1_*` `#define`s in this file) — found none, so
  RSA-disabled boards should not hit the equivalent error. `MBEDTLS_ECP_NIST_OPTIM` (~line 1814) is
  still unconditional but is inert (only consumed inside `#if defined(MBEDTLS_ECP_C)`-guarded code
  elsewhere) — not a forcing macro, left as-is.

**General lesson (supersedes the narrower one from the second gotcha):** when gating a PSA feature
in this file, grep the **entire file** (not just the algorithm/key-type sections) for any
unconditional `#define` of a macro that a dependency header treats as an alternate/OR-path trigger
for the same feature (`grep -n "define MBEDTLS_ECP_LIGHT\|define MBEDTLS_ECP_C" ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include/mbedtls/private/*.h`
to find all such trigger points for a given feature before declaring it gated).

**Files affected:** `test_files/ra_cfg/fsp_cfg/rm_tf_psa_crypto_cfg.h` (fixed — lines ~103-260 plus
~1008/1017 for the `MBEDTLS_PK_PARSE_EC_*` macros). **Not yet done:** re-run the `ra2e1_ek` (and
`ra2a2_ek`) LLVM build after this third fix to confirm both the original FLASH/RAM overflow and
this `#error` are actually cleared — every fix so far has been source-analysis-driven, not yet
confirmed by a clean build.

## 21. `ra2a1_tbb` RAM overflow (2532 bytes) is a fixed-size `psa_key_slot_t[MBEDTLS_PSA_KEY_SLOT_COUNT]` cost in v4, not an algorithm-selection problem

**Context:** after §20 concluded the whole hardware-capability PSA_WANT gating strategy was a false
premise (v3's `ra2a1_tbb` fits every algorithm; disprove-by-comparison), the board in
`rm_tf_psa_crypto.xml` was swapped from `ra2e1_ek` to `ra2a1_tbb` to match v3. That build then
failed with a much smaller overflow: `region 'RAM' overflowed by 2532 bytes` — worth its own
investigation since it's a different order of magnitude from the original ~18KB.

**Comparison method:** diffed every RAM-relevant setting between `rm_tf_psa_crypto_cfg.h` (v4) and
`rm_psa_crypto_cfg.h` (v3) for this exact board — `BSP_CFG_HEAP_BYTES` (`0x4000` both),
`BSP_CFG_STACK_MAIN_BYTES` (default `0x1000` both, from `bsp_cfg_ra2a1.h`),
`MBEDTLS_PSA_KEY_STORE_DYNAMIC` (off, both), `MBEDTLS_PSA_STATIC_KEY_SLOTS` (off, both),
`MBEDTLS_PSA_KEY_SLOT_COUNT` (not overridden in either file → both fall back to the same library
default of `32`, confirmed in each tree's own `crypto_extra.h`), MPI/ECP window sizes, CTR_DRBG
params — **all identical**. The only difference at all was that v4 (at the time) had RSA/ECC/
ChaChaPoly/SHA3/PK/CMAC/GCM/CCM gated off (bare SHA+AES+TRNG) while v3 has everything on
unconditionally — and v4 *still* overflowed despite enabling strictly less. That rules out
algorithm selection as the cause; this is a structural v4-vs-v3 library difference.

**Root cause:** `ra/arm/mbedtls-v4/tf-psa-crypto/core/psa_crypto_slot_management.c:186`:
```c
psa_key_slot_t key_slots[MBEDTLS_PSA_KEY_SLOT_COUNT];
```
A static (`.bss`) array — always allocated since `MBEDTLS_PSA_KEY_STORE_DYNAMIC` is off in both
configs. `MBEDTLS_PSA_KEY_SLOT_COUNT` defaults to **32** in both v3 and v4 (identical count), but
`psa_key_slot_t` (`core/psa_crypto_core.h:29-133`) is v4/TF-PSA-Crypto's own struct — not the same
representation v3 used. Computed field-by-field from `psa/crypto_struct.h` + `psa/crypto_types.h`:

| Field | Type | Bytes |
|---|---|---|
| `attr.type` | `uint16_t` | 2 |
| `attr.bits` | `uint16_t` | 2 |
| `attr.lifetime` | `uint32_t` | 4 |
| `attr.policy` (usage+alg+alg2) | 3×`uint32_t` | 12 |
| `attr.id` (`mbedtls_svc_key_id_t` = `psa_key_id_t`) | `uint32_t` | 4 |
| `state` | enum (int) | 4 |
| `var` union (`free`/`occupied`, max member) | `int32_t`/`size_t` | 4 |
| `key.data` (ptr, since `MBEDTLS_PSA_STATIC_KEY_SLOTS` off) + `key.bytes` | ptr + `size_t` | 8 |
| **Total per slot** | | **≈40 bytes** |

`32 × ~40 bytes ≈ 1280 bytes` of guaranteed static RAM from this array alone — roughly half the
2532-byte overflow, with the remainder presumably other v4-specific fixed-size internals not
traced further (not worth the effort once the actionable lever below closed the gap in practice).

**Verified safe to shrink:** grepped `psa_crypto_tests_tg1.c`/`tg2.c` (the SHA/AES tests that
actually run for this board) for any array of concurrently-held key handles — found none; tests
create and destroy one key at a time. 32 concurrent slots is far more than this board's suite ever
needs.

**Fix applied:** added an explicit override in `rm_tf_psa_crypto_cfg.h` (~line 1587, previously
commented out at the library default):
```c
#define MBEDTLS_PSA_KEY_SLOT_COUNT 8
```
This is a **new** override that v3 never needed — v3's older per-slot representation was
apparently small enough that 32 slots fit; v4's is not, on this board.

**General lesson:** when a v4 board build overflows RAM/FLASH despite v4 having *fewer* algorithms
enabled than the v3 equivalent for the same board, do not keep reaching for algorithm-gating fixes
(see §20) — diff the two config files for identical-looking-but-actually-different-by-library
settings instead (same macro name, same literal default, different underlying struct size). The
"is this macro's *value* the same" check is necessary but not sufficient; the struct/array it sizes
can differ between the two library trees even when the config file is byte-identical on that
setting.

**Files affected:** `test_files/ra_cfg/fsp_cfg/rm_tf_psa_crypto_cfg.h` (`MBEDTLS_PSA_KEY_SLOT_COUNT`
override added). **Not yet done:** rebuild `ra2a1_tbb` to confirm the full 2532-byte overflow is
cleared (the ~1280 bytes accounted for here may not be the whole gap) — if it's not fully cleared,
get an actual map-file/`nm --size-sort` breakdown rather than guessing at more fixed-size structs.

**Update after rebuild:** `MBEDTLS_PSA_KEY_SLOT_COUNT` 32→8 alone recovered exactly **960 bytes**
(overflow went from 2532 to 1572 bytes) — `(32-8) slots × 40 bytes/slot = 960`, confirming the
per-slot size estimate above was accurate to the byte. Continued hunting for the remaining 1572
bytes; see §22 for the second contributor found (a v4-only test-harness array, not a library
struct) and the fix applied for it.

## 22. Second RAM contributor for `ra2a1_tbb`: v4's test harness added a whole second leak-tracking array (`calloc_size_array`) that v3 never had

**Found while continuing to close the 1572-byte remainder from §21.** Compared
`ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_setup.c` against its v3 counterpart
`ra/fsp/src/rm_psa_crypto/!test/psa_crypto_tests_setup.c`:
```c
/* v4 (both present): */
uint32_t                 calloc_array[RM_PSA_CRYPTO_TESTS_MAX_CALLOC]      = {0};   /* 200*4 = 800 B */
static size_t            calloc_size_array[RM_PSA_CRYPTO_TESTS_MAX_CALLOC] = {0};   /* 200*4 = 800 B, v4-ONLY */

/* v3: only calloc_array exists -- no calloc_size_array at all. */
```
`RM_PSA_CRYPTO_TESTS_MAX_CALLOC` is `200` in both trees (`psa_crypto_tests_setup.h:16`, unchanged
value) — the difference is entirely the **second array**, `calloc_size_array`, which v4 added to
implement the size-based (not position-based) leak matching from §8
(`MBEDTLS_PSA_KEY_STORE_DYNAMIC`'s two structural allocations). `ra2a1_tbb` doesn't even have
`MBEDTLS_PSA_KEY_STORE_DYNAMIC` enabled, so it carries this array's 800 bytes for a workaround it
will never trigger. `RM_PSA_CRYPTO_TESTS_MAX_CALLOC` itself (200 slots) is also generously sized for
a board whose test suite (SHA+AES+TRNG only, sequential single-key tests, no array of concurrently
held handles — verified in §21) never approaches that many concurrently-tracked allocations.

**Fix applied — board-scoped override, not a global default change:**
1. `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_setup.h:16` — wrapped the constant so it's
   overridable without touching other boards:
   ```c
   #ifndef RM_PSA_CRYPTO_TESTS_MAX_CALLOC
    #define RM_PSA_CRYPTO_TESTS_MAX_CALLOC   (200)
   #endif
   ```
2. `projects/rm_tf_psa_crypto.xml`, `ra2a1_tbb`'s `common_macros` only (same block as its existing
   `BSP_CFG_HEAP_BYTES=0x4000` override):
   ```xml
   <macro>RM_PSA_CRYPTO_TESTS_MAX_CALLOC=32</macro>
   ```
   Expected recovery: `(200-32) slots × 8 bytes/slot (uint32_t + size_t) = 1344 bytes`.

**Deliberately NOT a global default change** — `RM_PSA_CRYPTO_TESTS_MAX_CALLOC` is shared test
infrastructure used by every board's leak detection, including boards with much heavier test
suites (RA8M1 with full RSA/ECC/PQC) that may genuinely track closer to 200 concurrent allocations
during a run. Lowering the global default risks silently breaking leak detection there (an
allocation past the tracked-slot count would go unrecorded, masking a real leak) — only
`ra2a1_tbb`'s own override was touched, matching how `BSP_CFG_HEAP_BYTES` is already scoped
per-board in the same file.

**Running total for `ra2a1_tbb`:** 960 bytes (§21, `MBEDTLS_PSA_KEY_SLOT_COUNT`) + up to 1344 bytes
(this section) ≈ 2304 bytes against the original 2532-byte overflow. **Not yet done:** rebuild to
confirm the exact final number — may need `RM_PSA_CRYPTO_TESTS_MAX_CALLOC` nudged down further
(e.g. to 16) if a small remainder persists, or a real map-file breakdown if it doesn't fully close.

**Files affected:** `ra/fsp/src/rm_tf_psa_crypto/!test/psa_crypto_tests_setup.h` (`#ifndef` guard
added), `projects/rm_tf_psa_crypto.xml` (`ra2a1_tbb` `common_macros`).

## 21. Board-Specific RAM Overflow Fixes (FSPRA-5629)

**Pattern:** Low-power boards (SCE5, low-end RSIP) overflow RAM during test builds. Fix by 
reducing `BSP_CFG_HEAP_BYTES` in `projects/rm_tf_psa_crypto.xml` or disabling test categories.

**Examples from FSPRA-5629:**
- **ra8m2_ek (E50D, 16KB heap)** → RSA 3072/4096 fails with `PSA_ERROR_INSUFFICIENT_MEMORY` (-141)
  - **Root cause:** heap under-provisioned (0x4000) despite 1.37MB physical RAM available
  - **Fix:** increased to 0xF000 (60KB) to match ra8m1_ek/ra6m4_ek (higher-end boards)
  
- **ra4m1_ek (SCE5, low-power)** → RAM overflows by 1104 bytes during link
  - **Root cause:** heap too large (0x4400) for actual device RAM
  - **Fix:** reduced to 0x3000 (12KB), matching ra2a1_ek (same SCE5 engine)
  - **Pattern:** SCE5 boards use lower heap; RoI marginal with higher crypto overhead

**Checklist when board RAM overflows:**
1. Check device's actual SRAM size (bsp_linker_info.h or datasheet) vs configured heap
2. Compare to reference board with same crypto engine (e.g., SCE5 → ra2a1_ek; E50D → ra8m1_ek)
3. Match heap/stack from the reference board
4. If still tight, disable test categories: `TEST_PSA_CRYPTO_SHA3=0`, `TEST_PSA_CRYPTO_RSA=0`, etc.
5. Rebuild and confirm no overflow

**Files affected:** `projects/rm_tf_psa_crypto.xml` (board `common_macros` heap/stack).

## 23. Module-description copy/paste bugs that break e2 studio constraints and generated config (2026-10-06)

Found while chasing xml-test failures `rm_tf_psa_crypto_tf_psa_crypto_availability_gcc_No_RTOS_*`
(initial constraints "Expected 7, Found 8", final "Expected 0, Found 1", build `completed-0`) on
all boards. All in `ra/arm/.module_descriptions/Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml`.

**1. Unbalanced parens in a constraint = permanently-active constraint.** Same class as §19 (ECC
heap). Second instance: "A minimum RTOS heap of 0x1800 ... Software ECC" had 10 `(` / 9 `)`. e2
studio cannot evaluate it, so it fails closed: shown even with No RTOS (the `!testExists(rtos)`
escape never gets evaluated) and not cleared by raising heap. That one constraint explains both the
+1 initial count and the leftover 1 at the end. Fix: add the missing `)` at the end.

**2. Properties whose option ids were copy-pasted from a sibling.** A property's `default` and its
`<option id>`s must all start with the property's own id. Found and fixed:
- `..._ecp_secp_r1_256`: options were `..._secp_k1_256.*`
- `..._ecp_secp_r1_521`: options and default were `..._secp_r1_512.*`
- `..._alg_ccm_star_no_tag`: options were `..._alg_ccm.*` (duplicate option ids with the CCM property)
- `..._key_type_{ecc,rsa,dh}_key_pair_import`: default had no `.enabled/.disabled` suffix. Set to
  `.disabled` to match every sibling key-pair property (intent not confirmed with the author).
Why it matters: the config template emits `#if ${config.driver.tf_psa_crypto_<id>}`, which needs
the property to resolve to an option value (`1`/`0`). A default that matches no option can leave a
bare `#if`, a preprocessor error in generated `tf-psa-crypto-config.h`. This is a likely cause of
the 17 compile errors noted as undiagnosed in §19 (not yet confirmed by a build). It also made the
`mbedTLS_v4` constraint "MBEDTLS_ECP_DP_SECP256R1_ENABLED ... PSA_WANT_ECC_SECP_R1_256" impossible
to satisfy, since `secp_r1_256.enabled` was not an option of that property.

**Not changed:** `secp_r1_256` default is `.disabled`, while v3 defaulted SECP256R1 to enabled and
the mbedTLS_v4 module requires it enabled. Decide whether the default should be `.enabled`.

**Checks to run after any edit of this file (all took seconds, python):**
1. Per `<constraint>`: `count('(') == count(')')`.
2. Per `<property>` with options: every option id starts with `property id + '.'`, and `default`
   (if a `config.` id) is one of its option ids; no option id appears twice file-wide.
3. Every `${config.driver.*}` used in constraints/templates has a `<property id=...>` definition.
   Ignore `config.bsp.*` and `config.awsfreertos.*` (defined in other module files).
4. `xmllint --noout`, and keep CRLF endings (the working copy is CRLF; use `open(..., newline='')`).
Numeric/self-closing properties will confuse a naive regex (it picks up the next property's
options); skip `<property .../>` tags.
