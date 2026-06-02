# Problem 307: work-problems Step 5 idle-timeout SIGTERM uses wall-clock not active/monotonic time — machine-sleep falsely kills a completing iter and loses its commit + metadata

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The Step 5 dispatch poll loop (P121 idle-timeout SIGTERM) computes `IDLE_SECONDS = NOW - LAST_ACTIVITY_MARK` where `LAST_ACTIVITY_MARK = max(DISPATCH_START_EPOCH, last-commit-epoch)`. This is **wall-clock** time. When the host machine suspends/sleeps between the 60s polls, wall-clock keeps advancing while the iter subprocess is itself suspended (doing no actual idle work). On resume, `IDLE_SECONDS` jumps past the threshold and SIGTERM fires on a subprocess that was genuinely making progress, not stuck.

Concrete evidence 2026-05-26: iter 1 working P177 — poll log idle jumped non-linearly `481s -> 1016s -> 5544s` (machine slept between polls), SIGTERM fired at `idle=5544s > 3600s` threshold, exit 143 + 0-byte JSON (the P147 stuck-before-emit metadata-loss class). The iter's P177 fix was actually complete and test-passing (36/36 bats green) but uncommitted; it was salvaged manually from the orchestrator main turn (commit `a8823be`). So the false-positive cost a full iter's commit + cost/usage metadata.

Candidate fix directions:
1. Track active/monotonic elapsed time and subtract suspended duration.
2. Detect large wall-clock jumps between consecutive polls (>> the 60s sleep interval) as suspend events and reset/advance the idle baseline rather than counting the gap as idle.
3. Have the iter subprocess write a heartbeat file the poll loop reads, instead of relying on commit-timestamp + wall-clock.

Surfaced 2026-05-26 during a `/wr-itil:work-problems` loop; retro never ran (SIGTERM before it) so this would otherwise have been lost.

## Symptoms

(deferred to investigation)

## Workaround

Manual salvage from the orchestrator main turn (verify work integrity from `git status` + bats, then commit the staged work through a fresh commit gate per the P261/P147 recovery path). Raising `WORK_PROBLEMS_IDLE_TIMEOUT_S` reduces but does not eliminate the false-positive (a long enough suspend still trips any wall-clock threshold).

## Impact Assessment

- **Who is affected**: maintainers running `/wr-itil:work-problems` AFK loops on laptops that suspend (lid-close, power-save) mid-loop.
- **Frequency**: (deferred to investigation)
- **Severity**: loss of a completing iter's commit + cost/usage metadata; requires manual salvage. Bounded (work survives in the tree) but defeats the AFK "progress while I'm away" job when the machine sleeps.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — confirm the wall-clock vs active/monotonic distinction in the Step 5 poll loop; reproduce with a simulated suspend (advance the clock past threshold without subprocess activity)
- [ ] Evaluate the three candidate fix directions (monotonic/active-time, jump-detect-as-suspend, subprocess heartbeat); pick one
- [ ] Create reproduction test (behavioural bats per ADR-052; extend `test/work-problems-step-5-idle-timeout-sigterm.bats`)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P121 (idle-timeout SIGTERM mechanism this defect lives in)

## Related

- **P121** — idle-timeout SIGTERM mechanism (the wall-clock `LAST_ACTIVITY_MARK` formula this ticket faults).
- **P147** — stuck-before-emit metadata-loss subclass (exit 143 + 0-byte JSON); the observed failure shape here, but the *trigger* differs (machine-sleep false-positive, not a genuine stuck subprocess).
- **P146 / P232** — polling antipatterns (sibling poll-loop hazards).
- Captured via /wr-itil:capture-problem; expand at next investigation.
