# Problem 032: Agent output references opaque problem/ADR IDs without human-readable titles

**Status**: Closed
**Reported**: 2026-04-17
**Closed**: 2026-04-17
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Effort**: S
**WSJF**: 15.0 — (15 × 1.0) / 1

## Description

Agents and governance skills in this suite routinely reference problem IDs (e.g., "P029") and ADR IDs (e.g., "ADR-013") in their output without including the human-readable title. The user does not have the ID-to-title mapping memorised and must leave their current context to look up each reference — opening the problem file or ADR file just to understand what the agent is talking about.

Example observed this session:

> "P029 is listed as Known Error with effort S in its file, but the README had it as Open/effort M."

The user has no idea what P029 is without looking it up. The output should have said:

> "P029 (Edit gate overhead for governance docs) is listed as Known Error with effort S..."

This applies to every agent and skill that emits problem IDs, ADR IDs, or JTBD IDs in prose output: risk-scorer, manage-problem, create-adr, review-design, review-jobs, architect agent, and JTBD agent.

## Symptoms

- Agent output contains bare "P029", "ADR-013", "JTBD-001" references with no title
- User has to interrupt their flow to look up what each ID refers to
- The more IDs an output contains, the worse the cognitive load — a WSJF ranking table with 15 bare IDs is unreadable without cross-referencing
- The README.md cache table already includes titles (good) but agent prose output does not
- Problem is compounded when the agent references multiple IDs in a single paragraph

## Workaround

User mentally maps IDs to titles from memory, or opens the referenced file each time. Neither scales.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — looking up IDs is the opposite of "without slowing down"
  - Tech-lead persona — audit trail readability depends on outputs being self-describing
- **Frequency**: Every agent output that references a problem, ADR, or JTBD by ID — which is most governance outputs
- **Severity**: High — compounding friction; each opaque ID costs a context switch. A single output with 5 bare IDs costs 5 lookups.
- **Analytics**: Observed this session — user reported "the agent tends to use opaque problem IDs and ADR IDs, which I'm not familiar with, so I have to go and look up the ticket"

## Root Cause Analysis

### Confirmed Root Cause

No agent prompt or skill instruction required IDs to be accompanied by their title. Agents naturally emit the shortest reference ("P029") because:

1. **No output formatting rule.** No skill instruction said "always include the title when referencing a problem or ADR by ID."
2. **Agents read the ID from filenames.** Problem files are named `029-edit-gate-overhead-...known-error.md` — the agent sees the ID but the title is inside the file, requiring a separate extraction step.
3. **Abbreviation is the LLM default.** LLMs prefer brevity; bare IDs are shorter than "P029 (Edit gate overhead for governance docs)".

### Investigation Tasks

- [x] Investigate root cause — confirmed: purely a prompt instruction gap
- [x] Design fix — chose option (b): add "## Output Formatting" section to each skill/agent that emits IDs
- [x] Create reproduction test — BATS doc-lint tests for manage-problem, architect agent, jtbd agent
- [x] Implement fix

## Fix

Added an `## Output Formatting` section to the 5 primary ID-emitting instruction files:

1. `packages/itil/skills/manage-problem/SKILL.md`
2. `packages/architect/agents/agent.md`
3. `packages/architect/skills/review-design/SKILL.md`
4. `packages/jtbd/agents/agent.md`
5. `packages/jtbd/skills/review-jobs/SKILL.md`

Each section instructs the agent: "When referencing problem, ADR, or JTBD IDs in prose output, always include the human-readable title on first mention."

BATS regression tests added:
- `packages/itil/skills/manage-problem/test/manage-problem-output-formatting.bats`
- `packages/architect/agents/test/architect-output-formatting.bats`
- `packages/jtbd/agents/test/jtbd-output-formatting.bats`

## Related

- P022: `docs/problems/022-agents-should-not-fabricate-time-estimates.open.md` — sibling: both are about agent output quality rules
- P021: `docs/problems/021-governance-skill-structured-prompts.known-error.md` — sibling: structured prompts partially address this for decision branches but not for ID references
- P030: `docs/problems/030-manage-problem-verification-prompts-lack-fix-summary.closed.md` — related: verification prompts also lacked context (fix summary)
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md` — "without slowing down" outcome
