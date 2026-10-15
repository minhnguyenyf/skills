# ra6_qspi TG2 failure report: "Expected Not-Equal" in the unaligned-erase tests

Date: 2026-10-07. Board: EK-RA6M5. Project: `ra6_qspi` (secondary slot intended in QSPI).
Status: **root cause found, fix applied and verified at the build/binary level, not yet re-run on hardware.**

## 1. Symptom
Reported from the test run (Unity output via `fsp_test_parallel`):
```
TEST(RM_MCUBOOT_PORT_TG2, TC_Erase_Rejects_Unaligned_Length)  rm_mcuboot_port_tests_tg2.c:246: FAIL: Expected Not-Equal
TEST(RM_MCUBOOT_PORT_TG2, TC_Erase_Rejects_Unaligned_Address) rm_mcuboot_port_tests_tg2.c:269: FAIL: Expected Not-Equal
```
Later report: the same assert at line 247 (the line moved by one after a comment edit; same test). No other TG2 failure was reported (the logs shown contained only these lines, so "the other tests passed" is an inference, not something seen in a full log).

The failing statements:
```c
TEST_ASSERT_NOT_EQUAL(0, flash_area_erase(gp_secondary_area, 0U,    XSPI_ERASE_TEST_LOGICAL_SIZE - 1U)); /* length test  */
TEST_ASSERT_NOT_EQUAL(0, flash_area_erase(gp_secondary_area, 4096U, XSPI_ERASE_TEST_LOGICAL_SIZE));      /* address test */
```
i.e. `flash_area_erase()` returned 0 (success) for an unaligned request instead of an error.

## 2. Where the rejection lives
`ra/fsp/src/rm_mcuboot_port/flash_map.c`, `flash_area_erase()`:
- **External device** (`fa_device_id != FLASH_DEVICE_INTERNAL_FLASH`), compiled only under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`: returns `FSP_ERR_INVALID_SIZE` when `len % RM_MCUBOOT_PORT_CFG_XSPI_BLOCK_ERASE_SIZE != 0` or `erase_address % ... != 0`.
- **Internal device**: computes how many native flash blocks to erase (rounding up) and calls `R_FLASH_Erase`; it does **not** reject unaligned lengths or offsets and returns 0.
So these two tests can only pass if the secondary slot is an external-flash area.

## 3. Root cause
The secondary slot was compiled as an **internal** flash area, not QSPI.
- `flash_map[]` (which area is internal/external, and its address) is defined in `bsp_linker_info.h` under `#ifdef FLASH_MAP_C`, included by `flash_map.c`.
- The compile-time include path for that header is set by the shared xml of the project type: `test_files/shared/common_boot.xml` -> `ra/fsp/src/bsp/mcu/${MCU}/!linker/${COMPILER}/${CORE_SUBFOLDER}boot`, and `common_boot_app.xml` -> `.../image`.
- My design added `boot_qspi`/`image_qspi` folders (with an external secondary entry) and selected them with the project `<linker_includes>`. That tag only feeds the **linker** search path (`LIBINCPATH`, `SConstruct` ~line 1811). A project `<include_dirs>` entry is appended **after** the common one, so the default folder always wins. `scons -n` showed the compile order `boot_app`, `image`, `image_qspi`; even adding the variant to `<include_dirs>` did not change which `bsp_linker_info.h` was used (that experiment was reverted).
- Result: both the bootloader and the app used the default ra6m5 map: secondary = `FLASH_DEVICE_INTERNAL_FLASH` at 0x40000. QSPI was opened and written (by the boot test hook), but MCUboot and `flash_area_erase()` treated the secondary as internal flash, whose erase path accepts unaligned requests. Hence "Expected Not-Equal".

## 4. Why the other TG2 tests did not fail
They pass on either path: virtual sectors are 32 KB on both slots, erase one/multiple blocks and read back 0xFF work on internal flash too, and the partial-erase test is ignored (32 KB logical equals the 32 KB physical block). Only the two "reject" tests depend on the external-only checks. This failure pattern was itself the clue.

## 5. Statements from earlier in this work that were wrong
- "It uses QSPI as the secondary slot by design" held only for the intended layout; the build did not implement it.
- The build-size evidence (flash_map.o bss 1154 bytes) only showed the XSPI write buffers were compiled in, not that the external map was used.
- The flow in the main report (secondary read from 0x60000000, QSPI erases after overwrite) did not happen in the run that failed; the secondary was read from internal 0x40000.

## 6. Why existing variants did not hit this
`mmf`/`xip` variants only change linker addresses; their flash map stays the default. `boot_multi_images`/`primary_core` are separate project types with their own shared xml, so their include path and linker path both change. ra8d1's OSPI support rewrote the default `boot`/`image` folders. A QSPI-only variant of the default ra6m5 folders had no mechanism to affect the compile path.

## 7. Fix applied
In the 8 default files `ra/fsp/src/bsp/mcu/ra6m5/!linker/{gcc,ac6,iar,llvm}/{boot,image}/bsp_linker_info.h`, the `FLASH_AREA_0S_ID` entry is now:
```c
#ifdef RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI
    .fa_device_id = FLASH_DEVICE_EXTERNAL_FLASH,
    .fa_off       = BSP_PARTITION_QSPI_FLASH_CPU0_S_START,   /* 0x60000000 */
#else
    .fa_device_id = FLASH_DEVICE_INTERNAL_FLASH,
    .fa_off       = BSP_PARTITION___BL_0_S_H_START,
#endif
```
Only the two QSPI projects (`ra6_qspi`, `rm_mcuboot_app_qspi.xml`) define `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`, so other ra6m5 projects are unchanged. The linker side keeps using the `boot_qspi`/`image_qspi` memory regions. No change to `SConstruct` or shared xml.
Alternatives not taken: new project types `boot_qspi`/`boot_app_qspi` (repo-native, shared build script change); rewriting the default folders to QSPI (breaks `ra6m5_std`); selecting the map inside `flash_map.c` (production code change).

## 8. Verification done (gcc, 2026-10-07)
Method: `arm-none-eabi-objdump -s .../flash_map.o`, section `.rodata.flash_map`, 12 bytes per entry (`fa_id`, `fa_device_id`, 2 pad, `fa_off`, `fa_size`; device `0x7f` internal, `0x80` external).
| Object | Secondary entry (`02 ..`) |
|---|---|
| secondary app (`rm_mcuboot_app_qspi`) | `02 80 00 00 00 00 00 60 00 00 02 00` external, 0x60000000, size 0x20000 |
| typical app (`rm_mcuboot_app_qspi`) | same |
| boot `ra6_qspi` typical and overwrite | same |
| `rm_mcuboot_app` (used by `ra6m5_std`) | `02 7f 00 00 00 00 04 00 ...` internal, 0x40000 (unchanged) |
`scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc` and `--build=rm_mcuboot_app_qspi` finish with exit 0. ac6, iar and llvm were not built.

## 9. Still to do
1. Re-run on EK-RA6M5 with a clean rebuild of both `rm_mcuboot_app_qspi` and `ra6_qspi`; both reject tests should pass.
2. Expect new behaviour: the QSPI erase/write path is now really used by MCUboot, so the earlier risks become testable: write alignment 128 vs page 256 (`MCUBOOT_BOOT_MAX_ALIGN`), quad-enable bit, swap-mode trailer writes.
3. Build ac6/iar/llvm (the guard was applied to all four).
4. Decide whether hand-editing the generated linker info files is acceptable; a regeneration would silently drop the guard (then the same failure returns).
5. Other tests/projects on ra6m5 that define the XSPI macro with the default folders would also get the external map; none exist today.

## 10. Lessons
- A project xml tag that sounds like "linker includes" does not change the compile-time header lookup; check the actual `-I` order with `scons -n` before assuming an override works.
- When a test only fails in the "reject" cases, check which code path the device takes before suspecting the test.
- Verify behaviour from the compiled artifact (dump `flash_map`), not from file contents or build size.
