# Problem 020: No user-invocable skills for on-demand governance assessments

**Status**: Verification Pending
**Reported**: 2026-04-16
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: L
**WSJF**: 8.0 — (16 × 2.0) / 4

## Description

The governance plugins (`wr-risk-scorer`, `wr-architect`, `wr-jtbd`) expose *setup* skills — `update-policy`, `create-adr`, `update-guide` — but no *assessment* skills. The assessment agents (risk-scorer pipeline/wip/plan modes, architect review, jtbd review) are only reachable via hooks that fire on specific events (user-prompt-submit, pre-tool-use, pre-commit, etc.).

Users regularly want to invoke an assessment *on demand*, outside the hook triggers. The most common case this session: "I want to run a risk assessment on the current release queue now — not wait until I try to `git commit` or `git push`." No skill exists to do this. The user has to either (a) fake an event (stage something, attempt the gated action) or (b) remember to delegate to the agent via the Task tool manually, which requires knowing the subagent_type and crafting a self-contained prompt.

Same gap exists for architect (proactive "review the current plan against ADRs") and jtbd (proactive "do any open problems violate persona constraints?").

## Symptoms

- No `/wr-risk-scorer:assess` or `/wr-risk-scorer:assess-release` skill exists. To get a release risk score outside of a commit/push attempt, the user must invoke the `wr-risk-scorer:pipeline` subagent manually via the Task tool — requires remembering the exact subagent_type.
- No `/wr-architect:review` skill for proactive architecture compliance checks on a feature branch or ADR draft.
- No `/wr-jtbd:review` skill for proactive persona/job alignment checks.
- The risk-scorer agent has five modes (`wip`, `pipeline`, `plan`, `policy`, `agent`) but only two have hook entry points and none have user-invocable skill entry points.
- Users retrospectively asking "what's the release risk right now?" have no low-friction answer — the hook fires on `git commit`, but by then you're already committing.
- Inconsistent pattern with `wr-itil` (which now has both setup-style and assessment-style skills: `update-policy` vs `manage-problem`/`manage-incident`). Governance plugins feel half-built in comparison.

## Workaround

Invoke agents manually via the Task tool with `subagent_type: "wr-risk-scorer:pipeline"` (or `:architect:agent`, `:jtbd:agent`) and a self-contained prompt. Requires the user or the calling agent to know:
- The exact subagent_type string
- Which mode to pick (e.g. pipeline vs wip)
- What context the agent needs to produce a useful assessment (e.g. the release queue, the current staged diff, the draft plan)

High friction; easy to forget; inconsistent invocation prompts produce inconsistent reports.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — proactive governance checks are the "without slowing down" primitive; unreachable assessments undermine the job.
  - Solo-developer persona (JTBD-003 Compose Only the Guardrails I Need) — users who opt in to a governance plugin reasonably expect user-invocable affordances, not just passive hooks.
  - Tech-lead persona — retrospective + continuous-improvement contexts demand on-demand assessments (pre-flight reviews, release readiness checks, ad-hoc audits).
  - Plugin-developer persona (JTBD-101) — the missing skills make the plugin surface feel inconsistent (ITIL has assessment skills; governance plugins don't).
- **Frequency**: Every session that wants a pre-flight assessment before choosing to commit/push/release. Common during retros, ADR drafting, and release-readiness reviews.
- **Severity**: High. The governance discipline the plugins are designed to support depends on these assessments being cheap to invoke. Passive-only invocation means the assessments only run when the user is already committed to the action — the worst time to discover a problem.
- **Analytics**: Observed this session — user said "sometimes we want to proactively run a risk assessment on releasing, but there is no skill to invoke the agent to do that."

## Root Cause Analysis

The governance plugins were built hook-first. The assumption was that assessments should run automatically at gate points (commit, push, release), making a user-invocable skill redundant. In practice, that assumption fails:

1. **Gate points are too late.** By the time the commit hook fires, the user has already decided to commit. An on-demand pre-flight lets the user adjust course before committing.
2. **Not all assessments correspond to gates.** The risk-scorer `wip` mode (cumulative per-edit risk guidance) has no natural gate; the architect review on a draft plan has no gate.
3. **Hook-only invocation makes agents invisible.** Users don't know what agents exist until a hook fires. A skill surface makes the capability discoverable via `/` autocompletion.
4. **The `wr-itil` plugin already broke this assumption** with `manage-problem` and `manage-incident`. That sets the precedent — ADR-011 establishes the skill-wrapping pattern for coordinating tools/agents (architect note).

### Investigation Tasks

- [x] Inventory every assessment mode across `wr-risk-scorer`, `wr-architect`, `wr-jtbd`. For each, decide whether an on-demand skill wrapper is valuable (likely yes for: risk-scorer pipeline/wip/plan, architect review, jtbd review) or redundant with the setup skill (likely no for policy/adr-authoring).
- [x] Design skill naming. Candidates: `/wr-risk-scorer:assess` (mode picker) vs one per mode (`:assess-release`, `:assess-wip`, `:assess-plan`). Consistency with `wr-itil:manage-<noun>` pattern. **Outcome**: per-mode skills chosen; `assess-<artifact>` for quantitative scoring, `review-<artifact>` for qualitative compliance.
- [x] Decide: does an on-demand assessment satisfy the hook's gate marker (ADR-009), or is it advisory-only? **Outcome**: `assess-release` pre-satisfies the gate — PostToolUse hook writes bypass marker after pipeline subagent runs. `assess-wip` is advisory only (no bypass marker). Documented in ADR-015.
- [x] Define the context-gathering pattern. **Outcome**: each skill auto-detects from git state (`git log`, `git diff --cached`, changesets dir); AskUserQuestion fallback if ambiguous.
- [x] Reference ADR-011 as the skill-wrapping precedent. Draft companion ADR. **Outcome**: ADR-015 written and committed.
- [x] Consider whether this should be one cross-plugin skill or per-plugin skills. **Outcome**: per-plugin chosen (Option A in ADR-015) — more discoverable, independent cadence, consistent with precedent.
- [ ] Add skill-creator-style eval harness (see P012) for assessment skills — deferred to P012.

### Fix Strategy

Implement four SKILL.md files per ADR-015 scope table:

| Skill | Package | Subagent |
|-------|---------|---------|
| `assess-release` | `packages/risk-scorer/skills/assess-release/SKILL.md` | `wr-risk-scorer:pipeline` |
| `assess-wip` | `packages/risk-scorer/skills/assess-wip/SKILL.md` | `wr-risk-scorer:wip` |
| `review-design` | `packages/architect/skills/review-design/SKILL.md` | `wr-architect:agent` |
| `review-jobs` | `packages/jtbd/skills/review-jobs/SKILL.md` | `wr-jtbd:agent` |

Also update ADR-002 package inventory to list the new skills.

## Fix Released

All four SKILL.md files implemented and committed (2026-04-16):
- `packages/risk-scorer/skills/assess-release/SKILL.md` — delegates to `wr-risk-scorer:pipeline`; gate-marker aware; AskUserQuestion for ambiguous scope
- `packages/risk-scorer/skills/assess-wip/SKILL.md` — delegates to `wr-risk-scorer:wip`; advisory only
- `packages/architect/skills/review-design/SKILL.md` — delegates to `wr-architect:agent`; AskUserQuestion for violations
- `packages/jtbd/skills/review-jobs/SKILL.md` — delegates to `wr-jtbd:agent`; AskUserQuestion for gaps/breaks
- ADR-002 package inventory updated with all new skills
- ADR-015 written (design decision documenting the pattern)
- JTBD-005, JTBD-202, JTBD-101, tech-lead persona updated

Awaiting user verification that skills are invocable and produce useful output.

## Related

- ADR-015: `docs/decisions/015-on-demand-assessment-skills.proposed.md` — the ADR that governs this fix
- Precedent: ADR-011 (`docs/decisions/011-manage-incident-skill.proposed.md`) — skill-wrapping pattern coordinating tools/agents
- Gate interaction: ADR-009 (`docs/decisions/009-gate-marker-lifecycle.proposed.md`) — on-demand assessment vs hook-gate satisfaction question
- Sibling-pattern reference: `wr-itil` plugin (both `update-policy` setup skill and `manage-problem`/`manage-incident` assessment-style skills)
- `packages/risk-scorer/` — existing agent modes: `agent`, `wip`, `pipeline`, `plan`, `policy`
- `packages/architect/` — existing agent + `create-adr` setup skill
- `packages/jtbd/` — existing agent + `update-guide` setup skill
- JTBD-005: `docs/jtbd/solo-developer/JTBD-005-assess-on-demand.proposed.md`
- JTBD-202: `docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
- Tech-lead persona: `docs/jtbd/tech-lead/persona.md`
- P012: `docs/problems/012-skill-testing-harness.open.md` — eval harness deferred here
