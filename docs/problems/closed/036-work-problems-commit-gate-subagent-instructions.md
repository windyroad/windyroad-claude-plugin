# Problem 036: work-problems orchestrator does not verify commit-landing between iterations

**Status**: Closed
**Reported**: 2026-04-17
**Updated**: 2026-04-17 (rescoped after P035 fix); 2026-04-19 (fix released)
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S
**WSJF**: 4.0 — (4 × 1.0) / 1

## Fix Released

Fix shipped in AFK iter 4 (2026-04-19, pending commit). Added Step 6.75 "Inter-iteration verification (P036)" to `packages/itil/skills/work-problems/SKILL.md`: after the release-cadence step and before the loop, the orchestrator runs `git status --porcelain` and classifies the result as clean (proceed), dirty-for-known-reason (carry forward in next iteration context), or dirty-for-unknown-reason (halt the loop with divergence report). Non-interactive default recorded in the decision table. Recovery attempt is explicitly out of scope per ADR-013 Rule 6 — the check surfaces the bug, the user decides. Added 6-test doc-lint bats file `packages/itil/skills/work-problems/test/work-problems-inter-iteration-verify.bats`. Released via `@windyroad/itil` patch bump. Awaiting user verification — next AFK loop that lands a subagent-internal commit failure should halt with a structured divergence report instead of silently continuing.

## Description

The `wr-itil:work-problems` AFK orchestrator spawns a subagent per iteration to run `manage-problem work`. Between iterations, the orchestrator does not verify that the previous subagent's committed state matches its reported outcome — if a commit silently fails, the next iteration spawns a fresh subagent that has no knowledge of the prior uncommitted work.

### Original scope and what changed

This ticket originally covered two sub-concerns:

**(a) Subagents don't receive fallback instructions when the primary commit-gate delegation fails** — **resolved** by P035's fix (commit `19ad307`, 2026-04-17). The `manage-problem` SKILL.md now documents a two-path commit gate: primary via `wr-risk-scorer:pipeline` subagent-type, fallback via `/wr-risk-scorer:assess-release` skill. Spawned subagents reading the updated skill will follow the fallback automatically.

**(b) Orchestrator has no inter-iteration verification** — **still open, now the sole scope of this ticket**. Even with P035's fallback documented, a subagent could still fail to commit for reasons the fallback doesn't cover (e.g., `/wr-risk-scorer:assess-release` itself internally delegates to `wr-risk-scorer:pipeline` and could fail at the same boundary; a git conflict in the subagent; a malformed commit message). Defence-in-depth: the orchestrator should verify via `git status` after each iteration that the working tree is clean (or deliberately staged for a known reason) before spawning the next one.

### Why Low priority after P035

P035's fix closes the most-likely failure path. Inter-iteration verification remains valuable as defence-in-depth but is no longer on the critical path for AFK usability. Downgrade reflects reduced blast radius while keeping the ticket visible.

## Symptoms

- Over multiple AFK iterations, staged changes accumulate undetected
- Final summary reports commits that didn't land, producing a stale audit trail
- On user return, a large unstructured diff is present with no per-iteration grouping

## Workaround

Run AFK loops for bounded durations (1-3 iterations) and `git status` on return before continuing. With P035's fix in place, this is mostly a precaution rather than a necessity.

## Impact Assessment

- **Who is affected**: Solo developers using `wr-itil:work-problems` for extended AFK backlog progression (JTBD-006)
- **Frequency**: Only on the residual failure surface not covered by P035's fallback — rare
- **Severity**: Minor — audit trail corruption is uncomfortable but recoverable; no data loss
- **Analytics**: N/A

## Root Cause Analysis

Orchestrator skills generally assume the delegated skill's reported outcome matches reality. The `wr-itil:work-problems` skill reads subagent completion reports as truth without independently verifying the git state. Any lie or silent failure in the subagent's report propagates into the orchestrator's summary.

### Investigation Tasks

- [ ] Design the inter-iteration check: after each subagent returns, run `git status --porcelain` and compare against an expected-clean baseline; if dirty, either (a) attempt recovery via `/wr-risk-scorer:assess-release` at the orchestrator level, (b) halt the loop with a structured "uncommitted state detected" signal, or (c) include the dirty state in the next iteration's subagent context
- [ ] Decide the recovery policy for each dirty-state cause (staged-not-committed, merge conflict, untracked governance artefact) — these have different correct responses
- [ ] Verify empirically that P035's fallback completes under real subagent conditions before deciding how aggressive this verification layer needs to be (if P035's fix fully works, this ticket can be Closed as obviated)
- [ ] Create a reproduction test that spawns a subagent which intentionally leaves dirty state, asserts the orchestrator catches it

## Related

- [JTBD-006](../jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md) — AFK backlog progression
- [P035](035-manage-problem-commit-gate-no-subagent-delegation-fallback.known-error.md) — upstream fix (commit `19ad307`); this ticket now defends against P035's fallback itself failing
- [packages/itil/skills/work-problems/SKILL.md](../../packages/itil/skills/work-problems/SKILL.md) — the orchestrator skill this problem lives in
- [ADR-014](../decisions/014-governance-skills-commit-their-own-work.proposed.md) — commit obligation
- [ADR-015](../decisions/015-on-demand-assessment-skills.proposed.md) — `/wr-risk-scorer:assess-release` semantics that P035 relies on
