# Problem 212: work-problems iteration boundary leaves run-retro BRIEFING.md edits uncommitted

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Iteration retros inside `/wr-itil:work-problems` write to `docs/BRIEFING.md` but cannot commit per ADR-014 (run-retro is out of scope for committing its own work). The orchestrator therefore has to add separate "BRIEFING hand-off" commits between iterations to keep Step 6.75 dirty-state classification clean. Each hand-off commit triggers another `wr-risk-scorer:pipeline` subagent invocation, doubling the gate overhead per iter.

## Workaround

Accept the doubled commit/gate overhead per iter. Tolerable for short loops; meaningful friction for long AFK runs.

## Impact Assessment

- **Severity**: Moderate — friction; not a correctness issue.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Architect call: either extend run-retro's commit scope to include BRIEFING handoffs (relax ADR-014 scope for retro narrative), OR have the orchestrator stage BRIEFING refresh alongside the iter's ticket commit (single-commit grain).
- [ ] Behavioural test asserting iter N's commit OR orchestrator commit carries the BRIEFING refresh in the same logical unit.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/83
- **Pipeline classification**: JTBD-aligned (JTBD-006); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil + @windyroad/retrospective.
