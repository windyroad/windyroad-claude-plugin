# R009: Functional defects in shipped plugin behaviour

Software has bugs. A plugin ships logic that doesn't behave as the SKILL/agent/hook prose describes — wrong-branch evaluation, off-by-one, regex matcher missing a class, marker key-mismatch, hook returning wrong exit code, script behaviour diverging from documented contract. A defect in a published plugin reaches every adopter who installs the version.

This is the bedrock software-delivery risk class. R002 / R003 / R005 / R006 / R010 are *specialisations* — they name specific defect modes; R009 is the catch-all when no specialisation applies. Insufficient test coverage is treated here as a control gap, not a separate risk class.

## Recogniser

**Path patterns** (any match → consider this entry):

- `packages/*/skills/*/SKILL.md`, `packages/*/skills/*/REFERENCE.md`
- `packages/*/agents/*.md`
- `packages/*/hooks/*.sh`, `packages/*/hooks/lib/*.sh`
- `packages/*/scripts/*.sh`, `packages/*/scripts/lib/*.sh`
- `packages/*/bin/*` (shim wrappers)
- (any source file that produces runtime behaviour — broadest possible scope)

**Diff-content keywords** (consider when the diff suggests semantic-content shift, not pure refactor):

- `if`, `else`, `case` — branch logic added or removed
- regex patterns added or modified
- numeric literals changed (loop bounds, thresholds, timeouts)
- `exit N`, `return N` — exit/return code changes
- function signatures changed (arg order, default values, parameter additions)

**Anti-patterns** (looks like R009 but score under specialisation instead):

- Cross-doc consistency drift → **R002**
- Hook source change → **R003**
- Changeset coordination issue → **R005**
- Published-package referencing source-tree paths → **R006**
- Bump-class mis-classification → **R010**

R009 is the residual class: any defect that doesn't slot into a specialisation.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Defect introduced here |
| push | yes | cumulative |
| release | yes | cumulative; defect reaches adopters |
| external-comms | no | Not the outbound-prose lens |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 4 (Significant) — `RISK-POLICY.md` L64: "Installed plugins degrade developer workflow". Functional defects are this Impact class.
- **Likelihood**: 4 (Likely) — every code change risks defects; bedrock class with high inherent likelihood.
- **Inherent score**: 16
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| Behavioural bats per ADR-052 (`packages/*/{skills,agents,hooks,scripts}/test/*.bats`) | Bats coverage exists for the changed code path AND tests pass | 1 (broad path; covers the dominant tested-path subset) | -1 likelihood for tested paths | Bump +1 if no paired bats; consider also-flag as R009 sub-class explicitly |
| Architect / JTBD review on every Edit/Write | Project-file edit | 2 (broad design-class catch) | -1 likelihood for design-class defects | Bump +1 |
| Held-changeset / dogfood-window | Hook/skill changes get in-repo dogfood time before adopter exposure | 3 (sub-class: hook/skill surfaces) | -1 likelihood for that subset | Bump +1 for hook/skill surfaces if held-area not used |
| TDD red-green discipline (`tdd-enforce-edit.sh` + `tdd-post-write.sh`) | Edit on `.ts/.tsx/.js/.jsx` files (only ~5% of project surface) | n/a (subset-only path) | 0 paths project-wide (subset-band-reduction doesn't shift project residual) | n/a for non-TS/JS files |
| `tdd-review-test` classifier (P081) | New test file | n/a (advisory; test-classification only) | 0 paths | n/a |
| Pipeline scoring per RISK-POLICY.md | Every commit | n/a (meta-control surfacing not catching) | 0 paths | Lower visibility of structural failure modes |

Lifetime residual likelihood across the broad class = 2 (Unlikely) under bats + review + dogfood firing-and-passing.

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Code path has paired behavioural bats AND tests pass on this commit | -1 | Empirical coverage evidence |
| Code path has only structural bats (per ADR-052 Migration; legacy ~50 still accepted-until-touched) | +1 | "Test passes" signal weaker than it looks |
| Code path has NO paired bats (un-tested) | +2 | Defect can land undetected |
| Diff is pure refactor (no semantic change in behaviour) | -1 | Lower defect risk; bats coverage usually sufficient |
| Diff changes regex patterns / numeric thresholds / branch logic | +1 | High-defect-density change shape |
| Skill / agent prompt prose change (not script code) | +1 | Prompt behaviour is non-deterministic; behavioural test harder |
| Script change with filesystem side-effects NOT asserted in bats | +1 | Bats stdout/exit-code coverage may be incomplete |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 2 (Unlikely) — bats coverage on dominant tested-path subset + architect/JTBD review broad. TDD red-green covers only TS/JS subset. Project-wide weighted residual stays at 2.
- **Residual score**: 8
- **Residual band**: Medium — above appetite.

**Above appetite** — bedrock class; defect-free software is impossible. Realistic mitigation lowers residual incrementally as: (a) ADR-052 Migration retrofits legacy structural bats to behavioural; (b) Phase-2 promotion of `tdd-review-test` from advisory to commit-blocking; (c) coverage gaps in skill/agent prose surfaces close as harness for prompt-driven LLM behaviour matures (P012). Floor ~6 stays even with all three because Impact 4 + Likelihood 1 = 4 (at appetite floor).

## Watch-out

- When scoring, check whether the defect maps to a specialisation entry (R002/R003/R005/R006/R010) before naming it as generic R009. If it does, score against the specialisation — its controls and modulators are sharper.
- Defects in skill / agent prose (vs script code) are harder to test behaviourally — runtime is LLM-driven, output non-deterministic, structural assertions on prompt content are pragmatic but limited (per ADR-005 + P011 Permitted Exception).
- Held-changeset dogfood catches HOOK defects well (P085, P064, P159 are exemplars) but skill-prose defects often slip through because dogfood replays focus on documented steps, not edge cases.
- Coverage gap sub-classes: (a) new code lands without paired bats; (b) modified code's bats only assert stdout/exit-code, missing filesystem side-effects on the same path; (c) ~50 legacy structural bats give a "test passes" signal that's weaker than it looks. Phase-2 trigger in ADR-052 Reassessment Criteria — un-annotated structural count drops to 0 OR advisory-skip rate exceeds 20% sustained — is when `tdd-review-test` promotes from advisory to blocking.

## See also

- **Specialisations**: R002 (drift), R003 (hook regression), R005 (release coordination), R006 (publish-boundary), R010 (semver violation) all narrow R009 to specific defect modes.
- **Drivers / ADRs**: ADR-052 (behavioural-tests default; supersedes ADR-037), ADR-005 (Permitted Exception narrative), P011 (Permitted Exception driver), P081 (review-test classifier driver), P012 (Skill testing harness scope undefined — Layer-B framework primitives blocker).
