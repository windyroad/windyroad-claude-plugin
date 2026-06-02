# Problem 236: AFK iter queues "proceed-vs-defer" as direction-setting when the framework's re-evaluate-when-X trigger has already fired

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Class-of-behaviour: AFK iter subprocess queues "proceed-vs-defer" as a category-1 direction-setting `outstanding_question` when the framework's "re-evaluate when X" trigger condition has already been met. The agent fails to recognize that the framework already resolved the decision (proceed when trigger fires) and spuriously creates a user-direction surface.

Evidence: iter 1 of `/wr-itil:work-problems` session 4 (2026-05-17) queued P162 Phase 2b proceed-vs-defer to the orchestrator outstanding-questions queue, citing the 2026-05-13 user direction's "re-evaluate when atomic-cohort accumulates" phrasing as genuine direction-setting per ADR-044 framework-resolution boundary.

User correction at mid-loop check-in: *"The answer is always proceed, never defer. We have a system for prioritising work. Use it."* The "re-evaluate when X" framing was the user deferring to the WSJF system (the framework), not deferring to themselves. When the trigger fires, the framework prescribes proceed — the agent should execute, not re-ask.

Sibling tickets: P132 (over-ask in interactive sessions — orchestrator-main-turn surface), P234 (fictional defer rationalization — different surface but same defer-as-non-action class), P135 / ADR-044 (framework-resolution boundary parent).

Distinguishing surface: iter-side `outstanding_questions` queue specifically, on "re-evaluate when X" trigger-met conditions.

Preferred fix: iter classifier rule — when a queued question's underlying decision was deferred-with-trigger-condition and the trigger fires, route to silent proceed (re-queue the underlying work for the WSJF picker) not to `outstanding_questions`. The framework's prioritisation system IS the proceed authority.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation) — initial signal: each occurrence steals an interactive user moment on a framework-resolved decision; pattern compounds across iters (P162 had 4 prior iters all queuing some variant of this same class)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — examine ITERATION_SUMMARY.outstanding_questions schema in work-problems Step 5 and the deviation-candidate classifier for "re-evaluate when X" patterns
- [ ] Create reproduction test
- [ ] Cross-check against P132 over-ask surface and P234 fictional-defer surface to confirm distinguishing surface (iter-side vs orchestrator-main-turn vs prose-defer)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P132, P234, P135 / ADR-044

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P132** — over-ask in interactive sessions (orchestrator-main-turn surface)
- **P234** — fictional defer rationalization (prose-defer surface)
- **P135** / **ADR-044** — framework-resolution boundary parent
- **P162** — the ticket whose iter 1 queued the question that surfaced this class
