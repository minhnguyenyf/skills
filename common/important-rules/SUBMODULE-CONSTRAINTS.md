# Submodule Read-Only Constraints

**Set:** 2026-10-01.

## Read-only submodules (do not modify)
- `ra/arm/mbedtls-v4/`: mbedTLS v4 with TF-PSA-Crypto. External library; changes go upstream or are dropped at submodule update.
- `ra/arm/mbedtls-v4/tf-psa-crypto/`: Trusted Firmware PSA Crypto. Changes need the upstream governance path.

## Fix at project level instead
- Missing include paths: add them to the e2 studio project settings, not by copying files into the submodule.
- Known case: `mbedtls/private_access.h` is only in `tf-psa-crypto/drivers/builtin/include/mbedtls/`. Add to GNU ARM Cross C Compiler > Includes:
  `${workspace_loc:/${ProjName}/ra/arm/mbedtls-v4/tf-psa-crypto/drivers/builtin/include}`

## Task rules
| Task | Approach |
|---|---|
| Fix submodule source | No. Open upstream issue or wait for a submodule update. |
| Work around it | Yes, in project config (e2 studio, build system, include paths, build flags). |
| Modify submodule files | No. If a submodule file change seems required, report it as a blocking issue and ask the user. |

Before any change, ask: "Am I modifying `ra/arm/mbedtls-v4*`?" If yes, stop.
