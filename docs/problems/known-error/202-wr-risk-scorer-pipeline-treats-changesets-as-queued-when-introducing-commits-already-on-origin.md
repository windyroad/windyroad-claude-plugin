# Problem 202: wr-risk-scorer:pipeline treats changesets as queued when introducing commits are already on origin

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

When the `wr-risk-scorer:pipeline` subagent scores Layer 1 (release risk), it reads `.changeset/*.md` files in the working tree and treats their descriptions as "pending consumer-facing changes". It does not verify whether the underlying commits that introduced each changeset have already been pushed to `origin/<base>`. This produces a false-high score in a common state: the maintainer pipeline (changesets-action) has already landed the feature commits to master, the changesets are on origin, and the working tree is waiting for the next release-PR merge to npm.

The error is asymmetric. False-high release risk routes downstream consumers (`/wr-itil:work-problems` Step 6.5 above-appetite branch, `/wr-itil:manage-problem` Step 12 release path, ADR-042 auto-apply remediation loop) into either halting the loop or surfacing phantom remediations (e.g. `move-to-holding` on changesets whose code has already shipped). None of these are correct when the underlying commits are already live.

## Symptoms

- Live example, 2026-05-02 AFK loop on a downstream repo. After iter 2 landed three docs-only commits, Step 6.5 invoked `wr-risk-scorer:pipeline`.
- First call assumed `.changeset/*.md` descriptions correspond to local-only work and computed release risk above appetite, triggering the above-appetite-remediation branch.
- Manual inspection revealed the changesets' introducing commits had been on origin since the prior release PR; the release-PR merge to npm was the only pending step.
- The auto-remediation loop's `move-to-holding` step would have moved live changesets into the holding area, fragmenting the release.

## Workaround

Manually inspect the changesets' git history before trusting the Layer 1 score. Use `git log --oneline -- .changeset/` cross-referenced against `git log origin/<base>..HEAD -- .changeset/` to distinguish queued from already-pushed changesets.

## Impact Assessment

- **Who is affected**: every maintainer running `wr-risk-scorer:pipeline` in a tree where some changesets are already on origin awaiting release-PR merge.
- **Frequency**: every Layer 1 score in the changesets-action holding pattern.
- **Severity**: High — false-high release-risk routes load-bearing automation (work-problems above-appetite, ADR-042 auto-apply) into incorrect branches.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Pipeline subagent: before counting a `.changeset/*.md` as "pending", check whether its containing commit is on `origin/<base>`. If on origin, treat it as already-released-pending-merge-PR (not pending-consumer-facing-change at THIS commit's surface).
- [ ] Architectural call: where does the "pending consumer-facing change" signal live? Likely needs to be `commits-introducing-changesets-that-are-NOT-on-origin`, not `changesets-in-working-tree`.
- [ ] Behavioural test: synthetic fixture with changesets on origin + working tree → assert Layer 1 score does NOT count them as queued.

## Dependencies

- **Blocks**: (none — but the false-high score blocks accurate work-problems Step 6.5 routing).
- **Blocked by**: (none)
- **Composes with**: P121 (parent? — same pipeline scoring logic), ADR-042 auto-apply, ADR-018 release-cadence, work-problems Step 6.5.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/121 (filed 2026-05-13 from a downstream project's adopter session).
- **Pipeline classification** (review-problems Step 4.5e): JTBD-alignment=aligned-with-existing-JTBD (JTBD-202 + JTBD-006 + JTBD-301); dual-axis-risk=safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
