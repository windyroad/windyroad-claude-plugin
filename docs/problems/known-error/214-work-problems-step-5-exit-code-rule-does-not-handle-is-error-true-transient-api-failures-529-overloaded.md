# Problem 214: work-problems Step 5 exit-code rule does not handle is_error:true transient API failures (529 Overloaded)

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`work-problems` SKILL.md Step 5 says "Non-zero exit → halt the loop" but does not cover `claude -p` returning exit 0 with `is_error: true, total_cost_usd: 0` on transient API failures (e.g. 529 Overloaded). Without an orchestrator-side `is_error` check, the loop silently treats the failure as success and tries to parse a missing ITERATION_SUMMARY block. Iteration counts get corrupted; the loop may continue dispatching subprocesses that all fail the same way.

## Workaround

Manually halt the loop on observation. AFK promise broken — the loop runs through API failures without surfacing.

## Impact Assessment

- **Severity**: High — silent failure corrupts AFK loop state; transient errors compound.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend Step 5 exit-code rule: orchestrator parses `is_error` from the `claude -p --output-format json` stdout. If `is_error: true`, halt the loop with the transient-error advisory (rate-limit / overload / auth-expired).
- [ ] Add a retry policy for known-transient classes (529 Overloaded → exponential backoff, max 3 retries; 401 auth-expired → halt-with-prompt).
- [ ] Behavioural test asserting is_error:true detected + appropriate routing.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/81
- **Pipeline classification**: JTBD-aligned (JTBD-006); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
