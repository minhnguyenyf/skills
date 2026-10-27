---
name: ocrypto
description: Build order and link errors for the Oberon Ocrypto library in the peaks repo (rm_ocrypto_port, libocrypto.a, ra2e1_ek and ra2l1_ek). Use when a build fails with "cannot find -locrypto", when building rm_ocrypto_port, or when changing the ocrypto library build.
metadata:
  type: reference
  recorded: 2026-10-27
---

# Ocrypto library build (rm_ocrypto_port)

## Build order

`rm_ocrypto_port` links `libocrypto.a`, which is built by a separate `ocrypto` project. Build the library first, then the target.

```bash
cd /home/coder/workspace/peaks
scons -k --build=ocrypto --board=ra2e1_ek --compiler=gcc          # 1. library (CM23)
scons -k --build=rm_ocrypto_port --board=ra2l1_ek --compiler=gcc # 2. target
```

- The library output is `build/ocrypto/ra2e1_ek/<compiler>/build_ocrypto_lib_typical_debug/libocrypto.a`, plus a `hw_accel` variant. RA2L1 uses the same CM23 library as RA2E1.
- Rebuild step 1 only when the ocrypto sources change, when `build/ocrypto/` is deleted, or when you switch compilers. Each compiler has its own output folder, so build the library for that compiler too.

## Why step 1 is needed

- The `ocrypto` dependency is listed in `projects/rm_ocrypto_port.xml` (the `<dependencies>` blocks).
- `projects/ocrypto.xml` targets only `ra2e1_ek`.
- `SConstruct` `_filter_boards()` (around line 225, called at line 393) keeps only projects whose boards match `--board`. With `--board=ra2l1_ek`, the `ocrypto` dependency is filtered out, so it is never built. The link then fails with `ld: cannot find -locrypto`.
- The error is not a path problem in the target. The library was never built.

## Verified

- Fresh machine, no `build/ocrypto/`: step 1 built both `libocrypto.a` variants, and step 2 reported SUCCEEDED for `rm_ocrypto_port` typical and hw_accel on `ra2l1_ek` with gcc.
- Not verified: a single run with `--board="ra2l1_ek ra2e1_ek"`. Check the output before using it.

## Related

- The RA2L1 BSP provides `interface.mcu.ocrypto_licensed` (`ra/fsp/src/bsp/mcu/ra2l1/.module_descriptions/`). The Oberon module requires it (`ra/oberon/.module_descriptions/Oberon##Ocrypto##all##Lib####x.xx.xx.xml`).
- The module packaging copies the library to `ra/oberon/ocrypto/Library/cm23_*/` (`ra/oberon/!dsn/module.xml`). That folder is absent in this clone, and the target links from `build/ocrypto/` instead.
- `ra/oberon/ocrypto` is a submodule (`3.9.4+renesas.0` at the time of this note).
