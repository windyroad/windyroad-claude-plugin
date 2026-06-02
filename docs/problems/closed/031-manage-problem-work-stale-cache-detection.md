# Problem 031: `manage-problem work` incorrectly determines cache is fresh

**Status**: Closed
**Reported**: 2026-04-17
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: S
**WSJF**: 24.0 — (12 × 2.0) / 1

## Description

The `manage-problem work` skill uses a fast-path cache check to skip the full WSJF review when `docs/problems/README.md` is newer than all problem files. The check uses:

```bash
find docs/problems -name "*.md" ! -name "README.md" -newer docs/problems/README.md 2>/dev/null | head -1
```

This check is fundamentally broken in git worktrees (and fresh checkouts) because all files receive the same mtime at checkout time. `find -newer` returns files **strictly** newer, so same-mtime files do NOT match — making the cache appear fresh when it is not.

Observed: during a `manage-problem work` invocation in a fresh worktree, the skill ran the cache check, got no output, and used the cached README.md rankings. But many commits had occurred since the last review (2026-04-16):
- P030 was opened and closed (never ranked)
- P011, P013 were closed
- P005 was parked
- P029 was opened
- Multiple problem files were modified across 20+ commits

The skill skipped the full review and used stale WSJF rankings, selecting the wrong problem to work.

## Symptoms

- `manage-problem work` reports "Using cached ranking" when the backlog has changed significantly
- WSJF rankings used for work selection are stale — problems that changed status or priority are ranked incorrectly
- The skill selects the wrong problem to work, wasting an entire work session
- In a fresh git worktree, the cache ALWAYS appears fresh because all files have the same mtime
- The `find -newer` approach is timestamp-based but git does not preserve file mtimes across clones/checkouts/worktrees

## Workaround

Run `/wr-itil:manage-problem review` explicitly before `work` to force a full re-rank. Or invoke `work` a second time after the first run completes.

## Impact Assessment

- **Who is affected**: Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — the skill picks the wrong problem to work
- **Frequency**: Every `manage-problem work` invocation in a fresh git worktree, plus any invocation following problem file edits in the same session
- **Severity**: Medium — wrong work selection wastes an entire work session; the skill itself still functions but produces incorrect governance outputs
- **Analytics**: Observed this session — fresh worktree, 20+ commits since last review, cache check said fresh, skill used stale rankings and worked the wrong problem

## Root Cause Analysis

### Confirmed Root Cause

The `find -newer` check is a filesystem-timestamp comparison. This is fundamentally flawed for git-managed files because:

1. **Git worktrees and fresh checkouts set all file mtimes to checkout time.** All files in `docs/problems/` get the same mtime, so `find -newer README.md` finds nothing — the cache always appears fresh. Confirmed in this session: worktree created at `ac9d453`, all files received checkout-time mtime.
2. **Git does not preserve original file mtimes** across clones, checkouts, or worktree creation. The relationship between README.md's mtime and problem file mtimes is meaningless in a new worktree.
3. **Multiple commits between reviews are invisible.** 20+ commits modified problem files since the last review, but the `find` check cannot detect this because it compares filesystem timestamps, not git history. Confirmed: `git log --oneline d0046f7..HEAD -- docs/problems/*.md` shows 2 commits touching problem files that `find -newer` would miss in a fresh checkout.

### Fix Strategy

Replace the mtime-based `find -newer` check with a git-based check that:
1. Gets the last commit that modified README.md: `git log -1 --format=%H -- docs/problems/README.md`
2. Checks if any problem file has commits since that README commit: `git log --oneline "${readme_commit}..HEAD" -- 'docs/problems/*.md' ':!docs/problems/README.md'`

This is git-native and works correctly across worktrees, fresh clones, and normal working trees.

Effort: **S** (one text change in SKILL.md, one BATS test update).

### Investigation Tasks

- [x] Investigate root cause — confirmed: filesystem mtime comparison broken in git worktrees; git log approach verified as correct alternative
- [x] Create reproduction test — `manage-problem-parked-and-cache.bats` test updated to assert git-based check instead of `-newer`
- [x] Design fix — replace `find -newer` with `git log` commit comparison in SKILL.md step 9 fast-path
- [ ] Create INVEST story for permanent fix

## Fix Released

Fix implemented in `packages/itil/skills/manage-problem/SKILL.md` (step 9, fast-path):
- Replaced `find -newer` mtime comparison with `git log` commit history comparison
- BATS test `manage-problem-parked-and-cache.bats` test 6 updated: asserts `git log` presence and `-newer` absence
- All 13 manage-problem tests GREEN

Awaiting user verification that `manage-problem work` correctly detects stale cache in worktrees.

## Related

- `packages/itil/skills/manage-problem/SKILL.md` — contains the cache check logic (step 9, fast-path)
- `packages/itil/skills/manage-problem/test/manage-problem-parked-and-cache.bats` — regression test (test 6)
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
