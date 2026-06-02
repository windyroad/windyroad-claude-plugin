# Problem 215: architect-gate drift detection rm's marker without offering recovery path

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`architect-gate.sh::check_architect_gate` `rm`s the `/tmp/architect-reviewed-<SID>` marker and returns 1 (deny) when the stored hash differs from the current hash. After this, the agent has no obvious recovery path other than re-invoking the architect agent — which does not help if the agent has no clear directive to do so.

## Workaround

Manual re-invocation of architect agent and retry of the gated edit.

## Impact Assessment

- **Severity**: Moderate — friction, recoverable with knowledge of the workaround.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Preserve marker on drift-detect; rename to `<marker>.stale` instead of `rm`, OR emit a deny-reason that explicitly directs the agent to re-invoke architect.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/80
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/architect.
