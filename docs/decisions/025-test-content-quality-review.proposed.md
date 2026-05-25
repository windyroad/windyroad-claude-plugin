---
status: "proposed"
date: 2026-04-20
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-20
---

# Test content quality review — concreteness + traceability (JTBD or Problem) invariant for `@windyroad/tdd`

## Context and Problem Statement

The `@windyroad/tdd` plugin currently enforces only a state machine — that a test file exists, goes RED (fails), then goes GREEN (passes) — and that the RED→GREEN transition traces to a meaningful edit. It does not enforce what a *good* test looks like.

Two classes of defect slip through silently:

**(P015 — Gherkin surface)** Cucumber's natural-language `.feature` files make it easy to write `Then` steps that look like assertions but don't assert anything concrete. Example: `Then the address detail will have related links` — the final `Then` promises specific outcomes (locality/postcode/state) in the scenario title but asserts only the category. A step definition that returns `true` whenever *any* link exists passes.

**(P018 — framework-agnostic surface)** The same defect appears in Jest (`expect(result).toBeTruthy()`), Vitest, Mocha, bats, pytest, and Go `testing`. A test whose name describes an outcome in the abstract ("handles the error case", "returns the user", "works") with an assertion that checks only truthiness or existence is a rule without an example. The rule is named, the example is missing, a trivial implementation passes.

Both classes are instances of the same invariant violation. P018's investigation notes explicitly frame P015 as the Cucumber-specific adapter of P018's framework-agnostic rule; the user has confirmed "one combined ADR." This ADR closes both.

Separately, tests today are not required to trace to any documented user outcome. A test can be perfectly concrete and still be guarding a rule no user actually depends on — implementation detail masquerading as behaviour. P018 calls for tests to cite a Job-To-Be-Done so the chain `test → example → JTBD → persona outcome` is unbroken. The user's direction — on the question of cross-cutting tests (security regressions, performance baselines) that do not fit a single JTBD — is unambiguous: "if it's cross cutting, e.g. performance, shouldn't there be a JTBD or problem that it's related to?" So Problem IDs (`P-NNN`, per the ITIL plugin's ticket convention) are first-class traceability targets alongside JTBD IDs.

## Decision Drivers

- **JTBD-002** (Ship AI-Assisted Code with Confidence) — "the agent cannot bypass governance" is the core promise. Vague tests that pass the gate silently erode that promise. Concreteness-blocking closes the "tests go green, regression slips through" failure mode.
- **JTBD-001** (Enforce Governance Without Slowing Down) — the traceability rule forces tests to cite a JTBD or Problem ID, which IS the governance record. "Without slowing down" is preserved via graceful fallback: when neither `docs/jtbd/` nor `docs/problems/` exists in the project, traceability is advisory-only and only concreteness is blocking.
- **JTBD-003** (Compose Only the Guardrails I Need) — the test-quality rule is itself a composable guardrail. Per jtbd-lead review, this ADR is an additive fit for JTBD-003's composability promise.
- **JTBD-101** (Extend the Suite with Clear Patterns) — a framework-agnostic invariant with Cucumber as one application is the "clear patterns, not reverse-engineering" promise for plugin developers extending the suite.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — the test → example → JTBD-or-Problem → persona chain strengthens the tech-lead persona's post-incident audit trail. Failed tests now point directly at the documented job or problem they defend.
- **P015** — Cucumber-specific detection of vague `Then` steps; the concrete observed failure mode that motivated this ADR.
- **P018** — framework-agnostic rule; the generalisation of P015.
- **P022** — fabricated time estimates; shares the "evidence-before-claims" pattern that ADR-025 applies to test assertions.
- **P037** — JTBD reviewer output contract; precedent for explicit contract-based enforcement rather than relying on author discipline.

## Considered Options

1. **Both layers blocking; concreteness always, traceability conditional; gate + agent; no escape hatch** (chosen) — The quadruplet (cited-JTBD-or-Problem, named-rule, specific-input, specific-expected-output) is the invariant. Concreteness (input + expected output) is blocking always. Traceability (JTBD or Problem citation) is blocking when `docs/jtbd/` OR `docs/problems/` exists in the project; advisory when neither exists (graceful fallback). Enforcement is gate + specialist agent. No escape hatch: cross-cutting tests cite catch-all JTBDs or Problem tickets.

2. **Concreteness blocking, traceability advisory** — the originally-recommended option. Rejected by the user in favour of blocking both when governance docs exist.

3. **Both advisory (agent review only)** — lowest friction, insufficient for P018's "regressions slip through" risk.

4. **Both blocking unconditionally, hard-dep on `@windyroad/jtbd`** — hardest stance; forces every consumer to adopt JTBD docs before they can write tests. Rejected because it breaks the graceful-adoption pattern ADR-008 establishes.

5. **Escape hatch via `@cross-cutting` annotation** — the originally-recommended option for cross-cutting tests. Rejected by the user: "if it's cross cutting, e.g. performance, shouldn't there be a JTBD or problem that it's related to?" The user's direction is that cross-cutting concerns have their own JTBDs or Problems, and the citation is not optional.

## Decision Outcome

Chosen option: **Option 1 — Both layers blocking; concreteness always, traceability conditional; gate + agent; no escape hatch.**

Rationale:
- Both-blocking on concreteness closes the P015/P018 "tests go green, regression slips through" failure mode definitively.
- Both-blocking on traceability (when docs exist) honours JTBD-002's "agent cannot bypass governance" promise without coupling the TDD plugin to the JTBD plugin at the package level — the dep remains soft per ADR-002.
- Graceful fallback on traceability respects JTBD-001's "without slowing down" when a project has not yet adopted JTBD or ITIL governance.
- No escape hatch forces the project's governance graph (JTBDs + Problems) to cover the full surface being tested. Projects may legitimately introduce catch-all JTBDs (`JTBD-999 Security Regressions`) or catch-all Problem tickets; the specialist agent review is the check against semantic abuse of those catch-alls.

### Scope

**In scope (this ADR):**

- **Invariant**: every test MUST contain a quadruplet (cited-JTBD-or-Problem-ID, named-rule, specific-input, specific-expected-output). The four components:
  - **cited-JTBD-or-Problem-ID** — the test file or test-case body MUST contain an annotation matching `JTBD-\d{3}` or `P\d{3}`. Accepted annotation forms (see `@jtbd:` from ADR-008 as parent; `@problem:` mirrors for ticket IDs introduced by ADR-010):
    - Code comment above or inside the test: `// @jtbd: JTBD-002`, `// @problem: P046`, `# @jtbd: JTBD-002`, `-- @jtbd: JTBD-002`, `/* @jtbd: JTBD-002 */`.
    - Gherkin scenario tag: `@jtbd:JTBD-002` or `@problem:P046` on the scenario or feature.
    - Describe/it string or test name: inline citation `describe('foo [JTBD-002]', ...)` or `@test "foo @jtbd:JTBD-002"`.
    - Exact regex: `(@jtbd:?\s*JTBD-\d{3})` or `(@problem:?\s*P\d{3})` or `(JTBD-\d{3})` or `(P\d{3})` appearing in the test file within the scope of the test case.
  - **named-rule** — the test's name (describe/it/scenario string, or `@test` name in bats) MUST name the rule being tested, not just the function under test. The specialist agent review catches name-without-rule cases; the gate does not enforce this layer deterministically.
  - **specific-input** — the test's Arrange step MUST include at least one literal value, a data-table row, a doc-string reference, or a named capture that the assertion references. Property-based tests satisfy this when paired with explicit concrete examples per the Example Mapping principle.
  - **specific-expected-output** — the test's assertion MUST reference a literal value, a structural predicate with literal fields, or a named data-table row. Forbidden patterns (gate-detected): `toBeTruthy()`, `toBeDefined()`, `toBeNull()`, `not.toBeNull()`, `toBeInstanceOf(<type>)`-only, `toHaveProperty(<name>)` without value, Gherkin `Then <subject> will have <thing>` without quoted/tabled value.

- **Concreteness layer — blocking always**: the TDD gate detects the forbidden-pattern list above on each test-file write. Violations deny the write with the reason that cites the detected pattern. Applies regardless of whether `docs/jtbd/` or `docs/problems/` exist.

- **Traceability layer — conditionally blocking**:
  - If `docs/jtbd/` exists OR `docs/problems/` exists in the project → **blocking**. The gate scans the test file for an annotation matching the regex above. If none found within the scope of a test case, denies with a reason that names the required annotation forms and points at ADR-025 for rationale.
  - If NEITHER directory exists → **advisory**. Gate does not block; the specialist agent review (on test-file write) emits an advisory `JTBD / Problem traceability: no docs/jtbd/ or docs/problems/ in project — advisory skipped` note in its output.
  - **Partial state** (one directory exists, the other does not) — rule activates as soon as *either* directory exists. The annotation may reference either namespace regardless of which directory is present. Example: a project with `docs/jtbd/` but no `docs/problems/` still accepts `@problem:P046` if the author chooses to file a problem ticket (which creates `docs/problems/` in the same commit).
  - **Annotation-resolves check** — the specialist agent review verifies the cited ID actually resolves to an entry in `docs/jtbd/` or `docs/problems/`. Gate does NOT enforce resolution (too expensive for per-write); agent advisory catches orphan citations.

- **Soft cross-plugin dependency**: `@windyroad/tdd` reads `docs/jtbd/` and `docs/problems/` if present. No `package.json` `dependencies` entry is added to `@windyroad/tdd` — the coupling is purely filesystem-based so the ADR-002 dependency graph stays unchanged.

- **Enforcement surface — gate + agent**:
  - **TDD gate** (deterministic, per test-file write, blocking): greps the test file for the forbidden concreteness-violation patterns and for the traceability annotation. The gate operates on **test files**, not on source files — it is a metadata/structural assertion, NOT a behavioural assertion against source code. This distinction is explicit so ADR-005's "behavioural tests must not grep source" rule is not violated.
  - **Specialist agent** (LLM-based, per test-file write, advisory): reviews the test content for subtle cases the gate cannot detect — named-rule vs abstract outcome, specific-input adequacy, semantic abuse of catch-all JTBDs/Problems. The agent's output follows the P037 contract (structured inline verdict, required remediation on FAIL).
  - **Agent marker caching per ADR-009**: the agent review caches its verdict per test file with a TTL+drift marker (per ADR-009's gate-marker-lifecycle pattern). TTL default per ADR-009. Drift hash includes the test file's content + the project's `docs/jtbd/README.md` and `docs/problems/README.md` modification times (so JTBD-renames or Problem-ticket edits invalidate cached verdicts). This is per the architect advisory — running the agent unconditionally per-test-write would inflate TDD's inner loop.

- **Framework mapping**:
  - **Jest / Vitest / Mocha**: matchers `toBeTruthy / toBeDefined / toBeNull / toBeInstanceOf (alone) / toHaveProperty (no-value)` flagged; annotation in describe/it string or code comment.
  - **Cucumber / Gherkin (P015 adapter)**: `Then` steps with no quoted literal, number, data-table row, or docstring ref flagged; annotation as scenario/feature `@jtbd:JTBD-NNN` or `@problem:P-NNN` tag.
  - **bats**: `[[ ]]` with only existence checks (`-f`, `-d`, `-n`, `-z` alone) flagged; annotation as test-name suffix or comment.
  - **pytest**: `assert x`, `assert x is not None`, `assert isinstance(x, T)` alone flagged; annotation as pytest marker `@pytest.mark.jtbd("JTBD-002")` or docstring.
  - **Go `testing`**: `if got == nil`, `if !reflect.DeepEqual(got, want)` without `want` literal flagged; annotation as `// @jtbd:` comment.

- **New specialist agent**: `packages/tdd/agents/test-quality-reviewer.md`. Follows P037 output contract. Runs on PostToolUse for test-file writes.

- **Gate extension**: `packages/tdd/hooks/tdd-gate.sh` gains a concreteness + traceability check. Reuses ADR-009's gate-marker-lifecycle pattern for its caching.

- **ADR-005 relationship**: ADR-025 **supplements** ADR-005, does not supersede. ADR-005 is about how the plugin suite tests itself (bats hooks in CI). ADR-025 is about what tests consumer projects must write when they use `@windyroad/tdd`. Different domains; call out in the Context section of ADR-025 (this ADR) and cross-reference from ADR-005's Related Decisions.

- **Bats test**: `packages/tdd/hooks/test/tdd-gate-concreteness.bats` + `packages/tdd/hooks/test/tdd-gate-traceability.bats` exercise the forbidden-pattern list and the traceability regex. `packages/tdd/agents/test/test-quality-reviewer-contract.bats` asserts the agent prompt.

**Out of scope (follow-up tickets or future ADRs):**

- `@jtbd` annotation resolution at CI time (validating that cited IDs exist in `docs/jtbd/README.md` or `docs/problems/README.md` across the entire repo). Agent advisory handles this per-file; repo-wide CI validation is a follow-up.
- Property-based test invariant enforcement beyond the paired-concrete-example requirement. A future ADR may extend to property-test invariant documentation as a first-class shape.
- Semantic validation that the cited JTBD/Problem actually covers the rule the test guards (agent advisory catches blatant mismatch; automated semantic-fit check is out of scope).
- ADR-005 updates to its own test strategy (this ADR does not modify ADR-005's scope).

## Consequences

### Good

- Tests ship with the chain `test → example → JTBD-or-Problem → persona outcome` intact. JTBD-002's "agent cannot bypass governance" promise holds against vague-test-through-the-gate failure mode.
- Cross-cutting tests (security, performance, migration) cite a catch-all JTBD or Problem ticket that makes their coverage first-class-visible in the governance graph.
- Graceful fallback (advisory-only when no governance docs exist) lets new projects adopt `@windyroad/tdd` without pre-committing to JTBD/ITIL adoption.
- P015's Cucumber detection and P018's framework-agnostic rule ship as one coherent contract — no duplicate rationale across two ADRs.
- Agent + gate composition gives defense-in-depth: gate catches obvious pattern violations fast; agent catches subtle cases with richer context.
- ADR-009's TTL+drift caching pattern keeps the agent review's inner-loop cost bounded; the agent does not run unconditionally per-test-write.

### Neutral

- `@windyroad/tdd` reads filesystem paths (`docs/jtbd/`, `docs/problems/`) owned by other plugins. No package dep added; filesystem coupling is deliberate and documented.
- The forbidden-pattern list is framework-heuristic and will grow as new matchers / idioms emerge. Bats tests pin the current list; additions are ADR-025 amendments, not new ADRs.
- The specialist agent's LLM-based review adds per-write latency. ADR-009 TTL+drift caching mitigates, but downstream projects may see measurable TDD-inner-loop latency increase. Reassessment criterion below fires if this becomes loop-stopping.

### Bad

- **No-escape-hatch failure mode**: teams under pressure may add catch-all JTBDs/Problems (`JTBD-999 Everything`, `P-000 Placeholder`) to satisfy the gate without genuine governance intent. Mitigation: the specialist agent review is explicitly charged with detecting semantic abuse of catch-alls (a test citing `JTBD-999 Everything` gets flagged as an advisory issue requiring human review). The gate alone cannot detect this; the agent's presence is load-bearing for this failure mode.
- Hard on-ramp for projects that have adopted `@windyroad/tdd` but not `@windyroad/jtbd` or `@windyroad/itil`. Those projects get the graceful fallback (traceability advisory). If they subsequently add `docs/jtbd/` or `docs/problems/` — e.g. by running `/wr-jtbd:update-guide` or opening their first problem ticket — traceability silently flips to blocking. This is intentional (governance adoption should tighten enforcement) but authors should be aware.
- Forbidden-pattern list false-positives: a legitimate test asserting "this thing is defined" (rare but valid, e.g. feature-flag presence checks) trips the gate. Mitigation: the specialist agent review can emit an `advisory PASS with justification` for manually-reviewed false-positives; the ADR does not include a blanket override annotation, so each case is reviewed.
- First plugin to combine two enforcement surfaces around a single invariant. Precedent established by this ADR (gate + agent with ADR-009 caching for the agent). Future similar decisions may want to cite this ADR as the pattern.

## Confirmation

Compliance is verified by:

1. **Source review:**
   - `packages/tdd/hooks/tdd-gate.sh` implements the concreteness pattern check and the traceability annotation grep.
   - `packages/tdd/agents/test-quality-reviewer.md` follows the P037 structured-verdict contract.
   - Neither the gate nor the agent imports from `@windyroad/jtbd` or `@windyroad/itil`; both read filesystem paths only. `packages/tdd/package.json` contains no new `dependencies` entries.
   - ADR-009 marker-caching pattern is applied to the agent review (TTL + drift hash).

2. **Test (bats):**
   - `packages/tdd/hooks/test/tdd-gate-concreteness.bats` asserts each forbidden pattern triggers a deny and each permitted pattern passes.
   - `packages/tdd/hooks/test/tdd-gate-traceability.bats` asserts: blocks when `docs/jtbd/` OR `docs/problems/` exist AND annotation is missing; permits when annotation is present; does not block when neither directory exists.
   - `packages/tdd/hooks/test/tdd-gate-traceability.bats` also covers the **partial state** case: project with `docs/jtbd/` but no `docs/problems/` still activates the rule; annotation referencing either namespace accepted.
   - `packages/tdd/agents/test/test-quality-reviewer-contract.bats` asserts the agent prompt contains: the quadruplet invariant; the catch-all-abuse detection charge; the P037 structured-verdict contract; the ADR-009 caching guidance.

3. **ADR-005 boundary statement**: ADR-005 is not modified by this ADR. ADR-025's Context section explicitly calls out the scope distinction (ADR-005 = plugin suite's self-testing; ADR-025 = consumer projects' test content) so readers do not misinterpret.

4. **ADR-008 annotation-convention extension**: ADR-008's `@jtbd:` annotation is the parent convention. `@problem:` mirrors it, introduced here (ADR-025) to cover the ITIL plugin's ticket namespace (ADR-010 is the ITIL plugin's own naming precedent). The regex in this ADR is the authoritative acceptance grammar until a follow-up ADR supersedes.

5. **Behavioural replay**: exercise the gate + agent on fixture tests representing each framework's forbidden-pattern list (Jest `toBeTruthy()`, Gherkin `Then X will have Y`, bats `[[ -f file ]]`, pytest `assert x`, Go `if got == nil`). Verify the gate denies and the agent provides remediation per the P037 contract.

6. **Annotation-grep vs behavioural-grep distinction (ADR-005 compliance)**: the gate's regex runs on **test files** as a metadata assertion (does this test carry a governance annotation?). ADR-005's rule that "behavioural tests must not grep source" applies to assertions about source code behaviour, not to metadata assertions about test files themselves. ADR-025's Confirmation section restates this distinction so reviewers do not flag the gate as an ADR-005 violation.

## Pros and Cons of the Options

### Option 1: Both layers blocking; concreteness always, traceability conditional; gate + agent; no escape hatch (chosen)

- Good: closes both P015 and P018 with one invariant; no duplicate rationale.
- Good: graceful fallback for pre-governance projects (concreteness-only) preserves JTBD-001 "without slowing down".
- Good: filesystem-only coupling keeps ADR-002 dependency graph clean.
- Good: ADR-009 caching pattern bounds the specialist agent's inner-loop cost.
- Good: no escape hatch forces the governance graph to be complete.
- Bad: catch-all-abuse failure mode exists; mitigation depends on the agent review being present and working.
- Bad: hard on-ramp when a pre-governance project adopts docs/jtbd/ or docs/problems/ — traceability silently flips to blocking.

### Option 2: Concreteness blocking, traceability advisory

- Good: gentler adoption; projects can ship without JTBD/ITIL docs.
- Bad: loses the "every test cites a user outcome" audit chain — JTBD-002's governance promise weakens.
- Bad: under-serves JTBD-201 (tech-lead audit trail) in post-incident reviews.

### Option 3: Both advisory (agent review only)

- Good: minimum friction; no gate denies.
- Bad: insufficient for P018's "regressions slip through" risk — the user has explicitly rejected this for governance contexts.

### Option 4: Both blocking unconditionally, hard-dep on `@windyroad/jtbd`

- Good: most uniform enforcement.
- Bad: breaks the graceful-adoption pattern in ADR-008; couples tdd to jtbd at the package level, changing ADR-002's dependency graph.
- Bad: projects adopting `@windyroad/tdd` first (before JTBD) cannot write any tests. High friction.

### Option 5: Escape hatch via `@cross-cutting` annotation

- Good: explicit channel for legitimately-cross-cutting tests.
- Bad: user has rejected this — cross-cutting concerns SHOULD map to a JTBD or Problem ticket, and a "no relevant job/problem" annotation is evidence the governance graph is incomplete, not that the test is special.

## Reassessment Criteria

Revisit this decision if:

- **False-positive rate on the forbidden-pattern list exceeds ~5%** in practice (measured via advisory-PASS-with-justification cases in the specialist agent review log). That signals the pattern list needs structural refinement or framework-specific escape hatches.
- **Consumer projects repeatedly request a per-test escape hatch** to opt a single test out of concreteness OR traceability. That signals either (a) the pattern list is too aggressive, or (b) the user's no-escape-hatch direction needs revisiting.
- **Framework coverage needs to expand beyond the six listed** (Jest/Vitest/Mocha, Gherkin, bats, pytest, Go). Each new framework is an ADR-025 amendment rather than a new ADR, unless a fundamentally different invariant emerges.
- **TDD inner-loop latency** becomes loop-stopping because the specialist agent runs too often. Options: tighten ADR-009 caching TTL, batch agent reviews, or restrict agent to on-demand invocation (falling back to gate-only for per-write).
- **Catch-all-abuse is pervasive** — the specialist agent flags it on a significant fraction of tests. That signals the no-escape-hatch policy is creating more governance noise than governance; an ADR-025 amendment may need to introduce a bounded, reviewed escape hatch.
- **A second plugin needs to combine a deterministic gate with a specialist agent around one invariant.** That signals the pattern is reusable and warrants extraction into a cross-cutting ADR on "gate-plus-agent composition" — ADR-025 is the first instance and can be cited as precedent.
- **ADR-005 scope changes** to include consumer-project test-strategy requirements. At that point ADR-025 and ADR-005 should be reviewed together.
- **`@jtbd:` / `@problem:` annotation conventions evolve** (e.g., ADR-008 or ADR-010 revises its annotation grammar). ADR-025's regex must stay in sync.

## Related

- **P015** — Cucumber-specific vague-`Then`-step detection; this ADR is the parent rule that P015 becomes an adapter of.
- **P018** — TDD BDD + Example Mapping with JTBD traceability; this ADR is P018's chosen fix path.
- **P022** — fabricated time estimates; shares the "evidence-before-claims" pattern. ADR-025 applies the principle to test assertions; a future ADR for P022 applies it to agent output.
- **P037** — JTBD reviewer output contract; the specialist agent in this ADR follows the same structured-verdict contract.
- **P055** — upstream problem-reporting contract; unrelated in content but shares the ADR-cycle of this batch.
- **ADR-002** (Monorepo per-plugin packages) — dependency graph is unchanged by this ADR; filesystem-only coupling.
- **ADR-005** (Plugin testing strategy) — **supplemented, not superseded**. ADR-005 covers plugin-suite self-testing; ADR-025 covers consumer-project test content.
- **ADR-008** (JTBD directory structure) — parent of the `@jtbd:` annotation convention this ADR extends.
- **ADR-009** (Gate marker lifecycle) — the specialist agent's review caches a verdict per test file using this TTL+drift pattern.
- **ADR-010** (Rename wr-problem to wr-itil) — introduces the `docs/problems/` namespace this ADR's `@problem:` annotation references.
- **ADR-015** (On-demand assessment skills) — precedent for LLM-based governance review; cited as influence on the specialist agent's shape.
- **JTBD-001**, **JTBD-002**, **JTBD-003**, **JTBD-101**, **JTBD-201** — personas whose needs drive this ADR. JTBD-002 primary.
- `packages/tdd/hooks/tdd-gate.sh` — current TDD gate; ADR-025 extends it.
- `packages/tdd/` — target plugin for the new agent + gate extension.
