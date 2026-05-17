# Ask Hygiene — Session 4 Iter 3 (P234 Phase 1 ship)

> Subprocess retro per P086 (AFK iter retro-on-exit). Iter-bounded scope per ADR-032 subprocess-boundary variant. Mid-loop AskUserQuestion is forbidden in this subprocess per the orchestrator constraint (P135 / ADR-044).

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| — | — | — | (no AskUserQuestion calls fired in this iter — subprocess constraint) |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

## Notes

- Subprocess constraint enforced silent agent action throughout: architect / JTBD / WIP risk / pipeline risk / external-comms-risk / voice-tone-risk reviewers were delegated via Agent (foreground-synchronous, framework-mediated per ADR-044), not via AskUserQuestion to the user.
- Stage-2 fix-strategy selection in any retro Step 4b carve-out runs silent per P135 / ADR-044 (the framework's catalog resolves the shape).
- Step 1.5 signal-vs-noise, Step 3 Tier-3 budget pass, Step 4a verification-close, Step 4b Stage 1 ticketing — all silent per the AFK fallback. None of these fired this iter because the iter scope was Phase 1 implementation, not a full briefing retro.
