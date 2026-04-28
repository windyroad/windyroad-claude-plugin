---
"@windyroad/itil": patch
---

P085 — `packages/itil/hooks/lib/detectors.sh` Prose-ask detector phrasing-list extension covering 2026-04-28 regression evidence (ticket reopened from Verification Pending). The 2026-04-24 fix (UserPromptSubmit gate + Stop review hook + detector registry) shipped at minor but the canonical phrasing list missed the "Awaiting your direction" / "Pending your decision" / "Once you confirm" shapes the orchestrator emitted at Step 6.75 halt-summary today.

Specific evidence (Citation 1, this session ~17:25): orchestrator main turn emitted *"Awaiting your direction on whether to add it + resume on P123, or end the session."* — a binary-choice prose-ask. Empirical verification: existing pattern list returned exit-code 1 on this text. Detector extension closes the gap.

Files shipped:
- `packages/itil/hooks/lib/detectors.sh` — `PROSE_ASK_PATTERNS` extended with four new entries: `Awaiting your (direction|input|decision|response|confirmation|answer|reply)`, `Pending your (direction|input|decision|response|confirmation|answer|reply)`, `Once you confirm`, `Awaiting your direction on whether` (specific shape from Citation 1, retained alongside the broader pattern for observability — first-match return reports the more specific phrase).
- `packages/itil/hooks/test/itil-assistant-output-review.bats` — 5 new behavioural bats per ADR-037 + P081: Citation 1 verbatim shape, plus four adjacent phrasings each fed through a JSONL transcript to the Stop hook with `stopReason` assertion. Clean-turn negative test unchanged remains green.

Citation 2 (over-ask when framework prescribes the answer — *"FFS, why are you stopping to ask. what does the decision framework tell you to do?"*) is class-of-behaviour overlap with P132 (Open, WSJF 4.5 — Agents over-ask in interactive sessions). Framework-knowability detection requires a hook that reads SKILL.md decision tables and reasons about whether the question is mechanically answerable; that is a substantially harder problem than the phrasing-list extension here. Deferred to P132's broader fix per architect verdict (composes with ADR-044 R6 numeric gate).

Transitions P085 Known Error → Verification Pending per ADR-022.
