# Problem 224: Risk-scorer agent does not write numeric score to gate files

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The risk-scorer agent produces correct risk reports (saved to `.risk-reports/`) but does not write the numeric score to the gate files (`/tmp/risk-commit-{SESSION_ID}`, `/tmp/risk-push-{SESSION_ID}`, `/tmp/risk-release-{SESSION_ID}`). The hooks pre-create these files with the placeholder; the agent's score never lands.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend the agent's emit-shape to write numeric scores back to gate files OR have the PostToolUse mark-reviewed hook parse the agent's score block and write it.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/59
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
