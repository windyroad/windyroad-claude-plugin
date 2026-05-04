# Risk Catalogue

Memory aid for the risk-scorer agent: known risk classes + their typical controls + inherent/residual scoring per `RISK-POLICY.md`. Reading the catalogue at scoring time saves re-deriving them and reduces the chance of forgetting a class previously surfaced. The inherent → residual gap shows where additional controls would pay back the cost.

## Residual semantics

Catalogue residuals reflect "**controls firing-and-passing**" — i.e. the per-action lens, matching how the pipeline scorer empirically computes residual on a real action that triggered the class. This is the residual that should be reconcilable with `.risk-reports/` outputs.

A second reading exists: `RISK-POLICY.md` `## Control Composition` strict path-counting (1/2/3+ independent paths → 1/2/3 bands). Where the two readings diverge meaningfully, the entry calls it out. The strict reading is more conservative; the per-action reading is what the gates and scorer actually achieve in practice.

An above-appetite catalogue residual is a real signal: it means "even when controls fire-and-pass, the typical instance of this class still sits above appetite". That's where additional controls (or a stronger control class) is genuinely needed.

## Entries

| ID | Class | Inherent | Residual | Gap |
|----|-------|----------|----------|-----|
| [R001](R001-confidential-disclosure-in-outbound-prose.md) | Confidential / business-metric disclosure in outbound prose | 12 (High) | 3 (Low) | -9 |
| [R002](R002-documentation-and-index-drift.md) | Documentation / index / cross-reference drift across docs | 12 (High) | 6 (Medium) | -6 |
| [R003](R003-hook-regression-shipped-to-adopters.md) | Hook regression / behaviour change ships to adopters | 16 (High) | 4 (Low) | -12 |
| [R004](R004-ambient-unstaged-state-in-commits.md) | Ambient unstaged state included in commits | 6 (Medium) | 2 (Very Low) | -4 |
| [R005](R005-release-coordination-changeset-drift.md) | Release-coordination / changeset queue drift | 9 (Medium) | 3 (Low) | -6 |
| [R006](R006-published-package-vs-source-tree-divergence.md) | Published-package references source-tree-only paths and IDs | 20 (Very High) | 8 (Medium) | -12 |
| [R007](R007-user-stated-preconditions-paired-capability.md) | User-stated preconditions / paired-capability check | 12 (High) | 4 (Low) | -8 |
| [R008](R008-credentials-in-committed-files.md) | Credentials / secrets in committed files | 15 (High) | 5 (Medium) | -10 |
| [R009](R009-functional-defects-in-shipped-behaviour.md) | Functional defects in shipped plugin behaviour (bedrock) | 16 (High) | 8 (Medium) | -8 |
| [R010](R010-semver-or-backward-compatibility-violation.md) | Semver / backward-compatibility violation on plugin contracts | 12 (High) | 4 (Low) | -8 |

## Within appetite (residual ≤ 4/Low)

R001, R003, R004, R005, R007, R010 — controls stack working; further reduction has diminishing returns.

## Above appetite — where we need more controls

| ID | Residual | Why above appetite + next milestone |
|----|----------|--------------------------------------|
| **R002** | 6 (Medium) | Some drift sub-classes (ADR-vs-ADR; sort-spec across N render-block sites) have only retro-time advisory coverage, no load-bearing hooks. P161 observation tracks the drift-class generalisation pattern; additional load-bearing detectors would drop residual to 3/Low. |
| **R006** | 8 (Medium) | Controls (ADR-049 shim, ADR-055 prefix, P154 detector) are mostly **advisory at retro time, not blocking at commit time**. Production evidence: `@windyroad/itil@0.23.2 → 0.24.0` shipped broken bin shims through 5 versions before the npm-pack-extension detector caught it. Phase-2 promotion to commit-blocking (per the P159 / ADR-051 load-bearing-from-the-start pattern) drops residual to 4/Low. |
| **R008** | 5 (Medium) | Impact 5 (Severe) caps residual at 5 even with Likelihood 1 (Rare). No additional detection control will drop residual below 5. Treatment is post-incident: rotation-runbook readiness for WHEN-not-IF the gate's false-negative rate eventually fires. |
| **R009** | 8 (Medium) | Bedrock class — defect-free software is impossible. Coverage gaps are real (skill-prose surfaces don't get behavioural-tested; ~50 legacy structural bats are accepted-until-touched per ADR-052 Migration). ADR-052 Migration retrofit + Phase-2 `tdd-review-test` promotion + harness-maturity (P012) drop residual incrementally; floor ~6 stays. |

## Adding to the catalogue

Identifying a new class during scoring? Author it via `/wr-risk-scorer:create-risk` (interactive) or `/wr-risk-scorer:create-risk --slug <slug>` (orchestrator-driven from an ADR-056 hint).

The catalogue is self-pruning: when a class stops surfacing in `.risk-reports/` (controls have made it rare), retire its entry by renaming `R<NNN>-<slug>.md` to `R<NNN>-<slug>.retired.md`. Git history preserves the prior content.
