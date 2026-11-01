# FSPRA-6331 / FSPRA-6767: MCUboot QSPI test on EK-RA6M5 (`ra6_qspi`)

Status: compacted 2026-11-01 from the 2026-10-09 final report. Owner reported all test cases passing on EK-RA6M5 (not independently seen). Build, size and lint checks were run with gcc.

## Goal and result
- Run MCUboot with the secondary image slot in external QSPI (MX25L25645G, 32 MB) and the primary in internal flash. Check the port's external-flash behaviour: virtual sectors, whole-block erase, rejection of unaligned erase.
- New boot project `ra6_qspi` and app project `rm_mcuboot_app_qspi.xml`. `ra6m5_std` is unchanged.
- The six TG2 erase tests (from OSPI, FSPRA-4851) now run for QSPI too, renamed from OSPI to XSPI.

## Why a design change was needed
- The compiled `flash_map[]` decides whether the secondary is internal or external. It comes from the default ra6m5 `bsp_linker_info.h`, which is a collected file (SHA-256 in `data/collected-files/ddsc-generated.yml`, checked in CI). It cannot be edited.
- The compile include path comes from the shared project-type XML, before a project's `<include_dirs>`. Variant linker folders therefore do not change the compiled table.
- Final design: a generic hook in `flash_map.c` (`RM_MCUBOOT_PORT_CFG_FLASH_MAP_HEADER`), and a test-only header `!test/rm_mcuboot_port_qspi_flash_map.h` with the QSPI table. Only the two QSPI projects set the macro. Without it, behaviour is unchanged.

## Layout
```
internal:  0x00000 bootloader   0x20000 primary (v1.0.0)   0x40000 staging copy   0x60000 scratch
QSPI:      0x60000000 secondary header (0x200), image (0x1FE00), slot 0x20000 = 4 x 32 KB
```

## Test flow
1. Build the bootloader (swap, overwrite, overwrite_fast) and app typical and secondary (v1.0.1, `--confirm`, EC-256).
2. Flash through J-Link: primary and secondary to internal flash, bootloader to 0x0. The loader never writes QSPI, so no J-Link script.
3. Bootloader: `qspi_test_setup_common()` opens QSPI, exits QPI, resets the flash, sets the quad-enable bit, erases the slot, copies 0x20000 bytes from 0x40000 to QSPI, waits for the last page, verifies byte by byte.
4. MCUboot reads both slots (secondary through the external entry), verifies, and swaps or overwrites.
5. App (secondary, now primary) runs TG2. Each test calls `rm_mcuboot_port_qspi_test_setup()`, then checks the secondary slot. If the update failed, TG2 reports "Primary app running, expected secondary".

## Code
- `!test/rm_mcuboot_port_data.c` (QSPI branch): instance and `gp_mcuboot_xspi_*` pointers, extended SPI, Fast Read Quad I/O, 3-byte address, page 256, erase commands 0x20, 0x52, 0xD8, 0xC7. `rm_mcuboot_port_qspi_test_setup()` configures six pins, opens QSPI, leaves QPI, resets, sets quad-enable, logs SR1 and JEDEC ID over RTT. Does not include `r_qspi_test_port.h` (its `g_qspi_extended_cfg` clashes).
- `!test/rm_mcuboot_port_test.c` (`qspi_test_setup_common`): quad-enable write and read-back, JEDEC check (0x001920C2), erase and write error codes, wait before reading memory-mapped, byte verify, header magic check (0x96F3B83D). RTT prefix `MCUBOOT-QSPI:`.
- `!test_app/` TG2 and runner: guards are `..._USE_XSPI`. `RM_MCUBOOT_PORT_XSPI_TEST_SETUP()` maps to the QSPI or OSPI setup. Requirement IDs `mcuboot_port_xspi_*`. Only `rm_mcuboot_port_ospi_test_setup()` keeps the OSPI name.
- TG2 tests: sectors match physical block; erase one block; erase multiple blocks; partial erase (ignored on QSPI because the logical sector equals the block); rejects unaligned length; rejects unaligned address. The last two exist only on the external path of `flash_map.c`, so the hook is required.
- `flash_map.c` external path is unchanged. It already supports any `spi_flash` driver.

## Verification
| Check | Result |
|---|---|
| Hardware, all test cases (owner report) | pass |
| gcc builds, 3 bootloader and 2 app configs | succeed |
| Compiled flash map (secondary) | external, 0x60000000 |
| Collected-file hash check (80 ra6m5 entries) | all match, nothing modified |
| clang-tidy, warnings-as-errors, new code | 0 errors |
| Bootloader size | about 67 KB, inside its 0x20000 region |
| ac6, iar, llvm | linker files updated; only gcc and llvm bootloader link were run by the author |

## Issues resolved (history)
1. Variant linker folders had no effect on the compiled table. Removed. Build comparison showed identical section layout with and without them.
2. The first guard in the default linker files failed the CI hash check. Replaced by the `flash_map.c` hook.
3. An early hardware run hung after the banner. Changes made at that time: quad-enable write added, wait before the first memory-mapped read added, app regions restored. The hang cause was not isolated.
4. Quad-enable bit (SR1 0x40) is non-volatile and off by default. The code now writes and checks it.
5. Lint: bare numbers and a redundant cast. Fixed with named constants and a `uint32_t` local.

## Risks and follow-ups
- The image reaches QSPI by the bootloader's copy, not a real download. A direct J-Link load is a possible follow-up.
- The QSPI table is duplicated in the test header. If the generated partition macros change, the build fails on a missing macro, and the header must be updated.
- Alignment: app `<align>128` versus QSPI page 256. No problem seen, not analysed in depth.
- Swap-mode power loss is not covered by this test.
- `ra6m5_std` keeps testing the internal path.

## Reproduce
```
export PATH=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH
scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8
arm-none-eabi-objdump -s <build dir>/ra/fsp/src/rm_mcuboot_port/flash_map.o   # section .rodata.flash_map
```
Expected RTT: `MCUBOOT-QSPI: quad-enable write err=0 ... SR1=0x40`, `JEDEC ... id=0x001920C2`, `verify OK ... header magic 0x96F3B83D`, then `APP-QSPI: ...`.
