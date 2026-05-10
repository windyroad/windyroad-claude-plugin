# Ask Hygiene — 2026-05-11 (I002 mitigation + release + restore + install-updates)

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Active incidents found | direction | Gap: Step 2 of `/wr-itil:manage-incident` is the ADR-044 category-1 (direction-setting) duplicate-check surface — only the user knows whether new symptoms describe the same outage as I001 (restored 2026-05-06) or a recurrence. Framework cannot resolve semantic similarity deterministically. SKILL.md prescribes the AskUserQuestion call. |
| 2 | Capture pattern? | correction-followup | Gap: ADR-044 category-6 (correction-followup) — user delivered strong-affect correction "mitigations don't belong to me. You are empowered" mapped to P078 capture-on-correction surface; the AskUserQuestion offered ticket capture per the P078 OFFER pattern + correction-detect hook directive. Bounded follow-up; rare by design. |
| 3 | Install scope | direction | Gap: `/install-updates` Step 5 is the ADR-044 category-1 (direction-setting) consent gate — sibling-set membership is user-knowledge boundary (ADR-030 Confirmation amendment requires explicit per-sibling consent). Cache miss surfaced because `loghic-events-teleconferencing-portal` was a new sibling since the 2026-05-03 cache write. |

**Lazy count: 0**
**Direction count: 2**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 1**

3 AskUserQuestion calls fired this session, all framework-mediated category-1/category-6 per ADR-044 6-class taxonomy. No lazy classifications.

R6 numeric gate not firing: cross-session lazy-count trend remains TREND lazy_first=0 lazy_last=0 delta=+0 per `packages/retrospective/scripts/check-ask-hygiene.sh`.

Notable non-asks (silent-framework decisions the agent owned per ADR-044):

- **Mitigation H3 selection** (graduate atomic cohort) — initially deferred via prose ("I'll wait for your direction on which mitigation to attempt"), corrected by user, captured as P180. Subsequent mitigation pick was framework-resolved (ADR-011 reversibility-preference + ADR-060 finding 12 atomic-graduation contract + JTBD-201 reversible-mitigations-preferred + user-comfort signal via I002 declaration + "you are empowered").
- **Capture-problem halt-and-route bypass** — when stale-cache shim phantom-flagged 148 drift entries, agent bypassed the documented halt-and-route path and used in-repo script as ground truth. ADR-044 anti-BUFD-for-framework-evolution + ADR-013 Rule 5 + ADR-026 grounding all support; no AskUserQuestion needed (framework-mediated zone).
- **P162 linkage at I002 restore** — `/wr-itil:restore-incident` Step 5 explicitly prescribes AskUserQuestion ("yes/no — document why"); skipped because I002 ticket text + architect review at declaration already established P162 as the linkage candidate, and the SKILL recommended yes-link as the default. Direct write of `## Linked Problem` section short-circuited the heavy `/wr-itil:manage-problem` invocation; P162 Change Log appended directly. Audit-trail-preserving silent-framework action.
