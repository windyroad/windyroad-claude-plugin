# Problem 255: ADR-036 Rule 6 AFK fail-safe clamps intake-scaffold auto-execution — sibling-class to P254 at the intake-scaffold surface; external-comms risk assessment is the actual protection layer

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Sibling-class to P254 at the intake-scaffold surface. When the AFK orchestrator (`/wr-itil:work-problems` Step 0 first-run preamble check, per ADR-036) detects a missing intake-scaffold surface in the current project — e.g. partial state where `SECURITY.md` is present but `.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `SUPPORT.md`, `CONTRIBUTING.md` are missing — ADR-036 Rule 6 forbids the orchestrator from auto-scaffolding. Instead the orchestrator appends a one-line `"pending intake scaffold"` note to the iter's `ITERATION_SUMMARY` notes field. The user reviews the pending notes on the next interactive session and runs `/wr-itil:scaffold-intake` manually.

Observed shape (verbatim from a recent AFK iter's intake-scaffold preamble check):

> Intake scaffold pending — partial (SECURITY.md present; .github/ISSUE_TEMPLATE/config.yml, problem-report.yml, SUPPORT.md, CONTRIBUTING.md missing). Per ADR-036 Rule 6 fail-safe, AFK orchestrator does NOT auto-scaffold; note carried for user attention on return.

This is the **same class of clamp as P254** at a different surface:

- **P254**: `/wr-itil:report-upstream` automation blocks (Step 6 security-path interactive halt + work-problems Step 4 upstream-blocked AFK fallback that writes a pending-marker instead of auto-invoking). Outbound feedback signal gated behind user interactive invocation.
- **P255 (this ticket)**: `/wr-itil:scaffold-intake` AFK auto-invoke forbidden per ADR-036 Rule 6 fail-safe. Intake-surface bootstrap gated behind user interactive invocation.

Both surfaces have the same shape: an agent identifies the work needs doing, the framework already has a protection layer (external-comms risk-scorer / pure-rename + pure-mkdir + standalone-commit policy-authorisation per ADR-019 precedent), but the AFK contract chose deferral instead of forward motion.

The user direction from P254 applies isomorphically: *"I want agents to freely [scaffold intake]. I don't want to clamp that feedback signal. The external-comms risk assessment protects us."* For the intake-scaffold surface specifically, the protection layer is even simpler — scaffold-intake operations are pure-additive file writes (no semantic merge, no destructive overwrite, no external-comms surface, fully reversible via `git revert`); the action class is policy-authorised under ADR-019's precedent shape.

**Audit note on type classification (added at capture time)**: same as P254. The Step 1.5 lexical-signal classifier would key on "friction" / "feedback signal" verbatim citations if pulled from the description; the agent classified `technical` because the description is unambiguously about agent-SKILL contract surfaces (ADR-036 Rule 6 AFK fail-safe and `/wr-itil:scaffold-intake` invocation policy), not adopter UX. See P254 audit note for the full reasoning.

## Symptoms

- AFK orchestrator iters append `"pending intake scaffold"` notes to `ITERATION_SUMMARY` and never auto-scaffold even when the project state is unambiguous (e.g. `SECURITY.md` present + intake files missing — clearly partial-scaffold needing completion).
- Adopters of `@windyroad/itil` may run an AFK loop on a fresh project and find that the intake surface remains absent for the entire loop, with notes accumulating one per iter; intake is only bootstrapped after the user returns and runs `/wr-itil:scaffold-intake` manually.
- The deferral preserves an artificial "user attention required" gate on a fully-reversible mechanical operation that the external-comms / governance risk layer already covers.

(symptoms section deferred to investigation — above are verbatim observations from the capture session)

## Workaround

User runs `/wr-itil:scaffold-intake` (or `/wr-itil:manage-problem` with the foreground prompt branch) on session start when they see the pending-intake-scaffold note in the prior AFK summary.

## Impact Assessment

- **Who is affected**: Plugin-user persona (JTBD-301) adopting `@windyroad/itil` in a new project — runs the AFK loop expecting the intake surface to bootstrap; finds it still missing on return. Plugin-developer persona (JTBD-101) — relies on intake-scaffold being present for inbound bug reports; AFK delay extends the window where the project has no inbound surface.
- **Frequency**: Every AFK loop invocation in a project that's missing one or more intake files. For fresh adopters, this is the FIRST AFK loop. For partial-scaffold states (the observed shape), every iter logs a note until the user manually runs scaffold-intake.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems`.
- [ ] Audit ADR-036 Rule 6 ("AFK orchestrator does NOT auto-scaffold; note carried for user attention on return") against ADR-019's pure-rename + pure-mkdir + standalone-commit policy-authorisation precedent — does Rule 6 add value over the policy-authorisation shape, or is it pure defence-in-depth that's clamping the auto-scaffold action?
- [ ] Specify the auto-scaffold contract: under what conditions should the AFK orchestrator auto-invoke `/wr-itil:scaffold-intake`? Suggested gate: (a) intake files detected as missing or partial, (b) no `.claude/.intake-scaffold-declined` marker, (c) no `.claude/.intake-scaffold-done` marker, (d) the scaffold operation classifies as policy-authorised under ADR-019 (pure-additive file writes, fully reversible). All four currently fire on the observed shape; the gate should resolve PASS and auto-invoke.
- [ ] Compose the ADR-036 amendment with P254's `/wr-itil:report-upstream` amendment — both surfaces share the same class-of-clamp (AFK fail-safe blocks an action the framework's risk layer already protects); a unified amendment ADR may cover both, OR each SKILL gets its own narrowly-scoped amendment that cites the parent class.
- [ ] Cite the user's verbatim direction (from P254's capture session): *"when you build the report upstream capability, you put automation blocks in there, which creates undesirable friction. I want agents to freely report issues. I don't want to clamp that feedback signal. The external comms risk assessment protects us."* The intake-scaffold surface mirrors the structure.
- [ ] Verify the existing decline-marker contract (`.claude/.intake-scaffold-declined`) still functions correctly when auto-scaffold is enabled — user MUST be able to opt out.

## Dependencies

- **Blocks**: (none — pending-note workaround keeps the channel functional, just slow.)
- **Blocked by**: (none — ADR-036 + ADR-019 + ADR-013 are all landed; this is a reconciliation of their interactions.)
- **Composes with**: P254 (report-upstream automation blocks — sibling-class at the upstream-feedback surface)

## Related

- `/wr-itil:work-problems` SKILL.md "First-run intake-scaffold pointer (P065 / ADR-036)" preamble — current AFK Rule 6 fail-safe.
- `/wr-itil:scaffold-intake` SKILL.md — the deferred auto-invocation target.
- ADR-036 — `/wr-itil:scaffold-intake` skill + layered triggers; Rule 6 names the AFK fail-safe (`AFK orchestrator does NOT auto-scaffold; note carried for user attention on return`).
- ADR-019 — preflight + policy-authorisation precedent (pure-rename / pure-mkdir / standalone-commit actions are policy-authorised). Intake-scaffold operations match this class structurally — fully reversible, no destructive overwrite, no external-comms surface.
- ADR-013 Rule 5 — policy-authorised silent-proceed framework principle.
- ADR-028 — external-comms risk-scorer gate (the user's named protection layer).
- ADR-044 — decision-delegation contract; this ticket frames the clamp as defensive over-asking the framework already resolved.
- ADR-032 — AFK iteration-isolation wrapper; the orchestrator's AFK contract should be re-evaluated for pure-policy-authorised actions like intake-scaffold.
- P254 — sibling capture (report-upstream automation blocks — same class-of-behaviour at the upstream-feedback surface).
- P065 — driver for the original intake-scaffold pointer at work-problems Step 0.

(captured via `/wr-itil:capture-problem`; expand at next investigation)
