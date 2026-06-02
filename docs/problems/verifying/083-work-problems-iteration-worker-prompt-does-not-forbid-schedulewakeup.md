# Problem 083: work-problems Step 5 iteration-worker prompt does not forbid ScheduleWakeup / time-deferring primitives — subagent can abandon synchronous-completion contract

**Status**: Verification Pending
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: S — single-file edit to `packages/itil/skills/work-problems/SKILL.md` Step 5 prompt template: add an explicit "Do NOT call `ScheduleWakeup`, `CronCreate`, or any tool that defers completion past the current turn — the iteration worker is synchronous; it must either complete the work and return `ITERATION_SUMMARY`, OR return a well-formed `action: skipped` summary" constraint. Plus a bats assertion (behavioural per P081 direction) that greps the Step 5 prompt for the forbidding language. Small + bounded + clear edit — S.

**WSJF**: 6.0 — (12 × 1.0) / 2 — High severity (silent abandonment of in-flight work is the exact-class failure P077 was meant to bound via isolation, but P077 didn't cover the worker's *contract surface* — only the delegation mechanism). Actual effort S; WSJF 12.0 in strict arithmetic, but ranked against the current 6.0 tier (P070 / P071 / P078 / P079 / P080 / P082) as a peer because the fix is narrow and the severity bucket matches.

## Description

`/wr-itil:work-problems` Step 5 (shipped in `@windyroad/itil@0.10.1` as the P077 fix) delegates each AFK iteration to a `general-purpose` subagent via the Agent tool. The iteration worker is **synchronous**: Step 5 says "The orchestrator awaits the subagent's final message before deciding whether to drain the release queue (Step 6.5), run the inter-iteration verification (Step 6.75), and spawn the next iteration." The worker's contract is "complete the work + return `ITERATION_SUMMARY`, OR return `action: skipped` with a reason".

Observed 2026-04-21 AFK iter 5 (this session, post-P077-release):

- Iteration worker spent ~8.5 minutes / 41 tool calls writing `packages/itil/skills/transition-problem/SKILL.md` + `test/transition-problem-contract.bats` + `test/manage-problem-transition-forwarder.bats` + edit to `manage-problem/SKILL.md` — all sound (19/19 bats pass post-hoc).
- Instead of committing and returning `ITERATION_SUMMARY`, the worker called `ScheduleWakeup` (or equivalent time-deferring primitive) — evidence: a `.claude/scheduled_tasks.lock` artefact appeared with `{"sessionId":"...","pid":71010,"acquiredAt":...}`.
- The worker's final message was literally "Still running — let me wait for the scheduled wake-up." — no `ITERATION_SUMMARY` block.
- Step 6.75's `git status --porcelain` check classified the state as dirty-for-unknown-reason (no documented hand-off) and halted the AFK loop per P036.

**The work was shippable** — reviewed post-hoc, tests pass, architect + JTBD gate hooks had fired during the original Write/Edit per ADR-032. The halt was cosmetic: the subagent misbehaved on its return contract, not on the artefact quality.

**This is a contract gap, not a quality bug.** P077 fixed the delegation mechanism (Agent-tool via `subagent_type: general-purpose`, structured `ITERATION_SUMMARY` return contract). P077 did NOT enumerate forbidden primitives in the worker's prompt. `general-purpose` subagents have `Tools: *` — including `ScheduleWakeup` + `CronCreate` + anything else that moves control off the current turn. Nothing in the Step 5 prompt says "don't use those".

The worker's reasoning (reconstructed from the return message) seems to have been: "task is large; I'll scheduled a wake-up and continue later." That reasoning is valid for standalone agents but violates the iteration worker's synchronous-handoff contract. The orchestrator is waiting on a summary that will never come; the scheduled wake-up fires into a DIFFERENT turn (potentially after the session closes); the work sits uncommitted.

## Symptoms

- AFK iteration worker writes files successfully, passes tests, but returns without `ITERATION_SUMMARY` and with a `.claude/scheduled_tasks.lock` artefact present.
- `git status --porcelain` shows uncommitted artefacts (modified SKILL.md + new test files) that the worker wrote but never staged.
- Step 6.75 halts the loop with "Dirty for unknown reason" — correctly catching the contract violation, but requires manual halt-recovery.
- Halt recovery: user (or next session) must inspect the work, decide commit-vs-discard, and manually ship. This is exactly the "AFK loop ends short" failure mode P077 was designed to fix — now re-emerging at a different layer.
- The scheduled wake-up, if it fires, arrives in a future turn with no context of the work-problems loop state — effectively a ghost invocation.

## Workaround

Current: user inspects the halt-state files, verifies soundness (run the tests, diff the staged set), commits manually per the shipped pattern, removes the stale `.claude/scheduled_tasks.lock`. Observed this session: ~10 minutes of inspection + commit + changeset authoring to recover iter 5's work; the recovery ran in an interactive turn and consumed context.

Architectural workaround (until P083 ships): add a "do not call ScheduleWakeup" reminder to every iteration-worker prompt at the orchestrator level (requires editing `packages/itil/skills/work-problems/SKILL.md` Step 5 prompt template — which is what this ticket's fix IS).

## Impact Assessment

- **Who is affected**:
  - **AFK persona** (`JTBD-006` — progress the backlog while I'm away) — every AFK loop where a worker hits a ScheduleWakeup-worthy mental trigger fails silently. Same-shape failure as pre-P077: the loop ends short, user finds uncommitted work on return. P077 fixed ONE mechanism for ALL_DONE-without-stop-condition; this fixes a sibling mechanism.
  - **solo-developer persona** (`JTBD-001` — enforce governance without slowing down) — halt-recovery is manual and context-expensive. The "governance without slowing down" promise breaks at recovery time.
  - **tech-lead persona** (`JTBD-201` — audit trail) — halt reports show `git status --porcelain` output but not *why* the subagent misbehaved. Audit trail records "halted" without the ScheduleWakeup diagnosis unless the user notices the lock file.
  - **plugin-developer persona** (`JTBD-101` — patterns propagate downstream) — downstream plugin authors copying the P077 iteration-isolation pattern inherit the same gap. The pattern mis-teaches worker-contract-surface boundaries.
- **Frequency**: observed once this session (iter 5). Likelihood scales with worker-task-size × worker-fatigue × worker-autonomy. With the fix not yet shipped, expect recurrence on any iteration whose scope feels "too big for one turn" to the worker.
- **Severity**: High. Silent failure mode on the orchestrator's synchronous-handoff invariant; only caught by P036's Step 6.75 halt, which is a safety net, not a primary defence.
- **Analytics**: N/A today. Post-fix candidate: count of `.claude/scheduled_tasks.lock` artefacts observed post-iteration across sessions (target: 0).

## Root Cause Analysis

### Structural

`packages/itil/skills/work-problems/SKILL.md` Step 5 prompt template says:

> **Constraints**: commit the completed work per ADR-014. Do NOT push, do NOT run `push:watch`, do NOT run `release:watch` — the orchestrator's Step 6.5 owns release cadence. Do NOT invoke `capture-*` background skills (AFK carve-out — ADR-032). Non-interactive defaults apply per ADR-013 Rule 6.

Three forbidden primitives: `push`, `push:watch`, `release:watch`, plus the background-capture carve-out. Missing: `ScheduleWakeup`, `CronCreate`, any `mcp__*__schedule_*`, any tool that defers completion to a future turn.

`packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` asserts structural constraints on the Step 5 prompt but does NOT test for the time-deferring-primitive forbidding. (Those tests are themselves structural-grep and scheduled for retrofit per P081 — this ticket's bats assertion should be behavioural from the start per P081 direction, once that infrastructure lands.)

The `general-purpose` subagent's tool set is `Tools: *` — all tools, including time-deferring ones. The P077 decision to use `general-purpose` (Option B in P077's ticket body) was made specifically BECAUSE the iteration worker needs broad tool access for its sub-delegations (architect / jtbd / style-guide / risk-scorer reviews). Restricting the subagent's tool set to exclude `ScheduleWakeup` is possible (the Agent tool accepts tool-restriction parameters), but that would require typed-subagent Option A (rejected in P077). So the fix is PROMPT-level: tell the worker explicitly what not to do.

### Why P077 didn't cover this

P077 was about the **delegation mechanism** (Agent-tool vs Skill-tool, subagent_type selection, return-summary contract shape). The worker's internal behaviour (what the worker chooses to DO with its tool set) wasn't scoped. The implicit assumption was "the worker is a general-purpose subagent; it knows how to behave synchronously". This session proves the assumption is too weak — LLM-driven general-purpose workers can reach for time-deferring primitives without realising the synchronous-handoff invariant.

### Candidate fix

**Option A: Amend Step 5 prompt to enumerate forbidden primitives** (lean).

Add to the Constraints block:

> Do NOT call `ScheduleWakeup`, `CronCreate`, `mcp__*__schedule_*`, or any primitive that defers completion past the current turn. The iteration worker is synchronous: return either a well-formed `ITERATION_SUMMARY` block (work completed + committed) OR an `action: skipped` summary with a reason. Abandoning mid-work via a scheduled wake-up violates the orchestrator's inter-iteration-verification contract (Step 6.75).

Plus a behavioural bats assertion (per P081 direction) that simulates a worker invocation with a large task and asserts the worker does not call the forbidden primitives. If P081's harness is not yet shipped, fall back to a structural assertion with a clearly-labelled limitation note.

Pros: single-file change; matches existing Constraints pattern; cheap to ship. Cons: relies on LLM discipline — a worker could still ignore the prompt. Mitigation: combine with a post-hoc check (Step 6.75 already halts on dirty state — the halt IS the enforcement).

**Option B: Restrict the subagent's tool set via Agent-tool parameters.**

If the Agent tool supports `forbidden_tools` (or equivalent), pass it alongside `subagent_type`. The worker physically cannot call `ScheduleWakeup`.

Pros: hard enforcement, not prompt-reliant. Cons: requires Claude Code feature (may not exist); couples the fix to a specific platform capability.

**Option C: Swap `general-purpose` for a typed iteration-worker subagent with restricted tools.**

Option A rejected in P077 itself. Revisit only if A + B prove insufficient.

### Lean direction

**Option A — amend Step 5 prompt + add behavioural bats.** Ship as a `@windyroad/itil` patch bump. Small, clear, landable in one commit.

If Option B (tool restriction via Agent-tool parameters) is available in Claude Code, add it alongside Option A as defence-in-depth. Architect review at implementation time decides the B layering.

### Related sub-concerns

**Sub-concern 1**: the same forbidding should apply to OTHER orchestrator workers — `run-retro` doesn't have iteration workers today, but `work-problems` is the template other AFK patterns follow. When a future skill adopts the same pattern, the forbidding clause must travel with the pattern. Consider promoting the prompt snippet to an ADR-032 amendment ("AFK iteration-worker prompt canonical constraints") so future pattern adopters inherit it.

**Sub-concern 2**: `.claude/scheduled_tasks.lock` cleanup. If an iteration worker DOES call ScheduleWakeup (prompt violation) and the halt fires, the stale lock sits in the working tree. Post-session cleanup should remove it, OR the lock file should be `.gitignore`d so it doesn't appear in `git status --porcelain` noise. Architect review decides whether this belongs in ADR-030 (repo-local artefacts) or in a simpler .gitignore update.

**Sub-concern 3**: the lock file also signals the scheduled wake-up may still fire after the session closes. Architect review decides whether the halt-recovery step should cancel any pending scheduled tasks (if that's exposed) or document the ghost-invocation risk.

**Sub-concern 4**: error message quality. When Step 6.75 halts, the current message names "dirty-for-unknown-reason". If the lock file is present, the halt message could additionally say "lock file detected — iteration worker may have called ScheduleWakeup". Small diagnostic improvement; architect decides if in-scope for this ticket or sibling.

### Investigation Tasks

- [ ] Architect review: Option A only, or Option A + B? ADR-032 amendment needed?
- [ ] Draft the Step 5 prompt amendment (forbidding clause + rationale).
- [ ] Behavioural bats assertion per P081 direction (fall back to structural with note if P081 harness not shipped).
- [ ] Explore Agent-tool parameters for forbidden-tools / tool-restriction (Option B feasibility).
- [ ] `.claude/scheduled_tasks.lock` — add to .gitignore? Clean up in halt-recovery? Architect decides.
- [ ] Step 6.75 error message: detect lock file presence, surface diagnostic. In-scope or sibling ticket?
- [ ] Cross-pollinate: if the forbidding clause promotes to ADR-032, update the AFK iteration-isolation wrapper sub-pattern (added 2026-04-21) to cite it.
- [ ] Update `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` with the new assertion (retrofit to behavioural when P081 ships).
- [ ] End-to-end test: run an AFK iteration with a task intentionally-large-enough to trigger worker fatigue; confirm the worker completes synchronously or skips explicitly.

## Related

- **P036** (`docs/problems/036-work-problems-commit-gate-subagent-instructions.verifying.md`) — Step 6.75 inter-iteration verification; the safety net that caught this gap. P036 does its job (halts the loop); P083 closes the primary defence upstream.
- **P077** (`docs/problems/077-work-problems-step-5-does-not-delegate-to-subagent.verifying.md`) — sibling ticket. P077 fixed the delegation mechanism; P083 fixes the worker's contract surface. Both are layers of the same synchronous-handoff contract.
- **P081** (`docs/problems/081-structural-content-tests-are-wasteful-tdd-agent-should-require-behavioural.open.md`) — bats assertion direction (behavioural > structural). P083's new assertion should follow P081 direction.
- **P082** (`docs/problems/082-no-voice-tone-or-risk-gate-on-commit-messages.open.md`) — commit messages lack voice/risk gate; P083 fixes the iteration worker's contract, including its commit-message authoring.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — AFK iteration-isolation wrapper sub-pattern added 2026-04-21 per P077; candidate for amendment to include canonical forbidding clause.
- **ADR-013 Rule 6** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — non-interactive fail-safe; the iteration worker's contract surface intersects Rule 6's "if you can't ask, pick a safe default" pattern.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — the iteration worker commits its own work; this ticket's fix preserves that.
- **ADR-018** / **ADR-019** — release cadence + preflight; untouched.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — target of the prompt amendment.
- `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` — target of the new assertion.
- `.claude/scheduled_tasks.lock` — artefact that signals the bug; cleanup / gitignore candidate.
- **JTBD-001**, **JTBD-006**, **JTBD-101**, **JTBD-201** — personas this fix serves, mirror-for-mirror with P077's ticket body.

## Fix Released

Deployed in `@windyroad/itil@0.13.0` via commit `260768f` (`fix(itil): P084 — work-problems Step 5 dispatches via claude -p subprocess`). The SKILL.md Step 5 prompt template's Constraints block at line 152 now carries the clause:

> Do NOT use `ScheduleWakeup` under any circumstance (P083 — iteration workers must not self-reschedule).

The forbidding clause landed alongside the P084 subprocess-dispatch rewrite because both changes target the same Step 5 prompt template and the P084 commit was the nearest open-path vehicle. The release provenance appears in `packages/itil/CHANGELOG.md` line 262 (0.13.0 entry — the Minor Changes bullet lists 260768f). Subsequent patch releases have carried the clause untouched.

Regression guard added in the same commit that transitions this ticket: `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` now contains two bats contract assertions — one for the forbidding clause's presence and one for the inline P083 citation — so removal of the clause in any future edit fails CI. STRUCTURAL doc-lint pattern per ADR-037's Permitted Exception (same rationale as the file's other 22 assertions on the Step 5 prompt template).

Awaiting user verification. Verification procedure: run an AFK `/wr-itil:work-problems` loop with at least one gate-covered iteration, confirm no `.claude/scheduled_tasks.lock` artefact appears and each iteration returns a well-formed `ITERATION_SUMMARY`. Additionally confirm `bats packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` passes the two new assertions (tests 23 and 24).

**Sub-concerns deferred to follow-up tickets** (not blocking verification):

- `.claude/scheduled_tasks.lock` `.gitignore` / cleanup handling — open as a sibling ticket if the concern re-surfaces.
- Step 6.75 halt-message diagnostic for lock-file presence — open as a sibling ticket if the concern re-surfaces.
- ADR-032 amendment to promote the forbidding clause to a canonical "AFK iteration-worker prompt constraint" so downstream pattern adopters inherit it — open as a sibling ticket when the next plugin adopts the iteration-isolation pattern.

These three items were listed in the Investigation Tasks at ticket creation; the primary defence (the prompt clause + regression guard) is sufficient to close the main concern. The sub-concerns can be opened independently without re-opening this ticket.
