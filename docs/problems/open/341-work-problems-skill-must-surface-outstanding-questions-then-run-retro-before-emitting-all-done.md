# Problem 341: `/wr-itil:work-problems` SKILL must surface outstanding questions FIRST, then run a retro, THEN emit `ALL_DONE` — current SKILL contract allows `ALL_DONE` to fire without one or both gates

**Status**: Open
**Reported**: 2026-05-31
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next `/wr-itil:review-problems`; HIGH in practice — accumulated direction-class observations and retro-class learnings can both be silently dropped on AFK-loop end if the orchestrator emits `ALL_DONE` without surfacing them or running retro)
**Origin**: internal
**Effort**: M (deferred — re-rate at next `/wr-itil:review-problems`; SKILL.md amendment to enforce sequence + behavioural bats coverage + possibly hook-enforced ordering)
**Type**: technical

## Description

Surfaced 2026-05-31 by direct user direction: *"The work-problems skill MUST surface the outstanding questions at the end before emitting ALL_DONE. It MUST then run a retro. Only then should it emit ALL_DONE. Please capture problem tickets for this"*.

Current `/wr-itil:work-problems` SKILL.md contract has both gates documented but does NOT structurally enforce the sequence:

1. **Outstanding-questions surface** is covered by Step 2.5 ("Surface accumulated outstanding questions at loop end") and Step 2.5b ("Surface accumulated user-answerable skips — reusable surfacing routine"). Both fire conditionally on stop-condition triggers; neither is wired as a mandatory pre-`ALL_DONE` gate.
2. **Retro** is mentioned in iter-prompt body as "retro-on-exit (P086)" — fires INSIDE each iter subprocess before that iter's `ITERATION_SUMMARY`. There is NO orchestrator-level loop-end retro. The session-level retrospective for the whole AFK loop is implicit; the SKILL.md doesn't prescribe one.
3. **`ALL_DONE` emit** is the final sentinel in the Output Format section. Per the SKILL.md it appears in `## Output Format` after the "Remaining Backlog" section. The contract doesn't enforce that outstanding-questions surface + retro have both completed first.

The structural gap: the SKILL allows the orchestrator to emit `ALL_DONE` while leaving direction-class observations queued (`.afk-run-state/outstanding-questions.jsonl` unread) and without running a session-level retro. Both gates are nominally documented but neither is a hard prerequisite for `ALL_DONE` emission. The user just observed this in the current session: iter retros' observations about iter 12 + iter 7 are queued for user triage rather than auto-ticketed (sibling ticket P342 captures that class), AND no orchestrator-level retro has been documented this session — only per-iter retros.

## Symptoms

- `ALL_DONE` may emit at loop end without the orchestrator having surfaced accumulated `outstanding-questions.jsonl` entries to the user (via batched `AskUserQuestion` per Step 2.5/2.5b's "default branch" OR a structured-summary table per the "fallback branch").
- `ALL_DONE` may emit without a session-level retro running, leaving session-level learnings (cross-iter patterns, recurring class-of-behaviour, framework-improvement candidates) un-codified and un-ticketed.
- User returning to a completed AFK loop sees `ALL_DONE` but discovers accumulated direction-class observations sitting in the queue file unsurfaced AND no session-level retrospective.

## Workaround

User explicitly directs: *"surface the outstanding questions ... then run a retro ... only then ... ALL_DONE"*. Until SKILL.md enforces the sequence structurally, the orchestrator must remember to fire both gates before `ALL_DONE`.

## Impact Assessment

- **Who is affected**: every user invoking `/wr-itil:work-problems` whose AFK loops accumulate direction-class observations OR generate session-level learnings worth capturing.
- **Frequency**: every AFK loop with ≥1 iter that queues an outstanding question OR that surfaces a friction pattern worth capturing as a retro learning.
- **Severity**: HIGH in practice — direction-class observations are precisely the surface ADR-044 was authored to protect (user-input is for genuine direction-setting); silently dropping them defeats the whole accumulation discipline.
- **Analytics**: this session (2026-05-30 → 2026-05-31, ~14 iter dispatches across two consecutive day boundaries) has `.afk-run-state/outstanding-questions.jsonl` with N queued entries (count varies; some pre-surfaced via mid-session `AskUserQuestion`s, others still pending) AND no orchestrator-level retro committed.

## Root Cause Analysis

SKILL.md Step 2.5 + Step 2.5b are CONDITIONAL gates that fire only when specific stop-conditions trigger:

> Step 2.5b is the single source of truth for routing accumulated user-answerable skip-reasons through `AskUserQuestion`-when-available-else-table. It is the sub-step that Step 2.5 (stop-condition #2) AND every halt path that fires after iters have accumulated skipped tickets cross-references...

The trigger model is "fire on stop-condition #2 OR fire on halt-paths". Stop-condition #1 (no actionable problems) and stop-condition #3 (all blocked) do NOT route through Step 2.5b unless the queue happens to be non-empty AND the agent remembers the cross-reference. The SKILL.md "halt-paths-must-route-design-questions-through-Step-2.5b" principle is named but only as advisory cross-reference, not as a structurally-enforced ordering.

Session-level retro is not mentioned in SKILL.md at the orchestrator level — only at the iter-subprocess level (Step 5's retro-on-exit clause). There is no "Step 7.5 — run session-level retro before ALL_DONE" or equivalent.

The required structural shape:

1. **Pre-`ALL_DONE` gate sequence**:
   a. Read `.afk-run-state/outstanding-questions.jsonl`. If non-empty, fire Step 2.5b's surfacing routine (`AskUserQuestion`-default with structured-summary fallback). On completion, truncate the queue.
   b. Run session-level retro via `/wr-retrospective:run-retro` — covers the AFK loop's cross-iter patterns, friction observations, and framework-improvement candidates. Retro commits its own work per ADR-014.
   c. Emit `ALL_DONE` ONLY after both (a) and (b) complete.

2. **Hard-fail mode**: if either gate cannot complete (e.g., `outstanding-questions.jsonl` has entries the user must triage but the user is not present), SKILL.md MUST direct the orchestrator to halt with a clear directive (NOT emit `ALL_DONE`). The halt is recoverable — user returns, surfaces, completes the loop with `ALL_DONE`.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems`
- [ ] Amend `/wr-itil:work-problems` SKILL.md to add a new step (e.g. "Step 2.4 — Pre-`ALL_DONE` gate sequence") that fires UNCONDITIONALLY before `ALL_DONE` emit, sequencing (a) outstanding-questions surface + (b) session-level retro.
- [ ] Amend the SKILL.md Output Format section to reflect the new gate sequence — `ALL_DONE` appears AFTER outstanding-questions surface AND retro, not before/around.
- [ ] Behavioural bats coverage: assert SKILL.md carries the new step prose; assert SKILL.md `ALL_DONE` mention is positioned AFTER the gate-sequence prose; assert the gate-sequence prose names BOTH outstanding-questions surface AND session-level retro as hard prerequisites.
- [ ] Consider whether the gate sequence needs hook-enforced ordering (e.g., a PostToolUse hook that denies emitting `ALL_DONE` in the orchestrator main turn output if the queue is non-empty OR if no retro commit was made this session). Decide opportunistically; default to SKILL.md prose enforcement for the first cut.
- [ ] Sibling-amend `/wr-itil:work-problem` (singular) SKILL.md if it has the same structural gap.
- [ ] Cross-reference P342 (sibling — iter retros queue observations instead of auto-ticketing; same trust-boundary class).

## Dependencies

- **Blocks**: trustworthy AFK loop completion. Until the gates are structurally enforced, `ALL_DONE` semantically means "loop terminated" but says NOTHING about whether the accumulated direction-class observations and session-level learnings were surfaced/captured.
- **Blocked by**: (none — fix is bounded to SKILL.md amendments + bats coverage).
- **Composes with**: P342 (sibling — iter retros queue instead of ticket; same trust-boundary class), ADR-044 (decision-delegation contract — direction-class observations are precisely the surface this enforcement protects), ADR-013 (structured user interaction), P086 (retro-on-exit — currently only at iter level; this ticket extends to orchestrator level).

## Related

(captured via direct user direction 2026-05-31 during session 9 AFK exchange after iter 1 P339+P340 completion)

- **P342** — sibling-class capture; iter retros queue observations as outstanding-questions instead of auto-ticketing (same trust-boundary).
- **ADR-013** — structured user interaction contract; outstanding-questions surface is the load-bearing application here.
- **ADR-014** — governance skills commit own work; session-level retro commit applies.
- **ADR-044** — decision-delegation contract; direction-class observations are the protected surface this gate enforces.
- **P086** — retro-on-exit at iter subprocess level; this ticket extends to orchestrator level.
- `packages/itil/skills/work-problems/SKILL.md` — amendment locus (Step 2.4 or equivalent + Output Format section).
- `packages/itil/skills/work-problems/test/*.bats` — behavioural-coverage locus.
