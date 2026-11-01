# ra6_qspi test report (EK-RA6M5, QSPI secondary slot)

Status: compacted 2026-11-01. Superseded by `ra6_qspi-final-report.md` (2026-10-09). Keep this file for the decision record and the bootloader-copy versus J-Link comparison.

## Purpose
MCUboot on EK-RA6M5 with the secondary slot in external QSPI (MX25L25645G, 32 MB) and the primary in internal flash. The comparable test is `ra8_ospi` (OSPI, EK-RA8D1).

## Decision record: why the QSPI app is a separate file
- Overwriting the `ra6m5_ek` entry in `rm_mcuboot_app.xml` breaks `ra6m5_std`.
- A second `ra6m5_ek` block in the same file makes scons fail: "Two environments with different actions were specified for the same target" (checked with `scons -n`).
- A named second block builds, but `SConstruct _add_dependency` finds the app by file name only, so `ra6_qspi` would flash `ra6m5_std`'s app.
- Result: `projects/rm_mcuboot_app_qspi.xml` is a separate file. Option "change SConstruct" was not taken.

## Layout
- Primary internal 0x20000 (v1.0.0). Staging copy internal 0x40000. Scratch internal 0x60000 (0x8000).
- Secondary QSPI 0x60000000. Header 0x200, image 0x1FE00. Slot 0x20000 = 4 x 32 KB virtual sectors.
- The secondary entry in `flash_map` must be external. That is what the final design sets.

## Build and flash
- Boot `ra6_qspi`: swap default, `overwrite`, `overwrite_fast`. App: typical (v1.0.0) and secondary (v1.0.1, `RM_MCUBOOT_PORT_SECONDARY=1`, `--confirm`).
- Flash: typical to 0x20000, secondary to 0x40000 (staging), bootloader to 0x0. No J-Link script, because the loader does not write QSPI.

## Boot flow (bootloader copy)
1. `qspi_test_setup_common()` opens QSPI, exits QPI, resets the flash, erases 0x20000, copies 0x20000 bytes from internal 0x40000 to 0x60000000.
2. MCUboot reads both slots, verifies EC256, and updates. Overwrite copies secondary over primary. Swap uses the internal scratch area.
3. The app runs TG2 on the secondary. If the update failed, TG2 reports "Primary app running, expected secondary".

## Bootloader copy versus J-Link direct load
| | Bootloader copy (chosen first) | J-Link direct (like `ra8_ospi`) |
|---|---|---|
| App `secondary_slot` | 0x40000 internal | 0x60000000 QSPI |
| QSPI written by | boot hook | flash loader from the srec |
| Needs QSPI loader or script | no | yes |
| Weakness | test data prepared by the driver under test | depends on loader and chip state |
| Change cost | none | boot flow change in shared `r_tests_runner_main.c` |

Recommendation at the time: first run with the bootloader copy, then J-Link direct for the closer-to-real test.

## Open risks (as of 2026-10-07)
1. Alignment: app `<align>128` and `MCUBOOT_BOOT_MAX_ALIGN` 128 versus QSPI page 256 and `flash_area_align()` 256. Possible MCUboot assertion, mainly in swap mode.
2. Quad-enable bit assumed set. Later code writes and checks it.
3. Swap mode with QSPI trailer writes was untested.
4. Whether the loader can program this QSPI chip is unverified.
5. `ra6m5_ek` is already in the `rm_mcuboot_port` pipeline entry, so the test runs in CI.
6. TG2 names renamed `ospi` to `xspi`. The erase-test doc text still describes the 32 KB logical sector.

## Build status (2026-10-07)
- gcc build of the app typical and secondary: succeeded.
- gcc link of the boot project: blocked at the time by a submodule mismatch (`shake_alt.c` needs `mbedtls/shake.h`). Not caused by this work. Submodules were not changed.
- ac6, iar and llvm: not tried at the time. Later checks are in the final report.
- Build recipe: `scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8` (`-n` for a dry run).
