# Problem 018: TDD plugin should enforce BDD + Example Mapping principles, with examples traceable to Jobs-To-Be-Done

**Status**: Open
**Reported**: 2026-04-16
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: XL — new ADR (docs/decisions/NNN-test-content-quality-review.proposed.md, ID to be minted at creation per P022 renumber rule), ADR-002 dependency-graph update if any (tdd → jtbd soft dep), per-framework invariant mapping (Jest/Vitest/Mocha/Bats/pytest/Go/Gherkin), gate + agent enforcement surfaces (L → XL 2026-04-19 per P047: multi-day, cross-package, new ADR required)
**WSJF**: 2.0 — (16 × 1.0) / 8
**Type**: technical

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**BDD enforcement scope**: **three features, gated on BDD-opt-in** per project.

Selected (multi-select):
1. **Gherkin test-name grammar (Given/When/Then)** — enforce test names follow the Given/When/Then shape via naming regex. Catches unstructured names ("test_the_thing").
2. **Example-mapping artefact before RED** — require a `.example-map.md` file naming the behaviour + example + rule + question before any RED test can land.
3. **Rule/question tracking in test comments** — require every test file's header comment to link to a Rule and at least one Question from the example map.

**User qualifier (verbatim)**: *"but this only applies to projects using BDD"*.

**Opt-in mechanism**: the TDD plugin detects BDD-discipline at runtime and only enforces the three rules when BDD is opted in. Detection candidates:

- **Explicit setting**: `.claude/settings.json` key `tdd.bdd: true` — cleanest, adopter declares intent.
- **Heuristic**: presence of `.feature` files OR a BDD test runner (e.g. Cucumber, Behave, godog) in `package.json` / `requirements.txt` / `go.mod`.
- **Per-file flag**: BDD rules fire only on test files tagged `@bdd` in their header comment.

Lean: **explicit setting** — deterministic, adopter-controlled, no false-positive risk. Architect review at implementation can decide whether to combine with the heuristic as a fallback.

Supersedes the 2026-04-20 direction below (which proposed gate + advisory agent without the BDD-opt-in qualifier). The opt-in gate protects non-BDD projects from false-positive enforcement noise.

## Direction decisions (2026-04-20, user — AFK loop stop-condition #2) — superseded by 2026-04-21 above on the opt-in qualifier

Shared with P015 (both bound to the same ADR candidate):

**Enforcement level**: **Both — gate + advisory agent**. Deterministic gate catches obvious concreteness/traceability violations (blocking). Specialist agent reviews subtler shape issues (advisory). P018 owns the framework-agnostic quadruplet invariant; P015 is the Cucumber-specific adapter.

**Plugin home**: **Extend `@windyroad/tdd`**. No new plugin. Cross-plugin soft dep on `@windyroad/jtbd` stays advisory (reads `docs/jtbd/` per ADR-008 Option 3 — no legacy-file fallback since P019 landed).

Implication: ADR-002 graph stays as-is (no new plugin). The candidate ADR can be drafted with both decisions fixed. Investigation Task "Decide relationship to P015" is resolved: P018 is the framework-agnostic rule; P015 is the Cucumber-specific adapter (no supersession).

## Description

The TDD plugin currently enforces only a state machine — that a test exists, fails, then passes. It does not enforce what a *good* test looks like. BDD and Example Mapping (https://cucumber.io/blog/bdd/example-mapping-introduction/) give a framework-agnostic answer to that question: **every test should encode a rule backed by at least one concrete example** (specific input → specific expected output).

These principles are not Gherkin-specific. A Jest `test("returns the right thing", () => expect(result).toBeTruthy())` has the same failure mode as a vague Gherkin `Then` step — the rule is named, the example is missing, a trivial implementation passes. Any test framework can express this defect: Vitest, Mocha, Bats, pytest, Go `testing`, RSpec.

P015 captures this for Gherkin/Cucumber specifically. This problem generalises P015: the TDD agent (and any future content-quality review surface) should apply BDD + Example Mapping principles regardless of the underlying framework.

**Examples must be traceable to a Job-To-Be-Done.** Concreteness alone is not enough. A test can name a specific input and a specific expected output and still be testing the wrong thing — a coincidence of implementation rather than a behaviour the user cares about. The stronger requirement is: **every example must cite a documented JTBD** (e.g. `JTBD-002`) so the test → example → JTBD → persona outcome chain is unbroken. This is how Example Mapping is meant to be used in practice — rules exist to serve user jobs; examples exist to pin down rules; tests exist to guard examples. A test that cannot cite the job it serves is testing code, not behaviour.

## Symptoms

- Jest/Vitest tests with assertions like `toBeTruthy()`, `toBeDefined()`, `not.toBeNull()` without concrete expected values — passes whenever *any* truthy value is returned.
- Tests whose names describe outcomes in the abstract ("handles the error case", "returns the user", "works") without the name or the body naming a specific input and specific expected output.
- Tests that assert on structure/shape without asserting on values (`expect(result).toHaveProperty('name')` without checking the name's value).
- Tests where the Arrange step uses opaque fixtures or randomised inputs so the reader cannot tell which example the assertion corresponds to.
- Property-based tests without documented invariants — which are the rules, not the examples, so they need paired concrete examples.
- Tests that cannot cite a JTBD — even when concrete, they may be testing implementation detail rather than a behaviour a persona cares about. With no traceability link, the test's value is un-auditable.
- Test suites that drift from the job map — JTBDs are added, changed, or removed in `docs/jtbd/` but tests continue to guard rules no JTBD depends on.
- No current mechanism in the TDD plugin flags any of this. The gate enforces presence and RED→GREEN only.

## Workaround

Manual review. Requires reviewers who already internalise BDD + Example Mapping. Does not scale with AI-assisted test authorship, where the agent can easily produce plausible-looking tests that assert nothing concrete.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-002 Ship With Confidence) — "the agent cannot bypass governance" is weak if the agent can write vague tests that pass the gate.
  - Tech-lead persona (JTBD-001 governance without slowing down) — audit trail quality depends on test quality.
  - Any plugin consumer using any test framework — this is not Cucumber-specific.
- **Frequency**: Every test authored by an AI agent without explicit example-based prompting. With AI-driven test writing now the default workflow, this is every test.
- **Severity**: High. Tests that don't fail on regressions are worse than no tests — they produce false confidence and mask defects. This is the specific risk the TDD plugin exists to prevent.
- **Analytics**: N/A. The Gherkin variant was observed this session (see P015 trigger example).

## Root Cause Analysis

Two contributing factors:

1. **The TDD plugin's scope was defined narrowly.** It enforces the Red-Green-Refactor *cycle*. Test *quality* — whether the Red step is actually a meaningful failure — was treated as out of scope. In practice this leaves a significant portion of the value of TDD unprotected.
2. **No shared BDD/Example-Mapping surface.** P015 is drafting this for Cucumber; there is no framework-agnostic primitive that Jest/Vitest/Mocha/Bats variants could plug into. If P015 and P018 are solved independently, we duplicate the rule-vs-example detection logic per framework.

### Investigation Tasks

- [ ] Define the framework-agnostic invariant. Updated draft: "Every test must contain at least one quadruplet of (cited-JTBD, named-rule, specific-input, specific-expected-output) where the expected output is a literal value, a structural predicate with literal fields, or a named data-table row, AND the test cites a JTBD identifier matching `JTBD-\d{3}` that resolves to an entry in `docs/jtbd/README.md` (the sole canonical layout per ADR-008 Option 3 chosen 2026-04-20 via P019; projects still on the legacy single-file layout must run `/wr-jtbd:update-guide` to migrate before P018's traceability gate activates). A test that only checks truthiness, existence, or structure without values fails the concreteness invariant; a test that cites no JTBD fails the traceability invariant."
- [ ] Decide the JTBD citation mechanism. Reuse the existing `@jtbd` annotation convention from ADR-008 rather than inventing a new one (architect guidance). Likely surfaces: Gherkin tags (`@jtbd:JTBD-002` on scenarios), Jest/Vitest describe-block comments or `.meta`, Bats `# @jtbd: JTBD-002` comments, Go `// @jtbd: JTBD-002`.
- [ ] Resolve the cross-plugin dependency. `@windyroad/tdd` currently has no dependency on `@windyroad/jtbd` (ADR-002 graph). Options: (a) add a soft dep — tdd reads `docs/jtbd/` if present, advisory-only otherwise; (b) add a hard dep — tdd requires jtbd to be installed when traceability is enabled. Architect preference: soft dep, with ADR-002's graph updated to reflect the optional link. Blocking mode would require explicit user opt-in.
- [ ] Define graceful fallback when no `docs/jtbd/` exists: traceability check becomes advisory, not blocking; the skill prompt surfaces a recommendation to run `/wr-jtbd:update-guide`. Concreteness check still runs regardless. (ADR-008 Option 3 means there is no legacy-file fallback to defer to; migration via update-guide is the only path.)
- [ ] Map the invariant onto each supported framework: Jest/Vitest matchers that qualify/disqualify; Gherkin `Then` step shape; Bats `[[ ]]` patterns; pytest assertions; Go `testing` patterns.
- [ ] Decide the enforcement surface. Candidates: (a) extend the TDD gate to parse test files and flag violations (blocking, deterministic, per-file); (b) a specialist agent review invoked after test writes (advisory, slower); (c) both — gate catches the obvious cases, agent catches the subtle ones.
- [ ] Draft ADR — candidate `docs/decisions/012-test-content-quality-review.proposed.md` — must cover: (a) the framework-agnostic concreteness invariant; (b) JTBD traceability as a separate layer with its own advisory/blocking toggle; (c) the `@jtbd` annotation format reused from ADR-008; (d) cross-plugin dependency direction, updating ADR-002's dependency graph accordingly; (e) behaviour for projects without `docs/jtbd/` — advisory-only with update-guide prompt (no legacy single-file fallback per ADR-008 Option 3); (f) CI validation that cited JTBD IDs resolve to real entries; (g) the escape hatch for tests that legitimately guard cross-cutting invariants not owned by any single JTBD (e.g. security regressions).
- [ ] Decide relationship to P015. Likely: P015 becomes the Cucumber-specific adapter; this P018 owns the framework-agnostic rule. Could also be reversed (P018 supersedes P015). Decide as part of the ADR.
- [ ] Write fixture pairs per framework showing a vague test vs its Example-Mapping-compliant rewrite. These fixtures become the reproduction tests.

## Related

- Generalises: `docs/problems/015-tdd-vague-gherkin-detection.open.md` (Cucumber-specific case)
- Sibling: `docs/problems/013-tdd-feature-file-classifier.open.md` (other half of original P013)
- Canonical references:
  - Cucumber Example Mapping — https://cucumber.io/blog/bdd/example-mapping-introduction/
  - BDD (Dan North, original articulation) — the "Given/When/Then" form is a surface; the principle is "describe behaviour via concrete examples."
- `packages/tdd/hooks/lib/tdd-gate.sh` — current enforcement surface (state machine only)
- ADR 005 (proposed): `docs/decisions/005-plugin-testing-strategy.proposed.md` — natural parent/related decision
- ADR 002 (proposed): `docs/decisions/002-monorepo-per-plugin-packages.proposed.md` — dependency graph must be updated if tdd gains a (soft or hard) dep on jtbd
- ADR 008 (proposed): `docs/decisions/008-jtbd-directory-structure.proposed.md` — source of `@jtbd` annotation convention. Option 3 chosen 2026-04-20 (P019) makes `docs/jtbd/` the sole canonical layout; P018's traceability layer no longer needs a single-file fallback path.
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
