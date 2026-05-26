# Ask Hygiene — 2026-05-26 work-problems P177 salvage + release

Session: `/wr-itil:work-problems` iter 1 (P177) SIGTERM'd before commit (machine-sleep false-positive idle-timeout); salvaged + released `@windyroad/itil@0.35.13`; captured P307/P308; caught + averted a false-graduation of 3 held changesets.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Recover P177 | direction | Gap: P147 + work-problems Step 6.75 route dirty-state recovery (exit 143 + 0-byte JSON + uncommitted work) to the user (ADR-013 Rule 6) — the framework prescribes the ask, recovery direction is user-owned |
| 2 | Capture friction | **lazy** | Framework: run-retro Step 4b Stage 1 — agent-observed friction is ticketed mechanically; offering capture/skip sub-contracted a framework-resolved decision |
| 3 | Release scope | override | Gap: Step 6.5 within-appetite drain is silent-proceed, but an outward-facing multi-feature npm publish with the user present weakens the "durably authorized" claim (harness "confirm outward-facing actions"); one-time confirmation of release scope/timing |
| 4 | Corrected scope | deviation-approval | Gap: `evaluate-graduation` `status=resolved` (join-only) contradicted by `docs/changesets-holding/README.md` Rule 4 evidence floors (P308); correcting the user's prior "full drain" choice on newly-discovered evidence |
| 5 | Next step | **lazy** | Framework: work-problems Step 7 + P130 mid-loop-ask discipline — "continue" is the framework-resolved default; the stale-cache concern was a research question the agent could (and did) answer itself |

**Lazy count: 2**
**Direction count: 1**
**Override count: 1**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Note: 5 questions across 4 `AskUserQuestion` tool-calls (call 1 carried 2 questions: "Recover P177" + "Capture friction"). The 2 lazy calls (Capture friction, Next step) were both surfaced to a present user during an anomaly-recovery session; neither blocked progress. R6 gate (lazy ≥2 across 3 consecutive retros) does NOT fire — the prior two retros were lazy=0.
