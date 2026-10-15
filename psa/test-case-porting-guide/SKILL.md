---
name: test-case-porting-checklist
description: Checklist and gotchas when porting test cases between mbedTLS v3↔v4 versions
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1b6c3459-c85f-49a6-be9c-d06896295e36
  modified: 2026-09-18T07:42:29.608Z
---

## Test Case Porting Checklist

**When porting tests from v3 to v4 (or vice versa), follow this systematic approach:**

### Step 1: Identify All Test Files
- [ ] Compare test group files (TG1, TG2, TG3, etc.) line-by-line
- [ ] Check line count differences: `wc -l` both versions to spot missing tests
- [ ] Use diff to identify removed/added test cases

### Step 2: Find Helper Functions
**GOTCHA:** Test cases often depend on helper/utility functions, not just TEST() macros.

When you see errors like:
```
undefined reference to 'cipher_example_encrypt_decrypt_aes_gcm_multipart_known_result'
```

**DO THIS:**
1. Search for the function in the source version: `grep -r "cipher_example_..." ./ra/fsp/src/rm_psa_crypto/!test/`
2. Find the line number: `grep -n "^psa_status_t cipher_example..."` (use `^` to match at start of line)
3. Extract the ENTIRE function definition (both forward declaration AND implementation)
4. Update API types during copy (see Step 3)
5. Add functions BEFORE the test cases that call them

### Step 3: API Migration During Copy
**Critical: Update these v3→v4 types while copying code:**

| v3 Type | v4 Type | Context |
|---------|---------|---------|
| `psa_key_handle_t` | `psa_key_id_t` | Key identity |
| `PSA_KEY_LIFETIME_IS_PERSISTENT()` | `(!PSA_KEY_LIFETIME_IS_VOLATILE())` | Macro replacement |
| `psa_open_key()` | `psa_get_key_attributes()` | Key lookup (error: `PSA_ERROR_INVALID_HANDLE`) |
| `mbedtls_pk_parse_key()` 7-arg | `mbedtls_pk_parse_key()` 5-arg | Remove f_rng, p_rng params |

### Step 4: Update Test Runner
- [ ] Find test runner file: `psa_crypto_tests_runner.c`
- [ ] Add `RUN_TEST_CASE()` calls for new tests in correct order
- [ ] Keep alphabetical or logical grouping
- [ ] Insert after related tests, not at the end

### Step 5: Verify Completeness
- [ ] Line count between v3 and v4 should now match
- [ ] All TEST() macros present: `grep "^TEST(PSA_CRYPTO_TG" file.c | wc -l`
- [ ] All helper functions present: `grep "^psa_status_t" file.c`
- [ ] All runners present: `grep "RUN_TEST_CASE" runner.c`

---

## Common Pitfalls

### ❌ Mistake 1: Only copying TEST() macros
**Problem:** Tests fail to link because helper functions are missing.
**Solution:** Always search for and copy helper functions that tests depend on.

### ❌ Mistake 2: Position-based line counting
**Problem:** "The test should be around line 3000" — wrong, might be elsewhere.
**Solution:** Search by function NAME, not position. Use `grep -n "^TEST(PSA_CRYPTO_TG2, TC_API_AES"` to find exact locations.

### ❌ Mistake 3: Forgetting API migration
**Problem:** Code compiles but types are wrong. Subtle bugs at runtime.
**Solution:** Create a checklist of v3→v4 type changes and check each function copy.

### ❌ Mistake 4: Not updating runner.c
**Problem:** Tests exist but never run. No one notices the test is broken.
**Solution:** Always add RUN_TEST_CASE() entries to runner when adding tests.

---

## Worked Example: TG2 GCM Tests

**Before:** v3 had 25 AES tests, v4 had 23 (missing 2)

**Process:**
```bash
# 1. Find what's missing
v3_tests=$(grep "^TEST(PSA_CRYPTO_TG2," v3.c | cut -d, -f2 | sort)
v4_tests=$(grep "^TEST(PSA_CRYPTO_TG2," v4.c | cut -d, -f2 | sort)
diff <(echo "$v3_tests") <(echo "$v4_tests")
# Result: TC_API_AESEncryptDecryptGCM_MultiPart, TC_API_AESEncryptDecryptGCM_ShortenedTag

# 2. Find helper functions
grep -n "cipher_example_encrypt_decrypt_aes_gcm_multipart_known_result" v3.c
# Result: 1768 (declaration), 1775 (definition)

# 3. Copy entire functions with API updates
- Read lines 1768-1954 (multipart function)
- Read lines 1963-2192 (shortened_tag function)
- Change psa_key_handle_t → psa_key_id_t
- Change PSA_KEY_LIFETIME_IS_PERSISTENT → (!PSA_KEY_LIFETIME_IS_VOLATILE)

# 4. Insert before test cases
- Add both function definitions BEFORE TC_API_AESEncryptDecryptGCM_MultiPart

# 5. Update runner
- Add RUN_TEST_CASE entries after TC_API_AESEncryptDecryptGCM
```

---

## Why This Matters

**Why not just copy/paste blindly?**
- Tests can have forward declarations AND definitions
- Tests depend on helper functions that might be hundreds of lines away
- API types changed between v3→v4; blind copy creates silent bugs
- Runner.c must be in sync or tests don't execute

**Result:** Systematic approach catches all missing pieces. Random copy/paste leaves broken tests that only fail at link-time.

