# Problem 286: pipeline gate block threshold was hardcoded (score >= 5) instead of derived from RISK-POLICY.md appetite

**Status**: Verification Pending
**Reported**: 2026-05-25
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Fix Released

Fixed by `3c732ba` "derive pipeline gate threshold from RISK-POLICY.md appetite (ADR-065)" — the pipeline risk gate now reads its block threshold from RISK-POLICY.md's Risk Appetite (tolerant of "Threshold: N" / "exceeds N" / "N/Low appetite", with a `RISK_APPETITE` env override), defaulting to 4 when absent. Released in `@windyroad/risk-scorer@0.11.0`. Verify: an adopter whose policy sets appetite > 4 no longer has within-appetite changes rejected, and the deny message names the actual appetite applied.

## Description

Pipeline risk gate block threshold was hardcoded (`score >= 5`) in `packages/risk-scorer/hooks/lib/risk-gate.sh` instead of being derived from the project's RISK-POLICY.md risk appetite. Adopters whose RISK-POLICY.md sets a higher appetite (e.g. one that sets "exceeds 9") had every within-appetite change in their 5-9 band gate-rejected. This repo's own appetite is 4 so the constant coincidentally matched and the defect never surfaced locally. Surfaced as the P007 half of inbound report #149 (#125); no prior local ticket existed.

Root cause CONFIRMED (architect 2026-05-25): ADR-009 governs gate TTL/drift but never owned the threshold value. Fix IMPLEMENTED and committed in ce1a0cd (#149 P007 fix, ADR-065): `check_risk_gate` now resolves the appetite with precedence `RISK_APPETITE` env > RISK-POLICY.md parse > default 4 and blocks when `score > N`, rendering the parsed appetite in the deny message; default 4 preserves the prior `score >= 5` behaviour exactly for integer scores. Behavioural bats green (102/102 risk-scorer hook tests). Changeset `@windyroad/risk-scorer` minor.

Lifecycle note: root cause is confirmed and the fix has shipped to source, so this ticket is effectively a Known Error pending release. Transition Open → Known Error → Verifying on release; close once an adopter with appetite > 4 confirms within-appetite changes pass. Sibling: P198 (the #149 P010 half).

## Symptoms

(captured via /wr-itil:capture-problem — see Description; root cause + fix already recorded)

## Workaround

Set `RISK_APPETITE=<N>` env override, or rely on the shipped ADR-065 fix once released.

## Impact Assessment

- **Who is affected**: adopters whose RISK-POLICY.md sets an appetite other than 4 (this repo unaffected — appetite 4)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Investigate root cause (CONFIRMED — hardcoded `score >= 5`; see Description)
- [x] Implement fix (ADR-065 / commit ce1a0cd)
- [ ] Verify on release with an adopter whose appetite > 4

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P198 (#149 P010 half — sibling defect from the same inbound report)

## Related

- #149 / #125 — inbound report (P007 half).
- ADR-065 — the decision (parse appetite, block score > N, default 4).
- ADR-009 — sibling gate-mechanics ADR (TTL/drift); did not own the threshold.
- P198 — sibling external-comms gate defect (#149 P010 half).

(captured via /wr-itil:capture-problem; expand at next investigation)
