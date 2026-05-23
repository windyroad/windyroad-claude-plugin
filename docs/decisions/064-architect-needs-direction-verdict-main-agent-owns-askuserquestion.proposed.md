---
status: "proposed"
date: 2026-05-23
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-08-23
---

# ADR-064: Architect emits a Needs-Direction verdict; the main agent owns the AskUserQuestion

## Context and Problem Statement

When the architect (`wr-architect:agent`) reviews a change and detects an undocumented decision with 2+ viable options where the user has not pinned a direction, its verdict vocabulary is limited to PASS / ISSUES FOUND. With no way to say "this needs the user's direction," it either (a) autocratically recommends one option in its verdict prose, or (b) prose-asks ("I recommend B but you might prefer A — which?"). The main agent then records the decision (an ADR) off that prose, and the auto-made pick stands.

User observation 2026-05-23 (driving P283): *"some of the automatically decided decisions are poor, so we're going to lift them up and make them human decisions. As part of the work, I guess we should use the askuserquestion tool to review and confirm every ADR."* A recorded decision is a load-bearing contract — a poor silent pick is costly and drifts from user intent.

The architect is a read-only reviewer (`Read`/`Glob`/`Grep`). It cannot call `AskUserQuestion` — and should not: it is a non-interactive verdict-emitter.

## Decision Drivers

- Auto-made option-level decisions have drifted from user intent (user observation 2026-05-23); a recorded decision is a load-bearing contract.
- `AskUserQuestion` is a primary-agent affordance, not a subagent one (ADR-013 Rules 2-3; the suite-wide convention that no reviewer subagent declares it; `feedback_askuserquestion_is_universal`).
- The architect must stay a pure, non-interactive reviewer (ADR-013's chosen Option B; the pure-scorer pattern the risk-scorer agents rely on; the ADR-052 verdict-emitter precedent).
- Preserve the "explicit direction already given" carve-out — a pinned option means the architect notes it and the main agent acts without re-asking (act-on-obvious; P085; the P132 inverse-P078 over-ask guard).
- Serve JTBD-001 (enforce governance without slowing down), JTBD-002 (ship with confidence — audit trail of "why this option"), and JTBD-101 (recorded "why" for contributors), without breaching the JTBD-006 AFK no-mid-loop-ask constraint.

## Considered Options

1. **Shape A** — Extend the architect's tool surface to include `AskUserQuestion` (let the subagent ask directly).
2. **Shape B** — Architect emits a structured "Needs Direction" verdict; the main agent translates it into an `AskUserQuestion`. (chosen)
3. **Shape C** — Skill-side `AskUserQuestion` in `/wr-architect:create-adr` and `/wr-architect:capture-adr` before/after architect delegation.

## Decision Outcome

Chosen: **Shape B + a thin slice of Shape C; Shape A rejected.**

- **Shape B (primary):** add a third verdict type to the architect agent — **Needs Direction**. When the architect detects an undocumented decision with 2+ viable options AND no pinned direction, it emits a structured block naming (a) the decision question and (b) the candidate options (each grounded in what it read, per ADR-026) — instead of auto-picking or prose-asking. When direction IS pinned, it emits a "direction already given" note and the main agent acts without asking.

  **Pinned-direction sources** (shared verbatim between this ADR and the agent prompt to prevent drift) — direction counts as given when the option is fixed by any of: a same-turn pin, a same-session pin, an accepted ADR, `RISK-POLICY.md` appetite, or a CLAUDE.md mandatory rule.

  **Negative bound (inverse-P078 guard):** Needs Direction does NOT fire when only **one** viable option exists (the "obvious choice" / "only one viable option" case already in agent.md's "When NOT to flag" list). Over-firing on obvious choices is exactly the over-ask trap CLAUDE.md P132 warns against.

- **Main-agent translation contract:** on a Needs-Direction verdict, the main agent (or the calling skill) translates the named question + options into an `AskUserQuestion` call — never a prose ask — before recording the decision.

  **AFK carve-out (inherits ADR-044):** under an AFK orchestrator (`/wr-itil:work-problems`) that cannot ask mid-loop, a Needs-Direction verdict queues to the iteration's `outstanding_questions` for batched return-presentation rather than blocking the loop or guessing — preserving JTBD-006.

- **Shape C (thin):** `/wr-architect:create-adr` already routes the cat-1 fields through `AskUserQuestion` (Step 2) plus a Step 5 confirm; `/wr-architect:capture-adr` is zero-ask only because direction is pre-pinned in `$ARGUMENTS`. Document the Needs-Direction handoff in both, and make the confirm load-bearing: a capture-adr `.proposed.md` skeleton must not reach `accepted` without a create-adr/`AskUserQuestion` confirm pass.

- **Shape A rejected:** it is ADR-013's documented rejected Option A ("expand tool grants on all agents" — Con: "breaks the pure scorer pattern"). No reviewer subagent in the suite declares `AskUserQuestion`; the suite-wide precedent is ADR-052 (behavioural-tests-default), whose concrete exemplar `packages/tdd/agents/review-test.md` states: "MUST NOT call AskUserQuestion even when classification is genuinely ambiguous; emit verdict 'unclear' and let the main agent escalate."

This ADR also codifies the previously-undocumented suite-wide invariant: **all reviewer subagents are non-interactive verdict-emitters; `AskUserQuestion` is a primary-agent / skill affordance only.**

## JTBD Alignment

- **JTBD-001 (enforce governance without slowing down):** converts silent agent guessing on architecture decisions into a surfaced, governed decision. The carve-out keeps the friction budget intact — the ask fires only on genuine 2+-option direction-setting (ADR-044 class 1), never on obvious/pinned cases.
- **JTBD-002 (ship with confidence):** the confirm-every-ADR gate produces an audit trail of "why this option," satisfying the "governance was followed / agent cannot bypass" outcome.
- **JTBD-006 (progress the backlog while I'm away):** the AFK carve-out queues Needs-Direction to `outstanding_questions` rather than blocking or guessing.
- **JTBD-101 (extend the suite):** a named decision question + options is a higher-quality recorded "why" than an auto-picked rationale.

## Consequences

### Good

- Recorded decisions reflect user intent; the audit trail of "why this option" is preserved.
- The architect stays pure and non-interactive; no coupling of agent prompts to UI interaction patterns.
- The "direction already given" carve-out keeps the common case friction-free (no over-asking; P132).

### Neutral

- The architect gains a third verdict type; calling skills must learn to translate it.

### Bad / risks accepted

- If the main agent fails to translate a Needs-Direction verdict, a decision could still land autocratically — mitigated by the confirm-every-ADR gate (every ADR gets a confirm before `accepted`).
- "Viable options" is a judgment the architect makes; it may occasionally over- or under-fire. The negative bound + reassessment metric calibrate this.

## Confirmation

Behavioural where a deterministic surface exists, split per the ADR-013 Rule 2 / Rule 3 boundary:

1. **Agent verdict shape** — a structural doc-lint bats guard that `agent.md` carries a Needs-Direction verdict type in How-to-Report + issue-types. Per ADR-052, prose-document greps are NOT a free Permitted Exception (ADR-052 narrows ADR-005, which names `agent.md` in its excluded set); this guard is a **`structural-justified` case under ADR-052 Surface 2**, carrying an in-file `tdd-review: structural-permitted (justification: …)` comment citing **P176** (the P012-descendant skill-invocation harness-gap ticket) as why a behavioural test is not yet possible. (The existing `architect-output-formatting.bats` / `architect-performance-review.bats` predate ADR-052 and use the older "Permitted Exception (ADR-005 / P011)" framing; this new guard uses the current ADR-052 Surface 2 framing.)
2. **Skill / main-agent translation** — the behavioural assertion (a create-adr-style flow given a Needs-Direction verdict + no pinned direction fires `AskUserQuestion`, not prose, before writing; given a pinned direction, acts without asking) is **blocked on the skill-invocation harness (P176)**. Until P176 lands, the testable surface is a doc-lint that the create-adr/capture-adr SKILLs document the handoff. Tracked as the behavioural follow-up.
3. **Confirm-every-ADR gate** — a capture-adr `.proposed.md` skeleton cannot reach `accepted` without a confirm pass; the same P176 harness limitation applies to the behavioural form.

## Pros and Cons of the Options

### Shape A — Extend the architect's tool surface

- Good: the subagent could ask directly (single hop).
- Bad: breaks the pure-scorer pattern (ADR-013's rejected Option A); subagents are non-interactive verdict-emitters (ADR-052 precedent); `AskUserQuestion` is a primary-agent affordance, and Task-spawned subagents cannot drive parent-side interactive prompts.

### Shape B — Structured Needs-Direction verdict (chosen)

- Good: keeps the architect pure; the main agent owns interaction (ADR-013 Rule 3); has a peer precedent (ADR-052 / review-test.md); maps cleanly to ADR-044 class 1.
- Bad: two-hop (verdict → translation); relies on the main agent honouring the translation contract (mitigated by the confirm-every-ADR gate).

### Shape C — Skill-side ask

- Good: the recording skills (create-adr) are the natural ask surface; create-adr already does this.
- Bad: alone it does not fix the architect verdict surface (the architect could still prose-ask in non-create-adr contexts). Hence a thin slice complementing Shape B, not a standalone fix.

## Reassessment Criteria

- **Over/under-firing metric:** count of ADRs that round-tripped through a Needs-Direction verdict where the user picked the architect's only-named option (proxy for over-firing) vs. decisions that still landed autocratically without a verdict (under-firing). Recalibrate the "2+ viable options + no pinned direction" trigger if either climbs.
- A future harness change lets Task-spawned subagents surface interactive prompts safely → revisit Shape A.
- P176 (skill-invocation harness) lands → upgrade the Confirmation item-2/3 doc-lints to true behavioural tests.
- The confirm-every-ADR gate proves too heavy for low-stakes ADRs (measured via the over-firing metric above, not a qualitative "feels heavy") → consider a stakes threshold.

## Related

- **P283** (`docs/problems/known-error/283-...md`) — driver ticket; this ADR is prong 1.
- **ADR-013** (structured user interaction) — Option A = Shape A (rejected); Rules 2-3 = the agent-purity parent.
- **ADR-044** (decision-delegation contract) — 6-class taxonomy (Needs Direction = class 1; carve-out = framework-mediated surface); Reassessment clause pre-authorises this sibling ADR.
- **ADR-026** (agent output grounding) — candidate options grounded per ADR-026.
- **ADR-052** (behavioural-tests-default) — suite-wide reviewer-subagent verdict-emitter precedent (exemplar `packages/tdd/agents/review-test.md`); Surface 2 `structural-justified` framing for the agent.md doc-lint.
- **P085** (assistant prose-asks vs AskUserQuestion master class) — main-agent sibling of this architect-surface case.
- **P176** (skill-invocation behavioural-test harness gap) — blocks the behavioural form of Confirmation items 2-3.
