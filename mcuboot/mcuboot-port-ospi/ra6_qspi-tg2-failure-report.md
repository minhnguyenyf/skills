# ra6_qspi TG2 failure (2026-10-07): "Expected Not-Equal" in the unaligned-erase tests

Status: compacted 2026-11-01. Root cause found and fixed in the design (see `ra6_qspi-final-report.md`). Owner later reported the tests passing.

## Symptom
- `TC_Erase_Rejects_Unaligned_Length` and `TC_Erase_Rejects_Unaligned_Address` failed ("Expected Not-Equal"). `flash_area_erase()` returned 0 for an unaligned request.
- The other TG2 tests passed on either flash path, so the two reject tests were the clue.

## Root cause
- The reject checks exist only on the external-flash path of `flash_map.c` (`FSP_ERR_INVALID_SIZE` for unaligned length or address). The internal path accepts them.
- The secondary slot was compiled as internal flash. `flash_map[]` comes from `bsp_linker_info.h` through the compile include path set by the common project-type XML. A project's `<linker_includes>` changes only the linker path. A project's `<include_dirs>` is appended after the common one, so the default folder won.
- Variant linker folders therefore had no effect on the compiled table.

## Fix
- `flash_map.c` QSPI table selected by the QSPI and XSPI macros (see the final report). Verified with `objdump` of `flash_map.o`: the secondary entry is external at 0x60000000 in the QSPI builds, and internal at 0x40000 in `rm_mcuboot_app` used by `ra6m5_std`.

## Lessons
- A tag named like "linker includes" does not change the compile-time header lookup. Check the real `-I` order with `scons -n`.
- If only the "reject" cases fail, check which code path the device takes before suspecting the test.
- Verify from the compiled artifact (dump `flash_map`), not from file contents or build size.
- Build size only showed the XSPI buffers were present. It did not prove the external map was used.
