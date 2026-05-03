---
status: proposed
date: 2026-05-03
deciders: solo-developer
consulted: wr-architect:agent (PASS-WITH-NOTES; 4 notes folded in), wr-jtbd:agent
informed: plugin-developer (composes-with future cluster ADRs)
---

# ADR-057: Three-phase declarative-first rollout for cluster-shaped governance rules

## Context and Problem Statement

Six ADRs landed in this session (2026-05-02 to 2026-05-03) all share the same 3-phase rollout shape:

| ADR | Driver Ticket | Phase 1 (contract) | Phase 2 (advisory) | Phase 3 (rollout) |
|-----|---------------|---------------------|---------------------|---------------------|
| ADR-049 | P151 | bin/-on-PATH normative resolution rule | grep-as-lint cross-plugin assertion | (not yet escalated) |
| ADR-051 | P152 | JTBD-anchored README with required `## Jobs to be Done` section | `check-readme-jtbd-currency.sh` advisory | R6-gated load-bearing hook deferred |
| ADR-052 | P081 | behavioural-tests-default for skill testing | `tdd-review-test.sh` PostToolUse advisory hook | promotion to PreToolUse gate deferred |
| ADR-053 | P087 | plugin maturity taxonomy (Experimental/Alpha/Beta/Stable/Deprecated) | (Phase 2 measurement-mechanism deferred to next iter) | retroactive labelling + load-bearing badge deferred |
| ADR-054 | P097 | SKILL.md runtime budget thresholds (≤ 20 / ≤ 1.6 KB pointer ceiling) | `check-skill-md-budgets.sh` advisory | retroactive extraction + R6-gated promotion deferred |
| ADR-055 | P137 | namespace-prefixed-permalinks rule (ADR-NNN → WR-ADR-NNN) | namespace-prefix advisory + measurement | Phase 2 mechanical sweep + R6 escalation deferred |

The shape is empirically the same across all six. Iters 14, 15, and 17 each independently flagged the pattern as warranting codification. Without an explicit codification, future cluster-class governance ADRs are written ad-hoc: the load-bearing-ness of declarative-first + advisory-second + rollout-third (the anti-BUFD shape that preserves user-recovery paths and avoids day-one blocking-hooks) is implicit rather than explicit. New ADRs in this family may shortcut to a load-bearing hook on day one and lose the advisory-first observation period that has empirically caught design issues across all six instances.

ADR-040 (declarative-first-then-enforce) established the underlying principle — but at single-rule grain. ADR-057 narrows ADR-040 to the cluster-class variant where the rule applies to ALL artefacts in a class and drift is countable.

## Decision Drivers

- **Anti-BUFD principle** — designing the rule before any tooling exists is correct (Phase 1 contract); designing the load-bearing hook before observing the advisory's drift count is wrong (Phase 3 follows Phase 2 measurement, not vice versa).
- **ADR-013 Rule 6 fail-safe** — advisory exit-0 always preserves user-recovery path on first-day rollout. Phase 2 cannot block.
- **ADR-040 declarative-first** — already-established principle at single-rule grain. ADR-057 narrows to cluster classes.
- **P135 R6 escalation precedent** — numeric gate (e.g. drift_instances trend across N consecutive retros / releases) drives the Phase 3 trigger. The R6 numeric-gate concept is portable; ADR-057 specifies the FORM not the THRESHOLD.
- **6 empirical instances this session** — pattern is observably load-bearing without a single counter-example. Iter-14's "second-occurrence-triggers-helper-extraction" precedent applies a fortiori; codification at 6 is conservative.

### Necessary conditions for "cluster-shaped"

ADR-057 applies when ALL three conditions hold:

1. **Class membership** — the rule applies to all artefacts matching a definable class (path-glob, package-glob, or named-class like "all SKILL.md files" / "all `@windyroad/*` plugins" / "all bin/wr-`<plugin>`-`<name>` shims"). A single-rule decision (one file, one config setting, one path) does NOT satisfy this; it falls under ADR-040 at single-grain instead.
2. **Class size at codification time** — the class has at least 3 instances when the Phase 1 ADR is written. Below 3, the rule is effectively single-rule per ADR-040; the cluster-shape investment is premature.
3. **Drift is countable** — the advisory script must emit a numeric drift count (e.g. `RETRO YYYY-MM-DD <name> drift=<N>` or `TOTAL drift_instances=<K>`). Without a numeric, R6's escalation gate has no signal to trigger on; Phase 3 cannot fire.

If any of these fail, the decision falls under ADR-040 single-rule grain or under a different pattern entirely (see "Negative space" below).

## Considered Options

1. **Codify as ADR-057 (Recommended)** — name the 3-phase shape explicitly so future cluster-class ADRs follow it intentionally. ADR-040 is the parent; ADR-057 is the cluster-narrowing.
2. **Wait for 7th instance** — defer per "second-occurrence-triggers-helper-extraction" applied as 7th-instance-codification. Pattern is descriptive at 6; prescriptive only when needed.
3. **Skip** — the pattern is well-documented inline across the 6 individual ADRs; meta-ADR adds maintenance overhead without changing behaviour.

## Decision Outcome

Chosen option: **1 — Codify as ADR-057**.

For cluster-shaped governance rules satisfying the three necessary conditions above, the canonical rollout shape is:

**Phase 1 — Contract-first**: a normative ADR codifies the rule. Status: proposed. MADR-conformant: Decision Drivers, Considered Options (≥2), Decision Outcome, Consequences, Confirmation, More Information, Reassessment Triggers. The rule is well-specified before any tooling exists. No advisory script, no hook, no enforcement layer.

**Phase 2 — Measurement-second**: a per-package advisory script (bash, exit-0 always per ADR-013 Rule 6 + ADR-040 declarative-first) computes a baseline drift count against the rule. Behavioural bats per ADR-005 / ADR-052. Phase 2 is purely descriptive — surfaces drift instances without blocking adopter or contributor workflows. The advisory is invoked from `/wr-retrospective:run-retro` Step 2b cross-reference (when wired) and/or as a release-time pre-publish smoke test.

**Phase 3 — Rollout-third (R6-gated)**: if the advisory's drift count fails to converge across `N` consecutive `M`-rate windows (e.g. `N=2` consecutive `M=monthly` retros, OR `N=3` consecutive `M=release` cycles), escalate to a load-bearing PreToolUse / PostToolUse hook OR a release-time CI gate.

The numeric gate `(N, M)` is chosen per-rule in the Phase 1 ADR — ADR-057 specifies the FORM (`drift_instances ≥ X across N consecutive M-rate windows, where N+M chosen per-rule`) not the THRESHOLD (specific `X`/`N`/`M`). This avoids accidental thresholding-by-citation and lets each child ADR pick numeric gates appropriate to its drift class.

R6-gated means human-resolvable on each release / retro pass; only escalated when the advisory empirically fails. Phase 3 escalation is **deferred indefinitely** if the advisory empirically converges (i.e. drift count trends to 0 or stays below the gate's `X` threshold). Convergence is the success path; escalation is the failure path. Both are valid outcomes.

### Negative space

ADR-057 does NOT apply when:

- The decision is single-rule (single file, single config setting, single path) — falls under ADR-040 single-grain.
- The class has fewer than 3 instances at codification time — wait until cluster materialises.
- Drift is not numerically countable (e.g. qualitative "is this style consistent?" type rules) — the advisory layer cannot compute an R6 gate; the rule needs a different rollout shape.
- The decision is genuinely irreversible (data migration, schema change, etc.) — declarative-first is the wrong shape; canonical rollout is required.
- The decision is governance-blocking by design (security / compliance hard requirements) — Phase 1 + Phase 3 directly without an advisory observation period is correct here; ADR-057's 3-phase shape would dangerously delay enforcement.

## Consequences

### Good

- **Future cluster-class ADRs follow the 3-phase shape intentionally**, not ad-hoc. Reduces re-litigating design-pattern decisions per cluster ADR.
- **Anti-BUFD discipline preserved** — observation period precedes enforcement; user-recovery paths preserved on first-day rollout.
- **R6-gated form is parameterised** — each child ADR picks `(X, N, M)` appropriate to its drift class; ADR-057 doesn't accidentally thresholding-by-citation.
- **Reduces design-relitigating cost** for plugin-developers extending the suite (JTBD-101 alignment) — pattern shape is documented in one place.

### Bad

- **Maintenance overhead** — ADR-057 is a meta-ADR; future revisions to the 3-phase shape ripple to all child ADRs that cite it.
- **Boundary fuzziness** — "cluster-shaped" is fuzzy at the edges; future reviewers may cite ADR-057 against single-rule cases. The three necessary conditions in Decision Drivers are intended to mitigate this.
- **Risk of over-invocation** — single-rule decisions that happen to share class metadata (e.g. "applies to packages/itil/" without applying to the rest) may be mis-routed through ADR-057 when ADR-040 is the correct path.

### Neutral

- **No adopter-facing change** — ADR-057 is internal codification of an internal-only pattern. Plugin-user persona unaffected.
- **No new tooling required** — the 6 existing cluster ADRs already implement the pattern; ADR-057 documents what's already shipped.

## Confirmation

This ADR is implementable / followed when:

- **Behavioural conformance check** (per ADR-052 behavioural-tests-default): given a cluster ADR, an automated check verifies its Phase 2 advisory file exists, exits 0, and emits a numeric drift_instances. The check resides in a sibling test file (`packages/<plugin>/test/cluster-adr-three-phase-conformance.bats` or similar) per ADR-005. Without this, ADR-057 is doc-text without an observable conformance gate.
- **Per-cluster-ADR Confirmation field** — each child cluster ADR's Confirmation MUST cite ADR-057 + name its Phase 2 advisory script path + name its numeric drift gate `(X, N, M)`. Without these citations, the child ADR is not in conformance with ADR-057.
- **Reassessment hook** (advisory-only initial mode): an advisory script `packages/itil/scripts/check-cluster-adr-three-phase.sh` (or sibling location) walks `docs/decisions/*.proposed.md` files matching the cluster-ADR shape (citing ADR-057 in More Information section) and emits per-ADR conformance lines. Phase 2 of P157-style detector for ADR-057 itself.

## More Information

### Parent

- **ADR-040** (declarative-first-then-enforce) — single-rule grain parent precedent. ADR-057 narrows to cluster-class variant.

### Sibling cluster ADRs (instances of the pattern)

- ADR-049 (P151 plugin-script resolution via bin/-on-PATH)
- ADR-051 (P152 JTBD-anchored README with drift advisory)
- ADR-052 (P081 Layer A behavioural-tests-default for skill testing)
- ADR-053 (P087 plugin maturity taxonomy)
- ADR-054 (P097 SKILL.md runtime budget advisory)
- ADR-055 (P137 namespace-prefixed-permalinks for internal-ID leakage)

### Related

- **ADR-013** Rule 6 — non-interactive fail-safe. Phase 2 advisory exit-0 contract.
- **ADR-044** decision-delegation contract — R6 gate precedent (`packages/retrospective/scripts/check-ask-hygiene.sh` cross-session trail). ADR-057's `(X, N, M)` form generalises ADR-044's specific `≥2 across 3 retros` instance.
- **ADR-005** plugin testing strategy — behavioural bats fixture for Phase 2 advisory conformance.
- **ADR-052** behavioural-tests-default for skill testing — Phase 2 bats authored as behavioural per default.
- **ADR-038** progressive-disclosure (advisory output bytecounts, ≤300 byte deny budgets etc.) — orthogonal but composing.

### Drivers

- **P135** decision-delegation contract — sibling pattern; R6 numeric gate precedent.
- **P137** namespace-prefix-leakage (ADR-055 driver) — first-tier instance that triggered iter-17 + iter-14 + iter-15 codification flagging.
- **P081** behavioural-tests-default (ADR-052 driver) — sibling Phase 1 + Phase 2 instance.
- **P087** plugin maturity taxonomy (ADR-053 driver) — Phase 1 only (Phase 2 deferred); precedent for "Phase 2 deferred" is acceptable per ADR-057's "convergence is the success path; escalation is the failure path; both are valid outcomes" framing.

## Reassessment Triggers

- **A 7th cluster ADR EITHER not following the 3-phase shape AND not surfacing a deviation-candidate per ADR-044 Cat-2** (deviation-approval). Pure non-conformance is the deviation; the trigger is *unflagged* non-conformance — i.e. a cluster ADR shipped without explicitly justifying why ADR-057's 3-phase shape doesn't apply.
- **Routine review 2026-11-03** (6 months after codification) — confirm pattern still observed across new cluster ADRs; check whether any of the 6 sibling cluster ADRs has empirically converged (drift count trended to 0) vs escalated to Phase 3 hook (advisory failed, hook now load-bearing).
- **Phase 3 escalation in any sibling ADR** — when one of the 6 sibling cluster ADRs ships its R6-gated hook (e.g. ADR-052's PostToolUse → PreToolUse promotion), revisit ADR-057 to confirm the Phase 3 form's wording survives the empirical test.
- **Class-of-rule expansion outside windyroad-claude-plugin** — if `@windyroad/*` adopter projects start writing their own cluster ADRs citing ADR-057, the pattern's adoption cost may surface. Reassess the boundary between ADR-040 and ADR-057 then.
