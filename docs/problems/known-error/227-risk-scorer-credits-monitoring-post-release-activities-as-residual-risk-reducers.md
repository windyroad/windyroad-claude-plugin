# Problem 227: Risk scorer credits monitoring/post-release activities as residual-risk reducers

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The risk-scorer agent's residual-risk computation lists post-release activities (monitoring, rollback readiness) as "controls" that reduce the residual score. This is a category error: a control reduces inherent risk *before* a change ships (a test that exercises the failure mode locally); monitoring is detection-after-fact and doesn't reduce the probability of the bad outcome occurring.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit risk-scorer agent prompts + RISK-POLICY.md: only pre-shipping controls credit the residual reduction. Monitoring + rollback readiness belong in a separate "detection-and-recovery" category that doesn't lower the residual score.
- [ ] Behavioural test asserting monitoring-only controls don't reduce residual.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/56
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
