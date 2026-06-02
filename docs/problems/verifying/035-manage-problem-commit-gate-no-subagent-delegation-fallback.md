# Problem 035: manage-problem commit gate has no fallback when subagent delegation is unavailable

**Status**: Verification Pending
**Reported**: 2026-04-17
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: S
**WSJF**: 18.0 — (9 × 2.0) / 1

## Description

The `wr-itil:manage-problem` skill's commit step (step 9e and step 11) hardcodes a single commit-gate path: "Delegate to `wr-risk-scorer:pipeline` (subagent_type) to assess the staged changes and create a bypass marker". When the current tool set does not expose the `wr-risk-scorer:pipeline` subagent-type (e.g., when `manage-problem` is itself running inside a spawned subagent), there is no documented fallback and the commit is silently skipped — leaving completed work uncommitted.

This was observed in a real AFK run on 2026-04-17: the subagent completed the P026 fix (sync-install-utils + CI drift check + bats tests), staged 6 files, but was unable to commit because the `Skill` tool rejected `wr-risk-scorer:pipeline` as "Unknown skill" and the subagent's tool set did not include a way to invoke the subagent-type. Per ADR-014 and ADR-013 non-interactive fail-safe rules, the subagent skipped the commit. All work was left staged with no path to completion without the user's manual intervention.

The skill should document a fallback — e.g., invoke the `/wr-risk-scorer:assess-release` skill (which is a skill, not a subagent-type, and therefore available anywhere the Skill tool works) — so the commit gate can be satisfied from any invocation context.

## Symptoms

- Subagents running `manage-problem work` complete the fix but cannot commit
- Work is staged but not committed at the end of an iteration
- No clear signal to the user that the commit gate failed for a delegation reason (vs. a risk-above-appetite reason)
- AFK loops that rely on `manage-problem` to self-commit accumulate uncommitted work across iterations

## Workaround

The user invokes `/wr-risk-scorer:assess-release` from the main session to generate the bypass marker, then runs `git commit` with the appropriate message.

## Impact Assessment

- **Who is affected**: Solo developers running AFK loops (JTBD-006); any agent-initiated workflow that delegates `manage-problem` to a subagent
- **Frequency**: Every AFK iteration; every subagent-mediated manage-problem invocation
- **Severity**: Medium — work is preserved (staged), but the autonomous commit promise of ADR-014 is broken
- **Analytics**: N/A

## Root Cause Analysis

The `wr-risk-scorer:pipeline` subagent-type is only exposed to contexts that have explicit access to the risk-scorer plugin's Agent-type registry. General-purpose subagents spawned via the Agent tool (e.g., from `wr-itil:work-problems` iteration agents) receive a restricted tool set that does not include this subagent-type. When `manage-problem` runs in such a context, its hardcoded single-path commit-gate delegation fails with "Unknown skill" and the commit is skipped.

Per ADR-015, the `/wr-risk-scorer:assess-release` skill wraps the same pipeline subagent and — via the `PostToolUse:Agent` hook — produces an equivalent bypass marker. Skills registered in the project plugin set are available to any context with the Skill tool, including spawned subagents. This makes `assess-release` a semantically equivalent fallback to the direct subagent-type delegation.

### Investigation Tasks

- [x] Confirm which subagent tool sets do not include `wr-risk-scorer:pipeline` as an allowed subagent-type — confirmed: general-purpose subagents spawned via the Agent tool during AFK orchestration do not expose it
- [x] Determine whether the gap should be fixed by (a) adding a fallback path in `manage-problem` SKILL.md, (b) expanding subagent tool sets, or (c) extending ADR-014 to cover the delegation-unavailable case — chose (a): documented fallback in SKILL.md is the lowest-blast-radius fix and works within existing ADR-015 equivalence
- [x] Check whether `/wr-risk-scorer:assess-release` is semantically equivalent to the `wr-risk-scorer:pipeline` subagent-type for gate-satisfaction purposes — yes, per ADR-015 the skill wraps the same subagent and the `PostToolUse:Agent` hook produces an equivalent bypass marker
- [ ] Create a reproduction test (invoke manage-problem work from a general-purpose subagent, assert commit either lands or produces a clear "gate unavailable" signal) — deferred; covered by operational verification
- [ ] Create INVEST story for permanent fix — not needed; fix landed in this session

## Fix Strategy

Document a two-path commit gate in `packages/itil/skills/manage-problem/SKILL.md` steps 9e and 11:
1. **Primary**: delegate to `wr-risk-scorer:pipeline` subagent-type via the Agent tool.
2. **Fallback**: if the subagent-type is unavailable in the current context, invoke `/wr-risk-scorer:assess-release` via the Skill tool. ADR-015 confirms equivalence.

Preserve the ADR-013 Rule 6 non-interactive fail-safe — the fallback is specifically for the *delegation-unavailable* branch; the *risk-above-appetite* branch still fails safe by skipping the commit and reporting the uncommitted state.

## Fix Released

Implemented 2026-04-17 (this session):

- Edited `packages/itil/skills/manage-problem/SKILL.md` step 9e and step 11 to document the two-path commit gate (Primary: pipeline subagent-type; Fallback: `/wr-risk-scorer:assess-release` skill). Both produce equivalent bypass markers per ADR-015.
- Clarified that the non-interactive fail-safe applies only to the risk-above-appetite branch, not the delegation-unavailable case — closing the silent-skip loophole.

Pending user verification in production: next time `/wr-itil:work-problems` or any orchestrator spawns a subagent that runs `manage-problem work`, the subagent should either commit successfully via the fallback or surface a structured "gate unavailable" signal rather than silently skipping.

## Related

- [JTBD-006](../jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md) — AFK backlog progression (this defect prevents the "git commits happen automatically when risk is within appetite" outcome)
- [ADR-013](../decisions/013-structured-user-interaction-for-governance-decisions.proposed.md) — non-interactive fail-safe rule
- [ADR-014](../decisions/014-governance-skills-commit-their-own-work.proposed.md) — commit obligation; the fail-safe matrix does not currently cover delegation-unavailable
- [P036](036-work-problems-commit-gate-subagent-instructions.open.md) — sibling defect in the orchestrator skill
- [packages/itil/skills/manage-problem/SKILL.md](../../packages/itil/skills/manage-problem/SKILL.md) — step 9e and step 11 hardcode the pipeline delegation
