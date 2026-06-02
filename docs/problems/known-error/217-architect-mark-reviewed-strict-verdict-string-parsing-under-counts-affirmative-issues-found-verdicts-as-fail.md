# Problem 217: architect-mark-reviewed.sh strict-verdict-string parsing under-counts affirmative ISSUES FOUND verdicts as FAIL

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `architect-mark-reviewed.sh` PostToolUse hook only creates the gate-release marker when the architect agent's output contains the literal string `Architecture Review: PASS`. When the architect's verdict is "ISSUES FOUND" but the bottom-line text is affirmative (e.g., "the proposed change is acceptable with the noted issues addressed inline"), the marker is not created and the gate denies the subsequent edit.

## Workaround

Manually re-prompt the architect agent to emit the literal `Architecture Review: PASS` string.

## Impact Assessment

- **Severity**: Moderate — false-deny on affirmative ISSUES FOUND verdicts; recoverable.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Parse verdict semantics: PASS, PASS-WITH-ISSUES, PASS-WITH-NOTES, ISSUES-FOUND-AFFIRMATIVE all create marker. FAIL / ISSUES-FOUND-BLOCKING do not.
- [ ] Behavioural test covering all verdict shapes.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/78
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/architect.
