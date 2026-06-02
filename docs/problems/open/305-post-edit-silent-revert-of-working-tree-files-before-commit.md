# Problem 305: Post-Edit silent revert of working-tree files before commit — potential silent-work-loss hazard

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Surfaced during the P258 AFK iter (2026-05-26). Edit-tool writes to several files (`docs/briefing/`, `docs/decisions/063`, `docs/problems/open/263`) returned **success**, but the edits were **reverted before commit** — a subsequent grep showed the written content gone (grep=0). Re-applying the edit + an **immediate `git add`** persisted it; the committed work was verified intact in the iter's commit. The same-iter edits to the primary ticket (258) survived without re-apply.

Cause unknown — candidates: an external formatter/watcher process rewriting files on save, a harness file-state race between the Edit tool's write and a subsequent read/commit, or an editor/LSP auto-format reverting. This is a **potential silent-work-loss hazard**: a write that reports success but doesn't persist could silently drop work if not caught by a post-write verification + immediate stage.

## Symptoms

(deferred to investigation)

- Edit tool reports success; subsequent grep of the target file shows the content absent.
- Re-apply + immediate `git add` persists; without the immediate stage the edit is lost.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Reproduce: identify whether an external formatter/watcher, editor auto-format, or a harness race causes the post-Edit revert.
- [ ] Consider a defensive post-Edit verification (grep-after-write + immediate git-add) contract for governance edits, OR identify + disable the reverting process.
- [ ] Assess blast radius: which file types/paths are affected (docs/ only, or source too?).

## Dependencies

- **Blocks**: (none — workaround is re-apply + immediate git-add)
- **Blocked by**: (none)
- **Composes with**: P258 (the iter that surfaced this).

## Related

(captured 2026-05-26 during the P283 prong-2 drain surfacing — user-directed "capture an investigation ticket")
- P258 — the AFK iter that observed the silent revert.
