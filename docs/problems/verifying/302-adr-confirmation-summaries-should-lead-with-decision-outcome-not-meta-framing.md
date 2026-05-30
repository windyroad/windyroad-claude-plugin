# Problem 302: ADR-confirmation summaries should lead with the Decision Outcome, not the meta-framing (caused 2 user re-asks this session)

**Status**: Verification Pending
**Reported**: 2026-05-25
**Priority**: 4 (Low-Med) — Impact: 2 (Minor — a confusing summary costs a clarifying re-ask round-trip + erodes trust in the drain's presentation; recoverable) × Likelihood: 2 (Unlikely-Possible — recurs when presenting meta-heavy ADRs, i.e. sibling/supersede/separate-vs-amend decisions, for oversight-confirm)
**Effort**: S — presentation-guidance edit to the `/wr-architect:review-decisions` skill (held) + a one-line agent-interaction briefing note
**WSJF**: 4/1 × 2.0 = **8.0** (Known Error multiplier 2.0)
**Type**: technical
**Origin**: internal

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

The two drain skills (`/wr-architect:review-decisions` Step 3 + `/wr-jtbd:confirm-jobs-and-personas` Step 3) carried `AskUserQuestion` bullets (`Question` / `Context` / `Options`) but did NOT direct the `question` field to **lead with the substantive outcome**. The skill prose left the framing open — so the agent, when authoring the question, often led with whatever it found first in the ADR (frequently Considered-Options meta or sibling relationships, because those tend to land before Decision Outcome in MADR-4.0-shaped bodies, or because the agent's own framing instinct privileged meta-coherence over substance). Two observed re-asks on 2026-05-25 (ADR-045, ADR-020) confirmed the gap was load-bearing in practice, not a one-off slip.

The cure is to make the presentation rule **explicit** in the skill prose — substance-first with worked bad/good examples, anchored to ADR-074 (*name the substance, not the grain*) and ADR-026 (grounding extended from artifact body to the `AskUserQuestion` `question` text). Mirroring on the JTBD-confirm surface (P316 sibling-ADR precedent of "if the same risk exists on both surfaces, write the rule on both") closes the same class on the JTBD drain. A briefing note generalises the rule to any decision-presentation surface — the create-adr Step 5 confirm has the same risk class but its presentation surface is differently shaped (the user just authored the decision moments earlier, so the substance is already known to them); cross-reference is sufficient there without a third SKILL.md edit.

### Investigation Tasks

- [x] Add a presentation rule to `/wr-architect:review-decisions` (the held drain skill, P283/ADR-066): when surfacing an ADR for confirm, the AskUserQuestion `question` MUST lead with the one-line Decision Outcome ("This ADR decides: X"); sibling/supersession/recording-shape meta goes in a trailing clause or is omitted. Mirror in `/wr-jtbd:confirm-jobs-and-personas`. — done; both Step 3 sections carry the rule + worked bad/good examples.
- [x] Add an agent-interaction briefing note (`docs/briefing/agent-interaction-patterns.md`): "When presenting a recorded decision for confirmation, lead with the Decision Outcome, not its Considered-Options meta or sibling relationships." — done; bullet added cross-referencing both SKILL.md sites + the create-adr Step 5 generalisation.
- [x] Generalises to any decision-presentation surface (not just the drain) — the create-adr Step 5 confirm has the same risk. — covered via the briefing note; no separate create-adr Step 5 edit (its presentation surface differs — the user just authored the decision so the substance is already known).

## Fix Strategy

Bounded prose-only edit to three files — no new code, no schema changes, no new ADR (fits cleanly under ADR-066 + ADR-068 + ADR-026 + ADR-013 + ADR-044 envelope per architect verdict):

1. `packages/architect/skills/review-decisions/SKILL.md` Step 3 — insert presentation rule between the "Options" bullets and the "genuine human-decision surface" closing line. Includes worked bad/good examples grounded in the ADR-045 and ADR-020 citations from this ticket.
2. `packages/jtbd/skills/confirm-jobs-and-personas/SKILL.md` Step 3 — mirror the rule adapted for jobs/personas (lead with job statement / persona definition; persona-cluster meta relegated or omitted).
3. `docs/briefing/agent-interaction-patterns.md` — append a "What Will Surprise You" bullet noting the rule generalises to any decision-presentation surface, cross-referencing both SKILL.md sites + the create-adr Step 5 confirm.

**Release vehicle**: `.changeset/p302-decision-confirmation-presentation-rule.md` (patch bump for `@windyroad/architect`; @windyroad/jtbd mirror rides the held `docs/changesets-holding/p288-jtbd-persona-oversight.md` changeset's graduation).

JTBD review (PASS): serves JTBD-005 (Invoke Governance Assessments On Demand), JTBD-006 (Progress the Backlog While I'm Away), JTBD-101 (Extend the Suite with New Plugins). Persona fit confirmed for both `developer` (speed-without-sacrificing-quality) and `plugin-developer` (clear-patterns-not-reverse-engineering).

## Dependencies

- **Blocks**: clean UX of the ADR-066/068 oversight drains.
- **Blocked by**: best landed alongside the `/wr-architect:review-decisions` skill graduation (it is currently held per ADR-066's changeset).
- **Composes with**: ADR-066/068 (the drain skills whose presentation this improves), the create-adr Step 5 confirm (same presentation risk), agent-interaction-patterns briefing.

## Fix Released

Released in `@windyroad/architect@0.12.1` via `.changeset/p302-decision-confirmation-presentation-rule.md` (version-packages commit `5244b5f`, merge commit `d929acd`, PR #178, released 2026-05-30). The architect surface (`/wr-architect:review-decisions` Step 3) and the briefing note (`docs/briefing/agent-interaction-patterns.md`) shipped at commit `d1de917`. The JTBD mirror (`packages/jtbd/skills/confirm-jobs-and-personas/SKILL.md` Step 3) is intentionally held — it rides the `docs/changesets-holding/p288-jtbd-persona-oversight.md` changeset's graduation per the architect verdict on this ticket.

Awaiting user verification — exercise either drain skill on a meta-heavy ADR (sibling / supersession / separate-vs-amend) and confirm the AskUserQuestion `question` field leads with the one-line Decision Outcome (`"This ADR decides: X"`) rather than the meta-framing.

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain retro)

- **P283** / **ADR-066** + **P288** / **ADR-068** — the drains whose presentation guidance this improves.
- `packages/architect/skills/review-decisions/SKILL.md` + `packages/jtbd/skills/confirm-jobs-and-personas/SKILL.md` — the edit targets (architect side released in 0.12.1; jtbd side held with p288).
- `docs/briefing/agent-interaction-patterns.md` — the briefing note target (shipped at commit `d1de917`).
