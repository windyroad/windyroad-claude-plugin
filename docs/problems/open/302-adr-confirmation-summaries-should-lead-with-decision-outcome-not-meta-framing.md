# Problem 302: ADR-confirmation summaries should lead with the Decision Outcome, not the meta-framing (caused 2 user re-asks this session)

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 4 (Low-Med) — Impact: 2 (Minor — a confusing summary costs a clarifying re-ask round-trip + erodes trust in the drain's presentation; recoverable) × Likelihood: 2 (Unlikely-Possible — recurs when presenting meta-heavy ADRs, i.e. sibling/supersede/separate-vs-amend decisions, for oversight-confirm)
**Effort**: S — presentation-guidance edit to the `/wr-architect:review-decisions` skill (held) + a one-line agent-interaction briefing note
**WSJF**: 4/1 = **4.0** (Open multiplier 1.0)
**Type**: technical

## Description

Observed twice during the 2026-05-25 P283/ADR-066 ADR-oversight drain. When presenting an ADR for human-oversight confirmation, the agent's `AskUserQuestion` summary led with the ADR's **meta-framing** (its relationship to sibling ADRs, or the considered-option "separate ADR vs amend ADR-014" choice) instead of **what the ADR decides**. The user couldn't tell what they were confirming:

- **ADR-045**: summary said "a sibling ADR codifying five patterns; ADR-038 governs UserPromptSubmit, ADR-040 governs SessionStart." User: *"if this decision defers to a sibling decision, what does this decision decide??"* (It decides the 5 per-tool-call hook patterns + budget bands — the meta about ADR-038/040 scope-fencing buried that.)
- **ADR-020**: summary said "a separate ADR citing ADR-014 + ADR-018 as lineage, keeping single-purpose ADRs." User: *"A decision to create a new decision??? What isn't this just the new decision?"* (It decides that non-AFK governance skills auto-drain the release queue after commit — the "separate-ADR-vs-amend" recording-shape meta buried the substance.)

Both re-asks resolved immediately once the agent re-presented leading with the Decision Outcome. The fix is a presentation rule: **lead with what the ADR decides (the Decision Outcome in one line); relegate the meta (sibling relationships, considered-option recording-shape, supersession lineage) to a trailing clause or omit it.**

## Symptoms

- AskUserQuestion summary for an ADR opens with its Considered-Options meta (separate-ADR-vs-amend) or its sibling/supersession relationship, not its Decision Outcome.
- User can't tell what they're confirming → clarifying re-ask → agent re-presents leading with the decision → confirmed.
- Affects meta-heavy ADRs (siblings, partial-supersessions, "new ADR vs amend" recording choices) disproportionately.

## Workaround

When the user re-asks "what does it decide?", re-present leading with the Decision Outcome. (The round-trip this ticket prevents.)

## Root Cause Analysis

### Investigation Tasks

- [ ] Add a presentation rule to `/wr-architect:review-decisions` (the held drain skill, P283/ADR-066): when surfacing an ADR for confirm, the AskUserQuestion `question` MUST lead with the one-line Decision Outcome ("This ADR decides: X"); sibling/supersession/recording-shape meta goes in a trailing clause or is omitted. Mirror in `/wr-jtbd:confirm-jobs-and-personas`.
- [ ] Add an agent-interaction briefing note (`docs/briefing/agent-interaction-patterns.md`): "When presenting a recorded decision for confirmation, lead with the Decision Outcome, not its Considered-Options meta or sibling relationships."
- [ ] Generalises to any decision-presentation surface (not just the drain) — the create-adr Step 5 confirm has the same risk.

## Dependencies

- **Blocks**: clean UX of the ADR-066/068 oversight drains.
- **Blocked by**: best landed alongside the `/wr-architect:review-decisions` skill graduation (it is currently held per ADR-066's changeset).
- **Composes with**: ADR-066/068 (the drain skills whose presentation this improves), the create-adr Step 5 confirm (same presentation risk), agent-interaction-patterns briefing.

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain retro)

- **P283** / **ADR-066** + **P288** / **ADR-068** — the drains whose presentation guidance this improves.
- `packages/architect/skills/review-decisions/SKILL.md` + `packages/jtbd/skills/confirm-jobs-and-personas/SKILL.md` — the edit targets (currently held).
- `docs/briefing/agent-interaction-patterns.md` — the briefing note target.
