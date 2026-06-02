# Problem 213: risk-scorer 30-min TTL expired during long-running orchestrator turns

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The risk-scorer commit gate uses a 1800s (30 min) TTL on the cached score marker. During long orchestrator turns (multi-iteration AFK loops, batched skill invocations), the score expires mid-turn even when no commits happen between scoring and the eventual commit. This forces a fresh `wr-risk-scorer:pipeline` subagent invocation just to satisfy the gate, wasting a turn and re-asking the user to wait.

## Workaround

Re-invoke the pipeline subagent whenever the gate denies on TTL expiry. Visible friction but recoverable.

## Impact Assessment

- **Severity**: Moderate — wasted turns; AFK loop tempo degraded.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Choose: (a) extend TTL to a longer interval (60 min?), (b) sliding-window refresh on each gate check (P111 pattern), (c) pin marker for the duration of the orchestrator turn.
- [ ] Behavioural test asserting the chosen semantics under simulated long-running turn.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/82
- **Pipeline classification**: JTBD-aligned (JTBD-006); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
