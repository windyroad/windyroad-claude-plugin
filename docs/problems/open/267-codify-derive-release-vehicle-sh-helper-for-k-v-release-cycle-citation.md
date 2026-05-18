# Problem 267: Codify `derive-release-vehicle.sh` helper for K→V release-cycle citation

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 6 (Medium) — Impact: 2 × Likelihood: 3
**Effort**: M (re-estimated 2026-05-18 — script + bin shim + bats fixture + transition-problem integration)
**Type**: technical

## Description

When `/wr-itil:transition-problem` Step 7 transitions a Known Error or Open ticket to Verifying per ADR-022 P143 fold-fix amendment, the K→V release-vehicle citation (changeset filename → version-packages commit → merge PR → merge commit) is currently composed by hand from `git log` output. Hand-typed citations are fragile to cross-ticket wrong-cite errors when a session pre-applies transitions for multiple sibling tickets before working any of them.

Observed 2026-05-18 work-problems session 7 iter 1 retro (P250 K→V): the prior session pre-applied P250's K→V edits citing P247's release refs (`1ef3157` / PR #143) instead of P250's actual refs (`4a0e1b7` / PR #141). Iter 1 caught + corrected the cross-cite error. The class-of-behaviour is "K→V transitions composed from inline pre-flight evidence are fragile to wrong-release-cited errors propagating forward into V→Closed".

**Fix**: ship `packages/itil/scripts/derive-release-vehicle.sh` + `packages/itil/bin/wr-itil-derive-release-vehicle` (ADR-049 shim). The script:

1. Takes a ticket ID `P<NNN>` as input.
2. Reads the ticket file body for the changeset filename pattern (e.g. `.changeset/p<NNN>-*.md` or by description text match).
3. Runs `git log --diff-filter=D --follow -- <changeset-path>` to find the deletion commit (version-packages commit).
4. Resolves the merge PR via `gh pr list --search "<version-packages-commit-sha>"` or git log reverse-walk.
5. Resolves the merge commit via `git log --merges --first-parent` filtered to the PR's merge ref.
6. Emits a structured citation block: `source commit / version-packages commit / PR #N / merge commit` ready for inline insertion into the ticket's `**Fix Released**` field.

Invoked from `/wr-itil:transition-problem` Step 7 when transitioning to Verifying; resolves the release vehicle deterministically. Bats coverage for the helper. Sibling pattern to `wr-itil-reconcile-readme` / `wr-itil-classify-readme-drift` ADR-049 shims.

## Symptoms

(deferred to investigation)

## Workaround

Cross-reference every hand-typed release ref against `git log` output BEFORE writing K→V citations into ticket files. Iter 1 retro observation 1 names this pattern.

## Impact Assessment

- **Who is affected**: anyone running `/wr-itil:transition-problem` K→V or `/wr-itil:work-problems` AFK orchestrator with K→V transition iters.
- **Frequency**: 1-of-6 transitions this session (P250 iter-1 corrective) — empirical incidence rate ~16% pre-helper.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — confirm the changeset-filename-pattern → git-log → PR → merge-commit chain is deterministic across all package layouts
- [ ] Create reproduction test (bats fixture: ticket file → script → expected citation shape)
- [ ] Audit `/wr-itil:transition-problem` Step 7 surface for the integration point

## Dependencies

- **Blocks**: (none — manual citation works, just fragile)
- **Blocked by**: (none)
- **Composes with**: ADR-022 (Verifying lifecycle), ADR-049 (bin/ on PATH naming grammar), `/wr-itil:transition-problem`, `/wr-itil:transition-problems` (batch variant)

## Related

(captured at /wr-itil:work-problems session 7 Step 2.5 user-direction routing)

- P250 iter-1 retro Observation 1 — origin signal
- `/wr-itil:transition-problem` SKILL.md Step 7 — integration point
- `wr-itil-reconcile-readme` / `wr-itil-classify-readme-drift` — sibling ADR-049 shim precedent
