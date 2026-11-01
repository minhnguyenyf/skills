# TF-PSA-Crypto v4 heap requirements

Status: UNVERIFIED (2026-10-01, compacted 2026-11-01). The heap constraints in `ra/arm/.module_descriptions/Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` were copied from v3 (mbedCrypto) and have not been measured for v4. Do not treat them as final.

## Current constraint values (v4 module, copied from v3)
- ECDH: 0x400
- ECDSA sign and verify: 0x1800
- RSA: 0x1500
- AES: 0x200

## Gaps
- Not covered in v3 or v4: `PSA_WANT_ALG_DETERMINISTIC_ECDSA` (assumed 0x1800), `PSA_WANT_ALG_JPAKE` (unknown), `PSA_WANT_ALG_FFDH` (unknown).
- No official v4 heap sizing table in the docs (`psa-driver-example-and-guide.md`, `1.0-migration-guide.md`, `psa-shared-memory.md`).

## Architecture change that may lower heap use
- v3 PK context held key material in a heap object. v4 keeps the public key in a fixed-size buffer inside `mbedtls_pk_context` (migration guide ~line 913). Private keys live in the PSA key store. Heap needs may be lower in v4, but the constraints do not reflect this.

## Open actions
1. Measure peak heap per algorithm and curve on hardware. Find the real minimum by shrinking the heap.
2. Research JPAKE and FFDH heap needs. Add constraints or document them.
3. Decide whether DETERMINISTIC_ECDSA needs its own constraint.
4. Consider a build-time check that enabled algorithms fit the heap.

## Known test blocker
RA4M1 (32 KB RAM) overflowed by 1104 bytes in an earlier build. Resolved by a heap reduction (see `mbedtls-v4-migration-notes/SKILL.md`, board RAM section).

## References
- v3 source: `Arm##PSA##Crypto##mbedCrypto####x.xx.xx.xml` (around lines 4340 to 4400)
- v4 source: `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` (around lines 3383 to 3396; line numbers may have moved)
- `ra/arm/mbedtls-v4/tf-psa-crypto/docs/1.0-migration-guide.md` (around line 913)
