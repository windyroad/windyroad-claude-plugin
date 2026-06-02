# Problem 176: Agent-side I2 (no type-branching) coverage gap — SKILL.md type-branching invariant not behaviourally testable until skill-invocation harness lands

**Status**: Open
**Reported**: 2026-05-06
**Priority**: 6 (Medium) — Impact: 3 (Moderate) x Likelihood: 2 (Possible) — deferred (re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — depends on P012 skill testing harness shape)
**WSJF**: 0.75 — (6 × 1.0) / 8 — re-rated 2026-05-23: transitive via P012 (XL) per P076 (was 1.5 marginal-only)

## Description

ADR-060 (P170-driven) ships Phase 1 invariant **I2 (uniform problem ontology)**: a behavioural test asserts that `capture-problem` / `manage-problem` / `work-problems` / `review-problems` / `transition-problem(s)` exhibit identical control-flow shape regardless of `type` value — no skill carries a branch keyed on `type`. The test ships at the same time as the type-tag (load-bearing-from-the-start per ADR-051; per ADR-060 architect finding 2).

**Coverage shipped in P170 Slice 4 iter 2** (this ticket's parent commit): the I2 behavioural test (`packages/itil/scripts/test/i2-no-type-branching.bats`) covers all **pure-bash supporting scripts** that read problem-ticket frontmatter — `reconcile-readme.sh`, `update-problem-rfcs-section.sh`, `classify-readme-drift.sh`, `check-problems-readme-budget.sh`, `reconcile-rfcs.sh`, the new `migrate-problems-add-type.sh`. Each is exercised against two synthetic ticket-set variants (one `type: technical`, one `type: user-business`) and observable outputs (stdout / exit code / file mutations) are asserted isomorphic.

**Coverage gap not closed in iter 2**: the SKILL.md files themselves (`/wr-itil:capture-problem`, `/wr-itil:manage-problem`, `/wr-itil:work-problems`, `/wr-itil:review-problems`, `/wr-itil:transition-problem`, `/wr-itil:transition-problems`) are agent-driven instructions, not scripts. To behaviourally test that they exhibit identical control-flow regardless of `type`, you'd need to invoke each skill twice (one ticket-set per type variant) and assert observable agent action (file writes / commits / outputs / decision shape) is isomorphic. **The framework primitive that would make this possible — a skill-invocation test harness — does not yet exist** (P012 tracks the harness as the master ticket).

**P081 protection**: the alternative — structural grep on SKILL.md content searching for `if type == X` patterns — is explicitly forbidden by P081 (no structural grep on SKILL.md content). Per `feedback_behavioural_tests.md`: "Prefer behavioural tests over structural grep on SKILL.md/ADR/source content. Structural tests are 'wasteful and not real tests' (P081)." So the gap cannot be closed by a quick structural test; it depends on the harness landing.

**Why this is captured as a first-class ticket** (per architect review action 4, P170 Slice 4 iter 2): defers the agent-side coverage from "hidden in plain sight" to "named, ticketed, audit-trailed". Per ADR-052's escape-hatch contract (Surface 2 — in-file `tdd-review: structural-permitted (justification: <P-NNN>)` comment with cited harness-gap ticket), the deferral cites this ticket. Without P176 captured, the deferral is silent.

## Symptoms

- A future SKILL.md change that introduces a branch keyed on `type` (`if type == 'user-business' then ... else ...`) would not be caught by `i2-no-type-branching.bats` because the bats only tests pure-bash supporting scripts.
- The `## I2 enforcement` clauses in ADR-060 (Confirmation criterion 8 + Decision Outcome line on Type-as-workflow-split rejection) name the SKILL.md surface explicitly, but no automated test enforces it on that surface.
- Drift signal: a maintainer or contributor adds a type-conditional branch to `/wr-itil:capture-problem` SKILL.md (e.g. "if user-business, ask for persona; if technical, skip persona") believing it satisfies UX without violating I2. ADR-060 line 146 (Phase 3 type-conditional capture-flow differentiation rejected) governs this, but enforcement is policy-statement-shaped, not test-shaped.

## Workaround

Currently:

- **Code-review discipline**: any SKILL.md edit that adds branching logic gets architect-review per the global edit gate; the architect can spot type-conditional branches by reading the diff. Costs human attention every edit.
- **ADR-060 + this ticket as policy backstop**: Phase 3 type-conditional capture-flow differentiation is explicitly rejected in ADR-060 line 146; type-tag drift is named as a Reassessment trigger in ADR-060 § Reassessment Criteria. Deters the failure mode without preventing it.

Neither workaround is load-bearing. The harness gap remains.

## Impact Assessment

- **Who is affected**: project maintainer (silent drift risk in agent-driven SKILL.md surface); future contributors (no automated guardrail when extending capture-problem / manage-problem to handle user-business vs technical asymmetries).
- **Frequency**: Possible — depends on whether and when a contributor (or this agent) believes the I2 invariant is "for technical reasons only" and adds type-conditional UX. ADR-060 line 146 is the policy-text deterrent; deterrence is not enforcement.
- **Severity**: Moderate — drift here would re-introduce the workflow-split that I2 was load-bearing to prevent (per architect finding 2: "differs slightly at capture leaks into differs at lifecycle leaks into differs at WSJF by graceful drift"). Not blocking, but compounding once it starts.
- **Analytics**: count of `type` references inside SKILL.md files (excluding documentation prose); count of conditional logic blocks (`if`, `case`, branching directives) inside SKILL.md keyed on the type field.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems (deferred per ADR-022 Capture-Time Effort Deferral — ratings depend on P012 harness shape decision).
- [ ] Confirm P012 (skill testing harness scope) is the right master ticket. P012 § Description names the testing-harness-for-skills shape; this ticket is its first concrete I2-driven harness-gap citation. Update P012 with a forward-pointer to this ticket if validated.
- [ ] Survey other invariants in ADR-060 + future ADRs that depend on agent-side SKILL.md observable behaviour. If multiple invariants need agent-invocation-harness coverage, P012's WSJF rating may need re-rating upward.
- [ ] Investigate whether a lightweight middle-ground exists: a bats test that scrapes `*.md` files in `packages/itil/skills/*/SKILL.md` for explicit `type` token references, then classifies each occurrence as documentation-prose (acceptable) vs control-flow-directive (P081-violation if asserted as classification). Almost certainly P081-prohibited; document the rejection rationale here for future-reader benefit.

## Fix Strategy

(deferred — depends on P012 harness landing first)

## Implementation Tasks

(deferred — investigation tasks first)

## Dependencies

- **Blocks**: ADR-060 § Confirmation criterion 8 cannot reach full coverage on the SKILL.md surface until this ticket's harness lands. Confirmation criterion 8 closure currently relies on the pure-bash subset coverage shipped in P170 Slice 4 iter 2.
- **Blocked by**: P012 (skill testing harness scope undefined) — this ticket's fix depends on the harness primitive that P012 tracks. Re-rate P176 effort once P012's design lands.
- **Composes with**: P081 (no structural grep on SKILL.md — protects against a tempting "quick structural test" workaround), ADR-052 § Surface 2 escape-hatch contract (in-file justification cites this ticket), ADR-051 (load-bearing-from-the-start posture sets the bar for I2 test shape).

## Related

- **P170** — driver problem (RFC framework strain pattern); ADR-060 ships I2 invariant as Phase 1 confirmation criterion 8.
- **ADR-060** — `docs/decisions/060-problem-rfc-story-framework-with-mandatory-problem-trace-and-unified-problem-ontology.accepted.md` — Confirmation criterion 8 + Decision Outcome line 146 (Phase 3 type-conditional rejection).
- **P012** — `docs/problems/012-skill-testing-harness.open.md` — master ticket for skill testing harness scope; P176's fix depends on it.
- **P081** — no structural grep on SKILL.md content (prevents shortcut-around).
- **ADR-052** — `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md` — Surface 2 escape-hatch contract that documents the deferral.
- **`packages/itil/scripts/test/i2-no-type-branching.bats`** — the bats file that cites this ticket in its header comment block to convert the deferral from "hidden" to "named".
