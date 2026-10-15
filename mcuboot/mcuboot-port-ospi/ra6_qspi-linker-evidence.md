# ra6_qspi: evidence for the variant-linker-folder approach (manager's advice) and what makes it work

Date: 2026-10-12. Branch FSPRA-6331_Re-enable_RA6_MCUboot_QSPI, baseline commit 7159690bed5. Build: gcc 13.2 (`/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi`), board ra6m5_ek.
All commands were run by the author on 2026-10-12; raw outputs are pasted below unedited except for trimmed blank lines. Hardware was not used for this experiment (an earlier hardware run is described in `ra6_qspi-tg2-failure-report.md`).

## Question
The manager advised: create separate linker folders for the QSPI test (for example `ra/fsp/src/bsp/mcu/ra6m5/!linker/ac6/image_qspi/bsp_linker_info.h`, no `#ifdef` for `flash_map`), then fix `linker_includes`. Does that give a QSPI secondary slot (`flash_map[]` entry with `FLASH_DEVICE_EXTERNAL_FLASH` at 0x60000000)?

## Method
`flash_map[]` is compiled from `bsp_linker_info.h`. A secondary slot is external only if the compiled table says so. For every experiment: (1) take the exact compile command of `flash_map.c` from the scons build log, run it with `-E -H` to list which `bsp_linker_info.h` the preprocessor opens; (2) decode `.rodata.flash_map` of `flash_map.o` with `arm-none-eabi-objdump -s` (12 bytes per entry: id, device, 2 pad bytes, offset, size; device `7f` internal, `80` external; entry 2 is the secondary slot, bytes `02 xx 00 00 | offset | size`); (3) check the CI collected-file hashes.

## Result summary
| Experiment | What was changed | Header the compiler opened | Compiled secondary slot |
|---|---|---|---|
| E0: guard (`#ifdef`) edited into the 8 default `bsp_linker_info.h` (HEAD) | collected files edited | default folders | external (but 8 of 80 collected-file hashes mismatch, CI fails) |
| E1: manager's advice as written | folders `boot_qspi`/`image_qspi` + `<linker_includes>` only | default `boot` / `image` | **internal 0x40000 (does not work)** |
| E2: E1 + new project types `boot_qspi`/`boot_app_qspi` | `SConstruct` + 2 shared xml; projects switched to the new types | `boot_qspi` / `image_qspi` | **external 0x60000000 (works)** |
| E3: regression, existing `ra6m5_std` | none | default folders | internal 0x40000 (unchanged) |
| E4: collected-file hash check with E2 | default linker files restored to develop | n/a | 80 of 80 match |

## E0: hash check with the guard in the default files (HEAD)
```
E0: collected-file hash check at HEAD (guard in default files)
ra6m5 entries: 80 mismatching: 8
   ra/fsp/src/bsp/mcu/ra6m5/!linker/ac6/boot/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/ac6/image/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/iar/boot/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/iar/image/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/llvm/boot/bsp_linker_info.h
   ra/fsp/src/bsp/mcu/ra6m5/!linker/llvm/image/bsp_linker_info.h
```

## E1: variant folders + linker_includes only
```
E1: manager approach = variant folders (boot_qspi/image_qspi with external flash_map) + <linker_includes>, default folders untouched

--- compile include order for flash_map.c, linker folders only (first found wins):
[rm_mcuboot_app_qspi/ra6m5_ek/gcc/build_rm_mcuboot_app_qspi_secondary_debug]
[rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug]

--- linker search path (-L) for the final link of the secondary app:
-Lra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_qspi
-Lra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image
-Lra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image_qspi

--- compiled flash_map.o, section .rodata.flash_map (12 bytes/entry: id,dev,pad,off,size; dev 7f internal / 80 external):
[rm_mcuboot_app_qspi/ra6m5_ek/gcc/build_rm_mcuboot_app_qspi_secondary_debug]
 0000 017f0000 00000200 00000200 027f0000  ................
 0010 00000400 00000200 037f0000 00000600  ................
 0020 00800000                             ....            
[rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug]
 0000 017f0000 00000200 00000200 027f0000  ................
 0010 00000400 00000200 037f0000 00000600  ................
 0020 00800000                             ....            

--- which bsp_linker_info.h the compiler really opened (gcc -E -H with the exact flags of the build):
[build_rm_mcuboot_app_qspi_secondary_debug]
  linker folders in -I order: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_app', 'ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image']
  opened: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image/bsp_linker_info.h']
[build_rm_mcuboot_port_ra6_qspi_overwrite_debug]
  linker folders in -I order: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot', 'ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot']
  opened: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot/bsp_linker_info.h']
```
Reading: the linker search path (`-L`) does include `boot_qspi`/`image_qspi`, but the compile include order is `boot_app, image` (app) and `boot, boot` (boot) and the preprocessor opened `.../image/bsp_linker_info.h` and `.../boot/bsp_linker_info.h`. Entry 2 of the compiled table is `02 7f 00 00 | 00 00 04 00 | 00 00 02 00`: internal flash, offset 0x40000. Cause: the compile include comes from the shared xml of the project type (`test_files/shared/common_boot.xml`: `.../${CORE_SUBFOLDER}boot`, `common_boot_app.xml`: `.../${CORE_SUBFOLDER}image`); `<linker_includes>` only feeds the linker (`LIBINCPATH`, `SConstruct` ~line 1811); a project's `<include_dirs>` is appended after the shared one.

## E2: new project types (the missing piece)
Changes (uncommitted prototype): `SConstruct` (2 constants, 2 dispatch branches, classes `project_boot_qspi` and `project_boot_app_qspi`, copied from the `boot_multi_images` pattern), new `test_files/shared/common_boot_qspi.xml` and `common_boot_app_qspi.xml` (same as the default shared xml with folder `boot_qspi` / `image_qspi` in both `<include_dirs>` and `<linker_includes>`), `ra6_qspi` uses `<type>boot_qspi</type>`, `rm_mcuboot_app_qspi.xml` uses `<type>boot_app_qspi</type>`, their own `<linker_includes>` removed (the shared xml provides them).
```
E2: new project types boot_qspi / boot_app_qspi (shared xml common_boot_qspi.xml, common_boot_app_qspi.xml; SConstruct classes) + variant folders; default folders untouched

--- which bsp_linker_info.h the compiler really opened (gcc -E -H, exact build flags):
[build_rm_mcuboot_app_qspi_secondary_debug]
  linker folders in -I order: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_app_qspi', 'ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image_qspi']
  opened: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/image_qspi/bsp_linker_info.h']
[build_rm_mcuboot_port_ra6_qspi_overwrite_debug]
  linker folders in -I order: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_qspi', 'ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_qspi']
  opened: ['ra/fsp/src/bsp/mcu/ra6m5/!linker/gcc/boot_qspi/bsp_linker_info.h']

--- compiled flash_map.o (dev 7f internal / 80 external):
[rm_mcuboot_app_qspi/ra6m5_ek/gcc/build_rm_mcuboot_app_qspi_secondary_debug]
 0000 017f0000 00000200 00000200 02800000  ................
 0010 00000060 00000200 037f0000 00000600  ...`............
 0020 00800000                             ....            
[rm_mcuboot_app_qspi/ra6m5_ek/gcc/build_rm_mcuboot_app_qspi_typical_debug]
 0000 017f0000 00000200 00000200 02800000  ................
 0010 00000060 00000200 037f0000 00000600  ...`............
 0020 00800000                             ....            
[rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug]
 0000 017f0000 00000200 00000200 02800000  ................
 0010 00000060 00000200 037f0000 00000600  ...`............
 0020 00800000                             ....            
[rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_typical_debug]
 0000 017f0000 00000200 00000200 02800000  ................
 0010 00000060 00000200 037f0000 00000600  ...`............
 0020 00800000                             ....
```
Reading: the compile include order starts with `boot_app_qspi`/`image_qspi` and `boot_qspi`; the opened headers are the variant ones; entry 2 is `02 80 00 00 | 00 00 00 60 | 00 00 02 00`: external flash, offset 0x60000000, size 0x20000, in the typical and the secondary app and in both bootloader configurations.

## E3 and E4: regression and hash check
```
E3: regression check, existing ra6m5_std (default types, default linker folders)
***   The build rm_mcuboot_port_ra6m5_std_typical:debug:ra6m5_ek:gcc:            SUCCEEDED
***   The build rm_mcuboot_port_ra6m5_std_overwrite:debug:ra6m5_ek:gcc:          SUCCEEDED
***   The build rm_mcuboot_port_ra6m5_std_overwrite_fast:debug:ra6m5_ek:gcc:     SUCCEEDED
***   The build rm_mcuboot_app_typical:debug:ra6m5_ek:gcc:                       SUCCEEDED
***   The build rm_mcuboot_app_secondary:debug:ra6m5_ek:gcc:                     SUCCEEDED
[rm_mcuboot_app/ra6m5_ek/gcc/build_rm_mcuboot_app_secondary_debug] compiled flash_map (expect internal: 02 7f ... 00 00 04 00)
 0000 017f0000 00000200 00000200 027f0000  ................
 0010 00000400 00000200 037f0000 00000600  ................
 0020 00800000                             ....            
[rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6m5_std_typical_debug] compiled flash_map (expect internal: 02 7f ... 00 00 04 00)
 0000 017f0000 00000200 00000200 027f0000  ................
 0010 00000400 00000200 037f0000 00000600  ................
 0020 00800000                             ....            

E4: collected-file hash check (data/collected-files/ddsc-generated.yml), ra6m5 entries:
entries: 80 mismatching: 0

new files are not in the database (not checked): 8 folders
```

## Conclusion
- The manager's idea (own folders for the QSPI test, no `#ifdef`, default collected files untouched) is right; E4 shows it keeps the CI hash check green (80 of 80 match; the new folders are not in the database).
- `<linker_includes>` alone does not make the compiler use the variant `bsp_linker_info.h` (E1). The repo's own mechanism for this is a project type with its own shared xml (as `boot_multi_images`); E2 shows that this makes the variant files effective.
- Existing ra6m5 projects are unaffected (E3).

## Limits and caveats
- gcc only. The linker folders were generated for gcc, ac6, iar and llvm by the same method, but only gcc was built; CI covers the others.
- No hardware run with the E2 build yet. Compiled tables are identical to those of the hardware-tested guard design, so the same behaviour is expected, but this is not proven.
- E2 changes `SConstruct` and adds two shared xml files; this needs the team's agreement. Alternatives: the `flash_map.c` hook (`RM_MCUBOOT_PORT_CFG_FLASH_MAP_HEADER` with a test-only header, no `SConstruct` change) or updating the collected-file hashes (not recommended).
- The variant `bsp_linker_info.h` files are hand-made copies of the generated ones with the secondary entry marked external; a future change to the generated layout of the default files must be mirrored there.

## Reproduce
```
export PATH=/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin:$PATH
scons --build=rm_mcuboot_port --board=ra6m5_ek --project=ra6_qspi --compiler=gcc -j8
# which header was opened: take the arm-none-eabi-gcc command for .../flash_map.o from the log, drop -c and -o, add -E -H -o /dev/null, grep bsp_linker_info.h
arm-none-eabi-objdump -s build/rm_mcuboot_port/ra6m5_ek/gcc/build_rm_mcuboot_port_ra6_qspi_overwrite_debug/ra/fsp/src/rm_mcuboot_port/flash_map.o   # section .rodata.flash_map
```
