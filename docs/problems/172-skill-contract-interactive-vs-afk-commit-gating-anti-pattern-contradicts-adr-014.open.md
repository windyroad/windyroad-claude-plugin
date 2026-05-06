# Problem 172: Skill contract "interactive vs AFK" commit-gating anti-pattern contradicts ADR-014

**Status**: Open
**Reported**: 2026-05-05
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Skill contracts that gate agent commits behind "interactive vs AFK" branching are presumed wrong — any "interactive: do NOT auto-commit, let user stage + commit" carve-out (e.g. `packages/itil/skills/reconcile-readme/SKILL.md` Step 6) contradicts ADR-014 ("governance skills commit their own work") and operational reality (user runs in AFK-equivalent mode for months at a time; agent does all commits).

**Class of behaviour**: agent reads literal SKILL guidance and applies it despite session-context evidence the rule is wrong/outdated. The cure is to remove the carve-out from the skill contract, not to teach the agent to override the contract case-by-case (which would create a different fragility — agents second-guessing skills).

**Trigger**: 2026-05-05 — `/wr-itil:work-problem P170` → `/wr-itil:manage-problem` Step 0 preflight detected committed cross-session drift (P171 missing from WSJF Rankings) → halt-routed to `/wr-itil:reconcile-readme` → reconcile-readme applied corrections cleanly (exit 0 verification) → agent applied Step 6 interactive carve-out and stopped instead of committing, drawing FFS-grade correction: *"WTF. I haven't committed anything for months. You do all the commits"*. Reconciliation commit then landed as `d8ad3ed` after the correction.

**Sweep needed**: all skills with "interactive vs AFK" commit-gating; the carve-out is presumed wrong unless an explicit user-decision surface is justified per ADR-044's 6-class authority taxonomy. The commit decision is **framework-mediated** for governance skills per ADR-014 (the policy ALREADY decided governance skills commit their own work) — NOT user direction-setting. A per-invocation "do you want to commit?" surface re-asks a decision the framework has already resolved (lazy-AskUserQuestion under ADR-044).

**P132 inverse cousin**: P132 closed the surface where "agents over-ask in interactive sessions conflating mechanical stages with user-interactive stages". This ticket is the SKILL-side mirror — skill contracts themselves carry the inverse anti-pattern (codifying user-decision surfaces where the framework has already resolved the call). P132 was an agent-behaviour fix; this is a skill-contract correction.

## Symptoms

- `packages/itil/skills/reconcile-readme/SKILL.md` Step 6 explicitly carves out interactive mode: "When invoked interactively, do NOT auto-commit — present a diff summary to the user and let them stage + commit."
- Agent following the contract in interactive mode produces uncommitted edits and waits for the user.
- User has been operating in AFK-equivalent mode for months; the carve-out has been pure friction with no upside.
- The carve-out also breaks the upstream halt-route contract: `manage-problem` Step 0 says "The reconciliation must complete and commit before this manage-problem invocation proceeds" — interactive mode silently violates this because the reconcile commit never happens.

## Workaround

(deferred to investigation)

Per-invocation: agent commits anyway when the user signals via correction. Not durable.

## Impact Assessment

- **Who is affected**: every interactive `/wr-itil:work-problem` / `/wr-itil:manage-problem` / `/wr-itil:work-problems` invocation that hits Step 0 drift. Likely also affects any other skill contract carrying a similar "interactive vs AFK" commit gate (sweep needed).
- **Frequency**: any session where Step 0 reconciliation triggers — i.e., any session inheriting cross-session drift, which is exactly the case P118 was designed to handle.
- **Severity**: (deferred to investigation) — likely Low impact (workaround is one-line correction) × Medium-High likelihood (every drift-bearing session).
- **Analytics**: lazy-AskUserQuestion-count regression metric (Step 2d Ask Hygiene Pass — `packages/retrospective/scripts/check-ask-hygiene.sh`). Carve-out removals would reduce this surface.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Sweep all skills under `packages/*/skills/` for "interactive" / "AFK" / "auto-commit" carve-outs in commit-relevant steps
- [ ] For each carve-out: classify per ADR-044 authority taxonomy. If the commit decision is framework-mediated (governance commits per ADR-014, OR policy-within-appetite per RISK-POLICY.md), remove the carve-out. If genuinely user direction-setting, keep but document the ADR-044 category.
- [ ] Author behavioural test (per ADR-052) asserting interactive vs AFK commit behaviour is identical for governance skills
- [ ] Cross-reference with P132 verification — same family, opposite direction

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P132, P122, P130 (interactive-vs-AFK-mode behaviour family — agent-side cousins to this skill-contract-side ticket)

## Related

- `packages/itil/skills/reconcile-readme/SKILL.md` Step 6 — the trigger instance
- `docs/decisions/014-governance-skills-commit-their-own-work.proposed.md` — the ADR the carve-out contradicts
- `docs/decisions/044-decision-delegation-contract.proposed.md` — framework-resolution boundary; the 6-class authority taxonomy classifies which decisions belong to user vs framework
- `docs/problems/132-agents-over-ask-in-interactive-sessions-conflating-mechanical-stages-with-user-interactive-stages.verifying.md` — inverse-cousin agent-side ticket; P132 closed agent-side over-asking, this ticket closes skill-contract-side over-carving-out
- `packages/retrospective/scripts/check-ask-hygiene.sh` — regression metric surface
- Trigger session: 2026-05-05 `/wr-itil:work-problem P170` flow; reconciliation commit `d8ad3ed`
- Captured via /wr-itil:capture-problem per P078 capture-on-correction MANDATORY rule
