# FSPRA-6331 (continues FSPRA-6767): MCUboot QSPI test on EK-RA6M5 (`ra6_qspi`) - review and report

Date: 2026-10-13. Branch `FSPRA-6331_Re-enable_RA6_MCUboot_QSPI`, HEAD `020f08699cc` ("update test"), working tree clean. Merge base with develop: `00e05645564` (2026-10-06). 13 commits on the branch.
Audience: reviewers, the project manager, and engineers who will maintain the MCUboot port tests.
This report replaces the earlier reports in the same folder where they disagree (see section 9).

## 1. Summary
- **What was delivered:** a new boot test `ra6_qspi` (EK-RA6M5) that runs MCUboot with the secondary image slot in the external QSPI flash (Macronix MX25L25645G, 32 MB) and the primary slot in internal flash, plus its app project `rm_mcuboot_app_qspi.xml`. The six erase tests that FSPRA-4851 wrote for OSPI now run for QSPI too (generalised from "OSPI" to "XSPI"). The existing `ra6m5_std` test is untouched.
- **How the secondary slot becomes external (the central point):** `flash_map.c` now defines the `flash_map[]` table itself when both `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI` and `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI` are defined, with the secondary slot as `FLASH_DEVICE_EXTERNAL_FLASH` at 0x60000000. In every other build it still uses the generated table from `bsp_linker_info.h`.
- **Why not the linker files:** the generated `bsp_linker_info.h` files are "collected files" protected by a CI hash check, the compile-time header path cannot be overridden from a project XML, and `SConstruct` was not to be changed (section 5).
- **Verification today (gcc, current HEAD):** all five builds of `ra6_qspi` and `rm_mcuboot_app_qspi` succeed, clang-tidy reports 0 errors, the compiled flash map shows the secondary slot as external in the bootloader and both apps, `ra6m5_std` still compiles the internal map, and all 80 collected-file hashes for ra6m5 match.
- **Not verified by the author:** hardware. The owner reported on 2026-10-09 that all test cases passed (with an earlier variant of the flash-map change that produced the same compiled table). I have not been shown a hardware result for the final HEAD, and a run on 2026-10-12 of an intermediate state failed in the two predicted tests (section 6).
- **Things reviewers should look at:** a board-specific table now lives in the shipped `flash_map.c`; the `boot_qspi` and `image_qspi` linker folders are kept by decision but have no functional effect (section 7).

## 2. Background and problem
| Item | State on develop |
|---|---|
| `ra8_ospi` (EK-RA8D1) | Only external-flash MCUboot test (FSPRA-4851). Its TG2 tests were OSPI-only. |
| Old QSPI boot test `ra6m4_qspi` | Added 2021-11-22 (SWFLEX-3508), deleted 2022-03-31 by `0ae01dcb03b` (a commit about the ra6m4 protected-mode test, so the removal looks like a side effect). Cannot run on current code. |
| `ra6m5_ek` entry in `rm_mcuboot_app.xml` | Defines `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI=1` only. It is the app of `ra6m5_std` (internal-flash secondary). |
| `flash_map.c` | Since FSPRA-4851 the external-flash code is compiled only under `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI`. |
| Generated `flash_map[]` for ra6m5 | Secondary slot is `FLASH_DEVICE_INTERNAL_FLASH` at 0x40000. |
So there was no QSPI test, the leftover QSPI flag selected nothing, and the generated flash map said "internal".

## 3. Final design (what is in HEAD)

### 3.1 Layout
```
internal flash                         QSPI (MX25L25645G)
0x00000  bootloader (mcuboot)          0x60000000  secondary header  (0x200)
0x20000  primary slot                  0x60000200  secondary image   (0x1FE00)
0x40000  staging copy of the secondary             slot size 0x20000 = 4 x 32 KB virtual sectors
0x60000  scratch (0x8000)
```
The 32 KB virtual sector equals the QSPI erase block offered by the module (`block_erase_size` 32 KB), so the slot is a whole number of erase blocks. The trailer lives inside the last sector of the slot.

### 3.2 Test flow
1. Build: boot `ra6_qspi` in three configurations (swap default, `overwrite`, `overwrite_fast`) and the app `rm_mcuboot_app_qspi` in two (typical = primary, v1.0.0; secondary = v1.0.1 with `RM_MCUBOOT_PORT_SECONDARY=1`, signed `--confirm`). EC-256 signing, SCE9 plain-key crypto, v3 `rm_psa_crypto`.
2. Flash through J-Link (`fsp_test_parallel.py`): typical signed srec to internal 0x20000, secondary signed srec to internal 0x40000, bootloader to 0x0. The loader never writes the QSPI chip, so no J-Link script (unlike OSPI).
3. Bootloader start (`test_files/src/r_tests_runner_main.c`, `TEST_MCUBOOT`): `qspi_test_setup_common()` configures the pins, opens QSPI, leaves QPI mode, resets the flash, sets the quad-enable bit, reads the JEDEC id, erases 0x20000 bytes of QSPI, copies the 0x20000-byte image from internal 0x40000 to 0x60000000, waits for the last page program, verifies the copy and logs everything over RTT. Then `boot_go()`.
4. MCUboot reads the primary (internal) and the secondary (QSPI, memory-mapped) through the external `flash_map` entry, verifies the signature, and updates. Overwrite configurations copy the secondary over the primary, then erase the secondary's first and last sector through the QSPI driver; the swap configuration swaps through the internal scratch area.
5. `RM_MCUBOOT_PORT_BootApp` sets VTOR to the primary image, flushes buffers, closes flash and QSPI, jumps.
6. The app (secondary build, now in the primary slot) runs `RunAllRM_MCUBOOT_PORTTests`. TG2 runs `rm_mcuboot_port_qspi_test_setup()` per test and then the six checks (3.4).
- If the update fails, the old typical image runs (`RM_MCUBOOT_PORT_SECONDARY=0`) and TG2 fails with "Primary app running, expected secondary", so a failed update cannot pass silently.

### 3.3 `flash_map.c` (shipped code, +31/-2 lines)
```c
#if defined(RM_MCUBOOT_PORT_CFG_SECONDARY_USE_QSPI) && defined(RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI)
static const struct flash_area flash_map[] =
{
    { .fa_id = FLASH_AREA_0P_ID, .fa_device_id = FLASH_DEVICE_INTERNAL_FLASH,
      .fa_off = BSP_PARTITION___BL_0_P_H_START, .fa_size = BSP_PARTITION___BL_0_P_H_SIZE + BSP_PARTITION_FLASH_CPU0_S_SIZE },
    { .fa_id = FLASH_AREA_0S_ID, .fa_device_id = FLASH_DEVICE_EXTERNAL_FLASH,
      .fa_off = BSP_PARTITION_QSPI_FLASH_CPU0_S_START, .fa_size = BSP_PARTITION___BL_0_S_H_SIZE + BSP_PARTITION___BL_0_S_I_SIZE },
    { .fa_id = FLASH_AREA_S_ID,  .fa_device_id = FLASH_DEVICE_INTERNAL_FLASH,
      .fa_off = BSP_PARTITION___BL_S_START, .fa_size = BSP_PARTITION___BL_S_SIZE },
};
#else
 #define FLASH_MAP_C
 #include "bsp_linker_info.h"
#endif
```
(shown compacted; the committed code is formatted one field per line). Both macros are required on purpose: the `ra6m5_ek` app in `rm_mcuboot_app.xml` and the protected apps define the QSPI macro without the XSPI macro and must keep the generated internal table. The partition macros come from the unmodified generated header, which `sysflash.h` already includes. No other change was made to `flash_map.c`; its external-flash path (virtual sectors, whole-block erase, rejection of unaligned length/address, page writes with a 256-word flush buffer, status polling) already worked for any `spi_flash` driver.

### 3.4 Test code
- **`!test/rm_mcuboot_port_data.c`** (+137): QSPI branch defining the instance the port uses (`g_qspi_ctrl`, `g_qspi_cfg`, `g_qspi`, `gp_mcuboot_xspi_*`: extended SPI, Fast Read Quad I/O, 3-byte addresses, page 256, erase commands 0x20/0x52/0xD8/0xC7) and the new `rm_mcuboot_port_qspi_test_setup()` used by TG2: pins P3_06 CS, P3_05 CLK, P3_07..P3_10 data; open; leave QPI mode (0xF5, written through `SFMCOM` because `DirectWrite` fails when driver and device disagree on the protocol); reset (0x66, 0x99); write the quad-enable bit (write enable 0x06, then write status register 0x01 with SR1 0x40); bounded status wait; read SR1 and the JEDEC id and log them (`APP-QSPI:` RTT lines). It does not copy an image.
- **`!test/rm_mcuboot_port_test.c`** (+96/-11): the bootloader's `qspi_test_setup_common()` extended as in 3.2 step 3 (`MCUBOOT-QSPI:` RTT lines: quad-enable write result and SR1, JEDEC id expected 0x001920C2, erase/write/wait error codes, page count, verify OK/FAILED with the first differing offset, header magic expected 0x96F3B83D). The wait before the memory-mapped read is new.
- **`!test_app/rm_mcuboot_port_tests_tg2.c`** (+66/-57) and **`..._runner.c`** (+3/-3): guards changed from `..._USE_OSPI_B` to `..._USE_XSPI`; TG2 calls `RM_MCUBOOT_PORT_XSPI_TEST_SETUP()` (QSPI or OSPI setup); the `TC_Vtor` skip applies to all XSPI. Renamed OSPI-specific names to XSPI: constants `XSPI_ERASE_TEST_*`, doxygen group, requirement ids `mcuboot_port_xspi_*` and the six `um_mcuboot_port_xspi_*` anchors in `!dsn/rm_mcuboot_port_usage_notes.md`. Only `rm_mcuboot_port_ospi_test_setup()` keeps its OSPI name.
- The six tests (secondary slot, in the app): virtual sectors equal the block size on both slots; erase one block; erase multiple blocks (erase, write 0x5A, erase, expect 0xFF); partial erase must not over-erase (ignored on QSPI because the 32 KB logical sector equals the 32 KB block); reject an unaligned length; reject an unaligned address (data must stay intact). The two reject tests exist only in the external path of `flash_map.c`, so they fail if the secondary is still compiled as internal.
- Code style: named constants instead of magic numbers and a `uint32_t` local for the masked status value, required by the CI clang-tidy (`readability-magic-numbers`, `rea-tp-casting`).

### 3.5 Projects, linker folders, release note
- **`ra6_qspi`** block in `projects/rm_mcuboot_port.xml` (+136), derived from `ra6m5_std`: board `ra6m5_ek`, dependency `rm_mcuboot_app_qspi`, type `boot`, `r_qspi.c` as instrumented code, macros `TEST_MCUBOOT=1`, `..._USE_QSPI=1`, `..._USE_XSPI`, `..._XSPI_BLOCK_ERASE_SIZE=32768`, `FSP_TEST_FUNCTION=RunAllRM_MCUBOOT_PORTTests`, the same three main-macro configurations as `ra6m5_std`, `<linker_includes>` pointing at `boot_qspi`.
- **`projects/rm_mcuboot_app_qspi.xml`** (new, +69): app for `ra6m5_ek`, primary slot 0x20000, secondary slot 0x40000 (staging address), slot size 0x20000, `align 128`, four sectors, EC-256 key, the same QSPI/XSPI macros, `<linker_includes>` pointing at `image_qspi`. It is a separate file because the build system finds a boot project's app by XML file name, board and toolchain (`SConstruct _add_dependency`), not by project name: a second `ra6m5_ek` entry in `rm_mcuboot_app.xml` makes scons stop ("Two environments with different actions were specified for the same target") and overwriting the existing entry would break `ra6m5_std`.
- **Linker folders** `ra/fsp/src/bsp/mcu/ra6m5/!linker/{gcc,ac6,iar,llvm}/{boot_qspi,image_qspi}` (32 files in 8 folders): copies of the default `boot`/`image` folders whose `bsp_linker_info.h` has the secondary partition macros at 0x60000000/0x60000200 and the secondary `flash_map` entry marked external. `memory_regions.*`, `fsp_gen.*` and `bsp_mcu_ofs_cfg.h` are byte-identical to the defaults in all 8 folders (checked with `cmp`), and `bsp_linker_info.h` differs in 3 lines (two partition macros and the secondary device type). See 7.2 for their actual effect.
- **Release note** `documents/release_notes/upcoming/FSPRA-6331.yml` (internal, MCU RA6M5, "Re-enabled MCUboot QSPI test for RA6M5").

## 4. Verification on HEAD `020f08699cc` (gcc 13.2, run 2026-10-13)
| Check | Result |
|---|---|
| `scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc` with `--static_analyze=export` | exit 0; 5 builds succeed (`ra6_qspi` typical/overwrite/overwrite_fast, `rm_mcuboot_app_qspi` typical/secondary); clang-tidy 0 errors |
| Compiled `flash_map` (decoded from `flash_map.o`, section `.rodata.flash_map`, 12 bytes per entry, device `7f` internal / `80` external) | secondary entry is `02 80 00 00 \| 00 00 00 60 \| 00 00 02 00` (external, 0x60000000, size 0x20000) in the secondary app, the typical app and all three bootloader configurations |
| Regression `ra6m5_std` build | exit 0; its app and bootloader still show `02 7f .. \| 00 00 04 00` (internal, 0x40000) |
| CI collected-file check (`data/collected-files/ddsc-generated.yml`) | 80 of 80 ra6m5 linker entries match; default linker files equal develop |
| Bootloader size | 67 240 bytes of code, inside the 0x20000 bootloader region |
| ac6, iar, llvm | not built for the final HEAD (an llvm bootloader link was built earlier on an intermediate state); left to CI |
| Hardware | owner reported all test cases passing on 2026-10-09 (earlier variant, same compiled table); no result shown for HEAD |

## 5. Constraints found (and why the design is what it is)
1. **`flash_map[]` is compiled from the default `bsp_linker_info.h`.** The compile include path comes from the shared project-type XML (`test_files/shared/common_boot.xml` -> `.../boot`, `common_boot_app.xml` -> `.../image`). A project's `<linker_includes>` only changes the linker search path (`LIBINCPATH`), and a project's `<include_dirs>` is appended after the shared ones, so variant folders cannot override it. The project XML has no tag that adds C compiler flags (`custom_cxx_flags` is C++ only).
2. **The generated linker files are collected files.** `scripts/pipeline/check_collected_files.sh` compares each file's SHA-256 against `data/collected-files/ddsc-generated.yml` (stage 1 rejects manual edits, stage 2 compares freshly collected files). The files come from the FSP configurator through the templates in `scripts/mcu_xml_gen/templates/linker_macros_bsp_h.j2` and are collected by `scripts/xml_testing/templates/linker_collect.yml.j2`; the `flash_map` device type follows the partition location defined in the solution. Hand-editing them fails the CI check and is overwritten on the next collection. (The ra8d1 OSPI linker files are not in that database, which is why the OSPI change was not affected.)
3. **No change to `SConstruct` or the shared project-type XML was allowed.** The repo-native way to select variant folders is a new project type with its own shared XML (as `boot_multi_images`). A prototype of that (new `boot_qspi`/`boot_app_qspi` types) worked locally and was reverted by decision.
4. Therefore the only place left to select the QSPI map without touching those is the port source itself, which is what HEAD does.

## 6. History of the ticket (what was tried, evidence, outcome)
| Step | Change | Result / evidence |
|---|---|---|
| 1 (10-07) | Variant linker folders + `<linker_includes>`, new app XML, XSPI generalisation of TG2, QSPI setup in data.c, project `ra6_qspi` | First hardware run: `TC_Erase_Rejects_Unaligned_Length` and `..._Address` failed ("Expected Not-Equal"). Root cause: compiled `flash_map` was internal, the folders reach only the linker (reproduced locally with `-E -H` and the decoded table). |
| 2 (10-07/09) | Guard `#ifdef ..._USE_XSPI` inside the 8 default `bsp_linker_info.h` files | Compiled map became external. First attempt hung on hardware (cause not determined; the guard in the bootloader file alone cannot work because TG2 runs in the app). With the guard in boot and image files, the quad-enable write, a status wait before the first memory-mapped read and the app linker regions back to internal, the owner reported all tests passing (2026-10-09). |
| 3 (10-09) | RTT diagnostics (JEDEC id, quad-enable, erase/write/verify), quad-enable write for the MX25L25645G (non-volatile bit SR1 0x40, which the repo's own r_qspi test also sets in every test case) | Builds; lint fixes for CI clang-tidy (named constants, one redundant cast). |
| 4 (10-09) | CI `check_collected_files.sh` failed for the 8 edited files (hash mismatch) | Guard design rejected by the CI rule (section 5.2). |
| 5 (10-10..12) | `flash_map.c` hook header experiment; manager's advice (separate linker folders, no `#ifdef`); evidence run | Folder-only design reproduces the failure (E1: internal map); folders + new project types work (E2) but need `SConstruct`; reverted per decision. Raw evidence: `ra6_qspi-linker-evidence.md`. |
| 6 (10-12) | Folder-only design committed (`a4af46b9056`); hardware run: the same two reject tests failed again (as predicted) | Table defined inside `flash_map.c` (this report, section 3.3), no new file, no macro. |
| 7 (10-13) | `020f08699cc` "update test" | Final state; re-verified in section 4. |
Lessons recorded in the skill: check the actual `-I` order with `scons -n` before assuming an XML tag overrides a header; decode `flash_map.o` instead of trusting file contents or size; never hand-edit files listed in `ddsc-generated.yml`.

## 7. Risks, limitations, open items
1. **Board-specific table in shipped code.** `flash_map.c` now contains a table that needs ra6m5's `BSP_PARTITION_*` macros; it is compiled only when both macros are defined, so no existing project is affected (verified for `ra6m5_std`). If a reviewer objects, the alternatives are a new project type (needs `SConstruct`) or a test-only header selected by a macro (verified earlier, hook design).
2. **The `boot_qspi` and `image_qspi` folders have no functional effect.** Their `memory_regions.*` and `fsp_gen.*` equal the defaults, and their `bsp_linker_info.h` is never compiled (the compiler opens the default header); a build with and without them gave identical section addresses and sizes (only unused symbol values differed). They are kept by decision and referenced by `<linker_includes>`, and two XML comments still describe them as selecting the QSPI map; the real mechanism is section 3.3.
3. **Delivery is simulated.** The image reaches QSPI through the bootloader's copy, not a real download. A J-Link-direct load (secondary slot at 0x60000000 like `ra8_ospi`) is a possible follow-up (the r_qspi tests set `QSPI_TEST_DEBUGGER_DOWNLOAD=1` for this board, so it looks feasible).
4. **Hang seen once on hardware, cause undetermined.** Candidates: the missing quad-enable write and the missing wait before the first memory-mapped read (both fixed), or the app linker regions. Not isolated; if it returns, halt after the timeout and read the PC and call stack.
5. **Alignment:** app `<align>128` (HP flash write size / `MCUBOOT_BOOT_MAX_ALIGN`) versus QSPI page size 256; no problem was reported in the passing run, not analysed in depth.
6. **Coverage gaps:** one of six TG2 tests is ignored on QSPI; `TC_Vtor` (end-to-end vector table check, which the old `ra6m4_qspi` test had) is skipped for XSPI; no automated check of the `MCUBOOT-QSPI` RTT lines; swap mode is exercised but not power-loss cases.
7. **Compilers:** only gcc was built for the final HEAD; ac6, iar and llvm rely on CI.
8. **Maintenance:** the QSPI table duplicates the generated partition layout. If the generated macro names or values change (for example after a solution change), `flash_map.c` fails to compile (detectable), but the values must be reviewed.

## 8. Suggested follow-ups
1. Re-run the final HEAD on EK-RA6M5 and attach the RTT lines (`MCUBOOT-QSPI:` and `APP-QSPI:`; expect JEDEC 0x001920C2, SR1 with bit 0x40, `verify OK`, header magic 0x96F3B83D).
2. Decide whether to keep the unused linker folders or remove them and their `<linker_includes>` (cleaner, no behaviour change).
3. Restore an end-to-end check for QSPI (`TC_Vtor` or equivalent) as the old test had.
4. Consider the J-Link-direct load and, if the team wants variant linker folders to be real, a project type in `SConstruct`.
5. Ask whoever owns `data/collected-files/` whether a solution-based QSPI partition (generated, hashed) is preferred for the long term.

## 9. Related notes (skill `mcuboot-port-ospi`) and what is outdated
`SKILL.md` (state log, evidence, history commands), `ra6_qspi-linker-evidence.md` (E0-E4 raw outputs of the folder/project-type experiments), `ra6_qspi-tg2-failure-report.md` (root cause of the first failure), `ra6_qspi-pm-review-report.md` (OSPI validity, old vs new test), `ra6_qspi-final-report.md` and `ra6_qspi-test-report.md` (earlier design reports). Outdated: those older reports describe an XSPI guard in the default linker files, a header/macro hook, or linker folders as the selection mechanism; the current mechanism is section 3.3 of this report.

## 10. Reproduce
```
export PATH=/opt/clang-tidy/bin:/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH
scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8 --static_analyze=export > log 2>&1
grep -E "error: .*warnings-as-errors" log | sort -u                       # no lines = lint clean
arm-none-eabi-objdump -s build/rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug/ra/fsp/src/rm_mcuboot_port/flash_map.o   # .rodata.flash_map
# collected-file check: compare sha256 of the ra6m5 linker files with data/collected-files/ddsc-generated.yml (or run scripts/pipeline/check_collected_files.sh)
```
