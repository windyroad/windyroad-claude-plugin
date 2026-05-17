# Ask Hygiene Trail — 2026-05-17 (session 4 iter 9 — P087 Phase 3a)

Per ADR-044 / P135 Phase 5 Step 2d. Cross-session trend consumed by `packages/retrospective/scripts/check-ask-hygiene.sh`.

## Calls

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|

(no direct AskUserQuestion calls fired this iter)

**Lazy count: 0**
**Direction count: 0**
**Deviation-approval count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## Notes

AFK iter; orchestrator brief explicitly disallows mid-loop `AskUserQuestion` per P135 / ADR-044. All decisions resolved silently per framework:

- Track selection (A vs B): orchestrator's classification rationale named in iter brief.
- capture-problem invocations (P244 + P245): `--no-prompt --type=technical` derive-first silent path; no AskUserQuestion fired in either capture.
- Agent delegations (architect / JTBD / risk-scorer:pipeline / risk-scorer:external-comms) are subagent invocations, not AskUserQuestion calls.
- Move-to-holding remediation: ADR-042 Rule 2 auto-apply per risk-scorer pipeline's RISK_REMEDIATIONS output; agent applied without re-asking.

Zero lazy count this iter — clean.
