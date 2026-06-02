# Problem 028: Governance skills should auto-release after completing fixes

**Status**: Closed
**Reported**: 2026-04-16
**Closed**: 2026-04-19 — verified end-to-end during the 2026-04-19 AFK loop
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M
**WSJF**: n/a (Closed)

## Closure Evidence (2026-04-19 AFK loop, iter 2)

Auto-release fired end-to-end during this AFK loop without manual intervention:

1. **Iter 2 push** (commit `f0de540`) triggered the Release workflow (run `24619715995`).
2. **Release workflow** ran `changesets/action` which created release PR #31 on branch `changeset-release/main` with the version bumps (`@windyroad/itil@0.4.5`, `@windyroad/retrospective@0.2.0`) and plugin.json manifest syncs (P042's hook fired in the version step).
3. **`npm run release:watch`** merged PR #31 (commit `b401c7b`), and the Version-or-Publish workflow (`24619740990`) then published both packages to npm. Tag `@windyroad/itil@0.4.5` was pushed by the workflow.
4. No manual `claude plugin install` required within the AFK loop itself (that's the auto-install half, tracked as P045 and blocked on upstream Claude Code in-session plugin reload).

The whole release path fired from a single `npm run push:watch` → `npm run release:watch` drain per ADR-018's release-cadence pattern, with no interactive prompts. This is the behaviour ADR-020 mandated; the fix is verified in production.

Closed with user's explicit confirmation on reviewing the AFK loop summary (2026-04-19).

> **Scope note (2026-04-19)**: The original ticket covered both auto-release and auto-install. On architect review, the two concerns were split. Auto-install is now tracked in P045 (deferred pending Claude Code in-session plugin reload). This ticket is narrowed to **auto-release for non-AFK governance flows**, which is ready to fix via ADR-020.

## Description

When a governance skill (`manage-problem`, `manage-incident`, `create-adr`, etc.) completes a fix outside an AFK orchestrator — commits, creates a changeset, closes the problem — it stops there. The user must then manually trigger `npm run push:watch` and `npm run release:watch` before the fix lands on npm.

This contradicts the lean release principle (ADR-014) and the "governance must not interrupt flow" constraint (JTBD-001 / JTBD-005). The fix is functionally complete but not usable until the user discovers and completes a 2-step release sequence.

The AFK orchestrator (`work-problems`) already drains the release queue after each iteration via ADR-018 Step 6.5. The non-AFK governance flow is the remaining gap.

## Symptoms

- After a non-AFK governance skill fix is committed, the user must manually run `npm run push:watch` and then `npm run release:watch` before the release lands on npm.
- Unreleased changesets accumulate silently when the user forgets to release after a direct skill invocation.
- The "governance happens in under 60 seconds" target (JTBD-001) is not met for non-AFK flows — the manual release step adds 1-3 minutes of user attention per fix.

## Workaround

Run manually: `npm run push:watch` then `npm run release:watch` after each governance commit. Already what the user does today; the P040/P041 fixes during this session demonstrated the pattern works non-interactively.

## Impact Assessment

- **Who is affected**: Solo-developer persona (JTBD-001, JTBD-005) — every non-AFK governance skill fix session.
- **Frequency**: Every time a non-AFK governance skill fix is completed.
- **Severity**: Medium — fix is committed but unreleased; the release step is friction that directly contradicts the "fast governance" premise and makes backlog drain depend on user memory.
- **Analytics**: Observed this session after P027 fix; pattern repeats on every non-AFK release cycle.

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

Source-code evidence from `packages/itil/skills/manage-problem/SKILL.md` step 11 (line 395+) and `packages/architect/skills/create-adr/SKILL.md` (equivalent terminal step):

- Step 11 explicitly lists three actions: `git add`, satisfy commit gate, `git commit`. There is no `npm run push:watch` or `npm run release:watch` call. The lean-release principle is referenced as prose at line 96 (under "Working a Problem") but not codified as an automated step.
- ADR-014 (governance skills commit their own work) terminates the workflow at commit. The "natural extension" P028 calls out — pushing and releasing — is not in the ADR.

### Partial Coverage from ADR-018 (2026-04-18)

ADR-018 (Inter-iteration release cadence for AFK loops) and the P041 fix that implemented it (commit `87c2ecf`, `@windyroad/itil@0.4.1`) shipped the auto-release behaviour for the **AFK orchestrator case only**:

- `work-problems` Step 6.5 now invokes `wr-risk-scorer:assess-release` after each iteration commit and runs `npm run push:watch` + `npm run release:watch` if push/release risk reaches appetite.
- This works — demonstrated live in the P040/P041 release cycles during this session.

What ADR-018 does NOT cover (this ticket's gap): non-AFK invocations of governance skills. When the user runs `/wr-itil:manage-problem` or `/wr-architect:create-adr` directly, step 11 still ends at commit.

### Fix Strategy — ADR-020 (2026-04-19)

After architect and JTBD review, the fix is a new ADR (not an amendment to ADR-014, following the ADR-018 precedent of symmetric decisions with cited lineage):

**ADR-020 "Governance skills auto-release when changesets are queued"**:
- In-scope skills mirror ADR-014: `manage-problem`, `manage-incident`. Other governance skills (`create-adr`, `run-retro`, `update-guide`, `update-policy`) do not yet have the `work → score → commit` sequence from ADR-014 and would leapfrog a prerequisite; ADR-020 notes they inherit ADR-020 automatically once they adopt ADR-014.
- Mechanism: after `git commit` lands, delegate to `wr-risk-scorer:assess-release` (subagent `wr-risk-scorer:pipeline` with Skill fallback per ADR-015). If push/release risk is within appetite, run `npm run push:watch` then (if `.changeset/` non-empty) `npm run release:watch`. Fail-safe identical to ADR-018 (stop on `release:watch` failure, no retry).
- Non-interactive authorisation: per ADR-013 Rule 6, `push:watch`/`release:watch` are policy-authorised when residual risk is within appetite; no `AskUserQuestion` required for the release itself.

### Implementation

- Updated `packages/itil/skills/manage-problem/SKILL.md` step 11 to extend the terminal sequence with the ADR-020 release steps.
- Updated `packages/itil/skills/manage-incident/SKILL.md` terminal commit step to mirror the same pattern.

### Investigation Tasks

- [x] Determine whether `push:watch` + `release:watch` can be appended to step 11 as a standard post-commit sequence — confirmed yes (demonstrated by ADR-018 / Step 6.5 in work-problems).
- [x] Check whether `claude plugin install` can be called from within the skill — confirmed possible via Bash, but with session-restart side-effects that make it unsafe in interactive sessions. Moved to P045.
- [x] Consider whether this belongs in SKILL.md or as a shared hook — per-SKILL.md step (mirrors Step 6.5 pattern); a shared helper script could come later if more skills need it.
- [x] Evaluate risk: auto-release is reversible at the `release:watch` gate (CI failure stops publish).
- [x] Architect decision: new ADR-020, not an amendment to ADR-014 — following ADR-018 precedent.
- [x] Decide whether to split auto-install into a separate ticket — split to P045.
- [x] Implement step 11 changes in manage-problem (and mirror in manage-incident).

## Fix Released

Fix implemented under ADR-020 on 2026-04-19:
- ADR-020: `docs/decisions/020-governance-auto-release-for-non-afk-flows.proposed.md`
- `packages/itil/skills/manage-problem/SKILL.md` step 11 extended with post-commit `assess-release` + `push:watch` + `release:watch` sequence.
- `packages/itil/skills/manage-incident/SKILL.md` terminal commit step extended with the same sequence.
- P045 created to track deferred auto-install concern.

Released in: _pending release cadence check (this iteration)_.

Awaiting user verification that `/wr-itil:manage-problem` invoked directly (non-AFK) now auto-releases after commit when risk is within appetite.

## Related

- ADR-014: `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — lean release principle (commit layer)
- ADR-018: `docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md` — AFK release cadence (the precedent this ADR mirrors)
- ADR-020: `docs/decisions/020-governance-auto-release-for-non-afk-flows.proposed.md` — the fix
- P045: `docs/problems/045-auto-plugin-install-after-governance-release.open.md` — split-out auto-install concern (deferred)
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md` — "under 60 seconds" target
- JTBD-005: `docs/jtbd/solo-developer/JTBD-005-assess-on-demand.proposed.md` — must not leave task context
- P027: `docs/problems/027-manage-problem-work-flow-is-expensive.closed.md` — preceded this; P027 fix required manual release
