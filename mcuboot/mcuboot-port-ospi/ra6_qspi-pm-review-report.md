# EK-RA6M5 QSPI MCUboot test: review for the project manager

Date: 2026-10-08. Branch FSPRA-6767. Prepared from the repository history, the code and the test runs so far.
Short answer first, details below.

## Summary
| Question | Answer |
|---|---|
| Is the ra8d1_ek OSPI test valid for the ra6m5_ek QSPI test? | **Partly.** The test logic is shared and reusable. It is not a valid substitute for validating QSPI on the ra6m5 hardware, and its way of selecting external flash cannot be copied. |
| Old removed test (`ra6m4_qspi`) or new test (`ra6_qspi`): which is better? | **Neither is validated today.** The old one was the better end-to-end check; the new one has better coverage of the erase logic. The best result is to keep the new erase tests and restore the old end-to-end check. |
| Does the new test work now? | **No.** First run: 2 of the TG2 tests failed. Second run, with the QSPI flash map really enabled: the run hung. That change was reverted, so the current build is back to the first state. |

## 1. Is the OSPI test (ra8_ospi, EK-RA8D1) valid for the QSPI test (EK-RA6M5)?

### What is shared (valid to reuse)
- The six TG2 erase tests call `flash_area_erase()`, `flash_area_get_sector()`, `flash_area_read/write()` in `flash_map.c`. The external-flash branch of that file is generic: it talks to the flash only through the `spi_flash` API (`erase`, `write`, `statusGet`), which both `r_ospi_b` and `r_qspi` implement. So the logic being tested (whole-block erases, rejecting unaligned length/address, virtual sectors equal to the erase block) is the same code for both.
- Both tests use the same build macros: `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI` plus an erase-size macro.

### What is different (not valid to copy as is)
| Aspect | ra8_ospi (EK-RA8D1) | ra6_qspi (EK-RA6M5) | Consequence |
|---|---|---|---|
| Erase block | 256 KB | 32 KB | The "partial erase does not over-erase" test only has meaning when the block is larger than 32 KB. On QSPI it is ignored, so 1 of 6 tests checks nothing. |
| Page size, address bytes | 64 B, 4-byte | 256 B, 3-byte | Write alignment differs; QSPI also has a 128 vs 256 alignment concern that OSPI does not. |
| How the secondary image gets into the external chip | J-Link loads it directly into OSPI (`secondary_slot 0x90000000`) and a J-Link script power-cycles the flash | Current design: bootloader copies it from internal flash at start-up | Different failure modes and a different level of realism. |
| Hardware setup | OSPI pins, reset line P1_06, OCTACLK clock source | QSPI pins P3_xx, quad-enable bit, QPI exit | The setup code cannot be shared. |
| How MCUboot learns the secondary is external | The default ra8d1 linker folders were rewritten (FSPRA-4851) | Not possible without breaking `ra6m5_std`, which needs the internal map | The ra8d1 approach does not transfer. This is what caused the problems below. |
| Test hardware | TrustZone-capable RA8, different flash chip | Cortex-M33 RA6, Macronix MX25L | Different flash behaviour. |

### Evidence limits
- I have not seen results of the ra8_ospi test run, so I cannot say it passes; I only read its code and configuration.
- "Valid" above means the same logic is exercised, not that QSPI hardware behaviour is proven.

## 2. Old test (`ra6m4_qspi`) versus new test (`ra6_qspi`)

### The old test
- Added 2021-11-22 (SWFLEX-3508), removed 2022-03-31 by a commit titled "disable ra6m4 protected mode test", which also removed `ra6m4_ek_sce9_protected_rsa3072`. The removal looks like a side effect of that change, but the commit does not say so (my inference).
- Board EK-RA6M4 (same QSPI chip as RA6M5), SCE9 crypto, v3 `rm_psa_crypto`, default `boot` linker.
- Flow: the app's secondary image is flashed to internal 0x40000 and copied to QSPI by a boot-time hook; the app's `TC_Vtor` test then runs `boot_set_confirmed()` and checks the vector table. It could only pass if the update from the QSPI secondary had actually booted. That is a true end-to-end check.
- It does not run today: since FSPRA-4851 `flash_map.c` only builds the external path when `RM_MCUBOOT_PORT_CFG_SECONDARY_USE_XSPI` is defined (the old project did not define it), and the default linker folders now describe an internal secondary. I could not verify how the old build selected the external map before the linker rework.

### The new test
- Boot project `ra6_qspi` (+ app `rm_mcuboot_app_qspi.xml`), EK-RA6M5, same copy-from-internal flow, plus the six TG2 tests that were written for OSPI (FSPRA-4851) and widened to XSPI.
- It targets the erase-granularity logic that did not exist when the old test was written.
- It skips `TC_Vtor` (I widened the existing OSPI skip to all XSPI), so the old end-to-end check is not part of it.

### Comparison
| Criterion | Old `ra6m4_qspi` | New `ra6_qspi` |
|---|---|---|
| End-to-end update from QSPI checked | **Yes** (`TC_Vtor` + confirm) | No (skipped) |
| Erase block/alignment logic checked | No | **Yes** (6 tests, 1 vacuous on QSPI) |
| Covers current code (post FSPRA-4851) | No, cannot run | Intended to |
| Board in CI | Not in CI since 2022 | `ra6m5_ek` is already in the `rm_mcuboot_port` pipeline entry |
| Runs correctly today | No | **No** |
| Truly exercises QSPI today | Unknown | **No**: the first run used the internal map; the second hung |

### Which is better, and why
- As a functional test, the old one was better, because one check proves the whole flow works with QSPI.
- As protection against the regression FSPRA-4851 fixed, the new tests are better.
- Neither can be called good until it passes on hardware with QSPI really in use. The recommended result is a combination: keep the new TG2 tests and bring back the end-to-end `TC_Vtor` check for QSPI.

## 3. Current status and what went wrong
| Run | Build state | Result |
|---|---|---|
| 1 | Default (internal) flash map; QSPI only a copy target | `TC_Erase_Rejects_Unaligned_Length` and `..._Address` failed ("Expected Not-Equal"). Expected: the reject checks exist only in the external path. The test did not use QSPI. |
| 2 | Flash map switched to external (guard in the default ra6m5 linker info) | Hung before the first test: no output for 10 minutes (llvm build). Cause not found. The bootloader ELF section layout looked sane, so the linker is not the likely cause; likely suspects are a QSPI status wait that never completes, reading the flash while it is busy, or a fault. |
| 3 | Guard reverted by the owner | Back to run 1 behaviour (predicted, not re-run). |

Mistakes on my side that should be corrected in earlier communication:
- I said the test "really uses QSPI as the secondary by design". For the build that failed, that was false: the new linker folders only affect the linker, not the compile-time flash map.
- I used build size as evidence that the external path was compiled; it only showed the QSPI buffers were present.
- When widening the OSPI tests I also removed the end-to-end `TC_Vtor` check for QSPI. That should be undone.

## 4. Recommendation and next steps
1. Debug the hang: halt the target after the timeout and read the program counter and call stack (Ozone or e2 studio). Then re-apply the external flash map guard and fix the cause.
2. Restore `TC_Vtor` (end-to-end) for QSPI by making the skip OSPI-only again.
3. Decide how the external map is selected long term: guard in the default linker files (small, but hand-edited generated files), new project types `boot_qspi`/`boot_app_qspi` (repo pattern, shared build script change), or in `flash_map.c`.
4. Optionally load the secondary image with J-Link like ra8_ospi for a more realistic test.
5. Build ac6, iar and llvm for the final layout; all four compilers have the linker files.

## 5. Where the details are
Skill `mcuboot-port-ospi`: `ra6_qspi-test-report.md` (design and flow), `ra6_qspi-tg2-failure-report.md` (root cause of run 1), `SKILL.md` (evidence about the old test, history commands).
