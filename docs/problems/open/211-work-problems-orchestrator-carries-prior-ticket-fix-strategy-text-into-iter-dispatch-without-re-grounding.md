# Problem 211: work-problems orchestrator carries prior-ticket Fix Strategy text into iter dispatch without re-grounding in design intent

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The `/wr-itil:work-problems` AFK orchestrator builds each iteration's dispatch prompt by reading the target ticket's `## Fix Strategy` section and citing it verbatim to the iteration subprocess. Across iterations, prior-ticket Fix Strategy text leaks into subsequent dispatches without re-grounding in the new ticket's design intent. Iter subprocesses inherit stale context and may attempt fixes anchored on the wrong design rationale.

Reported from downstream bbstats P194.

## Workaround

User-in-the-loop verification after each iter: read the subprocess's commit and check whether it cites the correct ticket's design rationale.

## Impact Assessment

- **Severity**: Moderate — design-rationale drift could land fixes that miss the real intent; AFK trust degrades.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit Step 5 iter dispatch prompt for verbatim cross-ticket Fix Strategy leakage. Likely fix: build the dispatch fresh per ticket; don't carry prior-iter context.
- [ ] Behavioural test asserting iter N dispatch references ticket N's Fix Strategy and ONLY ticket N's.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/97 (bbstats P194)
- **Pipeline classification**: JTBD-aligned (JTBD-006); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
