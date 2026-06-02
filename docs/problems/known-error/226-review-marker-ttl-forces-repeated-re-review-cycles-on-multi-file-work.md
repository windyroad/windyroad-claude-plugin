# Problem 226: Review-marker TTL forces repeated re-review cycles on multi-file work

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The four review gates installed by `wr-architect`, `wr-jtbd`, `wr-style-guide`, and `wr-voice-tone` each produce a review marker with an 1800s (30-minute) TTL. Every edit to a covered file re-checks the marker; once it expires, the edit is blocked with `review expired (Ns old, TTL 1800s)`. Multi-file work routinely exceeds 30 minutes, forcing re-review cycles per gate per file batch.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend TTL OR add sliding-window refresh (P111 pattern) OR scope marker per-batch rather than per-action.
- [ ] Coordinate with P213/#82 (risk-scorer TTL sibling).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/57
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: all four gate plugins.
- **Sibling**: P213/#82.
