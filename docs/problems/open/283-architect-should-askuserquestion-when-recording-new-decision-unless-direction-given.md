# Problem 283: Architect agent should always use AskUserQuestion to gather direction when recording a new decision — unless an explicit direction has already been given

**Status**: Open
**Reported**: 2026-05-23
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Class-of-behaviour observation 2026-05-23: when the `wr-architect:agent` subagent (or the `/wr-architect:create-adr` / `/wr-architect:capture-adr` skills) is recording a new architecture decision (proposing or capturing a new ADR), it should **always** route the direction-gathering through the `AskUserQuestion` tool — not via prose asks, not via silent autocratic decision, not by deferring all options to the user without structuring them.

The user-stated rule: *"the architect should always use the askuserquestion tool to get direction when recording a new decision unless an explicit direction has been given."*

Two carve-outs implied by the rule:

1. **Explicit direction already given** — if the user has already pinned a direction in the same turn / same session (e.g. *"go with Option A"*, *"use the per-state-subdir shape"*, *"yes, take the bypass route"*), the architect must act on that direction without re-asking. This is the "act on obvious" half of P085 / `feedback_act_on_obvious_decisions.md` scaled down to the architect surface.
2. **AskUserQuestion is the required ask shape** — when direction is NOT given, prose asks ("Want me to use Option A or Option B?", "Should I prefer the in-line refresh or the deferred refresh?") are non-compliant. The structured AskUserQuestion tool is mandatory. This is the P085 Facet B rule scaled down to the architect surface.

**Implementation reality complication**: the architect agent's tool surface (per `wr-architect:agent` definition) currently lists only `Read, Glob, Grep`. AskUserQuestion is NOT in that surface. So the architect agent CANNOT directly call AskUserQuestion in its current form. Three plausible resolution shapes for investigation:

- **Shape A — Extend the architect agent's tool surface** to include AskUserQuestion. Lets the subagent ask directly. Risk: subagents can typically only call tools synchronously within their own context; whether AskUserQuestion can be invoked from a subagent depends on the harness — needs verification.
- **Shape B — Architect emits a structured "needs-direction" verdict** that the calling skill (or main agent) translates into an AskUserQuestion call. The architect's job becomes "name the options + name the question"; the main agent's job becomes "execute the ask". This is the cleaner separation-of-concerns.
- **Shape C — Architect-driven SKILL contract amendments** for `/wr-architect:create-adr` and `/wr-architect:capture-adr`: the skill explicitly invokes AskUserQuestion for direction-gathering BEFORE delegating to the architect subagent, OR after receiving its verdict, depending on whether direction is already pinned. The architect subagent stays read-only-tools; the skill orchestration owns the ask.

The user's framing doesn't disambiguate which shape they want — capture-problem captures the observation; the architect verdict on the implementation shape belongs in the investigation (which is itself a recursion: the architect verdict on this ticket should... use AskUserQuestion).

## Symptoms

(deferred to investigation)

- Architect proposes ADRs with Decision Drivers / Considered Options sections filled out autocratically, without first surfacing "which driver is load-bearing?" or "which option do you want?" to the user via AskUserQuestion.
- Architect agent issues prose asks in its verdict text ("I recommend Option B but you might prefer Option A — which?") instead of structured-ask output.
- The user has to repeatedly re-direct the architect's chosen option in follow-up turns, when a single AskUserQuestion at decision-recording time would have settled it cleanly.
- `/wr-architect:create-adr` and `/wr-architect:capture-adr` SKILLs do not call AskUserQuestion before invoking the architect agent for option-resolution decisions.
- Sibling ADR-013 Rule 1 (AskUserQuestion mandate for governance decisions) is treated as main-agent-only; the architect subagent has been treated as exempt.

## Workaround

(deferred to investigation)

- **User-side**: explicitly pin direction in the prompt that invokes the architect (*"propose this ADR but use Option B"*) — bypasses the gap by removing the decision-recording moment.
- **Main-agent-side**: when delegating to the architect for ADR-recording work, the main agent calls AskUserQuestion FIRST to gather option direction, then passes that direction to the architect in the delegation prompt.
- **Skill-side**: amend `/wr-architect:create-adr` and `/wr-architect:capture-adr` to call AskUserQuestion at the option-resolution step before architect delegation.

## Impact Assessment

- **Who is affected**: (deferred to investigation)
  - Solo-developer persona — has to manually re-direct architect-proposed options multiple times per ADR; friction class.
  - Tech-lead persona — ADRs land with options that don't reflect the user's actual direction; audit trail of "why this option" is degraded.
  - AFK orchestrators — architect-proposed ADRs may land with autocratically-chosen options that drift from user intent across long loops; correction lag is high.
- **Frequency**: (deferred to investigation) — every ADR creation that lacks pre-pinned direction.
- **Severity**: (deferred to investigation) — Medium pending diagnosis; recoverable via follow-up redirection but the friction class is recurrent.
- **Analytics**: (deferred to investigation) — count of ADRs amended within 1-3 turns of initial creation as a proxy for direction-mismatch; count of `wr-architect:agent` outputs containing prose-ask patterns vs structured-option outputs.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Verify whether `wr-architect:agent` subagent can call AskUserQuestion at all in the current Claude Code harness (subagent tool-surface limitation question — probe via a controlled experiment)
- [ ] Architect verdict on implementation shape (A — extend subagent tools; B — structured needs-direction verdict; C — SKILL-side AskUserQuestion before architect delegation; or a hybrid) — recursive: this verdict should itself use AskUserQuestion to gather direction from the user
- [ ] Reconcile scope vs P085 — P085 is the main-agent prose-ask master class; P283 is the architect-agent specific case. Decide whether to merge as a P085 facet or keep separate
- [ ] Reconcile scope vs P135 (decision-delegation-contract-master) — does ADR-044's framework-resolution boundary already cover this case? The architect's autocratic decisions may be re-classified per ADR-044 category 4 (silent-framework) vs category 5 (taste) — but the user's rule says category 5 (and ambiguous category 4) should be AskUserQuestion, not silent
- [ ] Define "explicit direction has been given" precisely — same-turn pin / same-session pin / project-policy pin (RISK-POLICY.md, ADRs) all count; what about implicit pins from CLAUDE.md mandatory rules?
- [ ] Implement chosen shape + behavioural test fixture (architect invoked for ADR creation without pre-pinned direction; assert AskUserQuestion fires OR is offered via structured verdict)
- [ ] Update `/wr-architect:create-adr` SKILL contract to make the AskUserQuestion-before-architect-delegation rule load-bearing
- [ ] Update `/wr-architect:capture-adr` SKILL contract — the lightweight aside-capture variant may have a different threshold (capture skeleton without resolving all options vs full intake)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — investigation can begin immediately)
- **Composes with**:
  - **P085** (assistant prose-asks vs AskUserQuestion master class — same axis, broader scope)
  - **P135** (decision-delegation-contract-master — ADR-044 framework-resolution boundary surface)
  - **ADR-013** (structured user interaction for governance decisions — Rule 1 AskUserQuestion mandate)
  - **ADR-044** (decision-delegation contract — category 5 taste vs category 4 silent-framework boundary)
  - **`/wr-architect:create-adr` SKILL** (canonical ADR-creation surface; likely amendment target)
  - **`/wr-architect:capture-adr` SKILL** (lightweight aside-capture variant; threshold question)
  - **`wr-architect:agent` definition** (tool-surface extension question — Shape A)
  - **`feedback_act_on_obvious_decisions.md`** (carve-out grounding — the "unless direction given" half)
  - **`feedback_askuserquestion_is_universal.md`** (universal-primary-agent-UX grounding — extending the rule from main-agent to subagent surfaces)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- P085 — assistant prose-asks vs AskUserQuestion master class (sibling, NOT duplicate; P085 is main-agent scope, P283 is architect-subagent scope).
- P135 — decision-delegation-contract-master.
- ADR-013 — structured user interaction for governance decisions.
- ADR-044 — decision-delegation contract.
- `feedback_act_on_obvious_decisions.md` — carve-out grounding.
- `feedback_askuserquestion_is_universal.md` — extending rule from main-agent to subagent.
- `packages/architect/agents/architect.md` (or equivalent) — `wr-architect:agent` definition; tool-surface question.
- `packages/architect/skills/create-adr/SKILL.md` — canonical ADR-creation surface.
- `packages/architect/skills/capture-adr/SKILL.md` — lightweight aside-capture variant.
