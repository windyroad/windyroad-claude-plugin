# Problem 206: work-problems iter workers don't add changesets — fix commits accumulate without release

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The `/wr-itil:work-problems` AFK orchestrator dispatches iter subprocesses that complete fix commits but the dispatch prompt does NOT require those subprocesses to add a changeset alongside the fix commit. Result: AFK loops accumulate code changes without the npm-release path.

Reported from downstream consumer **bbstats** as P195: https://github.com/windyroad/bbstats/blob/main/docs/problems/195-afk-iter-workers-dont-add-changesets-no-release-path.open.md

## Workaround

Manually add changesets after AFK loops complete (defeats the AFK promise that release-cadence flows automatically per ADR-018).

## Impact Assessment

- **Who is affected**: every AFK loop on a project that publishes via changesets-action.
- **Frequency**: every code-fixing iter that should emit a changeset.
- **Severity**: High — load-bearing release-path is bypassed; JTBD-006 "drain push/release queues when unreleased risk would reach appetite" violated.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend `/wr-itil:work-problems` Step 5 iter dispatch prompt: require iter subprocesses to add a `.changeset/*.md` alongside any fix commit that touches `packages/*/{src,bin,hooks,skills,scripts,lib,agents}`. Doc-only commits and test-only commits don't need changesets.
- [ ] Add a post-iter validator in Step 6 that detects "fix commit landed without companion changeset" and routes to an iter-fix-up step OR halts the loop with a clear directive.
- [ ] Behavioural fixture: synthetic iter that lands a source-code fix; assert `.changeset/*.md` is present in the iter's commit.

## Dependencies

- **Composes with**: ADR-018 (release-cadence Step 6.5), ADR-042 (auto-apply), JTBD-006 (AFK), JTBD-007 (Keep Plugins Current — closure depends on fix shipping to npm).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/98 (bbstats P195).
- **Pipeline classification**: JTBD-aligned (JTBD-006 + JTBD-007); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
