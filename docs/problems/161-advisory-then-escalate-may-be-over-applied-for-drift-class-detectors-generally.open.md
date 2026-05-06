# Problem 161: Advisory-then-escalate may be over-applied as the default for drift-class detectors generally; load-bearing-from-the-start may be the better default

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 6 (Moderate) — Impact: Moderate (3) x Likelihood: Possible (2)
**Effort**: M — observation-only ticket; no immediate fix. Required work is *waiting* for 2-3 more drift-class detectors to arrive following the load-bearing-from-the-start shape, then deciding whether a meta-rule / meta-ADR is warranted.

**WSJF**: (6 × 1.0) / 2 = **3.0**
**Type**: technical

> Surfaced 2026-05-04 by P159's amendment to ADR-051. Filed as the sibling out-of-scope observation P159 explicitly carved out (per the orchestrator framing for P159's Phase 1 iter). Captures the broader question P159 surfaced but did not resolve.

## Description

ADR-040 / ADR-013 Rule 6 / P099 / P134 / P145 / P148 / ADR-051 Phase 1 (original) all follow the **advisory-then-escalate** pattern: ship a detector / hook / signal as exit-0 advisory in Phase 1; escalate to load-bearing only if drift accumulates without correction across N consecutive observation windows. The pattern's rationale is sound for **design-question** and **policy-class** signals: give the rule time to socialise; don't pre-commit to enforcement before the detector has been empirically validated; preserve fail-safe non-blocking behaviour when in doubt.

P159 surfaced an empirical observation that the pattern may be **over-applied** for **drift-class** detectors. Drift class is distinct from design-question / policy class on three axes:

1. **Mechanical detection**: drift is structurally bounded — code drifted from docs, README missing a JTBD anchor, citation pointing to a non-existent file. The detector's correctness is verifiable against synthetic fixtures; the rule the detector enforces is not subjective.
2. **No socialisation period needed**: the rule is "don't ship inconsistent state". There's no "socialise" phase because the rule isn't a recommendation — it's a structural invariant.
3. **Gradualism re-creates the failure mode**: an advisory consumed at retro time is consumed *after* the contributor has already committed the drift. The whole point of the detector is to catch the drift; advisory-then-escalate gradualism means the detector exists but never catches anything, because consumers see drift only after it's shipped.

P159's amendment to ADR-051 ships the load-bearing-from-the-start variant for the JTBD-anchored README rule. The empirical question this ticket queues: **is this the right default for drift-class detectors generally, or is it specific to the JTBD-anchored README case?**

## Symptoms

- ADR-051 Phase 1 (original) shipped advisory-only; user correction (*"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"*) drove the load-bearing-from-the-start amendment under P159.
- The user-correction friction was avoidable if the original ADR-051 had defaulted to load-bearing for the drift class. The advisory-first decision was made by analogy to design-question precedents (P099 / P134 / P145 / P148), not by analysis of the drift-class shape.
- Recent drift-class detectors filed since 2026-04 follow the advisory-first default by inertia: P099 (briefing-budget detector), P134 (skill-md-budget detector), P145 (briefing-budget bin shim), P148 (tarball-shipped-shims detector), P099 (internal-id-leak detector), ADR-051 (JTBD-anchored README detector). Each shipped exit-0 advisory in Phase 1.
- None of those detectors have escalated to Phase 2 load-bearing in their reassessment windows yet, because the user-correction-driven adjustment that reaches Phase 2 hasn't surfaced for any of them. P159 is the first.

## Workaround

None — observation-only ticket. The current default (advisory-then-escalate) continues to apply for drift-class detectors filed before the meta-rule (if any) is codified. Each new detector author can evaluate whether their detector is drift-class vs design-question class and choose the load-bearing-from-the-start direction explicitly when appropriate, citing ADR-051's amended Decision Driver "Load-bearing-from-the-start for drift class" as precedent.

## Impact Assessment

- **Who is affected**: future drift-class detector authors (plugin-developer persona — JTBD-101 "clear patterns, not reverse-engineering"); plugin-user persona transitively (a load-bearing detector closes the failure mode at the closest enforcement surface, advisory-only leaves the failure mode open).
- **Frequency**: each new drift-class detector filed encounters the question. Recent rate: ~1 per AFK loop session. If 2-3 more arrive following the load-bearing-from-the-start shape, the meta-rule warrants codification.
- **Severity**: Moderate (3) — design-pattern miscalibration. Bounded by: each detector author can deviate from the default per architect review.
- **Likelihood**: Possible (2) — at the current rate of new drift-class detectors, the question will recur within a few sessions.

## Root Cause Analysis

### Preliminary Hypothesis

Advisory-then-escalate is the right default for **design-question** signals (where the rule is being socialised, where empirical validation is needed before enforcement, where fail-safe non-blocking matters). It was adopted for drift-class signals by analogy / inertia, not by analysis. The drift-class shape (mechanical detection + no socialisation period + gradualism re-creates the failure mode) suggests load-bearing-from-the-start is the better default for the class.

### Investigation Tasks (deferred — observation-only ticket)

- [ ] Wait for 2-3 more drift-class detectors to arrive following the load-bearing-from-the-start shape (the originating instance is P159; the meta-rule needs at least 2-3 instances to confirm the pattern).
- [ ] At that point: architect review on whether to codify a meta-rule. Possible shapes:
  - **Option M1**: A new ADR amending ADR-013 Rule 6 to carve out drift-class from advisory-then-escalate.
  - **Option M2**: A new ADR-NNN "Drift-class detectors default to load-bearing-from-the-start" with the empirically-derived class definition (mechanical detection + no socialisation period + gradualism re-creates failure mode).
  - **Option M3**: No meta-ADR — keep the per-detector decision in each ADR, with the load-bearing-from-the-start direction explicitly named as precedent in each new drift-class ADR's Decision Drivers.
- [ ] If M1 or M2 chosen: revisit existing advisory-only drift-class detectors (P099 / P134 / P145 / P148) and decide whether each needs a Phase 2 escalation push earlier than the current "drift_instances ≥ N across M consecutive windows" trigger.

## Fix Strategy

Phase 1: observation-only — keep this ticket open as a tracking surface for the next drift-class detector authoring decision. Each new drift-class detector's ADR can cite this ticket + ADR-051's amended Decision Driver as guidance.

Phase 2: codification (deferred to a separate iter once 2-3 more drift-class detectors arrive following the load-bearing-from-the-start shape). At that point, architect review chooses M1 / M2 / M3.

Phase 3: retroactive review of advisory-only drift-class detectors (deferred — only relevant if M1 or M2 lands).

## Dependencies

- **Blocks**: (none — observation-only ticket; no downstream work depends on its resolution)
- **Blocked by**: (none — but Phase 2 codification is gated on the arrival of 2-3 more drift-class detectors following the load-bearing-from-the-start shape; counter accumulates with each future drift-class ADR that explicitly chooses load-bearing-from-the-start over advisory-then-escalate; originating instance is P159)
- **Composes with**: P159, ADR-051, ADR-040, ADR-013 Rule 6

## Related

- [P159](159-jtbd-currency-detector-should-be-load-bearing-commit-hook-with-auto-fix-not-retro-advisory.open.md) — originating observation; ADR-051 amendment that introduced the load-bearing-from-the-start direction for one drift-class detector.
- [ADR-051](../decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md) — amended 2026-05-04 by P159 to ship load-bearing-from-the-start; new Decision Driver "Load-bearing-from-the-start for drift class" names this ticket as the meta-question surface.
- [ADR-040](../decisions/040-session-start-briefing-surface.proposed.md) — declarative-first / advisory-then-escalate pattern. ADR-040 is the pattern ADR; the question this ticket queues is whether the pattern's universality should be revisited for drift class.
- [ADR-013 Rule 6](../decisions/013-structured-user-interaction-for-governance-decisions.proposed.md) — non-interactive fail-safe / advisory-then-escalate. Sibling pattern surface.
- [P099](099-no-context-budget-or-budget-tracking-mechanism.verifying.md) — advisory-only briefing-budget detector. Drift-class candidate for retroactive load-bearing-from-the-start review if M1 or M2 lands.
- [P134](134-skill-md-runtime-budget-not-mechanically-checked.verifying.md) — advisory-only skill-md-budget detector. Drift-class candidate.
- [P145](145-briefing-budget-detector-cant-resolve-via-bash-tool.verifying.md) — advisory-only briefing-budget bin shim. Drift-class candidate.
- [P148](148-tarball-shipped-shims-not-checked-against-bin-config.verifying.md) — advisory-only tarball-shipped-shims detector. Drift-class candidate.
- [JTBD-101](../jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) — clear patterns, not reverse-engineering. The meta-rule (if codified) serves this job.

## Change Log

- 2026-05-04: Initial filing. Surfaced as the sibling out-of-scope observation P159's Phase 1 iter explicitly carved out per orchestrator framing. Observation-only ticket; deferred resolution until 2-3 more drift-class detectors arrive following the load-bearing-from-the-start shape.
