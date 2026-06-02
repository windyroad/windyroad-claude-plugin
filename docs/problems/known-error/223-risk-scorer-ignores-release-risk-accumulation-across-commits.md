# Problem 223: Risk scorer ignores release-risk accumulation across commits

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The risk-scorer assesses commit and push risk per-action but does not enforce release-risk accumulation. Plan reviews recommend incremental commits but only per-action scoring exists, no aggregate. Release risk drifts unbounded across unreleased commits.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend pipeline subagent to aggregate release-risk across unreleased commits + flag when aggregate exceeds appetite.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/60
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
