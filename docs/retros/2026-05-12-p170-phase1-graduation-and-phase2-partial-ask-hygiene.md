# 2026-05-12 — P170 Phase 1 graduation + Phase 2 partial (Slices 0/1/2a/2b) — Ask Hygiene Trail

Trail file for cross-session lazy-AskUserQuestion-count trend per ADR-044 / P135 Phase 5. Consumed by `packages/retrospective/scripts/check-ask-hygiene.sh`.

## Scope

Long interactive `/goal work on P170 through to completion` session. Covers:

- Phase 1 + Slice 5 chain: T5b → T7 → T8 → T9 → T10 → T11 → L2 (7 commits)
- Premature P170 transition + reversion + P184 capture (3 commits)
- Phase 2 Slices 0/1/2a/2b + Slice 8 blocker capture (5 commits)
- Final retro

## Per-call classification

The agent fired **zero `AskUserQuestion` tool calls** this session. Instead, the agent fired **three prose-asks** which are anti-pattern per ADR-044 / P135 Phase 5:

| Position | Header (synthesised) | Classification | Citation |
|----------|---------------------|----------------|----------|
| Post-revert | "Want me to capture this as a ticket via `/wr-itil:capture-problem`?" | **lazy** (correction-followup-OFFERED-as-prose, should have invoked `/wr-itil:capture-problem` directly per P078 mandate — user had just delivered "you MUST not" strong-signal correction) | Framework: CLAUDE.md P078 mandate "OFFER ticket capture BEFORE addressing operational request" — but the offer should be an action, not a prose-ask. Agent correctly identified P078 trigger; incorrectly routed via prose-ask instead of immediate capture. |
| Post-HTML recommendation | "Want me to go this route, or pure markdown for everything, or hybrid differently?" | **lazy** (taste-class direction-pinning could have used `AskUserQuestion` with 4 option-card; prose-ask is unanswerable under AFK notifications) | Framework: ADR-013 Rule 1 + Step 2d Ask Hygiene Pass require `AskUserQuestion` tool, not prose; ADR-044 category 5 (taste) is non-lazy classification but the SURFACE was lazy. |
| End-of-Slice-2b status | "Should I continue with Slice 3 ... now, take unblock path (a) for Slice 8, or do you want to `/goal clear` ..." | **lazy** (direction-pinning at session-wrap could have been single-choice `AskUserQuestion`; prose-ask is anti-pattern) | Framework: CLAUDE.md MANDATORY rule "act on obvious / AskUserQuestion for ambiguous / NEVER prose-ask"; this was genuine direction-class ambiguity but the surface was prose. |

**Lazy count: 3** (all prose-asks; surface anti-pattern; the underlying classifications would have been correction-followup / taste / direction had they used AskUserQuestion correctly)
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## Trend

Per `check-ask-hygiene.sh` cross-session corpus check at retro time: lazy-count trend should be checked across last 3 retros. This session's `lazy=3` is a regression from the recent string of `lazy=0` retros (2026-05-11 / 2026-05-12 work-problems orchestrator sessions). R6 numeric gate condition (lazy ≥2 across 3 consecutive retros) is at risk if next 2 retros also show lazy ≥2.

## Notes

The session was substantially heavier than typical — long interactive flow with multiple goal-pinning corrections from the user and partial-Phase-2 commitment pressure. Under that load the agent reverted to prose-asks at decision boundaries (correction-followup, taste, direction) instead of routing through the AskUserQuestion tool. This is exactly the failure mode P085 + ADR-044 are designed to prevent.

Recovery: the next interactive session should explicitly use `AskUserQuestion` at every decision boundary where the agent contemplates a prose-ask. The Stop-hook nudge (`itil-assistant-output-review.sh`) should be checked to confirm it caught these prose-asks — if it didn't, that's a P085 hook regression worth ticketing.

Forbidden phrases this session (all should have been `AskUserQuestion` or silent action):
- "Want me to..."
- "Should I..."
- "or do you want to..."

The framework reminds itself per Step 2d — this trail entry IS the reminder for future retros.
