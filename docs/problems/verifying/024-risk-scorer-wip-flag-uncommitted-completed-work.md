# Problem 024: Risk-scorer WIP mode should flag uncommitted completed work and encourage commits

**Status**: Verification Pending
**Reported**: 2026-04-16
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: L — wip.md + assess-wip SKILL.md + ADR + BATS tests (re-sized from M after architect review)
**WSJF**: 2.0 — (8 × 2.0) / 8 → now known-error

## Description

The risk-scorer WIP mode (`packages/risk-scorer/agents/wip.md`) assesses risk of uncommitted changes by reading the current diff and codebase context. However, it does not distinguish between "work in progress" (genuinely incomplete changes) and "completed work that hasn't been committed yet" (finished changes sitting in the working tree).

When a governance skill completes a unit of work (e.g., manage-problem transitions a problem to Known Error, or implements a SKILL.md fix) but does not commit, the risk-scorer WIP assessment should:
1. Detect that the changes represent completed work (not WIP)
2. Flag the uncommitted state as risk — completed work in the working tree is at risk of loss
3. Encourage the user (or skill) to commit immediately to reduce WIP and feed the pipeline

Currently, the WIP scorer treats all uncommitted changes equally. It doesn't apply back-pressure to encourage committing completed work, missing an opportunity to reinforce the lean release principle.

## Symptoms

- Risk-scorer WIP assessments after a governance-skill completes work do not distinguish "done but uncommitted" from "genuinely in progress".
- No `RISK_VERDICT` signal encourages committing completed work — the scorer only flags risk of the changes themselves, not risk of leaving them uncommitted.
- The pipeline (commit → risk-score → release) stalls silently when completed work isn't committed, because the scorer has no visibility into work that should be flowing.

## Workaround

User commits manually. The risk-scorer then assesses the committed changes normally.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-002 Ship with Confidence) — uncommitted completed work is a pipeline blind spot.
  - Tech-lead persona — no audit trail of when work was completed vs when it was committed.
- **Frequency**: Every time a governance skill completes work without committing (which is the current default per P023).
- **Severity**: Low. The pipeline still works once the user commits. This is an optimisation to reduce WIP dwell time.
- **Analytics**: Observed this session — after P021 manage-problem fix, changes sat uncommitted with no risk-scorer signal to commit.

## Root Cause Analysis

The WIP scorer (`wip.md`) only emits CONTINUE or PAUSE — no signal for "this looks done, commit it." The treatment heuristic is risk-level-only (appetite vs appetite) with no content-awareness about whether changes represent completed vs in-progress work.

### Confirmed Root Cause

WIP scorer's verdict logic is binary (CONTINUE/PAUSE), based purely on risk score. It has no content-heuristic to classify uncommitted changes as completed governance work. Without a COMMIT signal, completed work sits in the working tree silently until the user notices and commits manually.

### Investigation Tasks

- [x] Read `packages/risk-scorer/agents/wip.md` — confirmed: two verdict types (CONTINUE, PAUSE), no content-awareness
- [x] Determine how WIP scorer could detect "completed work" — chose: governance-artefact-only diff check (docs/problems/, packages/*/skills/); completion signal (Fix Released in diff, status transition in filenames)
- [x] Design `RISK_VERDICT: COMMIT` — implemented as third verdict type per ADR-016; advisory only (Option 1), not hook-driven auto-commit (Option 2 too risky)
- [x] Architect review — flagged scope expansion (needed ADR + assess-wip SKILL.md update); created ADR-016; effort re-sized from M to L
- [x] Created ADR-016 (`docs/decisions/016-wip-verdict-commit-for-completed-governance-work.proposed.md`) documenting verdict contract extension, detection heuristic, appetite gate, and Option 1 vs Option 2 decision
- [x] Updated `packages/risk-scorer/agents/wip.md` — added Completed-Work Detection section with RISK_VERDICT: COMMIT and RISK_COMMIT_REASON:
- [x] Updated `packages/risk-scorer/skills/assess-wip/SKILL.md` Step 4 — added COMMIT verdict handling with AskUserQuestion prompt for user commit confirmation
- [x] Added BATS tests `packages/risk-scorer/agents/test/risk-scorer-commit-verdict.bats` (5 tests, all GREEN)
- [x] Ensure integrates with P023 (closed) — P024 is the safety net for cases where P023's auto-commit was skipped or failed

### Fix Strategy

Add RISK_VERDICT: COMMIT as a third verdict type in wip.md (ADR-016 Option 1 — advisory only):
- Governance-artefact-only diff + within appetite + completion signal → COMMIT
- assess-wip SKILL.md Step 4 surfaces COMMIT as prominent commit-now suggestion with AskUserQuestion
- risk-score-mark.sh hook unchanged (COMMIT is advisory only per ADR-016)

## Fix Released

Implemented 2026-04-17 across three files:
- `docs/decisions/016-wip-verdict-commit-for-completed-governance-work.proposed.md` — new ADR documenting the verdict contract extension
- `packages/risk-scorer/agents/wip.md` — Completed-Work Detection section with RISK_VERDICT: COMMIT + RISK_COMMIT_REASON:
- `packages/risk-scorer/skills/assess-wip/SKILL.md` Step 4 — COMMIT verdict handling with AskUserQuestion
- `packages/risk-scorer/agents/test/risk-scorer-commit-verdict.bats` — 5 structural tests (all GREEN)

Awaiting user verification that WIP assessments now emit RISK_VERDICT: COMMIT for completed governance work and that assess-wip surfaces the commit suggestion prominently.

## Related

- `packages/risk-scorer/agents/wip.md` — WIP assessment agent
- P023: `docs/problems/023-governance-skills-should-commit-completed-work.open.md` — governance skills should commit; this problem is the scorer-side complement
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
- RISK-POLICY.md — risk appetite and pipeline gate framing
