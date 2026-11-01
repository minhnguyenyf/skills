# ra6_qspi: evidence for the linker-folder approach (2026-10-12)

Status: compacted 2026-11-01. The design chosen after these experiments is in `ra6_qspi-final-report.md`. Gcc 13.2, board ra6m5_ek, no hardware in these experiments.

## Method
- `flash_map[]` is compiled from `bsp_linker_info.h`. Find which header the compiler opens with `gcc -E -H` using the exact flags from the build log.
- Decode `.rodata.flash_map` from `flash_map.o` with `arm-none-eabi-objdump -s`. 12 bytes per entry. Device `7f` internal, `80` external. Entry 2 is the secondary slot.
- Check the collected-file hashes in `data/collected-files/ddsc-generated.yml`.

## Results
| Experiment | Change | Header opened | Secondary slot |
|---|---|---|---|
| E0 | `#ifdef` guard in the 8 default `bsp_linker_info.h` | default | external, but 8 of 80 hashes mismatch (CI fails) |
| E1 | variant folders `boot_qspi`/`image_qspi` plus `<linker_includes>` only | default `boot`/`image` | internal 0x40000 (does not work) |
| E2 | E1 plus new project types `boot_qspi`/`boot_app_qspi` (SConstruct and shared xml) | variant folders | external 0x60000000 (works) |
| E3 | regression, existing `ra6m5_std` | default | internal (unchanged) |
| E4 | hash check with E2 | n/a | 80 of 80 match |

## Why E1 failed
- The linker search path (`-L`) includes the variant folders. The compile include order does not. It comes from the shared xml of the project type (`common_boot.xml` and `common_boot_app.xml`). `<linker_includes>` only feeds the linker. A project's `<include_dirs>` is appended after the shared one.

## Why E2 works
- New project types have their own shared xml, so the compile include order starts with the variant folders. The compiled table then has the external secondary entry in the typical and secondary apps and in both bootloader configurations.

## Conclusion
- Separate folders with no `#ifdef` leave the default collected files untouched. The hash check stays green (E4).
- `<linker_includes>` alone does not change the compiled header.
- Existing ra6m5 projects are unaffected (E3).

## Caveats
- Gcc only. Other compilers were not built.
- E2 needs `SConstruct` changes and two shared xml files. The team did not accept that in this form. The final design uses the `flash_map.c` hook instead.
- The variant `bsp_linker_info.h` files were hand-made copies of the generated ones. They must follow any future change to the default layout.
