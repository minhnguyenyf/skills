---
name: mcuboot-port-ospi
description: Notes on ra/fsp/src/rm_mcuboot_port (MCUboot port for RA) and its OSPI_B external-memory support, including the ra8_ospi test project in projects/rm_mcuboot_port.xml. Use when working on rm_mcuboot_port, flash_map.c, OSPI/QSPI secondary slots, MCUboot xml tests, or the ra8_ospi boot test.
---

# rm_mcuboot_port and the `ra8_ospi` test project

## Folder map (`ra/fsp/src/rm_mcuboot_port/`)
- `rm_mcuboot_port.c`: `RM_MCUBOOT_PORT_BootApp()` sets VTOR, handles dual-bank swap (reset or boot-without-reset), calls `rm_mcuboot_cleanup()`, then a naked `start_app(pc, sp)` (MSR MSP; BX). Disables MSPLIM / SP monitor first.
- `flash_map.c`: MCUboot flash backend (`flash_area_open/read/write/erase/align`, `flash_area_get_sector(s)`, flush, cleanup). Picks driver by feature macro: MRAM, FLASH_HP, else FLASH_LP. Internal flash is memory mapped; writes smaller than the write alignment are buffered in RAM and flushed (`RM_MCUBOOT_PORT_BUFFERED_WRITE_ENABLE`, off for plain overwrite-only). Two flush buffers indexed by `fa_device_id >> 7` (internal=0, external=1). Flush-buffer `g_current_block` is set at runtime because the bootloader never runs the C-library scatter loader, so `.data` initializers are not applied.
- `.module_descriptions/`: 4 modules: `rm_mcuboot_port`, `rm_mcuboot_protected_mode` (SCE9 custom crypto in `custom_crypto_stacks/protected_mode/`), `rm_mcuboot_ext_memory_qspi`, `rm_mcuboot_ext_memory_ospi_b`.
- `!dsn/module.xml`: pack-creator input (sources + include folders per module; QSPI and OSPI_B modules ship no files, config only). `!dsn/rm_mcuboot_port_usage_notes.md`: user doc plus internal `@anchor um_mcuboot_port_ospi_*` trace tags.
- `!test/` (dev unit test build: `rm_mcuboot_port_test.c`, `rm_mcuboot_port_data.c`, `.rkey` keys, `flash_with_key_*.sh`), `!test_app/` (app-side tests TG1/TG2, MMF, dual bank, secondary/primary debug images), `.xml_tests/` (e2 studio project-creation tests: encryption, dxip_mmf, dualbank_tz, macros, pqc).

## OSPI_B external memory (RA8)
- Module `config.middleware.mcuboot_ext_memory_ospi_b` generates `mcuboot_ospi_b_config.h` with `RM_MCUBOOT_PORT_CFG_OSPI_B_CHANNEL` and `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE` (options 32K/64K/128K/256K, default 32K; guarded by `#ifndef` so a project macro can override). Constraint: channel must equal the channel of the added OSPI_B stack. It defines `gp_mcuboot_xspi_ctrl/cfg/instance` from the OSPI_B stack name, and sets memory accumulator `BOOTLOADER_SECONDARY_USE_OSPI_B`.
- `flash_map.c` is enabled by `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI` (test project also defines `..._USE_OSPI_B`). The user (or test setup) must call `R_OSPI_B_Open()` before `boot_go()`; the port never opens it. After a secondary image is loaded the target must be reset before MCUboot sees it.
- **Virtual sectors:** MCUboot needs identical sector sizes for both slots, so with XSPI both slots report `RM_MCUBOOT_PORT_VIRTUAL_SECTOR_SIZE = XSPI block erase size`; internal flash erases several native blocks per virtual sector. `flash_area_erase` on the external device returns `FSP_ERR_INVALID_SIZE` unless length and address are multiples of the block size, and polls `statusGet` (huge timeout counter) before/after each erase. Slot sizes must be multiples of that size; the swap scratch area must equal the OSPI erase block (huge), so put scratch in OSPI or use overwrite mode. Erase size must be one the flash supports (S28HL512T: 4KB/256KB; IS25LX512M: 4/32/64/128KB).
- XSPI writes go page by page (`page_size_bytes`), alignment = page size; XSPI flush buffer is 256 words.

## `ra8_ospi` project (`projects/rm_mcuboot_port.xml`, ~line 2788; active, outside every `<?ignore ... ?>` block)
- type `boot`, board `ra8d1_ek`, depends on `rm_mcuboot_app`, crypto = RSIP-E51A plain key with the **v3** `rm_psa_crypto` + `ra/arm/mbedtls` (not TF-PSA-Crypto), `MBEDTLS_CONFIG_FILE=rm_psa_crypto_cfg.h`, littlefs/PSA storage macros on, heap 0x20000, stack 0x4000.
- `test_info_init` points to `ra/fsp/src/r_ospi_b/!test/SetupOSPI.JLinkScript`: `HandleBeforeFlashProg()` power-cycles the OSPI flash (PWR_S toggle and P1_06 reset pulse) because the J-Link loader can't detect it otherwise.
- test macros: `FSP_TEST_FUNCTION=RunAllRM_MCUBOOT_PORTTests`, `TEST_MCUBOOT=1`, `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI/_OSPI_B`, `RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE=262144` (256KB), `OSPI_B_CFG_COMBINATION_FUNCTION=64BYTE`, prefetch on, DOTF off; main macro config adds `OSPI_B_CFG_DMAC_SUPPORT_ENABLE=0`. `r_ospi_b.c` is a main (instrumented) dir.
- Tests (`!test_app/rm_mcuboot_port_tests_*.c`): TG1 runs `TC_Vtor` only when NOT OSPI (skipped with OSPI), plus multi-image if enabled. TG2 (OSPI only, needs `RM_MCUBOOT_PORT_SECONDARY=1`, else `TEST_FAIL_MESSAGE("Primary app running, expected secondary.")`): virtual sectors match physical block, erase one block, erase multiple blocks, partial erase does not over-erase, rejects unaligned length, rejects unaligned address (requirement ids `mcuboot_port_ospi_*`, Jira FSPRA-4851).
- `!test/rm_mcuboot_port_data.c` (OSPI branch, S28HS512T on EK-RA8D1, **device 1 / CS1**): defines `g_ospi_b_cfg` (1S-1S-1S commands) and `rm_mcuboot_port_ospi_test_setup()`: configures OSPI pins, releases CS0, pulses flash RESET# (P1_06) to leave octal/DDR mode, enables OCTACLK from main osc if disabled (else reads return 0xFF), opens OSPI_B once, then reads JEDEC ID into debug globals `g_ospi_jedec_id` (expect 0x001A5B34).

## Gotchas / open observations
- `rm_mcuboot_port` module constraints still reference `config.driver.psa_crypto.*` (v3 ids) for the PLATFORM_MEMORY and MEMORY_BUFFER_ALLOC checks, guarded by `testExists(interface.driver.psa_crypto)`. With the v4 tf_psa_crypto module (provides `interface.driver.tf_psa_crypto`) those checks are skipped, so v4 gets no equivalent check. Not changed.
- `ra8_ospi` has not been ported to v4 (uses v3 psa_crypto paths).
- Primary and secondary images are separate builds of `rm_mcuboot_app`; the `secondary` macro configuration sets `RM_MCUBOOT_PORT_SECONDARY=1`.
