# Problem 103: `/wr-itil:work-problems` orchestrator escalates above-appetite release decisions already resolved by the risk scorer — defeats AFK purpose

**Status**: Closed
**Reported**: 2026-04-22
**Priority**: 20 (High) — Impact: Major (4) x Likelihood: Almost certain (5)
**Effort**: M
**WSJF**: (20 × 1.0) / 2 = **10.0**

> Identified 2026-04-22 by the user during the iter-4 release-cadence check. Iter 4 produced a 4-changeset queue (itil patch, architect patch, jtbd patch, retrospective minor — slice 1 of P100); the risk scorer flagged release risk at 9/25 Medium (above the 4/25 appetite) due to the slice-1-without-slice-2 concentration in the retrospective minor. The scorer explicitly produced `RISK_REMEDIATIONS:` with **R3 at -5 impact** as a top-ranked remediation: "Release the itil patch + two exemption patches alone by dropping the retrospective changeset from this release batch." **The orchestrator escalated to the user via `AskUserQuestion` anyway, halting the AFK loop.** User direction verbatim: *"you have a risk scorer to assess release risk - you didn't need to ask me, instead of doing, you wasted time waiting for me to respond"*. This ticket captures the orchestrator behaviour as a defect.

## Description

`/wr-itil:work-problems` Step 6.5 (release-cadence drain) has two branches per the current SKILL.md:

- **Within appetite (push/release ≤ 4/25)**: drain via `push:watch` + `release:watch` (policy-authorized per ADR-013 Rule 6).
- **Above appetite (push/release ≥ 5/25)**: skip the drain and "report the unreleased state".

The current implementation, when above-appetite, effectively falls to an `AskUserQuestion` escalation — which defeats the AFK purpose. The risk scorer's job is NOT just to score — it also produces remediations ranked by impact reduction. Iter 4's scorer output included four remediations:

- **R1 (-5 impact)**: Hold retrospective minor + two exemption patches; drain only itil patch.
- **R3 (-5 impact)**: Hold only the retrospective minor; drain itil + architect + jtbd patches.
- **R4 (-4 impact)**: Defer all release until slice 2 ships.
- **R2 (-3 impact)**: Add behavioural bats test for empty-tree adopter scenario.

The orchestrator had a clear top-ranked remediation (R3 tied with R1, both at -5) but escalated to `AskUserQuestion` instead of applying it. Applying R3 non-interactively would have:

1. Moved `.changeset/p100-retrospective-briefing-migration.md` to `docs/changesets-holding/` (out of the top-level glob the changesets CLI scans — and outside `.changeset/` entirely, because `changesets/action@v1` fails with ENOENT on any subdirectory under `.changeset/`).
2. Dropped release risk below appetite (3 patches, no minor).
3. Proceeded with drain via policy-authorized `push:watch` + `release:watch`.
4. Resumed the AFK loop to iter 5 without user intervention.

Escalating to `AskUserQuestion` halted the loop for an indeterminate window while the user was AFK. This is the same "defer to ask" pattern captured in memory `feedback_act_on_obvious_decisions.md` — now extended to the above-appetite + scorer-recommended-remediation case.

## Symptoms

- AFK `/wr-itil:work-problems` loop halts at Step 6.5 whenever release risk is above appetite, even when the risk scorer has identified a clear highest-ranked remediation.
- User returns to a stalled loop and has to resolve a decision the scorer already proposed.
- Iteration count per AFK loop is artificially capped by the count of above-appetite release-cadence events — the loop stalls forever if the user never returns.
- Defeats JTBD-006 (Progress the Backlog While I'm Away).

## Workaround

User manually selects the scorer's top-ranked remediation when escalated. Does not fix the defeat-AFK behaviour for future loops or other adopters.

## Impact Assessment

- **Who is affected**: User of `/wr-itil:work-problems` (primary); every future AFK loop session on an adopter project.
- **Frequency**: Every AFK iteration that produces multi-package + minor-bump changesets. In practice: slice-by-slice fixes of L/XL tickets will trigger this on most iterations. Slice-1-without-slice-2 is the canonical shape.
- **Severity**: Major. Directly defeats the "AFK" in "AFK work-problems orchestrator".
- **Analytics**: One occurrence observed iter 4 2026-04-22. Expected to recur on every multi-package / above-appetite release event.

## Root Cause Analysis

### Preliminary Hypothesis

Step 6.5 of `work-problems` SKILL.md specifies the within-appetite drain path (policy-authorized via ADR-013 Rule 6) but lacks a decision rule for above-appetite scenarios where the scorer has produced ranked remediations. The implicit default is "ask the user", which is the wrong default when AFK is the operating mode and the scorer has already resolved the decision surface.

### Investigation Tasks

- [ ] Read the scorer's output contract: confirm it always produces a `RISK_REMEDIATIONS:` block when above-appetite, with impact-reduction per entry.
- [ ] Amend `packages/itil/skills/work-problems/SKILL.md` Step 6.5 with an explicit "above-appetite + scorer remediation available → auto-apply highest-ranked remediation; continue loop" branch.
- [ ] Distinguish "remediation that reduces risk to within appetite" (auto-applicable) from "remediation that reduces risk but remains above appetite" (may still warrant escalation — but not via `AskUserQuestion`; via structured summary per ADR-013 Rule 6).
- [ ] Define the fallback for the no-remediation-available case: emit the release decision in the loop's final Outstanding Design Questions table per Step 2.5 / ADR-013 Rule 6. Do NOT call `AskUserQuestion` mid-loop.
- [ ] Consider whether the auto-apply behaviour warrants a new ADR or amends ADR-018 / ADR-013.
- [ ] Bats coverage: simulate an above-appetite scorer output with remediations; assert Step 6.5 applies the highest-ranked and proceeds without `AskUserQuestion`.

### Fix Strategy

Amend `packages/itil/skills/work-problems/SKILL.md` Step 6.5 "Above-appetite branch":

1. When push or release risk ≥ 5/25, read the scorer's `RISK_REMEDIATIONS:` block.
2. If a remediation with sufficient impact reduction to bring residual risk within appetite is available, **auto-apply the highest-ranked one non-interactively**. Log the decision in the AFK iteration report.
3. Re-score after applying. If now within appetite, drain. If still above, emit Outstanding Design Questions in the loop's final summary (not `AskUserQuestion`) and proceed to the next iteration with the current queue uncommitted.
4. If no remediation is available or all remediations are destructive (require commit deletion, file recreation, etc.), halt the loop and emit the structured summary per ADR-013 Rule 6.

Bats coverage: exercise the auto-apply path, the no-remediation fallback path, and the destructive-remediation halt path.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none)
- **Composes with**: P085, P053

## Related

- **P085 (Assistant asks for input when the next step is obvious)** — parent pattern. P103 is the specific manifestation for AFK release decisions inside `work-problems`.
- **P053 (work-problems surfaces outstanding design questions at stop-condition #2)** — sibling. P053 established the structured-summary pattern; P103 extends it to release-cadence decisions above appetite.
- **ADR-013 (Structured user interaction for governance-skill decisions)** — Rule 6 non-interactive fallback applies here. This ticket surfaces a case where Rule 6 was not correctly applied.
- **ADR-018 (Release cadence)** — Step 6.5's within-appetite drain is defined here; above-appetite path is underspecified. ADR amendment candidate.
- Memory: `feedback_act_on_obvious_decisions.md` — captures this case's lesson in the user's memory; this ticket is the structural / repo fix.

## Fix Released

ADR-041 (`docs/decisions/041-auto-apply-scorer-remediations-above-appetite.proposed.md`) landed 2026-04-22 as the structural fix. Rule 1 prohibits release above appetite (removes the AskUserQuestion escalation surface); Rule 2 mandates auto-apply of scorer remediations in rank order; Rule 2a ships with `move-to-holding` implemented for ADR-041 v1 (other classes deferred to P108); Rule 5 halts the loop on exhaustion rather than falling through to user interaction.

Contract-assertion bats at `packages/itil/skills/work-problems/test/work-problems-above-appetite-remediation.bats` asserts the load-bearing strings. Manual behavioural verification pending an above-appetite iteration with an eligible `move-to-holding` remediation.

`work-problems` Step 6.5, `manage-problem` Step 12, and `manage-incident` Step 15 all adopt the Above-appetite branch per ADR-041. ADR-018 Step 6.5 and ADR-020 §6 cross-reference ADR-041 from the same landing commit. Holding-area convention (`docs/changesets-holding/`) promoted from provisional to blessed per Rule 7.
