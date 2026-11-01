# FSPRA-6331 / FSPRA-6767: MCUboot QSPI test on EK-RA6M5 (`ra6_qspi`), status 2026-10-13

Status: compacted 2026-11-01. This was the last state report. Design details are in `ra6_qspi-final-report.md`. Raw experiment outputs are in `ra6_qspi-linker-evidence.md`.

## What is delivered (branch `FSPRA-6331_Re-enable_RA6_MCUboot_QSPI`, HEAD `020f08699cc`)
- Boot test `ra6_qspi` (EK-RA6M5) and app `rm_mcuboot_app_qspi.xml`. Secondary slot in external QSPI (MX25L25645G, 32 MB), primary in internal flash.
- The six TG2 erase tests run for QSPI too (renamed from OSPI to XSPI). `ra6m5_std` is unchanged.
- The secondary slot is external because `flash_map.c` defines the table itself when `..._USE_QSPI` and `..._USE_XSPI` are both set. All other builds keep the generated table.

## Verification (gcc, HEAD)
- All five builds of `ra6_qspi` and `rm_mcuboot_app_qspi` succeed.
- clang-tidy: 0 errors.
- Compiled flash map: secondary external in the bootloader and both apps. `ra6m5_std` stays internal.
- All 80 ra6m5 collected-file hashes match.
- Not verified by the author: hardware. The owner reported all tests passing on 2026-10-09. The 2026-10-12 intermediate run had the two reject tests failing, as predicted before the flash-map fix.

## History (short)
1. 10-07: variant linker folders plus `<linker_includes>`. Hardware: two reject tests failed. Cause: the compiled flash map was internal.
2. 10-07 to 10-09: guard in the 8 default `bsp_linker_info.h` files. First attempt hung on hardware (cause not isolated). Quad-enable write and a status wait were added. RTT diagnostics were added.
3. 10-09: CI hash check failed for the 8 edited files. The guard was rejected.
4. 10-10 to 10-12: `flash_map.c` hook and evidence runs. Folder-only design reproduces the failure. Folders plus new project types work, but need `SConstruct` changes. The team chose the `flash_map.c` table.
5. 10-12 to 10-13: final design committed. The same two reject tests failed on the intermediate state.

Lessons: check the real `-I` order with `scons -n` before assuming an XML tag overrides a header. Decode `flash_map.o` instead of trusting file contents or size. Never hand-edit files listed in `ddsc-generated.yml`.

## Open risks
1. Board-specific table in shipped `flash_map.c`. Compiled only when both macros are set, so no other project is affected.
2. The `boot_qspi` and `image_qspi` linker folders have no functional effect. Their `bsp_linker_info.h` is never compiled. The 10-13 report says they are kept and referenced by `<linker_includes>`. The final report says they were removed (commit `ad4251fd329`). Check git to confirm the current state.
3. Delivery is simulated. The bootloader copies the image into QSPI.
4. One hang on hardware, cause not isolated. If it returns, halt after the timeout and read PC and call stack.
5. Alignment: app `<align>128` versus QSPI page 256.
6. Coverage gaps: one of six TG2 tests is ignored on QSPI. `TC_Vtor` is skipped for XSPI, so the end-to-end check from the old `ra6m4_qspi` test is gone. Swap power-loss cases are not tested. The RTT lines are not checked automatically.
7. Only gcc was built for HEAD. ac6, iar and llvm rely on CI.
8. The QSPI table duplicates the generated partition layout. A changed macro name fails the build, but a changed value needs review.

## Follow-ups
1. Run HEAD on EK-RA6M5. Attach the RTT lines: JEDEC `0x001920C2`, SR1 with bit `0x40`, `verify OK`, header magic `0x96F3B83D`.
2. Decide whether to keep or remove the unused linker folders and their `<linker_includes>`.
3. Restore an end-to-end check for QSPI.
4. Consider a J-Link direct load (secondary at 0x60000000, as `ra8_ospi`).
5. Ask the owner of `data/collected-files/` whether a generated, hashed QSPI partition is preferred long term.

## Reproduce
```
export PATH=/opt/clang-tidy/bin:/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH
scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8 --static_analyze=export > log 2>&1
grep -E "error: .*warnings-as-errors" log | sort -u    # no lines = lint clean
arm-none-eabi-objdump -s build/rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug/ra/fsp/src/rm_mcuboot_port/flash_map.o
```
