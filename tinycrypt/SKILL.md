---
name: tinycrypt
description: TinyCrypt port (rm_tinycrypt_port) notes: API names, deprecated RM_TINCYRYPT_PORT_* wrappers, TRNG, and their tests and usage notes. Read before changing rm_tinycrypt_port names, adding a test, or writing a release note for it.
---

# TinyCrypt port (rm_tinycrypt_port)

## Status
- Branch `FSPRA-6430_Correct_rm_tinycrypt_port_API_names`: new names in use, old names kept as deprecated wrappers. Not yet built with real BSP headers (not in the repo). Compat test not yet run on hardware.
- Release note: `documents/release_notes/upcoming/FSPRA-6430.yml`, category 4 (Deprecations).

## API names
- Typo fixed: `RM_TINCYRYPT_PORT_Init` / `RM_TINCYRYPT_PORT_TRNG_Read` are now `RM_TINYCRYPT_PORT_Init` / `RM_TINYCRYPT_PORT_TRNG_Read`.
- Old names still exist as wrapper functions in `ra/fsp/src/rm_tinycrypt_port/rm_tinycrypt_port.c` (end of file, after the group end comment). They call the new names, so already-linked code still works.
- Declared in `ra/fsp/inc/instances/rm_tinycrypt_port.h` and `ra/fsp/src/rm_tinycrypt_port/inc/rm_tinycrypt_port.h`, marked `// [DEPRECATED]`. Same style as LIN (`r_sci_lin.h`).

## Decision: no compiler deprecation attribute
- A `__attribute__((deprecated))` macro was tried and removed. `test_files/shared/tools.yml` sets `-Werror` in `fsp_flags` for GCC, LLVM, and another toolchain, so any call to an old name failed the build.
- LIN (FSPRA-4333) uses comments only. Follow that pattern.

## Tests and docs
- Compat test: `TC_API_TestDeprecatedNames` in `ra/fsp/src/rm_tinycrypt_port/!test/rm_tinycrypt_port_tests_tg1.c`, registered in `rm_tinycrypt_port_tests_runner.c`. Tags: `@req{tc_deprecated_names,FSPRA-6430,...}` and `@verify{tc_deprecated_names}`.
- Usage note: `!dsn/rm_tinycrypt_port_usage_notes.md`, section "Deprecated API Names", anchor `um_tc_deprecated_names`.
- Other tests, runner, example, and MCUboot port use the new names.

## Files that mention the old names
- Test runner `test_files/src/r_tests_runner_main.c` (line ~501), uses the new name.
- Test project `/home/coder/e2_studio/workspace/tinycrypt_api_test/src/hal_entry.c` calls the old names on purpose to check the wrappers link (no `-Werror` in that project).

## Open
- Build the pack with the real BSP headers and confirm the wrappers link.
- The editor sometimes saved an old copy of `rm_tinycrypt_port.c` and dropped the wrappers. Check `git diff HEAD` on that file after saving.
