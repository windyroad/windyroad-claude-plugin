# Problem 013: TDD plugin does not recognise `.feature` files as tests

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)

## Description

The TDD plugin's file classifier (`tdd_classify_file()` in `packages/tdd/hooks/lib/tdd-gate.sh`) only matches `*.test.*` and `*.spec.*`. Cucumber `.feature` files — which ARE tests — fall through to the "impl" classification. Writing a `.feature` file does not transition the test's state from IDLE to RED, so BDD users must create a throwaway `*.test.js` wrapper just to enter the TDD cycle.

Addressr reported this externally as their P005 after hitting the friction in real project work (see `~/Projects/addressr/docs/problems/005-tdd-hook-cucumber-friction.open.md`).

## Symptoms

- Cucumber users on projects governed by `@windyroad/tdd` must create thin `*.test.js` wrappers to satisfy the hook (extra boilerplate, confusing dual-test surface).
- `.feature` files written alone leave the associated impl file's TDD state at IDLE, blocking implementation edits even though a real test exists.
- Pair-detection logic (packages/tdd/hooks/lib/tdd-gate.sh:129-181) assumes a `Name.test.ext`/`Name.spec.ext` convention that doesn't map to Cucumber's `features/` ↔ `features/step_definitions/` layout, so even if `.feature` were classified as a test, pair resolution would still fail.

## Workaround

Create a companion `<name>.test.js` file importing the step definitions or a function under test. This satisfies the classifier and transitions to RED.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona using Cucumber/BDD (JTBD-002 Ship With Confidence)
  - Tech-lead persona in consulting contexts where BDD is common
  - Plugin-developer persona (JTBD-101) if classifier becomes an extension point
- **Frequency**: Every file edit on a BDD-first project governed by `@windyroad/tdd`.
- **Severity**: High — fake-wrapper workaround violates the "speed without sacrificing quality" constraint and BDD is a mainstream test style.
- **Analytics**: N/A. External report: addressr P005.

## Root Cause Analysis

`tdd_classify_file()` (packages/tdd/hooks/lib/tdd-gate.sh:15-23) matches only `.test.*` and `.spec.*`. Pair-detection (lines 129-181) assumes the same naming convention. Both need to learn about Cucumber's directory-based layout.

### Investigation Tasks

- [x] Decide scope: classifier-only fix (recognise `.feature` as test), or also extend pair-detection to handle `features/X.feature` ↔ `features/step_definitions/X.steps.js` — **both implemented**
- [x] Prototype classifier extension — `*.feature` added to test case in `tdd_classify_file()`
- [x] Create reproduction tests under `packages/tdd/hooks/test/tdd-gate.bats` — 4 new tests (all GREEN)
- [ ] Verify against addressr P005 scenario (does removing the fake wrapper now work?) — deferred to user verification

## Fix Released

Implemented 2026-04-16 in `packages/tdd/hooks/lib/tdd-gate.sh`:
- `tdd_classify_file()`: added `*.feature` to test case — Cucumber `.feature` files now transition TDD state from IDLE to RED
- `tdd_find_test_for_impl()`: added Cucumber pair-detection — step definitions in `step_definitions/` associate with the matching `.feature` in the parent `features/` directory; compound suffix `.steps.*` stripped before stem matching
- `packages/tdd/hooks/test/tdd-gate.bats`: 4 new regression tests (40/40 GREEN)

Awaiting user verification that BDD/Cucumber users no longer need fake `*.test.js` wrappers.

## Related

- Split from original P013 (combined ticket) — see P016 for the meta concern about conflated tickets
- Sibling: `docs/problems/015-tdd-vague-gherkin-detection.open.md` — the other half of the original P013
- External report: `~/Projects/addressr/docs/problems/005-tdd-hook-cucumber-friction.open.md`
- Addressr briefing: `~/Projects/addressr/docs/BRIEFING.md` line 35
- `packages/tdd/hooks/lib/tdd-gate.sh` — `tdd_classify_file()` and pair detection
- ADR 005 (proposed): `docs/decisions/005-plugin-testing-strategy.proposed.md` — names `tdd_classify_file` as a unit-tested function
- ADR 002 (proposed): `docs/decisions/002-monorepo-per-plugin-packages.proposed.md` — scopes `@windyroad/tdd`
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
