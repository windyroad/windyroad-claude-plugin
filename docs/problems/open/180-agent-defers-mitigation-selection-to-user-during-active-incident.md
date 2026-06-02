# Problem 180: Agent defers mitigation selection to user during active incident — surfaces mitigation choice as user-authority when SKILL contract empowers agent-driven reversible mitigations

**Status**: Open
**Reported**: 2026-05-10
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

During the I002 incident-management session (2026-05-10), the agent ended Step 14 reporting with the literal phrasing:

> *"I'll wait for your direction on which mitigation to attempt."*

That phrasing surfaced **mitigation selection** as user-authority territory at a stage where the `/wr-itil:manage-incident` SKILL contract has already framework-resolved the decision: the agent owns mitigation selection within the reversibility-preference + cited-evidence + within-appetite envelope. The user corrected verbatim:

> *"mitigations don't belong to me. You are empowered."*

JTBD-201 (Restore Service Fast with an Audit Trail) names "reversible mitigations are preferred" as a desired outcome — so the SKILL's empowerment of agent-driven mitigation is **documented**, not implicit. The deferral re-asked a decision JTBD-201 had already mediated, adding latency to the very job the SKILL exists to accelerate.

This is a **class-of-behaviour pattern**, sibling-but-distinct from existing tickets:

- **`feedback_dont_defer_at_session_wrap.md`** (memory) — covers session-wrap deferral ("session-side recommendations" framing). P180 is mid-flow during active incident, not session-wrap.
- **P132** (`Agents over-ask in interactive sessions — conflating mechanical-stages with user-interactive-stages`) — covers the inverse-P078 trap where defensive over-asking from upstream corrections re-introduces friction in mechanical stages. P180 is a fresh manifestation of the P132 class on the *mitigation-selection* surface specifically — distinct framework-resolution-boundary location, same root cause family.
- **P078 family** (`Assistant does not offer problem ticket on user correction`) — capture-on-correction OFFER pattern. P180 is the captured-on-correction observation; P078 is the meta-process that produced this ticket.
- **P179** (`Agent defers requested work into untracked phases — phases are fine, but unticketed phases never get implemented`) — sibling deferral pattern around requested-work phases. P180 is the deferral-pattern-mirror at the mitigation-selection surface.

Distinct surface: **mitigation-choice-during-active-incident**, not session-wrap, not declaration-fields, not requested-work-phases.

### Verbatim evidence

- Agent closing report on I002 commit `ef61039`, final paragraph: `"I'll wait for your direction on which mitigation to attempt."`
- User correction immediately following: `"mitigations don't belong to me. You are empowered"`
- Suggested-next-moves block in the same closing report enumerated three options (re-run I001 mitigation H3 / address P162 deeper defect / hybrid) and ended with the deferral phrase above — i.e., the agent prepared the analysis but stopped short of acting on the obvious mitigation.

### Architectural context

- ADR-044 (Decision-Delegation Contract) is the framework-resolution-boundary artefact. Mitigation selection within reversibility-preference + cited-evidence is a category-4 (silent-framework) surface, NOT category-1 (direction-setting). The deferral mis-classified it as category-1.
- ADR-011 (manage-incident SKILL) Step 7 + Step 8 explicitly delegate mitigation execution to `/wr-itil:mitigate-incident`. The skill contract treats mitigation as agent-action, not user-decision.
- ADR-013 Rule 5 (policy-authorised silent proceed) — within-appetite reversible mitigations are policy-authorised; no `AskUserQuestion` is required.
- JTBD-201 desired outcome wording ("Reversible mitigations [...] are preferred") makes the empowerment explicit per documented persona-job.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — likely sibling of P132 inverse-P078 trap manifesting on the mitigation-selection surface; confirm classification or document as distinct surface
- [ ] Create reproduction test — behavioural test exercising `/wr-itil:manage-incident` Step 14 reporting; verify agent transitions Step 14 → Step 7 mitigation invocation without surfacing user-authority gate
- [ ] Sibling-tree audit: check `/wr-itil:mitigate-incident`, `/wr-itil:restore-incident`, `/wr-itil:close-incident` for the same deferral pattern; check `/wr-itil:work-problem` selection surface; check ADR-042 auto-apply iteration boundaries

## Dependencies

- **Blocks**: (none direct)
- **Blocked by**: I002 (this ticket itself was captured via the bypass-the-broken-halt-and-route path because `/wr-itil:capture-problem` Step 0 hit a stale-cache phantom-drift halt — the cache is stale because RFC-002 T4 dual-tolerant reconcile script is held in `docs/changesets-holding/` and never reached npm; I002 mitigation will let the cache refresh and unblock the canonical capture path)
- **Composes with**: P078 (capture-on-correction), P132 (over-ask in interactive sessions), P179 (defers requested work into untracked phases), ADR-044 (framework-resolution boundary)

## Related

- **I002** (`docs/incidents/I002-release-pressure-and-wip-limit-controls-not-firing.investigating.md`) — the active incident in which this pattern was observed; commit `ef61039` carries the verbatim Step 14 closing report.
- **ADR-011** — manage-incident SKILL contract empowers agent-driven mitigation execution.
- **ADR-013 Rule 5** — policy-authorised silent proceed for within-appetite reversible mitigations.
- **ADR-032** — capture-problem Step 4 deferred-placeholder template (this ticket's shape).
- **ADR-044** — Decision-Delegation Contract (framework-resolution boundary).
- **P078** — capture-on-correction OFFER pattern (the meta-process that produced this ticket).
- **P132** — Agents over-ask in interactive sessions — the parent class of behaviour; P180 is a fresh manifestation on the mitigation-selection surface.
- **P179** — sibling deferral pattern (untracked phases for requested work).
- **JTBD-201** — Restore Service Fast with an Audit Trail; "reversible mitigations are preferred" desired outcome wording is the load-bearing JTBD evidence that SKILL empowerment is documented.
- `feedback_dont_defer_at_session_wrap.md` (user-memory feedback) — sibling pattern at session-wrap surface; this ticket extends the family to mid-flow active-incident surface.
