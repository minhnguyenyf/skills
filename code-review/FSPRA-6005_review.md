# Review: FSPRA-6005_RSA_ECC_updates_aligned_with_the_new_security_policy vs develop

**Status:** Draft for review. Not committed to the project repo.
**Written for:** the user (branch author), before the branch is merged.
**Base:** `develop` at `a16a55bdfc4` (merge-base, branch is 0 behind) · **Head:** `39de99ecb67` · **Size:** 17 commits · 14 files · +105 / −241.
**Scope limits:** `ra/fsp/src/r_sce/`, `ra/fsp/src/r_rsip_protected/` and `ra/fsp/src/r_sce_protected/` were not read (user restriction, see `common/important-rules`). Anything that depends on those paths is marked **Not verified**.

---

## 0. Branch state

- Ahead of develop by 17 commits, behind by 0. Fast-forward merge is possible.
- Uncommitted in the worktree (not part of this branch's change): `ra/aws/FreeRTOS` (modified submodule) and `ra/arm/mbedtls-v4/` (untracked). Neither is in this review.
- The branch includes commits with other ticket names:
  - `d784d843b5b` "FSPRA-5831 Corrected PSA TG3-4 and crypto_procedures adaptor functions" (touches `rm_psa_crypto` tests).
  - `653cf236ad6` "FSPRA-6275 Add RN" (edits `FSPRA-6005.yml`, not an FSPRA-6275 file).
  Check that both belong on this branch.

---

## 1. Verdict

The change extends the existing E51A plaintext-key handling to RSIP-E50D across the PSA alt-process code, the netx secure crypto code, the RSIP key-injection tests and the PSA tests. The guard pattern is consistent, and one existing preprocessor bug is fixed (see 4.1).

**Not ready to merge until item 2.1 is confirmed.** The E50D branches in the RSIP key-injection code were changed to call the E51A signatures. The E50D driver signatures are in a restricted path and were not checked.

| # | Severity | Finding | Status |
|---|---|---|---|
| 2.1 | High | E50D now uses the E51A call form (key-mode and NULL arguments) in ECDSA sign and AES/RSA test calls | **Not verified**. Confirm the E50D signatures. |
| 2.2 | Medium | Plaintext RSA-2048 key generation is now enabled on E50D. Develop said E50D does not support it. | Behaviour change. Needs hardware test and a release-note check. |
| 2.3 | Medium | Release note describes "RSIP-E50D support procedures" only, and does not mention the plaintext key-generation change | Open |
| 2.4 | Low | Commit messages do not match their content (`FSPRA-6275 Add RN` edits FSPRA-6005.yml; `FSPRA-5831` commit on this branch) | Check intent |
| 2.5 | Info | `r_sce/crypto_procedures` submodule pointer moves `1933c12` → `bed1080` | **Not verified** (restricted path) |

---

## 2. Findings

### 2.1 (High, not verified) E50D now uses the E51A call form
- `ra/fsp/src/r_rsip_key_injection/!test/hw_sce_ra_ecc.c`: `HW_SCE_EcdsaP256SignatureGenerate` and `HW_SCE_EcdsaP384SignatureGenerate`. Develop had a separate E50D call with no key-mode argument. The branch removes that branch, so E50D now calls `HW_SCE_EcdsaSignatureGenerateSub` / `HW_SCE_EcdsaP384SignatureGenerateSub` with `&indata_key_mode` as the second argument.
- `ra/fsp/src/r_rsip_key_injection/!test/r_rsip_tests.c`: the same pattern in `R_RSIP_AES` (ECB, and the XTS encrypt and decrypt init calls), and in `R_RSIP_RSA` (`HW_SCE_Rsa{2048,3072,4096}ModularExponentDecryptSub`). In each case the E50D branch used to pass no key-mode argument, and now passes `&in_data_key_mode`.
- **Failure scenario:** if the E50D versions of these functions take the develop argument list, the build fails (argument count). If they take the new list, the code is right and the develop version was the bug.
- **Why it is not verified:** the signatures are in the restricted driver paths.
- **Action:** compare the E50D signatures with the call sites above. Then build the `rm_netx_secure_crypto` / PSA / key-injection test projects for an RSIP-E50D board (ra8x2).

### 2.2 (Medium) Plaintext RSA-2048 key generation enabled on E50D
- `rm_psa_crypto/rsa_alt_process.c`: `HW_SCE_RSA_2048KeyGenerate` and `mbedtls_rsa_gen_key` now run the E50D path. The 3072 and 4096 plaintext paths are also enabled for E50D.
- `rm_psa_crypto/!test/psa_crypto_tests_tg3.c`: `TC_API_RSAGenerateKeyPairExportImport` no longer ignores E50D. The 3072/4096 tests run on E50D. The E50D "not supported" ignores were removed.
- `rm_psa_crypto/!dsn/rm_psa_crypto_usage_notes.md`: the E50D column for "Key generation - plaintext" (RSA) changed from `--` to `(3)`.
- **Risk:** this is a behaviour change, not just a fix. Develop says E50D does not do plaintext RSA keygen.
- **Action:** run the RSA plaintext keygen tests on RSIP-E50D hardware. Check what footnote `(3)` says in the usage notes, and make sure it matches the new behaviour.

### 2.3 (Medium) Release note wording
`documents/release_notes/upcoming/FSPRA-6005.yml`:
- `description: Updated the RSIP-E50D support procedures to align with the new security policy`. This does not say that plaintext RSA keygen (2.2) is now enabled on E50D.
- `release_note_type: 2` and `category: 2` are set. The file has no newline at the end.
- **Action:** if 2.2 is user-visible, say so in the note. Add the trailing newline.

### 2.4 (Low) Commit content and ticket names
- `653cf236ad6` "FSPRA-6275 Add RN" changes `FSPRA-6005.yml`. The FSPRA-6275 release note is in `documents/release_notes/upcoming/v6.7.0-beta.0/FSPRA-6275.yml`.
- `d784d843b5b` "FSPRA-5831 …" changes PSA TG3 and TG4 tests on this branch.
- **Action:** confirm these are intended here. A history rewrite is not needed unless the team wants it.

### 2.5 (Info, not verified) Submodule pointer
- `ra/fsp/src/r_sce/crypto_procedures`: `1933c1297f3` → `bed1080ab0f`. The commit is `2492bbaf788` "FSPRA-6005 Updated crypto_procedures submodule".
- The contents of the submodule were not read. Check the new commit against the policy change this ticket describes.

---

## 3. Checks that look correct

- All guard changes in `rm_psa_crypto/*_alt_process.c` and `rm_netx_secure_crypto/*_alt_process.c` add E50D beside E51A in the same form. The one-line guards match their comments.
- `rm_psa_crypto/ecdsa_alt_process.c`: the ECC-256, ECC-384 and ECC-521 wrap guards each add E50D. The ECC-384 guard was reformatted onto two lines, and the logic is the same.
- `rm_psa_crypto/ecp_alt_process.c`: the `!(SCE7 || SCE9 || E51A || E50D)` guard for the software path is consistent with the other files.
- `rm_psa_crypto/!test/psa_crypto_tests_tg4.c`: the ECC plaintext guard and the ignore message both name E50D.
- `r_rsip_tests.c` XTS and AES tests keep the same branch structure. The `in_data_key_mode` variable is declared in the same `#if` block that uses it.
- `hw_sce_ra_ecc.c`: `indata_key_mode`, `InData_DomainParam` and `data_buff` moved to the top of each function. This is a style change only.

---

## 4. Specific items

### 4.1 Fixed preprocessor bug (good)
- `rm_netx_secure_crypto/!test/rm_netx_secure_crypto_tests_tg3.c` line 480 used `(BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED)` with no `== 0`. The branch changes it to `(BSP_FEATURE_RSIP_RSIP_E50D_SUPPORTED == 0)`, matching the other terms. This is correct.

### 4.2 `in_data_key_mode` declaration
- `r_rsip_tests.c` RSA SIGN: the variable is now declared inside the `#if (E51A || E50D)` block that already holds the `sig` buffers. Previously it had its own `#if E51A` block. The new placement is correct.

---

## 5. Not verified

- No build was run for any board. The branch was not checked out. The review used `git diff` and `git show`.
- No hardware test was run.
- Restricted paths were not read: `r_sce`, `r_rsip_protected`, `r_sce_protected`, including the `crypto_procedures` submodule. This affects item 2.1 and item 2.5.
- The usage-note footnote `(3)` was not read (item 2.2).

---

## 6. Recommended before merge

1. Confirm the E50D signatures for `HW_SCE_EcdsaSignatureGenerateSub`, `HW_SCE_EcdsaP384SignatureGenerateSub`, the AES XTS and ECB init calls, and the RSA `ModularExponentDecryptSub` calls. Fix any call site that does not match (item 2.1). Someone with access to the restricted paths must do this.
2. Build the RSIP-E50D test projects and run the RSA plaintext keygen tests on hardware (item 2.2).
3. Check footnote `(3)` in `rm_psa_crypto_usage_notes.md` against the new behaviour.
4. Update the release-note description if plaintext RSA keygen on E50D is user-visible. Add the trailing newline (item 2.3).
5. Confirm the `crypto_procedures` pointer change (item 2.5).
6. Confirm the FSPRA-5831 and FSPRA-6275 commits belong on this branch (item 2.4).
