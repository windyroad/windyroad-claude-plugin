# Problem 191: JTBD edit gate misfires "no JTBD documentation exists" branch on bats fixture edits despite `docs/jtbd/` being present in session CWD

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 6 (Med) — Impact: 3 (Moderate, friction blocks legitimate edits) x Likelihood: 2 (Possible — fires intermittently on specific path patterns) (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The JTBD edit gate (`~/.claude/plugins/cache/windyroad/wr-jtbd/0.7.3/hooks/jtbd-enforce-edit.sh`) blocked multiple Edit-tool calls during the 2026-05-15 P038 fix session with the exact error:

> BLOCKED: Cannot edit '<file>' because no JTBD documentation exists. Run /wr-jtbd:update-guide to generate JTBD docs for this project, then delegate to wr-jtbd:agent for review.

This is the `JTBD_PATH=""` empty-branch message from `jtbd-enforce-edit.sh` line 80-82. However `docs/jtbd/` WAS present in the session CWD `/Users/tomhoward/Projects/windyroad-claude-plugin` and contained content (verified inline via `ls docs/jtbd/`). The hook's `[ -d "docs/jtbd" ]` check must be evaluating relative to a runtime CWD that differs from the session's `$PWD` in some Edit-tool transport paths.

## Symptoms

- Edit-tool calls to `packages/risk-scorer/hooks/test/external-comms-gate.bats` blocked twice with the empty-JTBD-PATH branch despite `docs/jtbd/` being on disk.
- Edit-tool call to `packages/shared/test/sync-external-comms-gate.bats` blocked with the same branch.
- **Workaround that succeeded each time**: a Bash-tool python rewrite of the same file content. The Bash transport apparently does not pass through the JTBD edit gate the same way the Edit transport does (or the hook resolves CWD differently).
- **Recovery that succeeded**: invoke `wr-jtbd:agent` (succeeds, marker writes), THEN retry Edit — that retry sometimes succeeds, suggesting the hook resolves CWD correctly when fired in close temporal proximity to a successful marker write.

## Workaround

Two known workarounds:

1. **Bash-tool python rewrite** of the same file content — bypasses the Edit transport entirely. Fast but loses Edit's diff-aware safety.
2. **Marker refresh dance** — invoke `wr-jtbd:agent` to write a fresh marker, then immediately retry the blocked Edit. Slow but preserves Edit semantics. Brittle: subsequent Edit retries (without another marker refresh) may re-trip.

Both workarounds add friction to long fix-implementation sessions where many bats fixture edits are needed.

## Impact Assessment

- **Who is affected**: solo-developer (JTBD-001) during fix implementation sessions involving multiple bats fixture edits — the friction compounds linearly with the number of test fixtures touched.
- **Frequency**: observed at least 3 times in the 2026-05-15 P038 session; intermittent — not every bats Edit triggers it.
- **Severity**: Moderate — there is a workaround, but the workaround is non-obvious to a fresh agent and consumes user-facing turn time each retry.
- **Analytics**: deferred to investigation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Instrument `jtbd-enforce-edit.sh` to log `$PWD` and the result of `[ -d "docs/jtbd" ]` at fire time, comparing against the session CWD recorded in some session-scoped marker file.
- [ ] Identify which Edit-tool transport paths trigger the misfire vs. which paths see the correct CWD (e.g. is it an Edit-after-Read-of-different-file pattern? An Edit-from-a-subagent context? An Edit during a paused tool sequence?).
- [ ] Test fix: hard-code the hook to look at `${CLAUDE_PROJECT_DIR:-$PWD}` (or similar) and verify the misfire disappears.
- [ ] Add behavioural bats fixture reproducing the misfire (the hardest part — the misfire is intermittent).
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.

### Preliminary Hypothesis

The PreToolUse hook may inherit a different CWD than the session's `$PWD` in some Edit-tool transport contexts (e.g. when Claude Code's Edit transport is invoked via a path that doesn't honour CWD propagation). This would explain:

- Why the same content edit succeeds via Bash (Bash-tool transport always inherits $PWD from the session shell).
- Why immediate post-`wr-jtbd:agent` retries sometimes succeed (the agent's recent fork inherits $PWD; the marker file write resets some hook-context state that the next Edit picks up).
- Why the misfire is intermittent (transport-dependent).

The hook's `JTBD_PATH=""` empty-branch is intentional graceful-degradation for adopters who haven't run `/wr-jtbd:update-guide` — but the empty-branch should only fire when `docs/jtbd/` GENUINELY doesn't exist in the project. The current check is necessary-but-not-sufficient: it doesn't validate that the CWD it's checking from is the session's CWD.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P004 (gate path resolution; ancestor concern), P107 (TTL extension; same class of hook-stability work), P173 (BYPASS env vars don't propagate; same CWD-context / env-context family — hooks see different runtime context than the session expects)

## Related

- `~/.claude/plugins/cache/windyroad/wr-jtbd/0.7.3/hooks/jtbd-enforce-edit.sh` (line 80-82 — the empty-JTBD-PATH branch).
- P004 (`docs/problems/closed/004-edit-gates-block-non-project-files.md`) — earlier work on gate path resolution; ancestor.
- P107 (`docs/problems/closed/107-architect-jtbd-edit-gate-markers-expire-mid-batch.md`) — TTL stability; related hook-quirk class.
- P173 — BYPASS env vars don't propagate from Bash subshell to PreToolUse hook context; same CWD/env-context family.
- Captured by `/wr-retrospective:run-retro` Step 4b Stage 1 + user direction "don't defer the stage 1 ticketing" (2026-05-15).
