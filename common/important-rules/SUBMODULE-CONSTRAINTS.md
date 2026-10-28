# Submodule Read-Only Constraints

**Last Updated**: 2026-10-01  
**User**: the user

---

## Read-Only Submodules

The following submodules are external dependencies and **cannot be modified**:

### ❌ `ra/arm/mbedtls-v4/`
- Upstream: mbedTLS v4.1.0 with TF-PSA-Crypto
- Status: Read-only submodule
- Reason: External cryptographic library; changes must be upstreamed or reverted during submodule updates

### ❌ `ra/arm/mbedtls-v4/tf-psa-crypto/`
- Upstream: Trusted Firmware PSA Crypto
- Status: Read-only submodule
- Reason: Trusted component; any required changes must go through proper governance/merge process

---

## Configuration Fixes (Project Level)

When issues arise from submodule dependencies, **fix them at the project level**, not by modifying submodule files:

### Example: Missing Include Paths

**❌ WRONG**: Copy `private_access.h` into the submodule include directory
```bash
cp drivers/builtin/include/mbedtls/private_access.h include/mbedtls/
# ❌ Don't do this — violates submodule read-only constraint
```

**✅ CORRECT**: Add include path to e2 studio project settings
1. Right-click project → Properties
2. C/C++ Build → Settings
3. GNU ARM Cross C Compiler → Includes
4. Add: `${workspace_loc:/${ProjName}/ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include}`

---

## Known Constraints

### TF-PSA-Crypto v4 Include Paths

**Problem**: `#include "mbedtls/private_access.h"` in platform.h cannot be resolved

**Root Cause**: `private_access.h` exists at:
- `/tf-psa-crypto/drivers/builtin/include/mbedtls/private_access.h`
- But not in the main `/include/mbedtls/` directory

**Solution**: Configure build system include paths; do NOT copy files into submodule

**e2 studio Fix**:
```
${workspace_loc:/${ProjName}/ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include}
```

---

## What This Means for Tasks

| Task Type | Approach |
|-----------|----------|
| **Fix submodule source code** | Cannot do — open upstream issue or wait for submodule update |
| **Work around submodule limitations** | Configure project (e2 studio, build system) — YES |
| **Fix headers/includes** | Add to project include paths — YES |
| **Fix build flags** | Configure in project — YES |
| **Modify submodule files directly** | NO — violates constraint |

---

## Verification

**Before making changes**, ask:
- "Am I modifying `ra/arm/mbedtls-v4*`?" → If YES, STOP
- "Can I fix this in the project config instead?" → If YES, do that
- "Does this require changing a submodule file?" → If YES, document as a blocking issue and ask user

---

## Related Policies

See [CLAUDE-COMMIT-POLICY.md](CLAUDE-COMMIT-POLICY.md) for:
- When to commit/push
- Which repositories allow auto-commit
- Emergency override procedure
