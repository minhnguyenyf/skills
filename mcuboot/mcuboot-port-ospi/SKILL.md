---
name: mcuboot-port-ospi
description: rm_mcuboot_port (MCUboot port for RA) with OSPI_B and QSPI external-flash secondary slots, the ra8_ospi and ra6_qspi test projects, and flash_map.c. Use when working on rm_mcuboot_port, flash_map.c, OSPI or QSPI secondary slots, MCUboot xml tests, or the ra8_ospi and ra6_qspi boot tests.
---

# rm_mcuboot_port: OSPI_B and QSPI external-flash slots

Status: compacted 2026-11-01. Older state notes were removed. The current QSPI state is in "ra6_qspi" below. Owner reported all TG2 tests passing on EK-RA6M5 (2026-10-09, not independently seen; see `ra6_qspi-final-report.md`).

## Folder map (`ra/fsp/src/rm_mcuboot_port/`)
- `rm_mcuboot_port.c`: `RM_MCUBOOT_PORT_BootApp()` sets VTOR, handles the dual-bank swap, calls `rm_mcuboot_cleanup()`, then jumps to the app (`start_app`). It disables MSPLIM and the SP monitor first.
- `flash_map.c`: the MCUboot flash backend. It picks the driver by feature macro (MRAM, FLASH_HP, else FLASH_LP). Writes smaller than the write alignment are buffered in RAM when `RM_MCUBOOT_PORT_BUFFERED_WRITE_ENABLE` is set. Flush buffers are indexed by `fa_device_id >> 7` (internal 0, external 1). `g_current_block` is set at runtime, because the bootloader does not run the C scatter loader.
- `.module_descriptions/`: `rm_mcuboot_port`, `rm_mcuboot_protected_mode` (SCE9 crypto), `rm_mcuboot_ext_memory_qspi`, `rm_mcuboot_ext_memory_ospi_b`.
- `!dsn/module.xml`: pack input. The QSPI and OSPI_B modules ship config only.
- `!test/`: unit-test build (`rm_mcuboot_port_test.c`, `rm_mcuboot_port_data.c`, keys, `flash_with_key_*.sh`). `!test_app/`: app-side tests TG1 and TG2. `.xml_tests/`: e2 project-creation tests.

## OSPI_B (RA8)
- Module `config.middleware.mcuboot_ext_memory_ospi_b` generates `mcuboot_ospi_b_config.h` with `RM_MCUBOOT_PORT_CFG_OSPI_B_CHANNEL` and `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE` (32K, 64K, 128K or 256K, default 32K, overridable). The channel must match the added OSPI_B stack.
- `flash_map.c` compiles the external path under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`. The application must call `R_OSPI_B_Open()` before `boot_go()`. The port does not open it.
- Virtual sectors: both slots report the XSPI erase block size, because MCUboot needs equal sector sizes. `flash_area_erase` returns `FSP_ERR_INVALID_SIZE` unless length and address are block multiples.
- Erase sizes the flash supports: S28HL512T 4 KB or 256 KB; IS25LX512M 4, 32, 64 or 128 KB.
- XSPI writes are page-sized. Flush buffer is 256 words.

## `ra8_ospi` project (`projects/rm_mcuboot_port.xml`, around line 2788, active)
- Type `boot`, board `ra8d1_ek`. Crypto: RSIP-E51A plain key with the v3 `rm_psa_crypto` and `ra/arm/mbedtls` (not TF-PSA-Crypto). Heap 0x20000, stack 0x4000.
- `test_info_init` uses `ra/fsp/src/r_ospi_b/!test/SetupOSPI.JLinkScript` to power-cycle the flash before programming.
- Test macros: `FSP_TEST_FUNCTION=RunAllRM_MCUBOOT_PORTTests`, `TEST_MCUBOOT=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`, `..._USE_OSPI_B`, `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE=262144`.
- Tests: TG1 `TC_Vtor` runs only when not OSPI. TG2 (OSPI only, needs `RM_MCUBOOT_PORT_SECONDARY=1`) checks virtual sectors, erase of one or many blocks, partial erase, and rejection of unaligned length and address. Requirement IDs: `mcuboot_port_ospi_*`.
- Test data: `g_ospi_b_cfg` (1S-1S-1S), `rm_mcuboot_port_ospi_test_setup()` (S28HS512T on device 1, CS1). Expect JEDEC ID 0x001A5B34.
- Not ported to v4 (still uses v3 `psa_crypto` paths).

## ra6_qspi (EK-RA6M5, QSPI secondary slot)
Status: owner reported all test cases pass on EK-RA6M5 with the current design (2026-10-09). Build, size and lint checks were run with gcc only. The earlier run failed the two TG2 reject tests (see "Why the reject tests failed").

Current design:
- `projects/rm_mcuboot_port.xml` has a `ra6_qspi` block. `projects/rm_mcuboot_app_qspi.xml` is the app project. The app project is separate because the `ra6m5_ek` entry in `rm_mcuboot_app.xml` is used by `ra6m5_std`. Two `ra6m5_ek` entries in one file collide in SConstruct (verified 2026-10-07).
- `flash_map.c` contains the QSPI table itself, under `#if defined(RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI) && defined(RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI)`. The secondary entry is `FLASH_DEVICE_EXTERNAL_FLASH` at `BSP_PARTITION_QSPI_FLASH_CPU0_S_START` (0x60000000). The `#else` keeps the generated internal map. Both macros are required. Other apps define `..._USE_QSPI=1` without XSPI and must keep the internal map.
- The default `ra6m5` linker folders are unchanged, so the collected-file hash check stays green. `boot_qspi` and `image_qspi` folders are not needed; their `bsp_linker_info.h` copies are never compiled.

Flow (intended):
1. Build the bootloader `ra6_qspi` and the app `rm_mcuboot_app_qspi`. Primary v1.0.0 goes to internal 0x20000. Secondary v1.0.1 is staged at internal 0x40000.
2. `qspi_test_setup_common()` in the bootloader (`!test/rm_mcuboot_port_test.c`) opens QSPI, exits QPI, resets the flash, erases 0x20000, and copies 0x20000 bytes from 0x40000 to QSPI 0x60000000.
3. MCUboot reads the secondary from QSPI through the external flash map entry, verifies EC256, and swaps.
4. The app runs the TG2 tests. Each calls `rm_mcuboot_port_qspi_test_setup()` before `flash_area_open(secondary)`. If the update failed, TG2 reports "Primary app running, expected secondary."

Chip facts (MX25L25645G): the quad-enable bit (status register 1 = 0x40) must be set before Fast Read Quad I/O works. The test setup writes it. Page 256. JEDEC C2 20 19.

Gotchas:
- Do NOT include `r_qspi_test_port.h` in `rm_mcuboot_port_data.c`. It declares a conflicting `g_qspi_extended_cfg`.
- TG2 names use `xspi`. Only `rm_mcuboot_port_ospi_test_setup()` keeps `ospi`.
- Unverified: (1) app `<align>128` vs QSPI page 256 and `MCUBOOT_BOOT_MAX_ALIGN` 128; (2) swap-mode power-loss cases on QSPI (not covered by the test).
- Generated linker info files: a regeneration would drop any XSPI guard. Do not hand-edit them without updating `data/collected-files/ddsc-generated.yml` (see the "Rules" section of `mcuboot-rsip-protected`).

### Why the reject tests failed (2026-10-07)
- `bsp_linker_info.h` (holds `flash_map[]`) is found through the common project-type xml's compile include path, which comes before a project's `<include_dirs>`. Variant linker folders therefore changed only the linker search path, and the compiled map stayed internal. The reject checks only exist on the external path.
- Fix applied: the `flash_map.c` QSPI table above. Verified by gcc build and `objdump` of `flash_map.o` (`.rodata.flash_map`, 12 bytes per entry, device 0x80 external or 0x7f internal). Owner reports the hardware run passes.

### Reading RTT diagnostics (QSPI bring-up)
- No `MCUBOOT-QSPI:` line: the bootloader hung before the copy.
- JEDEC 0x00000000 or 0xFFFFFFFF: the chip does not respond.
- Verify failed: the copy is wrong.
- Verify OK but no `APP-QSPI:` line: the hang is after the bootloader.

### Lint
Run clang-tidy locally before CI: `scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8 --static_analyze=export`, then grep for `warnings-as-errors`. Use named constants, not bare numbers (`readability-magic-numbers`). Do not cast a masked `uint32_t` (`rea-tp-casting`).

## Protected and older QSPI history (for reference)
- `ra6m4_qspi` (boot on `ra6m4_ek`) was removed in `0ae01dcb03b` (2022). Its QSPI macro predates FSPRA-4851.
- `ra6e1_fpb_sce9_protected_ecc` is disabled inside an `<?ignore?>` block. Its boot block has no QSPI macro.
- Active `ra6m4_ek` and `ra6m5_ek` protected entries in `rm_mcuboot_app_protected.xml` set QSPI macros on the app side only. Stale pattern.

## Reports (history, superseded where they conflict with this note)
- `ra6_qspi-ticket-report-2026-10-13.md`, `ra6_qspi-final-report.md`, `ra6_qspi-test-report.md`: full design and verification history.
- `ra6_qspi-linker-evidence.md`: linker experiments E1 to E4.
- `ra6_qspi-tg2-failure-report.md`: first hardware run failure and fix.
- `ra6_qspi-pm-review-report.md`: review of whether the OSPI test is valid for QSPI.
