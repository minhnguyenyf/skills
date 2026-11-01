# EK-RA6M5 QSPI MCUboot test: review for the project manager

Status: compacted 2026-11-01 from the 2026-10-08 review. Superseded where the final report (2026-10-09) reports the owner's passing run.

## Answers
- **Is the ra8_ospi (EK-RA8D1) OSPI test valid for the ra6_qspi (EK-RA6M5) test?** Partly. The erase-logic tests are shared and reusable. Their way of selecting the external flash cannot be copied, and QSPI hardware is not proven by them.
- **Which test is better, old `ra6m4_qspi` or new `ra6_qspi`?** The old one had a true end-to-end check (`TC_Vtor` after a confirmed update). The new one checks the erase logic. Best result: keep the new TG2 tests and restore the end-to-end check for QSPI.
- **Does the new test work?** At the review date, no. The first run failed two TG2 tests. A second run with the external map enabled hung. The change was reverted. The later fix is described in the final report.

## Differences between the two targets
| Aspect | ra8_ospi (RA8D1) | ra6_qspi (RA6M5) |
|---|---|---|
| Erase block | 256 KB | 32 KB. The "partial erase" test is meaningless on QSPI (1 of 6 tests is vacuous). |
| Page, address bytes | 64 B, 4-byte | 256 B, 3-byte |
| How the image gets to the flash | J-Link loads it directly | Bootloader copies it from internal flash at start-up |
| Setup code | OSPI pins, reset line, OCTACLK | QSPI pins, quad-enable bit, QPI exit. Not shareable. |
| How MCUboot selects external flash | Default linker folders rewritten (FSPRA-4851) | Not possible without breaking `ra6m5_std`, which needs the internal map |

## Old test (`ra6m4_qspi`)
- Added 2021-11-22, removed 2022-03-31 with a commit about protected-mode testing. The removal of the QSPI project looks like a side effect (inference).
- Flow: secondary image copied to QSPI at boot, then `TC_Vtor` confirms and checks the vector table. This only passes if the update from QSPI booted.
- Does not run today: `flash_map.c` builds the external path only under the XSPI macro, which that project does not define.

## Corrections to earlier communication
- It was wrong to say the build used QSPI as the secondary by design. The linker folders affected only the linker, not the compile-time flash map.
- Build size was not evidence of the external map.
- Widening the OSPI tests also removed the end-to-end `TC_Vtor` check for QSPI. That was to be undone.

## Recommendations (at review date)
1. Debug the hang: halt the target after the timeout and read PC and call stack.
2. Restore `TC_Vtor` for QSPI.
3. Choose a long-term way to select the external map (see the final report for the chosen design).
4. Optionally load the secondary with J-Link like ra8_ospi.
5. Build ac6, iar and llvm for the final layout.
