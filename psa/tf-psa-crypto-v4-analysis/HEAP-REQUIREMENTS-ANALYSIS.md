# TF-PSA-Crypto v4 Heap Requirements Analysis

**Status**: ⚠️ **UNVERIFIED** - Values inherited from v3, not validated for v4  
**Date**: 2026-10-01  
**Branch**: FSPRA-5629_MbedTLS_v4.1.0_TRNG_Sync

---

## Problem Statement

The heap requirements in `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` are **copy-pasted from v3 (mbedCrypto)** without verification that they're still valid in v4.

Current values:
- **0x400** (1024 bytes) - ECDH key agreement
- **0x1800** (6144 bytes) - ECDSA signing/verification  
- **0x1500** (5376 bytes) - RSA operations
- **0x200** (512 bytes) - AES operations

---

## Discovery Method

### V3 vs V4 Comparison

| Constraint | V3 (mbedCrypto) | V4 (TF-PSA-Crypto) | Verified |
|-----------|-----------------|-------------------|----------|
| Line source | ~4340-4400 | ~3383-3396 | ❌ No |
| Constraint format | Identical | Identical | ✅ Same |
| Algorithm checks | MBEDTLS_ECP_C, MBEDTLS_ECDSA_C | PSA_WANT_ALG_ECDH, PSA_WANT_ALG_ECDSA | ✅ Concept same |
| Heap values | 0x400, 0x1800, 0x1500, 0x200 | 0x400, 0x1800, 0x1500, 0x200 | ❌ **Unverified** |

### Missing Algorithms in Both v3 AND v4

These algorithms are **NOT covered by constraints** in either version:

| Algorithm | Purpose | Heap Required | Notes |
|-----------|---------|---------------|-------|
| PSA_WANT_ALG_DETERMINISTIC_ECDSA | ECDSA variant with deterministic nonce | **0x1800 (assumed)** | ⚠️ Not documented |
| PSA_WANT_ALG_JPAKE | Password-Authenticated Key Exchange | **Unknown** | ⚠️ Not documented |
| PSA_WANT_ALG_FFDH | Finite Field DH (not ECC) | **Unknown** | ⚠️ Not documented |

---

## Key Findings

### 1. **V4 Memory Architecture Changed**
From TF-PSA-Crypto 1.0 migration guide (line 913-915):
- **V3**: PK context stored all key material in heap-allocated object
- **V4**: PK context now contains **public key in fixed-size buffer directly in the structure**
  - This reduces heap allocation needs

**Implication**: Heap requirements may be **LOWER in v4** than v3, but this is not reflected in current constraints.

### 2. **No Official Heap Specification in v4 Docs**
Checked:
- ✅ psa-driver-example-and-guide.md → No heap size tables
- ✅ 1.0-migration-guide.md → Describes architectural changes, no new heap specs
- ✅ psa-shared-memory.md → Security architecture, not heap sizing
- ❌ No dedicated "MEMORY-REQUIREMENTS.md" or sizing guide found

### 3. **Missing Constraint Coverage**
Current constraints only check:
```
ECDH (0x400)
ECDSA (0x1800)
RSA (0x1500)
AES (0x200)
```

**NOT covered:**
- DETERMINISTIC_ECDSA (assumed 0x1800, not validated)
- JPAKE (unknown requirement)
- FFDH (unknown requirement)
- KEY_TYPE operations (should have separate check?)

---

## Recommendations

### Immediate Actions (Before v4 Release)

1. **Verify heap values empirically**
   - Profile each algorithm on actual hardware
   - Measure peak heap usage (not just static allocation)
   - Test with small heap sizes to find minimums

2. **Document missing algorithms**
   - Research JPAKE and FFDH heap requirements
   - Add constraints for DETERMINISTIC_ECDSA if different from ECDSA
   - Update PSA_WANT_ALG_JPAKE config if it exists

3. **Update constraint logic**
   - Include all crypto algorithms that have memory impact
   - Separate KEY_TYPE operations if they have distinct requirements

### Long-term

1. **Create TF-PSA-Crypto memory profile document**
   - Publish official heap requirements per algorithm/curve
   - Test on various board sizes (8KB, 16KB, 32KB, 64KB RAM)
   - Include both bare-metal and RTOS configurations

2. **Automate constraint verification**
   - Add build-time memory check
   - Warn if enabled algorithms exceed available heap
   - Track heap changes across v4 updates

---

## Testing Strategy

**Current blocker**: ra4m1_ek with 32KB RAM overflows by 1104 bytes

Options to verify if constraints are correct:
1. **Reduce heap to find minimum** (find actual requirement)
2. **Disable DETERMINISTIC_ECDSA** (is it included?)
3. **Disable JPAKE** (if present and not included in constraints)
4. **Profile memory usage** (actual vs. configured)

---

## References

- V3 Source: `Arm##PSA##Crypto##mbedCrypto####x.xx.xx.xml` (lines 4340-4400)
- V4 Source: `Arm##PSA##Crypto##TF-PSA-Crypto####x.xx.xx.xml` (lines 3383-3396)
- TF-PSA-Crypto Docs: `ra/arm/mbedtls-v4/tf-psa-crypto/docs/1.0-migration-guide.md` (line 913)
- Issue: RAM overflow on ra4m1_ek (32KB total, needs constraint review)

---

## Conclusion

**Do not treat these heap values as gospel truth.** They're inherited from v3 and unverified for v4's new memory architecture. Empirical profiling is required before finalizing constraints for production use.

**Key insight**: v4's architectural change (fixed-size key buffer in PK context) likely REDUCES heap needs, but the constraints haven't been updated to reflect this.
