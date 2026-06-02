# Problem 086: AFK iteration subprocess does not run retro before returning — per-iteration lessons learnt are lost when the subprocess exits

**Status**: Closed
**Reported**: 2026-04-21 (AFK iter-7, during iter 4 — user observation mid-loop)
**Fix Released**: 2026-04-21 — iteration prompt body in `packages/itil/skills/work-problems/SKILL.md` Step 5 gains a closing step (step 4) naming `/wr-retrospective:run-retro` before `ITERATION_SUMMARY` emission; ADR-032's subprocess-boundary variant amended with a matching "Retro-on-exit (P086 amendment)" clause under the Pattern contract block; 4 doc-lint bats assertions added to `work-problems-step-5-delegation.bats` (P086); Non-Interactive Decision table gains a retro-at-iteration-end row; @windyroad/itil@0.16.0 minor bump. Verification path: user runs the next AFK loop post-restart and confirms (a) iteration subprocesses invoke `/wr-retrospective:run-retro` before returning, (b) any retro-created tickets appear on the backlog on the next Step 1 scan, (c) retro failures do not halt the AFK loop (iteration still emits `ITERATION_SUMMARY`).

## Scope-clarification note (2026-04-21 user clarification)

P086's implementation (retro inside the `claude -p` iteration subprocess) is **correct** for the AFK `/wr-itil:work-problems` use case. The retro is naturally bounded to the iteration's own scope — what this iteration did, what friction it observed, what needs ticketing. The iteration-level retro is the right granularity for that loop; session-level retro is out of P086's scope.

P088 (run-retro cannot see full context when invoked as subagent) is about a **different** surface — running retro as a **background agent** (ADR-032's `capture-retro` sibling, per the capture-* background-capture pattern). That surface has the context-isolation problem; the `claude -p` AFK subprocess does not.

See P088 for the background-agent-specific scope and the implications for ADR-032's `capture-retro` sibling.

**P088 settlement note (2026-04-26)**: P088's in-iter scope ((a) ADR-032 amendment defers the `capture-retro` sibling, (b) run-retro SKILL.md adds a "Never invoke as a background agent" anti-pattern clause, (c) this note) confirms P086's retro-inside-`claude -p`-subprocess approach is **correct and distinct** from the deferred background-agent surface. The anti-pattern clause forbids the `Agent(run_in_background: true)` shape, NOT the `claude -p` subprocess shape — the two are different invocation surfaces (background subagent has isolated context at spawn; `claude -p` is a fresh main Claude Code session that loads its own context naturally). P086 ships unchanged.
**Priority**: 16 (High) — Impact: High (4) x Likelihood: Almost Certain (4)
**Effort**: M — requires (1) extending the iteration prompt in `packages/itil/skills/work-problems/SKILL.md` Step 5 to invoke `/wr-retrospective:run-retro` before emitting `ITERATION_SUMMARY`, OR (2) a new per-iteration retro contract that collects the subprocess's tool-call history + observed friction and emits structured findings the orchestrator parses alongside the summary; (3) decide what retro scope is: full run-retro or a lightweight iteration-retro; (4) handle the case where retro itself produces new tickets (orchestrator should pick them up on next Step 1 scan naturally).
**WSJF**: 8.0 — (16 × 1.0) / 2 — High severity (every AFK iteration silently discards observations; compounds across the backlog); moderate effort.

## Description

Per the ADR-032 subprocess-boundary variant shipped in P084 (2026-04-21, `@windyroad/itil@0.13.0`), each AFK `/wr-itil:work-problems` iteration runs in a dedicated `claude -p` subprocess. The subprocess:

1. Loads its own full main-Claude-Code session (CLAUDE.md, plugins, memory, SKILL.md expansions).
2. Runs `/wr-itil:manage-problem` for the assigned ticket.
3. Commits the work.
4. Emits the `ITERATION_SUMMARY` block on stdout.
5. **Exits — all context discarded**.

The orchestrator consumes the `ITERATION_SUMMARY` and moves on. Any friction, hook misbehaviour, skill-contract gap, repeat-workaround pattern, or codifiable observation encountered **inside the subprocess** vanishes when the subprocess exits. The ITERATION_SUMMARY contract has fields for `notes` and `outstanding_questions` but these are narrow — they don't carry the retro axes (pipeline instability, verification candidates, codification candidates, improvement axis).

Result: every AFK loop discards N × (per-iteration friction observations) where N = iteration count. Across a 5-iteration loop, that's potentially 20-50 tool-level observations the backlog never sees. This directly degrades JTBD-006 ("When I return, I can see a clear summary of what was worked, what was skipped, and what remains") — the "clear summary" is ticket-completion-shaped but pipeline-friction-blind.

**User observation 2026-04-21 AFK iter-7**: after watching iter 1 (P084 transition) and iter 2 (P071 slice 5) complete successfully but silently, user asked "does each iteration run a retro before it returns? if not, it should to avoid loosing lessons learnt and potential improvements". Direction pin.

## Symptoms

- Iteration subprocesses run full manage-problem workflows but emit only the ITERATION_SUMMARY — no pipeline-instability surfacing, no verification-candidate detection, no codification-candidate identification.
- TDD hook re-runs the full bats suite multiple times per iteration (observed in iter 2 taking 29 min and iter 3 taking 23 min) — that's a pipeline-instability signal the retro skill would catch and ticket, but the subprocess has no retro trigger.
- Hook TTL expiries, permission-mode interactions, architect/JTBD review depth deltas, risk-scorer gate behaviour — all invisible to the backlog.
- Repeat-workaround patterns observed inside a subprocess (e.g. "had to re-stage after git mv three times") never promote to a codification ticket because run-retro's Step 2b scan never fires.

## Workaround

User manually observes subprocess output (when available) and tickets friction themselves. Defeats the AFK-as-autonomous promise.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-006 Progress the Backlog While I'm Away)** — "clear summary" is ticket-completion-shaped but loses pipeline-friction axes.
  - **Plugin-developer persona (JTBD-101 Extend the Suite with Clear Patterns)** — new friction patterns in skills/hooks/agents go un-ticketed so future plugin development reinvents the same workarounds.
- **Frequency**: every AFK iteration. Compounds across the backlog.
- **Severity**: High. Observations are cheap to gather in-context and expensive to recover post-hoc.

## Root Cause Analysis

### Structural

The ADR-032 subprocess-boundary variant (P084) shipped without a retro-on-exit contract. The iteration prompt body (in `packages/itil/skills/work-problems/SKILL.md` Step 5) names architect / JTBD / risk-scorer / style-guide / voice-tone gate reviews but does NOT include `/wr-retrospective:run-retro` as a closing step. The ITERATION_SUMMARY contract was designed around ticket-completion state, not session-learnings state.

P077 (the Agent-tool variant that preceded P084) had the same gap — the subagent-isolation-wrapper preserved context isolation but also isolated the retro surface away from the orchestrator's view.

### Candidate fixes

1. **Extend iteration prompt to run run-retro before ITERATION_SUMMARY.** Simplest. The retro skill already produces structured output (tickets created/updated, BRIEFING diff, verification candidates, pipeline instability, codification candidates). Add a closing section to the Step 5 iteration prompt: "Before emitting ITERATION_SUMMARY, run `/wr-retrospective:run-retro` scoped to this iteration — any tickets created ride into the iteration's own commit or a follow-up commit per the retro skill's ADR-014 contract; the orchestrator picks them up on the next Step 1 scan." Cost: adds 1-2 min per iteration (retro skill is fast on a narrow scope). Risk: retro may produce findings the orchestrator re-ticketing path needs to handle idempotently.

2. **New lightweight iteration-retro contract.** Narrower than full run-retro — just the Step 2b pipeline-instability scan + a one-paragraph findings summary emitted alongside ITERATION_SUMMARY. Add a new field `iteration_findings` to the ITERATION_SUMMARY contract. Orchestrator aggregates findings across iterations and either tickets them or surfaces them in the ALL_DONE summary. Cost: bounded scope, smaller than option 1. Risk: forks the retro skill — risk of divergence between full run-retro and iteration-retro.

3. **Orchestrator-side retro between iterations.** Have the orchestrator's main turn run `/wr-retrospective:run-retro` between iterations — but the orchestrator's context doesn't have the subprocess's rich tool-call history, so the retro would be blind to per-iteration friction. Weaker than options 1-2.

4. **Defer — accept the loss for now, capture observations via user ad-hoc report.** Status quo. Rejected by user direction.

Recommended: (1). Run-retro is the canonical retro path; extending the iteration prompt to include it at the end preserves ADR-032 isolation (retro runs inside the subprocess, findings committed inside the subprocess, orchestrator sees the results via next-Step-1 scan + ITERATION_SUMMARY notes).

## Related

- **P084** (`docs/problems/084-*.verifying.md`) — parent: the subprocess-boundary dispatch variant this ticket extends.
- **P077** (`docs/problems/077-*.verifying.md`) — Agent-tool variant with the same retro-on-exit gap.
- **P074** (`docs/problems/074-*.verifying.md`) — shipped run-retro's Step 2b pipeline-instability scan. This ticket routes that scan's output through the AFK iteration surface.
- **ADR-022** — Verification Pending pattern; an iteration retro that detects exercised-but-open tickets in-subprocess can surface them for Step 4a closure in the retro artefact the commit carries.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — subprocess-boundary sub-pattern parent; may need a "retro-on-exit" clause added to the subprocess contract.
- **JTBD-006** (Progress the Backlog While I'm Away) — the "clear summary" outcome this ticket closes gaps on.
- **JTBD-101** (Extend the Suite with Clear Patterns) — new friction patterns become ticketable only via this path.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — implementation target.
- `packages/retrospective/skills/run-retro/SKILL.md` — the retro skill invoked.

### Investigation Tasks

- [ ] Architect review on the fix shape: option 1 (extend Step 5 prompt) vs option 2 (lightweight iteration-retro contract).
- [ ] Decide idempotency of retro-side ticketing when the same observation fires across iterations (e.g. TDD hook TTL expiry observed each iteration — should produce one ticket, not N).
- [ ] Update `packages/itil/skills/work-problems/SKILL.md` Step 5 iteration prompt with the retro invocation.
- [ ] Update bats contract assertion in `work-problems-cost-logging.bats` (or a new test file) asserting the iteration prompt names `/wr-retrospective:run-retro`.
- [ ] Amend ADR-032 subprocess-boundary variant with the retro-on-exit clause.
- [ ] Changeset: @windyroad/itil minor bump (iteration contract extension).
