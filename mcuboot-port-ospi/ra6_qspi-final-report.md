# FSPRA-6331 / FSPRA-6767: Re-enable the MCUboot QSPI test on EK-RA6M5 (`ra6_qspi`)

Date: 2026-10-09. Branch: `FSPRA-6331_Re-enable_RA6_MCUboot_QSPI` (commits from FSPRA-6767 and FSPRA-6331).
Result reported by the owner: **all test cases pass on EK-RA6M5.** (Hardware results were reported by the owner and not independently seen by the author of this document; build, size and lint checks listed below were run by the author with gcc.)
Audience: reviewers, the project manager, and engineers who will maintain the MCUboot port tests.

## 1. Summary
- **Goal:** have a test that runs MCUboot on EK-RA6M5 with the secondary image slot in the external QSPI flash (Macronix MX25L25645G, 32 MB) and the primary slot in internal flash, and checks the port's external-flash behaviour (virtual sectors, whole-block erase, rejection of unaligned erase).
- **Result:** a new boot project `ra6_qspi` plus a separate app project `rm_mcuboot_app_qspi.xml`; the existing `ra6m5_std` test is untouched. The six TG2 erase tests (written for OSPI in FSPRA-4851) now run for QSPI too and were generalised from OSPI to XSPI naming.
- **The key engineering finding:** MCUboot only treats the secondary slot as external flash if the compiled `flash_map[]` table says so. That table is selected at compile time from the default ra6m5 linker folders, not by the project's linker settings. The final design adds an `#ifdef` guard in 8 default `bsp_linker_info.h` files, so only the QSPI projects get the external map.
- **Quality checks (gcc, run locally):** all five builds succeed (`ra6_qspi` typical/overwrite/overwrite_fast, `rm_mcuboot_app_qspi` typical/secondary), the compiled `flash_map` was decoded and shows the secondary as external at 0x60000000, and the repo's clang-tidy reports 0 errors on the new code.

## 2. Background: what existed before
| Item | State on develop |
|---|---|
| `ra8_ospi` (EK-RA8D1) | Only external-flash MCUboot test; its TG2 tests are OSPI-only (FSPRA-4851). |
| Old QSPI boot test `ra6m4_qspi` | Added 2021-11-22 (SWFLEX-3508), deleted 2022-03-31 by `0ae01dcb03b`. Cannot run on current code. |
| `ra6m5_ek` entry in `rm_mcuboot_app.xml` | Flagged `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI=1` but no boot project used QSPI; it is the app for `ra6m5_std` (internal-flash secondary). |
| `flash_map.c` | Since FSPRA-4851 the external-flash code only compiles under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`; the QSPI flag alone selects nothing. |
| Default ra6m5 `boot`/`image` linker folders | `flash_map[]` secondary entry = `FLASH_DEVICE_INTERNAL_FLASH` at 0x40000. |

## 3. Design

### 3.1 Memory and slot layout
```
internal flash                         QSPI (MX25L25645G, 32 MB)
0x00000  bootloader (mcuboot)          0x60000000  secondary header  (0x200)
0x20000  primary slot (header+image)   0x60000200  secondary image   (0x1FE00)
0x40000  staging copy of the secondary             slot size 0x20000 = 4 x 32 KB
0x60000  scratch (0x8000)
```
- Slot size 0x20000 equals four 32 KB virtual sectors, so the slot is a whole number of the QSPI erase block (32 KB, the only size offered by `rm_mcuboot_ext_memory_qspi`).
- The trailer lives inside the last sector of the slot (no separate trailer region, same as the existing ra6m5 layout).

### 3.2 Test flow (build, flash, boot, test)
1. **Build** (`scons --build=rm_mcuboot_port --project=ra6_qspi`): the bootloader in three configurations (swap default, `overwrite`, `overwrite_fast`) and the app `rm_mcuboot_app_qspi` in two (typical = primary, version 1.0.0; secondary = version 1.0.1 built with `RM_MCUBOOT_PORT_SECONDARY=1`, signed `--confirm`). EC-256 signing (`MCUBOOT_SIGN_EC256`), SCE9 plain-key crypto, v3 `rm_psa_crypto`.
2. **Flash** (J-Link through `fsp_test_parallel.py`): typical signed srec to internal 0x20000; secondary signed srec to internal 0x40000; bootloader to 0x0. The J-Link loader never writes the QSPI chip, so no J-Link script is needed (unlike OSPI, where the loader programs the external chip and needs a power-cycle script).
3. **Bootloader start** (`test_files/src/r_tests_runner_main.c`, `TEST_MCUBOOT`): configure MPU, then `qspi_test_setup_common()`: pins, `R_QSPI_Open`, exit QPI mode (0xF5), software reset (0x66, 0x99), set the quad-enable bit, read JEDEC id, erase 0x20000 bytes of QSPI in 32 KB blocks, copy 0x20000 bytes from internal 0x40000 to 0x60000000 page by page, wait for the last program, verify byte for byte. Then mbedTLS platform setup and `boot_go()`.
4. **MCUboot:** reads the primary (internal, v1.0.0) and the secondary (QSPI, v1.0.1) through the external `flash_map` entry, verifies the signature, and updates. Overwrite configurations copy the secondary over the primary and then erase the secondary's first and last sector through the QSPI driver; the swap configuration swaps through the internal scratch area.
5. **`RM_MCUBOOT_PORT_BootApp`:** set VTOR to 0x20200, flush buffered writes, close flash and QSPI, jump.
6. **App** (secondary build, now in the primary slot) runs `RunAllRM_MCUBOOT_PORTTests`. TG1 `TC_Vtor` is skipped for XSPI. TG2: per test `rm_mcuboot_port_qspi_test_setup()` then `flash_area_open(secondary)` and the six checks (section 3.5).
- **Pass/fail linkage:** if the update failed, the old typical image runs (`RM_MCUBOOT_PORT_SECONDARY=0`) and TG2 fails with "Primary app running, expected secondary", so a failed update cannot pass silently.

### 3.3 Selecting external flash: the flash-map guard (the central design decision)
- `flash_map[]` is defined in `bsp_linker_info.h` under `#ifdef FLASH_MAP_C` and included by `flash_map.c`. Its secondary entry decides whether `flash_area_*` calls take the internal-flash or the external (XSPI) path.
- The compile-time include path to that header comes from the shared project-type XML (`test_files/shared/common_boot.xml` points at `.../!linker/${COMPILER}/boot`, `common_boot_app.xml` at `.../image`). A project's `<linker_includes>` only affects the linker search path, and a project's `<include_dirs>` is appended after the common one, so a project cannot override which `bsp_linker_info.h` is compiled. (Verified from the `scons -n` include order.)
- Therefore the guard lives in the default files, in all 8 of `ra/fsp/src/bsp/mcu/ra6m5/!linker/{gcc,ac6,iar,llvm}/{boot,image}/bsp_linker_info.h`:
```c
{
    .fa_id        = FLASH_AREA_0S_ID,
#ifdef RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI
    .fa_device_id = FLASH_DEVICE_EXTERNAL_FLASH,
    .fa_off       = BSP_PARTITION_QSPI_FLASH_CPU0_S_START,   /* 0x60000000 */
#else
    .fa_device_id = FLASH_DEVICE_INTERNAL_FLASH,
    .fa_off       = BSP_PARTITION___BL_0_S_H_START,          /* 0x40000 */
#endif
    .fa_size      = BSP_PARTITION___BL_0_S_H_SIZE + BSP_PARTITION___BL_0_S_I_SIZE,
},
```
- Only the two QSPI projects define `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI` on ra6m5, so every other ra6m5 project is unchanged. Verified: the compiled table for `rm_mcuboot_app` (used by `ra6m5_std`) still shows the secondary as internal at 0x40000.
- Verification method: `arm-none-eabi-objdump -s .../flash_map.o`, section `.rodata.flash_map`, 12 bytes per entry (`fa_id`, `fa_device_id`, 2 pad, `fa_off`, `fa_size`; device 0x7f = internal, 0x80 = external). The secondary app, the typical app and the `ra6_qspi` bootloader all show entry 2 as `02 80 .. 00 00 00 60 ..`.
- Trade-off: these are generated-style files edited by hand; regenerating them would silently drop the guard (the tests would then fail on the unaligned-erase cases, so it is detectable). Alternative considered: new project types `boot_qspi`/`boot_app_qspi` with their own shared XML (the pattern used by `boot_multi_images`); cleaner but changes `SConstruct`, so not taken.

### 3.4 Projects (XML)
- **`ra6_qspi`** in `projects/rm_mcuboot_port.xml` (133 added lines, placed next to `ra6m5_std`, derived from it): board `ra6m5_ek`, dependency `rm_mcuboot_app_qspi`, SCE9 plain-key crypto, `r_qspi.c` as instrumented code, test macros `TEST_MCUBOOT=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`, `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE=32768`, `FSP_TEST_FUNCTION=RunAllRM_MCUBOOT_PORTTests`, same three main-macro configurations as `ra6m5_std`.
- **`projects/rm_mcuboot_app_qspi.xml`** (new): app for `ra6m5_ek`, primary slot 0x20000, secondary slot 0x40000 (staging address in internal flash), slot size 0x20000, `align 128`, 4 sectors, EC-256 key, same QSPI/XSPI macros, `r_qspi` as a common dir, `!test_app` and `rm_mcuboot_port_data.c` as test dirs.
- **Why a separate app file:** the build system finds a boot project's app by XML file name, board and toolchain (`SConstruct _add_dependency`), not by project name. A second `ra6m5_ek` entry in `rm_mcuboot_app.xml` collides (verified: scons stops with "Two environments with different actions were specified for the same target") and overwriting the existing entry would break `ra6m5_std`. A named extra entry builds but makes both boot projects flash the wrong app. `rm_mcuboot_app_xip.xml`, `_protected.xml` and `_encrypted.xml` follow the same separate-file pattern.
- **Release note:** `documents/release_notes/upcoming/FSPRA-6331.yml`.

### 3.5 Code
**`ra/fsp/src/rm_mcuboot_port/!test/rm_mcuboot_port_data.c`** (QSPI branch, under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI`)
- Defines the QSPI instance the port uses: `g_qspi_ctrl`, `g_qspi_cfg`, `g_qspi`, and the pointers `gp_mcuboot_xspi_ctrl/cfg/instance` that `flash_map.c` links against. Configuration: extended SPI, Fast Read Quad I/O, 3-byte addresses, page 256, erase commands 0x20/0x52/0xD8/chip 0xC7, `QSPCLK` divided by 2.
- New `rm_mcuboot_port_qspi_test_setup()`, called from TG2's setup: configure the six QSPI pins (P3_06 CS, P3_05 CLK, P3_07..P3_10 data) for EK-RA6M3/M4/M5, `R_QSPI_Open`, leave QPI mode by writing `SFMCOM` directly (the driver's `DirectWrite` status check fails when driver and device disagree on protocol), reset the flash (0x66/0x99), set the quad-enable bit, read status register 1 and the JEDEC id, log both over RTT. Runs once (static flag). It deliberately does not copy an image; the bootloader does that.
- Named constants for the commands and masks (clang-tidy `readability-magic-numbers`); the masked status value is held in a `uint32_t` local (clang-tidy `rea-tp-casting`).
- Not included on purpose: `r_qspi_test_port.h`, because it declares `extern qspi_extended_cfg_t g_qspi_extended_cfg` which clashes with this file's static const of the same name.

**`ra/fsp/src/rm_mcuboot_port/!test/rm_mcuboot_port_test.c`** (`qspi_test_setup_common`, run by the bootloader)
- Extended from the legacy version: sets the quad-enable bit using the repo's own header values (`QSPI_TEST_WE_SR`, `QSPI_COMMAND_WRITE_STATUS_REGISTER_1`, `QSPI_TEST_DEFAULT_SR1/2`), reads the JEDEC id (expect 0x001920C2) and SR1 (QE bit 0x40), captures the erase and write error codes, waits for the last page program before reading QSPI memory-mapped (previously nothing waited), verifies the copy byte for byte, logs the first differing offset and the header magic (expect 0x96F3B83D). All logging is RTT lines prefixed `MCUBOOT-QSPI:`.

**`!test_app/rm_mcuboot_port_tests_tg2.c`** and **`..._runner.c`**
- Guards changed from `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_OSPI_B` to `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`; TG2 calls `RM_MCUBOOT_PORT_XSPI_TEST_SETUP()`, which maps to the QSPI or OSPI setup function; the `TC_Vtor` skip applies to all XSPI.
- Renamed OSPI-specific names to XSPI: constants `XSPI_ERASE_TEST_*`, doxygen group, requirement ids `mcuboot_port_xspi_*` and the six `um_mcuboot_port_xspi_*` anchors in `!dsn/rm_mcuboot_port_usage_notes.md`. Only `rm_mcuboot_port_ospi_test_setup()` keeps its OSPI name because it is OSPI-only.
- The six tests (all in the app, secondary slot): `TC_Virtual_Sectors_Match_Physical_Block` (both slots report 32 KB sectors), `TC_Erase_One_Physical_Block`, `TC_Erase_Multiple_Physical_Blocks` (erase, write pattern 0x5A, erase, read back 0xFF), `TC_Erase_Partial_Block_Does_Not_Overerase` (ignored on QSPI because the logical sector equals the 32 KB block), `TC_Erase_Rejects_Unaligned_Length` and `TC_Erase_Rejects_Unaligned_Address` (the port must return an error and leave data intact; these exist only in the external path of `flash_map.c`, which is why the flash-map guard is required for them to pass).

**`flash_map.c` was not modified.** Its external path already supports any `spi_flash` driver: `RM_MCUBOOT_PORT_VIRTUAL_SECTOR_SIZE` = XSPI erase block for both slots, `flash_area_erase` rejects length or address not multiples of the block, writes go page by page with a 256-word flush buffer, status is polled through `statusGet`.

## 4. Verification
| Check | Result |
|---|---|
| Hardware: all test cases (reported by owner) | pass |
| gcc builds of `ra6_qspi` (3 configs) and `rm_mcuboot_app_qspi` (2 configs) | succeed |
| Compiled flash map for secondary app, typical app, bootloader | external, 0x60000000 |
| `ra6m5_std`'s app flash map | still internal, 0x40000 (no regression) |
| clang-tidy (repo setting, warnings-as-errors) on the new code | 0 errors |
| Bootloader size | about 67 KB, inside the 0x20000 bootloader region |
| ac6, iar, llvm | linker files updated for all four compilers; only gcc builds and the llvm bootloader link were run by the author; the CI covers the rest |
| 2026-10-07 EK-RA6M5 run before the flash-map guard | two reject tests failed ("Expected Not-Equal") because the secondary was still internal; root cause in section 5 |

## 5. Issues found and how they were resolved (history)
1. **Variant linker folders had no effect.** The first design added `boot_qspi`/`image_qspi` linker folders selected by `<linker_includes>`. The two reject tests failed on hardware because the compiled flash map was still internal. Cause: section 3.3. Fix: the guard in the default files.
2. **The variant folders were then proved unnecessary and removed.** Building with and without them gave identical section addresses and sizes; only the values of unused symbols differed (`__BL_0_S_*`, `QSPI_FLASH_*`), because no output section is placed in the `__BL_0_S_*` regions and no C code references those symbols. 32 files and the `<linker_includes>` entries were deleted (commit `ad4251fd329`).
3. **A first attempt at the guard hung on hardware (cause not determined).** With the guard applied, the run printed the bootloader banner and then nothing for 10 minutes. Changes made around that time: the app's `image_qspi` linker regions were put back to internal (`bb012a69b52`), the guard was applied to both boot and image files (a guard in the bootloader file alone cannot work, because the TG2 tests run in the app and use the app's own compiled flash map), the unused variant folders were removed, the quad-enable write and a status wait after the last page program were added. The test passes after those changes. Which one removed the hang was not isolated; the linker-region theory is weakened by the build comparison in item 2 (section layout was identical with and without the variant regions). The most likely candidates are the missing quad-enable write and the missing wait before the first memory-mapped read, but this is a hypothesis.
4. **Quad-enable bit.** The MX25L25645G's quad-enable bit (SR1 0x40) is non-volatile and off by default; the repo's own r_qspi test writes it in every test case. The first setup code assumed it was set; the current code writes and reads it back.
5. **Lint.** CI clang-tidy rejected bare numbers; a local clang-tidy run also found one redundant cast. Both fixed with named constants and a `uint32_t` local in `rm_mcuboot_port_data.c` and `rm_mcuboot_port_test.c` (commit `7159690bed5` "Fix build failed" touches these two files; the author did not inspect its full content).
6. **Merging the QSPI app into `rm_mcuboot_app.xml`** was tried and rejected (section 3.4).

## 6. Risks, limits and follow-ups
- **Simulated delivery:** the image reaches QSPI through the bootloader's copy, not a real download. A J-Link-direct load (secondary slot at 0x60000000, as `ra8_ospi` does) is a possible follow-up; it needs the non-copy setup in the boot flow and a loader that can program this QSPI chip (the r_qspi tests set `QSPI_TEST_DEBUGGER_DOWNLOAD=1` for this board, so it is plausible).
- **Hand-edited generated files:** the guard in 8 `bsp_linker_info.h` files; a regeneration drops it silently (detected by the reject tests failing).
- **Alignment:** app `<align>128` (HP flash write size, `MCUBOOT_BOOT_MAX_ALIGN`) versus QSPI page size 256; no problem seen in the passing run, but not analysed in depth.
- **Swap configuration** with QSPI trailer writes: built and run as part of the three configurations; coverage of the failure cases (power loss mid-swap) is not part of this test.
- **Coverage gaps:** one of six TG2 tests is ignored on QSPI (block equals logical sector); `TC_Vtor` (end-to-end vector table check) is skipped for XSPI; RTT diagnostics exist but there is no automated check of the `MCUBOOT-QSPI` lines.
- **`ra6m5_std`** keeps testing the internal-flash path; both tests run on `ra6m5_ek` in the `rm_mcuboot_port` pipeline entry.

## 7. How to reproduce and re-check
```
export PATH=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH
scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8        # build both images
arm-none-eabi-objdump -s build/rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug/ra/fsp/src/rm_mcuboot_port/flash_map.o   # section .rodata.flash_map
export PATH=/opt/clang-tidy/bin:$PATH
scons ... --static_analyze=export > log 2>&1; grep -E "error: .*warnings-as-errors" log | sort -u   # 0 lines = clean
```
Expected RTT lines on a run: `MCUBOOT-QSPI: quad-enable write err=0 ... SR1=0x40`, `JEDEC ... id=0x001920C2`, `erase err=0 write err=0 wait err=0 pages=512`, `verify OK ... header magic 0x96F3B83D`, then `APP-QSPI: ...` from the app.

## 8. Related notes (skill `mcuboot-port-ospi`)
`SKILL.md` (design notes, evidence, state log), `ra6_qspi-test-report.md` (early design report, some parts superseded), `ra6_qspi-tg2-failure-report.md` (root cause of the first hardware failure), `ra6_qspi-pm-review-report.md` (OSPI validity and old versus new test, written for the project manager). This document supersedes statements in them about the `boot_qspi`/`image_qspi` linker folders.
