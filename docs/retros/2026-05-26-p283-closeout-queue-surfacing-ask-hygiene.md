# Ask Hygiene — 2026-05-26 P283 close-out + queue-surfacing (orchestrator main turn)

Session: interactive close-out of the AFK work-problems loop — P283 prong-2 oversight drain, release + install of the held mechanism, the 10-ADR oversight review, the 3 surfaced decisions, and the 5 surfaced queue observations. All AskUserQuestion calls below were main-turn (the iter subprocesses ran their own retros per P086).

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Close P283 | direction | Gap: how to close an XL ticket whose prong-2 mechanism is held — not framework-resolved; user owns the close strategy |
| 2 | P283 on patchy net | direction | Gap: network-constraint sequencing (release-first vs drain-first) is a user trade-off the framework doesn't resolve |
| 3 | Release failed | direction | Gap: post-failure recovery choice (manual/retry/pause) under patchy network — user's call |
| 4 | Next step | direction | Gap: resume-loop vs surface-questions vs wrap — user's strategic direction after P283 |
| 5 | Close P283 (graduate/drain/close — 2nd) | deviation-approval | Gap: graduate held changeset + amend-vs-accept ADR-061 reinstate criterion — user owns graduation per ADR-061 Rule 5 |
| 6 | Surface 3 decisions (ADR-060/052/018/019) | deviation-approval | Gap: human-oversight of recorded decisions IS the P283/ADR-066 deliverable; review-decisions SKILL mandates AskUserQuestion here ("NOT over-asking") |
| 7 | ADR-034/043/054/055 batch | deviation-approval | Gap: same oversight surface (ADR-066) — lifting auto-made decisions to human is the framework GOAL, not a sub-contract |
| 8 | ADR-043 re-ask (more details) | correction-followup | Gap: user said "need more details" — responsive to a user clarification request |
| 9 | 3 decisions resolution (ADR-017/P177/P260) | deviation-approval | Gap: ADR-050/ADR-017 posture changes + P177 resolution — direction/deviation the framework hadn't resolved |
| 10 | Surface 5 observations (batch + P142) | direction | Gap: user explicitly directed "Ask me the questions" — surfacing the queued observations is responsive to direct user direction |

**Lazy count: 0**
**Direction count: 5**
**Deviation-approval count: 4**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 1**

Note: the oversight-confirmation asks (calls 6-7) are the P283/ADR-066 mechanism's core deliverable — the `/wr-architect:review-decisions` SKILL explicitly classifies these as a genuine human-decision surface, NOT lazy over-asking. The P163/P198 close (within call 10) would default to silent close-on-evidence per run-retro Step 4a absent the user's explicit "ask me the questions" directive — surfacing was user-directed, not lazy.
