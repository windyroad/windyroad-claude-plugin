# Problem 165: P094 README-refresh enforcement gap — iter subprocess commits can land a `.verifying.md` rename without staging the corresponding Verification Queue row in `docs/problems/README.md`

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

**WSJF**: (9 × 1.0) / 2 = **4.5**
**Type**: technical

> Captured 2026-05-04 by `/wr-itil:work-problems` AFK loop iter 7 surfacing pass per user direction "capture all four now". Sibling finding from iter 4 P157 commit.

## Description

Per `manage-problem` SKILL.md Step 5 P094 + Step 7 P062, every ticket creation, ranking-bearing update, and status transition MUST stage the refreshed `docs/problems/README.md` in the same commit as the ticket change (ADR-014 single-commit grain). The contract is well-documented; bats fixtures cover the happy path.

Observed iter 4 P157: iter 3's commit `d28bd51` (P156 capture-adr) shipped without the P094 README refresh — the P156 row was missing from the WSJF Rankings table → Verification Queue. Iter 4 backfilled inline (extra P094 work added on top of P157's own scope) to recover the audit trail.

This is an **enforcement gap**: the manage-problem skill's contract says "MUST stage README", but iter subprocesses can ship a commit without it and nothing observable rejects the commit. The git log carries the violation forward; only the next iter (or a `/wr-itil:reconcile-readme` invocation) detects it.

## Symptoms

- Iter 3 commit `d28bd51` (P156 capture-adr) — staged the rename to `.verifying.md` and the ticket-body update, but not `docs/problems/README.md` refresh.
- Iter 4 P157 commit had to backfill the P156 VQ row to recover.
- General class: any iter subprocess can violate the contract; only the orchestrator's Step 0 P118 reconcile-check (or the next ticket-creator's Step 0) catches it.

## Workaround

Inline backfill on next iter (iter 4 did this for iter 3's gap). Cost: ~1-2 extra agent turns per backfill + the unused iter context that the violation cost.

## Impact Assessment

- **Who is affected**: Every iter subprocess that creates / updates / transitions a ticket. AFK loops accumulate violations across iters until the next reconcile.
- **Frequency**: Per-iter risk; observed once this AFK loop (iter 3 → iter 4 backfill).
- **Severity**: Moderate — README staleness misleads next reader (orchestrator's Step 1 backlog scan, user manual review). Recoverable; not catastrophic.
- **Likelihood**: Likely — observed once across this loop's 6 iters; iter dispatch shape (`claude -p` subprocess with isolated context) means each iter independently follows the contract; one slip-up per loop is plausible.

## Root Cause Analysis

The current manage-problem SKILL.md Step 5 P094 / Step 7 P062 contracts are declarative ("MUST stage README"). No structural enforcement detects the violation.

Possible enforcement shapes:

1. **PostCommit hook** scanning the just-landed commit's diff for a ticket file rename / Status edit without a corresponding `docs/problems/README.md` change. Emits a deny-style message after-the-fact (commit already landed; needs re-do).

2. **PreToolUse:Bash hook** on `git commit` that grep's the staged set for ticket file changes without README change. Halts the commit. Lower-friction for forward-fixing; same shape as P125 staging-trap detector + P141 changeset-discipline.

3. **manage-problem Step 5 hard-fail** — after writing the new file, the skill itself validates the README contains the new ticket's row before allowing the commit. Internal to the skill; doesn't help if the skill is bypassed.

4. **Step 7 hard-fail** — same as #3 for transitions. The skill validates `grep -q "<ticket-id>" docs/problems/README.md` matches the new state suffix before allowing the commit.

Option 2 (PreToolUse hook) is the strongest enforcement and matches the existing pattern (P125, P141). Option 4 (skill-internal hard-fail) is cheaper to implement but only catches good-faith errors.

### Investigation Tasks

- [ ] Confirm scope: only manage-problem Step 5 / Step 7 paths affected, or also transition-problem / transition-problems / capture-problem / review-problems?
- [ ] Decide enforcement shape — Option 1 / 2 / 3 / 4 above. Architect review.
- [ ] Implement chosen shape + behavioural bats per ADR-052.
- [ ] Apply to existing iter subprocess violations (would have caught iter 3 d28bd51).

## Fix Strategy

(Deferred to investigation.)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P094 (parent — README refresh on creation), P062 (parent — README refresh on transition), P125 (sibling — PreToolUse:Bash gate pattern), P141 (sibling — changeset-discipline gate), ADR-014 (single-commit grain), P118 (`/wr-itil:reconcile-readme` — recovery path)

## Related

- ADR-014 — single-commit grain.
- P094 — README refresh on creation contract (manage-problem Step 5).
- P062 — README refresh on transition contract (manage-problem Step 7).
- P125 — staging-trap detector PreToolUse:Bash hook (precedent shape).
- P141 — changeset-discipline PreToolUse:Bash hook (precedent shape).
- P118 — reconcile-readme recovery path.
- iter 4 P157 retro — `docs/retros/2026-05-04-p159-iter.md` (incident location).

## Change Log

- **2026-05-04** — Opened by orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 per user direction "capture all four now". Sibling finding from iter 4 P157 backfill. Skeleton ticket; investigation deferred.
