# Problem 175: Agent over-narrows scope-pin words ("just", "only", "first") into count constraints — halts AFK loop on agent-inferred scope rather than framework-prescribed stop conditions

**Status**: Open
**Reported**: 2026-05-06
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

When the user pins direction with a scope-pin word like "just work P170", "only work P170", or "first work P170", the framework reading is **scope filter**: "override Step 1's WSJF selection; work this ticket instead". The loop semantics (Step 7 "Loop. Go back to step 1") are unchanged — iterations continue on the pinned ticket until a framework-prescribed stop condition fires (#1 no actionable / #2 all interactive / #3 all blocked / quota exhaustion / hard halt). The scope-pin word does NOT alter loop control.

Agent observed misreading the scope-pin word as a **count constraint** ("exactly one iter") and emitting `ALL_DONE` after iter 1 returned `outcome: partial-progress` with explicit `outstanding_questions` queued and remaining slices named. The premature halt is agent-inferred, not framework-resolved — none of the documented stop conditions in /wr-itil:work-problems Step 2 fired; the iter's own ITERATION_SUMMARY explicitly named B7.T2-T4 + Slices 5-6 as remaining actionable work on the pinned ticket.

This is a **class of behaviour**: under-specified scope words ("just", "only", "first", "merely", "simply") get parsed as count constraints rather than scope filters. The framework already resolved loop control via Step 7 + Step 2's stop conditions; agent should not invent additional halt criteria from natural-language modifiers.

**Concrete evidence** — this session, 2026-05-06:

1. User invoked `/wr-itil:work-problems just work P170`.
2. Iter 1 dispatched, completed at commit `9b9920e` (Slice 4 B6.T1-T4 — RFC-001 retro on P168), returned `outcome: partial-progress` with named remaining work (`B7.T2-T4 (type-tag full migration with I2 behavioural test) deferred to future iter. Slice 5 (forward dogfood) and Slice 6 (graduate to adopters) remain.`).
3. Orchestrator (this agent's main turn) emitted `ALL_DONE` and the final summary table.
4. User replied "why did you stop?" — with `STOP` correction signal triggering P078 capture-on-correction OFFER discipline.
5. Operational answer: agent had read "just" as "single iter only".

**Inverse failure** to P130 (treat user as transient — agent inferring presence-shape from incomplete signal). P130 says agent should NOT halt on "user might want to review" mid-loop; P175 says agent should NOT halt on agent-inferred scope when framework hasn't fired a stop condition. Both stem from the same root: agent inferring loop-control semantics that the framework already resolved.

The framework-resolution boundary per ADR-044: loop control is framework-resolved (Step 7 + Step 2 stop conditions); agent over-narrowing scope-pin words into count constraints is sub-contracting framework-resolved decisions back to agent inference (the analogous failure mode to P132's lazy AskUserQuestion deferral, except in the opposite direction — instead of lazily asking what's framework-resolved, lazily inventing halt logic that's framework-resolved).

## Symptoms

- AFK loop emits `ALL_DONE` after one iteration despite the iter's own `ITERATION_SUMMARY` reporting `outcome: partial-progress` with named remaining sub-tasks on the pinned ticket.
- User reaction signal: "why did you stop?" / "keep going" / "you said you were going to do X but only did one" — strong-affect correction triggering P078.
- Orchestrator's reported "Remaining Backlog" includes the pinned ticket itself with WSJF still active and additional named slices/tasks visible.
- No documented Step 2 stop condition cited in the orchestrator's halt summary; halt summary references the user's invocation arguments instead (e.g. "user said 'just' meaning single iter").

## Workaround

Currently — user must re-prompt: "why did you stop?" → triggers P078 correction-capture → agent acknowledges + resumes the loop manually. Each re-prompt costs a round-trip the framework was supposed to eliminate.

A defensive workaround at orchestrator dispatch time: re-emit the loop-control rule explicitly in the iter prompt body or in the orchestrator's own pre-Step-1 reasoning — "scope pin = override WSJF selection; loop continues until Step 2 stop condition fires; agent does NOT invent halt logic from natural-language modifiers". Inelegant but breaks the misreading.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: solo-developer using AFK orchestrator; secondary: future adopters who consume the work-problems skill expecting framework-defined loop semantics.
- **Frequency**: (deferred to investigation) — first observed 2026-05-06; class-of-behaviour assessment suggests recurrence likely whenever a scope-pin word appears in the invocation args.
- **Severity**: (deferred to investigation) — likely Moderate; adds a re-prompt round-trip per AFK invocation and breaks the AFK-orchestrator value proposition for any user who scopes via natural language.
- **Analytics**: (deferred to investigation) — count of `/wr-itil:work-problems` invocations with scope-pin args (`just`, `only`, `first`, `merely`, `simply`) where the orchestrator emitted `ALL_DONE` after exactly one iter.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause: is this a SKILL.md gap (stop conditions don't explicitly disclaim scope-pin-word interpretation) or an agent-prior gap (training-data over-association of "just" with "exactly one")? Likely both — SKILL.md amendment + worked-example call-out is the load-bearing fix per ADR-051.
- [ ] Create reproduction test: behavioural bats fixture asserting orchestrator does NOT emit `ALL_DONE` after one iter when (a) iter returned `outcome: partial-progress` AND (b) the same ticket appears in the Remaining Backlog AND (c) no Step 2 stop condition is documented in the halt summary. Negative test: orchestrator DOES emit `ALL_DONE` when stop-condition #1/#2/#3 fires legitimately.
- [ ] Sweep ADR-044 framework-resolution boundary worked examples — does P175 belong in the inverse-P132 lazy-deferral worked-example list (currently P130 transient-user is the only inverse-failure entry)? If so, surface in `run-retro` Step 1.5 silent classification + Step 2d Ask Hygiene Pass criteria.
- [ ] Check whether the same misreading appears in non-AFK orchestrator surfaces — `/wr-itil:work-problem` (singular) might exhibit the same class when called with scope-pin args.
- [ ] Consider symmetric-inverse work: if "just" is misread as count constraint, are "every", "all", "each" misread as count expansion (e.g. user says "work every P170 sub-task" and agent dispatches N parallel iters)? Probably not — the natural-language asymmetry favours under-narrowing more than over-broadening.

## Dependencies

- **Blocks**: (none — but composes with the AFK-orchestrator UX value proposition; deferred fix means every scope-pinned invocation costs a re-prompt round-trip)
- **Blocked by**: (none)
- **Composes with**:
  - **P078** (capture-on-correction OFFER pattern) — this very ticket was captured under P078 discipline after the STOP correction signal.
  - **P130** (treat user as transient — orchestrator over-inferring presence-shape) — same root cause class: agent over-inferring loop-control semantics. P175 is the inverse-presence failure: instead of inferring "user is here, ask them", agent infers "user wants exactly one, halt".
  - **P132** (over-ask in interactive sessions — inverse-P078) — same root cause: agent inferring framework-unresolved decisions when framework already resolved. P175 is the inverse-direction failure: instead of asking the user, agent invents halt logic.
  - **ADR-044** (decision-delegation contract — framework-resolution boundary) — loop control is framework-resolved; agent must not sub-contract back via natural-language inference.
  - **ADR-013 Rule 6** (non-interactive AFK fail-safe) — when ambiguous, halt-with-report is the documented contract; agent inventing halt without ambiguity violates Rule 6's spirit.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-044 — framework-resolution boundary; loop control already resolved.
- ADR-013 Rule 6 — non-interactive fail-safe.
- /wr-itil:work-problems SKILL.md Step 2 — the canonical stop-condition list.
- /wr-itil:work-problems SKILL.md Step 7 — "Loop. Go back to step 1" — the contract this ticket says agent must not subvert.
- P078 — capture-on-correction discipline.
- P130 — treat user as transient (inverse-presence failure).
- P132 — over-ask in interactive sessions (inverse-direction failure).
- Session evidence — 2026-05-06 commit `9b9920e` followed by orchestrator `ALL_DONE` emission; user replied "why did you stop?".
