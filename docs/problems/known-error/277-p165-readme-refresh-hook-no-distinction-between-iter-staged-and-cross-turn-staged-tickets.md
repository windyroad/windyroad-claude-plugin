# Problem 277: P165 README-refresh hook doesn't distinguish iter-staged from cross-turn-staged tickets when AFK subprocess + orchestrator main turn share working tree

**Status**: Known Error
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

During session 8 iter 2 (P269), the orchestrator main turn captured P270 via `/wr-itil:capture-problem` while iter-2 P269 was running in background subprocess. P270 was auto-staged into iter-2's git working tree (the orchestrator + iter share the same tree). When iter-2's fold-fix commit ran, the P165 README-refresh hook detected P270 as a staged-ticket-without-README-refresh and BLOCKED the commit — even though P270 was not iter-2's work, but the orchestrator main turn's concurrent capture.

`git restore --staged` cleared the index to preserve iter-2's ADR-014 grain. But the underlying defect remains: P165 hook treats ALL staged ticket changes as "this commit's work" without distinguishing iter-grain from cross-turn-grain.

**Proposed fix shape**: P165 should either (a) filter the staged set to the commit-author's intended grain (e.g. read the commit message for ticket-ID hints and match staged tickets to that) OR (b) surface staged-but-not-author-intended files for explicit user-acknowledged dismissal.

## Symptoms

(deferred to investigation)

## Workaround

`git restore --staged` before iter-commit retry. Awkward — iter learns about the cross-turn-stage from P165 BLOCK message and acts reactively.

## Impact Assessment

- **Who is affected**: any AFK iter running concurrently with orchestrator-main-turn captures.
- **Frequency**: every concurrent capture → iter-commit cycle.
- **Severity**: (deferred to investigation) — initial: moderate.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — `packages/itil/hooks/lib/readme-refresh-detect.sh` treats every staged ticket as this commit's grain
- [ ] Design candidate (a): parse commit message for ticket-ID hints
- [ ] Design candidate (b): snapshot-diff against iter-start ref
- [ ] Create reproduction test

## Fix Strategy

**Kind**: create (new hook behaviour)
**Shape**: hook script edit
**Target file**: `packages/itil/hooks/lib/readme-refresh-detect.sh` (P165 helper) + canonical sync via existing pattern (analogous to P273+P274+P275 sibling sweep promoting `command_invokes_git_commit` to `packages/shared/hooks/lib/`)
**Observed flaw**: helper treats every staged ticket as the current commit's grain — no distinction between iter-staged (this commit's work) and cross-turn-staged (orchestrator main turn captured a ticket while iter was working in shared tree).
**Edit summary**: branch (a) — parse `$COMMIT_MSG_FILE` for ticket-ID hints (regex `P[0-9]+`) and filter staged ticket set to ID-matching subset before applying README-refresh discipline; OR branch (b) — snapshot-diff staged set against iter-start ref (requires iter-subprocess to publish start-ref via marker file similar to P119 runtime-sid). Architect should choose branch when fix is scheduled.
**Evidence (session 8)**:
- Iter-2 P269 fold-fix commit blocked by P165 hook because orchestrator main turn captured P270 concurrently (commit 04c15a6) into shared tree → P270's `.open.md` file appeared in iter-2's staged set → hook detected staged-ticket-without-README-refresh → BLOCK.
- Workaround was `git restore --staged docs/problems/open/270-*` before iter-2 retry — manual, reactive, learned from BLOCK message rather than designed for.
- This pattern recurs every concurrent-capture × iter-commit cycle in AFK orchestrator workflows — class-of-behaviour not one-off.

**Routing target**: when P277 is worked, `/wr-itil:manage-problem 277 known-error` → architect review on branch choice → implementation in `packages/itil/hooks/lib/readme-refresh-detect.sh` with behavioural bats covering both iter-staged and cross-turn-staged fixture cases.

## Dependencies

- **Composes with**: P165 (parent README-refresh hook), P268 (substring-match defect sibling), P119 (create-gate marker), ADR-014, ADR-032

## Related

(captured 2026-05-19 from /wr-itil:work-problems session 8 iter 2 (P269) deviation-approval queue, user-directed via AskUserQuestion at Step 2.5)

- P165 — parent README-refresh discipline hook
- P268 — sibling-defect substring-match fix
- P272-P275 — P165 sibling-hook cluster
- ADR-014, ADR-032 — grain contracts the cross-turn case violates
