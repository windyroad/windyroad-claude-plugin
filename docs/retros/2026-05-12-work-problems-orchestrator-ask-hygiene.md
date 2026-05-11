# 2026-05-12 — `/wr-itil:work-problems` orchestrator session — Ask Hygiene Trail

Trail file for cross-session lazy-AskUserQuestion-count trend per ADR-044 / P135 Phase 5. Consumed by `packages/retrospective/scripts/check-ask-hygiene.sh`.

## Scope

This trail covers the orchestrator's **main turn** AskUserQuestion calls across the multi-iter AFK loop session (2026-05-11 18:11 UTC through 2026-05-12 01:04 UTC). Iter subprocess retros (P162, P167, P165) each emit their own trail files with iter-bounded scope.

## Per-call classification

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | `Iter 3` (P162 retry 3rd or skip?) | direction | `Gap: P162 stream-idle 2× consecutive — retry-cap policy (P140 sibling) is 3, but evidence of systematic failure shape (identical error twice) made 3rd-retry's expected value ambiguous. The choice is retry-strategy direction for the agent under user authority, not framework-resolved.` |
| 2 | `Iter 5` (clean retry / manual finish / skip / halt?) | direction | `Gap: iter 5 attempt 1 stream-idle BUT produced 3 untracked unfinished hook+lib+bats files — different shape from iter 3 failures (which left nothing). Existing P183 retry-with-clean-state assumes nothing untracked; this case introduces orchestrator-takes-over-work option. Genuinely new direction surface.` |

**Lazy count: 0**
**Direction count: 2**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## Trend

TREND from cross-session corpus per `check-ask-hygiene.sh` (lazy=0 across last 9 retros prior to this entry):
`lazy_first=3 lazy_last=0 delta=-3`

R6 numeric gate (lazy ≥2 across 3 consecutive retros): NOT firing. Phase 2b detection hook stays deferred per anti-BUFD discipline (covered by P132 known-error).

## Notes

Both AskUserQuestion calls fired at the orchestrator's main turn (not inside iter subprocesses). Per ADR-044 framework-resolution boundary applied to the orchestrator-main-turn surface (P130): the orchestrator MUST NOT call AskUserQuestion mid-loop except at framework-prescribed halt points. Both calls fired at retry-decision points where the framework had genuinely not resolved the user's preferred retry strategy — they are direction-class, not lazy.

P183 (captured this session, commit `95f9ba5`) documents the orchestrator's halt-on-transient-API-error gap that drove call #1's question shape; future sessions with P183 fixed will resolve attempt-3 routing without an AskUserQuestion at that surface.
