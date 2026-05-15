# Problem 220: manage-problem has no cadence for checking upstream-bound tickets

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`wr-itil:manage-problem` defines two terminal states for tickets that aren't being actively worked: `.parked.md` (excluded from WSJF ranking, listed separately) and `.open.md` carrying a `## Reported Upstream` section (still ranked, still surfaced). Neither state describes a cadence for checking whether the upstream has shipped a fix — the maintainer must remember to check manually.

## Workaround

Manually check `gh issue view <id>` for each upstream-bound ticket periodically.

## Impact Assessment

- **Severity**: Moderate — upstream-bound tickets age silently; local closure depends on maintainer memory.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Architect call: extend `/wr-itil:review-problems` Step 4.5 (or sibling) to poll upstream-bound tickets' status (closed-as-resolved → auto-Verifying per ADR-062 sub-concern 7).
- [ ] Sibling: P063 (external-root-cause lineage marker — auto-Verifying when upstream resolves).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/63
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Composes with**: P063, P070, ADR-062 sub-concern 7.
