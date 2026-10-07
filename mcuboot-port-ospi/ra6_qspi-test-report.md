# ra6_qspi MCUboot test report (EK-RA6M5, QSPI secondary slot)

Date: 2026-10-07. Branch: FSPRA-6767. Author of the work: Minh Nguyen with Claude Code.
Status: **ran on hardware once (2026-10-07): 2 TG2 tests failed; root cause found, see section 0. Sections 4-6 describe the INTENDED design and are wrong about flash_map until the fix in section 0 is applied.**

## 0. Hardware result and root cause (2026-10-07) - read first
Failures: `TC_Erase_Rejects_Unaligned_Length` (tg2.c:246) and `TC_Erase_Rejects_Unaligned_Address` (tg2.c:269), "Expected Not-Equal"; the other TG2 tests did not fail.
Cause: the `boot_qspi`/`image_qspi` folders only reach the linker (`<linker_includes>` -> `LIBINCPATH`). The compile-time include for `bsp_linker_info.h` comes from the project type's shared xml (`test_files/shared/common_boot.xml` -> `boot`, `common_boot_app.xml` -> `image`) and a project `<include_dirs>` entry is appended after it, so the default folders always win (checked from the `scons -n` -I order). Both the bootloader and the app were therefore compiled with the INTERNAL flash map: the secondary slot was internal flash at 0x40000, QSPI was only a copy target, and `flash_area_erase` used the internal path, which accepts unaligned erases. The reject checks only exist in the external (XSPI) path of `flash_map.c`.
Consequences: section 6 below ("really uses QSPI") is NOT true for the current build; the earlier bss-size evidence only showed the XSPI buffers compiled in. The J-Link/bootloader-copy comparison in section 9 still holds as a design comparison.
Fix options (decision pending): (1) new project types `boot_qspi`/`boot_app_qspi` with their own shared xml and `SConstruct` classes, like `boot_multi_images` (repo-native, shared build script change); (2) rewrite ra6m5 default `boot`/`image` as ra8d1 did (breaks `ra6m5_std`); (3) select the flash map inside `flash_map.c` (production code change).

## 1. Purpose
Test MCUboot (`rm_mcuboot_port`) on EK-RA6M5 with the secondary image slot in the external QSPI flash (MX25L25645G, 32 MB) and the primary slot in internal flash. The only comparable test in the repo is `ra8_ospi` (OSPI on EK-RA8D1).

## 2. Why this was needed (findings)
- develop's `projects/rm_mcuboot_port.xml` contains no QSPI boot project. The old one, `ra6m4_qspi`, was deleted by commit `0ae01dcb03b` (2022-03-31); it was added by `8bf72097f7f` (2021-11-22).
- The `ra6m5_ek` entry of `rm_mcuboot_app.xml` is QSPI-flagged (`RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI=1`) but nothing uses QSPI: since FSPRA-4851 `flash_map.c` only compiles external-flash code under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`, and the ra6m5 `boot`/`image` linker folders put the secondary slot in internal flash at 0x40000.
- That entry is the dependency of the active `ra6m5_std` project, so it cannot be changed.

## 3. What was added (all uncommitted or committed on the branch, see `git status`)
| Item | Purpose |
|---|---|
| `projects/rm_mcuboot_port.xml`: new `ra6_qspi` block | Boot project, derived from `ra6m5_std` (SCE9 plain key, v3 `rm_psa_crypto`, EC256). Macros: `TEST_MCUBOOT=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`, `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE=32768`; linker `boot_qspi`; `r_qspi.c` as main code; runs `RunAllRM_MCUBOOT_PORTTests` |
| `projects/rm_mcuboot_app_qspi.xml` (new file) | App project for `ra6m5_ek`: primary v1.0.0, secondary v1.0.1 (`RM_MCUBOOT_PORT_SECONDARY=1`, signed `--confirm`), same XSPI macros, linker `image_qspi` |
| `ra/fsp/src/bsp/mcu/ra6m5/!linker/{gcc,ac6,iar,llvm}/{boot_qspi,image_qspi}` (32 files) | Copies of `boot`/`image` with the secondary slot moved to QSPI (see section 4) |
| `!test/rm_mcuboot_port_data.c` | New `rm_mcuboot_port_qspi_test_setup()`: configure pins P3_06/05/07-10, open QSPI, exit QPI (0xF5), reset flash (0x66/0x99); no image copy |
| `!test_app/rm_mcuboot_port_tests_tg2.c`, `..._runner.c` | OSPI erase tests and the `TC_Vtor` skip now key on `_USE_XSPI`; TG2 setup calls the QSPI setup when `_USE_QSPI` is defined |

Decision record: the QSPI app lives in its own file because (a) overwriting the `ra6m5_ek` entry breaks `ra6m5_std`; (b) a second `ra6m5_ek` block in `rm_mcuboot_app.xml` makes scons fail with "Two environments with different actions were specified for the same target" (verified with `scons -n`, both boot projects fail); (c) a second block with a `<name>` builds, but `SConstruct _add_dependency` looks the app up by file name only, so `ra6_qspi` would flash `ra6m5_std`'s internal-flash app (wrong). Option 2 would need an `SConstruct` change; not done.

## 4. Linker variant details (`boot_qspi`, `image_qspi`)
Only `memory_regions.*` and `bsp_linker_info.h` differ from `boot`/`image`; `fsp_gen.*` and `bsp_mcu_ofs_cfg.h` are byte-identical copies.

| Item | `boot`/`image` | `*_qspi` |
|---|---|---|
| `__BL_0_S_H_START` | 0x00040000 | 0x60000000 |
| `__BL_0_S_I_START` | 0x00040200 | 0x60000200 |
| `QSPI_FLASH` region | 0x60000000, 0x2000000 | 0x60020000, 0x1FE0000 (no overlap with the slot) |
| `flash_map` entry for the secondary | `FLASH_DEVICE_INTERNAL_FLASH` | `FLASH_DEVICE_EXTERNAL_FLASH` |
Slot = 0x20000 = header 0x200 + image 0x1FE00 = 4 x 32 KB virtual sectors. Primary stays internal at 0x20000, scratch `__BL_S` internal at 0x60000 (0x8000).
Precedent for per-mode linker folders: `boot_mmf`/`image_mmf` (ra2a2, ra6m3), `image_xip` (ra6m4, ra8m1), `primary_core`/`secondary_core` (ra8 dual core). ra8d1 instead rewrote its default folders for OSPI (FSPRA-4851).

## 5. Test flow
1. **Build:** boot `ra6_qspi` in three configurations (swap default, `overwrite`, `overwrite_fast`) plus the app (typical = primary v1.0.0; secondary v1.0.1).
2. **Flash (J-Link via `fsp_test_parallel.py`):** typical signed srec to internal 0x20000; secondary signed srec to internal 0x40000 (staging only); bootloader to 0x0. The loader never writes QSPI, so no J-Link script (unverified).
3. **Bootloader start** (`test_files/src/r_tests_runner_main.c`, `TEST_MCUBOOT`): `qspi_test_setup_common()` opens QSPI, exits QPI, resets the flash, erases 0x20000 bytes in 32 KB blocks and copies 0x20000 bytes from internal 0x40000 to QSPI 0x60000000; then mbedTLS platform setup and `boot_go()`.
4. **MCUboot:** reads primary (v1.0.0) and the QSPI secondary (v1.0.1, memory-mapped reads through the external `flash_map` entry), verifies the EC256 signature, then updates. Overwrite configs copy secondary over primary and afterwards erase the secondary's first and last sector through the QSPI driver (`loader.c` ~line 1082). The swap config swaps through the internal scratch area and writes status/trailer into the QSPI slot.
5. **`RM_MCUBOOT_PORT_BootApp`:** VTOR to 0x20200, flush buffered writes, close flash and QSPI, jump.
6. **App** (secondary build, now in the primary slot) runs `RunAllRM_MCUBOOT_PORTTests`: TG1 `TC_Vtor` skipped (XSPI); TG2 per test calls `rm_mcuboot_port_qspi_test_setup()` and opens the secondary area: virtual sectors equal 32 KB on both slots, erase one block, erase multiple blocks, partial erase (ignored: 32 KB equals the logical sector), reject unaligned length, reject unaligned address.
Pass/fail linkage: if the update fails the old typical image boots (`RM_MCUBOOT_PORT_SECONDARY=0`) and TG2 fails with "Primary app running, expected secondary."

## 6. Does it really use QSPI as the secondary slot?
By design yes: the boot flash map has no internal entry for the secondary, so v1.0.1 can only reach the primary slot by being read from QSPI at 0x60000000. QSPI is also exercised by the post-copy erases (overwrite), trailer writes (swap) and all TG2 operations. Circumstantial build evidence: `flash_map.o` for `ra6_qspi` has 1154 bytes of bss, consistent with the 1 KB XSPI write buffer being compiled in. Limitation: the image is placed in QSPI by the bootloader's own test hook (simulated delivery), not by a real download.

## 7. Verification status (honest)
| Item | Status |
|---|---|
| Project XML well formed, files diffed against `origin/develop` | done |
| gcc build of `rm_mcuboot_app` typical + secondary with `image_qspi` | **succeeded**; secondary ELF contains `rm_mcuboot_port_qspi_test_setup` and the TG2 tests |
| gcc build of boot `ra6_qspi`: `r_qspi.o`, `flash_map.o`, `rm_mcuboot_port.o` | compiled |
| gcc link of boot `ra6_qspi` | **blocked**: `ra/fsp/src/rm_psa_crypto/shake_alt.c` needs `mbedtls/shake.h`; local `ra/arm/mbedtls` is at `7f1228a`, the repo records `7b21deb` (has it); `r_sce/crypto_procedures` also differs. Not caused by this work. Submodules were not changed |
| ac6, iar, llvm builds | not tried |
| Hardware run | not done |
| Build recipe | `export PATH=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH; scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8` (`-n` for a dry run) |

## 8. Known risks / open items
1. **Alignment:** app `<align>128` and `MCUBOOT_BOOT_MAX_ALIGN` = 128 (HP flash write size) versus QSPI page size 256 and `flash_area_align()` = 256 for external: possible MCUboot assertion, mainly in swap mode.
2. **Quad-enable bit** of the MX25L is assumed set, as in the legacy `qspi_test_setup_common`.
3. **Swap configuration** with QSPI trailer/status writes is untested.
4. **J-Link:** whether the loader can program QSPI on this board is unverified. `r_qspi` tests set `QSPI_TEST_DEBUGGER_DOWNLOAD=1` for EK-RA6M5 (and have a `g_debugger_download_working` fallback), so loading directly is plausible.
5. **CI side effect:** `ra6m5_ek` is already in the `rm_mcuboot_port` pipeline entry, so `ra6_qspi` runs there automatically.
6. TG2 requirement ids/anchors/constants renamed `ospi` -> `xspi` (generic for OSPI and QSPI); the erase-test doc text still describes the 32 KB logical sector. Release note `FSPRA-6767.yml` is type 3 (internal).

## 9. Bootloader copy versus J-Link direct load
| | Bootloader copy (current) | J-Link direct (like `ra8_ospi`) |
|---|---|---|
| App `secondary_slot` | 0x40000 (internal) | 0x60000000 (QSPI) |
| QSPI written by | boot hook `qspi_test_setup_common()` | flash loader from the srec |
| Needs QSPI loader / script | no | yes (script possibly) |
| Weakness | QSPI test data prepared by the driver under test | depends on loader and chip state |
| Change cost | none | boot flow must use the non-copy `rm_mcuboot_port_qspi_test_setup()`; edits shared `test_files/src/r_tests_runner_main.c` |
Recommendation: first hardware run with the bootloader copy (no loader dependency); move to J-Link direct afterwards for the closer-to-real test.

## 10. Next steps
1. `git submodule update ra/arm/mbedtls ra/fsp/src/r_sce/crypto_procedures` (needs the owner's go-ahead), rebuild the boot link for gcc, then ac6/iar/llvm.
2. Run on EK-RA6M5; first check the three boot configurations reach TG2.
3. Resolve risk 1 (alignment) if MCUboot asserts.
4. Decide on J-Link direct load.
5. Commit (`git add projects/rm_mcuboot_app_qspi.xml`; project work is committed manually, never auto-committed).
