---
name: tinycrypt
description: TinyCrypt port (rm_tinycrypt_port) API names, deprecated RM_TINCYRYPT_PORT_* wrappers, TRNG, and their tests and usage notes. Read before changing rm_tinycrypt_port names, tests, or release notes.
---

# TinyCrypt port (rm_tinycrypt_port)

## Status
- Branch `FSPRA-6430_Correct_rm_tinycrypt_port_API_names`: new names in use, old names kept as deprecated wrappers.
- Not built against real BSP headers yet. Compat test not run on hardware.
- Release note: `documents/release_notes/upcoming/FSPRA-6430.yml` (category 4, Deprecations).

## Knowledge
- Typo fixed: `RM_TINCYRYPT_PORT_Init` / `_TRNG_Read` are now `RM_TINYCRYPT_PORT_Init` / `_TRNG_Read`.
- Old-name wrappers: end of `ra/fsp/src/rm_tinycrypt_port/rm_tinycrypt_port.c`. They call the new names.
- Declared in `ra/fsp/inc/instances/rm_tinycrypt_port.h` and `ra/fsp/src/rm_tinycrypt_port/inc/rm_tinycrypt_port.h`, marked `// [DEPRECATED]` (LIN style).
- No compiler deprecation attribute. It broke the build: `test_files/shared/tools.yml` sets `-Werror` in `fsp_flags`.
- Compat test: `TC_API_TestDeprecatedNames` in `!test/rm_tinycrypt_port_tests_tg1.c` (`@req`/`@verify` `tc_deprecated_names`). Usage note anchor: `um_tc_deprecated_names`.
- Test runner `test_files/src/r_tests_runner_main.c` uses the new name. The e2 test project `tinycrypt_api_test` calls the old names on purpose (no `-Werror` there).

## Open
- Pack build with real BSP headers to confirm the wrappers link.
- Editor save once dropped the wrappers. Check `git diff HEAD` on `rm_tinycrypt_port.c` after saving.
