# Problem 126: `/wr-itil:work-problems` failure-handling halt paths bypass Step 2.5's interactive-default routing for accumulated user-answerable design questions

**Status**: Verification Pending
**Reported**: 2026-04-26
**Transitioned to Known Error**: 2026-04-26 — Step 2.5b reusable surfacing routine extracted from Step 2.5; cross-references added to Step 0 (session-continuity halt + fetch-failure halt), Step 6.5 (Failure handling clause + ADR-042 Rule 5 halt), Step 6.75 (dirty-for-unknown-reason halt); architect FLAG guard added under Rule 5 separating prior-iter accumulated skips from halt-causing scorer-gap; Decisions Table row added; briefing entry added cross-referencing P122. Behavioural second-source: `packages/itil/skills/work-problems/test/work-problems-step-2-5b-cross-halt-routing.bats` (15/15 green; full work-problems suite 136/136 green). Awaiting release.
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M — extend `packages/itil/skills/work-problems/SKILL.md` Step 6.5 failure-handling clauses (CI-failure halt, ADR-042 Rule 5 above-appetite halt, network-failure halt, git-conflict halt) AND Step 0 prior-session-state halt branch AND Step 6.75 inter-iteration verification dirty-for-unknown-reason halt branch — every halt path that fires after iters have accumulated skipped tickets — to run Step 2.5's user-answerable-skip surfacing routine before emitting the AFK summary. Plus matching contract bats per ADR-037. Plus document the principle in the SKILL.md as "halt-paths-must-route-design-questions-through-Step-2.5".
**WSJF**: (12 × 1.0) / 2 = **6.0**

> Surfaced 2026-04-26 by direct user correction at the end of an AFK loop that halted on Step 6.5 CI-failure: "the end of the work-problems session didnt ask questions". The orchestrator had accumulated 6 user-answerable skip-reasons across 7 iters (P123 architect-design / P082 user-answerable transitive / P064 upstream-blocked / P101 user-answerable methodology / P014 user-answerable scope-pacing / P081 architect-design retrofit) and emitted them as an "Outstanding Design Questions" table in the ALL_DONE summary instead of calling `AskUserQuestion`. P122 (verifying — closed this same session) fixed the equivalent bug at Step 2.5 stop-condition #2; this ticket is the remaining-surface gap on the failure-handling halt paths that don't go through Step 2.5 at all.

## Description

P122's fix established the interactive-default routing at Step 2.5: when the AFK loop hits stop-condition #2 (all remaining problems require interactive input) AND `AskUserQuestion` is available (the orchestrator's main turn is interactive by construction per ADR-032 subprocess-boundary), batch the accumulated user-answerable skip-reasons into `AskUserQuestion` calls. The Outstanding Design Questions table is the AFK-only fallback when `AskUserQuestion` is unavailable.

But P122's fix is **scoped to Step 2.5's branch**. The AFK loop has multiple OTHER halt paths that fire AFTER iters have accumulated skipped tickets:

1. **Step 6.5 failure-handling halt** — CI red on a just-pushed commit (per the SKILL.md "Failure handling" clause: "stop the loop and report the failure in the AFK summary. Do not retry non-interactively"). Surfaced this session after iter 7's commit `8653541` failed CI on test 645.
2. **Step 6.5 ADR-042 Rule 5 above-appetite halt** — auto-apply loop exhausts without converging within appetite. Surfaced inside the SKILL contract; not yet observed in production.
3. **Step 0 prior-session-state halt** — session-continuity detection finds dirty-for-unknown-reason state (per P109's AFK fallback). Surfaced 2026-04-22 prior to P109's fix.
4. **Step 6.75 inter-iteration verification halt** — `git status --porcelain` returns dirty-for-unknown-reason between iters (per P036). Surfaced 2026-04-21 AFK iter 5.
5. **Network-failure halt at Step 0 `git fetch origin`** — `fail-closed by default` per the SKILL contract. Not observed.

In all 5 cases, the loop halts WITHOUT running Step 2.5's accumulated-skip-surfacing routine. The accumulated user-answerable design questions get either:
- Dumped into a manually-formatted "Outstanding Design Questions" table in the AFK summary (this session's behaviour — orchestrator violates P122's contract by emitting the AFK-fallback shape in interactive context), OR
- Lost entirely (orchestrator forgets to surface them; pure AFK summary).

Both are wrong. The user is interactive at the orchestrator's main turn by construction (per ADR-032). The contract should be: any halt path that fires AFTER ≥1 iter has skipped a user-answerable ticket MUST run Step 2.5's interactive-default routing (call `AskUserQuestion` when available; emit the table only when unavailable) before halting.

## Symptoms

- AFK loop halts via Step 6.5 / Step 0 / Step 6.75 halt paths with N accumulated user-answerable skips from prior iters.
- Orchestrator emits the AFK summary with an "Outstanding Design Questions" table inline.
- User reads the summary, notices the questions, and asks "why didn't you ask me?" — the P078 strong-signal correction this ticket was filed against.
- Subsequent loops re-encounter the same skipped tickets at the same skip-reasons because the design questions never got answered, perpetuating the cycle.

## Workaround

The user manually triggers the design-question round post-loop by saying "ask me the questions" (per the existing `feedback_askuserquestion_is_universal.md` memory + the AFK-stop-to-interactive-AskUserQuestion-escalation pattern documented in `docs/briefing/afk-subprocess.md`). The orchestrator's `/wr-retrospective:run-retro` Step 4a pattern then surfaces the accumulated skips via `AskUserQuestion`. Works but requires the user to remember the workaround and to spot the missed asking.

## Impact Assessment

- **Who is affected**: every user of `/wr-itil:work-problems` whose loop halts via any non-Step-2.5 halt path with accumulated user-answerable skips. Empirically: this session (Step 6.5 CI-failure halt with 6 accumulated skips). Likelihood: every AFK loop that hits a halt path before exhausting the backlog.
- **Frequency**: Likely. Halt paths fire whenever quota / CI / network / pre-existing dirty state intervenes. Most AFK loops over ~$10 cost / ~1hr wallclock will hit at least one halt before exhausting.
- **Severity**: Moderate. Not blocking — the manual workaround is documented and works. But it perpetuates the very cycle P122 was supposed to fix: design questions accumulate across loops, blocking the high-WSJF tickets they're attached to.
- **Likelihood**: Likely — observed this session; same architectural class as P122 which the user explicitly corrected.
- **Analytics**: Direct in-session evidence (this session's AFK summary table emit, the user's correction "the end of the work-problems session didnt ask questions").

## Root Cause Analysis

### Structural

P122's fix landed at Step 2.5 specifically — the SKILL.md Step 2.5 prose documents the interactive-default routing. The other halt paths (Step 6.5 failure-handling, Step 0 session-continuity, Step 6.75 inter-iter verification) have their own AFK-summary-emission code and don't route through Step 2.5. They emit summaries directly via the SKILL.md "Output Format" template, which carries the "Outstanding Design Questions" table as a fallback shape — but doesn't carry the interactive-default branch.

The fix shape is: extract Step 2.5's surfacing routine (the AskUserQuestion-when-available-else-table logic) into a named SKILL.md sub-step that EVERY halt path calls before emitting the final summary. Single source of truth; halt paths inherit the routing automatically.

### Investigation Tasks

- [ ] Audit all halt paths in `packages/itil/skills/work-problems/SKILL.md` and enumerate which ones emit a final AFK summary (Step 0 session-continuity halt; Step 6.5 failure-handling halt; Step 6.5 ADR-042 Rule 5 halt; Step 6.75 dirty-for-unknown-reason halt; Step 2 stop-condition #1; Step 2 stop-condition #3; quota-exhaust halt at Step 5).
- [ ] Decide the named sub-step shape: extract Step 2.5 verbatim into a `Step 2.5b — Surface accumulated user-answerable skips` reusable block, OR factor the routing into a SKILL.md "Halt path summary template" prose section that names the routing inline. Lean: the named sub-step (cross-referenced from each halt path) — keeps each halt path's prose terse + ensures the contract isn't accidentally forgotten on a new halt path.
- [ ] Decide whether the surfacing fires on EVERY halt or only when ≥1 user-answerable skip has accumulated. Lean: only when ≥1 skip-reason-category=`user-answerable` is on file — empty-skip halts don't need the round-trip.
- [ ] Behavioural bats: simulate each halt path with a fixture-generated skip list; assert the routing fires AskUserQuestion when available, table when unavailable.
- [ ] Update SKILL.md Output Format Decisions Table row(s) to reflect the cross-halt routing.
- [ ] Document in `docs/briefing/afk-subprocess.md` the principle "halt-paths-must-route-design-questions-through-Step-2.5" alongside the existing P122 entry.

### Fix Strategy

**Kind**: improve

**Shape**: skill (improvement stub — `packages/itil/skills/work-problems/SKILL.md`)

**Target file**: `packages/itil/skills/work-problems/SKILL.md`

**Observed flaw**: P122's interactive-default routing is scoped to Step 2.5's branch only. The 5 other halt paths emit AFK summaries directly without routing accumulated user-answerable skips through `AskUserQuestion`-when-available.

**Edit summary**: extract Step 2.5's surfacing routine into a reusable named sub-step (`Step 2.5b` or similar); cross-reference it from every halt path's summary-emission section; gate the call on ≥1 accumulated user-answerable skip; update SKILL.md Decisions Table to name the cross-halt routing.

**Evidence**:
- This session 2026-04-26 — `/wr-itil:work-problems` halted on Step 6.5 CI-failure after iter 7 with 6 accumulated user-answerable skips from prior iters; orchestrator emitted Outstanding Design Questions table inline rather than calling AskUserQuestion. User correction triggered this ticket via run-retro post-loop AskUserQuestion in the same orchestrator turn that filed this ticket.
- 2026-04-19 AFK iter 3 stop (per the existing `docs/briefing/afk-subprocess.md` "10 questions answered in 3 batches" entry) — same shape: post-stop user-driven escalation worked, but only because the user remembered to ask.

## Dependencies

- **Blocks**: any future AFK loop whose halt path fires before exhausting the backlog and accumulates ≥1 user-answerable skip.
- **Blocked by**: (none — fix is bounded to SKILL.md prose + bats).
- **Composes with**: P122 (verifying — established the routing at Step 2.5; this ticket extends it to remaining halt paths). P109 (closed — Step 0 session-continuity halt path). P036 (closed — Step 6.75 inter-iter verification halt path). P104 (verifying — Step 6.5 partial-progress hazard adjacent surface). P083 (verifying — iteration-worker forbids ScheduleWakeup, related contract surface).

## Fix Released

Released in `@windyroad/itil@0.21.1` (commit `6c46694` fix → release commit `4387824`, merge `12c24d8`):
- Step 2.5b reusable surfacing routine extracted from Step 2.5 in `packages/itil/skills/work-problems/SKILL.md`
- Cross-references added to Step 0 (session-continuity halt + fetch-failure halt), Step 6.5 (Failure handling clause + ADR-042 Rule 5 halt), Step 6.75 (dirty-for-unknown-reason halt)
- Architect FLAG guard under Rule 5 separating prior-iter accumulated skips from halt-causing scorer-gap
- Decisions Table row + briefing entry cross-referencing P122
- Behavioural second-source `packages/itil/skills/work-problems/test/work-problems-step-2-5b-cross-halt-routing.bats` (15/15 green; full work-problems suite 136/136 green)

Awaiting user verification: next AFK loop that hits a Step 6.5 / Step 0 / Step 6.75 halt with ≥1 accumulated user-answerable skip should route the questions through `AskUserQuestion` before emitting the AFK summary.

## Related

- **P122** (`docs/problems/122-work-problems-stop-condition-2-defaults-to-afk-table-instead-of-asking-interactively.verifying.md`) — direct parent. P122 fixed Step 2.5's branch; this ticket extends the same principle to the remaining halt paths.
- **P078** (`docs/problems/078-assistant-does-not-offer-problem-ticket-on-strong-signal-user-correction.verifying.md`) — this ticket's filing was triggered by P078's strong-signal-correction → ticket-capture flow ("the end of the work-problems session didnt ask questions" matches the contradiction-signal pattern in `lib/detectors.sh::CORRECTION_SIGNAL_PATTERNS`).
- **P109** (`docs/problems/109-work-problems-preflight-does-not-detect-prior-session-partial-work.closed.md`) — Step 0 session-continuity halt path. Currently routes via Step 0's AFK fallback ("halt with structured Prior-Session State report"); should also route through the new sub-step if ≥1 user-answerable skip is accumulated (none would be at Step 0 since iters haven't run yet — but the contract should be uniform).
- **P036** (`docs/problems/036-...closed.md`) — Step 6.75 inter-iter verification halt path.
- **P083** (`docs/problems/083-work-problems-iteration-worker-prompt-does-not-forbid-schedulewakeup.verifying.md`) — adjacent SKILL.md Step 5 contract surface.
- **P104** (`docs/problems/104-work-problems-partial-progress-iteration-outcome-can-paint-the-release-queue-into-a-mid-state-corner.verifying.md`) — Step 6.5 partial-progress hazard.
- **ADR-013 Rule 1** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — interactive default for governance decisions; directly applicable to the cross-halt routing.
- **ADR-013 Rule 6** — non-interactive AFK fail-safe; applies to the table fallback when AskUserQuestion is unavailable.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — orchestrator's main turn is interactive by construction; AFK persona served by subprocess boundary, not by suppressing AskUserQuestion at the orchestrator layer. P122's architect-FLAG cross-skill principle that this ticket extends.
- `packages/itil/skills/work-problems/SKILL.md` — primary fix target.
- `docs/briefing/afk-subprocess.md` — briefing entry for the principle alongside P122's existing entry.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. Halt paths that don't route design questions perpetuate the cycle of skipped tickets.
- **JTBD-006** (Progress the Backlog While I'm Away) — composes; AFK loops that halt with unanswered questions don't make progress on the next loop because the questions remain unanswered.
- 2026-04-26 session evidence: 7-iter AFK loop, 6 accumulated user-answerable skips, Step 6.5 CI-failure halt on commit `8653541` (test 645 idempotency local-vs-CI divergence), orchestrator emitted Outstanding Design Questions table at ALL_DONE; user correction "the end of the work-problems session didnt ask questions" triggered this ticket via run-retro post-loop AskUserQuestion. Same orchestrator turn applied the missed routing manually (the AskUserQuestion call that captured this ticket's options + recorded P123 / P082 / P069 design decisions).
