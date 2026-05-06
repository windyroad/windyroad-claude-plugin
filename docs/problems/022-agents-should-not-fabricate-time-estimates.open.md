# Problem 022: Agents must not fabricate time estimates without grounded data

**Status**: Open
**Reported**: 2026-04-16
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: XL — new cross-cutting ADR (ID to be minted by `create-adr` at draft time — next free ID is ≥030 as of 2026-04-20; the previously-penciled `014-agent-output-grounding` collides with the accepted ADR-014 governance-commit decision), audit of every agent prompt across the suite (risk-scorer, manage-problem, architect, plan-risk-guidance), WSJF effort-bucket semantics rework, grounding-citation convention (L → XL 2026-04-19 per P047: multi-day, cross-package, new ADR required)
**WSJF**: 2.0 — (16 × 1.0) / 8
**Type**: technical

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**Enforcement mechanism**: **Output-filter hook + CLAUDE.md rule combined** (same shape as P078 / P085 / P082 family). 

- **PostToolUse hook** on the assistant-output surface scans for unsupported time claims — hard-coded wall-clock predictions ("this will take 5 minutes", "in 3 seconds"), unjustified duration estimates, forecast language without a cited observable — and blocks with a systemMessage requiring replacement with observable-state language ("I'll monitor the output", "this runs until the test completes"). Mechanical enforcement.
- **CLAUDE.md mandatory rule** lists the forbidden time-claim shapes, the compliant alternatives, and the rationale (time predictions are fabrication without grounded data — violates ADR-026 output-grounding). Pre-generation guidance reduces hook-fire rate.

**Per-plugin ownership** (per P015/P078/P082/P085 shared-architecture decision 2026-04-21): this hook lives under `@windyroad/voice-tone` or `@windyroad/risk-scorer` — not a shared `/wr-governance:output-gate` registry. Architect review at implementation to decide which plugin owns it; lean toward `voice-tone` (time-claim fabrication is a voice concern).

ADR-level coverage: the shared-ADR draft (per the 2026-04-20 direction below) is still valid — defines the time-fabrication semantics. The hook-vs-registry decision is orthogonal to the ADR's output-grounding contract.

## Direction decision (2026-04-20, user — AFK loop stop-condition #2) — retained (ADR shape still applies)

**ADR numbering**: **Assign next free ADR number** at draft time (not the collided `014-agent-output-grounding` name). `create-adr` Step 3 mints the next available ID (currently ≥030, with `max(local, origin)+1` per P056 fix). Title-kebab remains `agent-output-grounding`. This is a new cross-cutting decision, not an extension or supersession of existing ADR-014 (governance commit) or ADR-016 (WIP verdict).

Implication: the ADR draft can proceed at the next AFK iteration with no numbering ambiguity. Candidate path: `docs/decisions/<next>-agent-output-grounding.proposed.md` where `<next>` is computed fresh.

## Description

LLM agents are prone to emitting plausible-sounding time estimates ("this will take 1 hour", "S / M / L", "~15 minutes") that have no grounding in measured data. The estimates look authoritative, feed into prioritisation math (WSJF), and get used to make decisions — but they are fabrication.

Observed this session from the risk-scorer: "Your call: accept 3/25 explicitly and merge, or take the 1 hour for the two remediations." The "1 hour" has no basis — the agent has never measured how long these remediations take in this codebase. The same failure mode exists in:

- Risk-scorer remediation outputs ("N hours to bring into appetite")
- `manage-problem` WSJF effort sizing (S < 1hr, M 1-4hr, L > 4hr) — the bucket thresholds are calibrated to human time, but the agent's *choice of bucket* is a guess
- Plan-risk-guidance estimates of implementation effort
- Any "this will take N hours/days" output from any agent in the suite

Rule: **no agent should emit a time estimate unless the estimate is grounded in concrete prior-work data** (recorded durations from comparable tasks previously executed in this codebase, stored somewhere the agent can read).

## Symptoms

- Agents confidently emit hour/day estimates that have no data backing.
- WSJF scores compound the fabrication — Effort is a guess, it's divided into Severity (itself partly guessed), and the resulting rank-ordering is treated as authoritative.
- Users calibrate to the fabricated estimates ("the agent said 1 hour so it should be quick") and get surprised when real effort is 10x.
- Remediation plans priced in hours look actionable but aren't — they can't be scheduled or committed to.
- No agent in the suite currently has a measurement surface to read prior execution times from; even if it wanted to ground estimates, there's no data to read.
- Tech-lead auditability is weakened: a retrospective can't verify "was the 1h estimate correct?" because no baseline was recorded.

## Workaround

User ignores time estimates and forms their own. Works but undermines the value of agent-produced planning output and wastes cognitive load re-estimating every remediation.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001, JTBD-002) — "the agent cannot bypass governance" is weakened when agent-produced planning numbers are fiction. Users have to manually police outputs.
  - Tech-lead persona — "no auditability of AI-assisted work" directly applies; fabricated durations corrupt the audit trail.
  - Plugin-developer persona (JTBD-101) — no documented pattern for "when may an agent emit an estimate?" across the suite.
- **Frequency**: Every risk-scorer above-appetite output, every WSJF effort bucket, every planning output that mentions hours/days.
- **Severity**: High. Decisions are being made against fabricated inputs. The fact that the inputs look reasonable is the problem — silent quality erosion rather than loud failure.
- **Analytics**: Observed this session (risk-scorer "1 hour for two remediations", Image #3).

## Root Cause Analysis

Two layers:

1. **No rule exists across the suite.** Agent prompts do not currently forbid fabricated estimates. LLMs fill the gap with plausible-looking numbers because the output template (e.g. "take the N hour for the remediations") implies one is expected.
2. **No measurement infrastructure.** Even if an agent wanted to ground estimates in prior data, there's no place to read that data from. Task durations aren't recorded anywhere the agent can access (no `~/.windyroad/measurements.jsonl` or equivalent).

### Investigation Tasks

- [ ] **Draft cross-cutting ADR: "Agent outputs must be grounded in measurable data, not LLM-fabricated estimates."** Architect flagged this as a likely future undocumented decision; co-locate with P021's structured-interaction ADR candidate (shared root cause: agents inventing content the prompt contract doesn't constrain). Candidate path: `docs/decisions/014-agent-output-grounding.proposed.md`.
- [ ] Define what "grounded" means precisely. Draft: an estimate is grounded if (a) it cites a specific source measurement (e.g. "based on P013 fix which took 47 min"), (b) the source measurement is persisted somewhere the agent can re-read, and (c) the estimate includes explicit uncertainty (range or confidence). Anything else is forbidden.
- [ ] Audit every agent prompt across the suite for estimate-emission patterns. Targets: `packages/risk-scorer/agents/*.md`, `packages/itil/skills/manage-problem/SKILL.md` (WSJF effort bucket selection), `packages/architect/agents/*.md`, any `plan-risk-guidance` prose.
- [ ] Decide how affected outputs degrade when no grounded data exists. Options: (a) omit the estimate field entirely; (b) emit "not estimated — no prior data" explicitly; (c) emit a qualitative relative sizing (larger-than / smaller-than prior problem N) without absolute durations.
- [ ] WSJF-specific treatment. The Effort bucket is currently S/M/L with human-time thresholds. Options: (a) keep the buckets but require the agent to cite a comparable prior problem for calibration; (b) replace time-based buckets with purely relative ones (smallest/medium/largest among the current backlog); (c) defer effort estimation to the user when no data exists.
- [ ] Design a minimal measurement surface. Candidates: (a) `docs/problems/<NNN>.*.md` gains an optional `Actual Effort:` field when closed, agent reads past entries for calibration; (b) a separate `docs/measurements/` log; (c) git-history derived (time between problem file creation and the fix commit).
- [ ] Retrofit WSJF Effort re-rating in `manage-problem review` to use any available actuals.
- [ ] Create reproduction test: prompt an agent to output a plan containing a time estimate with no measurement data available — assert output contains no hour/day value.

## Related

- Trigger: Image #3 this session — risk-scorer emitted "1 hour for two remediations" with no measurement basis
- Sibling: `docs/problems/021-risk-scorer-accept-prompt-below-appetite.open.md` — above-appetite output shape; estimate-grounding is the content rule, P021 is the delivery rule. Shared root cause (unconstrained LLM output), likely co-located ADR.
- Related: `docs/problems/016-manage-problem-should-split-multi-concern-tickets.open.md` — notes WSJF is meaningless for conflated tickets; P022 notes WSJF Effort is also meaningless without grounding.
- ADR-011 (proposed): `docs/decisions/011-manage-incident-skill.proposed.md` line 118 — rejects WSJF-effort scoring during incidents; aligns with P022's "no estimates without data" principle.
- `packages/risk-scorer/agents/pipeline.md` — primary offender for hour-estimates
- `packages/itil/skills/manage-problem/SKILL.md` — WSJF Effort bucket selection
- `packages/architect/` — planning-mode estimates
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
- Tech-lead persona: `docs/jtbd/tech-lead/persona.md` ("no auditability of AI-assisted work")
