# Problem 201: @windyroad/tdd hook only recognises same-dir or __tests__/ test associations

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`@windyroad/tdd`'s PreToolUse hook function `tdd_find_test_for_impl()` (in `packages/tdd/hooks/lib/tdd-gate.sh`) maps an implementation file to its test by checking two locations only:

1. Same-directory: `src/foo.js` → `src/foo.test.js`
2. `__tests__/`-adjacent: `src/foo.js` → `src/__tests__/foo.test.js`

It does NOT recognise a `test/`-mirror convention (`src/foo.js` → `test/foo.test.js`), which is a common Node/JS test layout (the default Vitest `test/**` glob; many Jest setups). Projects whose existing test layout mirrors `src/` under `test/` cannot satisfy the TDD gate from `test/` when adding a new test for an existing `src/` module — the hook blocks the implementation Edit because it can't see the existing test.

## Symptoms

- TDD state IDLE + a new `src/foo.js` impl → PreToolUse hook denies Edit/Write on `src/foo.js` because `tdd_find_test_for_impl()` returns no path; the hook suggests creating `src/foo.test.js` (same-dir) or `src/__tests__/foo.test.js`.
- Pre-existing tests at `test/foo.test.js` are invisible to the hook even when Vitest/Jest discover them at runtime.
- Adding a new src module + a new `test/`-located test requires either (a) co-locating as same-dir / `__tests__/`, OR (b) bypassing the gate.

## Workaround

Bypass the TDD gate or co-locate tests in same-dir / `__tests__/` against the project's existing convention. Both are friction-inducing for adopters with established `test/`-mirror layouts.

## Impact Assessment

- **Who is affected**: adopter projects using `test/`-mirror layout (Vitest default + many Jest setups).
- **Frequency**: every TDD-gated impl Edit in such projects.
- **Severity**: Moderate — adopters either bypass the gate or change their test layout to satisfy the hook.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend `tdd_find_test_for_impl()` to support a third path shape: `src/foo.js` → `test/foo.test.js` (and recursively for nested `src/a/b/foo.js` → `test/a/b/foo.test.js`).
- [ ] Behavioural bats coverage for the test/-mirror path including nested dirs.
- [ ] Document the supported layouts in `packages/tdd/README.md`.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: TDD plugin's test-association logic; any future test-layout extension.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/123 (filed 2026-05-13 from a downstream project's adopter session).
- **Pipeline classification** (review-problems Step 4.5e): JTBD-alignment=aligned-with-existing-JTBD; dual-axis-risk=safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/tdd.
