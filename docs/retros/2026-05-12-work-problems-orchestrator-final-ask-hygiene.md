# 2026-05-12 — `/wr-itil:work-problems` orchestrator session — Ask Hygiene Trail (final)

Second trail entry for this orchestrator session, covering the post-iter-2-retro portion (iters 3-7 retry cycles + wrap). Companion to `2026-05-12-work-problems-orchestrator-ask-hygiene.md`.

## Scope

Orchestrator main-turn `AskUserQuestion` calls fired AFTER the first retro emit (which covered iters 1-2 wrap). Covers iter 6's retry-decision call. Iter 7's halt was a user-initiated prompt ("stop after Iter 7"), not an `AskUserQuestion` from the agent.

## Per-call classification

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | `Iter 6` (P087 retry/skip/wrap/halt after 2× stream-idle) | direction | `Gap: P087 ADR-drafting stream-idled 2× consecutive — same pattern as iter 3, but now with cumulative-cost signal (~$50 session spend by then) plus pivoting-to-non-ADR option (P166). Framework hadn't resolved retry-vs-pivot under cost-pressure; that's direction-class for the user.` |

**Lazy count: 0**
**Direction count: 1**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## Trend (cumulative across both trails this session)

Across both trail files for this orchestrator session: 3 `AskUserQuestion` calls, all direction-class, zero lazy. TREND from cross-session corpus `lazy_first=0 lazy_last=0 delta=+0` — R6 gate not firing.

## Notes

The three direction-class calls all fired at retry-strategy decision points where P140-mirror retry policy + P183-documented transient retry overlap with cost-pressure observations. P183 (captured this session) closes the gap conceptually; future sessions with P183's classifier landed will dispatch first 2 retries silently and only surface a question on the 3rd attempt OR when cumulative-cost crosses a budgeted threshold.
