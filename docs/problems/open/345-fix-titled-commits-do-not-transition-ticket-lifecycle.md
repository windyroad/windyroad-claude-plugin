# Problem 345: Fix-titled commits do not transition the ticket lifecycle in the same commit grain — ticket stays Open across release + CI-verify + multiple intervening commits

**Status**: Open
**Reported**: 2026-05-31
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Recurring class: when fix code lands in commits titled `fix(<pkg>): P<NNN> ...`, the named ticket's lifecycle (Open → Known Error or Known Error → Verifying) is NOT transitioned in the same commit grain. The ticket stays Open across the release that ships the fix, across CI verification, and across N intervening commits — until a later session manually closes the lifecycle gap.

P334 evidence (this iter's witness):
- `3945878` "fix(architect): P334 awk substr Unicode portability — ASCII '...' for cross-platform compendium" — landed the awk-portability code; ticket stayed Open.
- `3e53a94` "fix(architect): P334 follow-up — LC_ALL=C wrap for compendium generator" — landed the byte-locale wrap; ticket stayed Open.
- `e9f7ce4` "fix(architect): regenerate compendium with @windyroad/architect@0.12.2 (unblocks CI test 2145)" — shipped compendium regen as part of `@windyroad/architect@0.12.2` release; ticket stayed Open.
- CI workflow "CI" green on commit `bad2eac` (main, run `26701674556`) — cross-platform drift gate test 2145 passes on Linux GNU awk; ticket stayed Open.
- This iter (session-9 work-problems AFK iter 1) was needed to manually close P334 despite all fix-shipping + CI-verification evidence being available 1+ day prior.

Why this matters: the ADR-022 Known-Error → Verifying auto-detection at release time has nothing to act on because the Open → Known Error transition never fires for fix-titled commits. The ticket lifecycle is effectively orphaned by the fix-without-paired-transition pattern.

Sibling class: P228 (`docs/problems/known-error/228-adr-022-known-error-md-verifying-md-transition-not-happening-consistently-at-release-time.md`) covers the K→V seam — this ticket covers the O→KE seam upstream. The session 8 wrap dispositions (`docs/retros/2026-05-30-work-problems-wrap-dispositions.md`) names the belt-and-braces direction on P228: "consider whether run-retro Step 4a or transition-problem release-path should belt-and-braces the K→V transition". This O→KE class is the upstream extension — the belt-and-braces design should cover BOTH seams (or whichever shape ends up unified).

Composes with: P206 (open `docs/problems/known-error/206-work-problems-iter-workers-dont-add-changesets-fix-commits-accumulate-without-release.md`) sibling-class on the changeset axis; P234 (closed) umbrella class for "defer-with-rationalization"; P335 inverse class (over-claim completion in ITERATION_SUMMARY).

Fix-strategy candidates (deferred to investigation):
- (a) Post-fix-commit advisory hook that diffs `fix(<pkg>): P<NNN>` commit titles against the named ticket's Status — emit advisory when fix-titled commits land without paired lifecycle transition.
- (b) Extend P228's belt-and-braces design surface (run-retro Step 4a or transition-problem release-path) to scan for `fix-titled-with-PNNN + ticket-still-Open` pattern at release time.
- (c) manage-problem-style commit hook that requires a paired lifecycle transition for any `fix(<pkg>): P<NNN> ...` commit.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause
- [ ] Create reproduction test
- [ ] Reconcile scope with P228 belt-and-braces direction (sibling K→V seam); decide unified-vs-separate fix surface
- [ ] Confirm whether P234's `itil-fictional-defer-detect.sh` advisory hook should be extended to cover this O→KE seam or whether a sibling hook is correct

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P228 (sibling K→V surface), P206 (sibling changeset-discipline surface), P234 (closed; defer-with-rationalization umbrella)

## Related

- P334 (`docs/problems/closed/334-...`) — concrete witness of the pattern (this iter's evidence chain).
- P228 (`docs/problems/known-error/228-...`) — sibling K→V class; belt-and-braces direction in session-8 wrap dispositions.
- P206 (`docs/problems/known-error/206-...`) — sibling changeset-discipline class.
- P234 (`docs/problems/closed/234-...`) — umbrella defer-with-rationalization class.
- P335 (`docs/problems/open/335-...`) — inverse class: AFK iter over-claim in ITERATION_SUMMARY.
- ADR-014 single-commit grain.
- ADR-022 K→V at release time.
- `docs/retros/2026-05-30-work-problems-wrap-dispositions.md` — session 8 wrap, P228 belt-and-braces direction.
- Captured via /wr-itil:capture-problem on 2026-05-31 (work-problems AFK iter 1 retro).
