# Problem 110: Risk register has no passive trigger — `/wr-risk-scorer:create-risk` alone partially satisfies JTBD-001

**Status**: Verification Pending
**Reported**: 2026-04-22
**Fix Released**: 2026-04-25 (pending release)
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: (8 × 1.0) / 2 = **4.0**

> Surfaced 2026-04-22 by the JTBD gate review during P102's fix implementation. P102 landed candidate (a) — slash command `/wr-risk-scorer:create-risk` — as a minimum-viable invocation surface, with an explicit scope note that passive triggers (candidates b/c/d from P102) are out of scope and tracked here. JTBD review confirmed the slash command alone is a floor for JTBD-005 (on-demand) and tech-lead auditability but does **not** fully satisfy JTBD-001 (solo-developer: Enforce Governance Without Slowing Down), because JTBD-001 explicitly rejects reliance on the assistant remembering to invoke — "no manual step is needed to trigger reviews — they happen on every edit".

## Description

P102's root-cause analysis (lines 42-44 of the verifying ticket) identified that `docs/risks/` sat empty for 5 days after P033 scaffolding because scaffolding + "populate incrementally" has no trigger. The fix shipped in P102 adds ONE trigger: the user (or assistant) invoking `/wr-risk-scorer:create-risk` by hand. This is the same failure mode as the pre-fix state, only one level up — the register now depends on the assistant *remembering to invoke the command* when a register-worthy risk appears, which the JTBD-001 pain point identifies as unreliable ("agents skip steps").

The missing piece is a **passive trigger** — something that fires without the assistant's explicit intent. P102 enumerated three candidates: (b) risk-scorer pipeline back-channel, (c) retro-step, (d) CLAUDE.md workflow rule. This ticket tracks selecting and implementing one (or more) of them.

## Symptoms

- Slash-command-only invocation requires the assistant to *remember* to invoke during a workflow that identified a register-worthy risk. JTBD-001's pain point is precisely that assistants skip steps.
- Pipeline risk reports (`wr-risk-scorer:pipeline` in `.risk-reports/`) identify standing-risk shapes (e.g. confidential-info leakage, context budget, hook-stack overhead) on every commit/push/release, but there is no back-channel to the register — those findings stay ephemeral.
- Retros (`/wr-retrospective:run-retro`) capture codification candidates but do not explicitly capture risks observed during the session.
- CLAUDE.md has no workflow rule directing the assistant to propose a register entry when pipeline scoring identifies an above-appetite residual.

## Workaround

Assistant and user should manually run `/wr-risk-scorer:create-risk` when a register-worthy risk is identified during a session. P102's MVP slash command is the current workaround for this ticket.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001) — the "without slowing down" outcome is at risk because registration requires a manual step that may not fire.
  - Tech-lead persona (auditability) — a populated register that depends on manual invocation is a weaker audit signal than one backed by a passive process (the audit expects "risks are recorded as they surface", not "risks are recorded when the assistant remembers").
- **Frequency**: Every session that produces a register-worthy risk finding without an explicit invocation.
- **Severity**: Minor. The MVP slash command works when invoked; the harm is slow-leak (risks that are identified but not recorded). Not acutely breaking — closing this ticket improves the *reliability* of the register rather than restoring any lost functionality.
- **Analytics**: Baseline starts 2026-04-22 with R001 populated. If in 30 days the register has 1-2 entries despite session activity producing 5+ register-worthy findings, that confirms the gap.

## Root Cause Analysis

### Confirmed Root Cause

P102 deliberately scoped to CREATE-only slash command to ship a minimum-viable invocation surface within budget. That was the right call for P102's scope but left the passive-trigger work as follow-up. The root cause remains the same as P102: organic population assumes an invocation route, and a user-invoked slash command is not an organic route for risks that surface during autonomous AFK sessions, pipeline findings, or retro observations.

### Investigation Tasks

- [ ] Pick one trigger candidate to land first. Evaluate per JTBD fit + implementation cost:
  - **(b) Pipeline back-channel** — when `wr-risk-scorer:pipeline` identifies a standing-risk shape in `.risk-reports/`, write a "propose register entry?" hint into the pipeline output. The assistant reads the hint and invokes `/wr-risk-scorer:create-risk` with pre-filled context. Requires: modifying `packages/risk-scorer/agents/pipeline.md` to emit the hint + documenting the hand-off protocol in the create-risk SKILL.md. *Might amend ADR-026 (grounding flow).*
  - **(c) Retro step** — add a "risks-observed-this-session" step to `/wr-retrospective:run-retro`, analogous to Step 4b's codification-candidates table. Fires on every retro, so the trigger is guaranteed. Requires: modifying `packages/retrospective/skills/run-retro/SKILL.md`.
  - **(d) CLAUDE.md workflow rule** — mandate via a `UserPromptSubmit` hook injection that the assistant proposes a register entry whenever a pipeline scoring identifies an above-appetite residual. Hook-injected MANDATORY prose, per ADR-038 pattern. Requires: a new hook in risk-scorer + the CLAUDE.md rule.
- [ ] Architect review to decide whether (b) amends ADR-026, whether (c) is a local retro change or warrants amending retrospective's ADR, whether (d) warrants a new cross-cutting ADR.
- [ ] Observe whether the MVP slash command alone produces enough registry population in 30 days to close this ticket without the passive trigger. (Baseline starts 2026-04-22 with R001.)

### Fix Strategy

Pending investigation. Expected shape: pick one of (b)/(c)/(d) after 30 days of observation data. Favour (c) retro-step as a low-risk first pass — it is local to the retrospective plugin, fires on cadence, and does not require amending ADR-026. If pipeline hand-off becomes desirable later, (b) is additive on top of (c).

## Dependencies

- **Blocks**: Final closure of **P102** — P102 can move Verifying → Closed once this ticket lands a passive trigger *or* 30-day observation confirms the slash command alone is sufficient.
- **Blocked by**: (none — P102's scaffolding + create-risk skill is sufficient substrate)
- **Composes with**: P033 (parent scaffolding), P034 (centralising `.risk-reports/`), P099 (briefing unbounded append — related append-only concerns)

## Related

- **P102 (No invocation surface creates risk register entries)** — parent. This ticket is the explicitly-out-of-scope follow-up from P102's fix strategy.
- **P033 (No persistent risk register)** — grandparent. The scaffolding this chain populates.
- **JTBD-001 (Enforce Governance Without Slowing Down)** — the job this ticket's fix fully satisfies (P102's fix is a floor).
- **JTBD-005 (Invoke Governance Assessments On Demand)** — already served by P102's slash command.
- **ADR-026 (Risk-scorer grounding)** — may need amendment if Investigation Task (b) lands.
- **ADR-038 (Progressive disclosure via hook-injected prose)** — the pattern that candidate (d) would follow.

## Fix Released

**Date**: 2026-04-25
**Release**: pending (changeset `.changeset/wr-risk-scorer-p110-passive-trigger.md`, wr-risk-scorer minor bump)

### Scope landed

Candidate (b) — pipeline back-channel — shipped. The `wr-risk-scorer:pipeline` agent now emits a structured `RISK_REGISTER_HINT:` block alongside its existing `RISK_SCORES:` / `RISK_REMEDIATIONS:` outputs whenever a register-worthy risk shape is identified. The calling orchestrator consumes the hint post-remediation-loop and invokes `/wr-risk-scorer:create-risk` with pre-filled context. This is the passive trigger that closes the JTBD-001 gap P102 left open.

### Why (b) was chosen over (c) and (d)

Architect gate verdict (2026-04-25):

- **(b) shipped** — the pipeline agent is hook-fired on every commit/push/release gate, so a hint emitted from it inherits the passivity JTBD-001 requires ("no manual step is needed to trigger reviews — they happen on every edit"). It directly addresses the JTBD-001 failure mode by routing the risk data the scorer already computes into the register contract, instead of depending on the assistant remembering to invoke create-risk.
- **(c) deferred** — retro-step is genuinely additive (session-scope catch for non-pipeline observations like plan-mode findings or AFK session observations), but piling a second surface change on top of (b) would widen the M-iteration blast radius unnecessarily. Tracked as a follow-up ticket.
- **(d) rejected** — a CLAUDE.md UserPromptSubmit hook recreates the same "agent skips step" failure mode JTBD-001 identifies as a pain point. ADR-038 progressive-disclosure would also make implementation cost non-trivial (session-marker sync, drift tests, CI step). Not worth the cost for a trigger that fails JTBD-001's own test.

### Surface area

- `packages/risk-scorer/agents/pipeline.md` — new "Risk Register Hand-Off (Passive Trigger)" section defining the RISK_REGISTER_HINT: contract, trigger conditions (above-appetite-residual / confidentiality-disclosure / user-stated-precondition), reason-tag vocabulary, post-loop consumption semantics, silence guarantee.
- `packages/risk-scorer/agents/test/risk-scorer-register-hint.bats` — doc-lint guard for the new contract (8 assertions; Permitted Exception per ADR-005/P011).
- `docs/decisions/015-on-demand-assessment-skills.proposed.md` — new "Scorer Output Contract: RISK_REGISTER_HINT: Companion Line (P110)" section + two Confirmation bullets.

### Verification

- All 52 risk-scorer agent bats tests pass, including the 8 new RISK_REGISTER_HINT assertions.
- Full repo bats suite: 854 tests, zero failures.
- No ADR-026 amendment required — reason-tags are an enumerated vocabulary, not quantitative estimates.
- No ADR-042 Rule 2a conflict — hint is a post-loop sibling output, not a within-loop remediation.

### Follow-ups (not blocking closure)

- File a follow-up ticket for candidate (c) retro-step — session-scope catch for observations outside pipeline gates (plan mode, AFK findings, mid-session reflections).
- Observe over 30 days whether the pipeline hint alone produces register population that matches pipeline-computed risk events.

### Open questions for user review

- Should the downstream `assess-release` / `assess-wip` skills be extended to parse `RISK_REGISTER_HINT:` and offer to invoke `/wr-risk-scorer:create-risk` directly (closing the loop end-to-end), or should consumption stay at the orchestrator / assistant level for now?
- Does the three-tag enumerated vocabulary cover the expected register-worthy shapes, or should we add a fourth tag (e.g. `control-drift` — a previously-claimed control no longer exercises its failure scenario) before release?
