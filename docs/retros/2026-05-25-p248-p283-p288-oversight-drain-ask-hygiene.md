# Ask Hygiene — 2026-05-25 P248/P283/P288 oversight drain (interactive session)

Per ADR-044 framework-resolution boundary. Lazy count is the regression metric (target 0).

This session fired a high volume of `AskUserQuestion` calls (≈24), but they are the **load-bearing core of the work** — the P283/ADR-066 + P288/ADR-068 human-oversight drain mandates a human decision on every recorded ADR/JTBD/persona. Confirming, amending, or rejecting an auto-made governance artifact is exactly the deviation-approval / direction surface ADR-044 reserves for the user. NONE are lazy.

| Class | Count | Examples |
|-------|-------|----------|
| deviation-approval | 13 | the 13 drain-surfaced amendments/rejects (ADR-060/052/018/019/051/043/054/047/055/034/063 + solo-developer persona + JTBD-301) — user found an existing decision wrong and directed amend/supersede |
| direction | ≈7 | P248 design forks (metric / migration / backfill), ADR-066 marker shape, P283/P288 build scope, drain-skill name |
| correction-followup | ≈2 | clarifying re-asks after the user questioned a summary (ADR-045 "what does it decide?", ADR-020 "decision to make a decision?", review-jobs purpose) |
| confirm-as-direction | ≈remainder | the ~37 ADR confirmations + 9 JTBD confirmations are the human-oversight decision itself (P283 mandate) — not lazy sub-contracting |

**Lazy count: 0**
**Direction count: 7**
**Deviation-approval count: 13**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 2**

Note: the 2 correction-followup re-asks were triggered by the agent's own summaries leading with an ADR's *meta-framing* (sibling-relationship / separate-ADR-vs-amend) instead of its Decision Outcome — captured as a self-improvement ticket (P302). Not lazy, but avoidable; the re-ask was the user correcting a presentation defect.
