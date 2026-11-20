---
name: test-case-rules
description: Rule for adding or changing a test case in an FSP module (for example rm_tinycrypt_port). Use when adding a TEST(), a @req or @verify tag, or a usage-note anchor, so the requirement, test, and usage note stay in sync.
---

# Test case and usage note rule

When you add a test case, do all of these in the same change:

1. **Test:** add `@req{<id>,<ticket>,<doc_ref>}` and `@verify{<id>}` in the test's comment block. Use the same `<id>` in both tags. The build checker reports `missing @verify` when the tag is absent.
2. **Usage note:** in the module's `!dsn/<module>_usage_notes.md`, add `@anchor um_<id>` where the feature is described. The anchor name is `um_` plus the requirement ID, lowercase, exactly.
3. **Check:** the requirement ID must match between the test tags and the anchor. Each anchor must sit in a section a user can read.
4. **Correct:** if the usage note already describes the behaviour, fix any out-of-date text in the same change. Do not leave a note that contradicts the test.
5. **Line endings:** keep CRLF in peaks files. Check with `grep -c $'\r$' <file>` against `wc -l`.

Example (rm_tinycrypt_port): test `TC_API_TestDeprecatedNames` uses `@req{tc_deprecated_names,FSPRA-6430,...}` and `@verify{tc_deprecated_names}`. The usage note has `@anchor um_tc_deprecated_names` in "Deprecated API Names".
