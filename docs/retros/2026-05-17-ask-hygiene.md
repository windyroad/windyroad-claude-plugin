# Ask Hygiene Trail — 2026-05-17 (session 3)

Per ADR-044 / P135 Phase 5 Step 2d. Cross-session trend consumed by `packages/retrospective/scripts/check-ask-hygiene.sh`.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Iter 4 target (3 iters done this session...) | **lazy** | Framework: /wr-itil:work-problems SKILL.md Step 3 (strict WSJF + tie-break ladder) + Step 4 (ticket-state classification) + P130 Mid-loop ask discipline subsection ("No mid-iter ask points... Every other point in the orchestrator's main turn... is a mechanical-stage transition that the framework has already resolved"). Decision was: pick smallest-effort next slice of next-highest WSJF actionable. P162 gated, P087 Phase 2c/3 + P097 + P232 all candidates. Framework's tie-break ladder resolves to P087 Phase 2c (smallest defined slice of next-WSJF 3.0 ticket). User AFK overnight; answered next morning with strong-signal P078 correction: "Why are you asking me. I was AFK. You wasted time." |

**Lazy count: 1**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## R6 gate trend

Per ADR-044 Reassessment Trigger: R6 fires when lazy count ≥2 across 3 consecutive retros after Phase 2/3 land.

Prior 10 retros (per check-ask-hygiene.sh): all lazy=0. Today: lazy=1. R6 NOT yet fired (not ≥2, not 3 consecutive).

But this lazy=1 IS the regression event that triggered P132 revert Verifying → Known Error (commit e891c96) and motivated P132 Phase 2b structural-enforcement hook shipment (commit 841db68 + @windyroad/itil@0.30.3). The single data point is enough motivating evidence on its own — the user's correction directly named it as the recurrence pattern P132 tracks. The R6 numeric gate is the additional auto-flag mechanism; today the user's direct correction served the same purpose ahead of the gate.
