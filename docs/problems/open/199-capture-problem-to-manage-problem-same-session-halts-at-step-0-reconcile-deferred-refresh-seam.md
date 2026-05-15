# Problem 199: capture-problem → manage-problem same-session halts at Step 0 reconcile (HALT_ROUTE_RECONCILE on deferred-refresh seam)

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`/wr-itil:capture-problem` followed by `/wr-itil:manage-problem` (or `/wr-itil:work-problem`) on the same ticket in the same session halts at manage-problem's Step 0 reconcile preflight. capture-problem defers `docs/problems/README.md` refresh by design (its trailing pointer: *"Run /wr-itil:review-problems next to fold P<NNN> into the WSJF rankings"*), but the subsequent manage-problem invocation immediately runs the Step 0 preflight reconcile and detects the just-captured ticket as MISSING from WSJF Rankings → `wr-itil-reconcile-readme` exits 1 with `MISSING  P<NNN> wsjf-rankings: actual=open`; `wr-itil-classify-readme-drift` returns `classify_exit=1 HALT_ROUTE_RECONCILE` (the "committed cross-session drift" class — the capture-problem commit landed without staging a README refresh, which fits the classifier's pattern literally even though it's the same session).

The fix-forward path requires invoking `/wr-itil:reconcile-readme` first, committing the README refresh in its own commit, then re-running manage-problem / work-problem. This adds an extra round-trip on the natural capture-then-work flow. Observed twice in the 2026-05-14 P220 session: capture → work-problem halt → reconcile → manage-problem halt → reconcile.

**Note: this monorepo session (2026-05-15) inverted the precedent**: the P165 README-refresh-discipline hook now BLOCKS the capture-problem commit unless README is staged. So in this monorepo, capture-problem can no longer commit without README — the deferred-refresh contract has been silently broken by P165. See P197 commit message + this ticket's Notes for the contract-conflict trail. Two reasonable resolutions: (a) update capture-problem SKILL.md Step 6 to acknowledge P165 takes precedence and stage README; (b) update P165 hook to recognise capture-problem commits and waive the refresh requirement.

## Symptoms

- `wr-itil-reconcile-readme docs/problems` exits 1 reporting `MISSING  P<NNN> wsjf-rankings: actual=open` after the capture-problem commit.
- `wr-itil-classify-readme-drift` returns exit 1 (HALT_ROUTE_RECONCILE).
- manage-problem (and work-problem, which dispatches manage-problem) halts with the directive to invoke `/wr-itil:reconcile-readme` first.

## Workaround

Three viable paths: (1) Run `/wr-itil:review-problems` between capture-problem and manage-problem; (2) Run `/wr-itil:reconcile-readme` on the halt; (3) Use `/wr-itil:manage-problem` directly for capture (skipping capture-problem) — loses the capture-problem speed advantage.

## Impact Assessment

- **Who is affected**: every maintainer using the capture-then-work flow.
- **Frequency**: deterministic on the canonical capture-then-work pattern.
- **Severity**: Moderate (adds friction; not a load-bearing block).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Decide on Option 1 (same-session-capture marker carve-out, symmetric to P149) OR Option 2 (stage README in capture-problem commit, killing the deferred-refresh contract) OR Option 3 (auto-inline-refresh for single same-session MISSING entry).
- [ ] Reconcile with P165 in-monorepo precedent: the README-refresh discipline already blocks capture-problem commits without README, so the deferred-refresh contract is already partially superseded. Either roll back P165 OR update capture-problem SKILL.md Step 6.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P149 (uncommitted-rename carve-out — symmetric precedent), P165 (README-refresh-discipline hook — supersedes capture-problem Step 6 deferred-refresh in this monorepo), P094 (manage-problem inline README refresh), P062 (transition README refresh), P118 (README reconciliation preflight)

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/126 (filed 2026-05-13 from downstream windyroad/bbstats project ticket P221).
- **Pipeline classification** (review-problems Step 4.5e): JTBD-alignment=aligned-with-existing-JTBD (JTBD-006 + JTBD-001); dual-axis-risk=safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
