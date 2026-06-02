# Problem 326: Staged index is cleared after a `wr-risk-scorer:pipeline` Agent delegation — forces a re-`git add` before the commit lands

**Status**: Open
**Reported**: 2026-05-28
**Priority**: 3 (Medium) — Impact: 2 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The ADR-014 commit-gate flow is: `git add <paths>` → delegate to `wr-risk-scorer:pipeline` (Agent tool) to score + write the bypass/score marker → `git commit`. Observed repeatedly this session (2026-05-28): after the scorer delegation returns, the previously-staged paths are **no longer staged** — `git commit` reports `Changes not staged for commit` / `no changes added to commit`, and a second `git add <paths>` + `git commit` is required to land it.

Net effect: every commit that routes through the risk-scorer delegation pays an extra `git add` round-trip. Low-severity individually, but it fired on ~3-4 commits this session (the README reconcile, the P324 capture, and others), and it's silent — the commit *looks* like it should work after scoring, then fails on staging, which is easy to misread as a gate issue rather than an index-state issue.

## Symptoms

- `git add X` → delegate to `wr-risk-scorer:pipeline` → `git commit` → `Changes not staged for commit` (the staged set was emptied during the delegation).
- Re-running the identical `git add X` + `git commit` immediately succeeds (the score/bypass marker from the delegation is still valid), confirming the only thing lost was the staging, not the score.

### Recurrence — 2026-05-30 session (run-retro evidence)

Fired again 3+ times during the ADR-076 / ADR-077 session: Slice 1 ADR-077 commit `846b5f2`, README reconcile `1da2ef5`, Slice 2 ADR-077 commit `9832593`. Each required a re-`git add` after the RISK-POLICY-staleness gate denial cleared the index. Wrapper-helper fix-strategy (e.g. `wr-risk-scorer-commit` that encapsulates `git add` + delegate + re-add + `git commit`) would eliminate the round-trip; route via Step 4b Stage 2 Option 3.

## Workaround

Re-`git add` the exact paths immediately before `git commit`, after the scorer delegation returns. (This session applied it ~3-4×.)

## Impact Assessment

- **Who is affected**: anyone following the ADR-014 stage→score→commit flow (every governance commit that hits the risk gate); the AFK orchestrator pays it per iter commit.
- **Frequency**: every scorer-delegated commit. High this session.
- **Severity**: low (recoverable in one re-stage) but recurring + silent — wastes a round-trip and can be misdiagnosed as a gate failure.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority/Effort at next /wr-itil:review-problems.
- [ ] Determine the mechanism: does the `wr-risk-scorer:pipeline` agent run a `git` operation (e.g. `git reset`, `git stash`, a worktree inspect) that clears the index? OR does the PreToolUse commit-gate *deny* path reset staging? OR does the Agent-tool subprocess boundary not preserve the parent index? Reproduce: `git add` a file, delegate to the scorer, `git status` before any commit attempt — confirm whether staging is already cleared by the delegation alone (vs by a blocked commit attempt).
- [ ] If the scorer agent is clearing the index, fix it to be index-non-destructive (read-only assessment must not `git add`/`reset`/`stash` the user's staging). If it's the deny path, make the deny non-destructive. If it's the Agent-boundary, document the re-stage as a required step in the ADR-014 flow (and consider a wrapper).

## Dependencies

- **Composes with**: P192 (risk-pipeline gate forces repeat rescoring round-trips when the working tree changes between scorer and commit — sibling scorer-delegation friction; this is the *staging-cleared* facet, P192 is the *rescore* facet), P057 / P125 / P273 (git staging traps — different mechanism: those are `git mv`+Edit re-stage; this is scorer-delegation index-clear).

## Related

- captured via /wr-itil:capture-problem during the 2026-05-28 run-retro Step 2b pipeline-instability scan (category: subagent-delegation friction + repeat-work friction); observed ~3-4× this session on governance commits.
